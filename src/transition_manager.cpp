#include "transition_manager.h"

#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/core/object.hpp> // callable_mp

namespace godot {

void TransitionManager::_bind_methods() 
{
    ClassDB::bind_method(D_METHOD("set_clock_path", "path"), &TransitionManager::set_clock_path);
    ClassDB::bind_method(D_METHOD("get_clock_path"), &TransitionManager::get_clock_path);
    ADD_PROPERTY(PropertyInfo(Variant::NODE_PATH, "clock_path"), "set_clock_path", "get_clock_path");

    ClassDB::bind_method(D_METHOD("queue_switch_at_measure", "measure_number"), &TransitionManager::queue_switch_at_measure);
    ClassDB::bind_method(D_METHOD("queue_switch_at_marker", "marker_name"), &TransitionManager::queue_switch_at_marker);
    ClassDB::bind_method(D_METHOD("cancel_switch"), &TransitionManager::cancel_switch);

    ADD_SIGNAL(MethodInfo(
        "transition_triggered",
        PropertyInfo(Variant::INT, "measure_number"),
        PropertyInfo(Variant::STRING_NAME, "marker_name")
    ));
}

void TransitionManager::set_clock_path(const NodePath &p_path) 
{
    if (p_path == clock_path) return;

    _disconnect_clock();
    clock_path = p_path;
    _connect_clock();
}

NodePath TransitionManager::get_clock_path() const 
{
    return clock_path;
}

void TransitionManager::queue_switch_at_measure(int measure_number) 
{
    queued_measure = measure_number;
    queued_marker = StringName();
}

void TransitionManager::queue_switch_at_marker(const StringName &marker_name) 
{
    queued_marker = marker_name;
    queued_measure = -1;
}

void TransitionManager::cancel_switch() 
{
    queued_measure = -1;
    queued_marker = StringName();
}

void TransitionManager::_ready() 
{
    _connect_clock();
}

void TransitionManager::_connect_clock() 
{
    if (!is_inside_tree()) return;
    if (clock_path.is_empty()) return;

    Node *clock = get_node_or_null(clock_path);
    if (!clock) 
    {
        UtilityFunctions::push_warning("TransitionManager: clock_path not found: ", String(clock_path));
        return;
    }

    const StringName sig_measure("measure");
    const StringName sig_marker("marker_passed");

    Callable on_measure = callable_mp(this, &TransitionManager::_on_clock_measure);
    Callable on_marker = callable_mp(this, &TransitionManager::_on_clock_marker_passed);

    if (clock->has_signal(sig_measure) && !clock->is_connected(sig_measure, on_measure)) 
    {
        clock->connect(sig_measure, on_measure);
    }
    if (clock->has_signal(sig_marker) && !clock->is_connected(sig_marker, on_marker)) 
    {
        clock->connect(sig_marker, on_marker);
    }

    connected_clock_path = clock_path;
}

void TransitionManager::_disconnect_clock() 
{
    if (!is_inside_tree()) 
    {
        connected_clock_path = NodePath();
        return;
    }
    if (connected_clock_path.is_empty()) return;

    Node *old_clock = get_node_or_null(connected_clock_path);
    if (old_clock) 
    {
        const StringName sig_measure("measure");
        const StringName sig_marker("marker_passed");

        Callable on_measure = callable_mp(this, &TransitionManager::_on_clock_measure);
        Callable on_marker = callable_mp(this, &TransitionManager::_on_clock_marker_passed);

        if (old_clock->is_connected(sig_measure, on_measure)) 
            old_clock->disconnect(sig_measure, on_measure);
        if (old_clock->is_connected(sig_marker, on_marker)) 
            old_clock->disconnect(sig_marker, on_marker);
    }

    connected_clock_path = NodePath();
}

void TransitionManager::_on_clock_measure(int measure_number) 
{
    if (queued_measure >= 0 && measure_number >= queued_measure) 
    {
        UtilityFunctions::print("Transition triggered at measure:", measure_number);
        emit_signal("transition_triggered", measure_number, StringName());
        cancel_switch();
    }
}

void TransitionManager::_on_clock_marker_passed(const StringName &marker_name) 
{
    if (!queued_marker.is_empty() && marker_name == queued_marker) 
    {
        UtilityFunctions::print("Transition triggered at marker:", String(marker_name));
        emit_signal("transition_triggered", -1, marker_name);
        cancel_switch();
    }
}

} // namespace godot
