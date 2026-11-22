class_name TurretAim
extends RefCounted
## Turret yaw relative to the hull (0 = bow, + = left). Limited traverse rate and arc;
## never swings through the aft dead zone because the angle stays inside ±TURRET_ARC.

var angle: float = 0.0


func step(target_world_yaw: float, hull_heading: float, dt: float) -> void:
	var desired := wrapf(target_world_yaw - hull_heading, -PI, PI)
	desired = clampf(desired, -Tuning.TURRET_ARC, Tuning.TURRET_ARC)
	angle = move_toward(angle, desired, Tuning.TRAVERSE_RATE * dt)


func world_yaw(hull_heading: float) -> float:
	return hull_heading + angle
