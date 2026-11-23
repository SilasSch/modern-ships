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


func test_railgun_shot_damages_enemy_in_line() -> void:
	battle._process(Tuning.WAVE_DELAY + 0.1)
	var e := _enemies()[0] as Enemy
	var origin := Vector3(e.global_position.x - 50.0, 2.0, e.global_position.z)
	var shot := RailgunShot.new()
	shot.damage = 1000.0
	shot.half_width = 1.2
	battle._on_fired(shot, origin, Vector3(1, 0, 0))
	battle._process(0.2)
	assert_false(e.can_be_hit(), "enemy on the line is destroyed after the beam delay")
