# CityEngine is the only interface the game uses. These tests hold the C++
# engine and its adapter to it: the same enum values, the same signals, every
# method implemented.
extends GutTest

const CPP_CLASS := "MicropolisEngine"


func _cpp_constant(name: String) -> int:
	return ClassDB.class_get_integer_constant(CPP_CLASS, name)


func _assert_enum_matches(enum_dict: Dictionary, prefix: String) -> void:
	for key: String in enum_dict:
		var cpp_name := prefix + key
		assert_true(ClassDB.class_has_integer_constant(CPP_CLASS, cpp_name), "C++ has %s" % cpp_name)
		assert_eq(enum_dict[key], _cpp_constant(cpp_name), "%s matches" % cpp_name)


func test_enums_match_the_cpp_engine() -> void:
	_assert_enum_matches(CityEngine.Tool, "TOOL_")
	_assert_enum_matches(CityEngine.ToolResult, "TOOL_RESULT_")
	_assert_enum_matches(CityEngine.Scenario, "SCENARIO_")
	_assert_enum_matches(CityEngine.HistoryType, "HISTORY_")
	_assert_enum_matches(CityEngine.HistoryScale, "HISTORY_")
	_assert_enum_matches(CityEngine.Overlay, "OVERLAY_")
	_assert_enum_matches(CityEngine.SpriteType, "SPRITE_")
	assert_eq(CityEngine.SpriteType.size(), _cpp_constant("SPRITE_TYPE_COUNT"))
	assert_eq(CityEngine.Tool.size(), _cpp_constant("TOOL_COUNT"))
	assert_eq(CityEngine.Scenario.size(), _cpp_constant("SCENARIO_COUNT"))
	assert_eq(CityEngine.HistoryType.size(), _cpp_constant("HISTORY_TYPE_COUNT"))
	assert_eq(CityEngine.Overlay.size(), _cpp_constant("OVERLAY_COUNT"))
	assert_eq(CityEngine.MAP_WIDTH, _cpp_constant("MAP_WIDTH"))
	assert_eq(CityEngine.MAP_HEIGHT, _cpp_constant("MAP_HEIGHT"))
	assert_eq(CityEngine.TILE_COUNT, _cpp_constant("TILE_COUNT"))


func test_every_signal_exists_on_the_cpp_engine_with_the_same_arguments() -> void:
	var signals := (load("res://engine/city_engine.gd") as Script).get_script_signal_list()
	assert_gt(signals.size(), 0)
	for info: Dictionary in signals:
		var name: StringName = info.name
		assert_true(ClassDB.class_has_signal(CPP_CLASS, name), "C++ emits %s" % name)
		if ClassDB.class_has_signal(CPP_CLASS, name):
			var cpp: Dictionary = ClassDB.class_get_signal(CPP_CLASS, name)
			assert_eq(cpp.args.size(), info.args.size(), "%s argument count" % name)


func test_the_adapter_implements_every_method() -> void:
	# GDScript already refuses to build a class that leaves an @abstract method
	# out; this names the method if it ever does.
	var interface := load("res://engine/city_engine.gd") as Script
	var adapter := load("res://engine/micropolis_city_engine.gd") as Script
	for info: Dictionary in interface.get_script_method_list():
		assert_string_contains(adapter.source_code, "\nfunc %s(" % info.name, false)
	var engine: CityEngine = MicropolisCityEngine.new()
	assert_not_null(engine)
