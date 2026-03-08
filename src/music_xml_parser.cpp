#include "music_xml_parser.h"
#include "song_data.h"

#include <godot_cpp/classes/xml_parser.hpp>       // for Godot's built-in XML Parser
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

void MusicXMLParser::_bind_methods() 
{
    ClassDB::bind_method(D_METHOD("parse_text", "xml_text"), &MusicXMLParser::parse_text);
}

Ref<SongData> MusicXMLParser::parse_text(const String &xml_text) const 
{
    UtilityFunctions::print("----Starting MusicXML Parse----");
    
    // Create song data structure
    Ref<SongData> data;
    data.instantiate();

    // -- STATE VARIABLES --
    // We need to track these as we move linearly through the file
    double current_total_time = 0.0;
    double current_bpm = 120.0; // Default if not defined
    int current_beats_per_measure = 4;
    int current_beat_type = 4; // 4/4 as the Default
    int current_divisions = 1;
    int measure_index = 0;

    // Temporary storage containers
    PackedFloat32Array bpm_map;
    PackedFloat32Array measure_offsets;
    std::vector<int> beats_per_measure_array;

    // Create the Godot XMLParser helper
    Ref<XMLParser> parser;
    parser.instantiate();

    // Feed the text data into the parser
    // Convert the String to a Godot Byte Array
    PackedByteArray bytes = xml_text.to_utf8_buffer();
    Error err = parser->open_buffer(bytes);
    if (err != OK) 
    {
        UtilityFunctions::push_error("Failed to open XML buffer.");
        return data; // Return empty
    }
    // Pass the array object to the parser
    parser->open_buffer(bytes);


    // =================================================================
    // PASS 1: READ THE FILE
    // =================================================================
    while (parser->read() == OK)
    {
        // We only care about "Elements" (opening tags like <measure>)
        if (parser->get_node_type() == XMLParser::NODE_ELEMENT)
        {
            String node_name = parser->get_node_name();
            
            if (node_name == "part") 
            {
                // Check if we already gathered data for the first track
                if (bpm_map.size() > 0) 
                {
                    UtilityFunctions::print("Found second Part (Instrument). Stopping parse to preserve sync.");
                    break; // Breaks out of the while loop entirely
                }
            }

            // -----------------------------------------------
            // 1. MEASURE HANDLING
            // -----------------------------------------------
            if (node_name == "measure")
            {
                // RECORD DATA 
                bpm_map.append(current_bpm);
                beats_per_measure_array.push_back(current_beats_per_measure);

                measure_index++;
            }


            // -----------------------------------------------
            // 2. ATTRIBUTES (Divisions, Time Sig)
            // -----------------------------------------------
            // Check for Divisions
            else if (node_name == "divisions")
            {
                // The value is inside the element, so we need to 
                // read one more step to get to the text
                parser->read();
                if (parser->get_node_type() == XMLParser::NODE_TEXT)
                {
                    current_divisions = parser->get_node_data().to_int();
                    UtilityFunctions::print("Found Divisions: ", current_divisions);
                }
            }
            
            // Check for Time Signature 
            // Numerator
            else if (node_name == "beats")
            {
                parser->read();
                if (parser->get_node_type() == XMLParser::NODE_TEXT) 
                {
                    current_beats_per_measure = parser->get_node_data().to_int();

                    // RETROACTIVE UPDATE:
                    // Because we read this tag *inside* the measure, we need to 
                    // update the array entry we just pushed at the start of the measure!
                    if (beats_per_measure_array.size() > 0)
                        beats_per_measure_array[beats_per_measure_array.size() - 1] = current_beats_per_measure;
                }
            }
            // Denominator
            else if (node_name == "beat-type") 
            {
                parser->read();
                if (parser->get_node_type() == XMLParser::NODE_TEXT) {
                    current_beat_type = parser->get_node_data().to_int();
                    // Print the full time signature now that we have both
                    UtilityFunctions::print(">>> Time Signature: ", current_beats_per_measure, "/", current_beat_type);
                }
            }


            // -----------------------------------------------
            // 3. DIRECTIONS (Tempo, Words, Section)
            // -----------------------------------------------
            // Check for Tempo
            else if (node_name == "sound") 
            {
                if (parser->has_attribute("tempo")) 
                {
                    float new_bpm = parser->get_named_attribute_value("tempo").to_float();
                    current_bpm = new_bpm;

                    UtilityFunctions::print(">>> Tempo Change: ", current_bpm);    

                    // Rewrite: Since we just found a new tempo inside the current measure, 
                    // we must update the entry we just added to the map.
                    if (bpm_map.size() > 0) 
                    {
                        // update current measure's entry
                        bpm_map.set(bpm_map.size() - 1, current_bpm);
                    }
                }
            }

            // Check for Words (Cues/Directions and Sections)
            else if (node_name == "words" || node_name == "rehearsal")
            {
                // For cleaner logging
                bool is_section = false;
                if (node_name == "rehearsal")
                    is_section = true;
                
                parser->read();
                if (parser->get_node_type() == XMLParser::NODE_TEXT)
                {
                    String text = parser->get_node_data();
                    // Log
                    if (!is_section)
                        UtilityFunctions::print("**Found Cue: ", text, " at measure ", measure_index);
                    else
                        UtilityFunctions::print(">>> Section: ", text, " (measure ", measure_index, ")");

                    // Save cues
                    data->add_cue_point(text, measure_index - 1);
                }
            }

            
            // -----------------------------------------------
            // 4. HARMONY (Chords)
            // -----------------------------------------------
            else if (node_name == "root-step") 
            {
                // TODO: This is a simplified check just to prove we can see chords
                parser->read();
                if (parser->get_node_type() == XMLParser::NODE_TEXT) 
                {
                    String root = parser->get_node_data();
                    UtilityFunctions::print("~Found Chord Root: ", root);
                }
            }

        }
    }

    // =================================================================
    // PASS 2: SMOOTH OUT ACCEL. AND RIT.
    // =================================================================
    Dictionary cues_by_name = data->get_cues_by_name();

    interpolate_tempo("accel.", cues_by_name, bpm_map);
    interpolate_tempo("rit.", cues_by_name, bpm_map);

    // =================================================================
    // PASS 3: RECALCULATE EXACT TIMESTAMPS
    // =================================================================
   double total_time = calculate_measure_offsets(bpm_map, beats_per_measure_array, measure_offsets);
    
    // Pad BPM map to match the size of measure_offsets (for the fencepost)
    bpm_map.append(bpm_map[bpm_map.size() - 1]); 

    UtilityFunctions::print("---- Parsing & Sync Complete. Total Time: ", total_time, "s ----");


    // SAVE DATA TO RESOURCE
    data->set_measure_offsets(measure_offsets);
    data->set_bpm_map(bpm_map);
    // cues already saved

    return data;
}



void MusicXMLParser::interpolate_tempo(const String &keyword, const Dictionary &cues, PackedFloat32Array &bpm_map) const 
{
    if (!cues.has(keyword)) return;

    Array indices = cues[keyword];
    
    for (int i = 0; i < indices.size(); i++) 
    {
        int start_idx = indices[i];
        
        // Safety check
        if (start_idx >= bpm_map.size()) continue;

        float start_bpm = bpm_map[start_idx];
        float target_bpm = start_bpm;
        int end_idx = -1;

        // DEBUG: Print where we are starting
        UtilityFunctions::print("--- Interpolating ", keyword, " starting at Measure ", start_idx + 1, " (BPM: ", start_bpm, ") ---");

        // Scan forward to find the target
        for (int j = start_idx + 1; j < bpm_map.size(); j++) 
        {
            // Use a small epsilon for float comparison to be safe
            if (Math::abs(bpm_map[j] - start_bpm) > 0.001) 
            {
                target_bpm = bpm_map[j];
                end_idx = j;
                UtilityFunctions::print("    -> Found Target at Measure ", end_idx + 1, " (BPM: ", target_bpm, ")");
                break;
            }
        }

        // Apply linear interpolation
        if (end_idx > start_idx) 
        {
            float bpm_diff = target_bpm - start_bpm;
            int steps = end_idx - start_idx;
            float step_amount = bpm_diff / steps;
            
            UtilityFunctions::print("    -> Steps: ", steps, " | Amount per step: ", step_amount);

            for (int j = 1; j < steps; j++) 
            {
                float new_bpm = start_bpm + (step_amount * j);
                bpm_map.set(start_idx + j, new_bpm);
                UtilityFunctions::print("    -> Set Measure ", (start_idx + j) + 1, " to ", new_bpm);
            }
        }
        else
        {
            UtilityFunctions::print("    -> ERROR: Could not find a target tempo change for ", keyword);
        }
    }
}

double MusicXMLParser::calculate_measure_offsets(const PackedFloat32Array &bpm_map, const std::vector<int> &beats_per_measure_array, PackedFloat32Array &measure_offsets) const {
    measure_offsets.clear(); 
    double final_total_time = 0.0;

    for (int i = 0; i < bpm_map.size(); i++) 
    {
        // Record the start time of this measure
        measure_offsets.append(final_total_time);
        
        // Safety check to ensure we have beat data for this measure
        int beats = (i < beats_per_measure_array.size()) ? beats_per_measure_array[i] : 4;
        
        // Calculate the duration of this measure
        double seconds_per_beat = 60.0 / bpm_map[i];
        final_total_time += seconds_per_beat * (double)beats;
    }
    
    // Add the "End of Song" / Fencepost marker
    measure_offsets.append(final_total_time);
    
    return final_total_time;
}