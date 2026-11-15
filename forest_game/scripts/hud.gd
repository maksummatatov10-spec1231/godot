extends CanvasLayer
## Resolution-independent, restrained game HUD; no external font dependency.
var player: CharacterBody3D
var world: Node3D
var status: Label
var focus: ProgressBar
var notice: Label
var quality: Label


func text(value: String, position_: Vector2, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.position = position_
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.015, 0.04, 0.03, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(label)
	return label


func setup(player_: CharacterBody3D, world_: Node3D) -> void:
	player = player_
	world = world_
	var cream := Color("f1e8cb")
	var sage := Color("b8d4bd")
	text("W A R D E N", Vector2(36, 25), 27, cream)
	text("T H E   E M E R A L D   W I L D", Vector2(38, 62), 11, sage)
	var objective := text(
		"THE OLD GROVE\nTest your blade on the ancient wards", Vector2(38, 108), 15, cream
	)
	objective.add_theme_constant_override("line_spacing", 5)
	var controls := text(
		"V   FIRST / THIRD PERSON\nQ   ARCANE STRIKE     •     LMB   SWORD",
		Vector2(-380, 29),
		13,
		cream
	)
	controls.anchor_left = 1
	controls.anchor_right = 1
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	quality = text("ULTRA  /  FORWARD+", Vector2(-260, 79), 11, sage)
	quality.anchor_left = 1
	quality.anchor_right = 1
	var reticle := text("·", Vector2(-5, -20), 32, cream)
	reticle.anchor_left = 0.5
	reticle.anchor_top = 0.5
	status = text("WARDEN   /   SWORD READY", Vector2(38, -106), 13, cream)
	status.anchor_top = 1
	var health := ProgressBar.new()
	health.position = Vector2(38, -76)
	health.anchor_top = 1
	health.size = Vector2(220, 5)
	health.show_percentage = false
	health.value = 100
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("bfd59d")
	health.add_theme_stylebox_override("fill", fill)
	add_child(health)
	focus = ProgressBar.new()
	focus.position = Vector2(38, -62)
	focus.anchor_top = 1
	focus.size = Vector2(165, 4)
	focus.show_percentage = false
	var gold := StyleBoxFlat.new()
	gold.bg_color = Color("e9c878")
	focus.add_theme_stylebox_override("fill", gold)
	add_child(focus)
	var tips := text(
		"WASD  MOVE     SHIFT  RUN     SPACE  JUMP     RMB  STRAFE / AIM     ESC  CURSOR     F6  QUALITY     R  RESET",
		Vector2(0, -30),
		11,
		cream
	)
	tips.anchor_top = 1
	tips.anchor_left = 0.5
	tips.position.x = -tips.get_minimum_size().x * 0.5
	notice = text("", Vector2(-220, -84), 14, cream)
	notice.anchor_left = 1
	notice.anchor_top = 1


func _process(_delta: float) -> void:
	if player == null:
		return
	focus.value = (1.0 - player.magic_cooldown / 2.5) * 100.0
	status.text = (
		"WARDEN   /   " + ("ARCANE STRIKE" if player.magic_cooldown > 1.8 else "SWORD READY")
	)
	quality.text = ("ULTRA" if world.high_quality else "BALANCED") + "  /  FORWARD+"
	notice.text = (
		("FIRST PERSON" if player.first_person else "THIRD PERSON")
		+ "\n"
		+ ("Q   READY" if player.magic_cooldown <= 0 else "ARCANE RECHARGING")
	)
