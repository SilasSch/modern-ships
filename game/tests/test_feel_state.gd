extends GutTest


func test_hitstop_returns_zero_scale_then_one() -> void:
	var f := FeelState.new()
	assert_eq(f.tick(0.016), 1.0, "no hitstop before a shot")
	f.add_shot(0.0)
	assert_eq(f.tick(0.05), 0.0)
	assert_eq(f.tick(0.05), 0.0)
	assert_eq(f.tick(0.05), 1.0)


func test_overcharge_lengthens_hitstop() -> void:
	var f := FeelState.new()
	f.add_shot(1.0)
	assert_almost_eq(f.hitstop_left, Tuning.HITSTOP * 1.5, 0.0001)


func test_trauma_decays_to_zero() -> void:
	var f := FeelState.new()
	f.add_shot(0.0)
	assert_gt(f.trauma, 0.7)
	f.tick(1.0)
	assert_eq(f.trauma, 0.0)
	assert_lt(f.flash, 0.01)


func test_impact_adds_trauma_capped() -> void:
	var f := FeelState.new()
	f.add_impact(1.0)
	f.add_impact(1.0)
	f.add_impact(1.0)
	assert_eq(f.trauma, 1.0)


func test_shake_offset_zero_without_trauma() -> void:
	var f := FeelState.new()
	assert_eq(f.shake_offset(1.234), Vector3.ZERO)
	f.add_impact(1.0)
	assert_gt(f.shake_offset(1.234).length(), 0.0)
