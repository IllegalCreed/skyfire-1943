extends RefCounted
## Original screen-space twin-gun implementation informed by FC ROM analysis.
## No ROM bytes, artwork, or original trajectory tables are embedded here.

const FPS := 60.0
const FIRST_HIT_FRAME := 16
const LAST_PATH_FRAME := 19
const EXPIRE_FRAME := 20
const MAX_PAIRS := 3
const PIXEL_SCALE := 2.25
const HIT_RADII := [Vector2.ZERO, Vector2(2, 2), Vector2(4, 3),
	Vector2(6, 6), Vector2(7, 7), Vector2(8, 9)]
# These world-depth thresholds are our prototype tuning, not NES constants.
const STAGE_DEPTHS := [180.0, 145.0, 110.0, 78.0, 48.0]
const PLANE_SCALES := [0.12, 0.18, 0.28, 0.42, 0.62, 0.92]

static func make_pair(flight) -> Dictionary:
	return {"air_pair": true, "surface": false, "age": 0.0,
		"muzzles": flight.gun_muzzles_screen(), "focus": flight.aim_screen(),
		"anchor_y": flight.aircraft_screen().y}

static func positions(pair: Dictionary, flight, age: float = -1.0) -> Array[Vector2]:
	var progress := clampf((pair.age if age < 0 else age) * FPS / LAST_PATH_FRAME, 0, 1)
	# Horizontal aim stays as fired. Existing bullets follow vertical scrolling,
	# as in the FC game; neither stream homes onto enemies or the moving helper.
	var scroll := Vector2(0, flight.aircraft_screen().y - pair.anchor_y)
	return [pair.muzzles[0].lerp(pair.focus, progress) + scroll,
		pair.muzzles[1].lerp(pair.focus, progress) + scroll]

static func hit_midpoints(pair: Dictionary, flight, before: float, after: float) -> Array[Vector2]:
	var result: Array[Vector2] = []
	# Include each eligible frame crossed, even if a delayed update expires the
	# pair. This prevents missing the complete four-frame window on slow frames.
	for frame in range(FIRST_HIT_FRAME, LAST_PATH_FRAME + 1):
		var time := frame / FPS
		if time > before + 0.000001 and time <= after + 0.000001:
			var points := positions(pair, flight, time)
			result.append((points[0] + points[1]) * 0.5)
	if after + 0.000001 >= FIRST_HIT_FRAME / FPS and after < EXPIRE_FRAME / FPS - 0.000001:
		var points := positions(pair, flight, after)
		var midpoint := (points[0] + points[1]) * 0.5
		if result.is_empty() or result[-1].distance_to(midpoint) > 0.000001: result.append(midpoint)
	return result

static func stage(distance: float) -> int:
	if distance <= 1.2: return -1
	for i in range(STAGE_DEPTHS.size()):
		if distance >= STAGE_DEPTHS[i]: return i
	return 5

static func hits(midpoint: Vector2, target: Vector2, target_stage: int) -> bool:
	if target_stage <= 0 or target_stage > 5: return false
	var offset := (midpoint - target).abs()
	var radius: Vector2 = HIT_RADII[target_stage] * PIXEL_SCALE
	return offset.x < radius.x and offset.y < radius.y

static func points_for_stage(target_stage: int) -> int:
	return 300 if target_stage == 5 else (200 if target_stage >= 3 else 150)

static func expired(pair: Dictionary) -> bool:
	return pair.age * FPS >= EXPIRE_FRAME - 0.000001
