extends RefCounted

const ENCOUNTER := preload("res://src/gameplay/chase_encounter.gd")
const FLIGHT := preload("res://src/gameplay/chase_flight.gd")
const GUN := preload("res://src/gameplay/chase_gun.gd")
const EXIT_CHECKS := preload("res://tests/chase_exit_checks.gd")

static func run(game) -> void:
	game.start_game()
	game._clear_combat()
	game.spawn_wave()
	assert(game.enemies.size() == 1, "First encounter has one aircraft")
	var first: Dictionary = game.enemies[0]
	var entry: Vector2 = game._entity_screen(first)
	assert(entry.y >= 100 and entry.y <= 145 and entry.y < game.flight.aim_screen().y - 120,
		"Aircraft enter high above the current firing cue")
	assert(GUN.stage(game._enemy_depth(first)) == 0, "Entry starts as a distant unhittable point")
	var previous_y := entry.y
	var previous_depth: float = first.chase_depth
	for tick in range(1, 57):
		first.age = tick * 0.1
		ENCOUNTER.update(first)
		var screen: Vector2 = game._entity_screen(first)
		assert(screen.y >= previous_y and first.chase_depth <= previous_depth,
			"Neutral approach descends and grows without reversing its distance stage")
		previous_y = screen.y
		previous_depth = first.chase_depth
	assert(previous_y > 440 and absf(first.bank) > 0.6, "Approach ends low and banked")
	game._clear_combat()
	game.wave = 0
	for i in range(20): game.spawn_wave()
	assert(game.enemies.size() == ENCOUNTER.MAX_AIRCRAFT and game.wave == 2,
		"Spawn requests cannot exceed the three-aircraft limit or advance skipped waves")
	# Camera turns change only the shared horizontal offset. Route age, bank,
	# vertical position, depth and sprite phase do not depend on where we look.
	game._clear_combat()
	var targets: Array[Dictionary] = []
	for age in [2.0, 4.0]:
		var enemy := ENCOUNTER.make_enemy(game.flight, 1, 0)
		enemy.age = age
		enemy.fire = 999
		ENCOUNTER.update(enemy)
		game.enemies.append(enemy)
		targets.append({"screen": game._entity_screen(enemy), "depth": enemy.chase_depth,
			"bank": enemy.bank, "phase": GUN.stage(enemy.chase_depth)})
	game.flight.heading = 0.2
	game.flight.view_heading = 0.2
	game.flight.bank = 0.34
	game._update_enemies(0)
	for i in range(game.enemies.size()):
		var enemy: Dictionary = game.enemies[i]
		var after: Vector2 = game._entity_screen(enemy)
		assert(absf(after.x - targets[i].screen.x + 120) < 0.001, "Near and far aircraft share the same left scroll")
		assert(is_equal_approx(after.y, targets[i].screen.y), "Horizontal input cannot move enemies vertically")
		assert(enemy.chase_depth == targets[i].depth and enemy.bank == targets[i].bank
			and GUN.stage(enemy.chase_depth) == targets[i].phase, "Looking away cannot trigger a route or size change")
	game.flight.view_heading = 0
	game.flight.bank = 0
	for i in range(game.enemies.size()):
		assert(game._entity_screen(game.enemies[i]).distance_to(targets[i].screen) < 0.001,
			"Returning the view restores the same frozen formation")
	var flight = FLIGHT.new()
	flight.view_heading = TAU - 0.015
	var world: Vector2 = flight.air_position_from_screen(Vector2(480, 140))
	flight.view_heading = 0.015
	assert(absf(flight.air_screen(world).x - 462) < 0.001, "Airfield scroll is continuous through 360 degrees")
	# Enemy bullets and supplies are consumers of the same airfield transform.
	game.start_game()
	var air_position: Vector2 = game.flight.air_position_from_screen(Vector2(530, 240))
	var bullet := {"air_bullet": true, "air_position": air_position}
	var pickup := {"air_pickup": true, "air_position": air_position}
	game.flight.view_heading = 0.1
	assert(game._entity_screen(bullet) == game._entity_screen(pickup), "Air bullets and drops cannot drift against the scrolling formation")
	game.start_game()
	game._clear_combat()
	game.energy = 50
	game.kills = 3
	game.enemies.append(ENCOUNTER.make_enemy(game.flight, 1, 0))
	game._destroy_enemy(0, 150)
	assert(game.pickups.size() == 1 and game.pickups[0].get("air_pickup", false), "Fighter supply uses the airfield, not obsolete world coordinates")
	game.pickups[0].air_position = game.flight.air_position_from_screen(game._ship_screen())
	game._update_pickups(0)
	assert(game.energy == 68 and game.power == 2, "Airfield supply remains collectible")
	game.start_game()
	game._clear_combat()
	game.spawn_wave()
	game.enemies.append({"p": Vector3(0, 0.3, 10), "hp": 7, "surface": true})
	game.shots.append({"p": Vector3(0, 0.3, 4), "v": Vector3(0, 0, 15), "surface": true})
	game._update_shots(0.5)
	assert(game.enemies.size() == 1 and game.enemies[0].get("air_route", false), "Torpedoes skip airfield targets safely")
	# Run two minutes without shooting or changing altitude: density must remain
	# bounded even when enemies aren't killed and the pilot turns away.
	game.start_game()
	game.transition = 0
	game.invulnerable = 999
	var peak_air := 0
	for frame in range(7200):
		var movement := Vector2.RIGHT if frame % 720 < 180 else Vector2.ZERO
		game.step(1.0 / 60, movement, false)
		var active_air := 0
		for enemy in game.enemies:
			if enemy.surface: continue
			active_air += 1
			assert(enemy.age < EXIT_CHECKS.EXPECTED_CLEAR_TIME, "Autonomous escapes cannot accumulate behind the viewer")
		peak_air = maxi(peak_air, active_air)
		assert(active_air <= ENCOUNTER.MAX_AIRCRAFT, "Long-run air density stays bounded")
		assert(game.hostile.size() <= 6, "Chase enemy bullets remain bounded")
	assert(game.wave >= 15 and not game.game_over, "Long-run encounters continue without hiding a stopped simulation")
	EXIT_CHECKS.run(game)
	game.start_game()
	print("CHASE ENCOUNTER PASS: high descending entry, sparse waves, max_air=", peak_air,
		", 120s cleanup, uniform scroll, no turn-induced phase/bank/Y changes, 360 seam, shared bullets/drops")
