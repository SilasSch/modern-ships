extends GutTest

const ONE_BOAT := [[{"type": &"speedboat", "count": 1}]]

var battle: Battle


func before_each() -> void:
	battle = Battle.new()
	battle.waves = ONE_BOAT
	add_child_autofree(battle)


func after_each() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0


func _enemies() -> Array[Node]:
	return get_tree().get_nodes_in_group(&"enemies")


func test_victory_after_all_waves() -> void:
	assert_eq(battle.outcome(), &"running")
	battle._process(Tuning.WAVE_DELAY + 0.1)
	var enemies := _enemies()
	assert_eq(enemies.size(), 1)
	(enemies[0] as Enemy).apply_damage(1000.0, Vector3.FORWARD)
	battle._process(0.1)
	assert_eq(battle.outcome(), &"victory")
	assert_eq(battle.kills, 1)


func test_defeat_when_player_dies() -> void:
	battle.player.apply_damage(10000.0)
	battle._process(0.1)
	assert_eq(battle.outcome(), &"defeat")


func test_input_disabled_after_end() -> void:
	battle.player.apply_damage(10000.0)
	battle._process(0.1)
	assert_false(battle.player.input_enabled)
	watch_signals(battle.player)
	battle.player._handle_fire_input(true)
	battle.player.railgun.tick(1.3)
	battle.player._handle_fire_input(false)
	assert_signal_not_emitted(battle.player, "fired")


func test_pause_cancels_charge() -> void:
	battle.player.railgun.tick(Tuning.RELOAD_TIME + 0.01)
	battle.player._handle_fire_input(true)
	battle.set_paused(true)
	assert_eq(battle.player.railgun.state, RailgunState.State.READY)
	assert_true(get_tree().paused)
	battle.set_paused(false)
	assert_false(get_tree().paused)


func _enemy_at(kind: StringName, offset: Vector3) -> Enemy:
	var e := Enemy.create(kind)
	e.position = battle.player.global_position + offset
	battle.add_child(e)
	return e


func _shot(damage: float, pierce: int) -> RailgunShot:
	var s := RailgunShot.new()
	s.damage = damage
	s.pierce = pierce
	s.half_width = 1.2
	return s


func _fire_ahead(shot: RailgunShot) -> void:
	var p := battle.player.global_position
	battle._on_fired(shot, Vector3(p.x, 3.0, p.z - 25.0), Vector3(0, 0, -1))


func test_round_hits_after_flight_time() -> void:
	var f := _enemy_at(&"frigate", Vector3(0, 0, -325))
	_fire_ahead(_shot(250.0, 2))
	battle._process(0.2)
	assert_eq(f.health.hp, Tuning.FRIGATE_HP, "still in flight after 0.2 s")
	for i: int in 12:
		battle._process(1.0 / 30.0)
	assert_eq(f.health.hp, Tuning.FRIGATE_HP - 250.0)


func test_round_pierces_two_in_line() -> void:
	var a := _enemy_at(&"speedboat", Vector3(0, 0, -125))
	var b := _enemy_at(&"speedboat", Vector3(0, 0, -175))
	_fire_ahead(_shot(1000.0, 2))
	for i: int in 30:
		battle._process(1.0 / 30.0)
	assert_false(a.can_be_hit())
	assert_false(b.can_be_hit())


func test_round_stopped_by_island() -> void:
	var p := battle.player.global_position
	battle.blockers.append({"center": Vector2(p.x, p.z - 150.0), "radius": 20.0})
	var f := _enemy_at(&"frigate", Vector3(0, 0, -325))
	_fire_ahead(_shot(250.0, 2))
	for i: int in 45:
		battle._process(1.0 / 30.0)
	assert_eq(f.health.hp, Tuning.FRIGATE_HP)


func test_islands_inside_map_and_clear_of_start() -> void:
	var layout: Array = Battle.island_layout()
	assert_eq(layout.size(), 12)
	for isl: Dictionary in layout:
		var p: Vector2 = isl["pos"]
		var r: float = isl["radius"]
		assert_lte(absf(p.x) + r, Tuning.MAP_HALF - 50.0 + 0.01)
		assert_lte(absf(p.y) + r, Tuning.MAP_HALF - 50.0 + 0.01)
		assert_gte(p.length() - r, 120.0)
		assert_between(r, 18.0, 45.0)


func test_enemies_spawn_at_engagement_range() -> void:
	battle._process(Tuning.WAVE_DELAY + 0.1)
	for n: Node in get_tree().get_nodes_in_group(&"enemies"):
		var d := (n as Node3D).global_position.distance_to(battle.player.global_position)
		assert_between(d, 400.0, 620.0)
