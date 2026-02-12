#include "song_data.h"

using namespace godot;

void SongData::_bind_methods() {
    ClassDB::bind_method(D_METHOD("set_bpm_map", "v"), &SongData::set_bpm_map);
    ClassDB::bind_method(D_METHOD("get_bpm_map"), &SongData::get_bpm_map);
    ADD_PROPERTY(PropertyInfo(Variant::PACKED_FLOAT32_ARRAY, "bpm_map"), "set_bpm_map", "get_bpm_map");

    ClassDB::bind_method(D_METHOD("set_measure_offsets", "v"), &SongData::set_measure_offsets);
    ClassDB::bind_method(D_METHOD("get_measure_offsets"), &SongData::get_measure_offsets);
    ADD_PROPERTY(PropertyInfo(Variant::PACKED_FLOAT32_ARRAY, "measure_offsets"), "set_measure_offsets", "get_measure_offsets");

    ClassDB::bind_method(D_METHOD("set_cues_by_measure", "cues"), &SongData::set_cues_by_measure);
    ClassDB::bind_method(D_METHOD("get_cues_by_measure"), &SongData::get_cues_by_measure);
    ADD_PROPERTY(PropertyInfo(Variant::DICTIONARY, "cues_by_measure"), "set_cues_by_measure", "get_cues_by_measure");

    ClassDB::bind_method(D_METHOD("set_cues_by_name", "cues"), &SongData::set_cues_by_name);
    ClassDB::bind_method(D_METHOD("get_cues_by_name"), &SongData::get_cues_by_name);
    ADD_PROPERTY(PropertyInfo(Variant::DICTIONARY, "cues_by_name"), "set_cues_by_name", "get_cues_by_name");

    ClassDB::bind_method(D_METHOD("add_cue_point", "name", "measure_index"), &SongData::add_cue_point);
}


void SongData::add_cue_point(const StringName &name, int measure_index) 
{
    // 1) Update Measure -> Names
    if (cues_by_measure.has(measure_index)) 
    {
        Array cues_list = cues_by_measure[measure_index];
        cues_list.append(name);
        cues_by_measure[measure_index] = cues_list;
    } 
    else 
    {
        Array cues_list;
        cues_list.append(name);
        cues_by_measure[measure_index] = cues_list;
    }

    // 2) Update Name -> Measures
    if (cues_by_name.has(name)) 
    {
        Array cues_list = cues_by_name[name];
        cues_list.append(measure_index);
        cues_by_name[name] = cues_list;
    } 
    else 
    {
        Array cues_list;
        cues_list.append(measure_index);
        cues_by_name[name] = cues_list;
    }
}