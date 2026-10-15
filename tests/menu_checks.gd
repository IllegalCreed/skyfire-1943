extends RefCounted
## Regression checks for menu isolation, scene initialization and local preferences.

static func run(game) -> void:
	var saved_developer: bool = game.developer_mode
	var saved_settings: String = game.settings_path
	var saved_volume: float = game.audio_volume
	var saved_aim: bool = game.aim_helper
	var saved_torpedo: bool = game.torpedo_helper
	game.developer_mode = false
	game.return_to_menu()
	assert(game.title and game.menu.visible and not game.menu.buttons.has("developer"), "Player build has no developer entry")
	game.menu.show_page("developer")
	assert(game.menu.page == "main", "Hidden developer page also rejects direct access")
	game.start_debug_scene("high")
	assert(game.title, "Player mode cannot start a developer scenario")
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_R
	game._unhandled_input(event)
	assert(game.title, "Gameplay shortcuts cannot bypass a menu")
	game.menu.buttons.settings.pressed.emit()
	assert(game.menu.page == "settings", "Settings button opens settings instead of starting flight")
	game.menu.go_back()
	game.menu.buttons.start.pressed.emit()
	assert(not game.title and not game.menu.visible and game.mode == game.Mode.CHASE and game.mission.active, "Normal start enters single-player mission")
	event.keycode = KEY_ESCAPE
	game._unhandled_input(event)
	assert(game.paused and game.menu.page == "pause", "Pause opens navigation")
	var before: float = game.elapsed
	game._process(1.0)
	assert(game.elapsed == before, "Menu freezes gameplay")
	game.menu.buttons.settings.pressed.emit()
	game.menu.go_back()
	assert(game.paused and game.menu.page == "pause", "Returning from pause settings stays paused")
	game.menu.go_back()
	assert(not game.paused and not game.menu.visible, "Escape resumes pause")
	event.keycode = KEY_F1
	game._unhandled_input(event)
	assert(not game.title, "F1 has no developer effect in player mode")
	game.developer_mode = true
	game.return_to_menu()
	assert(game.menu.buttons.has("developer"), "Developer build exposes developer entry")
	game.menu.buttons.developer.pressed.emit()
	assert(game.menu.page == "developer" and game.menu.buttons.size() == 9, "Eight scenes and back button")
	for caption in ["敌机接近", "远近与侧飞", "追尾巡航"]:
		for character in caption:
			assert(game.menu.ui_font.has_char(character.unicode_at(0)), "Menu font covers simplified Chinese")
	for scene_id in ["side", "top", "chase", "high", "sea", "approach", "bonus"]:
		game.start_debug_scene(scene_id)
		assert(not game.title and not game.paused and not game.game_over, "Debug scenario enters live game")
		assert(game.energy == 100 and game.score == 0 and game.power == 1, "Independent fresh scene state")
		assert(game.debug_scene == scene_id, "Active scenario recorded")
		if scene_id == "side": assert(game.mode == game.Mode.SIDE, "Side scenario")
		elif scene_id == "top": assert(game.mode == game.Mode.TOP, "Top scenario")
		elif scene_id == "high": assert(is_equal_approx(game.flight.position.y, 4.6) and not game.flight.sea_visible(), "High sky scenario")
		elif scene_id == "sea":
			assert(is_equal_approx(game.flight.position.y, 1.5) and game.flight.sea_visible(), "Sea scenario")
			game.step(1.0 / 60, Vector2.ZERO, false)
			assert(game.enemies[0].surface, "Low sea ship uses real gameplay update")
		elif scene_id == "approach":
			assert(game.enemies.size() == 1 and game.enemies[0].age == 2.6, "Immediate approach scenario")
		elif scene_id == "bonus":
			assert(game.enemies.size() == 1 and game.enemies[0].kind == "courier", "Bonus scene starts the actual reward aircraft")
		game.energy = 37
		game.restart_session()
		assert(game.debug_scene == scene_id and game.energy == 100, "Retry restores the selected debug scene")
	game._unhandled_input(event)
	assert(game.title and game.menu.page == "developer" and game.enemies.is_empty(), "F1 returns and clears threats")
	game.start_game()
	game.game_over = true
	game.menu.sync_game_state()
	assert(game.menu.page == "over", "Flight end gives retry and main navigation")
	event.keycode = KEY_R
	game.menu._input(event)
	assert(not game.game_over and not game.menu.visible, "R still retries after flight end")
	game.game_over = true
	game.menu.sync_game_state()
	game.menu.buttons.main.pressed.emit()
	assert(game.title and not game.game_over, "Return to main after failure")
	# Exercise real serialization in a unique temporary file, never the player's preferences.
	game.settings_path = "user://menu-check-%d.cfg" % Time.get_ticks_usec()
	game.apply_setting("volume", 0.35, false)
	game.apply_setting("aim_helper", false, false)
	game.apply_setting("torpedo_helper", true, false)
	game.apply_setting("muted", true, false)
	game.apply_setting("fullscreen", true, false)
	assert(game._save_settings() == OK, "Preferences save")
	game.audio_volume = 1
	game.aim_helper = true
	game.torpedo_helper = false
	game.muted = false
	game.fullscreen = false
	game._load_settings()
	assert(is_equal_approx(game.audio_volume, 0.35) and not game.aim_helper and game.torpedo_helper and game.muted and game.fullscreen, "Preferences and independent guides survive reload")
	assert(DirAccess.remove_absolute(ProjectSettings.globalize_path(game.settings_path)) == OK, "Temporary test preferences removed")
	# Legacy saves cannot tell the old enabled default from an explicit choice.
	var legacy := ConfigFile.new()
	legacy.set_value("audio","volume",0.45)
	legacy.set_value("audio","muted",true)
	legacy.set_value("display","fullscreen",true)
	legacy.set_value("play","aim_helper",true)
	legacy.set_value("custom","keep","retained")
	assert(legacy.save(game.settings_path)==OK,"Legacy settings fixture saved")
	game._load_settings()
	assert(not game.aim_helper and not game.torpedo_helper,"Legacy guides migrate to the new disabled default")
	assert(is_equal_approx(game.audio_volume,0.45) and game.muted and game.fullscreen,"Legacy audio/display preferences are retained")
	var migrated := ConfigFile.new()
	assert(migrated.load(game.settings_path)==OK and migrated.get_value("play","aim_guides_version")==2,"Migration saved once")
	assert(migrated.get_value("custom","keep")=="retained","Unrelated settings survive migration")
	game.apply_setting("aim_helper",true,false)
	game.apply_setting("torpedo_helper",true,false)
	assert(game._save_settings()==OK,"Explicit new guide choices saved")
	game.aim_helper = false
	game.torpedo_helper = false
	game._load_settings()
	assert(game.aim_helper and game.torpedo_helper,"New explicit choices are not reset on later launches")
	assert(DirAccess.remove_absolute(ProjectSettings.globalize_path(game.settings_path))==OK,"Migration test file removed")
	game.settings_path = saved_settings
	game.audio_volume = saved_volume
	game.aim_helper = saved_aim
	game.torpedo_helper = saved_torpedo
	game.fullscreen = false
	game.muted = true
	game.developer_mode = saved_developer
	game.return_to_menu()
	assert(is_equal_approx(game.scale.x, 2.0) and game.menu.scale == game.scale, "HD renderer scales world and UI equally")
	print("MENU PASS: player isolation, scene launch, pause, retry, return, preferences, HD scale")
