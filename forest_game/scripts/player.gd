extends CharacterBody3D
## Camera-relative locomotion; real Universal skeletal clips crossfade on one rig.

const SWORD = preload("res://assets/weapon/sword_C.gltf")
const PROJECTILE = preload("res://scripts/projectile.gd")
var visual: Node3D
var skeleton: Skeleton3D
var animator: AnimationPlayer
var view_animator: AnimationPlayer
var camera: Camera3D
var viewmodel: Node3D
var hud: CanvasLayer
var yaw := 0.0
var pitch := -0.09
var first_person := false
var action_timer := 0.0
var magic_cooldown := 0.0
var combo := 0
var attack_serial := 0
var damage_events := 0
var magic_hits := 0
var current_clip := ""
var elapsed := 0.0
var mouse_sensitivity := 0.0022
var camera_distance := 3.8
var camera_initialized := false
var aim := false
var step_clock := 0.0
var attacking := false
var input_enabled := true
var jump_phase := 0.0
var landing_phase := 0.0
var queued_attack := false
var sounds: Dictionary = {}


func _ready() -> void:
	configure_input()
	for sound_name in ["footstep", "sword", "arcane"]:
		var sound := AudioStreamPlayer.new()
		sound.stream = load("res://audio/" + sound_name + ".ogg")
		sound.volume_db = -14.0 if sound_name != "footstep" else -18.0
		add_child(sound)
		sounds[sound_name] = sound
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(48)
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = 1.76
	var collider := CollisionShape3D.new()
	collider.shape = capsule
	collider.position.y = 0.9
	add_child(collider)
	visual = load("res://assets/hero/warden.gltf").instantiate()
	visual.rotation.y = PI
	add_child(visual)
	skeleton = visual.find_children("*", "Skeleton3D", true, false)[0]
	animator = visual.find_children("*", "AnimationPlayer", true, false)[0]
	for clip in ["Idle", "Sword_Idle", "Walk", "Jog_Fwd", "Sprint", "Jump"]:
		if animator.has_animation(clip):
			animator.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	var hair_grip := BoneAttachment3D.new()
	hair_grip.bone_name = "Head"
	skeleton.add_child(hair_grip)
	var hair: Node3D = load("res://assets/hero/Hair_SimpleParted.gltf").instantiate()
	hair_grip.add_child(hair)
	hair.transform = skeleton.get_bone_global_rest(skeleton.find_bone("Head")).affine_inverse()
	animator.playback_default_blend_time = 0.16
	var grip := BoneAttachment3D.new()
	grip.bone_name = "hand_r"
	skeleton.add_child(grip)
	var sword: Node3D = SWORD.instantiate()
	sword.scale = Vector3.ONE * 0.52
	sword.rotation_degrees.z = -90
	sword.position = Vector3(0.02, 0.08, 0.02)
	grip.add_child(sword)
	# Body and bone-attached sword are hidden from the first-person lens only.
	for mesh in visual.find_children("*", "MeshInstance3D", true, false):
		mesh.layers = 2
	camera = Camera3D.new()
	camera.name = "ShoulderAndEyesCamera"
	camera.near = 0.055
	camera.far = 150.0
	camera.fov = 72
	camera.cull_mask = 3
	get_parent().add_child(camera)
	camera.current = true
	create_viewmodel()
	play_clip("Sword_Idle")


func configure_input() -> void:
	var bindings := {
		"forward": KEY_W,
		"back": KEY_S,
		"left": KEY_A,
		"right": KEY_D,
		"jump": KEY_SPACE,
		"sprint": KEY_SHIFT,
		"view": KEY_V,
		"magic": KEY_Q,
		"quality": KEY_F6,
		"reset": KEY_R
	}
	for action in bindings:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var key := InputEventKey.new()
		key.physical_keycode = bindings[action]
		InputMap.action_add_event(action, key)
	for binding in [["attack", MOUSE_BUTTON_LEFT], ["aim", MOUSE_BUTTON_RIGHT]]:
		if not InputMap.has_action(binding[0]):
			InputMap.add_action(binding[0])
			var button := InputEventMouseButton.new()
			button.button_index = binding[1]
			InputMap.action_add_event(binding[0], button)


func create_viewmodel() -> void:
	# Actual skin-weighted character arms, not primitive mitten placeholders.
	viewmodel = load("res://assets/hero/warden_arms.gltf").instantiate()
	viewmodel.name = "FirstPersonSkinnedArms"
	camera.add_child(viewmodel)
	viewmodel.position = Vector3(0, -1.1, -0.1)
	viewmodel.rotation.y = PI
	view_animator = viewmodel.find_children("*", "AnimationPlayer", true, false)[0]
	for clip in ["Idle", "Sword_Idle", "Walk", "Jog_Fwd", "Sprint", "Jump"]:
		view_animator.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	var arm_skeleton: Skeleton3D = viewmodel.find_children("*", "Skeleton3D", true, false)[0]
	var grip := BoneAttachment3D.new()
	grip.bone_name = "hand_r"
	arm_skeleton.add_child(grip)
	var sword: Node3D = SWORD.instantiate()
	sword.scale = Vector3.ONE * 0.48
	sword.rotation_degrees.z = -90
	sword.position = Vector3(0.02, 0.08, 0.02)
	grip.add_child(sword)
	viewmodel.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * mouse_sensitivity
		pitch = clampf(pitch - event.relative.y * mouse_sensitivity, -1.1, 0.8)
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = (
			Input.MOUSE_MODE_VISIBLE
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
			else Input.MOUSE_MODE_CAPTURED
		)
	if (
		event is InputEventMouseButton
		and event.pressed
		and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED
	):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event.is_action_pressed("view"):
		set_first_person(not first_person)
	if event.is_action_pressed("attack"):
		attack()
	if event.is_action_pressed("magic"):
		cast_magic()
	if event.is_action_pressed("quality"):
		get_parent().toggle_quality()
	if event.is_action_pressed("reset"):
		get_tree().reload_current_scene()


func _physics_process(delta: float) -> void:
	elapsed += delta
	jump_phase = maxf(0.0, jump_phase - delta)
	landing_phase = maxf(0.0, landing_phase - delta)
	var was_grounded := is_on_floor()
	magic_cooldown = maxf(0.0, magic_cooldown - delta)
	action_timer = maxf(0.0, action_timer - delta)
	if action_timer == 0.0:
		attacking = false
		if queued_attack:
			queued_attack = false
			attack()
	aim = first_person or Input.is_action_pressed("aim") or action_timer > 0.0
	var input := (
		Input.get_vector("left", "right", "forward", "back") if input_enabled else Vector2.ZERO
	)
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not get_parent().capture_mode:
		input = Vector2.ZERO
	var direction := Basis(Vector3.UP, yaw) * Vector3(input.x, 0, input.y)
	var speed := 5.7 if Input.is_action_pressed("sprint") and not aim else 3.15
	if action_timer > 0.0:
		speed *= 0.32
	velocity.x = move_toward(velocity.x, direction.x * speed, 16.0 * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, 16.0 * delta)
	if not is_on_floor():
		velocity.y -= 19.0 * delta
	elif Input.is_action_just_pressed("jump") and action_timer <= 0.0:
		jump_phase = 0.18
		velocity.y = 6.6
		play_clip("Jump_Start")
	move_and_slide()
	if is_on_floor() and not was_grounded:
		landing_phase = 0.18
	if position.y < -12.0 or Vector2(position.x, position.z).length() > 74.0:
		position = Vector3(0, 2, 7)
		velocity = Vector3.ZERO
	var moving := Vector2(velocity.x, velocity.z).length()
	step_clock -= delta
	if is_on_floor() and moving > 0.5 and step_clock <= 0:
		sounds["footstep"].play()
		step_clock = 0.29 if moving > 4.0 else 0.43
	if aim:
		visual.rotation.y = lerp_angle(visual.rotation.y, yaw + PI, 1.0 - exp(-18.0 * delta))
	elif direction.length_squared() > 0.05:
		visual.rotation.y = lerp_angle(
			visual.rotation.y, atan2(direction.x, direction.z), 1.0 - exp(-13.0 * delta)
		)
	if action_timer <= 0.0:
		if not is_on_floor():
			play_clip("Jump_Start" if jump_phase > 0.0 else "Jump")
		elif landing_phase > 0.0:
			play_clip("Jump_Land")
		elif moving > 0.15:
			play_clip("Sprint" if speed > 5.0 else "Walk")
			animator.speed_scale = clampf(moving / (5.7 if speed > 5.0 else 2.0), 0.65, 1.6)
			if aim and input.y > 0.1:
				animator.speed_scale *= -1.0
		else:
			play_clip("Sword_Idle")
			animator.speed_scale = 1.0
	update_camera(delta, moving)


func update_camera(delta: float, moving: float) -> void:
	camera.rotation = Vector3(pitch, yaw, 0)
	var pivot := global_position + Vector3(0, 1.55, 0)
	var offset := (
		Vector3(0.5, 0.25, camera_distance) if not first_person else Vector3(0, 0.10, -0.02)
	)
	var desired := pivot + camera.basis * offset
	if not first_person and is_inside_tree():
		var query := PhysicsRayQueryParameters3D.create(pivot, desired, 1, [get_rid()])
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			desired = hit.position + hit.normal * 0.23
	if not camera_initialized:
		camera.global_position = desired
		camera_initialized = true
	else:
		camera.global_position = camera.global_position.lerp(desired, 1.0 - exp(-20.0 * delta))
	camera.fov = lerpf(
		camera.fov, 78.0 if moving > 4.0 else (68.0 if aim else 72.0), 1.0 - exp(-6.0 * delta)
	)
	viewmodel.position = (
		Vector3(0, -1.1, -0.1)
		+ Vector3(sin(elapsed * 9.0) * moving * 0.002, abs(cos(elapsed * 9.0)) * moving * 0.003, 0)
	)
	viewmodel.rotation = Vector3(0, PI, 0)
	view_animator.speed_scale = animator.speed_scale


func set_first_person(value: bool) -> void:
	first_person = value
	camera.cull_mask = 1 if value else 3
	viewmodel.visible = value


func play_clip(clip: String) -> void:
	if current_clip == clip:
		return
	if not animator.has_animation(clip):
		push_error("Missing required skeletal animation: " + clip)
		return
	current_clip = clip
	animator.speed_scale = 1.0
	animator.play(clip, 0.14)
	if view_animator != null:
		view_animator.play(clip, 0.14)


func attack() -> void:
	if action_timer > 0.12:
		if attacking and action_timer < 0.5:
			queued_attack = true
		return
	sounds["sword"].play()
	attack_serial += 1
	var serial := attack_serial
	var clip: String = ["Sword_Regular_A", "Sword_Regular_B", "Sword_Regular_C"][combo % 3]
	combo += 1
	action_timer = minf(animator.get_animation(clip).length, 0.9)
	attacking = true
	visual.rotation.y = yaw + PI
	play_clip(clip)
	animator.speed_scale = animator.get_animation(clip).length / action_timer
	get_tree().create_timer(0.22).timeout.connect(
		func():
			if serial == attack_serial:
				melee_contact()
	)


func melee_contact() -> void:
	var forward := -Basis(Vector3.UP, yaw).z
	for target in get_tree().get_nodes_in_group("combat_targets"):
		var offset: Vector3 = target.global_position - global_position
		offset.y = 0
		if offset.length() < 2.35 and forward.dot(offset.normalized()) > 0.35:
			target.take_damage(34, false)
			damage_events += 1
	var fx := (
		(
			load("res://assets/BinbunVFX_Vol2/BattleFX/effects/slash/vfx_blank_slash.tscn")
			. instantiate()
		)
		as Node3D
	)
	get_parent().add_child(fx)
	fx.add_to_group("transient_slash")
	fx.global_position = global_position + forward * 1.1 + Vector3.UP
	fx.rotation.y = yaw
	fx.scale = Vector3.ONE * 0.65
	fx.call("open")
	get_tree().create_timer(1.6).timeout.connect(fx.queue_free)


func cast_magic() -> void:
	if magic_cooldown > 0.0 or action_timer > 0.15:
		return
	sounds["arcane"].play()
	magic_cooldown = 2.5
	action_timer = 0.85
	visual.rotation.y = yaw + PI
	play_clip("Spell_Simple_Shoot")
	var cast: Node3D = (
		load("res://assets/BinbunVFX_Vol2/ElementalMagicFX/effects/cast/vfx_fire_cast_01.tscn")
		. instantiate()
	)
	get_parent().add_child(cast)
	cast.global_position = global_position + Vector3(0, 1.35, 0) - Basis(Vector3.UP, yaw).z * 0.6
	cast.scale = Vector3.ONE * 0.42
	cast.set("one_shot", true)
	cast.call("play")
	get_tree().create_timer(1.2).timeout.connect(cast.queue_free)
	get_tree().create_timer(0.22).timeout.connect(launch_magic)


func launch_magic() -> void:
	var bolt := Node3D.new()
	bolt.set_script(PROJECTILE)
	bolt.direction = -Basis(Vector3.UP, yaw).z
	bolt.direction.y = sin(pitch) * 0.35
	bolt.direction = bolt.direction.normalized()
	bolt.player = self
	get_parent().add_child(bolt)
	bolt.global_position = global_position + Vector3(0, 1.25, 0) + bolt.direction * 0.8
