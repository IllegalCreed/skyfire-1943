extends RefCounted
## Exercise actual removal with sustained pursuit, not just neutral route samples.

const ENCOUNTER := preload("res://src/gameplay/chase_encounter.gd")
const FLIGHT := preload("res://src/gameplay/chase_flight.gd")
const ROSTER := preload("res://src/gameplay/enemy_roster.gd")
# An assertion about feasible flight, never a timeout used to delete enemies.
const EXPECTED_CLEAR_TIME := 10.0

static func run(game) -> void:
	assert(ENCOUNTER.EXIT_SPEED > FLIGHT.TURN_SPEED * FLIGHT.AIR_SCROLL_SCALE,
		"Escape can outrun the fastest same-direction camera scroll")
	# Even an artificially tracked, old aircraft cannot be removed on a timer.
	# Check partial silhouettes at both edges, not just a center inside the view.
	for x in [-64.1, -63.9, -31.0, 0.0, 480.0, 960.0, 991.0, 1023.9, 1024.1]:
		game.start_game()
		game._clear_combat()
		var enemy := ENCOUNTER.make_enemy(game.flight, 1, 0)
		enemy.age = 20.0
		enemy.fire = 999
		ENCOUNTER.update(enemy)
		game.flight.view_heading = wrapf((enemy.air_position.x - (x - 480)) / FLIGHT.AIR_SCROLL_SCALE, 0, TAU)
		game.enemies.append(enemy)
		game._update_enemies(0)
		var cleared: bool = x < -ENCOUNTER.EXIT_MARGIN or x > ENCOUNTER.VIEW_WIDTH + ENCOUNTER.EXIT_MARGIN
		assert(game.enemies.is_empty() == cleared, "Age never replaces full lateral silhouette clearance")
	# Both sides, both aircraft in a formation, and either side of the 360 seam.
	var longest_pursuit := 0.0
	for side in [-1, 1]:
		for heading in [0.0, 0.08, TAU - 0.08]:
			for index in [0, 1]:
				longest_pursuit = maxf(longest_pursuit, _check_pursuit(game, side, heading, index, false))
		# Also hold the turn from entry, and reverse during the escape.
		_check_pursuit(game, side, 0, 0, true)
		_check_reversal(game, side)
	game.start_game()
	print("CHASE EXIT PASS: both-direction sustained pursuit, longest=", longest_pursuit,
		"s, survives old expiry while visible, full silhouette clearance, no age cull, 360 seam, reversal")

static func _check_pursuit(game, side: int, heading: float, index: int, from_entry: bool,
	kind: String = "interceptor", check_old_expiry: bool = true) -> float:
	game.start_game()
	game._clear_combat()
	game.flight.heading = heading
	game.flight.view_heading = heading
	var enemy := ENCOUNTER.make_enemy(game.flight, 2 if side < 0 else 1, index)
	# Keep the original v0.5 disappearance fixture independent of wave variety.
	# New roles also reuse this full-speed pursuit test without the old timeout.
	enemy.kind = kind
	enemy.route_duration = ROSTER.profile(kind).duration + index * 0.45
	enemy.hp = ROSTER.profile(kind).hp
	var turn_start: float = 0.0 if from_entry else enemy.entry_delay + enemy.route_duration * ENCOUNTER.EXIT_START - 0.332
	var old_expiry: float = enemy.entry_delay + enemy.route_duration + 0.15
	enemy.fire = 999
	game.enemies.append(enemy)
	var retired := false
	var survived_old_expiry := false
	var previous_screen: Vector2 = game._entity_screen(enemy)
	for frame in range(int(EXPECTED_CLEAR_TIME * 60)):
		game.flight.advance(1.0 / 60, Vector2(side, 0) if enemy.age >= turn_start else Vector2.ZERO)
		game._update_enemies(1.0 / 60)
		var screen: Vector2 = game._entity_screen(enemy)
		# Wrapping the far-behind representation is harmless; a visible aircraft
		# must never jump, including when the player's heading crosses 0 degrees.
		if (screen.x >= -ENCOUNTER.EXIT_MARGIN and screen.x <= 960 + ENCOUNTER.EXIT_MARGIN) \
			or (previous_screen.x >= -ENCOUNTER.EXIT_MARGIN and previous_screen.x <= 960 + ENCOUNTER.EXIT_MARGIN):
			assert(screen.distance_to(previous_screen) < 40, "Escape motion and camera seam cannot teleport a visible aircraft")
		previous_screen = screen
		if game.enemies.is_empty():
			assert(ENCOUNTER.escaping(enemy) and (screen.x < -ENCOUNTER.EXIT_MARGIN
				or screen.x > ENCOUNTER.VIEW_WIDTH + ENCOUNTER.EXIT_MARGIN),
				"Actual enemy cleanup happens only beyond a lateral edge")
			if not from_entry:
				assert(side * (screen.x - 480) > 480 + ENCOUNTER.EXIT_MARGIN,
					"Close pursuit ends with the enemy outrunning us on its chosen escape side")
			retired = true
			break
		if enemy.age >= old_expiry:
			assert(not ENCOUNTER.finished(enemy, game.flight), "Old expiry cannot destroy an aircraft still in view")
			if screen.x > 64 and screen.x < 896: survived_old_expiry = true
	assert(retired, "Sustained full-speed pursuit must not indefinitely retain the enemy")
	if not from_entry and check_old_expiry:
		assert(survived_old_expiry, "Pursuit reproduces the old visible-disappearance case and preserves the aircraft")
	return enemy.age

static func _check_reversal(game, side: int) -> void:
	game.start_game()
	game._clear_combat()
	var enemy := ENCOUNTER.make_enemy(game.flight, 2 if side < 0 else 1, 0)
	enemy.fire = 999
	game.enemies.append(enemy)
	for frame in range(int(EXPECTED_CLEAR_TIME * 60)):
		var input := Vector2.ZERO
		if enemy.age >= 3.7: input.x = side if enemy.age < 5.7 else -side
		game.flight.advance(1.0 / 60, input)
		game._update_enemies(1.0 / 60)
		if game.enemies.is_empty():
			assert(ENCOUNTER.finished(enemy, game.flight), "Reversing the camera still retires only a fully cleared aircraft")
			break
	assert(game.enemies.is_empty(), "Reversing pursuit cannot trap an escaping aircraft")
