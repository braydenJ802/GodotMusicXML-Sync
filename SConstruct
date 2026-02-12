#!/usr/bin/env python
import os
import sys

env = SConscript("godot-cpp/SConstruct")

# For reference:
# - godot-cpp/ is the submodule
# - src/ is the source code
# - project/bin/ is where the compiled DLL will go

env.Append(CPPPATH=["src"])
sources = Glob("src/*.cpp")

# 1. Check if we are building for the editor (docs aren't needed in release games)
if env["target"] in ["editor", "template_debug"]:
    
    # 2. Tell SCons where to find the XML Doc files
    doc_classes = Glob("docs/doc_classes/*.xml")

    if doc_classes:
        # 3. Generate a C++ file from the XMLs
        # This function (GodotCPPDocData) is provided by the godot-cpp SConstruct
        doc_data = env.GodotCPPDocData("src/gen/doc_data.gen.cpp", source=doc_classes)
        
        # 4. Add this generated file to the compilation list
        sources.append(doc_data)

if env["platform"] == "macos":
    library = env.SharedLibrary(
        "project/bin/godot_music_xml_sync.{}.{}.framework/godot_music_xml_sync.{}.{}".format(
            env["platform"], env["target"], env["platform"], env["target"]
        ),
        source=sources,
    )
else:
    library = env.SharedLibrary(
        "project/bin/godot_music_xml_sync{}{}".format(env["suffix"], env["SHLIBSUFFIX"]),
        source=sources,
    )

Default(library)