extends RefCounted
## Simulated stage-1b battle: telegraph/rudder driving, lead-aimed railgun shots (one overcharged), then defeat.


func _nearest(b: Battle) -> Enemy:
	var best: Enemy = null
	var bd := INF
	for n: Node in b.get_tree().get_nodes_in_group(&"enemies"):
		var e := n as Enemy
		if e and e.can_be_hit():
			var d := e.global_position.distance_to(b.player.global_position)
			if d < bd:
				bd = d
				best = e
	return best


func _aim(b: Battle) -> void:
	var e := _nearest(b)
	if e == null:
		return
	var m := b.player.muzzle_transform().origin
	var v := ShipMotion.forward_of(e.motion.heading) * e.motion.speed
	var hit: Variant = Aim.intercept(Vector2(m.x, m.z), Vector2(e.global_position.x, e.global_position.z), v, Tuning.PROJECTILE_SPEED)
	if hit != null:
		b.player.aim_point = Vector3((hit as Vector2).x, 0, (hit as Vector2).y)


func _aim_for(c: Node, b: Battle, seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		_aim(b)
		await c.wait(0.1)
		t += 0.1


func run(c: Node) -> void:
	var b: Battle = c.get_tree().current_scene
	var p := b.player
	p.use_device_input = false
	b.camera.mouse_aim = false
	b.camera.zoom_index = 2
	Input.warp_mouse(c.get_viewport().get_visible_rect().size * Vector2(0.62, 0.42))
	p.control.telegraph = 3
	p.control.rudder_setting = 1
	await _aim_for(c, b, 5.0)
	await c.shot("b_wave1")
	p.control.rudder_setting = 0
	await _aim_for(c, b, 3.5)
	# first shot: click
	p._handle_fire_input(true)
	await _aim_for(c, b, 0.1)
	p._handle_fire_input(false)
	await c.wait(0.25)
	await c.shot("b_round_flight")
	await _aim_for(c, b, 6.8)
	# second shot: full overcharge
	p._handle_fire_input(true)
	await _aim_for(c, b, 1.2)
	await c.shot("b_hud_hold")
	await _aim_for(c, b, 1.1)
	await c.shot("b_hud_overcharge")
	p._handle_fire_input(false)
	await c.shot("b_overcharged_muzzle")
	await c.wait(0.4)
	await c.shot("b_overcharged_impact")
	p.control.rudder_setting = -2
	await _aim_for(c, b, 8.0)
	await c.shot("b_combat")
	p.apply_damage(100000.0)
	await c.wait(1.0)
	await c.shot("b_sinking")
	await c.wait(2.0)
	await c.shot("b_end")
