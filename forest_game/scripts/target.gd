extends StaticBody3D
## Re-forming stone sentinels provide visible combat feedback without an AI claim.
var health := 100
var hits := 0
var core: MeshInstance3D
var ring: MeshInstance3D
var base_y := 0.0
var flash := 0.0
var regeneration := 0.0


func _ready() -> void:
	add_to_group("combat_targets")
	collision_layer = 1
	collision_mask = 2
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.48
	shape.height = 2.1
	collision.shape = shape
	collision.position.y = 1.05
	add_child(collision)
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color("526b5c")
	stone.roughness = 0.93
	for i in range(3):
		var part := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.9 - i * 0.13, 0.52, 0.64 - i * 0.08)
		part.mesh = box
		part.material_override = stone
		part.position.y = 0.3 + i * 0.56
		part.rotation.y = i * 0.14
		add_child(part)
	core = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.17
	sphere.height = 0.34
	core.mesh = sphere
	core.position = Vector3(0, 1.36, 0.33)
	var rune := StandardMaterial3D.new()
	rune.albedo_color = Color("57efc3")
	rune.emission_enabled = true
	rune.emission = Color("3eddac")
	rune.emission_energy_multiplier = 2.5
	core.material_override = rune
	add_child(core)
	ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.52
	torus.outer_radius = 0.56
	ring.mesh = torus
	ring.material_override = rune
	ring.position.y = 0.06
	add_child(ring)
	var label := Label3D.new()
	label.name = "Label"
	label.text = "ANCIENT WARD\n100 / 100"
	label.font_size = 26
	label.pixel_size = 0.006
	label.position.y = 2.12
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color("d6e6c6")
	add_child(label)


func _process(delta: float) -> void:
	flash = maxf(0, flash - delta * 3.0)
	core.scale = Vector3.ONE * (1.0 + flash * 0.5)
	ring.rotation.y += delta * 0.4
	if regeneration > 0:
		regeneration -= delta
		if regeneration <= 0:
			health = 100
			visible = true
			collision_layer = 1
			$Label.text = "ANCIENT WARD\n100 / 100"


func take_damage(amount: int, magic: bool) -> void:
	if health <= 0:
		return
	health = maxi(0, health - amount)
	hits += 1
	flash = 1.0
	$Label.text = ("ARCANE HIT" if magic else "SWORD HIT") + "\n" + str(health) + " / 100"
	var tween := create_tween()
	tween.tween_property(self, "rotation:z", 0.10, 0.07)
	tween.tween_property(self, "rotation:z", -0.05, 0.08)
	tween.tween_property(self, "rotation:z", 0.0, 0.12)
	if health == 0:
		regeneration = 4.0
		collision_layer = 0
		$Label.text = "WARD SHATTERED\nReforming..."
