extends Node3D
## Title screen: live storm sea with the destroyer idling, title type and the main menu.

var _ship: PlayerShip
var _cam: Camera3D
var _t: float = 0.0
var _quality_btn: Button


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var storm := StormEnvironment.new()
	add_child(storm)
	add_child(Ocean.new())
	_ship = (load("res://ships/player_ship.tscn") as PackedScene).instantiate()
	_ship.use_device_input = false
	_ship.input_enabled = false
	add_child(_ship)
	_cam = Camera3D.new()
	_cam.fov = 38.0
	add_child(_cam)
	_cam.make_current()
	var weather := Weather.new()
	weather.storm = storm
	weather.follow = _cam
	add_child(weather)
	_build_ui()


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UiTheme.theme()
	layer.add_child(root)
	var g := Gradient.new()
	g.set_color(0, Color(0.01, 0.02, 0.04, 0.85))
	g.set_color(1, Color(0.01, 0.02, 0.04, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	var shade_tex := TextureRect.new()
	shade_tex.texture = gt
	shade_tex.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	shade_tex.size = Vector2(900, 1080)
	shade_tex.stretch_mode = TextureRect.STRETCH_SCALE
	shade_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade_tex)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	box.position = Vector2(130, -260)
	box.add_theme_constant_override(&"separation", 4)
	root.add_child(box)
	box.add_child(UiTheme.label("MODERN", 120, UiTheme.TEXT, UiTheme.display_bold))
	var ships := UiTheme.label("SHIPS", 120, UiTheme.CYAN, UiTheme.display_bold)
	ships.add_theme_constant_override(&"line_spacing", -30)
	box.add_child(ships)
	box.add_child(UiTheme.label("RAILGUN  ·  32 MJ  ·  2 500 M/S", 24, UiTheme.MUTED, UiTheme.mono))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 40)
	box.add_child(spacer)
	box.add_child(UiTheme.button("Gefecht starten", func() -> void: _flow(&"start_battle")))
	_quality_btn = UiTheme.button("", _toggle_quality)
	_update_quality_label()
	box.add_child(_quality_btn)
	box.add_child(UiTheme.button("Beenden", func() -> void: _flow(&"quit")))
	var hint := UiTheme.label("Grafik „Mittel“ für schwächere Grafik (z. B. Snapdragon). Wechsel startet das Spiel neu.", 18, UiTheme.MUTED, UiTheme.mono)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(520, 0)
	box.add_child(hint)
	(box.get_child(4) as Button).grab_focus.call_deferred()


func _update_quality_label() -> void:
	_quality_btn.text = "Grafik: %s" % ("Hoch" if Settings.is_high() else "Mittel")


func _toggle_quality() -> void:
	Settings.set_quality(not Settings.is_high())
	_update_quality_label()
	OS.set_restart_on_exit(true, OS.get_cmdline_args())
	get_tree().quit()


func _flow(method: StringName) -> void:
	if has_node(^"/root/Flow"):
		get_node(^"/root/Flow").call(method)


func _process(delta: float) -> void:
	_t += delta
	var a := _t * 0.06 + 0.6
	_cam.position = Vector3(sin(a) * 34.0 - 10.0, 13.0, cos(a) * 34.0)
	_cam.look_at(Vector3(-10.0, 2.0, 0.0))
	_ship.aim_point = Vector3(sin(_t * 0.3) * 60.0, 0, -80)
