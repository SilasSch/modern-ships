extends GutTest

const FakeTarget := preload("res://tests/support/fake_target.gd")


func _sim(damage: float = 250.0, pierce: int = 2) -> ProjectileSim:
	return ProjectileSim.new(Vector2.ZERO, Vector2(1, 0), 600.0, 900.0, damage, pierce)


func test_projectile_needs_flight_time() -> void:
	var t := FakeTarget.new(Vector2(300, 0), 4.0)
	var p := _sim()
	assert_eq(p.advance(0.25, [t], [], 1.2).size(), 0, "150 m flown, target at 300 m")
	var hits := p.advance(0.3, [t], [], 1.2)
	assert_eq(hits.size(), 1)
	assert_eq(hits[0]["target"], t)
	assert_almost_eq(float(hits[0]["damage"]), 250.0, 0.01)


func test_pierces_two_and_loses_damage() -> void:
	var a := FakeTarget.new(Vector2(100, 0), 4.0)
	var b := FakeTarget.new(Vector2(150, 0), 4.0)
	var c := FakeTarget.new(Vector2(200, 0), 4.0)
	var p := _sim(250.0, 2)
	var hits := p.advance(0.5, [a, b, c], [], 1.2)
	assert_eq(hits.size(), 2)
	assert_almost_eq(float(hits[0]["damage"]), 250.0, 0.01)
	assert_almost_eq(float(hits[1]["damage"]), 150.0, 0.01)
	assert_true(p.done)


func test_stops_at_island() -> void:
	var t := FakeTarget.new(Vector2(200, 0), 4.0)
	var p := _sim()
	var hits := p.advance(0.5, [t], [{"center": Vector2(100, 0), "radius": 10.0}], 1.2)
	assert_eq(hits.size(), 0)
	assert_true(p.done)
	assert_almost_eq(p.stop_point.x, 90.0, 0.1)


func test_no_double_hit_across_frames() -> void:
	var t := FakeTarget.new(Vector2(100, 0), 6.0)
	var p := _sim(250.0, 3)
	var total := 0
	for i: int in 30:
		total += p.advance(1.0 / 60.0, [t], [], 1.2).size()
	assert_eq(total, 1)


func test_freed_target_ignored() -> void:
	var gone := FakeTarget.new(Vector2(100, 0), 4.0, false)
	var p := _sim()
	assert_eq(p.advance(0.5, [gone, null], [], 1.2).size(), 0)


func test_range_limit() -> void:
	var p := _sim()
	p.advance(1.4, [], [], 1.2)
	assert_false(p.done)
	p.advance(0.2, [], [], 1.2)
	assert_true(p.done)
	assert_almost_eq(p.travelled, 900.0, 0.01)


func test_intercept_static_target_is_target() -> void:
	var r: Variant = Aim.intercept(Vector2.ZERO, Vector2(0, -300), Vector2.ZERO, 600.0)
	assert_eq(r, Vector2(0, -300))


func test_intercept_crossing_target() -> void:
	var r: Variant = Aim.intercept(Vector2.ZERO, Vector2(0, -300), Vector2(10, 0), 600.0)
	assert_not_null(r)
	assert_almost_eq((r as Vector2).x, 5.0, 0.05)


func test_intercept_impossible_returns_null() -> void:
	assert_null(Aim.intercept(Vector2.ZERO, Vector2(0, -300), Vector2(0, -700), 600.0))
