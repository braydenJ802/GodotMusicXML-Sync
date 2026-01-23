#pragma once
#include <godot_cpp/classes/resource.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/string_name.hpp>

namespace godot {

class SongData : public Resource {
    GDCLASS(SongData, Resource)

    PackedFloat32Array bpm_map;
    PackedFloat32Array measure_offsets;
    Dictionary cue_points;

protected:
    static void _bind_methods();

public:
    void set_bpm_map(const PackedFloat32Array &v) { bpm_map = v; }
    PackedFloat32Array get_bpm_map() const { return bpm_map; }

    void set_measure_offsets(const PackedFloat32Array &v) { measure_offsets = v; }
    PackedFloat32Array get_measure_offsets() const { return measure_offsets; }

    void set_cue_point(const StringName &name, int measure_index) { cue_points[name] = measure_index; }
    Dictionary get_cue_points() const { return cue_points; }
};

}
