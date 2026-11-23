class_name ShipControl
extends RefCounted
## World-of-Warships style helm: engine telegraph in 6 steps and rudder in 5 steps.
## Both stay where they are set; the rudder blade swings over slowly.

const LABELS: Array[String] = ["ZURÜCK VOLL", "STOPP", "¼", "½", "¾", "VOLL"]

var telegraph: int = 0        # -1 = back full, 0 = stop, 1..4 = 1/4 .. full
var rudder_setting: int = 0   # -2..2, positive = port (left)
var rudder: float = 0.0       # actual blade position -1..1


func throttle_up() -> void:
	telegraph = mini(telegraph + 1, 4)


func throttle_down() -> void:
	telegraph = maxi(telegraph - 1, -1)


func rudder_left() -> void:
	rudder_setting = mini(rudder_setting + 1, 2)


func rudder_right() -> void:
	rudder_setting = maxi(rudder_setting - 1, -2)


func target_speed(max_speed: float, max_reverse: float) -> float:
	if telegraph < 0:
		return -max_reverse
	return max_speed * telegraph / 4.0


func tick(dt: float) -> void:
	rudder = move_toward(rudder, rudder_setting / 2.0, dt / Tuning.RUDDER_SHIFT_TIME)


func telegraph_label() -> String:
	return LABELS[telegraph + 1]
