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
	_draw_gun_bearing(cam)
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
			_draw_lead(cam, e, sp)
			continue
		var p := Hud.edge_point(center + (sp - center).limit_length(10000.0), rect, 34.0)
		var dir := (sp - center).normalized()
		var side := Vector2(-dir.y, dir.x)
		var tip := p + dir * 12.0
		var col := UiTheme.RED
		draw_colored_polygon(PackedVector2Array([tip, p - dir * 6.0 + side * 10.0, p - dir * 2.0, p - dir * 6.0 - side * 10.0]), col)
		var dist := wp.distance_to(battle.player.global_position)
		draw_string(UiTheme.mono, p - dir * 26.0 + Vector2(-18, 6), "%d m" % dist, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(col, 0.85))


## Lead diamond: where to aim so the railgun round meets this enemy.
func _draw_lead(cam: Camera3D, e: Enemy, enemy_screen: Vector2) -> void:
	var muzzle := battle.player.muzzle_transform().origin
	var v := ShipMotion.forward_of(e.motion.heading) * e.motion.speed
	var hit: Variant = Aim.intercept(Vector2(muzzle.x, muzzle.z), Vector2(e.global_position.x, e.global_position.z), v, Tuning.PROJECTILE_SPEED)
	if hit == null:
		return
	var h := hit as Vector2
	var wp := Vector3(h.x, e.global_position.y + 1.0, h.y)
	if cam.is_position_behind(wp):
		return
	var p := cam.unproject_position(wp)
	var col := Color(UiTheme.RED, 0.9)
	if p.distance_to(enemy_screen) > 4.0:
		draw_line(enemy_screen, p, Color(UiTheme.RED, 0.35), 1.0)
	draw_polyline(PackedVector2Array([p + Vector2(0, -8), p + Vector2(8, 0), p + Vector2(0, 8), p + Vector2(-8, 0), p + Vector2(0, -8)]), col, 2.0)


## Thin line along the railgun's actual bearing (where a round fired now would go).
func _draw_gun_bearing(cam: Camera3D) -> void:
	var p := battle.player
	if p == null or p.health.is_dead():
		return
	var m := p.muzzle_transform().origin
	var f := ShipMotion.forward_of(p.turret.world_yaw(p.motion.heading))
	var a := Vector3(m.x, m.y, m.z)
	var b := a + Vector3(f.x, 0.0, f.y) * 260.0
	if cam.is_position_behind(a) or cam.is_position_behind(b):
		return
	var aligned := p.aim_error() <= 0.035
	var col := Color(UiTheme.CYAN, 0.55) if aligned else Color(UiTheme.AMBER, 0.5)
	var sa := cam.unproject_position(a)
	var sb := cam.unproject_position(b)
	var n := 14
	for i in n:
		if i % 2 == 0:
			draw_line(sa.lerp(sb, float(i) / n), sa.lerp(sb, float(i + 1) / n), col, 1.5)
