extends Node2D
## Three 2D-drawn modes. Chase air guns use FC-style screen-space convergence.

enum Mode { SIDE, TOP, CHASE }
const CHASE_FLIGHT := preload("res://src/gameplay/chase_flight.gd")
const CHASE_GUN := preload("res://src/gameplay/chase_gun.gd")
const CHASE_ENCOUNTER := preload("res://src/gameplay/chase_encounter.gd")
const CHASE_CHECKS := preload("res://tests/chase_combat_checks.gd")
const ENCOUNTER_CHECKS := preload("res://tests/chase_encounter_checks.gd")
const ENEMY_ROSTER := preload("res://src/gameplay/enemy_roster.gd")
const AIRCRAFT_ART := preload("res://src/rendering/aircraft_art.gd")
const VESSEL_ART := preload("res://src/rendering/vessel_art.gd")
const UNIT_CATALOG := preload("res://src/rendering/unit_catalog.gd")
const SCENE_ART := preload("res://src/rendering/scene_art.gd")
const ROSTER_CHECKS := preload("res://tests/roster_checks.gd")
const HORIZON_CHECKS := preload("res://tests/chase_horizon_checks.gd")
const SCROLL_CHECKS := preload("res://tests/chase_scroll_checks.gd")
const CHASE_SKY := preload("res://src/rendering/chase_sky.gd")
const SKY_CHECKS := preload("res://tests/chase_sky_checks.gd")
const MAIN_MENU := preload("res://src/ui/main_menu.gd")
const MENU_CHECKS := preload("res://tests/menu_checks.gd")
const BONUS_CHECKS := preload("res://tests/bonus_checks.gd")
const GUIDE_CHECKS := preload("res://tests/aim_guides_checks.gd")
const CONTROLS := preload("res://src/input/player_controls.gd")
const SETTINGS := preload("res://src/ui/settings_defaults.gd")
const SETTINGS_CHECKS := preload("res://tests/settings_checks.gd")
const MISSION := preload("res://src/gameplay/mission_director.gd")
const CHASE_BOSS := preload("res://src/gameplay/chase_boss.gd")
const BOSS_ART := preload("res://src/rendering/boss_art.gd")
const MISSION_OVERLAY := preload("res://src/ui/mission_overlay.gd")
const MISSION_CHECKS := preload("res://tests/mission_checks.gd")
const CHASE_BACKGROUND := preload("res://src/rendering/chase_background.gd")
const VIEW_TRANSITION := preload("res://src/rendering/view_transition.gd")
const PLAYER_POSE := preload("res://src/rendering/player_pose.gd")
const POSE_CHECKS := preload("res://tests/player_pose_checks.gd")
const SIZE := Vector2(960, 540)
const INK := Color("091526")
const TEAL := Color("69e6d2")
const AMBER := Color("ffba68")
const RED := Color("ff6872")
const WHITE := Color("edf7eb")
const MUTED := Color("93afb6")
const MODE_NAMES := ["01 / COASTAL PASS", "02 / ISLAND AIRFIELD", "03 / DAWN INTERCEPT"]
const MODE_NOTES := ["SIDE  /  cliffs + flak ceiling", "TOP  /  coast + armed vessels", "CHASE  /  island chain + twin guns"]

var flight = CHASE_FLIGHT.new()
var failure_reason := ""
var crash_elapsed := 0.0
var demonstration := false
var art_gallery := false
var aim_helper := false
var torpedo_helper := false
var simulation_accumulator := 0.0
const SIMULATION_STEP := 1.0 / 60.0

var mode := Mode.CHASE
var player := Vector2(0.5, 0.64)
var energy := 100.0
var score := 0
var kills := 0
var power := 1
var wave := 0
var elapsed := 0.0
var visual_time := 0.0
var bank := 0.0
var player_pose = PLAYER_POSE.new()
var fire_timer := 0.0
var special_timer := 0.0
var spawn_timer := 0.0
var invulnerable := 0.0
var transition := 0.0
var flash := 0.0
var title := true
var paused := false
var game_over := false
var muted := false
var enemies: Array[Dictionary] = []
var shots: Array[Dictionary] = []
var hostile: Array[Dictionary] = []
var particles: Array[Dictionary] = []
var pickups: Array[Dictionary] = []
var trail: Array[Vector2] = []
var font: Font
var rng := RandomNumberGenerator.new()
var sound: AudioStreamPlayer
var menu
var developer_mode := false
var debug_scene := ""
var audio_volume := 0.75
var fullscreen := false
var automation := false
var settings_path := "user://settings.cfg"
var controls = CONTROLS.new()
var master_volume := 1.0
var window_preset := 1
var vsync := true
var frame_limit := 60
var render_quality := 2
var brightness := 1.0
var particle_quality := 2
var screen_flashes := true
var show_fps := false
var hitbox_helper := false
var show_controls := true
var pause_on_focus_loss := true
var _applied_window_mode := -1
var _applied_window_preset := -1
var mission = MISSION.new()
var mission_overlay
var victory := false
var practice_mode := Mode.CHASE
var view_transition

func _ready() -> void:
	var game_font: FontFile = ThemeDB.fallback_font.duplicate()
	game_font.multichannel_signed_distance_field = true
	font = game_font
	rng.seed = 1943
	sound = AudioStreamPlayer.new()
	sound.volume_db = -10
	add_child(sound)
	_reset_trail()
	var args := OS.get_cmdline_user_args()
	for argument in args:
		if argument.begins_with("--capture") or argument in ["--smoke", "--flight-demo", "--check-build"]:
			automation = true
	developer_mode = OS.has_feature("editor") or OS.has_feature("developer") or "--developer" in args
	DisplayServer.window_set_title("Skyfire 1943 · 开发版" if developer_mode else "Skyfire 1943")
	if not automation: _load_settings()
	_apply_preferences()
	var menu_layer := CanvasLayer.new()
	add_child(menu_layer)
	menu = MAIN_MENU.new()
	menu_layer.add_child(menu)
	menu.setup(self)
	mission_overlay=MISSION_OVERLAY.new()
	menu_layer.add_child(mission_overlay)
	mission_overlay.setup(self)
	view_transition=VIEW_TRANSITION.new()
	add_child(view_transition)
	view_transition.setup(self)
	_update_render_scale()
	get_viewport().size_changed.connect(_update_render_scale)
	get_window().focus_exited.connect(_on_focus_lost)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	if "--smoke" in OS.get_cmdline_user_args():
		call_deferred("_smoke_test")
	elif "--check-build" in args:
		call_deferred("_check_build")
	elif "--capture-menu" in args:
		call_deferred("_capture_menu")
	elif "--capture-guides" in args:
		call_deferred("_capture_guides")
	elif "--capture-settings" in args:
		call_deferred("_capture_settings")
	elif "--capture-mission" in args:
		call_deferred("_capture_mission")
	elif "--capture-transitions" in args:
		call_deferred("_capture_transitions")
	elif "--capture-boss-motion" in args:
		call_deferred("_capture_boss_motion")
	elif "--capture-catalog" in args:
		call_deferred("_capture_catalog")
	elif "--capture-player-animation" in args:
		call_deferred("_capture_player_animation")
	elif "--capture" in OS.get_cmdline_user_args():
		call_deferred("_capture_views")
	elif "--capture-flight" in OS.get_cmdline_user_args():
		call_deferred("_capture_flight")
	elif "--capture-aim" in OS.get_cmdline_user_args():
		call_deferred("_capture_aim")
	elif "--capture-encounter" in OS.get_cmdline_user_args():
		call_deferred("_capture_encounter")
	elif "--capture-pursuit" in OS.get_cmdline_user_args():
		call_deferred("_capture_pursuit")
	elif "--capture-art" in OS.get_cmdline_user_args():
		call_deferred("_capture_art")
	elif "--capture-altitude" in OS.get_cmdline_user_args():
		call_deferred("_capture_altitude")
	elif "--capture-scroll" in OS.get_cmdline_user_args():
		call_deferred("_capture_scroll")
	elif "--capture-sky" in OS.get_cmdline_user_args():
		call_deferred("_capture_sky")
	elif "--flight-demo" in OS.get_cmdline_user_args():
		muted = true
		demonstration = true
		start_game()

func _input(event: InputEvent) -> void:
	controls.observe(event)

func _on_focus_lost() -> void:
	controls.release_keys()
	if not automation and pause_on_focus_loss and not title and not paused and not game_over and not victory:
		paused=true
		menu.show_page("pause")

func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if not connected: controls.forget_device(device)
	if is_instance_valid(menu) and menu.visible and menu.page=="settings" and menu.settings_section=="controls":
		menu.show_page("settings")

func _unhandled_input(event: InputEvent) -> void:
	if menu.visible: return
	if controls.action_event(event,"pause"):
		if not title and not game_over and not victory:
			if paused: resume_game()
			else: paused=true; menu.show_page("pause")
		return
	if controls.action_event(event,"retry"):
		restart_session()
		return
	if controls.action_event(event,"special"):
		if not title and not paused and not game_over and not victory: special()
		return
	if not event is InputEventKey or not event.pressed or event.echo: return
	match event.keycode:
		KEY_1, KEY_2, KEY_3:
			if not title and not paused and not game_over and not mission.active: switch_mode(int(event.keycode - KEY_1))
		KEY_M: apply_setting("muted", not muted)
		KEY_H: apply_setting("aim_helper", not aim_helper)
		KEY_F1:
			if developer_mode: open_developer_menu()

func start_game() -> void:
	if is_instance_valid(view_transition): view_transition.reset()
	# This is the retained sandbox initializer. The normal menu starts a mission.
	mission.reset()
	victory=false
	practice_mode=Mode.CHASE
	menu.hide_menu()
	debug_scene = ""
	art_gallery = false
	title = false
	paused = false
	game_over = false
	failure_reason = ""
	crash_elapsed = 0
	simulation_accumulator = 0
	flight.reset()
	score = 0
	kills = 0
	power = 1
	energy = 100.0
	elapsed = 0.0
	visual_time = 0.0
	bank = 0.0
	player_pose.reset()
	wave = 0
	special_timer = 0.0
	mode = Mode.CHASE
	player = Vector2(0.5, 0.64)
	_clear_combat()
	spawn_timer = 0.4
	transition = 0.8
	invulnerable = 2.0

func start_mission() -> void:
	start_game()
	mission.start()
	rng.seed=1943

func start_practice_mode(next_mode: int) -> void:
	start_game()
	practice_mode=next_mode
	switch_mode(next_mode)

func restart_session() -> void:
	if developer_mode and not debug_scene.is_empty(): start_debug_scene(debug_scene)
	elif mission.active: start_mission()
	else: start_practice_mode(practice_mode)

func resume_game() -> void:
	paused = false
	simulation_accumulator = 0
	menu.hide_menu()

func return_to_menu() -> void:
	if is_instance_valid(view_transition): view_transition.reset()
	title = true
	paused = false
	game_over = false
	victory=false
	mission.reset()
	demonstration = false
	art_gallery = false
	debug_scene = ""
	crash_elapsed = 0
	simulation_accumulator = 0
	mode = Mode.CHASE
	flight.reset()
	bank = 0
	_clear_combat()
	sound.stop()
	menu.show_page("main")

func open_developer_menu() -> void:
	if not developer_mode: return
	return_to_menu()
	menu.show_page("developer")

func start_debug_scene(scene_id: String) -> void:
	if not developer_mode: return
	if not scene_id in ["side", "top", "chase", "high", "sea", "approach", "bonus", "boss"]: return
	start_game()
	debug_scene = scene_id
	match scene_id:
		"side": switch_mode(Mode.SIDE)
		"top": switch_mode(Mode.TOP)
		"high": flight.position.y = 4.6
		"sea":
			flight.position.y = 1.5
			var vessel_position: Vector3 = flight.position + flight.forward() * 95 + flight.right() * 16
			vessel_position.y = 0.22
			enemies.append({"p": vessel_position, "v": Vector3.ZERO, "hp": ENEMY_ROSTER.VESSELS.escort.hp, "surface": true, "vessel": "escort", "age": 0.0, "fire": 3.0})
		"approach":
			var enemy := CHASE_ENCOUNTER.make_enemy(flight, 1, 0)
			enemy.age = 2.6
			CHASE_ENCOUNTER.update(enemy)
			enemies.append(enemy)
			spawn_timer = CHASE_ENCOUNTER.GAP
		"bonus":
			var enemy := CHASE_ENCOUNTER.make_enemy(flight,ENEMY_ROSTER.BONUS_INTERVAL,0)
			enemy.age = 1.2
			CHASE_ENCOUNTER.update(enemy)
			enemies.append(enemy)
			spawn_timer = CHASE_ENCOUNTER.GAP
		"boss":
			mission.start()
			mission.phase=2
			mission.announce("海鸥验证场景 · 一次接近，固定距离摆动交火",3.0)
			transition=0
			mission.update(self,0)
	transition = 0
	queue_redraw()

func _update_render_scale() -> void:
	# Only rendering changes; collision, projection and gun timing stay in lab coordinates.
	var render_scale := get_viewport_rect().size / SIZE
	scale = render_scale
	menu.scale = render_scale
	if is_instance_valid(mission_overlay): mission_overlay.scale=render_scale

func get_setting(key: String) -> Variant:
	match key:
		"volume": return audio_volume
		"input_mode": return controls.input_mode
		"gamepad_device": return controls.selected_gamepad
		"deadzone": return controls.deadzone
		"invert_chase_y": return controls.invert_chase_y
		"vibration_enabled": return controls.vibration_enabled
		"keyboard_bindings": return controls.bindings.duplicate()
	return get(key) if SETTINGS.DEFAULTS.has(key) else null

func _set_setting(key: String, value: Variant) -> void:
	match key:
		"volume": audio_volume=clampf(float(value),0,1)
		"master_volume": master_volume=clampf(float(value),0,1)
		"brightness": brightness=clampf(float(value),0.8,1.2)
		"window_preset": window_preset=clampi(int(value),0,SETTINGS.WINDOW_SIZES.size()-1)
		"render_quality": render_quality=clampi(int(value),0,SETTINGS.RENDER_SIZES.size()-1)
		"particle_quality": particle_quality=clampi(int(value),0,2)
		"frame_limit": frame_limit=int(value) if SETTINGS.FRAME_LIMITS.has(int(value)) else 60
		"input_mode": controls.input_mode=clampi(int(value),0,2)
		"gamepad_device": controls.selected_gamepad=maxi(-1,int(value))
		"deadzone": controls.deadzone=clampf(float(value),0.05,0.4)
		"invert_chase_y": controls.invert_chase_y=bool(value)
		"vibration_enabled": controls.vibration_enabled=bool(value)
		"keyboard_bindings": controls.load_bindings(value)
		"muted","fullscreen","vsync","screen_flashes","show_fps","aim_helper","torpedo_helper","hitbox_helper","show_controls","pause_on_focus_loss":
			set(key,bool(value))

func settings_snapshot(section := "") -> Dictionary:
	var result: Dictionary = {}
	var keys: Array = SETTINGS.GROUPS[section] if SETTINGS.GROUPS.has(section) else SETTINGS.DEFAULTS.keys()
	for key in keys: result[key]=get_setting(key)
	return result

func apply_setting(key: String, value: Variant, persist := true) -> void:
	if not SETTINGS.DEFAULTS.has(key): return
	_set_setting(key,value)
	_apply_preferences()
	if persist and not automation: _save_settings()

func apply_display_preferences(values: Dictionary, persist := true) -> void:
	for key in SETTINGS.GROUPS.display:
		if values.has(key): _set_setting(key,values[key])
	_apply_preferences()
	if persist and not automation: _save_settings()

func restore_settings_section(section: String, persist := true) -> void:
	if not SETTINGS.GROUPS.has(section): return
	for key in SETTINGS.GROUPS[section]: _set_setting(key,SETTINGS.DEFAULTS[key])
	_apply_preferences()
	if persist and not automation: _save_settings()

func rebind_key(action: String, key: int) -> String:
	var error: String = controls.try_bind(action,key)
	if error.is_empty() and not automation: _save_settings()
	return error

func _apply_preferences() -> void:
	sound.volume_db=-10+linear_to_db(maxf(audio_volume*master_volume,0.0001))
	if muted or is_zero_approx(audio_volume*master_volume): sound.stop()
	modulate=Color(brightness,brightness,brightness,1)
	get_window().content_scale_size=SETTINGS.RENDER_SIZES[render_quality]
	if is_instance_valid(menu): _update_render_scale()
	if not automation:
		var target_mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		var window_changed := target_mode!=_applied_window_mode or window_preset!=_applied_window_preset
		if target_mode!=_applied_window_mode and DisplayServer.window_get_mode()!=target_mode: DisplayServer.window_set_mode(target_mode)
		# Changing audio/controls must not undo a manually resized window.
		if window_changed and not fullscreen:
			var requested: Vector2i = SETTINGS.WINDOW_SIZES[window_preset]
			var usable := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen()).size-Vector2i(32,64)
			var fit := minf(1.0,minf(float(usable.x)/requested.x,float(usable.y)/requested.y))
			var actual := Vector2i(Vector2(requested)*maxf(0.25,fit))
			if DisplayServer.window_get_size()!=actual: DisplayServer.window_set_size(actual)
		_applied_window_mode=target_mode
		_applied_window_preset=window_preset
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
		Engine.max_fps=frame_limit

func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(settings_path)!=OK: return
	var legacy := int(config.get_value("play","aim_guides_version",0))<2
	for section in SETTINGS.CONFIG_FIELDS:
		for config_key in SETTINGS.CONFIG_FIELDS[section]:
			var key: String = SETTINGS.CONFIG_FIELDS[section][config_key]
			var value: Variant = config.get_value(section,config_key,SETTINGS.DEFAULTS[key])
			if legacy and key in ["aim_helper","torpedo_helper"]: value=false
			_set_setting(key,value)
	if legacy: _save_settings()

func _save_settings() -> Error:
	var config := ConfigFile.new()
	if FileAccess.file_exists(settings_path): config.load(settings_path)
	for section in SETTINGS.CONFIG_FIELDS:
		for config_key in SETTINGS.CONFIG_FIELDS[section]:
			var key: String = SETTINGS.CONFIG_FIELDS[section][config_key]
			config.set_value(section,config_key,get_setting(key))
	config.set_value("play","aim_guides_version",2)
	config.set_value("meta","settings_version",3)
	var result := config.save(settings_path)
	if result!=OK: push_warning("Could not save local preferences: %s"%error_string(result))
	return result

func preview_audio() -> void:
	_beep(660,0.16,true)

func switch_mode(next_mode: int) -> void:
	if next_mode == mode: return
	mode = next_mode
	player_pose.reset()
	# Preserve campaign state, discard threats with incompatible spatial rules.
	_clear_combat()
	player = Vector2(0.24, 0.48) if mode == Mode.SIDE else Vector2(0.5, 0.72)
	if mode == Mode.CHASE: flight.reset()
	_reset_trail()
	transition = 0.8
	invulnerable = 1.6
	spawn_timer = 0.9
	_beep(220.0, 0.16)

func _switch_mission_mode(next_mode: int) -> void:
	# Uncollected supplies survive the seam as the same pickup, not extra awards.
	var carried: Array[Dictionary] = []
	for item in pickups:
		carried.append({"relative":_entity_screen(item)-_ship_screen(),"item":item.duplicate(true)})
	switch_mode(next_mode)
	if next_mode==Mode.CHASE:
		flight.position=mission.saved_position
		flight.heading=mission.saved_heading
		flight.view_heading=mission.saved_heading
	bank=0
	for item in carried:
		var relative: Vector2 = item.relative
		var position_value := _ship_screen()+Vector2(clampf(relative.x,-180,180),-clampf(absf(relative.y),70,160))
		var pickup: Dictionary = item.item
		for field in ["p","air_position","air_pickup","air_drift_y"]: pickup.erase(field)
		if next_mode==Mode.CHASE:
			pickup.air_position=flight.air_position_from_screen(position_value)
			pickup.air_pickup=true
		else: pickup.p=position_value
		pickups.append(pickup)
	transition=1.2
	invulnerable=1.6

func _begin_mission_transition(next_mode: int, next_phase: int) -> void:
	shots.clear()
	hostile.clear()
	view_transition.begin(next_mode,next_phase)
	transition=VIEW_TRANSITION.DURATION

func _spawn_mission_wave(event: Dictionary) -> bool:
	var kinds: Array = event.kinds
	if mode==Mode.CHASE and enemies.size()+kinds.size()>CHASE_ENCOUNTER.MAX_AIRCRAFT: return false
	wave+=1
	for i in range(kinds.size()):
		var kind: String = kinds[i]
		var spec := ENEMY_ROSTER.profile(kind)
		var enemy: Dictionary
		if mode==Mode.CHASE:
			enemy=CHASE_ENCOUNTER.make_enemy(flight,wave,i)
			enemy.kind=kind
			enemy.hp=spec.hp
			enemy.route_duration=spec.duration+i*0.45
			if event.get("gentle",false): enemy.fire=4.2+i*0.7
		else:
			var x := 340.0+i*210.0 if wave%2==0 else 600.0-i*210.0
			var position_value := Vector2(x,-40-i*65)
			enemy={"p":position_value,"base":position_value,"v":Vector3.ZERO,"hp":spec.hp_2d,"kind":kind,
				"age":0.0,"fire":2.0+i*0.6,"surface":false,"bank":0.0}
		enemies.append(enemy)
		mission.spawned_targets+=1
	if event.has("vessel"):
		var vessel: String = event.vessel
		var position_value := Vector2(480,-100)
		enemies.append({"p":position_value,"base":position_value,"v":Vector3.ZERO,"hp":ENEMY_ROSTER.vessel_profile(vessel).hp,
			"surface":true,"vessel":vessel,"age":0.0,"fire":3.0})
		mission.spawned_targets+=1
	if kinds.has("courier"): mission.announce("金色奖励机 · 快速且不主动开火，击落必掉补给",2.6)
	return true

func _spawn_mission_supply() -> void:
	var position_value := _ship_screen()+Vector2(0,-100)
	var item := {"life":12.0,"mission_supply":true}
	if mode==Mode.CHASE:
		item.air_position=flight.air_position_from_screen(position_value)
		item.air_pickup=true
	else: item.p=position_value
	pickups.append(item)
	mission.announce("补给进入航道 · 恢复能量并强化火力",2.8)

func _finish_mission() -> void:
	if victory or not mission.active or game_over or energy<=0: return
	victory=true
	mission.result="won"
	mission.earned_bonus=1000+roundi(energy)*10
	score+=mission.earned_bonus
	_beep(1320,0.28)

func _clear_combat() -> void:
	enemies.clear()
	shots.clear()
	hostile.clear()
	particles.clear()
	pickups.clear()
	fire_timer = 0.0
	_reset_trail()

func _reset_trail() -> void:
	trail.clear()
	for i in range(48): trail.append(player * SIZE)

func _process(delta: float) -> void:
	menu.sync_game_state()
	if title: visual_time += delta
	if game_over and flight.crashed:
		crash_elapsed += delta
	if not title and not paused and not game_over and not victory:
		# Gun eligibility is measured in 60 Hz frames, independently of display FPS.
		simulation_accumulator += minf(delta, 0.1)
		while simulation_accumulator + 0.000001 >= SIMULATION_STEP:
			simulation_accumulator = maxf(0, simulation_accumulator - SIMULATION_STEP)
			if demonstration:
				var movement := Vector2.ZERO
				if elapsed >= 1.0 and elapsed < 2.5: movement = Vector2.RIGHT
				elif elapsed >= 2.5 and elapsed < 4.8: movement = Vector2.UP
				elif elapsed >= 5.8: movement = Vector2.DOWN
				step(SIMULATION_STEP, movement, true)
			else:
				step(SIMULATION_STEP, _movement(), controls.pressed("fire"))
			if game_over or victory: break
	else:
		simulation_accumulator = 0
	queue_redraw()

func _movement() -> Vector2:
	return controls.movement(mode==Mode.CHASE)

func step(delta: float, movement: Vector2, shooting: bool) -> void:
	if mission.active and (victory or not mission.result.is_empty()): return
	elapsed += delta
	visual_time += delta
	view_transition.aircraft_grace=maxf(0,view_transition.aircraft_grace-delta)
	if view_transition.active:
		mission.time+=delta
		view_transition.advance(delta)
		return
	bank = lerpf(bank, movement.x * 0.3, 1.0 - exp(-delta * 8))
	transition = maxf(0, transition - delta)
	invulnerable = maxf(0, invulnerable - delta)
	flash = maxf(0, flash - delta)
	fire_timer -= delta
	special_timer = maxf(0, special_timer - delta)
	if mode == Mode.CHASE:
		flight.advance(delta, movement)
		bank = flight.bank
		if flight.crashed:
			# Sea contact is fatal even during a transition or damage protection.
			energy = 0
			game_over = true
			if mission.active: mission.result="failed"
			failure_reason = "SEA IMPACT / TOO LOW"
			_beep(55, 0.3)
			return
	else:
		player += movement * Vector2(0.47, 0.67) * delta
		player.x = clampf(player.x, 0.06, 0.94)
		player.y = clampf(player.y, 0.14, 0.88)
	player_pose.advance(delta,mode,movement,flight.climb_rate/CHASE_FLIGHT.CLIMB_SPEED)
	trail.push_front(player * SIZE)
	if trail.size() > 48: trail.pop_back()
	if not mission.active or transition<=0: energy = maxf(0, energy - delta * 0.18)
	if energy <= 0:
		game_over = true
		if mission.active: mission.result="failed"
		return
	if transition <= 0:
		if shooting and fire_timer <= 0: fire()
		if not mission.active:
			spawn_timer -= delta
			if spawn_timer <= 0:
				spawn_wave()
				spawn_timer = CHASE_ENCOUNTER.GAP if mode == Mode.CHASE else 3.3
	_update_enemies(delta)
	_update_shots(delta)
	if victory:
		shots.clear()
		hostile.clear()
		pickups.clear()
		return
	_update_hostile(delta)
	_update_pickups(delta)
	for i in range(particles.size() - 1, -1, -1):
		particles[i].p += particles[i].v * delta
		particles[i].life -= delta
		if particles[i].life <= 0: particles.remove_at(i)
	if mode == Mode.SIDE:
		var p := player * SIZE
		if p.y < _ceiling(p.x) + 13 or p.y > _floor(p.x) - 13: damage(14)
	if mission.active: mission.update(self,delta)

func _player_world() -> Vector3:
	return flight.position

func fire() -> void:
	if mode == Mode.CHASE:
		var pair_count := 0
		for shot in shots:
			if shot.get("air_pair", false): pair_count += 1
		if pair_count >= CHASE_GUN.MAX_PAIRS: return
		fire_timer = 0.11 if power > 1 else 0.16
		shots.append(CHASE_GUN.make_pair(flight))
	else:
		fire_timer = 0.16
		var p := player * SIZE
		var velocity := Vector2(650, 0) if mode == Mode.SIDE else Vector2(0, -620)
		shots.append({"p": p, "v": velocity, "surface": false})
		if power > 1:
			for wingman in _wingmen(): shots.append({"p": wingman, "v": velocity, "surface": false})
	_beep(980.0, 0.018)

func special() -> void:
	if victory or special_timer > 0 or energy <= 18 or transition > 0: return
	energy -= 15
	special_timer = 1.5
	_beep(90, 0.24)
	if mode == Mode.CHASE:
		var p := _player_world() + flight.forward() * 8
		p.y = 0.22
		shots.append({"p": p, "v": flight.forward() * 58, "surface": true, "life": 4.0})
	else:
		flash = 0.32
		hostile.clear()
		for i in range(enemies.size() - 1, -1, -1):
			enemies[i].hp -= 4
			if enemies[i].hp <= 0: _destroy_enemy(i)

func spawn_wave() -> void:
	if mode == Mode.CHASE:
		_spawn_chase_wave()
		return
	wave += 1
	var count := 3 + mini(int(wave / 5.0), 2)
	for i in range(count):
		var kind := ENEMY_ROSTER.kind_for_wave(wave, i)
		var spec := ENEMY_ROSTER.profile(kind)
		var p: Variant
		if mode == Mode.SIDE:
			p = Vector2(990 + i * 64, 260 + sin(float(wave) * 1.8) * 84)
		elif mode == Mode.TOP:
			p = Vector2(170 + fmod(float(wave) * 121, 570) + (i - 1) * 60, -40 - i * 52)
		var enemy := {"p": p, "base": p, "v": -flight.forward() * 8, "hp": spec.hp_2d, "kind": kind,
			"age": 0.0, "fire": 1.5 + i * 0.28, "surface": false, "bank": 0.0}
		enemies.append(enemy)
	if wave % 3 == 0 and mode != Mode.SIDE:
		var p: Variant = Vector2(360 + sin(float(wave)) * 180, -130)
		var vessel := "cargo" if wave % 2 == 0 else "escort"
		enemies.append({"p": p, "base": p, "v": Vector3.ZERO, "hp": ENEMY_ROSTER.vessel_profile(vessel).hp, "age": 0.0, "fire": 1.8,
			"surface": true, "vessel": vessel})

func _spawn_chase_wave() -> void:
	var active_air := 0
	var active_boats := 0
	for enemy in enemies:
		if enemy.surface: active_boats += 1
		else: active_air += 1
	var available := CHASE_ENCOUNTER.MAX_AIRCRAFT - active_air
	if available <= 0: return
	wave += 1
	var count := mini(available, 2 if wave % 2 == 0 else 1)
	for i in range(count): enemies.append(CHASE_ENCOUNTER.make_enemy(flight, wave, i))
	if wave % 4 == 0 and active_boats == 0:
		var p: Vector3 = flight.position + flight.forward() * 190 + flight.right() * sin(float(wave)) * 25
		p.y = 0.22
		var vessel := "cargo" if wave % 8 == 0 else "escort"
		enemies.append({"p": p, "base": p, "v": Vector3.ZERO, "hp": ENEMY_ROSTER.vessel_profile(vessel).hp, "age": 0.0,
			"fire": 3.5, "surface": true, "vessel": vessel})

func _update_enemies(delta: float) -> void:
	for i in range(enemies.size() - 1, -1, -1):
		var e := enemies[i]
		var kind: String = e.get("kind", "interceptor")
		var spec := ENEMY_ROSTER.profile(kind)
		e.age += delta
		e.fire -= delta
		if mode == Mode.SIDE:
			e.p.x -= delta * spec.speed_side
			e.p.y = e.base.y + sin(e.age * spec.frequency) * spec.amplitude
		elif mode == Mode.TOP:
			e.p.y += delta * (42 if e.surface else spec.speed_top)
			var frequency: float = 1.9 if kind == "interceptor" else spec.frequency
			var amplitude: float = 48.0 if kind == "interceptor" else spec.amplitude
			e.p.x = e.base.x + sin(e.age * frequency) * (0 if e.surface else amplitude)
		else:
			if e.get("boss",false): CHASE_BOSS.update(e)
			elif e.get("air_route", false): CHASE_ENCOUNTER.update(e)
			else:
				e.p += e.v * delta
				if not e.surface: e.p.y = e.base.y + sin(e.age * 1.4) * 0.35
		if e.fire <= 0:
			e.fire = spec.fire_chase if mode == Mode.CHASE else spec.fire_2d
			if e.get("boss",false): e.fire=CHASE_BOSS.fire_interval(e.hp)
			if e.surface:
				var vessel_spec := ENEMY_ROSTER.vessel_profile(e.get("vessel","escort"))
				e.fire = vessel_spec.fire_chase if mode == Mode.CHASE else vessel_spec.fire_2d
			_fire_enemy(e)
		var offscreen := false
		if mode == Mode.CHASE:
			if e.get("boss",false): offscreen=false
			elif e.get("air_route", false): offscreen = CHASE_ENCOUNTER.finished(e, flight)
			else: offscreen = e.age > 18 or e.p.distance_to(flight.position) > 420
		else: offscreen = e.p.x < -70 if mode == Mode.SIDE else e.p.y > 580
		if not e.surface:
			if mode == Mode.CHASE:
				if e.get("air_route", false):
					if _enemy_depth(e) < 25 and _entity_screen(e).distance_to(_ship_screen()) < 20: damage(18)
				else:
					var pp := _player_world()
					if Vector2(e.p.x - pp.x, e.p.z - pp.z).length() < 2 and absf(e.p.y - pp.y) < 0.8: damage(18)
			elif e.p.distance_to(player * SIZE) < 25: damage(18)
		if offscreen:
			enemies.remove_at(i)

func _fire_enemy(enemy: Dictionary) -> void:
	var kind: String = enemy.get("kind", "interceptor")
	if mission.active and mode==Mode.TOP and not _mission_2d_target_ready(enemy): return
	if mode == Mode.CHASE:
		if not _entity_visible(enemy) or _enemy_depth(enemy) >= 160 or hostile.size() >= 6: return
		if enemy.get("air_route", false):
			var target: Vector2 = flight.air_position_from_screen(_ship_screen())
			var direction: Vector2 = target - enemy.air_position
			direction.x = wrapf(direction.x, -PI * CHASE_FLIGHT.AIR_SCROLL_SCALE, PI * CHASE_FLIGHT.AIR_SCROLL_SCALE)
			for velocity in ENEMY_ROSTER.shot_velocities(kind, direction, true, 6 - hostile.size()):
				hostile.append({"air_bullet": true, "air_position": enemy.air_position,
					"v": velocity, "age": 0.0, "life": 6.0})
		else: hostile.append({"p": enemy.p, "v": (_player_world() - enemy.p).normalized() * ENEMY_ROSTER.vessel_profile(enemy.get("vessel","escort")).bullet_chase, "life": 9.0})
	else:
		var direction: Vector2 = player * SIZE - enemy.p
		if enemy.surface:
			hostile.append({"p":enemy.p,"v":direction.normalized()*ENEMY_ROSTER.vessel_profile(enemy.get("vessel","escort")).bullet_2d})
			return
		for velocity in ENEMY_ROSTER.shot_velocities(kind, direction, false, 2):
			hostile.append({"p": enemy.p, "v": velocity})

func _update_shots(delta: float) -> void:
	for i in range(shots.size() - 1, -1, -1):
		var s := shots[i]
		if mode == Mode.CHASE and s.get("air_pair", false):
			if _update_chase_pair(s, delta): shots.remove_at(i)
			continue
		var old: Variant = s.p
		s.p += s.v * delta
		var consumed := false
		for j in range(enemies.size() - 1, -1, -1):
			var e := enemies[j]
			var hit := false
			if mode == Mode.CHASE:
				if not s.surface or not e.surface: continue
				var closest := _closest_segment3d(e.p, old, s.p)
				var offset: Vector3 = closest - e.p
				hit = s.surface and e.surface and Vector2(offset.x, offset.z).length() < 4.2 and absf(offset.y) < 0.85
			else:
				if mission.active and not _mission_2d_target_ready(e): continue
				# Segment tests prevent tunnelling on slow frames.
				var closest: Vector2 = Geometry2D.get_closest_point_to_segment(e.p, old, s.p)
				hit = closest.distance_to(e.p) < (32 if e.surface else 20)
			if hit:
				e.hp -= 7 if s.surface else 1
				if e.hp <= 0: _destroy_enemy(j)
				else: _burst(_entity_screen(e), TEAL, 3)
				consumed = true
				break
		var expired: bool
		if mode == Mode.CHASE:
			s.life = s.get("life", 3.2) - delta
			expired = s.life <= 0
		else: expired = not Rect2(-40, -40, 1040, 620).has_point(s.p)
		if consumed or expired: shots.remove_at(i)

func _mission_2d_target_ready(enemy: Dictionary) -> bool:
	var top := 110.0 if enemy.surface else 84.0
	return Rect2(-60,top,1080,506-top).has_point(enemy.p)

func _update_chase_pair(pair: Dictionary, delta: float) -> bool:
	var before: float = pair.age
	pair.age += delta
	var midpoints := CHASE_GUN.hit_midpoints(pair, flight, before, pair.age)
	for j in range(enemies.size() - 1, -1, -1):
		var e := enemies[j]
		if e.surface or not _entity_visible(e): continue
		var target_stage := CHASE_GUN.stage(_enemy_depth(e))
		var target := _entity_screen(e)
		for midpoint in midpoints:
			if CHASE_GUN.hits(midpoint, target, target_stage):
				if e.get("boss",false) and not CHASE_BOSS.holding(e):
					_burst(target,Color("93afb6"),3)
					return true
				e.hp -= 1
				if e.get("boss",false):
					mission.boss_hp=maxi(0,e.hp)
					if e.hp<=CHASE_BOSS.MAX_HP/2: e.fire=minf(e.fire,CHASE_BOSS.fire_interval(e.hp))
				if e.hp <= 0: _destroy_enemy(j, CHASE_GUN.points_for_stage(target_stage))
				else: _burst(target, TEAL, 3)
				return true
	return CHASE_GUN.expired(pair)

func _update_hostile(delta: float) -> void:
	for i in range(hostile.size() - 1, -1, -1):
		var b := hostile[i]
		if mode == Mode.CHASE and b.get("air_bullet", false):
			var before: Vector2 = _entity_screen(b)
			b.air_position += b.v * delta
			b.age += delta
			b.life -= delta
			var after: Vector2 = _entity_screen(b)
			var closest := Geometry2D.get_closest_point_to_segment(_ship_screen(), before, after)
			var hit: bool = b.age >= 0.55 and closest.distance_to(_ship_screen()) < 10
			if hit: damage(12)
			if hit or b.life <= 0: hostile.remove_at(i)
			continue
		var old: Variant = b.p
		b.p += b.v * delta
		var hit := false
		var expired := false
		if mode == Mode.CHASE:
			var p := _player_world()
			var closest := _closest_segment3d(p, old, b.p)
			var offset := closest - p
			hit = Vector2(offset.x, offset.z).length() < 1.15 and absf(offset.y) < 0.6
			b.life = b.get("life", 9.0) - delta
			expired = b.life <= 0 or b.p.distance_to(p) > 400
		else:
			var closest: Vector2 = Geometry2D.get_closest_point_to_segment(player * SIZE, old, b.p)
			hit = closest.distance_to(player * SIZE) < 10
			expired = not Rect2(-40, -40, 1040, 620).has_point(b.p)
		if hit: damage(12)
		if hit or expired: hostile.remove_at(i)

func _destroy_enemy(index: int, awarded_points: int = -1) -> void:
	var e := enemies[index]
	if mission.active: mission.defeated_targets+=1
	if e.get("boss",false):
		mission.boss_hp=0
		score+=CHASE_BOSS.POINTS
		kills+=1
		_burst(_entity_screen(e),AMBER,48)
		enemies.remove_at(index)
		_finish_mission()
		return
	var bonus: bool = not e.surface and ENEMY_ROSTER.is_bonus(e.get("kind","interceptor"))
	var points := 200
	if mode == Mode.CHASE:
		if awarded_points >= 0: points = awarded_points
		else:
			var distance: float = _enemy_depth(e)
			points = 300 if distance < 60 else (200 if distance < 110 else 150)
	score += points * (2 if e.surface else 1)
	kills += 1
	_burst(_entity_screen(e), AMBER, 18)
	_beep(150, 0.09)
	if bonus or kills % 4 == 0:
		var pickup: Dictionary
		if mode == Mode.CHASE and e.get("air_route", false):
			pickup = {"air_position": e.air_position, "life": 10.0, "air_pickup": true}
		else: pickup = {"p": e.p, "life": 14.0}
		if mode == Mode.CHASE and not e.surface and not e.get("air_route", false):
			# Air formation Y is a pseudo-3D projection coordinate. Ease its drop
			# into the flight lane so a distant kill still yields a reachable supply.
			var approach_time := maxf(0.5, (flight.depth(e.p) - CHASE_FLIGHT.CAMERA_DISTANCE) / CHASE_FLIGHT.SPEED)
			pickup["air_drift_y"] = (flight.position.y - e.p.y) / approach_time
		pickups.append(pickup)
		if bonus:
			pickup["bonus_drop"] = true
			pickup["life"] = 14.0
	enemies.remove_at(index)

func _update_pickups(delta: float) -> void:
	for i in range(pickups.size() - 1, -1, -1):
		var item := pickups[i]
		var hit := false
		var expired := false
		if mode == Mode.CHASE:
			if item.get("air_pickup", false):
				item.air_position.y += 35 * delta
				hit = _entity_screen(item).distance_to(_ship_screen()) < 25
			else:
				item.p.y += item.get("air_drift_y", 0.0) * delta
				var p := _player_world()
				var offset: Vector3 = item.p - p
				hit = Vector2(offset.x, offset.z).length() < 4.5 and absf(offset.y) < 1.3
			item.life = item.get("life", 14.0) - delta
			expired = item.life <= 0
		else:
			item.p += (Vector2(-90, 0) if mode == Mode.SIDE else Vector2(0, 100)) * delta
			hit = item.p.distance_to(player * SIZE) < 34
			expired = not Rect2(-50, -50, 1060, 640).has_point(item.p)
			if mission.active and item.has("life"):
				item.life-=delta
				expired=expired or item.life<=0
		if hit:
			if mission.active: mission.supplies_collected+=1
			power = 2
			energy = minf(100, energy + 18)
			score += 100
			_beep(1400, 0.15)
		if hit or expired: pickups.remove_at(i)

func damage(amount: float) -> void:
	if victory or invulnerable > 0 or transition > 0: return
	energy = maxf(0, energy - amount)
	invulnerable = 1.2
	flash = 0.13
	_burst(_ship_screen(), RED, 12)
	controls.vibrate()
	_beep(65, 0.18)
	if energy <= 0: game_over = true

func _burst(p: Vector2, color: Color, count: int) -> void:
	for i in range(count):
		particles.append({"p": p, "v": Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(35, 180), "life": rng.randf_range(0.18, 0.65), "color": color})

func _wingmen() -> Array[Vector2]:
	# Retain delayed vs fixed formation semantics, with space for actual hulls.
	if mode == Mode.SIDE: return [trail[14] - Vector2(48, 0), trail[30] - Vector2(94, 0)]
	return [player * SIZE + Vector2(-50, 20), player * SIZE + Vector2(50, 20)]

func _project(p: Vector3) -> Vector2:
	return flight.project(p)

func _closest_segment3d(point: Vector3, a: Vector3, b: Vector3) -> Vector3:
	var segment := b - a
	if segment.length_squared() < 0.000001: return a
	return a + segment * clampf((point - a).dot(segment) / segment.length_squared(), 0, 1)

func _entity_screen(p: Variant) -> Vector2:
	if p is Dictionary:
		if mode == Mode.CHASE and p.has("air_position"): return flight.air_screen(p.air_position)
		p = p.p
	return _project(p) if mode == Mode.CHASE else p

func _enemy_depth(enemy: Dictionary) -> float:
	return enemy.chase_depth if enemy.get("air_route", false) else flight.depth(enemy.p)

func _entity_visible(entity: Dictionary) -> bool:
	if mode == Mode.CHASE and entity.get("surface", false) and not flight.sea_visible(): return false
	if entity.get("air_route", false) and not CHASE_ENCOUNTER.entered(entity): return false
	if entity.get("boss",false): return Rect2(-CHASE_BOSS.VISUAL_RADIUS,66,960+2*CHASE_BOSS.VISUAL_RADIUS,440).has_point(_entity_screen(entity))
	if entity.has("air_position"): return Rect2(-90, 66, 1140, 440).has_point(_entity_screen(entity))
	return flight.visible(entity.p)

func _ship_screen() -> Vector2:
	return flight.aircraft_screen() if mode == Mode.CHASE else player * SIZE

func _ceiling(x: float) -> float:
	return 104 + 22 * sin(x * 0.006 + visual_time * 0.65) + 11 * sin(x * 0.018 + visual_time)

func _floor(x: float) -> float:
	return 452 + 25 * sin(x * 0.008 + visual_time * 0.8)

func _beep(frequency: float, duration: float, allow_in_menu := false) -> void:
	if muted or (paused and not allow_in_menu) or is_zero_approx(audio_volume*master_volume): return
	var samples := int(duration * 22050)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in range(samples):
		var envelope := 1.0 - float(i) / samples
		var value := (1 if sin(float(i) / 22050 * TAU * frequency) > 0 else -1) * int(4200 * envelope)
		data.encode_s16(i * 2, value)
	var audio := AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_16_BITS
	audio.mix_rate = 22050
	audio.data = data
	sound.stream = audio
	sound.play()

func _exit_tree() -> void:
	sound.stop()
	if Input.joy_connection_changed.is_connected(_on_joy_connection_changed): Input.joy_connection_changed.disconnect(_on_joy_connection_changed)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SIZE), INK)
	if is_instance_valid(view_transition) and view_transition.active:
		_draw_hud()
		return
	if art_gallery:
		_draw_aircraft_sheet()
		return
	match mode:
		Mode.SIDE: _draw_core()
		Mode.TOP: _draw_ocean()
		Mode.CHASE: _draw_horizon()
	if title:
		_draw_title()
		return
	var sorted_enemies := enemies.duplicate()
	if mode == Mode.CHASE:
		sorted_enemies.sort_custom(func(a, b): return _enemy_depth(a) > _enemy_depth(b))
	for e in sorted_enemies:
		if mode == Mode.CHASE and not _entity_visible(e): continue
		var pos := _entity_screen(e)
		var factor: float = 1.0
		if mode == Mode.CHASE:
			if e.surface: factor = clampf(22.0 / maxf(flight.depth(e.p), 1.0), 0.12, 2.8)
			else: factor = CHASE_GUN.PLANE_SCALES[maxi(0, CHASE_GUN.stage(_enemy_depth(e)))]
		if e.surface: _draw_boat(pos, factor, e.get("vessel", "escort"))
		elif e.get("boss",false): BOSS_ART.draw_boss(self,pos,factor,e,visual_time)
		else: _draw_plane(pos, factor, AMBER if ENEMY_ROSTER.is_bonus(e.get("kind","interceptor")) else RED, mode, false, e.get("bank", 0.0), e.get("kind", "interceptor"))
	for item in pickups:
		if mode == Mode.CHASE and not _entity_visible(item): continue
		var p := _entity_screen(item)
		var color := AMBER if item.get("bonus_drop",false) else TEAL
		draw_circle(p, 13 + 2 * sin(visual_time * 6), Color(color, 0.15))
		draw_rect(Rect2(p - Vector2(8, 8), Vector2(16, 16)), color, false, 2)
		_text("B" if item.get("bonus_drop",false) else "+", p + Vector2(-5, 5), 14, WHITE)
	for s in shots:
		if mode == Mode.CHASE and s.get("air_pair", false):
			_draw_chase_pair(s)
			continue
		if mode == Mode.CHASE and not flight.visible(s.p): continue
		if mode == Mode.CHASE and s.surface and not flight.sea_visible(): continue
		var pos := _entity_screen(s.p)
		var color: Color = AMBER if s.surface else TEAL
		var end := pos + (Vector2(-15, 0) if mode == Mode.SIDE else Vector2(0, 12))
		if mode == Mode.CHASE: end = _project(s.p - s.v.normalized() * 3)
		draw_line(pos, end, Color(color, 0.15), 8)
		draw_line(pos, end, color, 3)
	for b in hostile:
		if mode == Mode.CHASE and not _entity_visible(b): continue
		var p := _entity_screen(b)
		draw_circle(p, 7, Color(RED, 0.2))
		draw_circle(p, 4, RED)
		draw_circle(p, 1.6, WHITE)
	if particle_quality>0:
		for index in range(0,particles.size(),2 if particle_quality==1 else 1):
			var effect: Dictionary = particles[index]
			draw_rect(Rect2(effect.p, Vector2(3, 3)), Color(effect.color, clampf(effect.life * 2, 0, 1)))
	if power > 1 and mode != Mode.CHASE:
		for wingman in _wingmen():
			_draw_plane(wingman, 0.5, TEAL, mode, true)
	var p := _ship_screen()
	if mode == Mode.CHASE and flight.crashed:
		var splash := Vector2(p.x, 487)
		for i in range(3):
			draw_arc(splash, 12 + i * 14 + minf(crash_elapsed, 0.7) * 32, PI, TAU, 20, Color(TEAL, 0.65), 2)
		if crash_elapsed < 0.5:
			_draw_plane(p + Vector2(0, crash_elapsed * 110), 1.35, RED, mode, true)
	else:
		if invulnerable <= 0 or int(visual_time * 12) % 2 == 0 or view_transition.aircraft_grace>0:
			_draw_plane(p, 1.35 if mode == Mode.CHASE else 1.0, TEAL, mode, true)
			if hitbox_helper: draw_circle(p, 3, WHITE)
	if mode == Mode.CHASE and not flight.crashed:
		_draw_chase_guides()
		_draw_altimeter()
	_draw_hud()
	if flash > 0 and screen_flashes: draw_rect(Rect2(Vector2.ZERO, SIZE), Color(AMBER, flash * 0.65))
	if transition > 0 and not mission.active:
		draw_rect(Rect2(0, 210, 960, 82), Color(INK, 0.94))
		_center(MODE_NAMES[mode], 244, 26, TEAL)
		_center("REORIENTING  /  SHARED ENERGY & SCORE", 272, 12, MUTED)

func _draw_chase_guides() -> void:
	if aim_helper:
		var reticle: Vector2 = flight.aim_screen()
		# Optional display only; the gun always uses its existing nose reference.
		for offset in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			draw_line(reticle + offset * 6, reticle + offset * 11, Color(TEAL, 0.65), 1)
	if torpedo_helper:
		var sea_aim := _player_world() + flight.forward() * 70
		sea_aim.y = 0.22
		var sea_pos := _project(sea_aim)
		if flight.visible(sea_aim) and sea_pos.y >= flight.horizon() and sea_pos.y < 485:
			draw_line(sea_pos + Vector2(-8, 0), sea_pos + Vector2(8, 0), AMBER, 2)
			var special_key := "B" if controls.last_source=="gamepad" else OS.get_keycode_string(int(controls.bindings.special))
			_text(special_key+" / SEA", sea_pos + Vector2(-18, 15), 10, AMBER)

func _draw_horizon() -> void:
	CHASE_BACKGROUND.draw(self,flight)

func _draw_chase_pair(pair: Dictionary) -> void:
	var positions := CHASE_GUN.positions(pair, flight)
	var tail := CHASE_GUN.positions(pair, flight, maxf(0, pair.age - 1.0 / CHASE_GUN.FPS))
	var eligible: bool = pair.age * CHASE_GUN.FPS >= CHASE_GUN.FIRST_HIT_FRAME - 0.000001
	for side in range(2):
		draw_line(positions[side], tail[side], Color(TEAL, 0.18), 7)
		draw_line(positions[side], tail[side], WHITE if eligible else TEAL, 2)
		draw_circle(positions[side], 2.0 if eligible else 2.8, WHITE if eligible else TEAL)

func _draw_wave_layer(spacing: float, radius: int, sea_start: float) -> void:
	CHASE_BACKGROUND.waves(self,flight,spacing,radius,sea_start)

func _draw_altimeter() -> void:
	var low: bool = flight.position.y < CHASE_FLIGHT.LOW_ALTITUDE
	var color := RED if low else TEAL
	_text("ALT", Vector2(890, 290), 11, MUTED)
	draw_rect(Rect2(905, 307, 12, 136), Color(INK, 0.8))
	draw_rect(Rect2(905, 443 - flight.position.y / CHASE_FLIGHT.MAX_ALTITUDE * 136, 12, flight.position.y / CHASE_FLIGHT.MAX_ALTITUDE * 136), color)
	draw_rect(Rect2(905, 420, 12, 23), Color(RED, 0.3))
	var sea_mark := 443 - CHASE_FLIGHT.SEA_VISIBLE_BELOW / CHASE_FLIGHT.MAX_ALTITUDE * 136
	draw_line(Vector2(898, sea_mark), Vector2(924, sea_mark), AMBER, 1)
	_text("SEA", Vector2(866, sea_mark + 4), 10, MUTED)
	_text("%03d" % int(flight.position.y * 100), Vector2(891, 466), 13, color)
	_text("HDG %03d" % int(rad_to_deg(flight.heading)), Vector2(24, 90), 13, MUTED)
	if low and not game_over:
		_center("LOW ALTITUDE / PULL UP", 478, 19, RED if int(visual_time * 5) % 2 == 0 else AMBER)

func _draw_ocean() -> void:
	SCENE_ART.draw_top(self, visual_time)

func _draw_core() -> void:
	SCENE_ART.draw_side(self, visual_time, Callable(self, "_ceiling"), Callable(self, "_floor"))

func _draw_plane(pos: Vector2, s: float, accent: Color, perspective: int, friendly: bool, enemy_bank: float = 0.0, kind: String = "interceptor") -> void:
	AIRCRAFT_ART.draw_plane(self, pos, s, accent, perspective, friendly,
		bank if friendly else enemy_bank, kind, visual_time,player_pose.value() if friendly else Vector2.INF)

func _draw_boat(pos: Vector2, s: float, vessel: String = "escort") -> void:
	VESSEL_ART.draw_vessel(self,pos,s,mode==Mode.CHASE,vessel,RED)

func _draw_hud() -> void:
	draw_rect(Rect2(0, 0, 960, 66), Color(INK, 0.93))
	draw_line(Vector2(24, 66), Vector2(936, 66), Color("335362"))
	_text("SKYFIRE", Vector2(24, 28), 18, WHITE)
	_text("1943", Vector2(112, 28), 18, AMBER)
	if not mission.active:
		_text(MODE_NAMES[mode], Vector2(250, 28), 16, TEAL)
		_text(MODE_NOTES[mode], Vector2(250, 49), 11, MUTED)
	_text("SCORE  %06d" % score, Vector2(755, 27), 16, WHITE)
	_text("WAVE %02d   /   PWR %d" % [wave, power], Vector2(755, 49), 11, MUTED)
	if show_fps: _text("%03d FPS"%Engine.get_frames_per_second(),Vector2(655,27),11,TEAL)
	_text("ENERGY", Vector2(24, 49), 10, MUTED)
	draw_rect(Rect2(76, 41, 138, 8), Color("233e50"))
	draw_rect(Rect2(76, 41, 138 * energy / 100, 8), TEAL if energy > 30 else RED)
	if show_controls:
		draw_rect(Rect2(0, 506, 960, 34), Color(INK, 0.93))
		if controls.last_source=="gamepad" and controls.active_gamepad()>=0:
			_text("L STICK / DPAD  MOVE     A  FIRE",Vector2(24,528),11,MUTED)
			_text("B  TORPEDO" if mode==Mode.CHASE else "B  CLEAR",Vector2(355,528),11,AMBER)
			_text("START PAUSE    Y RETRY    "+("SCRIPTED VIEWS" if mission.active else "1/2/3 VIEW"),Vector2(550,528),11,MUTED)
		else:
			_text("MOVE  %s/%s/%s/%s    %s/Z FIRE"%[OS.get_keycode_string(controls.bindings.up),OS.get_keycode_string(controls.bindings.left),OS.get_keycode_string(controls.bindings.down),OS.get_keycode_string(controls.bindings.right),OS.get_keycode_string(controls.bindings.fire)],Vector2(24,528),10,MUTED)
			_text("%s  %s"%[OS.get_keycode_string(controls.bindings.special),"TORPEDO" if mode==Mode.CHASE else "CLEAR"],Vector2(355,528),11,AMBER)
			_text("%s  H AIM  %s PAUSE  %s RETRY"%["SCRIPTED" if mission.active else "1/2/3 VIEW",OS.get_keycode_string(controls.bindings.pause),OS.get_keycode_string(controls.bindings.retry)],Vector2(550,528),10,MUTED)

func _draw_title() -> void:
	draw_rect(Rect2(Vector2.ZERO, SIZE), Color(INK, 0.48))
	for x in range(0, 540, 4):
		draw_rect(Rect2(x, 0, 4, 540), Color(INK, 0.72 * (1.0 - x / 540.0)))
	var center := Vector2(716, 269)
	draw_circle(center, 132, Color(TEAL, 0.035))
	draw_arc(center, 132, 0, TAU, 160, Color(TEAL, 0.17), 1, true)
	draw_arc(center, 102, 0.2, 2.5, 70, Color(AMBER, 0.3), 1, true)
	draw_line(center + Vector2(-160, 0), center + Vector2(160, 0), Color(TEAL, 0.12), 1)
	draw_line(center + Vector2(0, -155), center + Vector2(0, 155), Color(TEAL, 0.12), 1)
	AIRCRAFT_ART.draw_plane(self, center + Vector2(0, sin(visual_time * 0.8) * 4), 3.1, TEAL, Mode.CHASE, true, sin(visual_time * 0.4) * 0.035, "interceptor", visual_time)

func _text(value: String, pos: Vector2, font_size: int, color: Color) -> void:
	draw_string(font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _center(value: String, y: float, font_size: int, color: Color) -> void:
	var width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	_text(value, Vector2((960 - width) / 2, y), font_size, color)

func _smoke_test() -> void:
	set_process(false)
	# The accelerated headless simulation does not advance the audio clock.
	muted = true
	start_game()
	for next_mode in [Mode.CHASE, Mode.TOP, Mode.SIDE]:
		switch_mode(next_mode)
		for frame in range(1200):
			step(1.0 / 60, Vector2(sin(frame * 0.03), cos(frame * 0.021)) * 0.4, true)
			if frame % 240 == 100: special()
			if game_over:
				energy = 100
				game_over = false
		assert(enemies.size() < 40, "Enemy cleanup")
		assert(shots.size() < 100, "Projectile cleanup")
		assert(energy >= 0 and energy <= 100, "Energy range")
		print("SMOKE mode=", next_mode, " score=", score, " enemies=", enemies.size(), " shots=", shots.size())
	mode = Mode.CHASE
	_clear_combat()
	var saved_energy := energy
	var saved_score := score
	power = 2
	switch_mode(Mode.TOP)
	assert(energy == saved_energy and score == saved_score and power == 2, "Shared state survives switching")
	assert(enemies.is_empty() and hostile.is_empty() and shots.is_empty(), "Safe transition seam")
	# Air fire cannot damage a surface target; torpedoes can.
	mode = Mode.CHASE
	_clear_combat()
	enemies.append({"p": Vector3(0, 0.3, 10), "hp": 7, "surface": true})
	shots.append(CHASE_GUN.make_pair(flight))
	_update_shots(0.4)
	assert(enemies[0].hp == 7, "Air/surface separation")
	shots.clear()
	shots.append({"p": Vector3(0, 0.3, 4), "v": Vector3(0, 0, 15), "surface": true})
	_update_shots(0.5)
	assert(enemies.is_empty(), "Torpedo destroys boat")
	# Ordinary 2D hits, pickups, invulnerability, restart, and input routing.
	switch_mode(Mode.TOP)
	transition = 0
	invulnerable = 0
	player = Vector2(0.5, 0.5)
	enemies.append({"p": Vector2(480, 200), "hp": 1, "surface": false})
	shots.append({"p": Vector2(480, 300), "v": Vector2(0, -620), "surface": false})
	_update_shots(0.2)
	assert(enemies.is_empty(), "2D swept hit")
	energy = 50
	pickups.append({"p": player * SIZE})
	_update_pickups(0)
	assert(energy == 68 and power == 2, "Pickup restores energy and upgrades")
	damage(12)
	damage(12)
	assert(energy == 56, "Invulnerability prevents double hit")
	invulnerable = 0
	damage(100)
	assert(game_over and energy == 0, "Game over")
	start_game()
	assert(not game_over and energy == 100 and score == 0 and power == 1, "Restart")
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_1
	_unhandled_input(event)
	assert(mode == Mode.SIDE, "Keyboard mode switch")
	event.keycode = KEY_P
	_unhandled_input(event)
	assert(paused, "Keyboard pause")
	menu._input(event)
	assert(not paused, "Keyboard resume")
	if _test_chase_scroll_and_crash() != true:
		get_tree().quit(1)
		return
	CHASE_CHECKS.run(self)
	HORIZON_CHECKS.run(self)
	SCROLL_CHECKS.run(self)
	SKY_CHECKS.run(self)
	ENCOUNTER_CHECKS.run(self)
	ROSTER_CHECKS.run(self)
	BONUS_CHECKS.run(self)
	GUIDE_CHECKS.run(self)
	MENU_CHECKS.run(self)
	SETTINGS_CHECKS.run(self)
	MISSION_CHECKS.run(self)
	POSE_CHECKS.run(self)
	print("SMOKE PASS: three modes, combat, cleanup, convergence window, torpedoes, shared state, menus")
	sound.stop()
	sound.stream = null
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit()

func _test_chase_scroll_and_crash():
	var test_flight = CHASE_FLIGHT.new()
	var landmark := Vector3(12, 3.3, -100)
	var before: Vector2 = test_flight.project(landmark)
	for i in range(45): test_flight.advance(1.0 / 60, Vector2.RIGHT)
	var after: Vector2 = test_flight.project(landmark)
	assert(after.x < before.x - 120, "Right turn scrolls stationary world left")
	assert(absf(test_flight.aircraft_screen().x - 480) < 40, "Aircraft stays near chase camera center")
	var held_heading: float = test_flight.heading
	for i in range(120): test_flight.advance(1.0 / 60, Vector2.ZERO)
	assert(absf(angle_difference(held_heading, test_flight.heading)) < 0.1, "Short neutral response, no large drift")
	assert(test_flight.heading > 0.3, "Release keeps the new heading")
	for i in range(900): test_flight.advance(1.0 / 60, Vector2.RIGHT)
	assert(test_flight.heading >= 0 and test_flight.heading < TAU, "360 degree wrap")
	assert(test_flight.turn_rate > 0.9, "No turn stop at screen edge")
	test_flight.reset()
	test_flight.heading = TAU - 0.025
	test_flight.view_heading = test_flight.heading
	before = test_flight.project(landmark)
	for i in range(12): test_flight.advance(1.0 / 60, Vector2.RIGHT)
	after = test_flight.project(landmark)
	assert(absf(after.x - before.x) < 90, "Projection continuous at heading seam")
	test_flight.reset()
	var initial_horizon: float = test_flight.horizon()
	for i in range(150): test_flight.advance(1.0 / 60, Vector2.UP)
	assert(initial_horizon >= CHASE_FLIGHT.SEA_VIEW_BOTTOM and test_flight.horizon() > initial_horizon,
		"Cruise is already sky-only; climbing keeps the sea outside the playing field")
	for i in range(120): test_flight.advance(1.0 / 60, Vector2.ZERO)
	assert(is_equal_approx(test_flight.position.y, CHASE_FLIGHT.MAX_ALTITUDE) and not test_flight.crashed, "Upper altitude limit is safe")
	test_flight.reset()
	var warned := false
	for i in range(240):
		test_flight.advance(1.0 / 60, Vector2.DOWN)
		if test_flight.position.y < CHASE_FLIGHT.LOW_ALTITUDE and not test_flight.crashed: warned = true
	assert(warned and test_flight.crashed, "Low warning precedes actual sea impact")
	start_game()
	flight.position.y = 0.2
	transition = 10
	invulnerable = 10
	step(0.04, Vector2.DOWN, false)
	assert(game_over and energy == 0 and flight.crashed, "Sea impact bypasses combat invulnerability")
	assert(failure_reason == "SEA IMPACT / TOO LOW", "Explain crash reason")
	start_game()
	assert(not flight.crashed and flight.position.y > CHASE_FLIGHT.LOW_ALTITUDE, "Restart at safe altitude")
	spawn_wave()
	var enemy_count := enemies.size()
	flight.heading = PI
	flight.view_heading = PI
	_update_enemies(0)
	assert(enemies.size() == enemy_count, "Turning away hides targets without deleting them")
	assert(not _entity_visible(enemies[0]), "Air targets stay behind the new heading")
	start_game()
	print("CHASE PASS: world scroll, centered aircraft, retained heading, wrap continuity, vertical scroll, sea impact")
	return true

func _capture_player_animation() -> void:
	set_process(false)
	muted=true
	var folder := "res://outputs/player-animation-v0.16"
	DirAccess.make_dir_recursive_absolute(folder)
	# These are real control inputs through step(), not direct art rotations.
	var segments := [Vector2.ZERO,Vector2.RIGHT,Vector2.ZERO,Vector2.LEFT,
		Vector2.ZERO,Vector2.UP,Vector2.ZERO,Vector2.DOWN,Vector2.ZERO,
		Vector2(0.7,-0.7),Vector2.ZERO,Vector2(-0.7,0.7),Vector2.ZERO]
	for view in [Mode.CHASE,Mode.TOP,Mode.SIDE]:
		start_practice_mode(view)
		transition=0
		# Keep the short diagnostic lane quiet, without altering player physics.
		spawn_timer=99
		invulnerable=0
		var index := 0
		for segment in range(segments.size()):
			for frame in range(24):
				step(SIMULATION_STEP,segments[segment],true)
				assert(not game_over,"Controlled art flight remains safely in bounds")
				if frame%2!=0: continue
				queue_redraw()
				await RenderingServer.frame_post_draw
				assert(get_viewport().get_texture().get_image().save_png(folder+"/view-%d-%03d.png"%[view,index])==OK)
				index+=1
		print("PLAYER MOTION VIEW PASS: ",view," ",index," real engine frames")
	print("PLAYER MOTION PASS: three actual-size views, input/release/reversal/diagonals, original firing")
	get_tree().quit()

func _capture_views() -> void:
	set_process(false)
	muted = true
	var args := OS.get_cmdline_user_args()
	var folder := "res://work/captures"
	var flag := args.find("--capture-dir")
	if flag >= 0 and flag + 1 < args.size(): folder = args[flag + 1]
	DirAccess.make_dir_recursive_absolute(folder)
	for next_mode in [Mode.CHASE, Mode.TOP, Mode.SIDE]:
		start_game()
		switch_mode(next_mode)
		for frame in range(200): step(1.0 / 60, Vector2.ZERO, true)
		visual_time = 3.3
		queue_redraw()
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(folder + "/mode-%d.png" % next_mode)
	title = true
	menu.show_page("main")
	mode = Mode.CHASE
	queue_redraw()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(folder + "/title.png")
	sound.stop()
	sound.stream = null
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit()

func _capture_flight() -> void:
	set_process(false)
	muted = true
	var args := OS.get_cmdline_user_args()
	var folder := "res://work/flight-captures"
	var flag := args.find("--capture-dir")
	if flag >= 0 and flag + 1 < args.size(): folder = args[flag + 1]
	DirAccess.make_dir_recursive_absolute(folder)
	start_game()
	for i in range(90): step(1.0 / 60, Vector2.ZERO, true)
	await _save_flight_frame(folder, "cruise")
	for i in range(35): step(1.0 / 60, Vector2.RIGHT, true)
	await _save_flight_frame(folder, "right-turn")
	for i in range(150): step(1.0 / 60, Vector2.UP, true)
	await _save_flight_frame(folder, "high-altitude")
	start_game()
	for i in range(120): step(1.0 / 60, Vector2.DOWN, false)
	await _save_flight_frame(folder, "low-altitude")
	for i in range(20):
		if not game_over: step(1.0 / 60, Vector2.DOWN, false)
	crash_elapsed = 0.8
	await _save_flight_frame(folder, "sea-impact")
	get_tree().quit()

func _capture_aim() -> void:
	set_process(false)
	muted = true
	aim_helper = true
	var folder := "res://outputs/screenshots-v0.16/aim"
	DirAccess.make_dir_recursive_absolute(folder)
	for setting in [{"name": "neutral", "alt": 3.3, "climb": 0.0, "bank": 0.0},
		{"name": "climb", "alt": 5.8, "climb": 1.55, "bank": 0.0},
		{"name": "bank", "alt": 3.3, "climb": 0.0, "bank": 0.34}]:
		start_game()
		transition = 0
		flight.position.y = setting.alt
		flight.climb_rate = setting.climb
		flight.bank = setting.bank
		bank = flight.bank
		spawn_wave()
		fire()
		shots[0].age = 16.0 / 60
		await _save_flight_frame(folder, setting.name)
	start_game()
	transition = 0
	flight.position.y = 5.8
	flight.climb_rate = 1.55
	aim_helper = false
	spawn_wave()
	fire()
	shots[0].age = 16.0 / 60
	await _save_flight_frame(folder, "no-helper")
	get_tree().quit()

func _capture_encounter() -> void:
	set_process(false)
	muted = true
	var folder := "res://outputs/screenshots-v0.16/encounter"
	DirAccess.make_dir_recursive_absolute(folder)
	start_game()
	transition = 0
	spawn_wave()
	for setting in [{"name": "entry", "age": 0.0}, {"name": "approach", "age": 2.6},
		{"name": "close", "age": 4.1}, {"name": "side-exit", "age": 5.0}]:
		enemies[0].age = setting.age
		enemies[0].fire = 999
		_update_enemies(0)
		await _save_flight_frame(folder, setting.name)
	enemies[0].age = 2.6
	_update_enemies(0)
	await _save_flight_frame(folder, "scroll-center")
	flight.heading = 0.16
	flight.view_heading = 0.16
	flight.bank = 0.25
	bank = flight.bank
	await _save_flight_frame(folder, "scroll-right")
	flight.heading = TAU - 0.16
	flight.view_heading = flight.heading
	flight.bank = -0.25
	bank = flight.bank
	await _save_flight_frame(folder, "scroll-left")
	get_tree().quit()

func _capture_pursuit() -> void:
	set_process(false)
	muted = true
	var folder := "res://outputs/screenshots-v0.16/pursuit"
	DirAccess.make_dir_recursive_absolute(folder)
	for side in [-1, 1]:
		start_game()
		transition = 0
		var enemy := CHASE_ENCOUNTER.make_enemy(flight, 2 if side < 0 else 1, 0)
		# Reproduce the original v0.5 fixture rather than its current wave role.
		enemy.kind = "interceptor"
		enemy.route_duration = ENEMY_ROSTER.profile("interceptor").duration
		enemy.fire = 999
		enemies.append(enemy)
		var prefix := "left" if side < 0 else "right"
		var captured_bank := false
		var captured_old_expiry := false
		var captured_edge := false
		for frame in range(600):
			# Hold the same turn direction throughout the close pass and escape.
			flight.advance(SIMULATION_STEP, Vector2(side, 0) if enemy.age >= 3.7 else Vector2.ZERO)
			bank = flight.bank
			visual_time += SIMULATION_STEP
			_update_enemies(SIMULATION_STEP)
			var screen := _entity_screen(enemy)
			if not captured_bank and absf(enemy.bank) > 0.7:
				captured_bank = true
				await _save_flight_frame(folder, prefix + "-bank")
			if not captured_old_expiry and enemy.age >= enemy.route_duration + 0.15:
				captured_old_expiry = true
				assert(enemies.has(enemy) and screen.x > 64 and screen.x < 896,
					"Pursued aircraft remains visible beyond the old fixed expiry")
				await _save_flight_frame(folder, prefix + "-past-old-expiry")
			if not captured_edge and enemies.has(enemy) and (screen.x < 20 or screen.x > 940):
				captured_edge = true
				await _save_flight_frame(folder, prefix + "-edge")
			if not enemies.has(enemy):
				assert(CHASE_ENCOUNTER.finished(enemy, flight) and captured_old_expiry and captured_edge,
					"Capture observes a complete same-direction lateral escape")
				print("PURSUIT ", prefix, " exit age=", enemy.age, " x=", screen.x)
				await _save_flight_frame(folder, prefix + "-clear")
				break
		assert(enemies.is_empty(), "Pursued aircraft must escape even at maximum player turn")
	get_tree().quit()

func _capture_art() -> void:
	set_process(false)
	muted = true
	var folder := "res://outputs/screenshots-v0.16"
	DirAccess.make_dir_recursive_absolute(folder)
	for next_mode in [Mode.CHASE, Mode.TOP, Mode.SIDE]:
		start_game()
		switch_mode(next_mode)
		transition = 0
		power = 2
		visual_time = 4.0
		var display_kinds := ["interceptor","bomber","courier"] if mode == Mode.CHASE else ["interceptor","raider","bomber","courier"]
		for i in range(display_kinds.size()):
			var kind: String = display_kinds[i]
			if mode == Mode.CHASE:
				var enemy := CHASE_ENCOUNTER.make_enemy(flight, i + 1, 0)
				enemy.kind = kind
				enemy.age = enemy.route_duration * 0.65
				CHASE_ENCOUNTER.update(enemy)
				enemy.air_position = flight.air_position_from_screen(Vector2(290 + i * 225, 275 - (i % 2) * 55))
				enemy.chase_depth = 65.0 + i * 5
				enemy.bank = [-0.18, 0.28, 0.05][i]
				enemies.append(enemy)
			else:
				var p := Vector2(460 + i * 130, 245 + (i % 2) * 75) if mode == Mode.SIDE else Vector2(350 + i * 160, 230 - (i % 2) * 85)
				enemies.append({"p": p, "kind": kind, "surface": false, "hp": ENEMY_ROSTER.profile(kind).hp_2d})
		if mode == Mode.TOP:
			enemies.append({"p": Vector2(460,85),"surface":true,"vessel":"escort"})
			enemies.append({"p": Vector2(810,100),"surface":true,"vessel":"cargo"})
		fire()
		if mode == Mode.CHASE: shots[0].age = 12.0 / 60
		else:
			for shot in shots: shot.p += shot.v * 0.16
		hostile.append({"p": Vector2(500,330)} if mode != Mode.CHASE else {"air_position":flight.air_position_from_screen(Vector2(655,340))})
		await _save_flight_frame(folder, ["coastal-pass", "island-airfield", "dawn-intercept"][mode])
	art_gallery = true
	await _save_flight_frame(folder, "aircraft-roster")
	get_tree().quit()

func _draw_aircraft_sheet() -> void:
	_text("SKYFIRE 1943  /  ORIGINAL AIRCRAFT STUDY", Vector2(30,38),20,WHITE)
	_text("0.16  /  SAME PALETTE, DISTINCT SILHOUETTES, DISTANCE-AWARE DETAIL",Vector2(30,61),12,MUTED)
	var names := ["TWIN-BOOM FIGHTER", "RADIAL INTERCEPTOR", "LONG-NOSE RAIDER", "TWIN-ENGINE ATTACKER", "GOLD COURIER"]
	var kinds := ["interceptor","interceptor","raider","bomber","courier"]
	for col in range(5):
		var x := 24 + col * 184
		draw_rect(Rect2(x,89,176,421),Color("142637"))
		var color := TEAL if col==0 else AMBER if col==4 else RED
		draw_line(Vector2(x,89),Vector2(x+176,89),color,2)
		_text(names[col],Vector2(x+9,116),10,WHITE)
		for view in range(3):
			var center := Vector2(x+88,181+view*121)
			AIRCRAFT_ART.draw_plane(self,center,1.2,color,view,col==0,0,kinds[col],visual_time)
			_text(["SIDE", "TOP", "CHASE / REAR" if col==0 else "CHASE / FRONT"][view],Vector2(x+12,center.y+48),10,MUTED)
	_text("FICTIONAL DESIGNS  /  NO ORIGINAL GAME ASSETS OR HISTORICAL INSIGNIA",Vector2(30,533),11,MUTED)

func _capture_altitude() -> void:
	set_process(false)
	muted = true
	var folder := "res://outputs/screenshots-v0.16/altitude"
	DirAccess.make_dir_recursive_absolute(folder)
	for setting in [{"name":"cruise-sky", "height":3.3},
		{"name":"above-third", "height":2.2}, {"name":"third-boundary", "height":CHASE_FLIGHT.SEA_VISIBLE_BELOW},
		{"name":"first-sea", "height":2.0}, {"name":"quarter-height", "height":1.575},
		{"name":"low-warning", "height":0.9}, {"name":"near-sea", "height":0.3},
		{"name":"maximum-sky", "height":CHASE_FLIGHT.MAX_ALTITUDE}]:
		start_game()
		transition = 0
		flight.position.y = setting.height
		spawn_wave()
		enemies[0].age = 2.6
		enemies[0].fire = 999
		_update_enemies(0)
		fire()
		shots[0].age = 16.0 / 60
		await _save_flight_frame(folder, setting.name)
	get_tree().quit()

func _capture_scroll() -> void:
	set_process(false)
	muted = true
	var folder := "res://outputs/screenshots-v0.16/scroll"
	DirAccess.make_dir_recursive_absolute(folder)
	# Freeze autonomous routes to make camera scroll visible against the sky.
	for direction in [1, -1]:
		start_game()
		transition = 0
		flight.position.y = 0.9
		spawn_wave()
		enemies[0].age = 2.6
		CHASE_ENCOUNTER.update(enemies[0])
		enemies[0].air_position = flight.air_position_from_screen(Vector2(580, 165))
		for point in [Vector3(-7, 0.22, -35), Vector3(35, 0.22, -100)]:
			enemies.append({"p":point, "surface":true, "hp":7, "vessel":"escort"})
		var label := "right" if direction == 1 else "left"
		await _save_flight_frame(folder, label + "-neutral")
		for tick in range(24):
			flight.advance(SIMULATION_STEP, Vector2(direction, 0))
			if tick in [11, 23]:
				await _save_flight_frame(folder, label + "-%02d" % (tick + 1))
				print("SCROLL FRAME ", label, " cloud_x=", flight.bearing_screen(0.0),
					" island_x=", flight.bearing_screen(0.05), " air_x=", _entity_screen(enemies[0]).x,
					" near_ship_x=", _entity_screen(enemies[1]).x, " far_ship_x=", _entity_screen(enemies[2]).x)
	get_tree().quit()

func _capture_sky() -> void:
	set_process(false)
	muted = true
	var folder := "res://outputs/screenshots-v0.16/sky"
	DirAccess.make_dir_recursive_absolute(folder)
	start_game()
	transition = 0
	flight.position.y = 4.0
	await _save_flight_frame(folder, "high-neutral")
	for tick in range(60): flight.advance(SIMULATION_STEP, Vector2.UP)
	await _save_flight_frame(folder, "high-climb")
	for tick in range(120): flight.advance(SIMULATION_STEP, Vector2.UP)
	await _save_flight_frame(folder, "ceiling")
	for tick in range(60): flight.advance(SIMULATION_STEP, Vector2.DOWN)
	await _save_flight_frame(folder, "high-descent")
	for tick in range(120): flight.advance(SIMULATION_STEP, Vector2.ZERO)
	await _save_flight_frame(folder, "high-released")
	for tick in range(24): flight.advance(SIMULATION_STEP, Vector2.RIGHT)
	await _save_flight_frame(folder, "high-right-turn")
	get_tree().quit()

func _save_flight_frame(folder: String, label: String, preserve_protection := false) -> void:
	if not preserve_protection: invulnerable = 0
	mission_overlay.refresh()
	queue_redraw()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(folder + "/" + label + ".png")
	print("CAPTURE ", label, " hdg=", rad_to_deg(flight.heading), " alt=", flight.position.y, " horizon=", flight.horizon(), " sea_visible=", flight.sea_visible(), " game_over=", game_over)

func _capture_menu() -> void:
	set_process(false)
	muted = true
	var args := OS.get_cmdline_user_args()
	var folder := "res://outputs/screenshots-v0.16"
	var flag := args.find("--capture-dir")
	if flag >= 0 and flag + 1 < args.size(): folder = args[flag + 1]
	DirAccess.make_dir_recursive_absolute(folder)
	var saved_developer := developer_mode
	developer_mode = false
	return_to_menu()
	await _save_flight_frame(folder, "player-menu")
	menu.open_settings("main")
	await _save_flight_frame(folder, "settings")
	menu.return_page = "main"
	menu.show_page("help")
	await _save_flight_frame(folder, "controls")
	developer_mode = true
	return_to_menu()
	await _save_flight_frame(folder, "developer-main")
	menu.show_page("developer")
	await _save_flight_frame(folder, "developer-menu")
	for scene_id in ["side", "top", "high", "sea", "approach", "bonus"]:
		start_debug_scene(scene_id)
		await _save_flight_frame(folder, "scene-" + scene_id)
	paused = true
	menu.show_page("pause")
	await _save_flight_frame(folder, "pause")
	paused = false
	game_over = true
	menu.sync_game_state()
	await _save_flight_frame(folder, "flight-ended")
	developer_mode = saved_developer
	get_tree().quit()

func _capture_catalog() -> void:
	set_process(false)
	muted = true
	menu.hide_menu()
	var folder := "res://outputs/unit-art-v0.16"
	DirAccess.make_dir_recursive_absolute(folder)
	var catalog := UNIT_CATALOG.describe()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(768,480)
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var illustration := UNIT_CATALOG.new()
	viewport.add_child(illustration)
	for unit in catalog.units:
		for view in unit.views:
			illustration.kind = unit.id
			illustration.view = view
			illustration.queue_redraw()
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			assert(viewport.get_texture().get_image().save_png(folder+"/%s-%d.png"%[unit.id,view])==OK,"Catalog image saved")
	var data := FileAccess.open(folder+"/units.json",FileAccess.WRITE)
	assert(data!=null,"Catalog data file opens")
	data.store_string(JSON.stringify(catalog,"\t"))
	data.close()
	print("CATALOG PASS: ",catalog.units.size()," units; exact game art and runtime roster data")
	get_tree().quit()

func _check_build() -> void:
	set_process(false)
	muted = true
	var expected := "--expect-developer" in OS.get_cmdline_user_args()
	assert(developer_mode == expected, "Exported build feature matches intended audience")
	assert(menu.buttons.has("developer") == expected, "Correct main-menu visibility in exported build")
	assert(not aim_helper and not torpedo_helper,"Exported app defaults hide both aim guides")
	await get_tree().process_frame
	await get_tree().process_frame
	assert(get_viewport().gui_get_focus_owner() == menu.buttons.start, "Initial keyboard focus")
	await _check_click(Vector2(1800, 800))
	assert(title and menu.page == "main", "No click-anywhere start")
	menu.buttons.start.grab_focus()
	await _check_key(KEY_DOWN)
	assert(get_viewport().gui_get_focus_owner()==menu.buttons.practice,"Practice is a separate player entry")
	await _check_key(KEY_DOWN)
	assert(get_viewport().gui_get_focus_owner() == menu.buttons.settings, "Arrow-key navigation through native UI")
	await _check_key(KEY_ENTER)
	assert(title and menu.page == "settings", "Enter activates selected settings")
	for section in ["graphics","audio","controls","display"]:
		await _check_click(menu.buttons["section_"+section].get_global_rect().get_center())
		assert(menu.settings_section==section,"Native category navigation")
	menu.display_draft.frame_limit=120
	await _check_click(menu.buttons.apply_display.get_global_rect().get_center())
	assert(menu.page=="display_confirm" and frame_limit==120,"Native display apply starts confirmation")
	await _check_key(KEY_ESCAPE)
	assert(menu.page=="settings" and frame_limit==60,"Native Escape reverts provisional display settings")
	await _check_click(menu.buttons.section_controls.get_global_rect().get_center())
	await _check_click(menu.buttons.key_bindings.get_global_rect().get_center())
	await _check_click(menu.buttons.bind_fire.get_global_rect().get_center())
	await _check_key(KEY_F)
	assert(controls.bindings.fire==KEY_F and menu.binding_action.is_empty(),"Native keyboard capture reaches input bindings")
	await _check_click(menu.buttons.bind_special.get_global_rect().get_center())
	await _check_key(KEY_F)
	assert(not menu.binding_action.is_empty() and controls.bindings.special==KEY_X,"Native conflicting key is rejected")
	await _check_key(KEY_ESCAPE)
	assert(menu.binding_action.is_empty() and menu.page=="settings","Native Escape cancels key capture, not the page")
	await _check_click(menu.buttons.reset.get_global_rect().get_center())
	assert(controls.bindings==CONTROLS.DEFAULT_KEYS,"Native keyboard reset")
	await _check_click(menu.buttons.section_game.get_global_rect().get_center())
	var initial_aim := aim_helper
	await _check_click(menu.buttons.aim.get_global_rect().get_center())
	assert(aim_helper != initial_aim, "HD mouse coordinates activate the intended setting")
	await _check_click(menu.buttons.torpedo.get_global_rect().get_center())
	assert(torpedo_helper and aim_helper!=initial_aim,"Native torpedo toggle is independent of gun guide")
	await _check_key(KEY_ESCAPE)
	assert(menu.page == "main", "Escape returns to main")
	await _check_click(menu.buttons.practice.get_global_rect().get_center())
	assert(menu.page=="practice","Native practice entry is separate from the mission")
	await _check_click(menu.buttons.practice_top.get_global_rect().get_center())
	assert(mode==Mode.TOP and not mission.active and not title,"Native practice chooses a sandbox view")
	await _check_key(KEY_ESCAPE)
	await _check_click(menu.buttons.main.get_global_rect().get_center())
	await get_tree().process_frame
	await _check_key(KEY_ENTER)
	assert(not title and not menu.visible and mission.active, "Enter starts the mission")
	await _check_key(KEY_ESCAPE)
	assert(paused and menu.page == "pause", "Real input opens pause")
	await _check_key(KEY_ESCAPE)
	assert(not paused and not menu.visible, "Real input resumes flight")
	if expected:
		await _check_key(KEY_F1)
		assert(title and menu.page == "developer", "F1 opens developer scene selection")
		await get_tree().process_frame
		await _check_key(KEY_ENTER)
		assert(mode == Mode.SIDE and debug_scene == "side", "Scene launches through keyboard UI")
		await _check_key(KEY_F1)
		await _check_click(menu.buttons.boss.get_global_rect().get_center())
		assert(mission.phase==2 and debug_scene=="boss" and mission.active,"Native developer Boss entry")
	else:
		await _check_key(KEY_F1)
		assert(not title, "Player build ignores developer shortcut")
	print("BUILD PASS: ", "developer" if expected else "player", "; native mission/practice, categories, display revert, key capture/conflict/reset, guides, pause and Boss scene gating; viewport=", get_viewport_rect().size)
	get_tree().quit()

func _capture_mission() -> void:
	set_process(false)
	muted=true
	var folder := "res://outputs/screenshots-v0.16/mission"
	DirAccess.make_dir_recursive_absolute(folder)
	return_to_menu()
	await _save_flight_frame(folder,"main")
	menu.show_page("practice")
	await _save_flight_frame(folder,"practice")
	start_mission()
	await _save_flight_frame(folder,"mission-entry",true)
	var saved: Dictionary = {}
	for frame in range(9600):
		step(SIMULATION_STEP,MISSION_CHECKS.pilot_input(self),true)
		var name := ""
		if view_transition.active:
			var sample := floori(view_transition.progress()*4)
			var transition_name := "view-%d-%d"%[view_transition.next_mode,sample]
			if not saved.has(transition_name): name=transition_name
		if mission.phase==1 and mission.phase_time>2.5 and not saved.has("top-formation"): name="top-formation"
		for enemy in enemies:
			if mission.phase==0 and enemy.get("kind","")=="interceptor" and enemy.age>2.25 and not saved.has("chase-intercept"): name="chase-intercept"
			if enemy.get("kind","")=="courier" and enemy.age>1 and not saved.has("reward-intercept"): name="reward-intercept"
			if enemy.surface and enemy.age>5.55 and not saved.has("escort-fire"): name="escort-fire"
			if enemy.get("boss",false):
				if CHASE_BOSS.holding(enemy) and not saved.has("boss-hold"): name="boss-hold"
				if CHASE_BOSS.holding(enemy) and enemy.air_position.x<enemy.route_end.x-50 and not saved.has("boss-left"): name="boss-left"
				if CHASE_BOSS.holding(enemy) and enemy.air_position.x>enemy.route_end.x+50 and not saved.has("boss-right"): name="boss-right"
				if enemy.hp<=CHASE_BOSS.MAX_HP/2 and not saved.has("boss-damaged"): name="boss-damaged"
		for item in pickups:
			if item.get("mission_supply",false) and not saved.has("supply-lane"): name="supply-lane"
		if not name.is_empty():
			saved[name]=true
			await _save_flight_frame(folder,name,true)
		if victory or game_over: break
	assert(victory,"Actual rendered pilot completes mission without cheats")
	var seconds: float = mission.time
	var remaining: float = energy
	menu.sync_game_state()
	await _save_flight_frame(folder,"victory",true)
	start_mission()
	flight.position.y=0.19
	for frame in range(60):
		if not game_over: step(SIMULATION_STEP,Vector2.DOWN,false)
	crash_elapsed=0.7
	menu.sync_game_state()
	assert(menu.page=="over" and not victory,"Actual sea impact gives mission failure, not victory")
	await _save_flight_frame(folder,"failure",true)
	print("MISSION VISUAL PASS: native camera bridge frames, fixed-distance Boss evasion, scripted stages, supply, victory/failure; controlled pilot=",seconds,"s energy=",remaining)
	get_tree().quit()

func _capture_transitions() -> void:
	set_process(false)
	muted=true
	apply_setting("render_quality",0,false)
	start_mission()
	transition=0
	visual_time=29
	flight.position.y=3.7
	flight.heading=0.2
	flight.view_heading=0.2
	flight.bank=0.16
	bank=0.16
	power=2
	mission.saved_position=flight.position
	mission.saved_heading=flight.heading
	var folder := "res://outputs/screenshots-v0.16/transition-motion"
	DirAccess.make_dir_recursive_absolute(folder)
	var index := 0
	for view in [Mode.TOP,Mode.CHASE]:
		_begin_mission_transition(view,1 if view==Mode.TOP else 2)
		for frame in range(79):
			if frame>0: step(1.0/30,Vector2.ZERO,false)
			mission_overlay.refresh()
			queue_redraw()
			await RenderingServer.frame_post_draw
			assert(get_viewport().get_texture().get_image().save_png(folder+"/%03d.png"%index)==OK,"Native motion frame saved")
			index+=1
		assert(not view_transition.active and mode==view,"Actual bridge reaches its exact endpoint")
	print("TRANSITION VISUAL PASS: 158 actual engine frames, both camera bridges, exact aircraft endpoints, no combat or physical altitude change")
	get_tree().quit()

func _capture_boss_motion() -> void:
	# Visual-only inspection: stationary camera and the exact autonomous model.
	set_process(false)
	muted=true
	apply_setting("render_quality",0,false)
	start_mission()
	transition=0
	invulnerable=0
	mission.phase=2
	mission.update(self,0)
	var boss: Dictionary = enemies[0]
	var folder := "res://outputs/screenshots-v0.16/boss-motion"
	DirAccess.make_dir_recursive_absolute(folder)
	for frame in range(132):
		boss.age=CHASE_BOSS.ENTRY_SECONDS+frame/30.0
		CHASE_BOSS.update(boss)
		visual_time=65+frame/30.0
		mission.time=visual_time
		mission_overlay.refresh()
		queue_redraw()
		await RenderingServer.frame_post_draw
		assert(is_equal_approx(boss.chase_depth,CHASE_BOSS.HOLD_DEPTH),"Actual motion frames hold Boss distance")
		assert(get_viewport().get_texture().get_image().save_png(folder+"/%03d.png"%frame)==OK,"Boss motion frame saved")
	print("BOSS MOTION VISUAL PASS: 132 real render frames, fixed depth 68, stationary camera, autonomous horizontal/vertical evasion")
	get_tree().quit()

func _check_key(key: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.pressed = pressed
		get_viewport().push_input(event, true)
		await get_tree().process_frame

func _capture_guides() -> void:
	set_process(false)
	muted = true
	var folder := "res://outputs/screenshots-v0.16/guides"
	DirAccess.make_dir_recursive_absolute(folder)
	start_game()
	transition = 0
	flight.position.y = 1.2
	var gun_position: Vector2 = flight.aim_screen()*2
	var sea_aim: Vector3 = flight.position+flight.forward()*70
	sea_aim.y = 0.22
	var sea_position: Vector2 = flight.project(sea_aim)*2
	var gun_regions: Array[PackedByteArray] = []
	var sea_regions: Array[PackedByteArray] = []
	for settings in [{"name":"both-off","gun":false,"sea":false},
		{"name":"gun-only","gun":true,"sea":false},
		{"name":"torpedo-only","gun":false,"sea":true},
		{"name":"both-on","gun":true,"sea":true}]:
		aim_helper = settings.gun
		torpedo_helper = settings.sea
		await _save_flight_frame(folder,settings.name)
		var frame := get_viewport().get_texture().get_image()
		gun_regions.append(frame.get_region(Rect2i(Vector2i(gun_position)-Vector2i(26,26),Vector2i(52,52))).get_data())
		sea_regions.append(frame.get_region(Rect2i(Vector2i(sea_position)-Vector2i(44,12),Vector2i(100,56))).get_data())
	assert(gun_regions[0]==gun_regions[2] and gun_regions[1]==gun_regions[3] and gun_regions[0]!=gun_regions[1],"Actual gun guide pixels follow only gun setting")
	assert(sea_regions[0]==sea_regions[1] and sea_regions[2]==sea_regions[3] and sea_regions[0]!=sea_regions[2],"Actual torpedo guide pixels follow only torpedo setting")
	aim_helper = false
	torpedo_helper = false
	return_to_menu()
	menu.open_settings("main")
	menu.select_settings_section("game")
	await _save_flight_frame(folder,"settings-defaults")
	print("GUIDE VISUAL PASS: four actual HD render combinations; both default off; independent pixel regions")
	get_tree().quit()

func _capture_settings() -> void:
	set_process(false)
	muted=false
	var folder := "res://outputs/screenshots-v0.16/settings"
	DirAccess.make_dir_recursive_absolute(folder)
	menu.open_settings("main")
	for section in ["display","graphics","audio","game","controls","keys"]:
		menu.select_settings_section(section)
		await _save_flight_frame(folder,section)
		assert(get_viewport().get_texture().get_image().get_size()==Vector2i(1920,1080),"HD settings screenshot")
	menu._begin_binding("fire")
	await _save_flight_frame(folder,"key-capture")
	menu.binding_action=""
	menu.select_settings_section("display")
	menu.display_draft.window_preset=0
	menu.begin_display_change()
	await _save_flight_frame(folder,"display-confirm")
	menu.cancel_display_change()
	menu.select_settings_section("graphics")
	apply_setting("render_quality",0,false)
	menu.show_page("settings")
	await _save_flight_frame(folder,"graphics-standard")
	assert(get_viewport().get_texture().get_image().get_size()==Vector2i(1280,720),"Standard quality changes actual render resolution")
	apply_setting("render_quality",2,false)
	start_game()
	transition=0
	await _save_flight_frame(folder,"flight-defaults")
	apply_setting("hitbox_helper",true,false)
	apply_setting("show_fps",true,false)
	apply_setting("show_controls",false,false)
	await _save_flight_frame(folder,"flight-display-aids")
	print("SETTINGS VISUAL PASS: six settings pages, capture, confirmation, actual 1280/1920 render sizes and optional HUD aids")
	get_tree().quit()

func _check_click(position_value: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = position_value
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		get_viewport().push_input(event, true)
		await get_tree().process_frame
