extends RefCounted
## Visual-only pose controller. Never feeds flight, collision or gun simulation.

const TRAVEL_PER_SECOND := 6.25 # neutral to full bank in 0.16 seconds
var roll := 0.0 # normalized -1..1
var pitch := 0.0

func reset() -> void:
	roll=0
	pitch=0

func advance(delta: float, view: int, movement: Vector2, climb_fraction: float) -> void:
	var roll_target := movement.y if view==0 else movement.x
	var pitch_target := clampf(climb_fraction,-1,1) if view==2 else 0.0
	roll=move_toward(roll,clampf(roll_target,-1,1),delta*TRAVEL_PER_SECOND)
	pitch=move_toward(pitch,pitch_target,delta*TRAVEL_PER_SECOND)

func value() -> Vector2:
	return Vector2(roll,pitch)
