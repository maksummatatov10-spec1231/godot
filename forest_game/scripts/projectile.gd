extends Node3D
## Swept ray hit detection prevents a fast bolt tunnelling through a sentinel.
var direction := Vector3.FORWARD
var player: CharacterBody3D
var life := 0.0
var detonated := false


func _ready() -> void:
	var effect := (
		(
			load(
				"res://assets/BinbunVFX_Vol2/ElementalMagicFX/effects/projectile/vfx_fire_projectile_01.tscn"
			)
			. instantiate()
		)
		as Node3D
	)
	add_child(effect)
	effect.scale = Vector3.ONE * 0.42
	effect.call("open")
	var light := OmniLight3D.new()
	light.light_color = Color("ffb441")
	light.light_energy = 2.5
	light.omni_range = 5.0
	add_child(light)


func _physics_process(delta: float) -> void:
	if detonated:
		return
	life += delta
	var next := global_position + direction * 18.0 * delta
	var query := PhysicsRayQueryParameters3D.create(global_position, next, 1, [player.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		global_position = hit.position
		detonate()
		return
	global_position = next
	if life > 2.6:
		detonate()


func detonate() -> void:
	if detonated:
		return
	detonated = true
	for target in get_tree().get_nodes_in_group("combat_targets"):
		if target.global_position.distance_to(global_position - Vector3.UP) < 3.0:
			target.take_damage(70, true)
			player.magic_hits += 1
	var effect := (
		(
			load("res://assets/BinbunVFX_Vol2/ElementalMagicFX/effects/area/vfx_fire_area_01.tscn")
			. instantiate()
		)
		as Node3D
	)
	get_parent().add_child(effect)
	effect.global_position = global_position
	effect.scale = Vector3.ONE * 0.6
	effect.call("open")
	get_tree().create_timer(2.3).timeout.connect(effect.queue_free)
	queue_free()
