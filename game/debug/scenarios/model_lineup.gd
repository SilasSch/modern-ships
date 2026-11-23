extends RefCounted

const MODELS := ["battlecruiser", "cruiser", "enemy_destroyer", "frigate", "submarine", "speedboat"]


func run(c: Node) -> void:
	var root: Node3D = c.get_tree().current_scene
	var x := -75.0
	for m: String in MODELS:
		var inst: Node3D = (load("res://assets/models/%s.glb" % m) as PackedScene).instantiate()
		inst.position = Vector3(x, 0, 0)
		inst.rotation.y = deg_to_rad(-60.0)
		root.add_child(inst)
		x += 34.0 if m in ["battlecruiser", "cruiser"] else 24.0
	var cam: Camera3D = c.find("Camera")
	cam.position = Vector3(-5, 70, 95)
	cam.look_at(Vector3(-5, 0, 0))
	await c.wait(1.0)
	await c.shot("lineup")
	cam.position = Vector3(-55, 20, 34)
	cam.look_at(Vector3(-75, 3, 0))
	await c.wait(0.3)
	await c.shot("close_battlecruiser")
	cam.position = Vector3(-25, 16, 30)
	cam.look_at(Vector3(-41, 2, 0))
	await c.wait(0.3)
	await c.shot("close_cruiser")
