class_name Battle
extends Node3D
## One sea battle: storm world, islands, the player destroyer, enemy waves, railgun resolution,
## HUD, pause and end screens.

const ISLANDS := [
	["a", Vector2(72, -62), 18.0],
	["b", Vector2(-92, -38), 12.0],
	["c", Vector2(42, 96), 8.0],
	["b", Vector2(-64, 84), 12.0],
	["c", Vector2(132, 24), 8.0],
]
const END_DELAY := 2.2

var waves: Array = WaveDirector.DEFAULT_WAVES
var director: WaveDirector
var player: PlayerShip
var camera: FollowCamera
var ocean: Ocean
var explosions: ExplosionFx
var hud: Hud
var blockers: Array = []
var kills: int = 0
var elapsed: float = 0.0

var _rounds: Array[RailgunRound] = []
var _end_t: float = -1.0
var _outcome: StringName = &"running"
var _pause_menu: OverlayMenu
var _end_menu: OverlayMenu
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 2026
	director = WaveDirector.new(waves)
	var storm := StormEnvironment.new()
	add_child(storm)
	ocean = Ocean.new()
	add_child(ocean)
	explosions = ExplosionFx.new()
	add_child(explosions)
	for isl: Array in ISLANDS:
		var node: Node3D = (load("res://assets/models/island_%s.glb" % isl[0]) as PackedScene).instantiate()
		var pos: Vector2 = isl[1]
		node.position = Vector3(pos.x, -0.3, pos.y)
		node.rotation.y = _rng.randf_range(0.0, TAU)
		add_child(node)
		blockers.append({"center": pos, "radius": float(isl[2]) * 1.0})
	player = (load("res://ships/player_ship.tscn") as PackedScene).instantiate()
	player.blockers = blockers
	add_child(player)
	player.fired.connect(_on_fired)
	player.died.connect(_on_player_died)
	camera = FollowCamera.new()
	camera.target = player
	add_child(camera)
	camera.make_current()
	ocean.follow = camera
	var weather := Weather.new()
	weather.storm = storm
	weather.follow = camera
	add_child(weather)
	hud = Hud.new()
	hud.battle = self
	add_child(hud)
	_pause_menu = OverlayMenu.new()
	_pause_menu.on_cancel = func() -> void: set_paused(false)
	add_child(_pause_menu)
	_end_menu = OverlayMenu.new()
	add_child(_end_menu)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


func outcome() -> StringName:
	return _outcome


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") and _outcome == &"running":
		set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()


func set_paused(paused: bool) -> void:
	if paused:
		player.railgun.cancel()
		if has_node(^"/root/Sfx"):
			Sfx.loop(&"overcharge_loop", false)
		get_tree().paused = true
		_pause_menu.open("PAUSE", UiTheme.TEXT, "", [
			["Weiter", func() -> void: set_paused(false)],
			["Zum Titel", func() -> void: _flow(&"goto_title")],
		])
	else:
		get_tree().paused = false
		_pause_menu.close()
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


func _process(delta: float) -> void:
	elapsed += delta if _outcome == &"running" else 0.0
	for kind: StringName in director.tick(delta):
		_spawn(kind)
	_step_rounds(delta)
	if _outcome == &"running":
		if player.health.is_dead():
			_finish(&"defeat")
		elif director.is_complete():
			_finish(&"victory")
	elif _end_t >= 0.0:
		_end_t -= delta
		if _end_t < 0.0:
			_show_end()


func _spawn(kind: StringName) -> void:
	var e := Enemy.create(kind)
	if e == null:
		return
	var center := Vector2(player.global_position.x, player.global_position.z)
	var away := -center.normalized() if center.length() > 1.0 else Vector2.UP
	var pos := center
	for attempt in 12:
		var ang := atan2(away.y, away.x) + _rng.randf_range(-1.1, 1.1)
		pos = center + Vector2(cos(ang), sin(ang)) * _rng.randf_range(140.0, 170.0)
		pos = pos.clamp(Vector2.ONE * -(Tuning.MAP_HALF - 10.0), Vector2.ONE * (Tuning.MAP_HALF - 10.0))
		var free := true
		for b: Dictionary in blockers:
			if pos.distance_to(b["center"]) < float(b["radius"]) + 12.0:
				free = false
		if free:
			break
	e.position = Vector3(pos.x, 0.0, pos.y)
	e.rotation.y = ShipMotion.yaw_of(center - pos)
	e.target = player
	e.blockers = blockers
	e.died.connect(_on_enemy_died)
	add_child(e)


func _on_enemy_died(_e: Enemy) -> void:
	kills += 1
	director.enemy_died()


func _on_fired(shot: RailgunShot, origin: Vector3, dir: Vector3) -> void:
	var round := RailgunRound.new()
	round.setup(origin, dir, shot, _hittable_enemies, blockers)
	add_child(round)
	_rounds.append(round)
	var reach := BeamHit.cast(Vector2(origin.x, origin.z), Vector2(dir.x, dir.z), Tuning.PROJECTILE_RANGE, 0.0, [], blockers)
	var end := origin + dir * float(reach["end_distance"])
	player.fx.play_muzzle(origin, dir, shot.overcharge, Vector3(end.x, 0.0, end.z))


func _hittable_enemies() -> Array:
	var out: Array = []
	for n: Node in get_tree().get_nodes_in_group(&"enemies"):
		if n is Enemy and (n as Enemy).can_be_hit():
			out.append(n)
	return out


func _step_rounds(delta: float) -> void:
	for i in range(_rounds.size() - 1, -1, -1):
		var r := _rounds[i]
		if not is_instance_valid(r) or not r.step(delta):
			if is_instance_valid(r):
				r.queue_free()
			_rounds.remove_at(i)


func _on_player_died() -> void:
	explosions.play(player.global_position + Vector3(0, 1.5, 0), 1.6)


func _finish(result: StringName) -> void:
	_outcome = result
	player.input_enabled = false
	player.railgun.cancel()
	_end_t = END_DELAY


func _show_end() -> void:
	var mins := int(elapsed) / 60
	var secs := int(elapsed) % 60
	var stats := "ZEIT %02d:%02d   ·   VERSENKT %d" % [mins, secs, kills]
	if _outcome == &"victory":
		_end_menu.open("SIEG", UiTheme.CYAN, stats, [["Nochmal", func() -> void: _flow(&"start_battle")], ["Zum Titel", func() -> void: _flow(&"goto_title")]])
	else:
		_end_menu.open("VERSENKT", UiTheme.RED, stats, [["Nochmal", func() -> void: _flow(&"start_battle")], ["Zum Titel", func() -> void: _flow(&"goto_title")]])


func _flow(method: StringName) -> void:
	if has_node(^"/root/Flow"):
		get_node(^"/root/Flow").call(method)
