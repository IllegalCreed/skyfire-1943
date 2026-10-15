extends RefCounted
## Settings persistence, safety revert, key capture and one-player controller routing.

const CONTROLS := preload("res://src/input/player_controls.gd")

static func _key(code: int, pressed := true) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode=code
	event.pressed=pressed
	return event

static func run(game) -> void:
	var saved: Dictionary = game.settings_snapshot()
	var saved_path: String = game.settings_path
	game.return_to_menu()
	game.menu.open_settings("main")
	for section in ["display","graphics","audio","game","controls","keys"]:
		game.menu.select_settings_section(section)
		assert(game.menu.page=="settings" and game.menu.buttons.has("reset"),"Every settings category has a real page and reset")
	# Settings change sound/render presentation, never the fixed gameplay tick.
	game.apply_setting("master_volume",0.5,false)
	game.apply_setting("volume",0.4,false)
	assert(absf(game.sound.volume_db-(-10+linear_to_db(0.2)))<0.001,"Master and effects volumes both reach the audio player")
	game.apply_setting("brightness",0.9,false)
	assert(is_equal_approx(game.modulate.r,0.9),"Brightness changes the actual game canvas")
	game.apply_setting("render_quality",0,false)
	assert(game.get_window().content_scale_size==Vector2i(1280,720),"Render quality changes the actual viewport base size")
	game.apply_setting("frame_limit",999,false)
	assert(game.frame_limit==60,"Invalid frame cap safely falls back")
	# Display changes are provisional until confirmed and automatically revert.
	game.menu.select_settings_section("display")
	var old_display: Dictionary = game.settings_snapshot("display")
	game.menu.display_draft.fullscreen=not game.fullscreen
	game.menu.display_draft.window_preset=0
	game.menu.begin_display_change()
	assert(game.menu.page=="display_confirm" and game.fullscreen!=old_display.fullscreen,"Display preview is active")
	game.menu._process(15.1)
	assert(game.settings_snapshot("display")==old_display and game.menu.page=="settings","Unconfirmed display mode automatically reverts")
	game.menu.display_draft.frame_limit=120
	game.menu.begin_display_change()
	game.menu.confirm_display_change()
	assert(game.frame_limit==120 and game.menu.page=="settings","Confirmed display choice is retained")
	# Native key-capture path updates bindings; conflicts and cancellation are safe.
	game.menu.select_settings_section("keys")
	for action in CONTROLS.ACTIONS:
		assert(game.menu.buttons["bind_"+action].size.y<=27,"Compact key rows do not overlap: %s"%game.menu.buttons["bind_"+action].size)
	game.menu._begin_binding("fire")
	game.menu._input(_key(KEY_F))
	assert(game.controls.bindings.fire==KEY_F and game.menu.binding_action.is_empty(),"Key capture saves a valid remap")
	game.menu._begin_binding("special")
	game.menu._input(_key(KEY_F))
	assert(game.controls.bindings.special==KEY_X and not game.menu.binding_action.is_empty(),"Conflicting key is rejected")
	game.menu._input(_key(KEY_ESCAPE))
	assert(game.menu.binding_action.is_empty(),"Esc cancels rebinding")
	assert(not game.rebind_key("fire",KEY_F1).is_empty(),"Prototype/menu reserved keys cannot be stolen")
	game.controls.deadzone=0.27
	game.menu.reset_current_section()
	assert(game.controls.bindings==CONTROLS.DEFAULT_KEYS and is_equal_approx(game.controls.deadzone,0.27),"Keyboard-page reset does not reset device preferences")
	assert(game.rebind_key("fire",KEY_F).is_empty(),"Test firing remap restored")
	# Exercise actual input routing with recorded device events, not only labels.
	game.start_game()
	game._input(_key(KEY_F))
	assert(game.controls.pressed("fire"),"Remapped keyboard fire reaches gameplay input")
	game._input(_key(KEY_F,false))
	assert(not game.controls.pressed("fire"),"Release ends remapped firing")
	# Losing focus pauses active play but must never discard a settings/confirmation page.
	var saved_automation: bool = game.automation
	game.automation=false
	game._on_focus_lost()
	assert(game.paused and game.menu.page=="pause","Active single-player flight pauses on focus loss")
	game.menu.open_settings("pause")
	game._on_focus_lost()
	assert(game.menu.page=="settings","Already paused settings survive focus loss")
	game.automation=saved_automation
	game.resume_game()
	assert(game.rebind_key("pause",KEY_Q).is_empty(),"Pause can be remapped")
	game._unhandled_input(_key(KEY_Q))
	assert(game.paused and game.menu.page=="pause","Remapped key pauses active gameplay")
	game.menu._input(_key(KEY_Q))
	assert(not game.paused and not game.menu.visible,"The same remapped key resumes through the menu")
	game.controls.bindings.pause=KEY_ESCAPE
	game.controls.input_mode=0
	var motion := InputEventJoypadMotion.new()
	motion.device=71
	motion.axis=JOY_AXIS_LEFT_X
	motion.axis_value=0.05
	game._input(motion)
	assert(game._movement().is_zero_approx(),"Controller deadzone suppresses drift")
	motion.axis_value=0.8
	game._input(motion)
	assert(game._movement().x>0.7,"Controller axis reaches the real movement path")
	game.controls.input_mode=1
	assert(game._movement().is_zero_approx(),"Keyboard-only mode rejects controller movement")
	game.controls.input_mode=0
	motion.axis=JOY_AXIS_LEFT_X
	motion.axis_value=0
	game._input(motion)
	motion.axis=JOY_AXIS_LEFT_Y
	motion.axis_value=-0.8
	game._input(motion)
	game.controls.invert_chase_y=false
	var normal: Vector2 = game._movement()
	game.controls.invert_chase_y=true
	assert(game._movement().y==-normal.y,"Chase pitch inversion changes only input sign")
	var button := InputEventJoypadButton.new()
	button.device=71
	button.button_index=JOY_BUTTON_A
	button.pressed=true
	game._input(button)
	assert(game.controls.pressed("fire"),"Controller fire reaches gameplay")
	button.pressed=false
	game._input(button)
	game.controls.forget_device(71)
	game.controls.input_mode=2
	assert(game.controls.keyboard_enabled(),"Absent controller cannot lock the player out")
	# Round-trip every category and keys through an isolated real preferences file.
	game.settings_path="user://settings-check-%d.cfg"%Time.get_ticks_usec()
	game.apply_setting("particle_quality",0,false)
	game.apply_setting("hitbox_helper",true,false)
	game.apply_setting("pause_on_focus_loss",false,false)
	var expected: Dictionary = game.settings_snapshot()
	assert(game._save_settings()==OK,"Expanded preferences save")
	for section in game.SETTINGS.GROUPS: game.restore_settings_section(section,false)
	game._load_settings()
	assert(game.settings_snapshot()==expected,"All categories and remapped keys survive reload")
	assert(DirAccess.remove_absolute(ProjectSettings.globalize_path(game.settings_path))==OK,"Isolated settings test file removed")
	game.settings_path=saved_path
	for key in saved: game._set_setting(key,saved[key])
	game._apply_preferences()
	game.controls.forget_device(71)
	game.controls.release_keys()
	game.return_to_menu()
	game.menu.settings_section="display"
	print("SETTINGS PASS: five categories, audio/render output, display revert, key capture/conflicts, controller events/deadzone, preferences round-trip")
