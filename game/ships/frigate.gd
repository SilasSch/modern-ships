class_name Frigate
extends Enemy
## Stealth frigate: keeps 80–130 m, turns broadside, fires telegraphed shell salvos with arcs.

const MODEL := preload("res://assets/models/frigate.glb")
const TELEGRAPH := 0.6

var _salvo_t: float = 0.0
var _telegraph: float = -1.0
var _glows: Array[OmniLight3D] = []


func _init() -> void:
	configure(MODEL, Tuning.FRIGATE_HP, Tuning.FRIGATE_SPEED, 2.0, 0.35, 5.0)
	explosion_strength = 1.3


func _ready() -> void:
	super._ready()
	_salvo_t = _rng.randf_range(2.0, Tuning.FRIGATE_SALVO_INTERVAL)
	for n: String in ["Gun_0", "Gun_1", "Gun_2"]:
		var g := model.find_child(n) as Node3D
		if g:
			var l := OmniLight3D.new()
			l.light_color = Color("#ff5a3b")
			l.omni_range = 6.0
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
	if dist > 130.0:
		throttle = 1.0
		steer_to(tp)
	elif dist < 80.0:
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
	elif _salvo_t <= 0.0 and dist < Tuning.FRIGATE_RANGE:
		_salvo_t = Tuning.FRIGATE_SALVO_INTERVAL
		_telegraph = 0.0


func _fire_salvo() -> void:
	var lead := Vector3.ZERO
	if target is PlayerShip:
		var ps := target as PlayerShip
		var f := ShipMotion.forward_of(ps.motion.heading) * ps.motion.speed * Tuning.SHELL_FLIGHT_TIME * 0.8
		lead = Vector3(f.x, 0, f.y)
	for i in Tuning.FRIGATE_SALVO:
		var gun := model.find_child("Gun_%d" % (i % 3)) as Node3D
		var from := gun.global_position if gun else global_position + Vector3(0, 2, 0)
		var aim := target.global_position + lead + Vector3(_rng.randf_range(-6, 6), 0, _rng.randf_range(-6, 6))
		var s := Shell.new()
		get_parent().add_child(s)
		s.setup(from, aim, Tuning.SHELL_FLIGHT_TIME + i * 0.12, Tuning.FRIGATE_SHELL_DMG, target)
	_sfx(&"enemy_gun", 4.0)
