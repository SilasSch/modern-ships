class_name ProjectileSim
extends RefCounted
## Straight railgun round with travel time. Each frame sweeps its path segment, hits up to
## `pierce` targets (damage x PIERCE_FACTOR per further target) and stops at islands or max range.

var position: Vector2
var dir: Vector2
var speed: float
var max_range: float
var damage: float
var pierce: int
var travelled: float = 0.0
var done: bool = false
var stop_point: Vector2

var _hit_ids: Dictionary = {}


func _init(origin: Vector2, p_dir: Vector2, p_speed: float, p_range: float, p_damage: float, p_pierce: int) -> void:
	position = origin
	dir = p_dir.normalized()
	speed = p_speed
	max_range = p_range
	damage = p_damage
	pierce = p_pierce
	stop_point = origin


## Returns this frame's hits: [{target, damage, point: Vector2}].
func advance(dt: float, targets: Array, blockers: Array, half_width: float) -> Array:
	var hits: Array = []
	if done:
		return hits
	var step := minf(speed * dt, max_range - travelled)
	var valid: Array = []
	for t: Variant in targets:
		if t == null or not is_instance_valid(t):
			continue
		if _hit_ids.has((t as Object).get_instance_id()):
			continue
		valid.append(t)
	var res := BeamHit.cast(position, dir, step, half_width, valid, blockers)
	for h: Dictionary in res["hits"]:
		var target: Object = h["target"]
		_hit_ids[target.get_instance_id()] = true
		hits.append({"target": target, "damage": damage, "point": position + dir * float(h["distance"])})
		damage *= Tuning.PIERCE_FACTOR
		if _hit_ids.size() >= pierce:
			done = true
			stop_point = position + dir * float(h["distance"])
			break
	if done:
		return hits
	var blocked := float(res["end_distance"]) < step - 1e-4
	var moved := float(res["end_distance"]) if blocked else step
	position += dir * moved
	travelled += moved
	if blocked or travelled >= max_range - 1e-4:
		done = true
		stop_point = position
	return hits
