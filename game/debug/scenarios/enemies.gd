extends RefCounted
## One of each enemy attacks the player; captures shells, torpedo, surfacing sub, flak and a sinking boat.


func run(c: Node) -> void:
	var root: Node3D = c.get_tree().current_scene
	(c.find("Camera") as Camera3D).queue_free()
	var boom := ExplosionFx.new()
	root.add_child(boom)
	var ship: PlayerShip = (load("res://ships/player_ship.tscn") as PackedScene).instantiate()
	ship.use_device_input = false
	root.add_child(ship)
	ship.control.telegraph = 2
	var cam := FollowCamera.new()
	cam.target = ship
	cam.mouse_aim = false
	cam.distance = 75.0
	root.add_child(cam)
	cam.make_current()
	(c.find("Weather") as Weather).follow = cam
	ship.aim_point = Vector3(60, 0, -40)
	var spawn := func(kind: StringName, pos: Vector3, yaw: float) -> Enemy:
		var e := Enemy.create(kind)
		e.position = pos
		e.rotation.y = yaw
		e.target = ship
		root.add_child(e)
		return e
	var boat: Enemy = spawn.call(&"speedboat", Vector3(-30, 0, -20), 1.0)
	spawn.call(&"speedboat", Vector3(30, 0, 10), -1.5)
	var frig: Frigate = spawn.call(&"frigate", Vector3(45, 0, -70), 2.0)
	var sub: Submarine = spawn.call(&"submarine", Vector3(-35, 0, -45), 0.5)
	frig._salvo_t = 0.5
	await c.wait(1.3)
	await c.shot("e_telegraph")
	await c.wait(0.9)
	await c.shot("e_shells_flight")
	await c.wait(1.0)
	await c.shot("e_shells_impact")
	sub.set_state(Submarine.SubState.SURFACING)
	await c.wait(0.8)
	await c.shot("e_sub_surfacing")
	await c.wait(1.6)
	await c.shot("e_torpedo")
	if is_instance_valid(boat):
		boat.apply_damage(1000.0, Vector3.FORWARD)
	await c.wait(0.25)
	await c.shot("e_boat_explodes")
	await c.wait(1.5)
	await c.shot("e_boat_sinking")
