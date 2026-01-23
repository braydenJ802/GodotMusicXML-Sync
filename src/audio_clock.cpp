#include "audio_clock.h"
#include "song_data.h"

#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/string_name.hpp>

using namespace godot;

void AudioClock::_bind_methods() {
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
    ClassDB::bind_method(D_METHOD("get_song_time"), &AudioClock::get_song_time);

    ADD_SIGNAL(MethodInfo("beat", PropertyInfo(Variant::INT, "beat_number")));
    ADD_SIGNAL(MethodInfo("bar", PropertyInfo(Variant::INT, "bar_number")));
    ADD_SIGNAL(MethodInfo("marker_passed", PropertyInfo(Variant::STRING_NAME, "marker_name")));
}

void AudioClock::set_song_data(const Ref<SongData> &p_data) {
    song_data = p_data;
}

Ref<SongData> AudioClock::get_song_data() const {
    return song_data;
}

void AudioClock::set_audio_player_path(const NodePath &p_path) {
    audio_player_path = p_path;
}

NodePath AudioClock::get_audio_player_path() const {
    return audio_player_path;
}

void AudioClock::start() {
    running = true;
    song_time = 0.0;
    current_bar = -1;
    current_beat = -1;
}

void AudioClock::stop() {
    running = false;
}

bool AudioClock::is_running() const {
    return running;
}

double AudioClock::get_song_time() const {
    return song_time;
}

void AudioClock::_process(double delta) {
    if (!running) return;

    song_time += delta;

    // Stub beat: one "beat" per second (replace later with tempo math).
    int beat_now = (int)song_time;
    if (beat_now != current_beat) {
        current_beat = beat_now;
        emit_signal("beat", current_beat);
    }

    // Bar detection from measure_offsets.
    if (song_data.is_valid()) {
        PackedFloat32Array offsets = song_data->get_measure_offsets();
        if (offsets.size() > 0) {
            int bar_now = 0;
            for (int i = 0; i < offsets.size(); i++) {
                if (song_time >= offsets[i]) bar_now = i;
                else break;
            }

            if (bar_now != current_bar) {
                current_bar = bar_now;
                emit_signal("bar", current_bar);

                // Fire marker_passed if any cue_points map to this bar.
                Dictionary cues = song_data->get_cue_points();
                Array keys = cues.keys();
                for (int i = 0; i < keys.size(); i++) {
                    Variant k = keys[i];
                    Variant v = cues[k];
                    if ((int)v == current_bar) {
                        emit_signal("marker_passed", StringName(k));
                    }
                }
            }
        }
    }
}
