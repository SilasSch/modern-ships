extends RefCounted
## Charge, overcharge and fire the railgun; capture every stage of the shot.


func _setup(c: Node) -> PlayerShip:
	var root: Node3D = c.get_tree().current_scene
	(c.find("Camera") as Camera3D).queue_free()
	var ship: PlayerShip = (load("res://ships/player_ship.tscn") as PackedScene).instantiate()
	ship.use_device_input = false
	root.add_child(ship)
	var cam := FollowCamera.new()
	cam.target = ship
	cam.mouse_aim = false
	root.add_child(cam)
	cam.make_current()
	(c.find("Weather") as Weather).follow = cam
	var boom := ExplosionFx.new()
	boom.name = "Explosions"
	root.add_child(boom)
	ship.aim_point = Vector3(80, 0, -50)
	ship.fired.connect(func(shot: RailgunShot, origin: Vector3, dir: Vector3) -> void:
		ship.fx.play_shot(origin, dir, Tuning.BEAM_RANGE, shot.overcharge)
		var hit := origin + dir * 55.0
		c.get_tree().create_timer(0.1, true, false, false).timeout.connect(func() -> void: boom.play(hit, 1.0 + shot.overcharge)))
	return ship


func _fire_sequence(c: Node, ship: PlayerShip, hold: float, tag: String) -> void:
	ship._handle_fire_input(true)
	await c.wait(0.6)
	await c.shot(tag + "_charge50")
	await c.wait(0.6)
	await c.shot(tag + "_charge100")
	if hold > 1.2:
		await c.wait(hold - 1.2)
		await c.shot(tag + "_overcharge")
	ship._handle_fire_input(false)
	await c.shot(tag + "_hitstop")
	await c.wait(0.15)
	await c.shot(tag + "_t015")
	await c.wait(0.35)
	await c.shot(tag + "_t050")
	await c.wait(0.7)
	await c.shot(tag + "_t120")


func run(c: Node) -> void:
	var ship := _setup(c)
	await c.wait(2.0)
	await _fire_sequence(c, ship, 1.2 + 0.78, "a")
	await c.wait(3.5)
	await _fire_sequence(c, ship, 1.2 + 1.3, "b")
