extends RefCounted
## Regression checks for nose-relative aim and the four-frame twin-gun window.

const FLIGHT := preload("res://src/gameplay/chase_flight.gd")
const GUN := preload("res://src/gameplay/chase_gun.gd")

static func run(game) -> void:
	var flight = FLIGHT.new()
	for altitude in [0.25, 1.0, 3.3, 5.0, FLIGHT.MAX_ALTITUDE]:
		for climb in [-FLIGHT.CLIMB_SPEED, 0.0, FLIGHT.CLIMB_SPEED]:
			for roll in [-0.34, 0.0, 0.34]:
				flight.position.y = altitude
				flight.climb_rate = climb
				flight.bank = roll
				var aim: Vector2 = flight.aim_screen()
				assert(aim.y < flight.aircraft_screen().y - 50, "Aim remains above the nose at every altitude")
				assert(Rect2(0, 66, 960, 440).has_point(aim), "Aim stays inside the playing field")
				var pair := GUN.make_pair(flight)
				var endpoints := GUN.positions(pair, flight, 19.0 / 60)
				assert(endpoints[0].distance_to(aim) < 0.001 and endpoints[1].distance_to(aim) < 0.001,
					"Both barrels converge on the displayed firing cue")
				for distance in [30.0, 90.0, 165.0, 220.0]:
					assert(flight.project(flight.point_from_screen(aim, distance)).distance_to(aim) < 0.001,
						"Formation projection and screen-space aiming agree")
	flight.reset()
	var pair := GUN.make_pair(flight)
	assert(GUN.hit_midpoints(pair, flight, 0, 15.0 / 60).is_empty(), "No hit before frame 16")
	assert(not GUN.hit_midpoints(pair, flight, 15.0 / 60, 16.0 / 60).is_empty(), "Frame 16 opens hit window")
	assert(not GUN.hit_midpoints(pair, flight, 18.0 / 60, 19.0 / 60).is_empty(), "Frame 19 can hit")
	assert(GUN.hit_midpoints(pair, flight, 20.0 / 60, 21.0 / 60).is_empty(), "Expired pair cannot hit")
	assert(GUN.hit_midpoints(pair, flight, 19.0 / 60, 20.0 / 60).is_empty(), "Frame 20 cannot replay the previous hit sample")
	assert(GUN.hit_midpoints(pair, flight, 0, 0.5).size() == 4, "Slow update cannot skip all four eligible frames")
	pair.age = 20.0 / 60
	assert(GUN.expired(pair), "Expiry is frame 20")
	pair.age = 0
	var before := GUN.positions(pair, flight, 16.0 / 60)
	flight.position.y += 1
	var after := GUN.positions(pair, flight, 16.0 / 60)
	assert(is_equal_approx(before[0].x, after[0].x) and after[0].y < before[0].y - 50,
		"Existing bullets move vertically with the climbing aircraft")
	flight.reset()
	var target := Vector2(480, 300)
	assert(not GUN.hits(target, target, 0), "Most distant phase cannot be hit")
	for stage in range(1, 6):
		var radius: Vector2 = GUN.HIT_RADII[stage] * GUN.PIXEL_SCALE
		assert(GUN.hits(target + radius - Vector2.ONE * 0.001, target, stage), "Inside stage hit box")
		assert(not GUN.hits(target + Vector2(radius.x, 0), target, stage), "Strict horizontal boundary")
		assert(not GUN.hits(target + Vector2(0, radius.y), target, stage), "Strict vertical boundary")
	assert(not GUN.hits(Vector2(490, 300), target, 1) and GUN.hits(Vector2(490, 300), target, 5),
		"Near phases are more forgiving than distant phases")
	# A stream is not an independent hit collider; only the pair midpoint counts.
	assert(not GUN.hits((target + target + Vector2(30, 0)) * 0.5, target, 3), "One stream on target is insufficient")
	assert(GUN.hits((target - Vector2(20, 0) + target + Vector2(20, 0)) * 0.5, target, 3), "Midpoint can hit between streams")
	# Exercise the actual game collision route and scoring, not just helper math.
	for stage in range(6):
		game.start_game()
		game._clear_combat()
		var shot := GUN.make_pair(game.flight)
		var points := GUN.positions(shot, game.flight, 16.0 / 60)
		var midpoint := (points[0] + points[1]) * 0.5
		var distance: float = [220.0, 165.0, 125.0, 90.0, 60.0, 30.0][stage]
		game.enemies.append({"p": game.flight.point_from_screen(midpoint, distance), "hp": 1, "surface": false})
		game.shots.append(shot)
		game._update_shots(15.0 / 60)
		assert(game.enemies.size() == 1, "Visual alignment before window is not an instant hit")
		game._update_shots(1.0 / 60)
		if stage == 0:
			assert(game.enemies.size() == 1 and game.score == 0, "Stage zero blocks real game damage")
		else:
			assert(game.enemies.is_empty() and game.shots.is_empty(), "Hit consumes the entire pair")
			assert(game.score == GUN.points_for_stage(stage), "Far/mid/near score follows hit stage")
	game.start_game()
	game._clear_combat()
	var shot := GUN.make_pair(game.flight)
	var points := GUN.positions(shot, game.flight, 16.0 / 60)
	game.enemies.append({"p": game.flight.point_from_screen((points[0] + points[1]) * 0.5, 60), "hp": 7, "surface": true})
	game.shots.append(shot)
	game._update_shots(0.5)
	assert(game.enemies[0].hp == 7 and game.shots.is_empty(), "Air pairs cannot damage boats and expire safely")
	game._clear_combat()
	game.power = 2
	for i in range(10): game.fire()
	assert(game.shots.size() == GUN.MAX_PAIRS, "Power upgrades preserve the three-pair slot limit")
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_H
	var helper_before: bool = game.aim_helper
	game._unhandled_input(event)
	assert(game.aim_helper != helper_before, "H toggles only the aiming overlay")
	game._unhandled_input(event)
	# The real display-loop accumulator must produce identical gameplay on
	# low- and high-refresh displays; eligibility cannot depend on render FPS.
	var baseline: Dictionary = {}
	game.demonstration = true
	for render_fps in [30, 60, 144]:
		game.start_game()
		game.transition = 0
		game.spawn_timer = 999
		for i in range(render_fps * 2): game._process(1.0 / render_fps)
		var state := {"elapsed": game.elapsed, "heading": game.flight.heading, "pairs": game.shots.size()}
		if baseline.is_empty(): baseline = state
		else:
			assert(absf(state.elapsed - baseline.elapsed) < 0.00001 and absf(state.heading - baseline.heading) < 0.00001,
				"30/60/144 Hz displays execute the same fixed simulation")
			assert(state.pairs == baseline.pairs, "Display FPS does not change pair lifetimes")
	game.demonstration = false
	game.start_game()
	game._clear_combat()
	game.spawn_wave()
	var banked := false
	var side_exit := false
	for i in range(480):
		game.flight.advance(1.0 / 60, Vector2.ZERO)
		game._update_enemies(1.0 / 60)
		for enemy in game.enemies:
			if enemy.surface: continue
			if absf(enemy.get("bank", 0.0)) > 0.3: banked = true
			var screen: Vector2 = game._entity_screen(enemy)
			if game._enemy_depth(enemy) > 1.2 and (screen.x < 0 or screen.x > 960): side_exit = true
	assert(banked and side_exit, "Approaching air formations bank and leave through the side of the view")
	game.start_game()
	print("CHASE AIM PASS: altitude/nose alignment, twin convergence, frames 16-19, six phase boxes, scores, slow updates, 30/60/144 Hz, side exits, sea separation, helper toggle")
