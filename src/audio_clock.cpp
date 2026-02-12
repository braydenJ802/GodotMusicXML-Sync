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

    ClassDB::bind_method(D_METHOD("start"), &AudioClock::start);
    ClassDB::bind_method(D_METHOD("stop"), &AudioClock::stop);
    ClassDB::bind_method(D_METHOD("is_running"), &AudioClock::is_running);
    ClassDB::bind_method(D_METHOD("is_looping"), &AudioClock::is_looping);

    ClassDB::bind_method(D_METHOD("get_song_time"), &AudioClock::get_song_time);
    ClassDB::bind_method(D_METHOD("get_num_measures"), &AudioClock::get_num_measures);
    ClassDB::bind_method(D_METHOD("set_loop_bounds_time", "start", "end"), &AudioClock::set_loop_bounds_time);
    ClassDB::bind_method(D_METHOD("set_loop_bounds_measure", "start", "end"), &AudioClock::set_loop_bounds_measure);

    ADD_SIGNAL(MethodInfo("beat", PropertyInfo(Variant::INT, "beat_number")));
    ADD_SIGNAL(MethodInfo("measure", PropertyInfo(Variant::INT, "measure_number")));
    ADD_SIGNAL(MethodInfo("marker_passed", PropertyInfo(Variant::STRING_NAME, "marker_name")));
}

void AudioClock::set_song_data(const Ref<SongData> &p_data) 
{
    song_data = p_data;
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

void AudioClock::start() 
{
    running = true;
    song_time = 0.0;
    current_measure = -1;
    current_beat = -1;
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
        if (p_start_measure < offsets.size() && p_end_measure < offsets.size()) 
        {
            // Look up the time (i.e. translate measures into seconds)
            set_loop_bounds_time(offsets[p_start_measure], offsets[p_end_measure]);
        }
    }
}

void AudioClock::_process(double delta) 
{
    if (!running) return;

    // --- SYNC LOGIC ---
    // Instead of adding delta, we ask the AudioPlayer where it is
    // This prevents "Game Time" (FPS) drifting from "Audio Time" (DPS)
    Node* node = get_node_or_null(audio_player_path);
    AudioStreamPlayer* audio_player = Object::cast_to<AudioStreamPlayer>(node); // safe cast to audiostreamplayer node

    if (audio_player && audio_player->is_playing()) 
    {
        // Get the exact time from the audio thread
        song_time = audio_player->get_playback_position();
    }
    else 
    {
        // Fallback if no is hooked up / currently playing (for testing)
        song_time += delta;
    }

    // --- LOOP LOGIC ---
    // We check every frame if the song is over and set it to loop again (if looping is set to true)
    if (looping && song_time >= loop_end_time) 
    {
        if (audio_player)
            audio_player->seek(loop_start_time); // loop
        song_time = loop_start_time;
    }

    // --- MEASURE DETECTION ---
    if (song_data.is_valid()) 
    {
        PackedFloat32Array offsets = song_data->get_measure_offsets();
        if (offsets.size() > 0) 
        {
            // Find current measure based on time
            int measure_now = 0;
            for (int i = 0; i < offsets.size(); i++) 
            {
                if (song_time >= offsets[i]) 
                    measure_now = i;
                else break;
            }

            if (measure_now != current_measure) 
            {
                current_measure = measure_now;
                emit_signal("measure", current_measure);

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
                        UtilityFunctions::print("Marker passed: ", marker_name);
                    }
                }
            }
        }
    }
}
