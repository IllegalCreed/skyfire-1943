extends RefCounted
## Original silhouettes and modest role differences, not historical aircraft.

const KINDS := ["interceptor", "raider", "bomber"]
const BONUS_KIND := "courier"
const BONUS_INTERVAL := 5
const VESSELS := {
	"escort": {"hp": 7, "fire_2d": 2.5, "fire_chase": 3.4, "bullet_2d": 155.0, "bullet_chase": 30.0},
	"cargo": {"hp": 7, "fire_2d": 5.2, "fire_chase": 5.2, "bullet_2d": 155.0, "bullet_chase": 30.0}
}
const PROFILES := {
	"interceptor": {"hp": 1, "hp_2d": 3, "duration": 5.6, "weave": 0.0,
		"speed_side": 145.0, "speed_top": 105.0, "amplitude": 42.0, "frequency": 2.4,
		"fire_chase": 3.4, "fire_2d": 2.5, "bullet_speed": 110.0, "bullet_2d": 155.0, "burst": 1},
	"raider": {"hp": 1, "hp_2d": 2, "duration": 5.3, "weave": 42.0,
		"speed_side": 158.0, "speed_top": 125.0, "amplitude": 62.0, "frequency": 2.9,
		"fire_chase": 3.8, "fire_2d": 2.8, "bullet_speed": 118.0, "bullet_2d": 165.0, "burst": 1},
	"courier": {"hp": 1, "hp_2d": 1, "duration": 4.3, "weave": 76.0,
		"speed_side": 240.0, "speed_top": 175.0, "amplitude": 80.0, "frequency": 3.8,
		"fire_chase": 5.0, "fire_2d": 5.0, "bullet_speed": 110.0, "bullet_2d": 155.0, "burst": 0},
	"bomber": {"hp": 2, "hp_2d": 5, "duration": 6.4, "weave": 0.0,
		"speed_side": 112.0, "speed_top": 80.0, "amplitude": 16.0, "frequency": 1.1,
		"fire_chase": 4.8, "fire_2d": 3.2, "bullet_speed": 95.0, "bullet_2d": 130.0, "burst": 2}
}

static func kind_for_wave(wave: int, index: int) -> String:
	if wave > 0 and wave % BONUS_INTERVAL == 0 and index == 0: return BONUS_KIND
	return KINDS[posmod(wave - 1 + index, KINDS.size())]

static func is_bonus(kind: String) -> bool:
	return kind == BONUS_KIND

static func profile(kind: String) -> Dictionary:
	return PROFILES.get(kind, PROFILES.interceptor)

static func vessel_profile(kind: String) -> Dictionary:
	return VESSELS.get(kind,VESSELS.escort)

static func shot_velocities(kind: String, direction: Vector2, chase: bool, available: int) -> Array[Vector2]:
	var spec := profile(kind)
	var shots: Array[Vector2] = []
	var count := mini(int(spec.burst), available)
	var speed: float = spec.bullet_speed if chase else spec.bullet_2d
	for i in range(count):
		var spread := (i * 2 - 1) * 0.13 if spec.burst == 2 else 0.0
		shots.append(direction.normalized().rotated(spread) * speed)
	return shots
