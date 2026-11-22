extends GutTest

func test_overcharge_window_and_damage_sane() -> void:
	assert_gt(Tuning.OVERCHARGE_TIME, 0.0)
	assert_eq(Tuning.BASE_DAMAGE, 100.0)
	assert_true(Tuning.TURRET_ARC < PI)
