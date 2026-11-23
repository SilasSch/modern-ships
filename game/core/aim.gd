class_name Aim
extends RefCounted
## Lead calculation for a straight, constant-speed projectile.


## Point where a projectile fired now from shooter meets the target, or null if it can't.
static func intercept(shooter: Vector2, target: Vector2, target_vel: Vector2, speed: float) -> Variant:
	var rel := target - shooter
	var a := target_vel.dot(target_vel) - speed * speed
	var b := 2.0 * rel.dot(target_vel)
	var c := rel.dot(rel)
	var t := -1.0
	if absf(a) < 1e-6:
		if absf(b) > 1e-6:
			t = -c / b
	else:
		var disc := b * b - 4.0 * a * c
		if disc < 0.0:
			return null
		var sq := sqrt(disc)
		var t1 := (-b - sq) / (2.0 * a)
		var t2 := (-b + sq) / (2.0 * a)
		t = minf(t1, t2) if minf(t1, t2) > 0.0 else maxf(t1, t2)
	if t <= 0.0:
		return null if c > 0.0 else target
	return target + target_vel * t
