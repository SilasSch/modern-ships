class_name Submarine
extends Enemy
## Hunter submarine: hidden while submerged (only its wake shows), surfaces with a warning,
## fires a torpedo, then dives again. Only hittable while surfaced.

enum SubState { SUBMERGED, SURFACING, SURFACED, DIVING }

const MODEL := preload("res://assets/models/submarine.glb")
const DEPTH := 3.2
const TRANSITION := 1.0

var state: SubState = SubState.SUBMERGED
var _state_t: float = 0.0
var _fired: bool = false


func _init() -> void:
	configure(MODEL, Tuning.SUB_HP, Tuning.SUB_SPEED, 2.5, 0.5, 1.8)
	explosion_strength = 1.0
	collision_radius = 1.0
	half_length = 7.0


func _ready() -> void:
	super._ready()
	_state_t = _rng.randf_range(2.0, Tuning.SUB_SUBMERGED_TIME)


func set_state(s: SubState) -> void:
	state = s
	_state_t = 0.0
	_fired = false
	if s == SubState.SURFACING and _ocean:
		_ocean.add_ring(global_position, 0.6)


func can_be_hit() -> bool:
	return not dying and state == SubState.SURFACED


func _sink_offset() -> float:
	match state:
		SubState.SUBMERGED:
			return DEPTH
		SubState.SURFACING:
			return DEPTH * (1.0 - clampf(_state_t / TRANSITION, 0.0, 1.0))
		SubState.DIVING:
			return DEPTH * clampf(_state_t / TRANSITION, 0.0, 1.0)
	return 0.0


func _ai(delta: float) -> void:
	_state_t += delta
	match state:
		SubState.SUBMERGED:
			throttle = 1.0
			if target_alive():
				# reposition to a flank of the target
				var tp := target_pos2()
				var rel := motion.position - tp
				var ang := atan2(rel.y, rel.x) + 0.6
				steer_to(tp + Vector2(cos(ang), sin(ang)) * Tuning.SUB_ATTACK_DIST)
			if _state_t >= Tuning.SUB_SUBMERGED_TIME:
				set_state(SubState.SURFACING)
		SubState.SURFACING:
			throttle = 0.2
			if _state_t >= TRANSITION:
				set_state(SubState.SURFACED)
		SubState.SURFACED:
			throttle = 0.2
			if target_alive():
				steer_to(target_pos2(), 1.5)
				if not _fired and _state_t >= 1.0:
					_fired = true
					_launch()
			if _state_t >= Tuning.SUB_SURFACED_TIME:
				set_state(SubState.DIVING)
		SubState.DIVING:
			throttle = 0.6
			if _state_t >= TRANSITION:
				set_state(SubState.SUBMERGED)


func _launch() -> void:
	var tube := model.find_child("Tube") as Node3D
	var from := tube.global_position if tube else global_position
	var to := lead_point(Tuning.TORPEDO_SPEED) - from
	if to.length() > Tuning.SUB_RANGE:
		return
	var t := Torpedo.new()
	t.blockers = blockers
	get_parent().add_child(t)
	t.setup(from, to, target)
