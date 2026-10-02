extends RefCounted
## Sea framing is independent of the established airfield and nose aiming.

const FLIGHT := preload("res://src/gameplay/chase_flight.gd")

static func run(game) -> void:
	var flight = FLIGHT.new()
	assert(not flight.sea_visible(), "Default cruise must show sky, not a half-screen ocean")
	assert(is_equal_approx(FLIGHT.SEA_VISIBLE_BELOW / FLIGHT.MAX_ALTITUDE, 1.0 / 3),
		"Sea entry matches the lower-third mark on the altitude bar")
	for height in [FLIGHT.SEA_VISIBLE_BELOW, 2.2, 3.3, 4.8, FLIGHT.MAX_ALTITUDE]:
		flight.position.y = height
		for climb in [-FLIGHT.CLIMB_SPEED, 0.0, FLIGHT.CLIMB_SPEED]:
			flight.climb_rate = climb
			assert(not flight.sea_visible() and flight.horizon() >= FLIGHT.SEA_VIEW_BOTTOM,
				"Upper two-thirds stay sky-only even while descending or climbing")
	flight.climb_rate = 0
	flight.position.y = FLIGHT.SEA_VISIBLE_BELOW
	assert(absf(flight.horizon() - FLIGHT.SEA_VIEW_BOTTOM) < 0.001, "Sea first meets the playable bottom, not the HUD's bottom")
	var previous := -INF
	for tick in range(601):
		flight.position.y = lerpf(FLIGHT.SEA_LEVEL, FLIGHT.MAX_ALTITUDE, tick / 600.0)
		var horizon: float = flight.horizon()
		assert(horizon > previous, "Descending raises the sea smoothly across the entire altitude range")
		assert(horizon <= FLIGHT.SEA_VIEW_BOTTOM + FLIGHT.SKY_OVERSCAN,
			"Offscreen sea horizon stays bounded independently of the scrolling clouds")
		previous = horizon
	# Check continuous position and slope at the entry, not an on/off sea sprite.
	flight.position.y = FLIGHT.SEA_VISIBLE_BELOW - 0.001
	var below: float = flight.horizon()
	flight.position.y = FLIGHT.SEA_VISIBLE_BELOW + 0.001
	var above: float = flight.horizon()
	assert(below < FLIGHT.SEA_VIEW_BOTTOM and above > FLIGHT.SEA_VIEW_BOTTOM and above - below < 0.5,
		"Crossing the entry threshold cannot jump the sea up the screen")
	assert(absf((FLIGHT.SEA_VIEW_BOTTOM - below) - (above - FLIGHT.SEA_VIEW_BOTTOM)) < 0.001,
		"Sea scrolling speed also remains continuous at the threshold")
	flight.position.y = FLIGHT.SEA_VISIBLE_BELOW - 0.1
	assert(flight.sea_visible() and FLIGHT.SEA_VIEW_BOTTOM - flight.horizon() < 25,
		"First descent into the lower third exposes only a narrow strip")
	flight.position.y = FLIGHT.SEA_LEVEL
	assert(absf(flight.horizon() - FLIGHT.SEA_NEAR_HORIZON) < 0.001, "The ocean fills the view only near sea impact")
	# Keep all pre-existing vertical airfield motion, including short response lag.
	for height in [0.3, 1.05, 2.0, FLIGHT.SEA_VISIBLE_BELOW, 3.3, 5.0, FLIGHT.MAX_ALTITUDE]:
		flight.position.y = height
		for climb in [-FLIGHT.CLIMB_SPEED, 0.0, FLIGHT.CLIMB_SPEED]:
			flight.climb_rate = climb
			var expected: float = (flight.position.y - 3.3) * 115 + climb * 12
			assert(absf(flight.air_scroll_y() - expected) < 0.001,
				"Reframing the sea cannot reframe airborne targets or supplies")
			var screen := Vector2(515, 240)
			assert(flight.air_screen(flight.air_position_from_screen(screen)).distance_to(screen) < 0.001,
				"Airfield inverse is unchanged at every sea-framing height")
	# A close ship could previously poke into the field even with an offscreen
	# horizon. Visibility must also exclude surface silhouettes and their fire.
	game.start_game()
	var boat := {"p": Vector3(0, 0.22, -1), "surface": true}
	assert(game.flight.visible(boat.p), "Fixture covers a potentially protruding close ship")
	assert(not game._entity_visible(boat), "A ship cannot float in the sky-only altitude band")
	game._fire_enemy(boat)
	assert(game.hostile.is_empty(), "A hidden surface ship does not fire unseen attacks")
	game.flight.position.y = 1.5
	boat.p = Vector3(0, 0.22, -100)
	assert(game._entity_visible(boat), "Sea targets become visible again after descending")
	game._fire_enemy(boat)
	assert(game.hostile.size() == 1, "Visible sea targets retain their original firing route")
	game.start_game()
	print("CHASE HORIZON PASS: sea below 1/3 only, sky cruise, smooth entry/slope, near-sea fill, unchanged airfield, hidden surface actors")
