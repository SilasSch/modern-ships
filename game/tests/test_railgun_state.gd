extends GutTest

var gun: RailgunState


func before_each() -> void:
	gun = RailgunState.new()


func _hold(seconds: float, step: float = 0.05) -> bool:
	var misfired := false
	var t := 0.0
	while t < seconds - 0.0001:
		if gun.tick(step):
			misfired = true
		t += step
	return misfired


func test_release_before_full_cancels() -> void:
	gun.press()
	_hold(0.6)
	var shot: RailgunShot = gun.release()
	assert_null(shot)
	assert_eq(gun.state, RailgunState.State.READY)


func test_full_charge_fires_base_damage() -> void:
	gun.press()
	_hold(1.2)
	var shot: RailgunShot = gun.release()
	assert_not_null(shot)
	assert_almost_eq(shot.damage, 100.0, 0.01)
	assert_almost_eq(shot.overcharge, 0.0, 0.01)
	assert_eq(gun.state, RailgunState.State.COOLDOWN)


func test_overcharge_doubles_damage() -> void:
	gun.press()
	_hold(1.2 + 1.3)
	var shot: RailgunShot = gun.release()
	assert_almost_eq(shot.damage, 200.0, 0.5)
	assert_almost_eq(shot.half_width, 2.4, 0.01)


func test_cooldown_blocks_press() -> void:
	gun.press()
	_hold(1.2)
	gun.release()
	gun.press()
	assert_eq(gun.state, RailgunState.State.COOLDOWN)
	_hold(1.0)
	gun.press()
	assert_eq(gun.state, RailgunState.State.CHARGING)


func test_holding_overcharge_overheats_and_locks() -> void:
	gun.press()
	var misfired := false
	var t := 0.0
	while t < 6.0 and not misfired:
		misfired = gun.tick(0.1)
		t += 0.1
	assert_true(misfired, "holding in overcharge must overheat within 6 s")
	assert_eq(gun.state, RailgunState.State.LOCKED)
	assert_almost_eq(gun.heat, 0.6, 0.01)
	gun.press()
	assert_eq(gun.state, RailgunState.State.LOCKED)
	_hold(4.0)
	assert_eq(gun.state, RailgunState.State.READY)


func test_spamming_overcharged_shots_overheats() -> void:
	var misfired := false
	for i in 3:
		gun.press()
		var t := 0.0
		while t < 2.5 and not misfired:
			misfired = gun.tick(0.05)
			t += 0.05
		if misfired:
			break
		gun.release()
		_hold(1.0)
	assert_true(misfired, "third overcharged charge at the latest must misfire")


func test_cancel_while_charging() -> void:
	gun.press()
	_hold(0.8)
	gun.cancel()
	assert_eq(gun.state, RailgunState.State.READY)
	assert_eq(gun.charge, 0.0)
	assert_null(gun.release())


func test_heat_decays_when_idle() -> void:
	gun.heat = 0.5
	gun.tick(1.0)
	assert_almost_eq(gun.heat, 0.3, 0.001)
