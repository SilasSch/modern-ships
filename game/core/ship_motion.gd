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
	_turn_and_move(rudder, dt)


## Heavy-ship drive: speed approaches target_speed with ACCEL (gaining) / BRAKE (losing).
func step_to(target_speed: float, rudder: float, dt: float) -> void:
	var gaining := absf(target_speed) > absf(speed) and signf(target_speed) == signf(speed) or speed == 0.0
	var rate := accel if gaining else Tuning.BRAKE
	speed = move_toward(speed, clampf(target_speed, -max_reverse, max_speed), rate * dt)
	_turn_and_move(clampf(rudder, -1.0, 1.0), dt)


func _turn_and_move(rudder: float, dt: float) -> void:
	var speed_factor := lerpf(Tuning.TURN_MIN_FACTOR, 1.0, clampf(absf(speed) / max_speed, 0.0, 1.0))
	var dir_sign := -1.0 if speed < 0.0 else 1.0
	heading += turn_rate * rudder * speed_factor * dir_sign * dt
	position += forward_of(heading) * speed * dt


## Pushes the hull (sampled along its length) out of circular blockers and the map bounds.
## Glancing contact slides; near head-on contact (> ~37°) stops the ship.
func resolve_blockers(blockers: Array, ship_radius: float, half_length: float = 0.0) -> void:
	var f := forward_of(heading)
	var reach := maxf(0.0, half_length - ship_radius)
	var offsets: Array[float] = [0.0]
	if reach > 0.0:
		offsets = [-reach, -reach * 0.5, 0.0, reach * 0.5, reach]
	for pass_i in 2:
		for b: Dictionary in blockers:
			var center: Vector2 = b["center"]
			var min_dist := float(b["radius"]) + ship_radius
			var push := Vector2.ZERO
			for off: float in offsets:
				var p := position + f * off
				var delta := p - center
				var dist := delta.length()
				if dist < min_dist:
					var n := delta / dist if dist > 0.0001 else -f
					var need := n * (min_dist - dist)
					if need.length() > push.length():
						push = need
			if push != Vector2.ZERO:
				position += push
				_hit_wall(push.normalized(), f)
	var lim := Tuning.MAP_HALF
	if position.x < -lim:
		position.x = -lim
		_hit_wall(Vector2(1, 0), f)
	elif position.x > lim:
		position.x = lim
		_hit_wall(Vector2(-1, 0), f)
	if position.y < -lim:
		position.y = -lim
		_hit_wall(Vector2(0, 1), f)
	elif position.y > lim:
		position.y = lim
		_hit_wall(Vector2(0, -1), f)


## n = wall normal pointing away from the wall.
func _hit_wall(n: Vector2, f: Vector2) -> void:
	var into := f.dot(n) * speed
	if into < 0.0 and absf(f.dot(n)) > 0.8:
		speed = 0.0
