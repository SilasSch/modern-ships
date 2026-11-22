extends RefCounted
## Minimal beam target for tests (duck-typed like enemies).

var center: Vector2
var radius: float
var hittable: bool = true


func _init(c: Vector2, r: float = 2.0, can_hit: bool = true) -> void:
	center = c
	radius = r
	hittable = can_hit


func get_hit_center() -> Vector2:
	return center


func get_hit_radius() -> float:
	return radius


func can_be_hit() -> bool:
	return hittable
