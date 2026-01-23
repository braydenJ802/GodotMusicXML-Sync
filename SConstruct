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