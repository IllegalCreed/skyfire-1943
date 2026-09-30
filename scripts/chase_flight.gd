extends RefCounted
## World-space flight with a 2D pinhole projection. No screen-edge movement bounds.
## Altitude controls the vertically scrolling field, not just the aircraft sprite.

const SEA_LEVEL := 0.18
const LOW_ALTITUDE := 1.05
const MAX_ALTITUDE := 6.3
const SPEED := 12.0
const TURN_SPEED := 0.92
const CLIMB_SPEED := 1.55
const FOCAL := 380.0
const CAMERA_DISTANCE := 6.0

var position := Vector3(0, 3.3, 0)
var heading := 0.0
var view_heading := 0.0
var turn_rate := 0.0
var climb_rate := 0.0
var bank := 0.0
var crashed := false

func reset() -> void:
	position = Vector3(0, 3.3, 0)
	heading = 0
	view_heading = 0
	turn_rate = 0
	climb_rate = 0
	bank = 0
	crashed = false

func advance(delta: float, input: Vector2) -> void:
	if crashed: return
	# Short response lag, not a flight-simulator's long drift.
	turn_rate = lerpf(turn_rate, input.x * TURN_SPEED, 1.0 - exp(-delta * 14))
	climb_rate = lerpf(climb_rate, -input.y * CLIMB_SPEED, 1.0 - exp(-delta * 14))
	heading = wrapf(heading + turn_rate * delta, 0, TAU)
	view_heading = lerp_angle(view_heading, heading, 1.0 - exp(-delta * 16))
	bank = lerpf(bank, input.x * 0.34, 1.0 - exp(-delta * 12))
	position += forward() * SPEED * delta
	position.y += climb_rate * delta
	if position.y >= MAX_ALTITUDE:
		position.y = MAX_ALTITUDE
		climb_rate = minf(0, climb_rate)
	if position.y <= SEA_LEVEL:
		position.y = SEA_LEVEL
		crashed = true

func forward() -> Vector3:
	return Vector3(sin(heading), 0, -cos(heading))

func right() -> Vector3:
	return Vector3(cos(heading), 0, sin(heading))

func horizon() -> float:
	# Rise -> scroll the world down, eventually leaving only sky in view.
	return 210 + (position.y - 3.3) * 115 + climb_rate * 12

func aircraft_screen() -> Vector2:
	return Vector2(480 + bank * 110, clampf(380 - (position.y - 3.3) * 62 - climb_rate * 16, 175, 475))

func depth(point: Vector3) -> float:
	return (point - position).dot(Vector3(sin(view_heading), 0, -cos(view_heading))) + CAMERA_DISTANCE

func project(point: Vector3) -> Vector2:
	var distance := depth(point)
	if distance < 1.2: return Vector2(-10000, -10000)
	var relative := point - position
	var horizontal := relative.dot(Vector3(cos(view_heading), 0, sin(view_heading)))
	var anchor := aircraft_screen()
	return Vector2(anchor.x + horizontal * FOCAL / distance,
		anchor.y + (position.y - point.y) * FOCAL / distance
		+ (horizon() - anchor.y) * (1.0 - CAMERA_DISTANCE / distance))

func visible(point: Vector3) -> bool:
	return depth(point) > 1.2 and Rect2(-90, 65, 1140, 520).has_point(project(point))

func bearing_screen(bearing: float) -> float:
	return aircraft_screen().x + wrapf(bearing - view_heading, -PI, PI) * 600
