extends GutTest
## Regression tests for the stage-1b whole-branch review.

const PlayerShipScene := preload("res://ships/player_ship.tscn")
const FakePlayer := preload("res://tests/support/fake_player.gd")


func after_each() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0


func _ship() -> PlayerShip:
	var s: PlayerShip = PlayerShipScene.instantiate()
	s.use_device_input = false
	add_child_autofree(s)
	return s


# C1 ------------------------------------------------------------ enemies at combat range are on screen
func test_enemy_at_combat_range_visible_in_every_direction() -> void:
	var ship := _ship()
	var cam := FollowCamera.new()
	cam.target = ship
	cam.mouse_aim = false
	add_child_autofree(cam)
	cam.make_current()
	for offset: Vector3 in [Vector3(0, 0, -350), Vector3(0, 0, 350), Vector3(350, 0, 0), Vector3(-350, 0, 0)]:
		ship.aim_point = ship.global_position + offset
		for i: int in 300:
			cam._process(1.0 / 30.0)
		assert_true(cam.is_position_in_frustum(ship.global_position + offset), "enemy at %s visible when aimed at" % offset)
		assert_true(cam.is_position_in_frustum(ship.global_position), "own ship stays in view")


func test_engagement_envelopes_fit_the_view() -> void:
	assert_lte(Tuning.FRIGATE_STANDOFF_MAX, 340.0)
	assert_lte(Tuning.CRUISER_STANDOFF_MAX, 400.0)
	assert_lte(Tuning.DESTROYER_STANDOFF_MAX, 260.0)


# I1 ------------------------------------------------------------ torpedoes reach and hit the hull
func test_torpedo_lives_long_enough_for_its_range() -> void:
	assert_gte(Torpedo.LIFETIME * Tuning.TORPEDO_SPEED, Tuning.SUB_RANGE)


func test_torpedo_hits_bow_not_only_centre() -> void:
	var ship := _ship()
	ship.motion.heading = 0.0
	ship._process(0.0)
	var t := Torpedo.new()
	add_child_autofree(t)
	t.setup(Vector3(-60, 0, -15), Vector3(1, 0, 0), ship)
	for i: int in 180:
		t._process(1.0 / 60.0)
	assert_lt(ship.health.hp, Tuning.PLAYER_HULL, "a torpedo crossing the bow 15 m forward must hit")


func test_shell_bursting_on_the_stern_hits() -> void:
	var ship := _ship()
	ship._process(0.0)
	var shell := Shell.new()
	add_child_autofree(shell)
	shell.setup(Vector3(0, 20, 100), Vector3(0, 0, 16), 0.0, 60.0, ship)
	shell._process(0.016)
	assert_eq(ship.health.hp, Tuning.PLAYER_HULL - 60.0)


# I2 ------------------------------------------------------------ near ocean stays under the player
func test_near_ocean_follows_the_player() -> void:
	var battle := Battle.new()
	battle.waves = [[{"type": &"frigate", "count": 1}]]
	add_child_autofree(battle)
	assert_eq(battle.ocean.follow, battle.player)


# I3 ------------------------------------------------------------ gun bearing / alignment is known
func test_aim_error_reports_turret_lag() -> void:
	var ship := _ship()
	var piv := ship.turret_pivot.global_position
	ship.aim_point = Vector3(piv.x + 200.0, 0, piv.z)
	ship._process(0.016)
	assert_gt(ship.aim_error(), 1.0, "turret still points ahead")
	for i: int in 400:
		ship._process(1.0 / 30.0)
	assert_lt(ship.aim_error(), 0.02, "turret on target")


# I4 ------------------------------------------------------------ enemy hull, not a centre circle
func test_round_hits_destroyer_bow() -> void:
	var d := Enemy.create(&"destroyer")
	add_child_autofree(d)
	d.global_position = Vector3.ZERO
	d.motion.position = Vector2.ZERO
	d.motion.heading = 0.0
	var res := BeamHit.cast(Vector2(-100, -9.5), Vector2(1, 0), 300.0, 1.0, [d], [])
	assert_eq(res["hits"].size(), 1, "a round across the bow 9.5 m forward hits")
	var miss := BeamHit.cast(Vector2(-100, -16.0), Vector2(1, 0), 300.0, 1.0, [d], [])
	assert_eq(miss["hits"].size(), 0, "past the bow tip it misses")


# regraded minors ----------------------------------------------
func test_telegraph_labels_are_ascii_fractions() -> void:
	assert_eq(HelmGauge.T_LABELS, ["Z.VOLL", "STOPP", "1/4", "1/2", "3/4", "VOLL"] as Array[String])


func test_map_edge_warning_gives_room_to_turn() -> void:
	assert_gte(Hud.EDGE_WARN_DIST, 2.0 * Tuning.MAX_SPEED / Tuning.TURN_RATE * 0.5)


func test_enemy_routes_around_island() -> void:
	var e := Enemy.create(&"frigate")
	add_child_autofree(e)
	e.motion.position = Vector2(0, 100)
	e.motion.heading = 0.0
	e.blockers = [{"center": Vector2(0, 0), "radius": 40.0}]
	var wp := e.route_point(Vector2(0, -200))
	assert_false(Blockers.segment_blocked(e.motion.position, wp, e.blockers), "detour waypoint has a clear line")
