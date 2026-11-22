extends GutTest

const DIR := "res://assets/models/"


func _load(model: String) -> Node3D:
	var scene: PackedScene = load(DIR + model + ".glb")
	assert_not_null(scene, model + ".glb must exist")
	if scene == null:
		return null
	var root: Node3D = scene.instantiate()
	add_child_autofree(root)
	return root


func _length_z(root: Node3D) -> float:
	var box := AABB()
	var first := true
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var b := mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box.size.z


func test_destroyer_contract() -> void:
	var r := _load("destroyer")
	if r == null:
		return
	assert_not_null(r.get_node_or_null("TurretPivot/Railgun/Muzzle"))
	assert_not_null(r.find_child("FlakPivot"))
	assert_not_null(r.find_child("Bridge"))
	assert_almost_eq(_length_z(r), 24.0, 2.4 + 3.0, "hull 24 m plus railgun overhang")
	var muzzle: Node3D = r.get_node("TurretPivot/Railgun/Muzzle")
	assert_lt(muzzle.global_position.z, -10.0, "bow and muzzle point to -Z")


func _enemy_contract(model: String, length: float, extra: String) -> void:
	var r := _load(model)
	if r == null:
		return
	assert_not_null(r.find_child("Bow"), model + " Bow")
	assert_not_null(r.find_child("Stern"), model + " Stern")
	assert_not_null(r.find_child(extra), model + " " + extra)
	assert_almost_eq(_length_z(r), length, length * 0.12)


func test_frigate_contract() -> void:
	_enemy_contract("frigate", 16.0, "Gun_0")


func test_speedboat_contract() -> void:
	_enemy_contract("speedboat", 6.0, "Gun")


func test_submarine_contract() -> void:
	_enemy_contract("submarine", 14.0, "Tube")


func test_islands_load() -> void:
	for n: String in ["island_a", "island_b", "island_c"]:
		assert_not_null(_load(n))
