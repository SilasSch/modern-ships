extends RefCounted
## Drives the player ship with simulated input to check movement, buoyancy, wake and turret.


func run(c: Node) -> void:
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
	ship.aim_point = Vector3(40, 0, -40)
	ship.throttle_input = 1.0
	await c.wait(1.5)
	await c.shot("drive_0")
	await c.wait(2.5)
	await c.shot("drive_1")
	ship.rudder_input = 1.0
	ship.aim_point = Vector3(-60, 0, 0)
	await c.wait(3.0)
	await c.shot("drive_turn")
	ship.rudder_input = 0.0
	ship.aim_point = ship.global_position + Vector3(0, 0, 60)
	await c.wait(2.0)
	await c.shot("drive_aim_aft")
