#pragma once
#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/node_path.hpp>
#include <godot_cpp/variant/string_name.hpp>

namespace godot {

class TransitionManager : public Node {
    GDCLASS(TransitionManager, Node)

    NodePath clock_path;
    NodePath connected_clock_path;

    int queued_measure = -1;
    StringName queued_marker;

protected:
    static void _bind_methods();

public:
    void set_clock_path(const NodePath &p_path);
    NodePath get_clock_path() const;

    void queue_switch_at_measure(int measure_number);
    void queue_switch_at_marker(const StringName &marker_name);
    void cancel_switch();

    void _ready() override;

private:
    void _connect_clock();
    void _disconnect_clock();

    void _on_clock_measure(int measure_number);
    void _on_clock_marker_passed(const StringName &marker_name);
};

} // namespace godot
