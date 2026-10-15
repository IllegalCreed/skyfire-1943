extends RefCounted
## Single-player vertical slice. The sandbox's cyclic spawner is never run here.

const BOSS := preload("res://src/gameplay/chase_boss.gd")
const DURATIONS := [28.0,26.0]
const EVENTS := [
	[{"at":2.0,"type":"wave","kinds":["interceptor"],"gentle":true},
	 {"at":9.0,"type":"wave","kinds":["raider"],"gentle":true},
	 {"at":16.0,"type":"wave","kinds":["courier"]},
	 {"at":22.0,"type":"wave","kinds":["bomber"]},
	 {"at":24.0,"type":"supply"}],
	[{"at":1.5,"type":"wave","kinds":["interceptor","raider"]},
	 {"at":7.5,"type":"wave","kinds":["interceptor","interceptor"],"vessel":"escort"},
	 {"at":13.0,"type":"wave","kinds":["raider","bomber"]},
	 {"at":19.0,"type":"wave","kinds":["courier"]},
	 {"at":22.0,"type":"supply"}]
]

var active := false
var phase := 0
var phase_time := 0.0
var time := 0.0
var cursor := 0
var dispatched: Array[String] = []
var boss_hp := BOSS.MAX_HP
var boss_spawned := false
var previewed := false
var spawned_targets := 0
var defeated_targets := 0
var supplies_collected := 0
var earned_bonus := 0
var result := ""
var notice := ""
var notice_time := 0.0
var saved_position := Vector3(0,3.3,0)
var saved_heading := 0.0

func reset() -> void:
	active=false
	phase=0
	phase_time=0
	time=0
	cursor=0
	dispatched.clear()
	boss_hp=BOSS.MAX_HP
	boss_spawned=false
	previewed=false
	spawned_targets=0
	defeated_targets=0
	supplies_collected=0
	earned_bonus=0
	result=""
	notice=""
	notice_time=0
	saved_position=Vector3(0,3.3,0)
	saved_heading=0

func start() -> void:
	reset()
	active=true
	announce("破晓突袭 · 突破拦截线，清除沿岸火力",3.5)

func announce(message: String, seconds := 2.8) -> void:
	notice=message
	notice_time=seconds

func update(game, delta: float) -> void:
	if not active or not result.is_empty(): return
	if game.game_over:
		result="failed"
		return
	time+=delta
	notice_time=maxf(0,notice_time-delta)
	if game.transition>0: return
	phase_time+=delta
	if phase<2:
		if not previewed and phase_time>=DURATIONS[phase]-3:
			previewed=true
			announce("电台：前方沿岸火力，准备切入对海攻击" if phase==0 else "电台：重型拦截机接近，准备重返空域迎战",3.0)
		var events: Array = EVENTS[phase]
		while cursor<events.size() and phase_time+0.000001>=events[cursor].at:
			var event: Dictionary = events[cursor]
			if event.type=="wave":
				if not game._spawn_mission_wave(event): break
			else: game._spawn_mission_supply()
			dispatched.append("%d:%d"%[phase,cursor])
			cursor+=1
		if phase_time>=DURATIONS[phase] and cursor==events.size():
			# Let every remaining visible aircraft really leave; then use a clear seam.
			if not game.enemies.is_empty():
				if notice_time<=0: announce("拦截力量尚未离场 · 清空后进入下一航段",1.0)
				return
			if phase==0:
				saved_position=game.flight.position
				saved_heading=game.flight.heading
				game._begin_mission_transition(game.Mode.TOP,1)
			else:
				game._begin_mission_transition(game.Mode.CHASE,2)
	else:
		if not boss_spawned:
			boss_spawned=true
			game.enemies.append(BOSS.make_enemy(game.flight,boss_hp))
			spawned_targets+=1

func phase_title() -> String:
	return ["突破拦截","沿岸扫荡","海鸥决战"][phase]

func objective() -> String:
	if phase==0: return "等敌机接近后射击 · 金色快机击落掉补给"
	if phase==1: return "清除敌方炮舰 · 穿过沿岸火网"
	return "海鸥保持交战距离 · 跟踪摆动，瞄准机鼻"
