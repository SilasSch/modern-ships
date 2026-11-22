class_name Hud
extends CanvasLayer
## In-battle HUD: hull bar, wave readout, overheat warning, aim cursor, controls hint.

var battle: Battle
var _hull_label: Label
var _hull_bar: ColorRect
var _hull_fill: ColorRect
var _wave_label: Label
var _warn: Label
var _hint: Label
var _cursor: CursorRing
var _hint_t: float = 9.0
var _t: float = 0.0


func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiTheme.theme()
	add_child(root)

	var tl := VBoxContainer.new()
	tl.position = Vector2(32, 26)
	tl.add_theme_constant_override(&"separation", 6)
	root.add_child(tl)
	_hull_label = UiTheme.label("RUMPF", 21, UiTheme.MUTED, UiTheme.mono)
	tl.add_child(_hull_label)
	_hull_bar = ColorRect.new()
	_hull_bar.custom_minimum_size = Vector2(340, 10)
	_hull_bar.color = Color(1, 1, 1, 0.12)
	tl.add_child(_hull_bar)
	_hull_fill = ColorRect.new()
	_hull_fill.color = UiTheme.CYAN
	_hull_fill.size = Vector2(340, 10)
	_hull_bar.add_child(_hull_fill)

	_wave_label = UiTheme.label("", 30, UiTheme.TEXT, UiTheme.display)
	_wave_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wave_label.position = Vector2(-400, 22)
	_wave_label.size = Vector2(800, 40)
	root.add_child(_wave_label)

	_warn = UiTheme.label("ÜBERHITZT", 52, UiTheme.RED, UiTheme.display_bold)
	_warn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_warn.position = Vector2(-300, -170)
	_warn.size = Vector2(600, 50)
	_warn.visible = false
	root.add_child(_warn)

	_hint = UiTheme.label("WASD fahren  ·  Maus zielen  ·  Linksklick halten: laden  ·  länger halten: überladen  ·  Esc: Pause", 21, UiTheme.MUTED, UiTheme.mono)
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.position = Vector2(-800, -60)
	_hint.size = Vector2(1600, 30)
	root.add_child(_hint)

	_cursor = CursorRing.new()
	root.add_child(_cursor)


func _process(delta: float) -> void:
	_t += delta
	if battle == null or battle.player == null:
		return
	var p := battle.player
	_cursor.railgun = p.railgun
	_cursor.visible = battle.outcome() == &"running" and not battle.get_tree().paused
	var frac := p.health.fraction()
	_hull_fill.size.x = 340.0 * frac
	_hull_fill.color = UiTheme.CYAN if frac > 0.35 else UiTheme.RED
	_hull_label.text = "RUMPF  %d / %d" % [ceili(p.health.hp), int(p.health.max_hp)]
	var d := battle.director
	if d.current_wave == 0:
		_wave_label.text = "FEIND NÄHERT SICH"
	elif d.is_complete():
		_wave_label.text = "SEEGEBIET GESICHERT"
	elif d.alive == 0:
		_wave_label.text = "WELLE %d / %d  ·  NÄCHSTE WELLE" % [d.current_wave, d.total_waves()]
	else:
		_wave_label.text = "WELLE %d / %d  ·  %d %s" % [d.current_wave, d.total_waves(), d.alive, "FEIND" if d.alive == 1 else "FEINDE"]
	_warn.visible = p.railgun.state == RailgunState.State.LOCKED and fmod(_t, 0.5) < 0.32
	_hint_t -= delta
	_hint.modulate.a = clampf(_hint_t, 0.0, 1.0)
