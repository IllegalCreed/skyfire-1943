extends RefCounted
## All chase layers share camera yaw; only world translation adds parallax.

const FLIGHT := preload("res://src/gameplay/chase_flight.gd")

static func run(game) -> void:
	var flight = FLIGHT.new()
	flight.position.y = 1.5
	for bearing in [-0.6, 0.0, 0.6]:
		for sea_range in [4.0, 30.0, 100.0, 220.0]:
			flight.view_heading = 0
			flight.bank = 0
			var point: Vector3 = flight.camera_position() + Vector3(sin(bearing), 0, -cos(bearing)) * sea_range
			point.y = 0.22
			var air := Vector2(bearing * FLIGHT.AIR_SCROLL_SCALE, 260)
			var before: Vector2 = flight.project(point)
			var air_before: Vector2 = flight.air_screen(air)
			var background_before: float = flight.bearing_screen(bearing)
			var depth_before: float = flight.depth(point)
			for yaw in [-0.2, 0.2]:
				flight.view_heading = yaw
				flight.bank = signf(yaw) * 0.34
				var expected: float = -yaw * FLIGHT.AIR_SCROLL_SCALE
				var after: Vector2 = flight.project(point)
				assert(absf(after.x - before.x - expected) < 0.001,
					"Near/far ships, sea texture and buoys use the same yaw as the sky")
				assert(absf(flight.air_screen(air).x - air_before.x - expected) < 0.001
					and absf(flight.bearing_screen(bearing) - background_before - expected) < 0.001,
					"Air targets, clouds, islands and world points share one camera scroll")
				assert(absf(after.y - before.y) < 0.001 and is_equal_approx(flight.depth(point), depth_before),
					"Yaw and bank cannot change a frozen ship's height or size")
			flight.view_heading = 0
			flight.bank = -0.34
			assert(flight.project(point).distance_to(before) < 0.001, "Bank cannot drag scenery with our wings")
	# Round-trip across the viewport, several depths and both sides of 0 degrees.
	for heading in [0.0, 0.4, TAU - 0.025, TAU + 0.025]:
		flight.view_heading = heading
		for x in [10.0, 240.0, 480.0, 720.0, 950.0]:
			for distance in [10.0, 30.0, 90.0, 220.0]:
				var screen := Vector2(x, 320)
				var point: Vector3 = flight.point_from_screen(screen, distance)
				assert(flight.project(point).distance_to(screen) < 0.001
					and absf(flight.depth(point) - distance) < 0.001,
					"Shared projection preserves the screen/depth inverse, including bank and seam")
	flight.view_heading = TAU - 0.03
	var point := Vector3(20, 0.22, -100)
	var before: Vector2 = flight.project(point)
	flight.view_heading = 0.03
	assert(absf(flight.project(point).x - before.x + 36) < 0.001, "Sea objects cross the heading seam without a jump")
	flight.view_heading = PI
	assert(not flight.visible(point), "Angular wrap still hides a ship behind the pilot")
	# Actual movement is different from a pure camera turn: nearer objects can
	# move faster, and approaching ships grow. Do not eliminate that depth cue.
	flight.view_heading = 0
	var near := Vector3(20, 0.22, -40)
	var far := Vector3(20, 0.22, -200)
	var near_before: Vector2 = flight.project(near)
	var far_before: Vector2 = flight.project(far)
	flight.position.x += 2
	assert(absf(flight.project(near).x - near_before.x) > absf(flight.project(far).x - far_before.x) * 2,
		"Translation retains real near/far parallax instead of flattening the world")
	flight.reset()
	flight.position.y = 1.5
	point = Vector3(0, 0.22, -100)
	before = flight.project(point)
	var old_depth: float = flight.depth(point)
	flight.advance(1.0, Vector2.ZERO)
	assert(flight.depth(point) < old_depth and flight.project(point).y > before.y,
		"Forward approach still moves ships down and increases their scale")
	flight.position.z = -103
	assert(flight.project(point).y > FLIGHT.SEA_VIEW_BOTTOM + 70,
		"A close ship passes fully below the playable bottom before crossing behind the camera")
	# The real ship draw, torpedo draw and world collision share the same point.
	game.start_game()
	game._clear_combat()
	game.transition = 0
	game.flight.position.y = 1.5
	game.flight.heading = 0.38
	game.flight.view_heading = 0.38
	game.flight.bank = 0.34
	point = game.flight.position + game.flight.forward() * 64
	point.y = 0.22
	game.enemies.append({"p": point, "hp": 7, "surface": true})
	assert(absf(game._entity_screen(game.enemies[0]).x - 480) < 0.001, "A ship ahead is not dragged by player bank")
	game.special()
	assert(game.shots.size() == 1 and absf(game._entity_screen(game.shots[0]).x - 480) < 0.001,
		"The forward torpedo shares the ship's angular line")
	game._update_shots(1.2)
	assert(game.enemies.is_empty(), "Angular rendering must not change swept world-space torpedo hits")
	game.start_game()
	print("CHASE SCROLL PASS: sky/air/sea shared yaw, no bank drift or size pumping, projection inverse, 360 seam, real translation parallax, torpedo hits")
