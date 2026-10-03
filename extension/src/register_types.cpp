// GDExtension entry points for the Micropolis engine wrapper.
//
// Part of Metrobits, which is GPLv3 with Electronic Arts' additional terms
// (see LICENSE and micropolis-core/MicropolisGPLLicenseNotice.md).

#include "register_types.h"

#include "micropolis_engine.h"

#include <gdextension_interface.h>

#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>

#ifdef _WIN32
#include <clocale>
#endif

using namespace godot;

void initialize_micropolis_module(ModuleInitializationLevel p_level) {
    if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
        return;
    }
#ifdef _WIN32
    // Godot hands us paths as UTF-8, and the engine opens files with fopen.
    // Windows' C runtime reads those names in the old ANSI code page unless
    // its character set is UTF-8, so a city in a folder with letters beyond
    // English's, like a user folder under an accented name, wouldn't open.
    // The extension has its own copy of the runtime, so this changes nothing
    // for Godot.
    setlocale(LC_CTYPE, ".UTF-8");
#endif
    GDREGISTER_CLASS(MicropolisEngine);
}

void uninitialize_micropolis_module(ModuleInitializationLevel p_level) {
    if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
        return;
    }
}

extern "C" {
GDExtensionBool GDE_EXPORT micropolis_library_init(GDExtensionInterfaceGetProcAddress p_get_proc_address,
                                                   GDExtensionClassLibraryPtr p_library,
                                                   GDExtensionInitialization *r_initialization) {
    GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library, r_initialization);
    init_obj.register_initializer(initialize_micropolis_module);
    init_obj.register_terminator(uninitialize_micropolis_module);
    init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
    return init_obj.init();
}
}
