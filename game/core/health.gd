class_name Health
extends RefCounted
## Hit points with a single death event.

var hp: float
var max_hp: float


func _init(max_value: float) -> void:
	max_hp = max_value
	hp = max_value


## Applies damage. Returns true only for the hit that kills.
func damage(amount: float) -> bool:
	if is_dead():
		return false
	hp = maxf(0.0, hp - amount)
	return hp <= 0.0


func is_dead() -> bool:
	return hp <= 0.0


func fraction() -> float:
	return hp / max_hp if max_hp > 0.0 else 0.0
