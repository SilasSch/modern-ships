extends GutTest

var gun: RailgunState


func before_each() -> void:
	gun = RailgunState.new()


func _run(seconds: float, step: float = 0.05) -> bool:
	var misfired := false
	var t := 0.0
	while t < seconds - 0.0001:
		if gun.tick(step):
			misfired = true
		t += step
	return misfired


func _load() -> void:
	_run(Tuning.RELOAD_TIME + 0.05)


func test_starts_loading_then_ready() -> void:
	assert_eq(gun.state, RailgunState.State.LOADING)
	_run(6.9)
	assert_eq(gun.state, RailgunState.State.LOADING)
	assert_almost_eq(gun.reload, 6.9 / 7.0, 0.01)
	_run(0.2)
	assert_eq(gun.state, RailgunState.State.READY)


func test_click_fires_base_shot() -> void:
	_load()
	gun.press()
	_run(0.1)
	var shot := gun.release()
	assert_not_null(shot)
	assert_almost_eq(shot.damage, 250.0, 0.01)
	assert_eq(shot.overcharge, 0.0)
	assert_eq(shot.pierce, 2)
	assert_eq(gun.state, RailgunState.State.LOADING)
	assert_eq(gun.reload, 0.0)


func test_hold_overcharges() -> void:
	_load()
	gun.press()
	_run(Tuning.CLICK_GRACE + Tuning.OVERCHARGE_TIME)
	var shot := gun.release()
	assert_almost_eq(shot.damage, 500.0, 2.0)
	assert_eq(shot.pierce, 4)


func test_press_while_loading_ignored() -> void:
	_run(3.0)
	gun.press()
	assert_eq(gun.state, RailgunState.State.LOADING)
	assert_null(gun.release())
	assert_eq(gun.state, RailgunState.State.LOADING)


func test_press_right_after_reload_starts_holding() -> void:
	_load()
	gun.press()
	assert_eq(gun.state, RailgunState.State.HOLDING)


func test_overheat_misfire_locks() -> void:
	_load()
	gun.press()
	var misfired := false
	var t := 0.0
	while t < 6.0 and not misfired:
		misfired = gun.tick(0.1)
		t += 0.1
	assert_true(misfired)
	assert_eq(gun.state, RailgunState.State.LOCKED)
	assert_almost_eq(gun.heat, Tuning.HEAT_AFTER_MISFIRE, 0.01)
	gun.press()
	assert_eq(gun.state, RailgunState.State.LOCKED)
	_run(Tuning.LOCK_TIME)
	assert_eq(gun.state, RailgunState.State.LOADING)


func test_cancel_keeps_round_loaded() -> void:
	_load()
	gun.press()
	_run(1.0)
	gun.cancel()
	assert_eq(gun.state, RailgunState.State.READY)
	assert_eq(gun.overcharge, 0.0)


func test_heat_decays_when_idle() -> void:
	gun.heat = 0.5
	gun.tick(1.0)
	assert_almost_eq(gun.heat, 0.3, 0.001)
