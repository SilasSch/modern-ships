extends RefCounted
## Plays a battle with simulated input: drive, aim at the nearest enemy, fire, overcharge once, then lose.


func _nearest(b: Battle) -> Node3D:
	var best: Node3D = null
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
	var t := _nearest(b)
	if t:
		b.player.aim_point = t.global_position


func run(c: Node) -> void:
	var b: Battle = c.get_tree().current_scene
	var p := b.player
	p.use_device_input = false
	b.camera.mouse_aim = false
	var vp := c.get_viewport()
	Input.warp_mouse(vp.get_visible_rect().size * Vector2(0.62, 0.42))
	p.throttle_input = 0.7
	await c.wait(6.5)
	await c.shot("b_wave1")
	for i in 4:
		_aim(b)
		p._handle_fire_input(true)
		for k in 6:
			await c.wait(0.2)
			_aim(b)
		if i == 0:
			await c.shot("b_hud_charge")
		if i == 2:
			for k in 6:
				await c.wait(0.2)
				_aim(b)
			await c.shot("b_hud_overcharge")
		p._handle_fire_input(false)
		await c.wait(0.2)
		if i == 2:
			await c.shot("b_overcharged_shot")
		p.rudder_input = 0.4 if i % 2 == 0 else -0.3
		await c.wait(1.4)
	await c.shot("b_combat")
	p.apply_damage(10000.0)
	await c.wait(1.0)
	await c.shot("b_sinking")
	await c.wait(2.0)
	await c.shot("b_end")
