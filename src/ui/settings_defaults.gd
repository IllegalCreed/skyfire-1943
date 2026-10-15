extends RefCounted

const CONTROLS := preload("res://src/input/player_controls.gd")
const WINDOW_SIZES := [Vector2i(1280,720),Vector2i(1440,810),Vector2i(1920,1080)]
const RENDER_SIZES := [Vector2i(1280,720),Vector2i(1600,900),Vector2i(1920,1080)]
const FRAME_LIMITS := [30,60,120,144,0]
const DEFAULTS := {
	"fullscreen":false,"window_preset":1,"vsync":true,"frame_limit":60,
	"render_quality":2,"brightness":1.0,"particle_quality":2,"screen_flashes":true,"show_fps":false,
	"master_volume":1.0,"volume":0.75,"muted":false,
	"aim_helper":false,"torpedo_helper":false,"hitbox_helper":false,"show_controls":true,"pause_on_focus_loss":true,
	"input_mode":0,"gamepad_device":-1,"deadzone":0.18,"invert_chase_y":false,"vibration_enabled":true,"keyboard_bindings":CONTROLS.DEFAULT_KEYS
}
const GROUPS := {
	"display":["fullscreen","window_preset","vsync","frame_limit"],
	"graphics":["render_quality","brightness","particle_quality","screen_flashes","show_fps"],
	"audio":["master_volume","volume","muted"],
	"game":["aim_helper","torpedo_helper","hitbox_helper","show_controls","pause_on_focus_loss"],
	"controls":["input_mode","gamepad_device","deadzone","invert_chase_y","vibration_enabled","keyboard_bindings"]
}
const CONFIG_FIELDS := {
	"display":{"fullscreen":"fullscreen","window_preset":"window_preset","vsync":"vsync","frame_limit":"frame_limit"},
	"graphics":{"render_quality":"render_quality","brightness":"brightness","particle_quality":"particle_quality","screen_flashes":"screen_flashes","show_fps":"show_fps"},
	"audio":{"master_volume":"master_volume","volume":"volume","muted":"muted"},
	"play":{"aim_helper":"aim_helper","torpedo_helper":"torpedo_helper","hitbox_helper":"hitbox_helper","show_controls":"show_controls","pause_on_focus_loss":"pause_on_focus_loss"},
	"controls":{"input_mode":"input_mode","gamepad_device":"gamepad_device","deadzone":"deadzone","invert_chase_y":"invert_chase_y","vibration_enabled":"vibration_enabled","keys":"keyboard_bindings"}
}
