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
