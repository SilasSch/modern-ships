extends GutTest


func test_wave_height_bounded() -> void:
	for ix in 50:
		for iz in 50:
			var h := Ocean.wave_height(ix * 3.7 - 90.0, iz * 3.1 - 70.0, 12.3, 1.55)
			assert_true(absf(h) <= 1.55 * 0.75, "height %f out of bounds" % h)


func test_wave_height_continuous() -> void:
	for i in 200:
		var x := i * 1.3 - 100.0
		var a := Ocean.wave_height(x, 5.0, 3.0, 1.55)
		var b := Ocean.wave_height(x + 0.1, 5.0, 3.0, 1.55)
		assert_true(absf(a - b) < 0.1)


func test_wave_height_changes_over_time() -> void:
	assert_ne(Ocean.wave_height(10.0, 10.0, 0.0, 1.55), Ocean.wave_height(10.0, 10.0, 1.0, 1.55))


func test_ocean_forwards_ring_to_effects() -> void:
	var ocean := Ocean.new()
	add_child_autofree(ocean)
	ocean.add_ring(Vector3(1.0, 5.0, 2.0), 0.8)
	var r: Vector4 = ocean.effects.ring_data()[0]
	assert_eq(r, Vector4(1.0, 2.0, 0.0, 0.8))


func test_ocean_forwards_trench_and_charge() -> void:
	var ocean := Ocean.new()
	add_child_autofree(ocean)
	ocean.add_trench(Vector3(0, 0, 0), Vector3(10, 2, -5), 2.0)
	ocean.set_charge(Vector3(3, 0, 4), 0.5)
	assert_eq(ocean.effects.trench_data()[0], Vector4(0, 0, 10, -5))
	assert_eq(ocean.effects.charge_pos, Vector2(3, 4))


func test_trench_meta_has_speed() -> void:
	var e := OceanEffects.new()
	e.add_trench(Vector2.ZERO, Vector2(100, 0), 3.0, 600.0)
	assert_eq(e.trench_meta()[0], Vector3(0.0, 3.0, 600.0))


func test_far_ocean_follows() -> void:
	var ocean := Ocean.new()
	add_child_autofree(ocean)
	var target := Node3D.new()
	add_child_autofree(target)
	ocean.follow = target
	target.global_position = Vector3(333.0, 0, -127.0)
	ocean._process(0.016)
	var far := ocean.get_node("FarOcean") as MeshInstance3D
	assert_almost_eq(far.global_position.x, 333.0, Ocean.SIZE / Ocean.SUBDIV)
	assert_true((far.material_override as ShaderMaterial).get_shader_parameter("far_lod"))
