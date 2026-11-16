extends CharacterBody2D
const TOOLS = ["Katana", "Axe", "Pickaxe", "Net", "Hammer"]
## A feet-based body: the drawn head never enlarges the physical footprint.
var sprite := Sprite2D.new()
var tool: Sprite2D
var facing := 0
var clock := 0.0
var stride_phase := 0.0
var state := "idle"
var timer := 0.0
var equipped := 0
var species := ""
var flee_time := 0.0
var wander := Vector2.ZERO
var wander_time := 0.0
var home := Vector2.ZERO
var startled := 0.0
var world: Node2D
var player_controlled := false


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var capsule := CircleShape2D.new()
	capsule.radius = 4.0
	shape.shape = capsule
	shape.position = Vector2(0, -3)
	add_child(shape)
	sprite.region_enabled = true
	sprite.position = Vector2(0, -10)
	add_child(sprite)
	if player_controlled:
		sprite.texture = load(
			"res://assets/ninja/Actor/CharacterAnimated/NinjaGreen/SpriteSheet.png"
		)
		tool = Sprite2D.new()
		tool.region_enabled = true
		tool.position = sprite.position
		add_child(tool)
		update_tool()
	elif not species.is_empty():
		sprite.texture = load("res://assets/world/" + species + ".png")
	else:
		sprite.texture = load("res://assets/ninja/Actor/Character/Master/SpriteSheet.png")
	home = position
	animate()


func update_tool() -> void:
	tool.texture = load(
		"res://assets/ninja/Actor/CharacterAnimated/Weapon/" + TOOLS[equipped] + ".png"
	)


func direction_row(direction: Vector2) -> int:
	if absf(direction.x) > absf(direction.y):
		return 2 if direction.x < 0 else 3
	return 1 if direction.y < 0 else 0


func start_attack() -> void:
	if timer > 0.0:
		return
	state = "attack"
	timer = 0.34
	world.play_tone(280.0, 0.06, 0.08)


func surprise(from: Vector2) -> void:
	if startled > 0.0:
		return
	startled = 1.4
	timer = 0.35
	state = "surprise"
	velocity = (position - from).normalized() * 55.0
	world.play_tone(660.0, 0.1, 0.08)


func _physics_process(delta: float) -> void:
	if world.mode != "play" and world.mode != "main":
		velocity = Vector2.ZERO
		return
	# Sleep distant wildlife only; collision bodies remain registered and nearby
	# wildlife wakes before it can see/startle the player (reaction radius 66).
	if not species.is_empty() and world.mode == "play":
		if (
			global_position.distance_squared_to(world.hero.global_position) > 25600.0
			and not world.world_view_rect().grow(96).has_point(global_position)
		):
			velocity = Vector2.ZERO
			return
	clock += delta
	startled = maxf(0.0, startled - delta)
	if world.mode != "play":
		velocity = Vector2.ZERO
		animate()
		return
	if player_controlled:
		player_step(delta)
	elif not species.is_empty():
		animal_step(delta)
	else:
		velocity = Vector2.ZERO
	var before_move := position
	move_and_slide()
	if not species.is_empty():
		var stride_length := 28.0 if flee_time > 0.0 else 14.0
		stride_phase = fposmod(
			stride_phase + position.distance_to(before_move) / stride_length, 1.0
		)
	animate()


func player_step(delta: float) -> void:
	if timer > 0.0:
		timer -= delta
		if state == "surprise":
			velocity = velocity.move_toward(Vector2.ZERO, delta * 90.0)
		else:
			velocity = Vector2.ZERO
		if timer <= 0.0:
			state = "idle"
		return
	var movement := Input.get_vector("left", "right", "up", "down")
	velocity = movement * (112.0 if Input.is_action_pressed("run") else 76.0)
	state = "walk" if movement.length() > 0.1 else "idle"
	if movement.length() > 0.1:
		facing = direction_row(movement)


func animal_step(delta: float) -> void:
	var away: Vector2 = position - world.hero.position
	var distance := away.length()
	var sees: bool = distance < 66.0 and world.clear_sight(position, world.hero.position)
	if sees:
		if flee_time <= 0.0 and distance < 25.0:
			world.hero.surprise(position)
		flee_time = 4.0
		wander = away.normalized()
	if flee_time > 0.0:
		flee_time -= delta
		velocity = wander * (100.0 if species == "fox" else 87.0)
		if is_on_wall():
			wander = wander.rotated(0.8)
		if flee_time <= 0.0:
			home = position
	else:
		wander_time -= delta
		if wander_time <= 0.0:
			wander_time = randf_range(1.0, 2.6)
			wander = Vector2.from_angle(randf() * TAU) if randf() > 0.35 else Vector2.ZERO
			if position.distance_to(home) > 85.0:
				wander = position.direction_to(home)
		velocity = wander * 17.0
		if is_on_wall():
			wander_time = 0.0
	if velocity.length() > 1.0:
		facing = direction_row(velocity)
	state = "walk" if velocity.length() > 1.0 else "idle"


func animate() -> void:
	if player_controlled:
		var row := 0
		var column := facing
		if state == "walk":
			row = 1 + int(clock * (15.0 if Input.is_action_pressed("run") else 10.0)) % 4
		elif state == "attack":
			row = 8 + clampi(int((0.34 - timer) * 12.0), 0, 3)
		elif state == "surprise":
			column += 4
			row = 4 + int(clock * 8.0) % 2
		elif state == "ability":
			column += 4
			row = 12 + int(clock * 8.0) % 3
		sprite.region_rect = Rect2(column * 32, row * 32, 32, 32)
		tool.visible = state != "surprise" and state != "ability"
		var weapon_row := 0
		if state == "attack":
			weapon_row = 1 + clampi(int((0.34 - timer) * 12.0), 0, 2)
		tool.region_rect = Rect2(facing * 32, weapon_row * 32, 32, 32)
		tool.z_index = -1 if facing == 1 else 1
	elif not species.is_empty():
		var gait := 0 if state == "idle" else (2 if flee_time > 0.0 else 1)
		var frame := int(clock * 6.0) % 12 if gait == 0 else int(stride_phase * 12.0) % 12
		sprite.region_rect = Rect2(frame * 32, (gait * 4 + facing) * 32, 32, 32)
	else:
		# Original regular sheets: each column a direction; rows 0..3 walking.
		sprite.region_rect = Rect2(facing * 16, 0, 16, 16)
	# Small idle breathing, not full-body bobbing or moving collision shapes.
	var breath := sin(clock * 2.6) * 0.018 if state == "idle" else 0.0
	sprite.scale = Vector2(1.0 + breath * 0.5, 1.0 - breath)
	var local_floor: float = world.shadows.contact_local_y({"source": sprite, "foot": self})
	sprite.position.y = -3.0 - local_floor * sprite.scale.y
	if player_controlled:
		# Held equipment shares the body's contact plane, not its own lowest tip.
		tool.scale = sprite.scale
		tool.position = sprite.position
	queue_redraw()


func _draw() -> void:
	if startled > 0.0:
		var p := Vector2(0, -26)
		draw_line(p, p + Vector2(0, 5), Color("fff1c2"), 2)
		draw_circle(p + Vector2(0, 8), 1, Color("fff1c2"))
