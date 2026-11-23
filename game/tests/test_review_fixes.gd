extends GutTest
## Regression tests for the final whole-branch review findings.

const PlayerShipScene := preload("res://ships/player_ship.tscn")
const FakePlayer := preload("res://tests/support/fake_player.gd")
const TEST_CFG := "user://test_review_override.cfg"


func after_each() -> void:
	Input.action_release(&"fire")
	get_tree().paused = false
	Engine.time_scale = 1.0
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_CFG))
	Settings.override_path = "user://settings_override.cfg"
	Settings.invalidate()


func _ship() -> PlayerShip:
	var s: PlayerShip = PlayerShipScene.instantiate()
	add_child_autofree(s)
	return s


# 1 -------------------------------------------------------------- aim from the turret, not the hull centre
func test_beam_goes_through_the_cursor() -> void:
	var ship := _ship()
	ship.use_device_input = false
	var pivot := ship.turret_pivot.global_position
	ship.aim_point = Vector3(pivot.x + 30.0, 0.0, pivot.z)
	for i in 600:
		ship._process(1.0 / 30.0)
	watch_signals(ship)
	ship._handle_fire_input(true)
	ship.railgun.tick(0.1)
	ship._handle_fire_input(false)
	var dir: Vector3 = get_signal_parameters(ship, "fired")[2]
	assert_almost_eq(dir.z, 0.0, 0.02, "beam must pass through the aim point")
	assert_gt(dir.x, 0.99)


# 2 -------------------------------------------------------------- camera framing and engagement ranges
func test_camera_frames_engagement_ranges() -> void:
	var ship := _ship()
	ship.use_device_input = false
	var cam := FollowCamera.new()
	cam.target = ship
	cam.mouse_aim = false
	add_child_autofree(cam)
	cam.make_current()
	ship.aim_point = ship.global_position + Vector3(0, 0, -100)
	for i in 120:
		cam._process(1.0 / 30.0)
	var p := ship.global_position
	assert_true(cam.is_position_in_frustum(p + Vector3(0, 0, -80)), "80 m ahead visible")
	assert_true(cam.is_position_in_frustum(p + Vector3(60, 0, 0)), "60 m to the side visible")
	assert_true(cam.is_position_in_frustum(p + Vector3(0, 0, 30)), "30 m behind visible")


func test_ranged_enemies_fight_inside_the_view() -> void:
	assert_lte(Tuning.FRIGATE_STANDOFF_MAX, 85.0)
	assert_lte(Tuning.SUB_ATTACK_DIST, 60.0)


func test_offscreen_marker_clamps_to_screen_edge() -> void:
	var p := Hud.edge_point(Vector2(-100, 300), Vector2(1920, 1080), 40.0)
	assert_eq(p, Vector2(40, 300))
	assert_eq(Hud.edge_point(Vector2(5000, -50), Vector2(1920, 1080), 40.0), Vector2(1880, 40))


# 3 -------------------------------------------------------------- hull does not sink into islands
func test_bow_never_enters_island() -> void:
	var m := ShipMotion.new(14.0, 5.0, 3.0, 0.45)
	var island := {"center": Vector2(0, -40), "radius": 8.0}
	for i in 600:
		m.step(1.0, 0.0, 1.0 / 60.0)
		m.resolve_blockers([island], 2.4, 12.0)
	var bow := m.position + ShipMotion.forward_of(m.heading) * 12.0
	assert_gte(bow.distance_to(island["center"]), 8.0 - 0.3)


# 4 -------------------------------------------------------------- map edge: slide, don't glue
func test_map_edge_glancing_keeps_speed() -> void:
	var m := ShipMotion.new(14.0, 5.0, 3.0, 0.45)
	m.position = Vector2(0, -Tuning.MAP_HALF + 0.5)
	m.heading = PI / 4.0
	m.speed = 14.0
	for i in 10:
		m.step(1.0, 0.0, 1.0 / 60.0)
		m.resolve_blockers([], 2.4)
	assert_gt(m.speed, 8.0)


func test_map_edge_head_on_stops() -> void:
	var m := ShipMotion.new(14.0, 5.0, 3.0, 0.45)
	m.position = Vector2(0, -Tuning.MAP_HALF + 0.5)
	m.speed = 14.0
	for i in 10:
		m.step(1.0, 0.0, 1.0 / 60.0)
		m.resolve_blockers([], 2.4)
	assert_lt(m.speed, 1.0)
	assert_gte(m.position.y, -Tuning.MAP_HALF)


# 5 -------------------------------------------------------------- flak hits don't drain the explosion pool
func test_small_hit_does_not_use_explosion_pool() -> void:
	var ex := ExplosionFx.new()
	add_child_autofree(ex)
	var boat := Speedboat.new()
	add_child_autofree(boat)
	boat.apply_damage(Tuning.FLAK_DAMAGE, Vector3.FORWARD)
	assert_eq(ex.pool.active_count(), 0)
	var frig := Frigate.new()
	add_child_autofree(frig)
	frig.apply_damage(Tuning.BASE_DAMAGE, Vector3.FORWARD)
	assert_eq(ex.pool.active_count(), 1, "a railgun hit still explodes")


# 6 -------------------------------------------------------------- holding fire through cooldown starts charging
func test_held_fire_starts_charge_after_cooldown() -> void:
	var ship := _ship()
	assert_eq(ship.railgun.state, RailgunState.State.LOADING)
	Input.action_press(&"fire")
	ship._process(Tuning.RELOAD_TIME + 0.1)
	assert_eq(ship.railgun.state, RailgunState.State.HOLDING, "holding through the reload starts the hold")
	Input.action_release(&"fire")
	watch_signals(ship)
	ship._process(0.05)
	assert_signal_emitted(ship, "fired", "a missed release event still fires")


# 7 -------------------------------------------------------------- medium quality cuts particles
func test_medium_quality_scales_particles() -> void:
	Settings.override_path = TEST_CFG
	Settings.set_quality(false)
	var p := FxUtil.burst(100, 1.0, ParticleProcessMaterial.new(), QuadMesh.new())
	assert_eq(p.amount, 45)
	p.free()
	Settings.set_quality(true)
	var q := FxUtil.burst(100, 1.0, ParticleProcessMaterial.new(), QuadMesh.new())
	assert_eq(q.amount, 100)
	q.free()


# 8 -------------------------------------------------------------- post effects stay under the HUD
func test_post_layer_below_hud() -> void:
	var feel := get_tree().root.get_node(^"Feel")
	var layers := feel.find_children("*", "CanvasLayer", true, false)
	assert_eq(layers.size(), 1)
	assert_lt((layers[0] as CanvasLayer).layer, 10)


# 9 -------------------------------------------------------------- every ship keeps its own wake
func test_wake_slots_unique_and_released() -> void:
	var ocean := Ocean.new()
	add_child_autofree(ocean)
	var seen := {}
	for i in Ocean.WAKE_SLOTS - 1:
		var s := ocean.acquire_wake()
		assert_gt(s, 0, "slot 0 belongs to the player")
		assert_false(seen.has(s))
		seen[s] = true
	assert_eq(ocean.acquire_wake(), -1)
	ocean.release_wake(3)
	assert_eq(ocean.acquire_wake(), 3)
	assert_gte(Ocean.WAKE_SLOTS, 12, "wave 3 has 10 enemies")


# 10 ------------------------------------------------------------- warning sounds come from the right place
func test_shell_and_torpedo_sounds_are_positioned() -> void:
	var fake: Node3D = FakePlayer.new()
	add_child_autofree(fake)
	var shell := Shell.new()
	add_child_autofree(shell)
	shell.setup(Vector3(0, 10, 0), Vector3(50, 0, 50), 1.8, 20.0, fake)
	assert_eq(Sfx.last_at, Vector3(50, 0, 50))
	var t := Torpedo.new()
	add_child_autofree(t)
	t.setup(Vector3(10, 0, 10), Vector3(0, 0, -1), fake)
	assert_almost_eq(Sfx.last_at.distance_to(Vector3(10, -0.3, 10)), 0.0, 0.01)


# 11 + 12 ------------------------------------------------------- pause: silence and Esc toggles
func test_pause_stops_overcharge_hum_and_esc_resumes() -> void:
	var battle := Battle.new()
	battle.waves = [[{"type": &"speedboat", "count": 1}]]
	add_child_autofree(battle)
	Sfx.loop(&"overcharge_loop", true)
	battle.set_paused(true)
	assert_false(Sfx.is_looping(&"overcharge_loop"))
	var ev := InputEventAction.new()
	ev.action = &"pause"
	ev.pressed = true
	battle._pause_menu._unhandled_input(ev)
	assert_false(get_tree().paused, "Esc closes the pause menu")


# 13 ------------------------------------------------------------- islands are cover against enemy fire
func test_torpedo_explodes_on_island() -> void:
	var fake: Node3D = FakePlayer.new()
	add_child_autofree(fake)
	fake.global_position = Vector3(0, 0, -40)
	var t := Torpedo.new()
	add_child_autofree(t)
	t.blockers = [{"center": Vector2(0, -20), "radius": 5.0}]
	t.setup(Vector3.ZERO, Vector3(0, 0, -1), fake)
	for i in 180:
		t._process(1.0 / 60.0)
	assert_eq(fake.damage_taken, 0.0)


func test_line_of_fire_blocked_by_island() -> void:
	var isl := [{"center": Vector2(0, -20), "radius": 5.0}]
	assert_true(Blockers.segment_blocked(Vector2.ZERO, Vector2(0, -40), isl))
	assert_false(Blockers.segment_blocked(Vector2.ZERO, Vector2(20, 0), isl))
	assert_false(Blockers.segment_blocked(Vector2.ZERO, Vector2(0, -10), isl), "target in front of the island")
