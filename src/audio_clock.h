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
    bool looping = false; 

    double song_time = 0.0;
    int num_measures = 0;
    int current_measure = -1;
    int current_beat = -1;
    double loop_start_time = 0.0;
    double loop_end_time = 0.0;

    NodePath audio_player_path;

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
    bool is_looping() const;

    double get_song_time() const;
    double get_num_measures() const;
    void set_loop_bounds_time(double p_start_time, double p_end_time);
    void set_loop_bounds_measure(int p_start_measure, int p_end_measure);

    void _process(double delta) override;
};

} // namespace godot
