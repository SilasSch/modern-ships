class_name BeamHit
extends RefCounted
## Piercing straight-line hit test on the XZ plane.
## Targets are duck-typed: get_hit_center() -> Vector2, get_hit_radius() -> float, can_be_hit() -> bool.
## Blockers are { "center": Vector2, "radius": float } circles (islands); the first one cuts the beam.


static func cast(origin: Vector2, dir: Vector2, max_range: float, half_width: float, targets: Array, blockers: Array) -> Dictionary:
	var d := dir.normalized()
	var end_distance := max_range
	for b: Dictionary in blockers:
		var entry := _ray_circle_entry(origin, d, b["center"], float(b["radius"]))
		if entry >= 0.0 and entry < end_distance:
			end_distance = entry
	var hits: Array = []
	for t: Object in targets:
		if not t.can_be_hit():
			continue
		var reach := float(t.get_hit_radius()) + half_width
		if t.has_method(&"get_hit_segment"):
			var seg: PackedVector2Array = t.call(&"get_hit_segment")
			var r := _segment_to_ray(origin, d, end_distance, seg[0], seg[1])
			if r.x <= reach:
				hits.append({"target": t, "distance": r.y})
			continue
		var rel: Vector2 = t.get_hit_center() - origin
		var along := rel.dot(d)
		if along < 0.0 or along > end_distance:
			continue
		var perp := absf(rel.cross(d))
		if perp <= reach:
			hits.append({"target": t, "distance": along})
	hits.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["distance"] < b["distance"])
	return {"end_distance": end_distance, "hits": hits}


## Closest approach between the ray segment [origin, origin + d*len] and segment [a, b].
## Returns Vector2(distance, along-the-ray distance of the closest point).
static func _segment_to_ray(origin: Vector2, d: Vector2, len: float, a: Vector2, b: Vector2) -> Vector2:
	var best := Vector2(INF, 0.0)
	var ray_end := origin + d * len
	var ab := b - a
	var denom := d.cross(ab)
	if absf(denom) > 1e-6:
		var t := (a - origin).cross(ab) / denom
		var u := (a - origin).cross(d) / denom
		if t >= 0.0 and t <= len and u >= 0.0 and u <= 1.0:
			return Vector2(0.0, t)
	for p: Vector2 in [a, b]:
		var along := clampf((p - origin).dot(d), 0.0, len)
		var dist := p.distance_to(origin + d * along)
		if dist < best.x:
			best = Vector2(dist, along)
	for q: Vector2 in [origin, ray_end]:
		var s := clampf((q - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
		var dist := q.distance_to(a + ab * s)
		if dist < best.x:
			best = Vector2(dist, (q - origin).dot(d))
	return best


## Distance along the ray where it enters the circle, or -1 if it misses / starts inside.
static func _ray_circle_entry(origin: Vector2, d: Vector2, center: Vector2, radius: float) -> float:
	var rel := center - origin
	var along := rel.dot(d)
	var perp_sq := rel.length_squared() - along * along
	var r_sq := radius * radius
	if perp_sq > r_sq or along < 0.0:
		return -1.0
	return maxf(0.0, along - sqrt(r_sq - perp_sq))
