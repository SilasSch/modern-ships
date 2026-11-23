extends GutTest

var c: ShipControl


func before_each() -> void:
	c = ShipControl.new()


func test_throttle_steps_and_clamps() -> void:
	for i: int in 5:
		c.throttle_up()
	assert_eq(c.telegraph, 4)
	for i: int in 7:
		c.throttle_down()
	assert_eq(c.telegraph, -1)


func test_target_speed_per_step() -> void:
	c.telegraph = 2
	assert_almost_eq(c.target_speed(12.0, 4.5), 6.0, 0.0001)
	c.telegraph = -1
	assert_almost_eq(c.target_speed(12.0, 4.5), -4.5, 0.0001)
	c.telegraph = 0
	assert_eq(c.target_speed(12.0, 4.5), 0.0)


func test_rudder_shifts_slowly() -> void:
	c.rudder_left()
	c.rudder_left()
	c.tick(1.5)
	assert_almost_eq(c.rudder, 0.5, 0.001)
	c.tick(1.5)
	assert_almost_eq(c.rudder, 1.0, 0.001)


func test_rudder_clamps() -> void:
	for i: int in 4:
		c.rudder_right()
	assert_eq(c.rudder_setting, -2)
	for i: int in 9:
		c.rudder_left()
	assert_eq(c.rudder_setting, 2)


func test_labels() -> void:
	c.telegraph = -1
	assert_eq(c.telegraph_label(), "ZURÜCK VOLL")
	c.telegraph = 4
	assert_eq(c.telegraph_label(), "VOLL")


func test_step_to_reaches_quarter_speed_slowly() -> void:
	var m := ShipMotion.new(Tuning.MAX_SPEED, Tuning.MAX_REVERSE, Tuning.ACCEL, Tuning.TURN_RATE)
	for i: int in 120:
		m.step_to(3.0, 0.0, 1.0 / 60.0)
	assert_almost_eq(m.speed, 1.0, 0.05)
	for i: int in 3480:
		m.step_to(3.0, 0.0, 1.0 / 60.0)
	assert_almost_eq(m.speed, 3.0, 0.01)


func test_full_speed_turn_circle() -> void:
	var m := ShipMotion.new(Tuning.MAX_SPEED, Tuning.MAX_REVERSE, Tuning.ACCEL, Tuning.TURN_RATE)
	m.speed = Tuning.MAX_SPEED
	var minp := Vector2(INF, INF)
	var maxp := -Vector2(INF, INF)
	for i: int in int(80.0 * 30.0):
		m.step_to(Tuning.MAX_SPEED, 1.0, 1.0 / 30.0)
		minp = minp.min(m.position)
		maxp = maxp.max(m.position)
	var diameter := (maxp - minp).x
	assert_almost_eq(diameter, 300.0, 30.0)
