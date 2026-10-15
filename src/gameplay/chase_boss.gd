extends RefCounted
## One approach, then bounded autonomous evasion at a fixed engagement depth.
const MAX_HP := 8
const POINTS := 2400
const ENTRY_SECONDS := 5.0
const HOLD_DEPTH := 68.0
const SWAY_X := 84.0
const SWAY_Y := 18.0
const SWAY_RATE := 1.7 # radians / second, not an arrival/exit timer.
const DRAW_SCALE := 2.05
const VISUAL_RADIUS := 120.0

static func make_enemy(flight, hp: int) -> Dictionary:
	var start: Vector2 = flight.air_position_from_screen(Vector2(625,104))
	var end: Vector2 = flight.air_position_from_screen(Vector2(480,294))
	return {"boss":true,"boss_id":"seagull-demo","kind":"bomber","surface":false,
		"air_route":true,"air_position":start,"route_start":start,"route_end":end,
		"entry_delay":0.0,"chase_depth":220.0,"hp":hp,
		"age":0.0,"fire":ENTRY_SECONDS+0.8,"bank":0.0}

static func update(enemy: Dictionary) -> void:
	var start: Vector2 = enemy.route_start
	var end: Vector2 = enemy.route_end
	var entry := clampf(enemy.age/ENTRY_SECONDS,0,1)
	var ease := entry*entry*(3-2*entry)
	var battle := maxf(0,enemy.age-ENTRY_SECONDS)
	# Damage modestly increases sway; no camera, input or projectile is inspected.
	var damaged := clampf((MAX_HP/2.0-enemy.hp)/4.0,0,1)
	var amplitude := SWAY_X*(1+0.18*damaged)
	var fade := 1-exp(-battle*2.0)
	var clock := battle*SWAY_RATE
	var x := amplitude*(0.72*sin(clock)+0.28*sin(clock*1.83))*fade
	var y := SWAY_Y*sin(battle*0.82)*fade
	enemy.air_position=start.lerp(end,ease)+Vector2(x,y)
	enemy.chase_depth=lerpf(220.0,HOLD_DEPTH,ease)
	enemy.bank=(0.72*cos(clock)+0.28*1.83*cos(clock*1.83))*0.15*fade

static func fire_interval(hp: int) -> float:
	return 2.8 if hp<=MAX_HP/2 else 4.4

static func holding(enemy: Dictionary) -> bool:
	return enemy.age>=ENTRY_SECONDS
