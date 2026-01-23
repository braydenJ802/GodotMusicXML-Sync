#pragma once
#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/classes/ref.hpp>
#include <godot_cpp/variant/node_path.hpp>

namespace godot {

class SongData;

class AudioClock : public Node {
    GDCLASS(AudioClock, Node)

    Ref<SongData> song_data;
    bool running = false;
    double song_time = 0.0;
    int current_bar = -1;
    int current_beat = -1;

    NodePath audio_player_path; // optional later

protected:
    static void _bind_methods();

public:
    void set_song_data(const Ref<SongData> &p_data);
    Ref<SongData> get_song_data() const;

    void set_audio_player_path(const NodePath &p_path);
    NodePath get_audio_player_path() const;

    void start();
    void stop();
    bool is_running() const;

    double get_song_time() const;

    void _process(double delta) override;
};

} // namespace godot
