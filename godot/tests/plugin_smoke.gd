extends SceneTree
## Headless checks validate registration and compiled shader artifacts, not GPU frames.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if ProjectSettings.get_setting("rendering/renderer/rendering_method") != "forward_plus":
		_fail("Forward+ must be the project renderer")
		return
	if ProjectSettings.get_setting("rendering/rendering_device/fallback_to_opengl3", true):
		_fail("Silent OpenGL fallback would disable compute clouds")
		return
	for class_name_to_check in [
		"Terrain3D", "Terrain3DData", "Terrain3DMaterial", "Terrain3DAssets"
	]:
		if not ClassDB.class_exists(class_name_to_check):
			_fail("Missing native class: " + class_name_to_check)
			return
	var terrain := ClassDB.instantiate("Terrain3D") as Node3D
	if terrain == null:
		_fail("Terrain3D cannot be instantiated")
		return
	terrain.free()
	for script_path in [
		"res://addons/SunshineClouds2/SunshineClouds.gd",
		"res://addons/SunshineClouds2/SunshineCloudsDriver.gd",
		"res://addons/assets2godot/plugin.gd",
	]:
		var script := load(script_path) as GDScript
		if script == null or not script.can_instantiate():
			_fail("Invalid plugin script: " + script_path)
			return
	var shaders := [
		"SunshineCloudsCompute.glsl",
		"SunshineCloudsPreCompute.glsl",
		"SunshineCloudsPostCompute.glsl",
		"SunshineCloudsPostCompute.msaa.glsl",
		"SunshineCloudsDisplay.glsl",
		"SunshineCloudsDisplay.msaa.glsl",
		"Dock/MaskDrawingCompute.glsl",
	]
	for shader_path in shaders:
		var file := load("res://addons/SunshineClouds2/" + shader_path) as RDShaderFile
		if file == null or not file.base_error.is_empty():
			_fail("Shader import failed: " + shader_path)
			return
		var spirv := file.get_spirv()
		var stages := 0
		for stage in range(RenderingDevice.SHADER_STAGE_MAX):
			var error := spirv.get_stage_compile_error(stage)
			if not error.is_empty():
				_fail(shader_path + ": " + error)
				return
			if not spirv.get_stage_bytecode(stage).is_empty():
				stages += 1
		if stages == 0:
			_fail("No SPIR-V generated: " + shader_path)
			return
	print(
		"PLUGIN_SMOKE_OK Terrain3D registered; plugin scripts parsed; 7 shader artifacts compiled"
	)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
