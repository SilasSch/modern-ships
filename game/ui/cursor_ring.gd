class_name CursorRing
extends Control
## Aim cursor: inner arc = charge (cyan), outer arc = overcharge (white -> cyan), thin outer ring = heat.

var railgun: RailgunState
var ship: PlayerShip
var _blink: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(120, 120)


func _process(delta: float) -> void:
	_blink += delta
	position = get_viewport().get_mouse_position() - size * 0.5
	queue_redraw()


func _draw() -> void:
	if railgun == null:
		return
	var c := size * 0.5
	var locked := railgun.state == RailgunState.State.LOCKED
	draw_line(c + Vector2(-7, 0), c + Vector2(-3, 0), UiTheme.TEXT, 2.0)
	draw_line(c + Vector2(3, 0), c + Vector2(7, 0), UiTheme.TEXT, 2.0)
	draw_line(c + Vector2(0, -7), c + Vector2(0, -3), UiTheme.TEXT, 2.0)
	draw_line(c + Vector2(0, 3), c + Vector2(0, 7), UiTheme.TEXT, 2.0)
	var start := -PI / 2.0
	draw_arc(c, 22.0, 0.0, TAU, 48, Color(1, 1, 1, 0.15), 3.0, true)
	var ready := railgun.state == RailgunState.State.READY or railgun.state == RailgunState.State.HOLDING
	if ready:
		draw_arc(c, 22.0, 0.0, TAU, 48, UiTheme.CYAN, 4.0, true)
	elif railgun.reload > 0.0:
		draw_arc(c, 22.0, start, start + TAU * railgun.reload, 48, Color(UiTheme.TEXT, 0.55), 3.0, true)
	if railgun.overcharge > 0.0:
		var oc := Color.WHITE.lerp(UiTheme.CYAN, 0.3 + 0.3 * sin(_blink * 30.0))
		draw_arc(c, 30.0, start, start + TAU * railgun.overcharge, 48, oc, 5.0, true)
	var heat := railgun.heat
	if heat > 0.01:
		var hc := UiTheme.AMBER.lerp(UiTheme.RED, clampf((heat - 0.5) * 2.0, 0.0, 1.0))
		if heat > 0.8 and fmod(_blink, 0.3) < 0.15:
			hc.a = 0.35
		draw_arc(c, 38.0, start, start + TAU * heat, 64, hc, 2.0, true)
	if ship and ship.aim_error() > 0.035 and not locked:
		draw_arc(c, 22.0, 0.0, TAU, 48, Color(0.05, 0.08, 0.12, 0.65), 5.0, true)
		draw_string(UiTheme.mono, c + Vector2(-34, 56), "SCHWENKT", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, UiTheme.AMBER)
	if locked:
		var f := UiTheme.mono
		draw_string(f, c + Vector2(-34, 56), "GESPERRT", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, UiTheme.RED)
