# Runs before the GUT tests: the game keeps its settings in memory only, so no
# test reads or changes the player's settings.cfg; and it starts on Detroit
# rather than the city chooser, so each test has a city (test_start_and_pace
# covers the chooser at the start).
extends GutHookScript


func run() -> void:
	Settings.default_path = ""
	load("res://main.gd").start_scenario = CityEngine.Scenario.DETROIT
