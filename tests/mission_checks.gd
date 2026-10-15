extends RefCounted

const GUN := preload("res://src/gameplay/chase_gun.gd")
const BOSS := preload("res://src/gameplay/chase_boss.gd")
const ENCOUNTER := preload("res://src/gameplay/chase_encounter.gd")

static func pilot_input(game) -> Vector2:
	# Test/capture-only pilot. It uses the real flight, collision, energy and gun path.
	var ship: Vector2 = game._ship_screen()
	var direction := Vector2.ZERO
	if game.mode==game.Mode.CHASE:
		var target: Dictionary = {}
		for enemy in game.enemies:
			if enemy.surface or not game._entity_visible(enemy) or game._enemy_depth(enemy)>145: continue
			if not enemy.get("boss",false) and ENCOUNTER.escaping(enemy): continue
			target=enemy
			break
		if not target.is_empty():
			var projected := target.duplicate()
			projected.age+=16.0/60
			if projected.get("boss",false): BOSS.update(projected)
			else: ENCOUNTER.update(projected)
			var offset: Vector2 = game._entity_screen(projected)-game.flight.aim_screen()
			direction=Vector2(clampf(offset.x/130,-0.65,0.65),clampf(offset.y/180,-0.6,0.6))
		else:
			for pickup in game.pickups:
				if not pickup.get("air_pickup",false): continue
				var offset: Vector2 = game._entity_screen(pickup)-ship
				direction=Vector2(clampf(offset.x/130,-0.6,0.6),clampf(offset.y/160,-0.5,0.5))
		for bullet in game.hostile:
			if bullet.get("air_bullet",false) and game._entity_screen(bullet).distance_to(ship)<80:
				direction.x=-0.8 if game._entity_screen(bullet).x>ship.x else 0.8
		if game.flight.position.y<1.2: direction.y=minf(direction.y,-0.5)
		if game.flight.position.y>5.8: direction.y=maxf(direction.y,0.5)
	else:
		var target := Vector2(480,365)
		for enemy in game.enemies:
			if enemy.p.y>30 and enemy.p.y<310: target.x=enemy.p.x; break
		for pickup in game.pickups:
			if pickup.p.y>240:
				target=pickup.p
				break
		direction=(target-ship)/Vector2(130,140)
		direction=direction.limit_length(0.7)
		for bullet in game.hostile:
			if bullet.p.distance_to(ship)<85: direction.x=-0.8 if bullet.p.x>ship.x else 0.8
	return direction

static func run(game) -> void:
	var developer: bool = game.developer_mode
	game.start_mission()
	assert(game.mission_overlay.health.size.y<=6,"Boss health bar does not cover armour-state text")
	var key := InputEventKey.new()
	key.keycode=KEY_1
	key.pressed=true
	game._unhandled_input(key)
	assert(game.mode==game.Mode.CHASE,"Mission rejects sandbox view shortcuts")
	game.paused=true
	var before: float = game.mission.time
	game._process(0.5)
	assert(game.mission.time==before,"Paused mission timeline is frozen")
	game.resume_game()
	# A wave waits for capacity rather than being duplicated or overriding the cap.
	game.transition=0
	game.mission.phase_time=2
	for i in range(3): game.enemies.append(ENCOUNTER.make_enemy(game.flight,1,i))
	game.mission.update(game,0)
	assert(game.mission.cursor==0 and game.enemies.size()==3,"Scripted wave waits for air capacity")
	game.enemies.clear()
	game.mission.update(game,0)
	game.mission.update(game,0)
	assert(game.mission.cursor==1 and game.enemies.size()==1 and game.wave==1,"Script event dispatches exactly once")
	game.mission.phase_time=28
	game.mission.cursor=5
	game.mission.update(game,0)
	assert(game.mission.phase==0 and game.enemies.size()==1,"Transition never age-deletes a remaining visible enemy")
	# Full non-shooting road validates the timeline independently of combat survival.
	game.start_mission()
	var phases: Dictionary = {}
	for frame in range(4200):
		game.invulnerable=999
		game.step(1.0/60,Vector2.ZERO,false)
		phases[game.mission.phase]=true
		if game.mode==game.Mode.CHASE:
			assert(game.enemies.size()<=3 and game.hostile.size()<=6,"Mission retains chase encounter/fire caps")
		else: assert(game.enemies.size()<=6,"Top mission avoids stacked waves")
	assert(phases.size()==3 and game.mission.dispatched.size()==10 and game.wave==8,"All road events and three phases run without cyclic spawner")
	assert(game.mission.spawned_targets==13 and game.mission.boss_hp==BOSS.MAX_HP,"Eight waves, one ship and one persistent Boss identity")
	game.mission.time=120
	game.mission.update(game,0)
	assert(not game.victory and game.mission.boss_hp==BOSS.MAX_HP,"Time alone can never win or damage the Boss")
	for side in [-1,1]:
		game.start_mission()
		game.transition=0
		game.mission.phase=2
		game.mission.update(game,0)
		var pursued: Dictionary = game.enemies[0]
		for frame in range(1800):
			game.invulnerable=999
			game.step(1.0/60,Vector2(side,0),false)
			assert(game.enemies.size()==1 and game.enemies[0]==pursued,"Boss stays the same entity even outside the observation window")
			if pursued.age>=BOSS.ENTRY_SECONDS:
				assert(is_equal_approx(pursued.chase_depth,BOSS.HOLD_DEPTH),"Boss stops approaching after arrival, regardless of camera turns")
		assert(game.mission.spawned_targets==1 and game.kills==0,"Turning never respawns, kills or scores the Boss")
	# Supplies/energy/firepower and flight orientation survive both real view seams.
	game.start_mission()
	game.energy=37
	game.score=987
	game.power=2
	game.flight.position=Vector3(12,4.6,-75)
	game.flight.heading=1.2
	game.flight.view_heading=1.2
	game.mission.saved_position=game.flight.position
	game.mission.saved_heading=game.flight.heading
	game.pickups.append({"air_pickup":true,"air_position":game.flight.air_position_from_screen(game._ship_screen()-Vector2(0,100)),"bonus_drop":true,"life":9.0})
	game._switch_mission_mode(game.Mode.TOP)
	assert(game.energy==37 and game.score==987 and game.power==2 and game.pickups.size()==1,"Transition carries an uncollected supply without awarding it")
	game._switch_mission_mode(game.Mode.CHASE)
	assert(game.pickups.size()==1 and game.pickups[0].air_pickup and game.pickups[0].bonus_drop,"Pickup converts back, keeping one identity and bonus flag")
	assert(game.flight.position==Vector3(12,4.6,-75) and is_equal_approx(game.flight.heading,1.2),"Chase orientation and altitude are restored without forced low flight")
	before=game.energy
	game.step(1.0/60,Vector2.ZERO,false)
	assert(game.energy==before,"Mission transition does not drain energy")
	# The cinematic camera has a midpoint commit, continuous aircraft pose and frozen combat.
	game.start_mission()
	game.transition=0
	game.mission.phase_time=28
	game.mission.cursor=5
	game.pickups.append({"p":Vector2(480,200),"life":9.0})
	game.pickups[0]={"air_pickup":true,"air_position":game.flight.air_position_from_screen(Vector2(480,220)),"life":9.0}
	game.mission.update(game,0)
	assert(game.view_transition.active and game.mode==game.Mode.CHASE,"Mission begins a bridge, not an instant perspective cut")
	before=game.energy
	var clock_before: float = game.mission.phase_time
	var previous: Vector2 = game.view_transition.source_plane.position
	game.paused=true
	var frozen: float = game.view_transition.elapsed
	game._process(0.5)
	assert(game.view_transition.elapsed==frozen,"Pause freezes the camera bridge")
	game.resume_game()
	for frame in range(156):
		game.step(1.0/60,Vector2.DOWN,true)
		assert(game.view_transition.source_plane.position.distance_to(previous)<3,"Our aircraft moves continuously through the view change")
		previous=game.view_transition.source_plane.position
		assert(game.shots.is_empty() and game.hostile.is_empty() and game.energy==before,"No firing, hidden attacks or energy drain during bridge")
		assert(is_equal_approx(game.pickups[0].life,9.0),"Uncollected pickup lifetime freezes across the bridge")
		if frame<75: assert(game.mode==game.Mode.CHASE and game.mission.phase_time==clock_before,"Old logical view remains until midpoint")
		if frame>80: assert(game.mode==game.Mode.TOP and game.mission.phase==1,"New view commits beneath the veil")
	assert(not game.view_transition.active and game.pickups.size()==1,"Bridge finishes once, preserving one supply")
	assert(game.view_transition.target_plane.position.distance_to(game._ship_screen()-Vector2(0,66))<0.001 and is_zero_approx(game.bank),"Cinematic aircraft endpoint exactly matches the live player pose")
	assert(game.view_transition.aircraft_grace>0,"Normal protection does not make the aircraft disappear at the camera endpoint")
	game.return_to_menu()
	assert(not game.view_transition.active,"Return to menu clears pending cinematic state")
	# The physical viewport/frame cap does not become the mission's simulation clock.
	var saved_keys: Dictionary = game.controls._keys.duplicate()
	var saved_mode: int = game.controls.input_mode
	game.controls.input_mode=1
	for action in game.controls.ACTIONS:
		game.controls._keys[game.controls.bindings[action]]=false
		for alias in game.controls.ALTERNATE_KEYS[action]: game.controls._keys[alias]=false
	var expected_clock: Dictionary = {}
	for rate in [30,60,144]:
		game.start_mission()
		for frame in range(rate*12): game._process(1.0/rate)
		var clock := {"ticks":roundi(game.mission.time*60),"phase":game.mission.phase,"events":game.mission.dispatched.duplicate(),"wave":game.wave}
		if expected_clock.is_empty(): expected_clock=clock
		else: assert(clock==expected_clock,"30/60/144 Hz display updates share the same mission timeline")
	game.controls._keys=saved_keys
	game.controls.input_mode=saved_mode
	# Mission ships neither shoot nor take damage while still hidden behind the HUD.
	game.start_mission()
	game.switch_mode(game.Mode.TOP)
	var entering := {"p":Vector2(480,30),"hp":7,"surface":true,"vessel":"escort"}
	game.enemies.append(entering)
	game.shots.append({"p":Vector2(480,100),"v":Vector2(0,-620),"surface":false})
	game._update_shots(0.12)
	game._fire_enemy(entering)
	assert(entering.hp==7 and game.hostile.is_empty(),"HUD-hidden mission ship cannot be shot or fire invisible attacks")
	entering.p.y=150
	game.shots.clear()
	game.shots.append({"p":Vector2(480,300),"v":Vector2(0,-620),"surface":false})
	game._update_shots(0.25)
	game._fire_enemy(entering)
	assert(entering.hp==6 and game.hostile.size()==1,"Visible mission ship uses real swept damage and cannon fire")
	game.hostile.clear()
	entering.p.y=516
	game._fire_enemy(entering)
	assert(game.hostile.is_empty(),"Ship cannot launch from underneath the footer either")
	# Hit the actual Boss through exactly the same twin-gun collision path.
	game.start_mission()
	game.transition=0
	game.mission.phase=2
	game.mission.update(game,0)
	var boss: Dictionary = game.enemies[0]
	boss.age=6.0
	var pair := GUN.make_pair(game.flight)
	var positions := GUN.positions(pair,game.flight,16.0/60)
	boss.air_position=game.flight.air_position_from_screen((positions[0]+positions[1])*0.5)
	boss.chase_depth=80
	game.shots.append(pair)
	game._update_shots(15.0/60)
	assert(boss.hp==BOSS.MAX_HP,"Boss cannot be hit before frame 16")
	game._update_shots(1.0/60)
	assert(boss.hp==BOSS.MAX_HP-1 and game.mission.boss_hp==boss.hp and game.shots.is_empty(),"One valid pair consumes one Boss HP")
	# Large ages do not restart its approach; motion is bounded at the fixed depth.
	var horizontal_extent := 0.0
	var vertical_extent := 0.0
	for tick in range(3600):
		boss.age=BOSS.ENTRY_SECONDS+tick/60.0
		BOSS.update(boss)
		assert(is_equal_approx(boss.chase_depth,BOSS.HOLD_DEPTH),"Boss depth stays fixed throughout prolonged combat")
		var offset: Vector2 = boss.air_position-boss.route_end
		horizontal_extent=maxf(horizontal_extent,absf(offset.x))
		vertical_extent=maxf(vertical_extent,absf(offset.y))
		assert(absf(offset.x)<=BOSS.SWAY_X+0.01 and absf(offset.y)<=BOSS.SWAY_Y+0.01,"Boss evasion stays bounded, never becomes a lateral escape")
	assert(horizontal_extent>60 and vertical_extent>15,"Both horizontal and vertical evasion are real motion")
	assert(boss.hp==BOSS.MAX_HP-1,"Motion and elapsed time never reset Boss damage")
	var view_before: Vector2 = boss.air_position
	var bank_before: float = boss.bank
	game.flight.heading=1.6
	game.flight.view_heading=1.6
	BOSS.update(boss)
	assert(boss.air_position==view_before and boss.bank==bank_before,"Camera turns cannot change the Boss's autonomous route or bank")
	game.flight.heading=0
	game.flight.view_heading=0
	for hit in range(BOSS.MAX_HP-1):
		boss.age=6.0
		pair=GUN.make_pair(game.flight)
		positions=GUN.positions(pair,game.flight,16.0/60)
		boss.air_position=game.flight.air_position_from_screen((positions[0]+positions[1])*0.5)
		boss.chase_depth=80
		game.shots.append(pair)
		game._update_shots(16.0/60)
	assert(game.victory and not game.game_over and game.mission.result=="won","Boss must be actually destroyed to win")
	var final_score: int = game.score
	game._finish_mission()
	game.step(1.0/60,Vector2.ZERO,true)
	before=game.energy
	game.special()
	game.invulnerable=0
	game.damage(12)
	assert(game.energy==before,"Victory cannot spend energy or receive damage")
	assert(game.score==final_score and final_score==4400 and game.mission.defeated_targets==1,"Boss, clear and energy bonuses cannot duplicate")
	game.menu.sync_game_state()
	assert(game.menu.page=="victory" and game.menu.buttons.has("retry"),"Victory has result, retry and main navigation")
	game.restart_session()
	assert(game.mission.active and game.mission.phase==0 and game.energy==100 and game.score==0 and game.mission.boss_hp==BOSS.MAX_HP,"Mission retry resets the full timeline and rewards")
	game.energy=0
	game.transition=0
	game.step(1.0/60,Vector2.ZERO,false)
	game.menu.sync_game_state()
	assert(game.game_over and not game.victory and game.menu.page=="over" and game.mission.result=="failed","Failure is distinct from victory")
	game.restart_session()
	assert(not game.game_over and game.mission.result.is_empty(),"Failed mission can restart")
	# No invulnerability, health refill, forced damage or assisted hit in this pilot run.
	game.start_mission()
	for frame in range(9600):
		game.step(1.0/60,pilot_input(game),true)
		if game.victory or game.game_over: break
	print("MISSION PILOT: result=",game.mission.result," time=",game.mission.time," energy=",game.energy," hp=",game.mission.boss_hp," kills=",game.kills," supplies=",game.mission.supplies_collected)
	assert(game.victory,"Controlled real-combat pilot completes the single-player slice")
	game.developer_mode=developer
	game.developer_mode=true
	game.start_debug_scene("boss")
	assert(game.enemies.size()==1 and game.enemies[0].boss and game.mission.phase==2,"Boss debug scene starts its real actor immediately")
	game.mission.boss_hp=3
	game.restart_session()
	assert(game.debug_scene=="boss" and game.enemies[0].hp==BOSS.MAX_HP,"Boss debug retry preserves the chosen scenario")
	game.developer_mode=developer
	game.return_to_menu()
	print("MISSION PASS: scripted caps, cinematic continuity/pause/carry, fixed-depth evasive Boss, unchanged frame hits, victory/failure/retry and real-combat pilot")
