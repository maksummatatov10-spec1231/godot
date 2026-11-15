extends MeshInstance3D
## A volumetric tapered curved tube, never a camera-facing slash sprite/flat disk.
var lifetime := 0.0


func _ready() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(28):
		for side in range(6):
			for corner in [
				Vector2i(0, 0),
				Vector2i(1, 0),
				Vector2i(0, 1),
				Vector2i(1, 0),
				Vector2i(1, 1),
				Vector2i(0, 1)
			]:
				var t := float(i + corner.x) / 28.0
				var angle := lerpf(-1.1, 1.1, t)
				var ring := float(side + corner.y) / 6.0 * TAU
				var width := 0.028 * sin(t * PI) + 0.001
				var radial := Vector3(sin(angle), 0, -cos(angle))
				surface.add_vertex(
					radial * (1.05 + cos(ring) * width) + Vector3.UP * sin(ring) * width
				)
	surface.generate_normals()
	mesh = surface.commit()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("b4d8c4")
	material.emission_enabled = true
	material.emission = Color("7ea598")
	material.emission_energy_multiplier = 0.6
	material_override = material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = false


func strike(at: Vector3, yaw: float, alternate: bool) -> void:
	global_position = at
	rotation = Vector3(0, yaw, -0.5 if alternate else 0.65)
	lifetime = 0.13
	visible = true


func _process(delta: float) -> void:
	lifetime = maxf(0.0, lifetime - delta)
	visible = lifetime > 0
