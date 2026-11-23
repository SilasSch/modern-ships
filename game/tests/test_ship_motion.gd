extends GutTest

var m: ShipMotion


func before_each() -> void:
	m = ShipMotion.new(Tuning.MAX_SPEED, Tuning.MAX_REVERSE, Tuning.ACCEL, Tuning.TURN_RATE)


func _run(throttle: float, rudder: float, seconds: float) -> void:
	for i in int(round(seconds * 60.0)):
		m.step(throttle, rudder, 1.0 / 60.0)


func test_accelerates_to_max_speed_not_beyond() -> void:
	_run(1.0, 0.0, 60.0)
	assert_almost_eq(m.speed, Tuning.MAX_SPEED, 0.001)


func test_moves_along_forward_vector() -> void:
	_run(1.0, 0.0, 2.0)
	assert_lt(m.position.y, 0.0, "heading 0 moves toward -Z")
	assert_almost_eq(m.position.x, 0.0, 0.001)


func test_turns_slowly_at_standstill() -> void:
	_run(0.0, 1.0, 1.0)
	assert_almost_eq(m.heading, Tuning.TURN_RATE * Tuning.TURN_MIN_FACTOR, 0.002)


func test_turns_full_rate_at_max_speed() -> void:
	m.speed = Tuning.MAX_SPEED
	m.step(1.0, 1.0, 0.1)
	assert_almost_eq(m.heading, Tuning.TURN_RATE * 0.1, 0.001)


func test_positive_rudder_turns_left() -> void:
	m.speed = 14.0
	_run(1.0, 1.0, 1.0)
	assert_lt(m.position.x, 0.0, "turning left drifts toward -X")


func test_coasts_to_stop() -> void:
	m.speed = Tuning.MAX_SPEED
	_run(0.0, 0.0, 15.0)
	assert_lt(m.speed, 1.0)
	assert_gt(m.speed, -0.001)


func test_reverse_capped() -> void:
	_run(-1.0, 0.0, 60.0)
	assert_almost_eq(m.speed, -Tuning.MAX_REVERSE, 0.001)


func test_island_pushes_ship_out_and_kills_inward_speed() -> void:
	m.position = Vector2(0, 0)
	m.heading = 0.0
	m.speed = 10.0
	var island := {"center": Vector2(0, -12), "radius": 8.0}
	_run(1.0, 0.0, 0.5)
	m.resolve_blockers([island], 4.0)
	var to_center: Vector2 = island["center"] - m.position
	assert_gte(to_center.length(), 12.0 - 0.001)
	assert_lte((ShipMotion.forward_of(m.heading) * m.speed).dot(to_center), 0.001)


func test_map_edge_clamps() -> void:
	m.position = Vector2(0, -Tuning.MAP_HALF + 1.0)
	m.speed = 14.0
	_run(1.0, 0.0, 1.0)
	m.resolve_blockers([], 4.0)
	assert_gte(m.position.y, -Tuning.MAP_HALF)


func test_yaw_and_forward_roundtrip() -> void:
	var dir := Vector2(1, -1).normalized()
	assert_almost_eq(ShipMotion.forward_of(ShipMotion.yaw_of(dir)).distance_to(dir), 0.0, 0.0001)
