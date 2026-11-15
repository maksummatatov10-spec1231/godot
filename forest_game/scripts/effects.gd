extends Node3D
## Fixed-size reusable VFX pool. Resources and pipelines are prepared before play.
const CAST = preload(
	"res://assets/BinbunVFX_Vol2/ElementalMagicFX/effects/cast/vfx_fire_cast_01.tscn"
)
const BOLT = preload(
	"res://assets/BinbunVFX_Vol2/ElementalMagicFX/effects/projectile/vfx_fire_projectile_01.tscn"
)
const AREA = preload(
	"res://assets/BinbunVFX_Vol2/ElementalMagicFX/effects/area/vfx_fire_area_01.tscn"
)
var pools: Dictionary = {}
var serial := 0
var warmed := false


func _ready() -> void:
	for key in ["cast", "bolt", "area"]:
		pools[key] = []
		var scene: PackedScene = {"cast": CAST, "bolt": BOLT, "area": AREA}[key]
		for i in range(3):
			var effect := scene.instantiate() as Node3D
			add_child(effect)
			if key == "cast":
				effect.set("one_shot", true)
			for geometry in effect.find_children("*", "GeometryInstance3D", true, false):
				geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			for light in effect.find_children("*", "Light3D", true, false):
				light.shadow_enabled = false
			for particles in effect.find_children("*", "GPUParticles3D", true, false):
				particles.amount = mini(particles.amount, 32)
				particles.emitting = false
			effect.visible = false
			pools[key].append(effect)


func acquire(key: String, at: Vector3, size: float, duration := 0.0) -> Node3D:
	var list: Array = pools[key]
	var effect: Node3D = list.pop_front()
	list.append(effect)
	serial += 1
	effect.set_meta("lease", serial)
	effect.global_position = at
	effect.scale = Vector3.ONE * size
	effect.visible = true
	effect.call("play" if key == "cast" else "open")
	for particles in effect.find_children("*", "GPUParticles3D", true, false):
		particles.restart()
		particles.emitting = true
	if duration > 0:
		var lease := serial
		get_tree().create_timer(duration, false).timeout.connect(
			func():
				if is_instance_valid(effect) and effect.get_meta("lease") == lease:
					release(effect)
		)
	return effect


func release(effect: Node3D) -> void:
	effect.visible = false
	for particles in effect.find_children("*", "GPUParticles3D", true, false):
		particles.emitting = false
	for animation in effect.find_children("*", "AnimationPlayer", true, false):
		animation.stop()


func warm_up(camera: Camera3D) -> void:
	# Draw the EXACT live instances, including particle/light paths, behind loading UI.
	for key in pools:
		for effect in pools[key]:
			acquire(key, camera.global_position - camera.global_basis.z * 4, 0.3)
	for i in range(12):
		await get_tree().process_frame
	for key in pools:
		for effect in pools[key]:
			release(effect)
	warmed = true
