# Headless check that the Micropolis GDExtension loads.
#   godot --headless --path game --script res://tools/check_extension.gd
extends SceneTree


func _init() -> void:
	var path := "res://micropolis.gdextension"
	var loaded := GDExtensionManager.is_extension_loaded(path)
	print("extension %s: %s" % [path, "loaded" if loaded else "NOT LOADED"])
	quit(0 if loaded else 1)
