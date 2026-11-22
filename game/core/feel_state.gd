class_name FeelState
extends RefCounted
## Game-feel values driven in real time: screenshake trauma, camera kick, flash, bloom pulse, hitstop.

var trauma: float = 0.0
var kick: float = 0.0
var flash: float = 0.0
var pulse: float = 0.0
var hitstop_left: float = 0.0


func add_shot(overcharge: float) -> void:
	trauma = maxf(trauma, 0.8 + 0.2 * overcharge)
	kick = 1.0
	flash = 1.0
	pulse = 1.0
	hitstop_left = Tuning.HITSTOP * (1.0 + 0.5 * overcharge)


func add_impact(strength: float) -> void:
	trauma = minf(1.0, trauma + 0.5 * strength)
	pulse = minf(1.4, pulse + 0.3 * strength)


## Advances by real (unscaled) time. Returns the sim time scale: 0 during hitstop, else 1.
func tick(real_dt: float) -> float:
	var scale := 1.0
	if hitstop_left > 0.0:
		hitstop_left -= real_dt
		scale = 0.0
	trauma = maxf(0.0, trauma - 1.5 * real_dt)
	kick *= exp(-5.0 * real_dt)
	flash *= exp(-11.0 * real_dt)
	pulse *= exp(-2.6 * real_dt)
	return scale


## Deterministic shake offset scaled by trauma².
func shake_offset(time: float) -> Vector3:
	var t2 := trauma * trauma
	if t2 <= 0.0:
		return Vector3.ZERO
	return Vector3(_n(time, 31.0) * 1.3, _n(time + 3.1, 27.0) * 0.9, _n(time + 7.4, 35.0)) * t2


static func _n(t: float, f: float) -> float:
	return sin(t * f) * 0.6 + sin(t * f * 2.31 + 1.7) * 0.4
