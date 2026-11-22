extends RefCounted

const MODELS := ["destroyer", "frigate", "speedboat", "submarine"]


func run(c: Node) -> void:
	var root: Node3D = c.get_tree().current_scene
	var x := -30.0
	for m: String in MODELS:
		var inst: Node3D = (load("res://assets/models/%s.glb" % m) as PackedScene).instantiate()
		inst.position = Vector3(x, 0, 0)
		inst.rotation.y = deg_to_rad(-60.0)
		root.add_child(inst)
		x += 20.0
	for i: int in 3:
		var isl: Node3D = (load("res://assets/models/island_%s.glb" % ["a", "b", "c"][i]) as PackedScene).instantiate()
		isl.position = Vector3(-60.0 + i * 55.0, 0, -60.0)
		root.add_child(isl)
	var cam: Camera3D = c.find("Camera")
	await c.wait(1.0)
	await c.shot("lineup")
	cam.position = Vector3(-18, 11, 16)
	cam.look_at(Vector3(-30, 2, 0))
	await c.wait(0.3)
	await c.shot("close_destroyer")
	cam.position = Vector3(-8, 8, 15)
	cam.look_at(Vector3(-4, 0.5, 0))
	await c.wait(0.3)
	await c.shot("close_frigate_boat")
