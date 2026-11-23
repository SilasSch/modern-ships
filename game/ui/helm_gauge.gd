class_name HelmGauge
extends Control
## Bottom-centre helm display: engine telegraph (6 steps) with actual speed marker,
## rudder (5 steps) with the actual blade position, and speed in knots.

const T_LABELS: Array[String] = ["Z.VOLL", "STOPP", "¼", "½", "¾", "VOLL"]
const R_LABELS: Array[String] = ["HART BB", "HALB BB", "MITTE", "HALB STB", "HART STB"]
const CELL := Vector2(84, 30)
const GAP := 4.0

var control: ShipControl
var motion: ShipMotion


func _ready() -> void:
	name = "HelmGauge"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(6 * (CELL.x + GAP), 2 * CELL.y + 44)
	size = custom_minimum_size


func telegraph_index() -> int:
	return control.telegraph + 1 if control else 1


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if control == null:
		return
	var f := UiTheme.mono
	# telegraph row
	for i in 6:
		var r := Rect2(Vector2(i * (CELL.x + GAP), 0), CELL)
		var on := i == telegraph_index()
		draw_rect(r, Color(UiTheme.CYAN, 0.85) if on else Color(1, 1, 1, 0.08))
		draw_string(f, r.position + Vector2(0, 20), T_LABELS[i], HORIZONTAL_ALIGNMENT_CENTER, CELL.x, 16,
			Color(0.02, 0.05, 0.08) if on else UiTheme.MUTED)
	if motion:
		var max_s := Tuning.MAX_SPEED
		var idx := 1.0 + (motion.speed / max_s * 4.0 if motion.speed >= 0.0 else motion.speed / Tuning.MAX_REVERSE)
		var x := idx * (CELL.x + GAP) + CELL.x * 0.5
		draw_colored_polygon(PackedVector2Array([Vector2(x, CELL.y + 2), Vector2(x - 7, CELL.y + 12), Vector2(x + 7, CELL.y + 12)]), UiTheme.TEXT)
	# rudder row (port on the left)
	var y0 := CELL.y + 16
	var rw := (6 * (CELL.x + GAP) - 4 * GAP) / 5.0
	for i in 5:
		var r := Rect2(Vector2(i * (rw + GAP), y0), Vector2(rw, CELL.y))
		var on := i == 2 - control.rudder_setting
		draw_rect(r, Color(UiTheme.CYAN, 0.85) if on else Color(1, 1, 1, 0.08))
		draw_string(f, r.position + Vector2(0, 20), R_LABELS[i], HORIZONTAL_ALIGNMENT_CENTER, rw, 14,
			Color(0.02, 0.05, 0.08) if on else UiTheme.MUTED)
	var blade := (2.0 - control.rudder * 2.0) * (rw + GAP) + rw * 0.5
	draw_line(Vector2(blade, y0 - 3), Vector2(blade, y0 + CELL.y + 3), UiTheme.TEXT, 2.0)
	if motion:
		var kn := "%d KN" % Hud.knots(motion.speed)
		draw_string(UiTheme.display_bold, Vector2(6 * (CELL.x + GAP) + 12, CELL.y - 4), kn, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, UiTheme.TEXT)
