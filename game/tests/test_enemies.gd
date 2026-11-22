extends GutTest

const FakePlayer := preload("res://tests/support/fake_player.gd")


func _fake_at(pos: Vector3) -> Node3D:
	var f: Node3D = FakePlayer.new()
	add_child_autofree(f)
	f.global_position = pos
	return f


func test_submerged_sub_cannot_be_hit() -> void:
	var sub := Submarine.new()
	add_child_autofree(sub)
	sub.set_state(Submarine.SubState.SUBMERGED)
	assert_false(sub.can_be_hit())
	sub.set_state(Submarine.SubState.SURFACED)
	assert_true(sub.can_be_hit())


func test_enemy_died_signal_once() -> void:
	var boat := Speedboat.new()
	add_child_autofree(boat)
	watch_signals(boat)
	boat.apply_damage(1000.0, Vector3.FORWARD)
	boat.apply_damage(1000.0, Vector3.FORWARD)
	assert_signal_emit_count(boat, "died", 1)
	assert_false(boat.can_be_hit())


func test_frigate_survives_one_normal_railgun_hit() -> void:
	var f := Frigate.new()
	add_child_autofree(f)
	f.apply_damage(Tuning.BASE_DAMAGE, Vector3.FORWARD)
	assert_true(f.can_be_hit())
	f.apply_damage(Tuning.BASE_DAMAGE, Vector3.FORWARD)
	assert_false(f.can_be_hit())


func _shell_damage(offset: float) -> float:
	var fake := _fake_at(Vector3(offset, 0, 0))
	var shell := Shell.new()
	add_child_autofree(shell)
	shell.setup(Vector3(0, 20, -100), Vector3.ZERO, 0.0, Tuning.FRIGATE_SHELL_DMG, fake)
	shell._process(0.016)
	return fake.damage_taken


func test_shell_damages_player_in_radius() -> void:
	assert_eq(_shell_damage(3.0), 20.0)
	assert_eq(_shell_damage(7.0), 0.0)


func test_torpedo_hits_player() -> void:
	var fake := _fake_at(Vector3(0, 0, -10))
	var t := Torpedo.new()
	add_child_autofree(t)
	t.setup(Vector3.ZERO, Vector3(0, 0, -1), fake)
	for i in 60:
		t._process(1.0 / 60.0)
	assert_eq(fake.damage_taken, Tuning.TORPEDO_DMG)


func test_flak_ignores_large_targets() -> void:
	var frigate := Frigate.new()
	add_child_autofree(frigate)
	frigate.global_position = Vector3(30, 0, 0)
	assert_null(FlakTurret.pick_target(Vector3.ZERO, 0.0, [frigate]))
	var boat := Speedboat.new()
	add_child_autofree(boat)
	boat.global_position = Vector3(30, 0, 0)
	assert_eq(FlakTurret.pick_target(Vector3.ZERO, 0.0, [frigate, boat]), boat)


func test_flak_respects_range_and_bow_arc() -> void:
	var boat := Speedboat.new()
	add_child_autofree(boat)
	boat.global_position = Vector3(0, 0, -30)
	assert_null(FlakTurret.pick_target(Vector3.ZERO, 0.0, [boat]), "straight ahead is the railgun's arc")
	boat.global_position = Vector3(90, 0, 0)
	assert_null(FlakTurret.pick_target(Vector3.ZERO, 0.0, [boat]), "out of range")
