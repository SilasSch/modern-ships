extends RefCounted
## All zoom levels, then the farthest zoom at the map corner: sea must reach every screen edge.


func run(c: Node) -> void:
	var root: Node3D = c.get_tree().current_scene
	(c.find("Camera") as Camera3D).queue_free()
	var ship: PlayerShip = (load("res://ships/player_ship.tscn") as PackedScene).instantiate()
	ship.use_device_input = false
	root.add_child(ship)
	var cam := FollowCamera.new()
	cam.target = ship
	cam.mouse_aim = false
	cam.zoom_index = 0
	root.add_child(cam)
	cam.make_current()
	(c.find("Ocean") as Ocean).follow = cam
	(c.find("Weather") as Weather).follow = cam
	ship.aim_point = Vector3(0, 0, -400)
	for z: int in FollowCamera.ZOOM_LEVELS.size():
		cam.zoom_index = z
		await c.wait(2.5)
		await c.shot("zoom_%d" % z)
	ship.motion.position = Vector2(580, 580)
	await c.wait(3.0)
	await c.shot("zoom_corner")
