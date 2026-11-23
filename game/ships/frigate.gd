class_name Frigate
extends Enemy
## Stealth frigate: keeps 80–130 m, turns broadside, fires telegraphed shell salvos with arcs.

const MODEL := preload("res://assets/models/frigate.glb")
const TELEGRAPH := 0.6

var _salvo_t: float = 0.0
var _telegraph: float = -1.0
var _glows: Array[OmniLight3D] = []
var standoff_min: float = Tuning.FRIGATE_STANDOFF_MIN
var standoff_max: float = Tuning.FRIGATE_STANDOFF_MAX
var salvo_interval: float = Tuning.FRIGATE_SALVO_INTERVAL
var fire_range: float = Tuning.FRIGATE_RANGE


func _init() -> void:
	_setup_kind()


## Overridden by Destroyer / Cruiser to pick model, health and engagement envelope.
func _setup_kind() -> void:
	configure(MODEL, Tuning.FRIGATE_HP, Tuning.FRIGATE_SPEED, 2.0, 0.35, 2.6)
	explosion_strength = 1.3
	collision_radius = 1.7
	half_length = 8.0


func _ready() -> void:
	super._ready()
	_salvo_t = _rng.randf_range(2.0, salvo_interval)
	for n: String in ["Gun_0", "Gun_1", "Gun_2", "Gun_3"]:
		var g := model.find_child(n) as Node3D
		if g:
			var l := OmniLight3D.new()
			l.light_color = Color("#ff5a3b")
			l.omni_range = 9.0
			l.light_energy = 0.0
			g.add_child(l)
			_glows.append(l)


func _ai(delta: float) -> void:
	if not target_alive():
		throttle = 0.3
		rudder = 0.0
		return
	var tp := target_pos2()
	var to := tp - motion.position
	var dist := to.length()
	if dist > standoff_max:
		throttle = 1.0
		steer_to(tp)
	elif dist < standoff_min:
		throttle = 1.0
		steer_to(motion.position - to)
	else:
		throttle = 0.5
		var side := Vector2(-to.y, to.x).normalized()
		if side.dot(ShipMotion.forward_of(motion.heading)) < 0.0:
			side = -side
		steer_to(motion.position + side * 50.0, 1.5)
	_salvo_t -= delta
	if _telegraph >= 0.0:
		_telegraph += delta
		for l: OmniLight3D in _glows:
			l.light_energy = 6.0 * _telegraph / TELEGRAPH
		if _telegraph >= TELEGRAPH:
			_telegraph = -1.0
			for l: OmniLight3D in _glows:
				l.light_energy = 0.0
			_fire_salvo()
	elif _salvo_t <= 0.0 and dist < fire_range:
		_salvo_t = salvo_interval
		_telegraph = 0.0


func _fire_salvo() -> void:
	fire_salvo(Tuning.FRIGATE_SALVO, Tuning.FRIGATE_SHELL_DMG, 10.0)


## Shared by frigate, destroyer and cruiser: telegraphed shells with led aim and spread.
func fire_salvo(count: int, damage: float, spread: float) -> void:
	var dist := Vector2(target.global_position.x - global_position.x, target.global_position.z - global_position.z).length()
	var flight := Shell.flight_time_for(dist)
	var lead := Vector3.ZERO
	if target is PlayerShip:
		var ps := target as PlayerShip
		var f := ShipMotion.forward_of(ps.motion.heading) * ps.motion.speed * flight * 0.8
		lead = Vector3(f.x, 0, f.y)
	for i in count:
		var gun := model.find_child("Gun_%d" % (i % _gun_count())) as Node3D
		var from := gun.global_position if gun else global_position + Vector3(0, 3, 0)
		var aim := target.global_position + lead + Vector3(_rng.randf_range(-spread, spread), 0, _rng.randf_range(-spread, spread))
		var s := Shell.new()
		get_parent().add_child(s)
		s.setup(from, aim, flight + i * 0.12, damage, target)
	_sfx(&"enemy_gun", 6.0)


func _gun_count() -> int:
	return 3
