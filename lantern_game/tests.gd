extends SceneTree
var game: Node2D
var checks := 0
var failures: Array[String] = []


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("FAIL ", message)


func _initialize() -> void:
	call_deferred("run")


func frame(count: int = 1) -> void:
	for i in range(count):
		await physics_frame
		await process_frame


func action(name: String) -> void:
	var event := InputEventAction.new()
	event.action = name
	event.pressed = true
	game._unhandled_input(event)


func walk(from: Vector2, direction: String, frames: int) -> Vector2:
	game.hero.position = from
	game.hero.timer = 0.0
	game.hero.state = "idle"
	Input.action_press(direction)
	await frame(frames)
	Input.action_release(direction)
	await frame(2)
	return game.hero.position


func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await frame(3)
	check(game.mode == "main", "Main menu opens before movement")
	check(game.hero.position == Vector2(776, 658), "Central village spawn")
	action("interact")
	await frame(2)
	check(game.mode == "play", "Z activates focused main-menu button")
	check(
		game.body.get_child_count() == game.map.solids.size(),
		"All manifest solids are physical shapes"
	)
	check(game.map.objects.size() > 400, "Large composed village and surrounding forest")
	var house_count := 0
	var water_count := 0
	var fence_count := 0
	for shape in game.body.get_children():
		var kind: String = shape.get_meta("kind")
		if kind == "house":
			house_count += 1
		if kind == "water":
			water_count += 1
		if kind == "fence":
			fence_count += 1
		check(shape.shape.size.x > 0.0 and shape.shape.size.y > 0.0, "Positive solid extents")
		var query := PhysicsPointQueryParameters2D.new()
		query.position = shape.position
		query.collision_mask = 1
		check(
			not game.get_world_2d().direct_space_state.intersect_point(query).is_empty(),
			"Solid registered in physics at " + str(shape.position)
		)
	check(house_count == 12, "Twelve collidable cottages")
	check(water_count > 400, "Water collision follows cyan shoreline pixel runs")
	check(fence_count > 25, "Fence segments physically block")
	var start := Vector2(776, 658)
	var end: Vector2 = await walk(start, "right", 18)
	check(end.x > start.x + 18.0 and end.x < start.x + 30.0, "Practical walking across plaza")
	end = await walk(Vector2(480, 420), "up", 60)
	check(end.y >= 398.0 and end.y < 410.0, "Building front blocks walking through wall")
	end = await walk(Vector2(430, 386), "right", 60)
	check(end.x <= 448.0 and end.x > 436.0, "Building side blocks walking")
	end = await walk(Vector2(1100, 1012), "up", 60)
	check(end.y >= 994.0 and end.y < 1008.0, "Farm south fence blocks walking")
	end = await walk(Vector2(1144, 804), "down", 72)
	check(end.y > 870.0, "Farm gate is passable; not a whole-farm rectangle")
	end = await walk(Vector2(1030, 610), "right", 100)
	var bank := 9999.0
	for item in game.map.solids:
		if item.kind == "water" and item.rect[1] <= 607.0 and item.rect[1] + item.rect[3] > 607.0:
			bank = minf(bank, item.rect[0])
	check(
		end.x < bank and absf(end.x - (bank - 4.0)) < 2.0,
		"Lake blocks actual movement within two pixels of visible west bank"
	)
	# Pause and dialogue lock the actual player physics, not just menus.
	game.hero.position = start
	action("pause")
	check(game.mode == "pause", "C/Escape opens pause")
	var before: Vector2 = game.hero.position
	Input.action_press("right")
	await frame(12)
	Input.action_release("right")
	check(game.hero.position == before, "Pause freezes character")
	var animal: CharacterBody2D
	for actor in game.actors.get_children():
		if actor is CharacterBody2D and actor.species == "fox":
			animal = actor
			break
	var animal_before: Vector2 = animal.position
	await frame(12)
	check(animal.position == animal_before, "Pause freezes wildlife")
	action("pause")
	game.hero.position = game.traveller.position + Vector2(0, 23)
	check(game.interactable(), "Nearby wanderer enables interaction button")
	action("interact")
	check(game.mode == "dialogue", "Z begins portrait dialogue")
	await frame(3)
	check(
		(
			game.dialogue_text.visible_characters > 0
			and (
				game.dialogue_text.visible_characters
				< game.dialogue_text.get_total_character_count()
			)
		),
		"Dialogue typewriter reveals gradually"
	)
	action("cancel")
	await frame(2)
	check(
		game.dialogue_text.visible_characters == game.dialogue_text.get_total_character_count(),
		"X reveals complete page including final punctuation"
	)
	action("interact")
	check(game.dialog_page == 1, "Z advances completed page")
	check(game.portrait.texture != null, "Wanderer portrait loaded")
	for page in range(1, game.dialogue.size()):
		action("cancel")
		await frame(1)
		action("interact")
	check(game.mode == "play", "Final Z closes story and restores walking")
	game.hero.position = start
	game.hero.timer = 0.0
	game.use_ability()
	check(
		game.pulse >= 0.0 and game.ability_cooldown > 0.0,
		"Lantern ability has visible pulse and cooldown"
	)
	check(game.hero.state == "ability", "Dedicated ability animation")
	check(
		game.beacons.any(func(b: Dictionary): return b.lit),
		"Lantern ability lights real nearby beacons"
	)
	var cd: float = game.ability_cooldown
	game.use_ability()
	check(game.ability_cooldown == cd, "Ability cannot spam through cooldown")
	game.hero.timer = 0.0
	game.hero.state = "idle"
	game.hero.start_attack()
	check(game.hero.state == "attack" and game.hero.timer > 0.0, "Weapon attack animation")
	for tool in range(5):
		game.hero.equipped = tool
		game.hero.update_tool()
		check(game.hero.tool.texture != null, "Animated interchangeable tool " + str(tool))
	for facing in range(4):
		game.hero.facing = facing
		game.hero.state = "walk"
		game.hero.animate()
		check(
			game.hero.sprite.region_rect.position.x == facing * 32,
			"Four-direction animation " + str(facing)
		)
	game.hero.timer = 0.0
	game.hero.startled = 0.0
	animal.position = start + Vector2(18, 0)
	animal.flee_time = 0.0
	animal.animal_step(0.016)
	check(
		animal.flee_time > 0.0 and animal.velocity.x > 0.0,
		"Fox flees away from visible nearby player"
	)
	check(
		game.hero.state == "surprise" and game.hero.velocity.x < 0.0,
		"Close encounter startles player and steps back"
	)
	game.hero.position = Vector2(1100, 820)
	animal.position = Vector2(1100, 850)
	check(
		not game.clear_sight(animal.position, game.hero.position),
		"Fence occludes wildlife line of sight"
	)
	action("collision")
	check(game.debug_collision and debug_collisions_hint, "F3 enables actual collision display")
	game.returning_to = "pause"
	game.show_menu("settings")
	check(game.mode == "settings", "Settings are accessible")
	game.show_menu("controls")
	check(game.mode == "controls", "Controls are documented in game")
	game.tone_player.stop()
	game.ambience_player.stop()
	await create_timer(0.1).timeout
	game.queue_free()
	await frame(3)
	print("LANTERN_TEST_RESULT ", JSON.stringify({"checks": checks, "failed": failures}))
	if failures.is_empty():
		print("LANTERN_TEST_OK ", checks)
	quit(0 if failures.is_empty() else 1)
