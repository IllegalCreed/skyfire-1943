extends RefCounted
## World-space flight with shared angular scrolling and vertical pseudo-3D depth.
## Altitude controls the vertically scrolling field, not just the aircraft sprite.

const SEA_LEVEL := 0.18
const LOW_ALTITUDE := 1.05
const MAX_ALTITUDE := 6.3
const SEA_VISIBLE_BELOW := MAX_ALTITUDE / 3.0
# The playable bottom excludes the 34-pixel footer. At the one-third mark,
# the sea first reaches that edge, rather than already filling half the view.
const SEA_VIEW_BOTTOM := 506.0
const SEA_NEAR_HORIZON := 80.0
const SKY_OVERSCAN := 100.0
const SEA_SCROLL_RATE := (SEA_VIEW_BOTTOM - SEA_NEAR_HORIZON) / (SEA_VISIBLE_BELOW - SEA_LEVEL)
const SPEED := 12.0
const TURN_SPEED := 0.92
const CLIMB_SPEED := 1.55
const FOCAL := 380.0
const CAMERA_DISTANCE := 6.0
const AIR_SCROLL_SCALE := 600.0

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
	# Sea enters only in the lower third of the altitude bar. Low flight raises
	# it continuously; above that band the horizon eases outside the viewport.
	var height := position.y - SEA_VISIBLE_BELOW
	if absf(height) < 0.000001: height = 0.0
	if height <= 0: return SEA_VIEW_BOTTOM + height * SEA_SCROLL_RATE
	return SEA_VIEW_BOTTOM + SKY_OVERSCAN * (1.0 - exp(-height * SEA_SCROLL_RATE / SKY_OVERSCAN))

func sea_visible() -> bool:
	return horizon() < SEA_VIEW_BOTTOM

func aircraft_screen() -> Vector2:
	return Vector2(480 + bank * 110, clampf(380 - (position.y - 3.3) * 62 - climb_rate * 16, 175, 475))

func aim_screen() -> Vector2:
	# FC-style air fire is a screen-space convergence cue, not a projected
	# horizontal world ray. It must remain in front of the nose at every altitude.
	return aircraft_screen() + Vector2(0, -74 - climb_rate * 6).rotated(bank)

func gun_muzzles_screen() -> Array[Vector2]:
	var anchor := aircraft_screen()
	return [anchor + Vector2(-18.5, -3).rotated(bank) * 1.35,
		anchor + Vector2(18.5, -3).rotated(bank) * 1.35]

func air_scroll_y() -> float:
	# Air targeting keeps its established vertical scroll. Reframing the sea
	# must not shift enemies, old bullets, supplies or their convergence timing.
	return (position.y - 3.3) * 115 + climb_rate * 12

func sky_screen(bearing: float, base_y: float) -> Vector2:
	# Clouds are part of the vertically scrolling airfield, not attached to
	# the sea's bounded horizon. High-altitude climbs must still move the sky.
	return Vector2(bearing_screen(bearing), base_y + air_scroll_y())

func air_position_from_screen(screen: Vector2) -> Vector2:
	return Vector2(view_heading * AIR_SCROLL_SCALE + screen.x - 480.0, screen.y - air_scroll_y())

func air_screen(air_position: Vector2) -> Vector2:
	# A shared wrapping 2D airfield, like the FC's scroll subtraction. Turning
	# shifts every air target equally; it cannot change their Y, size or route.
	return Vector2(bearing_screen(air_position.x / AIR_SCROLL_SCALE), air_position.y + air_scroll_y())

func point_from_screen(screen: Vector2, distance: float) -> Vector3:
	# Exact inverse of the shared angular X and range-based vertical projection.
	# Distance remains a pseudo-3D scale coordinate, not altitude in metres.
	var anchor := aircraft_screen()
	var bearing := view_heading + (screen.x - 480.0) / AIR_SCROLL_SCALE
	var vertical := (screen.y - anchor.y
		- (horizon() - anchor.y) * (1.0 - CAMERA_DISTANCE / distance)) * distance / FOCAL
	return camera_position() + Vector3(sin(bearing), 0, -cos(bearing)) * distance - Vector3.UP * vertical

func camera_position() -> Vector3:
	# The eye is behind the aircraft in world space. Rotate the view around
	# that eye, not around a per-object pinhole or a banked screen-space anchor.
	return position - forward() * CAMERA_DISTANCE

func depth(point: Vector3) -> float:
	# Looking sideways must not shrink the sea range or inflate a stationary
	# ship. Forward travel still changes range, scale and genuine near parallax.
	var relative := point - camera_position()
	return Vector2(relative.x, relative.z).length()

func project(point: Vector3) -> Vector2:
	var distance := depth(point)
	if distance < 1.2: return Vector2(-10000, -10000)
	var relative := point - camera_position()
	var anchor := aircraft_screen()
	# Use the same heading subtraction as clouds, islands and airborne targets.
	# Bank only moves our aircraft/aim, never the world beneath it. Avoid a tan
	# projection here: its accelerating edge scroll disagrees with the airfield.
	return Vector2(bearing_screen(atan2(relative.x, -relative.z)),
		anchor.y + (position.y - point.y) * FOCAL / distance
		+ (horizon() - anchor.y) * (1.0 - CAMERA_DISTANCE / distance))

func visible(point: Vector3) -> bool:
	return depth(point) > 1.2 and Rect2(-90, 65, 1140, 520).has_point(project(point))

func bearing_screen(bearing: float) -> float:
	return 480.0 + wrapf(bearing - view_heading, -PI, PI) * AIR_SCROLL_SCALE
