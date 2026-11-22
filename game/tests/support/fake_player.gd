extends Node3D
## Minimal damage receiver for projectile tests.

var damage_taken: float = 0.0


func apply_damage(amount: float) -> void:
	damage_taken += amount


func can_be_hit() -> bool:
	return true
