extends GutTest


func test_unused_slots_are_inactive() -> void:
	var e := OceanEffects.new()
	var rings := e.ring_data()
	assert_eq(rings.size(), 8)
	assert_eq(rings[3].z, 99.0)
	assert_eq(rings[3].w, 0.0)
	assert_eq(e.trench_data().size(), 2)
	assert_eq(e.trench_meta()[1].x, 99.0)


func test_ring_buffer_recycles_oldest() -> void:
	var e := OceanEffects.new()
	for i in 9:
		e.add_ring(Vector2(i, 0), float(i + 1))
	assert_eq(e.ring_data()[0].w, 9.0)
	assert_eq(e.ring_data()[0].x, 8.0)
	assert_eq(e.ring_data()[1].w, 2.0)


func test_rings_and_trenches_age() -> void:
	var e := OceanEffects.new()
	e.add_ring(Vector2(5, 6), 1.0)
	e.add_trench(Vector2(0, 0), Vector2(10, 0), 3.0)
	e.tick(0.5)
	assert_almost_eq(e.ring_data()[0].z, 0.5, 0.0001)
	assert_almost_eq(e.trench_meta()[0].x, 0.5, 0.0001)
	assert_eq(e.trench_meta()[0].y, 3.0)
	assert_eq(e.trench_data()[0], Vector4(0, 0, 10, 0))


func test_charge_stored() -> void:
	var e := OceanEffects.new()
	e.set_charge(Vector2(3, 4), 0.7)
	assert_eq(e.charge_pos, Vector2(3, 4))
	assert_eq(e.charge_amount, 0.7)
