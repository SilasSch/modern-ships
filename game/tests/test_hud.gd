extends GutTest


func after_each() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0


func test_knots_conversion() -> void:
	assert_eq(Hud.knots(6.0), 12)
	assert_eq(Hud.knots(0.0), 0)
	assert_eq(Hud.knots(-4.5), -9)


func test_hud_builds_with_battle() -> void:
	var battle := Battle.new()
	battle.waves = [[{"type": &"frigate", "count": 1}]]
	add_child_autofree(battle)
	var gauge := battle.hud.find_child("HelmGauge", true, false) as HelmGauge
	assert_not_null(gauge)
	assert_eq(gauge.control, battle.player.control)
	battle.player.control.throttle_up()
	gauge.queue_redraw()
	assert_eq(gauge.telegraph_index(), 2, "cell index of ¼ (0 = back full)")
