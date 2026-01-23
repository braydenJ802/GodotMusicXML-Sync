#pragma once
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>

namespace godot {

class SongData;

class MusicXMLParser : public RefCounted {
    GDCLASS(MusicXMLParser, RefCounted)

protected:
    static void _bind_methods();

public:
    MusicXMLParser() = default;

    Ref<SongData> parse_text(const String &xml_text) const;
};

}
