extends RefCounted
## Original scripted pseudo-3D approach, independent of player camera turns.
## The FC research informs high entries/shared scroll, not copied route tables.

const ROSTER := preload("res://src/gameplay/enemy_roster.gd")

const GAP := 6.8
const MAX_AIRCRAFT := 3
const ENTRY_Y := 112.0
const EXIT_START := 0.72
const EXIT_ACCELERATION := 800.0
# Faster than maximum player airfield scroll (0.92 * 600 = 552 px/s).
# This is an autonomous escape, not an enemy position tied to the camera.
const EXIT_SPEED := 1400.0
const EXIT_BANK := 1.12
# Conservative radius of the largest, rotated aircraft, plus clearance.
const EXIT_MARGIN := 64.0
const VIEW_WIDTH := 960.0

static func make_enemy(flight, wave: int, index: int) -> Dictionary:
	var kind := ROSTER.kind_for_wave(wave, index)
	var spec := ROSTER.profile(kind)
	var side := -1.0 if wave % 2 == 0 else 1.0
	var entry := Vector2(480 + side * (115 + index * 32), ENTRY_Y + index * 20)
	var start: Vector2 = flight.air_position_from_screen(entry)
	var end: Vector2 = flight.air_position_from_screen(Vector2(480, 465))
	return {"air_route": true, "air_position": start, "route_start": start,
		"route_end": end, "route_duration": spec.duration + index * 0.45, "kind": kind,
		"entry_delay": index * 0.7, "exit_sign": side, "chase_depth": 220.0,
		"hp": spec.hp, "age": 0.0, "fire": 2.8 + index * 0.7,
		"surface": false, "bank": 0.0}

static func update(enemy: Dictionary) -> void:
	var t := clampf((enemy.age - enemy.entry_delay) / enemy.route_duration, 0, 1)
	var exit_age := maxf(0, enemy.age - enemy.entry_delay - enemy.route_duration * EXIT_START)
	var acceleration_time := minf(exit_age, EXIT_SPEED / EXIT_ACCELERATION)
	# Integrate acceleration, then continue at full speed without an age clamp.
	var lateral := 0.5 * EXIT_ACCELERATION * acceleration_time * acceleration_time \
		+ EXIT_SPEED * (exit_age - acceleration_time)
	var start: Vector2 = enemy.route_start
	var end: Vector2 = enemy.route_end
	var approach := clampf(t / EXIT_START, 0, 1)
	var weave: float = ROSTER.profile(enemy.get("kind", "interceptor")).weave \
		* sin(approach * TAU * 1.2) * pow(sin(approach * PI), 2)
	enemy.air_position = Vector2(lerpf(start.x, end.x, minf(t, EXIT_START) * 0.7)
		+ enemy.exit_sign * (lateral + weave),
		lerpf(start.y, end.y, pow(t, 1.6)))
	enemy.chase_depth = lerpf(220.0, 12.0, t)
	enemy.bank = enemy.exit_sign * EXIT_BANK * (1.0 - exp(-exit_age * 3.4))

static func entered(enemy: Dictionary) -> bool:
	return enemy.age >= enemy.entry_delay

static func escaping(enemy: Dictionary) -> bool:
	return enemy.age > enemy.entry_delay + enemy.route_duration * EXIT_START

static func finished(enemy: Dictionary, flight) -> bool:
	if not escaping(enemy): return false
	var screen: Vector2 = flight.air_screen(enemy.air_position)
	# Never retire a visible aircraft because its scripted approach has ended.
	# The full silhouette must clear a lateral edge before it is removed.
	return screen.x < -EXIT_MARGIN or screen.x > VIEW_WIDTH + EXIT_MARGIN
