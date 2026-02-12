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
    Dictionary cues_by_measure;        // Key: int (Measure) -> Value: Array[String]
    Dictionary cues_by_name;           // Key: String (Name) -> Value: Array[int]

protected:
    static void _bind_methods();

public:
    void set_bpm_map(const PackedFloat32Array &v) { bpm_map = v; }
    PackedFloat32Array get_bpm_map() const { return bpm_map; }

    void set_measure_offsets(const PackedFloat32Array &v) { measure_offsets = v; }
    PackedFloat32Array get_measure_offsets() const { return measure_offsets; }

    void set_cues_by_measure(const Dictionary &p_cues) { cues_by_measure = p_cues; }
    Dictionary get_cues_by_measure() const { return cues_by_measure; }

    void set_cues_by_name(const Dictionary &p_cues) { cues_by_name = p_cues; }
    Dictionary get_cues_by_name() const { return cues_by_name; }

    void add_cue_point(const StringName &name, int measure_index);
};

}
