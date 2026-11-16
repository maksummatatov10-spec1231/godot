extends SceneTree


## Importing res:// does not parse external tools. Validate every capture driver early.
func _initialize() -> void:
	var directory := ProjectSettings.globalize_path("res://").path_join("../tools").simplify_path()
	for driver in ["lantern_audit.gd", "lantern_motion.gd", "lantern_beauty.gd"]:
		var script: Script = load(directory.path_join(driver))
		if script == null or not script.can_instantiate():
			printerr("LANTERN_DRIVER_PARSE_FAIL ", driver)
			quit(1)
			return
	print("LANTERN_DRIVER_PARSE_OK")
	quit()
