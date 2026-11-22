class_name InputSetup
extends RefCounted
## Registers the game's input actions (physical keys, layout independent).


static func ensure() -> void:
	_key(&"move_forward", KEY_W)
	_key(&"move_back", KEY_S)
	_key(&"rudder_left", KEY_A)
	_key(&"rudder_right", KEY_D)
	_key(&"pause", KEY_ESCAPE)
	if not InputMap.has_action(&"fire"):
		InputMap.add_action(&"fire")
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event(&"fire", mb)


static func _key(action: StringName, key: Key) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	InputMap.action_add_event(action, ev)
