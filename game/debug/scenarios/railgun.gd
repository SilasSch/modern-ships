extends RefCounted
## Railgun round: loaded, hold 50 % / 100 %, muzzle blast, round in flight, impact, aftermath.

var _rounds: Array[RailgunRound] = []


func run(c: Node) -> void:
	var root: Node3D = c.get_tree().current_scene
	(c.find("Camera") as Camera3D).queue_free()
	var boom := ExplosionFx.new()
	root.add_child(boom)
	var ship: PlayerShip = (load("res://ships/player_ship.tscn") as PackedScene).instantiate()
	ship.use_device_input = false
	root.add_child(ship)
	var cam := FollowCamera.new()
	cam.target = ship
	cam.mouse_aim = false
	cam.zoom_index = 1
	root.add_child(cam)
	cam.make_current()
	(c.find("Ocean") as Ocean).follow = cam
	(c.find("Weather") as Weather).follow = cam
	var targets: Array = []
	for d: float in [150.0, 190.0]:
		var f := Frigate.new()
		f.position = Vector3(d * 0.6, 0, -d * 0.8)
		f.rotation.y = 0.4
		root.add_child(f)
		targets.append(f)
	ship.aim_point = Vector3(120, 0, -160)
	ship.fired.connect(func(shot: RailgunShot, origin: Vector3, dir: Vector3) -> void:
		var r := RailgunRound.new()
		r.setup(origin, dir, shot, func() -> Array: return targets.filter(func(t: Enemy) -> bool: return is_instance_valid(t) and t.can_be_hit()), [])
		root.add_child(r)
		_rounds.append(r)
		ship.fx.play_muzzle(origin, dir, shot.overcharge, origin + dir * Tuning.PROJECTILE_RANGE))
	c.get_tree().process_frame.connect(func() -> void:
		for r: RailgunRound in _rounds:
			if is_instance_valid(r):
				r.step(1.0 / 30.0))
	ship.railgun.tick(Tuning.RELOAD_TIME - 1.5)
	await c.wait(1.8)
	await c.shot("r_loaded")
	ship._handle_fire_input(true)
	await c.wait(1.25)
	await c.shot("r_hold50")
	await c.wait(1.0)
	await c.shot("r_hold100")
	ship._handle_fire_input(false)
	await c.shot("r_muzzle")
	await c.wait(0.15)
	await c.shot("r_flight")
	await c.wait(0.25)
	await c.shot("r_impact")
	await c.wait(1.0)
	await c.shot("r_after")
