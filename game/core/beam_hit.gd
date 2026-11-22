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
		var rel: Vector2 = t.get_hit_center() - origin
		var along := rel.dot(d)
		if along < 0.0 or along > end_distance:
			continue
		var perp := absf(rel.cross(d))
		if perp <= float(t.get_hit_radius()) + half_width:
			hits.append({"target": t, "distance": along})
	hits.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["distance"] < b["distance"])
	return {"end_distance": end_distance, "hits": hits}


## Distance along the ray where it enters the circle, or -1 if it misses / starts inside.
static func _ray_circle_entry(origin: Vector2, d: Vector2, center: Vector2, radius: float) -> float:
	var rel := center - origin
	var along := rel.dot(d)
	var perp_sq := rel.length_squared() - along * along
	var r_sq := radius * radius
	if perp_sq > r_sq or along < 0.0:
		return -1.0
	return maxf(0.0, along - sqrt(r_sq - perp_sq))
