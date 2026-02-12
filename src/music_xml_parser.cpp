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


    // Loop through the file
    while (parser->read() == OK)
    {
        // We only care about "Elements" (opening tags like <measure>)
        if (parser->get_node_type() == XMLParser::NODE_ELEMENT)
        {
            String node_name = parser->get_node_name();
            
            if (node_name == "part") 
            {
                // If we have already calculated time (meaning we finished Part 1), stop.
                if (current_total_time > 0.0) 
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
                // RECORD DATA for this measure
                measure_offsets.append(current_total_time);
                bpm_map.append(current_bpm);

                // CALCULATE DURATION for the *next* measure accumulation
                // (Beats * 60) / BPM = Seconds per measure
                
                // NOTE: This assumes BPM is Quarter-Note based. 
                // If beat-type is 8 (e.g. 6/8), this math might need a modifier later, 
                // but for 4/4 and 3/4 this works perfectly.
                double seconds_per_beat = 60.0 / current_bpm;
                double measure_duration = seconds_per_beat * (double)current_beats_per_measure;

                // Add to accumulator
                current_total_time += measure_duration;

                // Log for debugging
                String measure_number = parser->get_named_attribute_value("number");
                UtilityFunctions::print("Measure ", measure_number, " starts at: ", measure_offsets[measure_index], "s");
                
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
                    current_bpm = parser->get_named_attribute_value("tempo").to_float();
                    UtilityFunctions::print(">>> Tempo Change: ", current_bpm);    
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
                    data->add_cue_point(text, measure_index);
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

    UtilityFunctions::print("---- Parsing Complete. Total Time: ", current_total_time, "s ----");

    // SAVE DATA TO RESOURCE
    data->set_measure_offsets(measure_offsets);
    data->set_bpm_map(bpm_map);
    // cues already saved

    return data;
}
