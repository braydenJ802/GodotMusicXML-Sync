#include "music_xml_parser.h"
#include "song_data.h"

#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

void MusicXMLParser::_bind_methods() {
    ClassDB::bind_method(D_METHOD("parse_text", "xml_text"), &MusicXMLParser::parse_text);
}

Ref<SongData> MusicXMLParser::parse_text(const String &xml_text) const {
    UtilityFunctions::print("Parser got chars:", xml_text.length());
    Ref<SongData> data;
    data.instantiate();

    // Temporary dummy values to prove data flow.
    data->set_bpm_map(PackedFloat32Array{120.0f});
    data->set_measure_offsets(PackedFloat32Array{0.0f});
    data->set_cue_point(StringName("intro"), 0);

    return data;
}
