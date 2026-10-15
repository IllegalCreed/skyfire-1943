extends RefCounted

const ROSTER := preload("res://src/gameplay/enemy_roster.gd")
const ENCOUNTER := preload("res://src/gameplay/chase_encounter.gd")
const GUN := preload("res://src/gameplay/chase_gun.gd")
const ART := preload("res://src/rendering/aircraft_art.gd")
const EXIT := preload("res://tests/chase_exit_checks.gd")

static func run(game) -> void:
	var spec := ROSTER.profile(ROSTER.BONUS_KIND)
	assert(spec.speed_side > ROSTER.profile("raider").speed_side and spec.speed_top > ROSTER.profile("raider").speed_top, "Reward enemy outruns ordinary aircraft in 2D")
	assert(spec.duration < ROSTER.profile("interceptor").duration, "Reward enemy approaches and leaves faster in chase")
	for side in [-1,1]: EXIT._check_pursuit(game,side,0,0,false,ROSTER.BONUS_KIND,false)
	for mode in [game.Mode.SIDE,game.Mode.TOP,game.Mode.CHASE]:
		game.start_game()
		game.switch_mode(mode)
		game._clear_combat()
		game.wave = ROSTER.BONUS_INTERVAL-1
		game.spawn_wave()
		var found := -1
		for i in range(game.enemies.size()):
			if game.enemies[i].get("kind","") == ROSTER.BONUS_KIND: found = i
		assert(found >= 0, "Reward enemy appears in every space's real waves")
		game.kills = 0
		game._destroy_enemy(found)
		assert(game.pickups.size() == 1 and game.pickups[0].bonus_drop, "First kill still drops the guaranteed reward")
		game.energy = 60
		game.power = 1
		if mode == game.Mode.CHASE: game.pickups[0].air_position = game.flight.air_position_from_screen(game._ship_screen())
		else: game.pickups[0].p = game.player*game.SIZE
		game._update_pickups(0)
		assert(game.energy == 78 and game.power == 2 and game.pickups.is_empty(), "Actual collection restores energy and upgrades firepower")
	# Four-kill periodic drops must not duplicate a bonus enemy's guaranteed drop.
	game.start_game()
	game._clear_combat()
	var courier := ENCOUNTER.make_enemy(game.flight,ROSTER.BONUS_INTERVAL,0)
	var pair := GUN.make_pair(game.flight)
	var positions := GUN.positions(pair,game.flight,16.0/60)
	courier.air_position = game.flight.air_position_from_screen((positions[0]+positions[1])*0.5)
	courier.chase_depth = 60
	game.kills = 3
	game.enemies.append(courier)
	game._fire_enemy(courier)
	assert(game.hostile.is_empty(), "Courier prefers escape rather than shooting")
	game.shots.append(pair)
	game._update_shots(15.0/60)
	assert(game.enemies.size()==1 and game.pickups.is_empty(), "Reward target still cannot be hit before frame 16")
	game._update_shots(1.0/60)
	assert(game.enemies.is_empty() and game.pickups.size()==1 and game.kills==4, "Valid convergence hit yields exactly one reward")
	game.energy = 60
	game.power = 1
	for frame in range(180): game._update_pickups(1.0/60)
	assert(game.pickups.is_empty() and game.energy==78 and game.power==2, "Real convergence drop drifts into reachable flight lane without teleporting")
	# Escaping an unhit courier must not award a consolation pickup.
	game.start_game()
	game._clear_combat()
	courier = ENCOUNTER.make_enemy(game.flight,ROSTER.BONUS_INTERVAL,0)
	courier.fire = 999
	game.enemies.append(courier)
	for frame in range(600): game._update_enemies(1.0/60)
	assert(game.enemies.is_empty() and game.pickups.is_empty() and game.kills==0, "Escape is not a kill and gives no reward")
	# The redesigned wings and painted gun ends retain existing physical references.
	for kind in ROSTER.KINDS+[ROSTER.BONUS_KIND]:
		var dimensions := ART.dimensions(kind,false)
		for point in ART.front_wing(dimensions):
			assert(point.length()*GUN.PLANE_SCALES[-1]+1 < ENCOUNTER.EXIT_MARGIN, "Redesigned wing fits real full-silhouette clearance")
	for roll in [-0.34,0.0,0.34]:
		game.flight.bank = roll
		var muzzles: Array = game.flight.gun_muzzles_screen()
		for i in range(2):
			assert(muzzles[i].distance_to(game.flight.aircraft_screen()+ART.MUZZLES[i].rotated(roll)*1.35)<0.001, "Painted cannon ends match gameplay gun origins")
	game.start_game()
	print("BONUS PASS: faster rare courier, all modes, guaranteed reachable pickup, no duplicate or escape reward, unchanged hit window, art/gun bounds")
