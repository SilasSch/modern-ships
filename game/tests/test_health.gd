extends GutTest


func test_damage_kills_once() -> void:
	var h := Health.new(100.0)
	assert_false(h.damage(60.0))
	assert_true(h.damage(60.0))
	assert_true(h.is_dead())
	assert_false(h.damage(10.0))
	assert_eq(h.hp, 0.0)


func test_fraction() -> void:
	var h := Health.new(200.0)
	h.damage(50.0)
	assert_almost_eq(h.fraction(), 0.75, 0.0001)
