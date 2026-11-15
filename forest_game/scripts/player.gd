extends CharacterBody3D
## Camera-relative locomotion; real Universal skeletal clips crossfade on one rig.
const FPS_ARMS = preload("res://scripts/fps_arms.gd")
const SWORD = preload("res://assets/weapon/sword_C.gltf")
const PROJECTILE = preload("res://scripts/projectile.gd")
const LEGS = preload("res://assets/hero/warden_legs.gltf")
const TRAIL = preload("res://scripts/blade_trail.gd")

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
var attack_duration := 0.9
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
var invert_y := false
var legs: Node3D
var legs_animator: AnimationPlayer
var body_meshes: Array[MeshInstance3D] = []
var camera_boom := 3.8
var boom_shape := SphereShape3D.new()
var boom_query := PhysicsShapeQueryParameters3D.new()
var camera_motion_enabled := true
var sprinting := false
var arm_skeleton: Skeleton3D
var leg_skeleton: Skeleton3D
var combat_pose: Dictionary
var world_sword: Node3D
var view_sword: Node3D
var arm_modifier: SkeletonModifier3D
var copied_bones_last_frame := 0
var animation_cpu_usec := 0
var trail: MeshInstance3D


func _ready() -> void:
	combat_pose = JSON.parse_string(FileAccess.get_file_as_string("res://combat_pose.json"))
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
	for mesh in hair.find_children("*", "MeshInstance3D", true, false):
		for surface in range(mesh.mesh.get_surface_count()):
			var mat: StandardMaterial3D = mesh.get_active_material(surface).duplicate()
			mat.albedo_color = Color(0.20, 0.11, 0.055)
			mesh.set_surface_override_material(surface, mat)
	animator.playback_default_blend_time = 0.16
	var grip := BoneAttachment3D.new()
	grip.bone_name = "hand_r"
	skeleton.add_child(grip)
	var sword: Node3D = SWORD.instantiate()
	world_sword = sword
	apply_pose(sword, combat_pose.weapon)
	grip.add_child(sword)
	for mesh in visual.find_children("*", "MeshInstance3D", true, false):
		mesh.layers = 1
		body_meshes.append(mesh)
	legs = LEGS.instantiate()
	visual.add_child(legs)
	leg_skeleton = legs.find_children("*", "Skeleton3D", true, false)[0]
	legs_animator = legs.find_children("*", "AnimationPlayer", true, false)[0]
	for clip in ["Idle", "Sword_Idle", "Walk", "Jog_Fwd", "Sprint", "Jump"]:
		legs_animator.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	legs.visible = false
	var waist_cap := MeshInstance3D.new()
	var cap := CylinderMesh.new()
	cap.top_radius = 0.15
	cap.bottom_radius = 0.16
	cap.height = 0.055
	cap.radial_segments = 16
	waist_cap.mesh = cap
	waist_cap.position.y = 0.985
	waist_cap.scale.z = 0.7
	var belt := StandardMaterial3D.new()
	belt.albedo_color = Color("273239")
	waist_cap.material_override = belt
	legs.add_child(waist_cap)
	for mesh in legs.find_children("*", "MeshInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	trail = MeshInstance3D.new()
	trail.set_script(TRAIL)
	get_parent().add_child(trail)
	camera = Camera3D.new()
	camera.name = "ShoulderAndEyesCamera"
	camera.near = 0.055
	camera.far = 150.0
	camera.fov = 72
	camera.cull_mask = 1
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	get_parent().add_child(camera)
	camera.current = true
	boom_shape.radius = 0.22
	boom_query.shape = boom_shape
	boom_query.collision_mask = 1
	boom_query.exclude = [get_rid()]
	create_viewmodel()
	for animation_player in [animator, view_animator, legs_animator]:
		animation_player.callback_mode_process = (
			AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		)
	# Auxiliary rigs are pose consumers, never independent clip evaluators.
	view_animator.active = false
	legs_animator.active = false
	set_first_person(false)
	play_clip("Sword_Idle")


func apply_pose(node: Node3D, pose: Dictionary) -> void:
	node.position = Vector3(pose.position[0], pose.position[1], pose.position[2])
	node.rotation_degrees = Vector3(
		pose.rotation_degrees[0], pose.rotation_degrees[1], pose.rotation_degrees[2]
	)
	node.scale = Vector3.ONE * float(pose.scale)


func advance_animation(delta: float) -> void:
	var started := Time.get_ticks_usec()
	animator.advance(delta)
	copied_bones_last_frame = 0
	if first_person:
		sync_first_person_pose()
	animation_cpu_usec = Time.get_ticks_usec() - started


func sync_first_person_pose() -> void:
	# One evaluation, two consumers; also reset unkeyed channels before IK.
	for bone in range(skeleton.get_bone_count()):
		var pose := skeleton.get_bone_pose(bone)
		arm_skeleton.set_bone_pose(bone, pose)
		leg_skeleton.set_bone_pose(bone, pose)
	copied_bones_last_frame = skeleton.get_bone_count() * 2


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
	apply_pose(viewmodel, combat_pose.first_person)
	view_animator = viewmodel.find_children("*", "AnimationPlayer", true, false)[0]
	for clip in ["Idle", "Sword_Idle", "Walk", "Jog_Fwd", "Sprint", "Jump"]:
		view_animator.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	arm_skeleton = viewmodel.find_children("*", "Skeleton3D", true, false)[0]
	var correction := SkeletonModifier3D.new()
	arm_modifier = correction
	correction.set_script(FPS_ARMS)
	correction.controller = self
	arm_skeleton.add_child(correction)
	var grip := BoneAttachment3D.new()
	grip.bone_name = "hand_r"
	arm_skeleton.add_child(grip)
	var sword: Node3D = SWORD.instantiate()
	view_sword = sword
	apply_pose(sword, combat_pose.weapon)
	grip.add_child(sword)
	for mesh in viewmodel.find_children("*", "MeshInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	viewmodel.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw = wrapf(yaw - event.screen_relative.x * mouse_sensitivity, -PI, PI)
		pitch = clampf(
			pitch - event.screen_relative.y * mouse_sensitivity * (-1 if invert_y else 1),
			-1.35,
			1.15
		)
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
	sprinting = (
		Input.is_action_pressed("sprint")
		and not Input.is_action_pressed("aim")
		and action_timer <= 0.0
	)
	var speed := 5.7 if sprinting else 3.15
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
		reset_physics_interpolation()
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


func _process(delta: float) -> void:
	advance_animation(delta)
	if camera_motion_enabled:
		update_camera(delta, Vector2(velocity.x, velocity.z).length())


func update_camera(delta: float, moving: float) -> void:
	camera.rotation = Vector3(pitch, yaw, 0)
	var pivot := get_global_transform_interpolated().origin + Vector3(0, 1.55, 0)
	var offset := (
		Vector3(0.5, 0.25, camera_distance) if not first_person else Vector3(0, 0.10, -0.02)
	)
	var desired := pivot + camera.basis * offset
	if not first_person and is_inside_tree():
		# Sphere sweep protects the entire near plane, not just its centre ray.
		boom_query.transform = Transform3D(Basis.IDENTITY, pivot)
		boom_query.motion = desired - pivot
		var fractions := get_world_3d().direct_space_state.cast_motion(boom_query)
		var safe_length := offset.length() * fractions[0]
		if not camera_initialized or safe_length < camera_boom:
			camera_boom = safe_length
		else:
			camera_boom = lerpf(camera_boom, safe_length, 1.0 - exp(-8.0 * delta))
		desired = pivot + (desired - pivot).normalized() * camera_boom
	# Orbit is centred on the interpolated pivot; never lerp world camera position
	# behind mouse rotation (that caused the old rubber-band orbit and jerk).
	camera.global_position = desired
	camera_initialized = true
	camera.fov = lerpf(
		camera.fov, 78.0 if moving > 4.0 else (68.0 if aim else 72.0), 1.0 - exp(-6.0 * delta)
	)


func set_first_person(value: bool) -> void:
	first_person = value
	camera.cull_mask = 1
	viewmodel.visible = value
	legs.visible = value
	arm_modifier.active = value
	viewmodel.process_mode = Node.PROCESS_MODE_INHERIT if value else Node.PROCESS_MODE_DISABLED
	legs.process_mode = Node.PROCESS_MODE_INHERIT if value else Node.PROCESS_MODE_DISABLED
	if value:
		sync_first_person_pose()
	for mesh in body_meshes:
		mesh.cast_shadow = (
			GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
			if value
			else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		)
	camera_initialized = false


func play_clip(clip: String) -> void:
	if current_clip == clip:
		return
	if not animator.has_animation(clip):
		push_error("Missing required skeletal animation: " + clip)
		return
	current_clip = clip
	animator.speed_scale = 1.0
	animator.play(clip, 0.14)


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
	attack_duration = action_timer
	attacking = true
	visual.rotation.y = yaw + PI
	play_clip(clip)
	animator.speed_scale = animator.get_animation(clip).length / action_timer
	get_tree().create_timer(0.22, false).timeout.connect(
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
	trail.strike(global_position + Vector3.UP * 1.15, yaw, combo % 2 == 0)


func cast_magic() -> void:
	if magic_cooldown > 0.0 or action_timer > 0.15:
		return
	sounds["arcane"].play()
	magic_cooldown = 2.5
	action_timer = 0.85
	visual.rotation.y = yaw + PI
	play_clip("Spell_Simple_Shoot")
	get_parent().effects.acquire(
		"cast", global_position + Vector3(0, 1.35, 0) - Basis(Vector3.UP, yaw).z * 0.6, 0.42, 1.2
	)
	get_tree().create_timer(0.22, false).timeout.connect(launch_magic)


func launch_magic() -> void:
	var bolt := Node3D.new()
	bolt.set_script(PROJECTILE)
	bolt.direction = -Basis(Vector3.UP, yaw).z
	bolt.direction.y = sin(pitch) * 0.35
	bolt.direction = bolt.direction.normalized()
	bolt.player = self
	bolt.position = global_position + Vector3(0, 1.25, 0) + bolt.direction * 0.8
	get_parent().add_child(bolt)
