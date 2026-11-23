class_name Cruiser
extends Frigate
## Heavy cruiser: slow, holds 400–600 m, fires big six-shell salvos. Needs several railgun hits.

const CRUISER_MODEL := preload("res://assets/models/cruiser.glb")


func _setup_kind() -> void:
	configure(CRUISER_MODEL, Tuning.CRUISER_HP, Tuning.CRUISER_SPEED, 1.2, 0.22, 8.0)
	explosion_strength = 1.9
	collision_radius = 2.8
	half_length = 17.0
	standoff_min = Tuning.CRUISER_STANDOFF_MIN
	standoff_max = Tuning.CRUISER_STANDOFF_MAX
	salvo_interval = Tuning.CRUISER_SALVO_INTERVAL
	fire_range = Tuning.CRUISER_RANGE


func _fire_salvo() -> void:
	fire_salvo(Tuning.CRUISER_SALVO, Tuning.CRUISER_SHELL_DMG, 14.0)


func _gun_count() -> int:
	return 4
