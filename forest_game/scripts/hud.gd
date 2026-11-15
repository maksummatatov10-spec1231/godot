extends CanvasLayer
## Fixed logical 1280x720 canvas, re-laid out on viewport resize without anchor drift.
var player: CharacterBody3D
var world: Node3D
var status: Label
var focus: ProgressBar
var health: ProgressBar
var notice: Label
var quality: Label
var controls: Label
var tips: Label
var reticle: Label
var last_size := Vector2.ZERO


func text(value: String, point: Vector2, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.position = point
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.015, 0.04, 0.03, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(label)
	return label


func bar(width: float, height: float, color: Color) -> ProgressBar:
	var result := ProgressBar.new()
	result.show_percentage = false
	result.custom_minimum_size = Vector2(width, height)
	result.size = result.custom_minimum_size
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(2)
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.025, 0.06, 0.05, 0.65)
	background.set_corner_radius_all(2)
	result.add_theme_stylebox_override("fill", fill)
	result.add_theme_stylebox_override("background", background)
	add_child(result)
	return result


func setup(actor: CharacterBody3D, scene_world: Node3D) -> void:
	player = actor
	world = scene_world
	var cream := Color("f1e8cb")
	var sage := Color("b8d4bd")
	text("W A R D E N", Vector2(36, 25), 27, cream)
	text("T H E   E M E R A L D   W I L D", Vector2(38, 62), 11, sage)
	text("THE OLD GROVE\nTest your blade on the ancient wards", Vector2(38, 108), 14, cream)
	controls = text(
		"V   FIRST / THIRD PERSON\nQ   ARCANE STRIKE     •     LMB   SWORD", Vector2.ZERO, 12, cream
	)
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	quality = text("ULTRA  /  FORWARD+", Vector2.ZERO, 11, sage)
	quality.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	reticle = text("·", Vector2.ZERO, 32, cream)
	status = text("WARDEN   /   SWORD READY", Vector2.ZERO, 12, cream)
	health = bar(220, 6, Color("bfd59d"))
	health.value = 100
	focus = bar(165, 4, Color("e9c878"))
	tips = text(
		"WASD  MOVE    SHIFT  RUN    SPACE  JUMP    RMB  AIM    ESC  MENU    F6  QUALITY    R  RESET",
		Vector2.ZERO,
		11,
		cream
	)
	tips.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice = text("", Vector2.ZERO, 12, cream)
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	layout()


func layout() -> void:
	last_size = get_viewport().get_visible_rect().size
	var width := last_size.x
	var height := last_size.y
	controls.position = Vector2(width - 390, 29)
	controls.size = Vector2(350, 48)
	quality.position = Vector2(width - 290, 79)
	quality.size = Vector2(250, 20)
	reticle.position = Vector2(width / 2 - 5, height / 2 - 20)
	status.position = Vector2(38, height - 96)
	health.position = Vector2(38, height - 69)
	focus.position = Vector2(38, height - 55)
	tips.position = Vector2(20, height - 25)
	tips.size = Vector2(width - 40, 20)
	notice.position = Vector2(width - 250, height - 85)
	notice.size = Vector2(210, 48)


func _process(_delta: float) -> void:
	if player == null:
		return
	if last_size != get_viewport().get_visible_rect().size:
		layout()
	focus.value = (1.0 - player.magic_cooldown / 2.5) * 100.0
	status.text = (
		"WARDEN   /   " + ("ARCANE STRIKE" if player.magic_cooldown > 1.8 else "SWORD READY")
	)
	quality.text = (["LOW", "HIGH", "ULTRA"][world.profile]) + "  /  FORWARD+"
	if world.menu != null and world.menu.options.fps:
		quality.text += (
			"  |  %d FPS  %.1f ms"
			% [Engine.get_frames_per_second(), 1000.0 / maxf(1.0, Engine.get_frames_per_second())]
		)
	notice.text = (
		("FIRST PERSON" if player.first_person else "THIRD PERSON")
		+ "\n"
		+ ("Q   READY" if player.magic_cooldown <= 0 else "ARCANE RECHARGING")
	)
