class_name Destroyer
extends Frigate
## Enemy destroyer: faster, closes to 220–350 m, light gun salvos and a torpedo fan every ~18 s.

const DESTROYER_MODEL := preload("res://assets/models/enemy_destroyer.glb")

var _torp_t: float = 8.0


func _setup_kind() -> void:
	configure(DESTROYER_MODEL, Tuning.DESTROYER_HP, Tuning.DESTROYER_SPEED, 2.5, 0.5, 5.0)
	explosion_strength = 1.4
	collision_radius = 1.8
	half_length = 11.0
	standoff_min = Tuning.DESTROYER_STANDOFF_MIN
	standoff_max = Tuning.DESTROYER_STANDOFF_MAX
	salvo_interval = Tuning.DESTROYER_GUN_INTERVAL
	fire_range = Tuning.DESTROYER_RANGE


func _fire_salvo() -> void:
	fire_salvo(Tuning.DESTROYER_GUN_SALVO, Tuning.DESTROYER_GUN_DMG, 8.0)


func _gun_count() -> int:
	return 2


func _ai(delta: float) -> void:
	super._ai(delta)
	if not target_alive():
		return
	_torp_t -= delta
	var dist := Vector2(target.global_position.x - global_position.x, target.global_position.z - global_position.z).length()
	if _torp_t <= 0.0 and dist < Tuning.DESTROYER_TORP_RANGE:
		_torp_t = Tuning.DESTROYER_TORP_INTERVAL
		launch_fan(3, 12.0)


## Torpedo fan toward the target: count torpedoes spread over ±spread_deg.
func launch_fan(count: int, spread_deg: float) -> void:
	var tubes := [model.find_child("Torp_L") as Node3D, model.find_child("Torp_R") as Node3D]
	var to := target.global_position - global_position
	var base_yaw := atan2(to.x, to.z)
	for i in count:
		var k := 0.0 if count == 1 else (float(i) / (count - 1)) * 2.0 - 1.0
		var yaw := base_yaw + deg_to_rad(spread_deg) * k
		var tube: Node3D = tubes[i % 2]
		var from := tube.global_position if tube else global_position
		var t := Torpedo.new()
		t.blockers = blockers
		get_parent().add_child(t)
		t.setup(from, Vector3(sin(yaw), 0, cos(yaw)), target)
