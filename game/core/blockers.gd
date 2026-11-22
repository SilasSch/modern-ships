class_name Blockers
extends RefCounted
## Island circles ({center: Vector2, radius: float}) as cover against lines of fire.


static func segment_blocked(a: Vector2, b: Vector2, blockers: Array) -> bool:
	var ab := b - a
	var len_sq := maxf(ab.length_squared(), 0.0001)
	for bl: Dictionary in blockers:
		var c: Vector2 = bl["center"]
		var t := clampf((c - a).dot(ab) / len_sq, 0.0, 1.0)
		if (a + ab * t).distance_to(c) < float(bl["radius"]):
			return true
	return false
