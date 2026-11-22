extends GutTest

const PlayerShipScene := preload("res://ships/player_ship.tscn")

var ship: PlayerShip


func before_each() -> void:
	ship = PlayerShipScene.instantiate()
	add_child_autofree(ship)
	ship.aim_point = Vector3(0, 0, -100)


func test_focus_out_cancels_charge() -> void:
	ship._handle_fire_input(true)
	assert_eq(ship.railgun.state, RailgunState.State.CHARGING)
	ship._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_eq(ship.railgun.state, RailgunState.State.READY)


func test_dead_ship_ignores_fire() -> void:
	watch_signals(ship)
	ship.health.damage(1000.0)
	ship._handle_fire_input(true)
	ship.railgun.tick(1.3)
	ship._handle_fire_input(false)
	assert_signal_not_emitted(ship, "fired")
	assert_eq(ship.railgun.state, RailgunState.State.READY)


func test_charge_started_signal() -> void:
	watch_signals(ship)
	ship._handle_fire_input(true)
	assert_signal_emitted(ship, "charge_started")


func test_fire_emits_signal_with_muzzle_origin() -> void:
	watch_signals(ship)
	ship._handle_fire_input(true)
	ship.railgun.tick(1.2)
	var expected_origin := ship.muzzle_transform().origin
	ship._handle_fire_input(false)
	assert_signal_emitted(ship, "fired")
	var params: Array = get_signal_parameters(ship, "fired")
	assert_almost_eq((params[1] as Vector3).distance_to(expected_origin), 0.0, 0.001)
	var dir := params[2] as Vector3
	assert_almost_eq(dir.y, 0.0, 0.0001)
	assert_almost_eq(dir.length(), 1.0, 0.0001)


func test_misfire_damages_self() -> void:
	watch_signals(ship)
	ship.railgun.heat = 0.99
	ship._handle_fire_input(true)
	for i in 30:
		ship._process(0.1)
	assert_signal_emitted(ship, "misfired")
	assert_almost_eq(ship.health.hp, Tuning.PLAYER_HULL - Tuning.MISFIRE_SELF_DAMAGE, 0.001)


func test_apply_damage_emits_died_once() -> void:
	watch_signals(ship)
	ship.apply_damage(1000.0)
	ship.apply_damage(10.0)
	assert_signal_emit_count(ship, "died", 1)
	assert_false(ship.can_be_hit())


func test_moves_forward_with_input() -> void:
	ship.use_device_input = false
	ship.throttle_input = 1.0
	for i in 60:
		ship._process(1.0 / 30.0)
	assert_lt(ship.global_position.z, -1.0)
