extends Node3D
## Swept ray hit detection prevents a fast bolt tunnelling through a sentinel.
var direction := Vector3.FORWARD
var player: CharacterBody3D
var life := 0.0
var detonated := false

var effect: Node3D


func _ready() -> void:
	effect = get_parent().effects.acquire("bolt", global_position, 0.42)


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
	effect.global_position = next
	effect.basis = Basis.looking_at(direction) * Basis(Vector3.UP, PI / 2)
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
	get_parent().effects.release(effect)
	get_parent().effects.acquire("area", global_position, 0.6, 2.3)
	queue_free()
