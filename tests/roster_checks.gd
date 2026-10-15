extends RefCounted

const ROSTER := preload("res://src/gameplay/enemy_roster.gd")
const ENCOUNTER := preload("res://src/gameplay/chase_encounter.gd")
const EXIT_CHECKS := preload("res://tests/chase_exit_checks.gd")
const GUN := preload("res://src/gameplay/chase_gun.gd")
const ART := preload("res://src/rendering/aircraft_art.gd")

static func run(game) -> void:
	var seen: Dictionary = {}
	var vessels: Dictionary = {}
	var saw_bonus := false
	game.start_game()
	for wave in range(12):
		game._clear_combat()
		game.spawn_wave()
		for enemy in game.enemies:
			if enemy.surface: vessels[enemy.vessel] = true
			else:
				if ROSTER.is_bonus(enemy.kind): saw_bonus = true
				else: seen[enemy.kind] = true
				assert(enemy.hp == ROSTER.profile(enemy.kind).hp, "Live chase waves apply each role's durability")
	assert(seen.size() == 3 and vessels.size() == 2, "Natural waves expose all three aircraft and both vessels")
	assert(saw_bonus, "Bonus aircraft appears in natural waves")
	for kind in ROSTER.KINDS:
		var spec := ROSTER.profile(kind)
		var shots := ROSTER.shot_velocities(kind, Vector2.DOWN, true, 6)
		assert(shots.size() == spec.burst, "Aircraft fire patterns match their role")
		assert(ROSTER.shot_velocities(kind, Vector2.DOWN, true, 1).size() == 1,
			"A two-shot attack respects the last available enemy-bullet slot")
		for velocity in shots: assert(absf(velocity.length() - spec.bullet_speed) < 0.001, "Role projectile speed")
		for side in [-1, 1]:
			EXIT_CHECKS._check_pursuit(game, side, 0, 0, false, kind, kind == "interceptor")
		# All front silhouettes fit the existing 64-pixel exit clearance even
		# under rotation. Bigger art must not resurrect edge disappearance.
		var dimensions := ART.dimensions(kind, false)
		assert(Vector2(dimensions.span, 24).length() * GUN.PLANE_SCALES[-1] < ENCOUNTER.EXIT_MARGIN,
			"Every aircraft silhouette fits the full offscreen-removal margin")
		game.start_game()
		var enemy := ENCOUNTER.make_enemy(game.flight, 1, 0)
		enemy.kind = kind
		enemy.route_duration = spec.duration
		enemy.age = spec.duration * 0.5
		ENCOUNTER.update(enemy)
		var original: Vector2 = enemy.air_position
		var before: Vector2 = game.flight.air_screen(original)
		var depth: float = enemy.chase_depth
		game.flight.view_heading = 0.2
		ENCOUNTER.update(enemy)
		var after: Vector2 = game.flight.air_screen(enemy.air_position)
		assert(enemy.air_position == original and enemy.chase_depth == depth,
			"Role weaving is autonomous, never affected by camera turns")
		assert(absf(after.x - before.x + 120) < 0.001 and is_equal_approx(after.y, before.y),
			"All roles retain the shared horizontal-only airfield scroll")
	# A bomber takes two real convergence hits, not an enlarged screen hitbox.
	game.start_game()
	game._clear_combat()
	var bomber := ENCOUNTER.make_enemy(game.flight, 3, 0)
	var pair := GUN.make_pair(game.flight)
	var points := GUN.positions(pair, game.flight, 16.0 / 60)
	bomber.air_position = game.flight.air_position_from_screen((points[0] + points[1]) * 0.5)
	bomber.chase_depth = 60.0
	game.enemies.append(bomber)
	game.shots.append(pair)
	game._update_shots(16.0 / 60)
	assert(game.enemies.size() == 1 and bomber.hp == 1 and game.score == 0, "First valid hit damages but does not kill the twin-engine attacker")
	game.shots.append(GUN.make_pair(game.flight))
	game._update_shots(16.0 / 60)
	assert(game.enemies.is_empty() and game.kills == 1 and game.score == 200, "Second valid hit awards one normal distance-based kill")
	# Exercise the actual capped spread producer, not only roster helper math.
	game.start_game()
	game._clear_combat()
	var capped_bomber := ENCOUNTER.make_enemy(game.flight, 3, 0)
	capped_bomber.age = capped_bomber.route_duration * 0.5
	capped_bomber.fire = 0
	game.enemies.append(capped_bomber)
	for i in range(5): game.hostile.append({"air_bullet": true, "air_position": Vector2.ZERO, "v": Vector2.ZERO, "age": 0.0, "life": 6.0})
	game._update_enemies(0)
	assert(game.hostile.size() == 6, "Real bomber firing cannot exceed the chase six-bullet cap")
	# Both 2D spaces also use the roster, without changing existing controls.
	for mode in [game.Mode.SIDE, game.Mode.TOP]:
		game.start_game()
		game.switch_mode(mode)
		game.wave = 0
		game.spawn_wave()
		var speeds: Dictionary = {}
		for enemy in game.enemies:
			assert(enemy.hp == ROSTER.profile(enemy.kind).hp_2d, "2D roles apply correct durability")
			speeds[enemy.kind] = enemy.p
		game._update_enemies(0.1)
		for enemy in game.enemies:
			var spec := ROSTER.profile(enemy.kind)
			var advance: float = speeds[enemy.kind].x - enemy.p.x if mode == game.Mode.SIDE else enemy.p.y - speeds[enemy.kind].y
			assert(absf(advance - (spec.speed_side if mode == game.Mode.SIDE else spec.speed_top) * 0.1) < 0.001,
				"2D motion is genuinely different between roles, not just recolored")
	game.start_game()
	print("ROSTER PASS: three aircraft, two vessels, distinct motion/fire/HP, bomber two-hit combat, capped spread, autonomous scroll, all-role side exits")
