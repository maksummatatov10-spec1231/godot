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
	await check_live_shadows()
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
	# Regression audit: actual swept movement against EVERY trunk, four approaches.
	# Unlike old centre-point tests, this catches uncollidable visible side trunks.
	game.mode = "capture"
	var tree_moves := 0
	var house_fronts := 0
	for index in range(game.body.get_child_count()):
		var shape: CollisionShape2D = game.body.get_child(index)
		var kind: String = shape.get_meta("kind")
		if kind == "tree":
			var half: Vector2 = shape.shape.size / 2.0
			var trunk_hits := 0
			for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
				var gap: Vector2 = half * direction + direction * 6.0
				game.hero.position = shape.position + gap + Vector2(0, 3)
				# A boundary/adjacent trunk can make a side physically inaccessible.
				var query := PhysicsShapeQueryParameters2D.new()
				query.shape = game.hero.get_child(0).shape
				query.transform = Transform2D(0, game.hero.position + Vector2(0, -3))
				query.collision_mask = 1
				if not game.get_world_2d().direct_space_state.intersect_shape(query).is_empty():
					continue
				var collision: KinematicCollision2D = game.hero.move_and_collide(-gap * 2.0)
				check(
					collision != null and collision.get_collider_shape() == shape,
					"Swept movement hits actual trunk %d from %s" % [index, direction]
				)
				tree_moves += 1
				if collision != null and collision.get_collider_shape() == shape:
					trunk_hits += 1
			check(trunk_hits >= 2, "Every trunk stops movement on at least two accessible sides")
		elif kind == "house":
			game.hero.position = Vector2(shape.position.x - 8.0, shape.position.y + 40.0)
			var collision: KinematicCollision2D = game.hero.move_and_collide(Vector2(0, -60))
			check(collision != null, "Each facade stops actual movement")
			var base_y: float = shape.position.y + shape.shape.size.y / 2.0
			check(game.hero.position.y > base_y, "Hero standing at facade sorts IN FRONT of wall")
			house_fronts += 1
	check(tree_moves >= 1200 and house_fronts == 12, "Whole-map trunk/facade movement coverage")
	# Sample the real physics space along the WHOLE street network, then flood-fill.
	# Door thresholds/fence crossings are allowed to occupy painted edge tiles;
	# every remaining walkable road cell must belong to the same connected network.
	var road_query := PhysicsShapeQueryParameters2D.new()
	var road_feet := CircleShape2D.new()
	road_feet.radius = 4.0
	road_query.shape = road_feet
	road_query.collision_mask = 1
	var walkable: Dictionary = {}
	for cell in game.map.paths:
		var point := Vector2i(int(cell[0]), int(cell[1]))
		road_query.transform = Transform2D(0, Vector2(point * 16) + Vector2(8, 8))
		if game.get_world_2d().direct_space_state.intersect_shape(road_query).is_empty():
			walkable[point] = true
	var first: Vector2i = walkable.keys()[0]
	var reached: Dictionary = {}
	reached[first] = true
	var pending: Array[Vector2i] = [first]
	while not pending.is_empty():
		var point: Vector2i = pending.pop_back()
		for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var neighbor: Vector2i = point + step
			if walkable.has(neighbor) and not reached.has(neighbor):
				reached[neighbor] = true
				pending.append(neighbor)
	check(reached.size() == walkable.size(), "All physically walkable street cells are connected")
	for door in game.map.doors:
		var approach := Vector2i(int(floor(door[0] / 16.0)), int(floor(door[1] / 16.0)) + 1)
		check(reached.has(approach), "Every cottage door reaches the real walkable street network")
	print("WALKABLE_ROAD_CELLS ", reached.size(), " OF ", game.map.paths.size())
	print("TRUNK_MOVEMENT_COVERAGE ", tree_moves, " HOUSE_FRONTS ", house_fronts)
	game.mode = "play"
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


func check_live_shadows() -> void:
	check(game.shadows.z_index < game.actors.z_index, "Cast shadows stay below all actors")
	var expected: int = (
		game.map.objects.size() + game.actors.get_child_count() - game.map.objects.size()
	)
	# Every actor child is a map sprite, animated sprite, or character; only ripples do not cast.
	for animation in game.map.animations:
		if animation.kind == "ripple":
			expected -= 1
	# Hero has two silhouettes: body AND equipped tool.
	expected += 1
	check(game.shadows.casters.size() == expected, "Every raised sprite has a live silhouette")
	var hero_entry: Dictionary
	for entry in game.shadows.casters:
		check(entry.shadow.texture == entry.source.texture, "Shadow shares actual source texture")
		check(
			entry.shadow.region_rect == entry.source.region_rect,
			"Shadow matches current atlas frame"
		)
		if entry.source == game.hero.sprite:
			hero_entry = entry
	check(not hero_entry.is_empty(), "Hero has a directional silhouette, not only a contact oval")
	var old_position: Vector2 = game.hero.position
	var before: Vector2 = hero_entry.shadow.global_position
	game.hero.position += Vector2(20, 10)
	await frame(3)
	check(
		hero_entry.shadow.global_position.is_equal_approx(before + Vector2(20, 10)),
		"Shadow follows actor translation"
	)
	game.hero.state = "attack"
	game.hero.timer = 0.12
	game.hero.animate()
	await frame(3)
	check(
		hero_entry.shadow.region_rect == game.hero.sprite.region_rect,
		"Shadow follows attack animation"
	)
	game.hero.tool.hide()
	await frame(3)
	for entry in game.shadows.casters:
		if entry.source == game.hero.tool:
			# animate() restores tool visibility; test sync directly for the hidden case.
			game.hero.tool.hide()
			game.shadows.sync(entry)
			check(not entry.shadow.visible, "Hidden equipment cannot cast a stale shadow")
	game.hero.position = old_position
	game.hero.state = "idle"
	game.hero.timer = 0.0
	game.hero.animate()
	check(game.leaves.size() >= 600, "Crown-local falling leaf emitters cover the forest")
	var old_time: float = game.elapsed
	var sample: Vector3 = game.leaf_sample(Vector3(100, 100, 0))
	game.elapsed += 1.0
	var later: Vector3 = game.leaf_sample(Vector3(100, 100, 0))
	check(not sample.is_equal_approx(later), "Leaves drift and fall with simulation time")
	game.elapsed = old_time
	await frame(3)
