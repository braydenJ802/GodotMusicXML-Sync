#include "register_types.h"
#include <gdextension_interface.h>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>

// Classes
#include "song_data.h"
#include "music_xml_parser.h"
#include "audio_clock.h"
#include "transition_manager.h"

using namespace godot;

void initialize_godot_music_xml_sync_module(ModuleInitializationLevel p_level) {
    if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
        return;
    }

    UtilityFunctions::print("godot_music_xml_sync loaded!");

    ClassDB::register_class<godot::SongData>();
    ClassDB::register_class<godot::MusicXMLParser>();
    ClassDB::register_class<godot::AudioClock>();
    ClassDB::register_class<godot::TransitionManager>();
}

void uninitialize_godot_music_xml_sync_module(ModuleInitializationLevel p_level) {
    if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
        return;
    }
}

extern "C" {
// Initialization.
GDExtensionBool GDE_EXPORT godot_music_xml_sync_library_init(GDExtensionInterfaceGetProcAddress p_get_proc_address, const GDExtensionClassLibraryPtr p_library, GDExtensionInitialization *r_initialization) {
    godot::GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library, r_initialization);

    init_obj.register_initializer(initialize_godot_music_xml_sync_module);
    init_obj.register_terminator(uninitialize_godot_music_xml_sync_module);
    init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);

    return init_obj.init();
}
}