extends Control
## Native controls above the original 960x540 gameplay coordinate system.

const INK := Color("091526")
const WHITE := Color("edf7eb")
const MUTED := Color("93afb6")
const TEAL := Color("69e6d2")
const AMBER := Color("ffba68")
const SETTINGS := preload("res://src/ui/settings_defaults.gd")
const CONTROLS := preload("res://src/input/player_controls.gd")
const SETTINGS_SECTIONS := [["display","显示"],["graphics","画面"],["audio","音频"],["game","游戏辅助"],["controls","控制"]]
const SCENARIOS := [
	["side", "横版 · 海岸航道", "断崖、防空边界与横向射击"],
	["top", "俯视 · 岛屿机场", "海岸、舰船与固定侧翼火力"],
	["chase", "追尾 · 巡航接敌", "默认高度 3.3，正常波次与双弹汇聚"],
	["high", "追尾 · 高空云层", "高度 4.6，检查拉升、下降和云滚动"],
	["sea", "追尾 · 低空海面", "高度 1.5，检查海面、岛链和水面鱼雷"],
	["approach", "追尾 · 敌机接近", "直接进入接近阶段，检查远近与侧飞"],
	["bonus", "追尾 · 奖励敌机", "金色快机，击落必掉补给；正常命中规则"],
	["boss", "追尾 · 海鸥验证版", "固定距离、持续摆动、交火预警与胜利结算"],
]

var game
var page := ""
var return_page := "main"
var content: Control
var controls: Array[Control] = []
var buttons: Dictionary = {}
var ui_font: SystemFont
var settings_section := "display"
var form_controls: Array[Control] = []
var display_draft: Dictionary = {}
var previous_display: Dictionary = {}
var previous_window_size := Vector2i.ZERO
var display_seconds := 0.0
var countdown_label: Label
var binding_action := ""
var binding_message := ""

func setup(owner_game) -> void:
	game = owner_game
	size = Vector2(960, 540)
	mouse_filter = Control.MOUSE_FILTER_STOP
	ui_font = SystemFont.new()
	ui_font.font_names = PackedStringArray(["Heiti SC", "PingFang SC", "Noto Sans CJK SC", "sans-serif"])
	ui_font.oversampling = 2.0
	var menu_theme := Theme.new()
	menu_theme.default_font = ui_font
	menu_theme.default_font_size = 16
	theme = menu_theme
	show_page("main")

func _draw() -> void:
	if page != "main":
		draw_rect(Rect2(0, 0, 960, 540), Color(INK, 0.92 if game.title else 0.86))
		draw_line(Vector2(64, 122), Vector2(896, 122), Color("335362"), 1)

func show_page(next_page: String) -> void:
	if next_page == "developer" and not game.developer_mode:
		next_page = "main"
	page = next_page
	visible = true
	if is_instance_valid(content):
		remove_child(content)
		content.queue_free()
	content = Control.new()
	content.size = size
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content)
	controls.clear()
	form_controls.clear()
	buttons.clear()
	match page:
		"main": _main_page()
		"developer": _developer_page()
		"settings": _settings_page()
		"display_confirm": _display_confirm_page()
		"help": _help_page()
		"pause": _pause_page()
		"over": _over_page()
		"victory": _victory_page()
		"practice": _practice_page()
	for i in range(controls.size()):
		var current := controls[i]
		current.focus_neighbor_top = current.get_path_to(controls[posmod(i - 1, controls.size())])
		current.focus_neighbor_bottom = current.get_path_to(controls[(i + 1) % controls.size()])
		current.focus_next = current.focus_neighbor_bottom
		current.focus_previous = current.focus_neighbor_top
	if not controls.is_empty():
		_focus_later(controls[0])
	if page=="settings": _settings_focus_routes()
	queue_redraw()

func _focus_later(control: Control) -> void:
	await get_tree().process_frame
	if visible and is_instance_valid(control) and control.is_inside_tree():
		control.grab_focus()

func hide_menu() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	if focused and is_ancestor_of(focused): focused.release_focus()
	visible = false
	page = ""

func sync_game_state() -> void:
	if game.title: return
	if game.victory:
		if page!="victory": show_page("victory")
	elif game.game_over and (not game.flight.crashed or game.crash_elapsed >= 0.6):
		if page != "over": show_page("over")
	elif game.paused:
		if not visible: show_page("pause")
	elif visible:
		hide_menu()

func _input(event: InputEvent) -> void:
	if visible and page=="settings" and not binding_action.is_empty():
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode==KEY_ESCAPE:
				binding_action=""
				binding_message="已取消，原按键保留。"
			else:
				var error: String = game.rebind_key(binding_action,int(event.keycode))
				if error.is_empty(): binding_action=""; binding_message="按键已保存。"
				else: binding_message=error+" 按 Esc 取消。"
			show_page("settings")
			get_viewport().set_input_as_handled()
		return
	if visible and event is InputEventJoypadButton and event.pressed:
		if event.button_index==JOY_BUTTON_B or (event.button_index==JOY_BUTTON_START and page=="pause"):
			go_back()
			get_viewport().set_input_as_handled()
		elif event.button_index==JOY_BUTTON_Y and page in ["pause","over","victory"]:
			game.restart_session()
			get_viewport().set_input_as_handled()
		return
	if not visible or not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_ESCAPE or (game.controls.action_event(event,"pause") and page == "pause"):
		go_back()
		get_viewport().set_input_as_handled()
	elif game.controls.action_event(event,"retry") and page in ["pause", "over", "victory"]:
		game.restart_session()
		get_viewport().set_input_as_handled()
	elif event.keycode in [KEY_W, KEY_S]:
		var index := controls.find(get_viewport().gui_get_focus_owner())
		if not controls.is_empty(): controls[posmod(index + (-1 if event.keycode == KEY_W else 1), controls.size())].grab_focus()
		get_viewport().set_input_as_handled()

func go_back() -> void:
	match page:
		"settings":
			if settings_section=="keys": select_settings_section("controls")
			else: show_page(return_page)
		"display_confirm": cancel_display_change()
		"help": show_page(return_page)
		"developer", "over", "victory", "practice": game.return_to_menu()
		"pause": game.resume_game()

func _main_page() -> void:
	_label("SKYFIRE", Rect2(62, 90, 510, 84), 64, WHITE)
	_label("1943", Rect2(64, 164, 360, 76), 62, AMBER)
	_label("一架飞机，三片战场。", Rect2(68, 248, 400, 30), 17, TEAL)
	_label("DEVELOPMENT BUILD" if game.developer_mode else "ORIGINAL FLIGHT PROTOTYPE", Rect2(66, 45, 490, 28), 11, TEAL)
	var y := 288.0
	_button("start", "开始游戏 · 破晓突袭  →", Rect2(64, y, 340, 42), game.start_mission, true,16)
	y += 50
	_button("practice", "三视角练习场", Rect2(64,y,340,34),func(): show_page("practice"),false,16)
	y += 39
	_button("settings", "设置", Rect2(64, y, 340, 34), func(): open_settings("main"),false,16)
	y += 39
	_button("help", "操作说明", Rect2(64, y, 340, 34), func(): return_page = "main"; show_page("help"),false,16)
	y += 39
	if game.developer_mode:
		_button("developer", "开发者菜单", Rect2(64, y, 340, 34), func(): show_page("developer"),false,16)
		y += 39
	_button("quit", "退出游戏", Rect2(64, y, 340, 34), func(): game.get_tree().quit(),false,16)
	_label("试玩原型  /  v0.16", Rect2(652, 47, 244, 24), 12, MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	_label("单人突袭样段 · 持续交战 · 非六关正式版", Rect2(460, 457, 436, 27), 12, MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	_label("破晓突袭：追尾 → 俯视 → 海鸥决战", Rect2(480, 429, 416, 25), 13, TEAL, HORIZONTAL_ALIGNMENT_CENTER)
	_footer()

func _practice_page() -> void:
	_header("FLIGHT LAB / SANDBOX","三视角练习场","原有循环刷敌与自由切换 · 没有关末 Boss 或通关判定")
	for i in range(3):
		_button(["practice_chase","practice_top","practice_side"][i],["追尾 · 接敌与汇聚","俯视 · 编队与舰船","横版 · 海岸航道"][i],Rect2(64,158+i*68,470,48),game.start_practice_mode.bind([game.Mode.CHASE,game.Mode.TOP,game.Mode.SIDE][i]),i==0)
	_button("back","← 返回主菜单",Rect2(64,390,270,40),game.return_to_menu)
	_footer()

func _header(kicker: String, heading: String, note: String) -> void:
	_label(kicker, Rect2(64, 28, 750, 24), 11, TEAL)
	_label(heading, Rect2(62, 57, 830, 48), 30, WHITE)
	_label(note, Rect2(64, 96, 830, 24), 12, MUTED)

func _developer_page() -> void:
	_header("DEVELOPER / SCENE SELECT", "开发者菜单", "快速启动独立调试场景 · 每次重新初始化能量、分数与火力")
	for i in range(SCENARIOS.size()):
		var scenario: Array = SCENARIOS[i]
		var rect := Rect2(64 + (i % 2) * 428, 145 + (i / 2) * 72, 404, 62)
		_button(scenario[0], "%02d   %s" % [i + 1, scenario[1]], rect, game.start_debug_scene.bind(scenario[0]))
		buttons[scenario[0]].alignment = HORIZONTAL_ALIGNMENT_LEFT
		buttons[scenario[0]].add_theme_font_size_override("font_size", 16)
		for state in ["normal", "hover", "pressed"]:
			var style: StyleBoxFlat = buttons[scenario[0]].get_theme_stylebox(state).duplicate()
			style.content_margin_bottom = 21
			buttons[scenario[0]].add_theme_stylebox_override(state, style)
		_label(scenario[2], Rect2(rect.position + Vector2(16, 38), Vector2(375, 21)), 11, MUTED)
	_button("back", "← 返回主菜单", Rect2(64,440,270,40), game.return_to_menu)
	_label("F1 返回场景选择 · Esc 打开暂停菜单", Rect2(420,447,476,25), 12, MUTED)
	_footer()

func open_settings(origin: String) -> void:
	return_page = origin
	display_draft=game.settings_snapshot("display")
	binding_action=""
	binding_message=""
	show_page("settings")

func select_settings_section(section: String) -> void:
	settings_section=section
	binding_action=""
	binding_message=""
	if section=="display": display_draft=game.settings_snapshot("display")
	show_page("settings")
	_focus_later(buttons["section_controls" if section=="keys" else "section_"+section])

func _settings_page() -> void:
	_header("PREFERENCES","设置","保存于本机 · 显示变更需确认，其余选项即时生效")
	for i in range(SETTINGS_SECTIONS.size()):
		var section: Array = SETTINGS_SECTIONS[i]
		var button := _button("section_"+section[0],section[1],Rect2(64,150+i*49,166,40),select_settings_section.bind(section[0]))
		if section[0]==settings_section or (settings_section=="keys" and section[0]=="controls"):
			button.add_theme_stylebox_override("normal",_style(Color("254a52"),TEAL))
	_button("back","← 返回",Rect2(64,446,166,40),go_back)
	match settings_section:
		"display": _display_settings()
		"graphics": _graphics_settings()
		"audio": _audio_settings()
		"game": _game_settings()
		"controls": _control_settings()
		"keys": _key_settings()
	_footer()

func _settings_heading(title: String) -> void:
	_label(title,Rect2(274,146,610,30),20,WHITE)

func _choice(id: String, caption: String, y: float, items: Array, selected: int, action: Callable) -> OptionButton:
	_label(caption,Rect2(280,y,294,36),15,WHITE)
	var option := OptionButton.new()
	option.position=Vector2(586,y)
	option.size=Vector2(300,36)
	option.add_theme_font_size_override("font_size",15)
	option.add_theme_color_override("font_color",WHITE)
	option.add_theme_stylebox_override("normal",_style(Color("102436"),Color("2e4657")))
	option.add_theme_stylebox_override("hover",_style(Color("1b3947"),TEAL))
	option.add_theme_stylebox_override("pressed",_style(Color("254856"),TEAL))
	option.add_theme_stylebox_override("focus",_style(Color.TRANSPARENT,TEAL))
	for item in items: option.add_item(str(item))
	option.select(clampi(selected,0,items.size()-1))
	content.add_child(option)
	option.get_popup().add_theme_stylebox_override("panel",_style(Color("102436"),Color("2e4657")))
	option.get_popup().add_theme_color_override("font_color",WHITE)
	option.item_selected.connect(action)
	controls.append(option)
	form_controls.append(option)
	buttons[id]=option
	return option

func _setting_toggle(id: String, caption: String, y: float, key: String) -> void:
	_toggle(id,caption,Rect2(276,y,610,38),bool(game.get_setting(key)),func(value): game.apply_setting(key,value))
	form_controls.append(buttons[id])

func _slider(id: String, caption: String, y: float, key: String, low: float, high: float, step: float) -> void:
	_label(caption,Rect2(280,y,295,32),15,WHITE)
	var value := _label("%d%%"%roundi(float(game.get_setting(key))*100),Rect2(826,y,62,32),15,TEAL)
	var slider := HSlider.new()
	slider.position=Vector2(586,y)
	slider.size=Vector2(222,32)
	slider.min_value=low
	slider.max_value=high
	slider.step=step
	slider.value=float(game.get_setting(key))*100
	slider.focus_mode=Control.FOCUS_ALL
	content.add_child(slider)
	controls.append(slider)
	form_controls.append(slider)
	buttons[id]=slider
	slider.value_changed.connect(func(amount): game.apply_setting(key,amount/100.0); value.text="%d%%"%roundi(amount))

func _reset_button() -> void:
	var button := _button("reset","恢复本页默认",Rect2(648,446,238,40),reset_current_section)
	form_controls.append(button)

func reset_current_section() -> void:
	if settings_section=="display":
		display_draft=game.SETTINGS.DEFAULTS.duplicate(true)
	elif settings_section=="keys":
		game.apply_setting("keyboard_bindings",CONTROLS.DEFAULT_KEYS)
	else:
		game.restore_settings_section(settings_section)
	binding_action=""
	binding_message="已恢复本页默认。"
	show_page("settings")

func _display_settings() -> void:
	_settings_heading("显示")
	if display_draft.is_empty(): display_draft=game.settings_snapshot("display")
	_choice("window_mode","窗口模式",184,["窗口","全屏"],1 if display_draft.fullscreen else 0,func(index): display_draft.fullscreen=index==1; buttons.window_size.disabled=display_draft.fullscreen)
	var size_option := _choice("window_size","窗口分辨率",238,["1280 × 720","1440 × 810","1920 × 1080"],display_draft.window_preset,func(index): display_draft.window_preset=index)
	size_option.disabled=display_draft.fullscreen
	_choice("vsync","垂直同步",292,["关闭","开启"],1 if display_draft.vsync else 0,func(index): display_draft.vsync=index==1)
	_choice("frame_limit","帧率上限",346,["30 FPS","60 FPS","120 FPS","144 FPS","不限"],SETTINGS.FRAME_LIMITS.find(display_draft.frame_limit),func(index): display_draft.frame_limit=SETTINGS.FRAME_LIMITS[index])
	_label("全屏使用桌面尺寸；窗口会按屏幕可用区域适配。\n确认后保存，15 秒未确认会自动还原。",Rect2(280,398,606,42),12,MUTED)
	var button := _button("apply_display","应用显示设置",Rect2(276,446,226,40),begin_display_change,true)
	form_controls.append(button)
	_reset_button()

func begin_display_change() -> void:
	previous_display=game.settings_snapshot("display")
	previous_window_size=DisplayServer.window_get_size()
	game.apply_display_preferences(display_draft,false)
	display_seconds=15.0
	show_page("display_confirm")

func _display_confirm_page() -> void:
	_header("DISPLAY CONFIRMATION","保留新的显示设置？","如果画面异常，等待自动还原，或按 Esc 立即还原。")
	countdown_label=_label("还有 %d 秒自动还原"%ceili(display_seconds),Rect2(64,162,800,46),25,AMBER)
	_label("窗口模式、窗口尺寸、垂直同步和帧率上限会一起确认。",Rect2(64,220,800,35),15,MUTED)
	_button("keep_display","保留并保存",Rect2(64,290,290,46),confirm_display_change,true)
	_button("revert_display","还原",Rect2(374,290,250,46),cancel_display_change)

func _process(delta: float) -> void:
	if not visible or page!="display_confirm": return
	display_seconds=maxf(0,display_seconds-delta)
	if is_instance_valid(countdown_label): countdown_label.text="还有 %d 秒自动还原"%ceili(display_seconds)
	if display_seconds<=0: cancel_display_change()

func confirm_display_change() -> void:
	if not game.automation: game._save_settings()
	previous_display.clear()
	display_draft=game.settings_snapshot("display")
	show_page("settings")

func cancel_display_change() -> void:
	game.apply_display_preferences(previous_display,false)
	if not game.automation and not game.fullscreen and previous_window_size!=Vector2i.ZERO:
		DisplayServer.window_set_size(previous_window_size)
	previous_display.clear()
	display_draft=game.settings_snapshot("display")
	show_page("settings")

func _graphics_settings() -> void:
	_settings_heading("画面")
	_choice("render_quality","画面清晰度",184,["标准 · 1280 × 720","清晰 · 1600 × 900","高清 · 1920 × 1080"],game.render_quality,func(index): game.apply_setting("render_quality",index))
	_slider("brightness","画面亮度",238,"brightness",80,120,5)
	_choice("particle_quality","爆炸粒子",292,["关闭","精简","完整"],game.particle_quality,func(index): game.apply_setting("particle_quality",index))
	_setting_toggle("flashes","受击 / 特殊攻击闪屏",346,"screen_flashes")
	_setting_toggle("fps","显示帧率",394,"show_fps")
	_reset_button()

func _audio_settings() -> void:
	_settings_heading("音频")
	_slider("master_volume","总音量",184,"master_volume",0,100,5)
	_slider("volume","音效音量",238,"volume",0,100,5)
	_setting_toggle("sound","静音",292,"muted")
	_label("背景音乐",Rect2(280,346,285,35),15,WHITE)
	_label("暂未制作配乐",Rect2(586,346,300,35),14,MUTED)
	var test_button := _button("test_audio","播放测试音效",Rect2(276,397,255,36),game.preview_audio)
	form_controls.append(test_button)
	_reset_button()

func _game_settings() -> void:
	_settings_heading("游戏辅助")
	_setting_toggle("aim","机枪辅助准心",184,"aim_helper")
	_setting_toggle("torpedo","鱼雷投弹点提示",232,"torpedo_helper")
	_setting_toggle("hitbox","显示我机碰撞参考点",280,"hitbox_helper")
	_setting_toggle("hints","显示底部操作提示",328,"show_controls")
	_setting_toggle("focus_pause","窗口失焦时自动暂停",376,"pause_on_focus_loss")
	_label("三种参考默认关闭；显示开关不改变命中，难度待战役平衡。",Rect2(280,420,606,24),11,MUTED)
	_reset_button()

func _control_settings() -> void:
	_settings_heading("控制 · 单人")
	_choice("input_mode","输入方式",184,["自动 · 键盘 + 手柄","仅键盘","手柄优先 · 无手柄回退键盘"],game.controls.input_mode,func(index): game.apply_setting("input_mode",index); _refresh_control_status())
	var devices: Array = [-1]
	var captions: Array = ["自动选择连接的手柄"]
	for device in Input.get_connected_joypads():
		devices.append(device)
		captions.append("%d · %s"%[device,Input.get_joy_name(device)])
	if not devices.has(game.controls.selected_gamepad):
		devices.append(game.controls.selected_gamepad)
		captions.append("设备 %d · 未连接"%game.controls.selected_gamepad)
	_choice("gamepad","手柄设备",232,captions,devices.find(game.controls.selected_gamepad),func(index): game.apply_setting("gamepad_device",devices[index]); _refresh_control_status())
	_slider("deadzone","左摇杆死区",280,"deadzone",5,40,1)
	_setting_toggle("invert","反转追尾上下",328,"invert_chase_y")
	_setting_toggle("vibration","手柄震动",376,"vibration_enabled")
	buttons.vibration.toggled.connect(func(_enabled): _refresh_control_status())
	var keys_button := _button("key_bindings","键盘按键映射 →",Rect2(276,446,225,40),select_settings_section.bind("keys"))
	form_controls.append(keys_button)
	var vibration_button := _button("test_vibration","震动测试",Rect2(512,446,125,40),func(): game.controls.vibrate())
	form_controls.append(vibration_button)
	_reset_button()
	buttons.device_status=_label("",Rect2(280,420,606,24),11,MUTED)
	buttons.device_status.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	_refresh_control_status()

func _refresh_control_status() -> void:
	if not buttons.has("test_vibration"): return
	var device: int = game.controls.active_gamepad()
	buttons.test_vibration.disabled=device<0 or not Input.get_connected_joypads().has(device) or not Input.has_joy_vibration(device) or not game.controls.vibration_enabled
	buttons.device_status.text=game.controls.device_description()+" A 射击 / B 特殊 / Start 暂停 / Y 重开。"

func _key_settings() -> void:
	_settings_heading("键盘按键映射")
	_label(binding_message if not binding_message.is_empty() else "点击主按键后按下新键；Esc 取消。备用键保留。",Rect2(280,178,606,24),12,AMBER if not binding_action.is_empty() else MUTED)
	for i in range(CONTROLS.ACTIONS.size()):
		var action: String = CONTROLS.ACTIONS[i]
		var y := 210+i*27
		_label(CONTROLS.LABELS[action],Rect2(280,y,270,26),14,WHITE)
		var button := _button("bind_"+action,"按下新键…" if binding_action==action else game.controls.action_name(action),Rect2(576,y,170,25),_begin_binding.bind(action),false,13)
		for state in ["normal","hover","pressed","focus"]:
			var compact: StyleBoxFlat = button.get_theme_stylebox(state).duplicate()
			compact.content_margin_top=0
			compact.content_margin_bottom=0
			button.add_theme_stylebox_override(state,compact)
		button.size=Vector2(170,25)
		form_controls.append(button)
		var aliases: Array[String] = []
		for key in CONTROLS.ALTERNATE_KEYS[action]: aliases.append(CONTROLS.key_name(key))
		_label("备用 "+"/".join(aliases) if not aliases.is_empty() else "—",Rect2(768,y,120,26),11,MUTED)
	var back_button := _button("keys_back","← 返回控制",Rect2(276,446,250,40),select_settings_section.bind("controls"))
	form_controls.append(back_button)
	_reset_button()

func _begin_binding(action: String) -> void:
	binding_action=action
	binding_message="正在设置“%s”；按 Esc 取消。"%CONTROLS.LABELS[action]
	show_page("settings")

func _settings_focus_routes() -> void:
	for i in range(SETTINGS_SECTIONS.size()):
		var item: Control = buttons["section_"+SETTINGS_SECTIONS[i][0]]
		item.focus_neighbor_top=item.get_path_to(buttons["section_"+SETTINGS_SECTIONS[posmod(i-1,5)][0]])
		item.focus_neighbor_bottom=item.get_path_to(buttons["section_"+SETTINGS_SECTIONS[(i+1)%5][0]])
		if not form_controls.is_empty(): item.focus_neighbor_right=item.get_path_to(form_controls[0])
	var selected: Control = buttons["section_controls" if settings_section=="keys" else "section_"+settings_section]
	for i in range(form_controls.size()):
		var item := form_controls[i]
		item.focus_neighbor_top=item.get_path_to(form_controls[posmod(i-1,form_controls.size())])
		item.focus_neighbor_bottom=item.get_path_to(form_controls[(i+1)%form_controls.size()])
		item.focus_neighbor_left=item.get_path_to(selected)

func _help_page() -> void:
	_header("FLIGHT MANUAL", "操作说明", "横版 / 俯视移动；追尾左右回旋、上下升降。")
	var keyboard = game.controls
	var movement_keys: Array[String] = []
	for action in ["up","down","left","right"]: movement_keys.append(keyboard.action_name(action))
	var entries := [[" / ".join(movement_keys),"移动 · 备用方向键 / 左摇杆"],
		[keyboard.action_name("fire")+" / Z","按住射击 · 手柄 A"],
		[keyboard.action_name("special"),"追尾投鱼雷；其他视角清弹 · 手柄 B"],
		[keyboard.action_name("pause")+" / Esc / P","暂停与继续 · 手柄 Start"],
		[keyboard.action_name("retry")+" / M / H","重开 / 静音 / 准心；手柄 Y 重开"],
		["1 / 2 / 3","仅练习场自由切换；关卡按任务转场"]]
	for i in range(entries.size()):
		_label(entries[i][0], Rect2(80, 146 + i * 41, 250, 30), 16, TEAL)
		_label(entries[i][1], Rect2(348, 146 + i * 41, 548, 30), 16, WHITE)
	_button("back", "← 返回主菜单", Rect2(64, 426, 230, 40), go_back)
	_footer()

func _pause_page() -> void:
	_header("FLIGHT PAUSED", "已暂停", "继续飞行，或返回主菜单重新选择。")
	_button("resume", "继续游戏     →", Rect2(64, 156, 340, 46), game.resume_game, true)
	_button("retry", "重新开始", Rect2(64, 216, 340, 42), game.restart_session)
	_button("settings", "设置", Rect2(64, 272, 340, 42), func(): open_settings("pause"))
	_button("main", "返回主菜单", Rect2(64, 328, 340, 42), game.return_to_menu)
	if game.developer_mode:
		_button("developer", "开发者菜单", Rect2(64, 384, 340, 42), game.open_developer_menu)
	_footer()

func _over_page() -> void:
	_header("MISSION FAILED" if game.mission.active else "FLIGHT ENDED", "突袭任务失败" if game.mission.active else "本次飞行结束", "触海坠毁" if game.flight.crashed else "能量耗尽")
	_label("得分   %06d" % game.score, Rect2(64, 154, 600, 56), 32, AMBER)
	if game.mission.active: _label("进度："+game.mission.phase_title()+" · 重试从任务开头重新开始",Rect2(64,207,800,26),14,MUTED)
	_button("retry", "重新开始     →", Rect2(64, 241, 340, 46), game.restart_session, true)
	_button("main", "返回主菜单", Rect2(64, 302, 340, 42), game.return_to_menu)
	_footer()

func _victory_page() -> void:
	var boss_debug: bool = game.debug_scene=="boss"
	_header("BOSS CHECK COMPLETE" if boss_debug else "MISSION COMPLETE / VERTICAL SLICE","海鸥验证 · 击破成功" if boss_debug else "破晓突袭 · 任务完成","独立 Boss 调试场景 · 不含道中，不作为完整关卡通关成绩" if boss_debug else "海鸥已击破，敌方拦截线已突破 · 当前为单人关卡验证样段")
	_label("总得分   %06d"%game.score,Rect2(64,148,830,53),32,AMBER)
	_label("任务用时   %02d:%02d"%[int(game.mission.time)/60,int(game.mission.time)%60],Rect2(64,212,410,30),18,WHITE)
	_label("击破   %d / %d    补给拾取   %d"%[game.mission.defeated_targets,game.mission.spawned_targets,game.mission.supplies_collected],Rect2(64,253,800,30),18,WHITE)
	_label("剩余能量   %d    通关与生存加分   +%d"%[roundi(game.energy),game.mission.earned_bonus],Rect2(64,294,800,30),17,TEAL)
	_button("retry","再次挑战     →",Rect2(64,363,340,46),game.restart_session,true)
	_button("main","返回主菜单",Rect2(64,423,340,42),game.return_to_menu)
	_footer()

func _footer() -> void:
	_label("方向键 / W S  选择   Enter / A  确认   Esc / B  返回   鼠标可点", Rect2(430, 503, 470, 22), 11, MUTED, HORIZONTAL_ALIGNMENT_RIGHT)

func _label(text_value: String, rect: Rect2, font_size: int, color: Color, alignment := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text_value
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = alignment
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(label)
	return label

func _style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 16
	style.content_margin_right = 16
	return style

func _button(id: String, caption: String, rect: Rect2, action: Callable, primary := false, font_size := 17) -> Button:
	var button := Button.new()
	button.text = caption
	button.position = rect.position
	button.size = rect.size
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", INK if primary else WHITE)
	button.add_theme_color_override("font_hover_color", INK if primary else WHITE)
	button.add_theme_color_override("font_focus_color", INK if primary else WHITE)
	button.add_theme_color_override("font_pressed_color", INK if primary else TEAL)
	button.add_theme_stylebox_override("normal", _style(AMBER if primary else Color("102436"), AMBER if primary else Color("2e4657")))
	button.add_theme_stylebox_override("hover", _style(Color("ffd09a") if primary else Color("1b3947"), AMBER if primary else TEAL))
	button.add_theme_stylebox_override("pressed", _style(Color("e6a55f") if primary else Color("254856"), AMBER))
	var focus := _style(Color.TRANSPARENT, AMBER if primary else TEAL)
	focus.set_border_width_all(2)
	button.add_theme_stylebox_override("focus", focus)
	content.add_child(button)
	controls.append(button)
	buttons[id] = button
	button.pressed.connect(action)
	return button

func _toggle(id: String, caption: String, rect: Rect2, value: bool, action: Callable) -> void:
	var button := _button(id, caption + ("    开" if value else "    关"), rect, func(): pass)
	button.toggle_mode = true
	button.button_pressed = value
	button.toggled.connect(func(enabled): action.call(enabled); button.text = caption + ("    开" if enabled else "    关"))
