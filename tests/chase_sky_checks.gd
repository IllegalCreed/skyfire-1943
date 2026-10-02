extends RefCounted
## Cloud motion must not flatten with the sea horizon in high-altitude flight.

const FLIGHT := preload("res://src/gameplay/chase_flight.gd")
const SKY := preload("res://src/rendering/chase_sky.gd")

static func run(game) -> void:
	var flight = FLIGHT.new()
	var base_y := SKY.CLOUD_BASE_Y - SKY.ROW_SPACING
	flight.position.y = 4.0
	var before: Vector2 = flight.sky_screen(0.0, base_y)
	var old_horizon: float = flight.horizon()
	flight.position.y = 5.0
	var after: Vector2 = flight.sky_screen(0.0, base_y)
	assert(after.y - before.y > 114.9 and flight.horizon() - old_horizon < 2,
		"A high climb still scrolls clouds even when the offscreen sea horizon barely moves")
	# Exercise the actual drawn cloud list, not just a new helper unused by art.
	flight.position.y = 4.0
	var cloud_before := _find_cloud(SKY.clouds(flight), Vector2i(0, -1))
	flight.position.y = 5.0
	var cloud_after := _find_cloud(SKY.clouds(flight), Vector2i(0, -1))
	assert(not cloud_before.is_empty() and not cloud_after.is_empty()
		and absf(cloud_after.pos.y - cloud_before.pos.y - 115) < 0.001,
		"The same visible cloud actually moves down 115 pixels, rather than being replaced")
	# Sky remains populated throughout the all-sky altitude band and a full turn.
	for height in [FLIGHT.SEA_VISIBLE_BELOW, 3.3, 4.0, 5.0, 6.0, FLIGHT.MAX_ALTITUDE]:
		flight.position.y = height
		for climb in [-FLIGHT.CLIMB_SPEED, 0.0, FLIGHT.CLIMB_SPEED]:
			flight.climb_rate = climb
			for tick in range(60):
				flight.view_heading = tick * TAU / 60
				var visible := 0
				for cloud in SKY.clouds(flight):
					if Rect2(0, 72, 960, 425).has_point(cloud.pos): visible += 1
				assert(visible >= 2, "Upper cloud rows prevent a blank sky when lower rows leave the view")
	# Real 60 Hz climbing/descending, with frozen autonomous sky/air positions.
	flight.reset()
	flight.position.y = 3.6
	var air := Vector2(0, base_y)
	for input in [Vector2.UP, Vector2.DOWN]:
		before = flight.sky_screen(0.0, base_y)
		var initial_y := before.y
		for tick in range(60):
			flight.advance(1.0 / 60, input)
			after = flight.sky_screen(0.0, base_y)
			assert(after.distance_to(flight.air_screen(air)) < 0.001,
				"Clouds and frozen air targets use identical ascent/descent view offsets")
			# A fast control reversal also changes the existing nose-response
			# offset; allow that six-pixel response, never a 380-pixel row wrap.
			assert(absf(after.y - before.y) < 8, "Ordinary high-sky movement cannot snap or screen-wrap")
			before = after
		assert((after.y - initial_y) * -input.y > 150,
			"High climbing moves clouds down and high descending moves them up")
	# Releasing the controls settles the view; reaching the actual altitude cap
	# is different from the old premature stop at mid/high altitude.
	for tick in range(120): flight.advance(1.0 / 60, Vector2.ZERO)
	before = flight.sky_screen(0.0, base_y)
	for tick in range(60): flight.advance(1.0 / 60, Vector2.ZERO)
	assert(flight.sky_screen(0.0, base_y).distance_to(before) < 0.001, "Neutral flight does not fake a perpetual cloud drift")
	for tick in range(240): flight.advance(1.0 / 60, Vector2.UP)
	assert(is_equal_approx(flight.position.y, FLIGHT.MAX_ALTITUDE) and not flight.sea_visible(),
		"The true ceiling is retained and high climbs cannot bring the sea back")
	before = flight.sky_screen(0.0, base_y)
	for tick in range(60): flight.advance(1.0 / 60, Vector2.UP)
	assert(flight.sky_screen(0.0, base_y).distance_to(before) < 0.001, "Only the actual altitude ceiling stops sustained upward scrolling")
	flight.view_heading = TAU - 0.02
	before = flight.sky_screen(0.0, base_y)
	flight.view_heading = 0.02
	after = flight.sky_screen(0.0, base_y)
	assert(absf(after.x - before.x + 24) < 0.001 and absf(after.y - before.y) < 0.001,
		"New cloud rows retain the existing horizontal scroll and 360-degree seam")
	game.start_game()
	print("CHASE SKY PASS: high-climb cloud motion, shared airfield Y, persistent rows, full-turn coverage, ascent/descent/neutral/ceiling, unchanged horizontal seam")

static func _find_cloud(items: Array[Dictionary], id: Vector2i) -> Dictionary:
	for item in items:
		if item.id == id: return item
	return {}
