extends SkeletonModifier3D
## Retarget the REAL clip wrists into reachable camera space. Preserve their
## animated rotation and every finger channel; solve elbows with two-bone IK.
var controller: CharacterBody3D
var arm_bones: Array[PackedInt32Array] = []


func _ready() -> void:
	var skeleton := get_skeleton()
	for side in ["r", "l"]:
		arm_bones.append(
			PackedInt32Array(
				[
					skeleton.find_bone("upperarm_" + side),
					skeleton.find_bone("lowerarm_" + side),
					skeleton.find_bone("hand_" + side)
				]
			)
		)


func _process_modification() -> void:
	if controller == null or not controller.first_person:
		return
	var skeleton := get_skeleton()
	var to_camera: Transform3D = (
		controller.camera.global_transform.affine_inverse() * skeleton.global_transform
	)
	var to_model := to_camera.affine_inverse()
	for index in range(arm_bones.size()):
		var side: String = "r" if index == 0 else "l"
		var upper: int = arm_bones[index][0]
		var lower: int = arm_bones[index][1]
		var wrist: int = arm_bones[index][2]
		var source_upper := skeleton.get_bone_global_pose(upper)
		var source_lower := skeleton.get_bone_global_pose(lower)
		var source_wrist := skeleton.get_bone_global_pose(wrist)
		var shoulder := Vector3(0.32 if side == "r" else -0.32, -0.60, 0.10)
		var target: Vector3 = to_camera * source_wrist.origin
		var reach := target - shoulder
		var distance := clampf(reach.length(), 0.1, 0.76)
		var direction := reach.normalized()
		target = shoulder + direction * distance
		# Fixed anatomical lengths, no disconnected forearms or stretched spaghetti.
		var upper_length := 0.39
		var lower_length := 0.39
		var along := (
			(upper_length * upper_length - lower_length * lower_length + distance * distance)
			/ (2 * distance)
		)
		var height := sqrt(maxf(0.0, upper_length * upper_length - along * along))
		var pole := Vector3(0.6 if side == "r" else -0.6, -1.0, -0.1)
		var bend := (pole - shoulder) - direction * (pole - shoulder).dot(direction)
		var elbow := shoulder + direction * along + bend.normalized() * height
		var new_upper: Vector3 = to_model * shoulder
		var new_lower: Vector3 = to_model * elbow
		var new_wrist: Vector3 = to_model * target
		set_segment(skeleton, upper, source_upper, source_lower.origin, new_upper, new_lower)
		set_segment(skeleton, lower, source_lower, source_wrist.origin, new_lower, new_wrist)
		# No Euler/sin replacement: A/B/C retain different blade orientations.
		skeleton.set_bone_global_pose(wrist, Transform3D(source_wrist.basis, new_wrist))


func set_segment(
	skeleton: Skeleton3D,
	bone: int,
	source: Transform3D,
	end: Vector3,
	start: Vector3,
	finish: Vector3
) -> void:
	var before := end - source.origin
	var after := finish - start
	var turn := Basis(Quaternion(before.normalized(), after.normalized()))
	# Axial stretch only: preserve sleeve width when fitting the camera anatomy.
	var axis := before.normalized()
	var amount := after.length() / maxf(0.001, before.length()) - 1.0
	var stretch := Basis.IDENTITY
	stretch.x += axis * axis.x * amount
	stretch.y += axis * axis.y * amount
	stretch.z += axis * axis.z * amount
	skeleton.set_bone_global_pose(bone, Transform3D(turn * stretch * source.basis, start))
