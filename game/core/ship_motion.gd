class_name ShipMotion
extends RefCounted
## Inertial ship movement on the XZ plane (Vector2(x, z)).
## heading = rotation.y; forward = Vector2(-sin h, -cos h). rudder +1 turns left.

var position: Vector2 = Vector2.ZERO
var heading: float = 0.0
var speed: float = 0.0

var max_speed: float
var max_reverse: float
var accel: float
var turn_rate: float


func _init(p_max_speed: float, p_max_reverse: float, p_accel: float, p_turn_rate: float) -> void:
	max_speed = p_max_speed
	max_reverse = p_max_reverse
	accel = p_accel
	turn_rate = p_turn_rate


static func forward_of(yaw: float) -> Vector2:
	return Vector2(-sin(yaw), -cos(yaw))


static func yaw_of(dir: Vector2) -> float:
	return atan2(-dir.x, -dir.y)


func step(throttle: float, rudder: float, dt: float) -> void:
	throttle = clampf(throttle, -1.0, 1.0)
	rudder = clampf(rudder, -1.0, 1.0)
	if throttle > 0.0:
		speed = minf(max_speed, speed + accel * throttle * dt)
	elif throttle < 0.0:
		if speed > 0.0:
			speed = maxf(0.0, speed - Tuning.BRAKE * -throttle * dt)
		else:
			speed = maxf(-max_reverse, speed - accel * -throttle * dt)
	else:
		speed -= speed * Tuning.WATER_DRAG * dt
	var speed_factor := lerpf(Tuning.TURN_MIN_FACTOR, 1.0, clampf(absf(speed) / max_speed, 0.0, 1.0))
	var dir_sign := -1.0 if speed < 0.0 else 1.0
	heading += turn_rate * rudder * speed_factor * dir_sign * dt
	position += forward_of(heading) * speed * dt


## Pushes the ship out of circular blockers and the map bounds, removing speed into the wall.
func resolve_blockers(blockers: Array, ship_radius: float) -> void:
	for b: Dictionary in blockers:
		var center: Vector2 = b["center"]
		var min_dist := float(b["radius"]) + ship_radius
		var delta := position - center
		var dist := delta.length()
		if dist >= min_dist:
			continue
		var n := delta / dist if dist > 0.0001 else Vector2.UP
		position = center + n * min_dist
		var into := forward_of(heading).dot(n) * speed
		if into < 0.0:
			speed *= 1.0 - absf(forward_of(heading).dot(n))
	var clamped := position.clamp(Vector2(-Tuning.MAP_HALF, -Tuning.MAP_HALF), Vector2(Tuning.MAP_HALF, Tuning.MAP_HALF))
	if clamped != position:
		position = clamped
		speed *= 0.5
