extends RefCounted
## One-player keyboard/gamepad routing; cooperative slots are not implemented yet.

const ACTIONS := ["up","down","left","right","fire","special","pause","retry"]
const LABELS := {"up":"向上 / 拉升","down":"向下 / 下降","left":"向左 / 左转","right":"向右 / 右转","fire":"持续射击","special":"特殊攻击","pause":"暂停 / 继续","retry":"重新开始"}
const DEFAULT_KEYS := {"up":KEY_W,"down":KEY_S,"left":KEY_A,"right":KEY_D,"fire":KEY_SPACE,"special":KEY_X,"pause":KEY_ESCAPE,"retry":KEY_R}
const ALTERNATE_KEYS := {"up":[KEY_UP],"down":[KEY_DOWN],"left":[KEY_LEFT],"right":[KEY_RIGHT],"fire":[KEY_Z],"special":[],"pause":[KEY_ESCAPE,KEY_P],"retry":[]}
const RESERVED_KEYS := [KEY_ENTER,KEY_KP_ENTER,KEY_TAB,KEY_1,KEY_2,KEY_3,KEY_F1,KEY_M,KEY_H]
const PAD_BUTTONS := {"fire":JOY_BUTTON_A,"special":JOY_BUTTON_B,"pause":JOY_BUTTON_START,"retry":JOY_BUTTON_Y}

var bindings: Dictionary = DEFAULT_KEYS.duplicate()
var input_mode := 0 # 0 auto, 1 keyboard, 2 gamepad with keyboard fallback if absent.
var selected_gamepad := -1
var deadzone := 0.18
var invert_chase_y := false
var vibration_enabled := true
var last_source := "keyboard"
var _last_pad := -1
var _keys: Dictionary = {}
var _axes: Dictionary = {}
var _buttons: Dictionary = {}

func observe(event: InputEvent) -> void:
	if event is InputEventKey:
		_keys[int(event.keycode)] = event.pressed
		if event.pressed: last_source = "keyboard"
	elif event is InputEventJoypadMotion:
		if not _axes.has(event.device): _axes[event.device] = {}
		_axes[event.device][int(event.axis)] = event.axis_value
		_last_pad = event.device
		if absf(event.axis_value)>deadzone: last_source = "gamepad"
	elif event is InputEventJoypadButton:
		if not _buttons.has(event.device): _buttons[event.device] = {}
		_buttons[event.device][int(event.button_index)] = event.pressed
		_last_pad = event.device
		if event.pressed: last_source = "gamepad"

func forget_device(device: int) -> void:
	_axes.erase(device)
	_buttons.erase(device)
	if _last_pad==device: _last_pad=-1

func release_keys() -> void:
	for key in _keys: _keys[key]=false

func active_gamepad() -> int:
	if input_mode==1: return -1
	var connected := Input.get_connected_joypads()
	if selected_gamepad>=0:
		return selected_gamepad if connected.has(selected_gamepad) or _axes.has(selected_gamepad) or _buttons.has(selected_gamepad) else -1
	if not connected.is_empty(): return connected[0]
	return _last_pad if _axes.has(_last_pad) or _buttons.has(_last_pad) else -1

func keyboard_enabled() -> bool:
	return input_mode!=2 or active_gamepad()<0

func _key_pressed(key: int) -> bool:
	return bool(_keys[key]) if _keys.has(key) else Input.is_key_pressed(key)

func _button_pressed(device: int, button: int) -> bool:
	if _buttons.has(device) and _buttons[device].has(button): return _buttons[device][button]
	return Input.is_joy_button_pressed(device,button)

func _axis(device: int, axis: int) -> float:
	if _axes.has(device) and _axes[device].has(axis): return _axes[device][axis]
	return Input.get_joy_axis(device,axis)

func pressed(action: String) -> bool:
	if keyboard_enabled():
		if _key_pressed(int(bindings[action])): return true
		for key in ALTERNATE_KEYS[action]:
			if _key_pressed(key): return true
	var device := active_gamepad()
	return device>=0 and PAD_BUTTONS.has(action) and _button_pressed(device,PAD_BUTTONS[action])

func action_event(event: InputEvent, action: String) -> bool:
	if event is InputEventKey:
		if not event.pressed or event.echo: return false
		if action=="pause" and event.keycode==KEY_ESCAPE: return true
		return keyboard_enabled() and (event.keycode==int(bindings[action]) or ALTERNATE_KEYS[action].has(event.keycode))
	if event is InputEventJoypadButton:
		return event.pressed and event.device==active_gamepad() and PAD_BUTTONS.has(action) and event.button_index==PAD_BUTTONS[action]
	return false

func movement(chase: bool) -> Vector2:
	var direction := Vector2.ZERO
	if keyboard_enabled():
		direction = Vector2(float(pressed("right"))-float(pressed("left")),float(pressed("down"))-float(pressed("up")))
	var device := active_gamepad()
	if device>=0:
		var stick := Vector2(_axis(device,JOY_AXIS_LEFT_X),_axis(device,JOY_AXIS_LEFT_Y)).limit_length(1.0)
		if stick.length()>deadzone: direction+=stick.normalized()*((stick.length()-deadzone)/(1.0-deadzone))
		direction+=Vector2(float(_button_pressed(device,JOY_BUTTON_DPAD_RIGHT))-float(_button_pressed(device,JOY_BUTTON_DPAD_LEFT)),float(_button_pressed(device,JOY_BUTTON_DPAD_DOWN))-float(_button_pressed(device,JOY_BUTTON_DPAD_UP)))
	direction=direction.limit_length(1.0)
	if chase and invert_chase_y: direction.y=-direction.y
	return direction

func try_bind(action: String, key: int) -> String:
	if not ACTIONS.has(action) or key==KEY_NONE: return "无效按键。"
	if RESERVED_KEYS.has(key): return "该键保留给菜单或原型快捷操作。"
	for other in ACTIONS:
		if other!=action and (int(bindings[other])==key or ALTERNATE_KEYS[other].has(key)):
			return "该键已用于“%s”。"%LABELS[other]
	bindings[action]=key
	return ""

func load_bindings(values: Variant) -> void:
	bindings=DEFAULT_KEYS.duplicate()
	if not values is Dictionary: return
	var candidate := DEFAULT_KEYS.duplicate()
	for action in ACTIONS:
		if values.has(action): candidate[action]=int(values[action])
	for action in ACTIONS:
		var key: int = candidate[action]
		if key==KEY_NONE or RESERVED_KEYS.has(key): return
		for other in ACTIONS:
			if other!=action and (candidate[other]==key or ALTERNATE_KEYS[other].has(key)): return
	bindings=candidate

static func key_name(key: int) -> String:
	match key:
		KEY_SPACE: return "空格"
		KEY_UP: return "↑"
		KEY_DOWN: return "↓"
		KEY_LEFT: return "←"
		KEY_RIGHT: return "→"
		KEY_ESCAPE: return "Esc"
	return OS.get_keycode_string(key)

func action_name(action: String) -> String:
	return key_name(int(bindings[action]))

func device_description() -> String:
	var connected := Input.get_connected_joypads()
	var device := active_gamepad()
	if device<0 or not connected.has(device): return "未检测到连接的手柄，键盘可用。"
	return "当前手柄：%s"%Input.get_joy_name(device)

func vibrate() -> bool:
	var device := active_gamepad()
	if not vibration_enabled or device<0 or not Input.get_connected_joypads().has(device) or not Input.has_joy_vibration(device): return false
	Input.start_joy_vibration(device,0.25,0.45,0.15)
	return true
