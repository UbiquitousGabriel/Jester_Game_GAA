extends Node
## Autoload. Registers default input actions at startup.
##
## Actions are created in code (instead of project.godot) so the defaults live
## in one readable place and a future remapping screen can overwrite them.
## An action that already exists in the InputMap is left untouched.

const DEADZONE: float = 0.3


func _enter_tree() -> void:
	_bind(&"move_left", [KEY_A, KEY_LEFT], [JOY_BUTTON_DPAD_LEFT], JOY_AXIS_LEFT_X, -1.0)
	_bind(&"move_right", [KEY_D, KEY_RIGHT], [JOY_BUTTON_DPAD_RIGHT], JOY_AXIS_LEFT_X, 1.0)
	_bind(&"move_up", [KEY_W, KEY_UP], [JOY_BUTTON_DPAD_UP], JOY_AXIS_LEFT_Y, -1.0)
	_bind(&"move_down", [KEY_S, KEY_DOWN], [JOY_BUTTON_DPAD_DOWN], JOY_AXIS_LEFT_Y, 1.0)
	_bind(&"jump", [KEY_SPACE], [JOY_BUTTON_A])
	_bind(&"attack_light", [KEY_J], [JOY_BUTTON_X])
	_bind(&"attack_heavy", [KEY_K], [JOY_BUTTON_B])
	_bind(&"dash", [KEY_SHIFT], [JOY_BUTTON_RIGHT_SHOULDER])
	_bind(&"special", [KEY_L], [JOY_BUTTON_LEFT_SHOULDER])
	_bind(&"pause", [KEY_ESCAPE], [JOY_BUTTON_START])
	_bind(&"debug_restart", [KEY_R], [JOY_BUTTON_BACK])


func _bind(
	action: StringName,
	keys: Array,
	buttons: Array,
	axis: JoyAxis = JOY_AXIS_INVALID,
	axis_value: float = 0.0
) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action, DEADZONE)
	for key: Key in keys:
		var key_event := InputEventKey.new()
		key_event.physical_keycode = key
		InputMap.action_add_event(action, key_event)
	for button: JoyButton in buttons:
		var button_event := InputEventJoypadButton.new()
		button_event.button_index = button
		InputMap.action_add_event(action, button_event)
	if axis != JOY_AXIS_INVALID:
		var motion_event := InputEventJoypadMotion.new()
		motion_event.axis = axis
		motion_event.axis_value = axis_value
		InputMap.action_add_event(action, motion_event)
