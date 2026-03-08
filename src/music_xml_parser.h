#pragma once
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>

#include <vector> // Needed for std::vector

namespace godot {

class SongData;

class MusicXMLParser : public RefCounted {
    GDCLASS(MusicXMLParser, RefCounted)

protected:
    static void _bind_methods();

public:
    MusicXMLParser() = default;

    Ref<SongData> parse_text(const String &xml_text) const;

private:
    // Helper function to smooth tempos
    void interpolate_tempo(const String &keyword, const Dictionary &cues, PackedFloat32Array &bpm_map) const;

    // Math helper function. Returns the total song time as a double.
    double calculate_measure_offsets(const PackedFloat32Array &bpm_map, const std::vector<int> &beats_per_measure_array, PackedFloat32Array &measure_offsets) const;
};

}
