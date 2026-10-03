// GDExtension entry points for the Micropolis engine wrapper.
//
// Part of Metrobits, which is GPLv3 with Electronic Arts' additional terms
// (see LICENSE and micropolis-core/MicropolisGPLLicenseNotice.md).

#pragma once

#include <godot_cpp/core/class_db.hpp>

void initialize_micropolis_module(godot::ModuleInitializationLevel p_level);
void uninitialize_micropolis_module(godot::ModuleInitializationLevel p_level);
