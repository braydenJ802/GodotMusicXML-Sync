#include "song_data.h"

using namespace godot;

void SongData::_bind_methods() {
    ClassDB::bind_method(D_METHOD("set_bpm_map", "v"), &SongData::set_bpm_map);
    ClassDB::bind_method(D_METHOD("get_bpm_map"), &SongData::get_bpm_map);
    ADD_PROPERTY(PropertyInfo(Variant::PACKED_FLOAT32_ARRAY, "bpm_map"), "set_bpm_map", "get_bpm_map");

    ClassDB::bind_method(D_METHOD("set_measure_offsets", "v"), &SongData::set_measure_offsets);
    ClassDB::bind_method(D_METHOD("get_measure_offsets"), &SongData::get_measure_offsets);
    ADD_PROPERTY(PropertyInfo(Variant::PACKED_FLOAT32_ARRAY, "measure_offsets"), "set_measure_offsets", "get_measure_offsets");

    ClassDB::bind_method(D_METHOD("set_cue_point", "name", "measure_index"), &SongData::set_cue_point);
    ClassDB::bind_method(D_METHOD("get_cue_points"), &SongData::get_cue_points);
    ADD_PROPERTY(PropertyInfo(Variant::DICTIONARY, "cue_points"), "", "get_cue_points");
}
