extends GutTest

var t: TurretAim


func before_each() -> void:
	t = TurretAim.new()


func test_traverse_rate_limited() -> void:
	t.step(PI / 2.0, 0.0, 0.5)
	assert_almost_eq(t.angle, Tuning.TRAVERSE_RATE * 0.5, 0.001)


func test_clamps_at_arc() -> void:
	for i in 900:
		t.step(PI, 0.0, 1.0 / 60.0)
	assert_almost_eq(absf(t.angle), Tuning.TURRET_ARC, 0.001)


func test_never_crosses_dead_zone() -> void:
	t.angle = deg_to_rad(140.0)
	t.step(deg_to_rad(-140.0), 0.0, 0.1)
	assert_lt(t.angle, deg_to_rad(140.0), "must turn back through the bow")
	for i in 1800:
		t.step(deg_to_rad(-140.0), 0.0, 1.0 / 60.0)
	assert_almost_eq(t.angle, deg_to_rad(-140.0), 0.001)


func test_world_yaw_includes_hull() -> void:
	t.angle = 0.3
	assert_almost_eq(t.world_yaw(1.0), 1.3, 0.0001)


func test_target_relative_to_rotated_hull() -> void:
	for i in 1800:
		t.step(1.0, 0.8, 1.0 / 60.0)
	assert_almost_eq(t.angle, 0.2, 0.001)
