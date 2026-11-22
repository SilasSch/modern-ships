class_name EdgeMarkers
extends Control
## Red chevrons at the screen edge pointing to enemies outside the view (submerged subs stay hidden).

var battle: Battle


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if battle == null or battle.camera == null:
		return
	var cam := battle.camera
	var rect := get_viewport_rect().size
	var center := rect * 0.5
	for n: Node in get_tree().get_nodes_in_group(&"enemies"):
		var e := n as Enemy
		if e == null or not e.can_be_hit():
			continue
		var wp := e.global_position
		var behind := cam.is_position_behind(wp)
		var sp := cam.unproject_position(wp)
		if behind:
			sp = center - (sp - center) * 1000.0
		var inside := not behind and sp.x >= 0.0 and sp.y >= 0.0 and sp.x <= rect.x and sp.y <= rect.y
		if inside:
			continue
		var p := Hud.edge_point(center + (sp - center).limit_length(10000.0), rect, 34.0)
		var dir := (sp - center).normalized()
		var side := Vector2(-dir.y, dir.x)
		var tip := p + dir * 12.0
		var col := UiTheme.RED
		draw_colored_polygon(PackedVector2Array([tip, p - dir * 6.0 + side * 10.0, p - dir * 2.0, p - dir * 6.0 - side * 10.0]), col)
		var dist := wp.distance_to(battle.player.global_position)
		draw_string(UiTheme.mono, p - dir * 26.0 + Vector2(-18, 6), "%d m" % dist, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(col, 0.85))
