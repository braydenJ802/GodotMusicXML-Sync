#include "audio_clock.h"
#include "song_data.h"

#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/string_name.hpp>

#include <godot_cpp/classes/audio_stream_player.hpp> // needed to talk to the audio node

using namespace godot;

void AudioClock::_bind_methods() 
{
    ClassDB::bind_method(D_METHOD("set_song_data", "song_data"), &AudioClock::set_song_data);
    ClassDB::bind_method(D_METHOD("get_song_data"), &AudioClock::get_song_data);
    ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "song_data", PROPERTY_HINT_RESOURCE_TYPE, "SongData"),
                 "set_song_data", "get_song_data");

    ClassDB::bind_method(D_METHOD("set_audio_player_path", "path"), &AudioClock::set_audio_player_path);
    ClassDB::bind_method(D_METHOD("get_audio_player_path"), &AudioClock::get_audio_player_path);
    ADD_PROPERTY(PropertyInfo(Variant::NODE_PATH, "audio_player_path"), "set_audio_player_path", "get_audio_player_path");

    ClassDB::bind_method(D_METHOD("start", "time_offset"), &AudioClock::start);
    ClassDB::bind_method(D_METHOD("resume"), &AudioClock::resume);
    ClassDB::bind_method(D_METHOD("stop"), &AudioClock::stop);
    ClassDB::bind_method(D_METHOD("is_running"), &AudioClock::is_running);
    ClassDB::bind_method(D_METHOD("is_looping"), &AudioClock::is_looping);

    ClassDB::bind_method(D_METHOD("get_song_time"), &AudioClock::get_song_time);
    ClassDB::bind_method(D_METHOD("get_num_measures"), &AudioClock::get_num_measures);
    ClassDB::bind_method(D_METHOD("set_loop_bounds_time", "start", "end"), &AudioClock::set_loop_bounds_time);
    ClassDB::bind_method(D_METHOD("set_loop_bounds_measure", "start", "end"), &AudioClock::set_loop_bounds_measure);
    ClassDB::bind_method(D_METHOD("clear_loop"), &AudioClock::clear_loop);

    ADD_SIGNAL(MethodInfo("beat", PropertyInfo(Variant::INT, "beat_number")));
    ADD_SIGNAL(MethodInfo("measure", PropertyInfo(Variant::INT, "measure_number")));
    ADD_SIGNAL(MethodInfo("marker_passed", PropertyInfo(Variant::STRING_NAME, "marker_name")));
    ADD_SIGNAL(MethodInfo("loop_occurred", PropertyInfo(Variant::FLOAT, "new_time")));
}

void AudioClock::set_song_data(const Ref<SongData> &p_data) 
{
    song_data = p_data;

    // Update the measure count
    // (-1 because the last offset is the end-of-song fencepost)
    if (song_data.is_valid() && song_data->get_measure_offsets().size() > 0) 
        num_measures = song_data->get_measure_offsets().size() - 1;
    else
        num_measures = 0;
}

Ref<SongData> AudioClock::get_song_data() const 
{
    return song_data;
}

void AudioClock::set_audio_player_path(const NodePath &p_path) 
{
    audio_player_path = p_path;
}

NodePath AudioClock::get_audio_player_path() const 
{
    return audio_player_path;
}

void AudioClock::start(double p_start_time) 
{
    running = true;
    song_time = p_start_time;
    current_measure = -1;
    current_beat = -1;
}

void AudioClock::resume() {
    running = true;
}

void AudioClock::stop() 
{
    running = false;
}

bool AudioClock::is_running() const 
{
    return running;
}

bool AudioClock::is_looping() const 
{
    return looping;
}

double AudioClock::get_song_time() const 
{
    return song_time;
}

double AudioClock::get_num_measures() const 
{
    return num_measures;
}

void AudioClock::set_loop_bounds_time(double p_start_time, double p_end_time) 
{
    loop_start_time = p_start_time;
    loop_end_time = p_end_time;
    looping = true;

} 

void AudioClock::set_loop_bounds_measure(int p_start_measure, int p_end_measure) 
{
    if (song_data.is_valid()) 
    {
        // Get the array of starting times for each measure
        PackedFloat32Array offsets = song_data->get_measure_offsets();

        // Convert Musical Number (1-based) to Array Index (0-based)
        int start_index = p_start_measure - 1;
        int end_index = p_end_measure - 1;

        if (start_index >= 0 && end_index < offsets.size() && start_index < end_index) 
        {
            // Look up the time (i.e. translate measures into seconds)
            set_loop_bounds_time(offsets[start_index], offsets[end_index]);
        }
    }
}

void AudioClock::clear_loop() {
    looping = false;
    loop_start_time = 0.0;
    loop_end_time = 0.0;
}

void AudioClock::_process(double delta) 
{
    if (!running) return;

    // --- SYNC LOGIC ---
    // Instead of adding delta, we ask the AudioPlayer where it is
    // This prevents "Game Time" (FPS) drifting from "Audio Time" (DPS)
    Node* node = get_node_or_null(audio_player_path);

    // Check if the node exists, if it has been added to the scene tree yet, and 
    // if it isn't currently being freed by the Music Director (GDScript)
    bool is_node_valid = (node != nullptr && node->is_inside_tree() && !node->is_queued_for_deletion());
    AudioStreamPlayer* audio_player = is_node_valid ? Object::cast_to<AudioStreamPlayer>(node) : nullptr; // safe cast to AudioStreamPlayer node

    if (audio_player)
    {
        if (audio_player->is_playing()) 
        {
            // Get the exact time from the audio thread
            song_time = audio_player->get_playback_position();
        }
        else 
        {
            // --- End of Song Check ---
            // If the player is not playing, AND we have valid song data,
            // it probably means the song has finished.
            if (song_data.is_valid()) {
                PackedFloat32Array offsets = song_data->get_measure_offsets();
                // The last entry in offsets is the "End of Song" time.
                if (offsets.size() > 0)
                    song_time = offsets[offsets.size() - 1];
            }

            running = false;
            UtilityFunctions::print("AudioClock: Song finished, stopping clock.");
            return;
        }
    }
    else
    {
        song_time += delta;
    }
    

    // --- LOOP LOGIC ---
    // We check every frame if the song is over and set it to loop again (if looping is set to true)
    if (looping && song_time >= (loop_end_time - 0.05)) // trigger the loop 50ms early so the "seek" happens before a "pop" happens 
    {
        song_time = loop_start_time;

        // Force reset the measure tracker so Measure Detection notices a new measure
        current_measure = -1; 

        // Instead of seeking one player, we tell the MusicDirector (GDScript) a loop happened
        emit_signal("loop_occurred", loop_start_time);
    }

    // Do not proceed if SongData isn't loaded
    if (!song_data.is_valid()) {
        return;
    }

    PackedFloat32Array offsets = song_data->get_measure_offsets();
    if (offsets.size() == 0) return;

    // --- MEASURE DETECTION ---
    // Find current measure based on time
    int measure_now = 0;
    for (int i = 0; i < num_measures; i++) 
    {
        if (song_time >= offsets[i]) 
            measure_now = i;
        else break;
    }

    if (measure_now != current_measure) 
    {
        current_measure = measure_now;
        emit_signal("measure", current_measure + 1);

        // -- MARKER LOGIC --
        Dictionary cues = song_data->get_cues_by_measure(); // O(1) lookup
                
        // Check if this measure has any cues
        if (cues.has(current_measure)) 
        {
            // If yes, get the list of cues
            Array markers = cues[current_measure];
                    
            // Loop through the markers at this specific measure only
            for(int i = 0; i < markers.size(); i++) 
            {
                StringName marker_name = markers[i];
                emit_signal("marker_passed", marker_name);
                //UtilityFunctions::print("Marker passed: ", marker_name);
            }
        }
    }

    // --- BEAT DETECTION ---
    // Get the data for the current measure
    PackedFloat32Array bpms = song_data->get_bpm_map();
    PackedInt32Array beats_per_measure = song_data->get_beats_per_measure();

    // UtilityFunctions::print(
    //     "DEBUG beat arrays | current_measure=", current_measure,
    //     " bpm_size=", bpms.size(),
    //     " beats_size=", beats_per_measure.size()
    // );

    if (current_measure >= 0 && 
        current_measure < num_measures && 
        current_measure < bpms.size() &&
        current_measure < beats_per_measure.size())
    {
        double measure_start_time = offsets[current_measure];
        double current_bpm = bpms[current_measure];
        int beats_in_measure = beats_per_measure[current_measure];

        if (current_bpm > 0.0 && beats_in_measure > 0)
        {
            double seconds_per_beat = 60.0 / current_bpm;
            double time_in_measure = song_time - measure_start_time;
            int raw_beat_now = (int)(time_in_measure / seconds_per_beat);

            // UtilityFunctions::print(
            //     "BEAT DEBUG | measure=", current_measure + 1,
            //     " bpm=", current_bpm,
            //     " beats_in_measure=", beats_in_measure,
            //     " time_in_measure=", time_in_measure,
            //     " raw_beat_now=", raw_beat_now,
            //     " current_beat=", current_beat
            // );

            if (raw_beat_now >= 0 &&
                raw_beat_now < beats_in_measure &&
                raw_beat_now != current_beat)
            {
                current_beat = raw_beat_now;
                emit_signal("beat", current_beat + 1);
            }
        }
    }
    // else
    // {
    //     UtilityFunctions::print(
    //         "BEAT BLOCK SKIPPED | current_measure=", current_measure,
    //         " num_measures=", num_measures,
    //         " bpm_size=", bpms.size(),
    //         " beats_size=", beats_per_measure.size()
    //     );
    // }
}
