extends SkeletonModifier3D
## First-person pose correction AFTER the shared clips: real skin, fingers and grip.
## Full-body idle elbows sit behind the eyes; this keeps them below the lens.
var controller: CharacterBody3D


func _process_modification() -> void:
	if controller == null:
		return
	var skeleton := get_skeleton()
	var swing := 0.0
	if controller.attacking:
		var phase: float = 1.0 - controller.action_timer / controller.attack_duration
		swing = sin(clampf(phase, 0.0, 1.0) * PI)
	var spell := 0.0
	if controller.magic_cooldown > 1.65:
		spell = sin((2.5 - controller.magic_cooldown) / 0.85 * PI)
	pose_arm(
		skeleton,
		"r",
		Vector3(0.57, -0.85, -0.05),
		Vector3(0.42, -0.52, -0.37),
		Vector3(0.28 - swing * 0.66, -0.34 + swing * 0.22, -0.64),
		Basis(Vector3.FORWARD, -swing * 1.5) * Basis(Vector3.UP, Vector3.FORWARD, Vector3.LEFT)
	)
	pose_arm(
		skeleton,
		"l",
		Vector3(-0.57, -0.85, -0.05),
		Vector3(-0.43, -0.57, -0.25),
		Vector3(-0.26, -0.38 + spell * 0.16, -0.52 - spell * 0.17),
		Basis(Vector3.DOWN, Vector3.FORWARD, Vector3.RIGHT)
	)


func pose_arm(
	skeleton: Skeleton3D,
	side: String,
	shoulder: Vector3,
	elbow: Vector3,
	hand: Vector3,
	hand_basis: Basis
) -> void:
	var upper := skeleton.find_bone("upperarm_" + side)
	var lower := skeleton.find_bone("lowerarm_" + side)
	var wrist := skeleton.find_bone("hand_" + side)
	var upper_rest := skeleton.get_bone_global_rest(upper)
	var lower_rest := skeleton.get_bone_global_rest(lower)
	var hand_rest := skeleton.get_bone_global_rest(wrist)
	var upper_turn := Quaternion(
		(lower_rest.origin - upper_rest.origin).normalized(), (elbow - shoulder).normalized()
	)
	var lower_turn := Quaternion(
		(hand_rest.origin - lower_rest.origin).normalized(), (hand - elbow).normalized()
	)
	skeleton.set_bone_global_pose(
		upper, Transform3D(Basis(upper_turn) * upper_rest.basis, shoulder)
	)
	skeleton.set_bone_global_pose(lower, Transform3D(Basis(lower_turn) * lower_rest.basis, elbow))
	skeleton.set_bone_global_pose(wrist, Transform3D(hand_basis, hand))
