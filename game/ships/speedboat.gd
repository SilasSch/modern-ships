class_name Speedboat
extends Enemy
## Fast attack craft: circles the player and strafes with a light gun. Swarm unit, flak's main prey.

const MODEL := preload("res://assets/models/speedboat.glb")

var _orbit_dir: float = 1.0
var _orbit_r: float = 32.0
var _gun_t: float = 0.0
var _tracer: MeshInstance3D
var _tracer_mesh := ImmediateMesh.new()
var _tracer_t: float = 0.0


func _init() -> void:
	configure(MODEL, Tuning.SPEEDBOAT_HP, Tuning.SPEEDBOAT_SPEED, 9.0, 1.7, 2.4)
	is_small = true
	collision_radius = 1.0
	half_length = 3.0
	explosion_strength = 0.6


func _ready() -> void:
	super._ready()
	_orbit_dir = 1.0 if _rng.randf() < 0.5 else -1.0
	_orbit_r = _rng.randf_range(25.0, 40.0)
	_gun_t = _rng.randf_range(0.0, Tuning.SPEEDBOAT_GUN_INTERVAL)
	_tracer = MeshInstance3D.new()
	_tracer.mesh = _tracer_mesh
	_tracer.top_level = true
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(4.0, 1.2, 0.6)
	_tracer.material_override = m
	add_child(_tracer)


func _ai(delta: float) -> void:
	throttle = 1.0
	if not target_alive():
		rudder = 0.3
		return
	var tp := target_pos2()
	var rel := motion.position - tp
	var ang := atan2(rel.y, rel.x) + _orbit_dir * 0.5
	steer_to(tp + Vector2(cos(ang), sin(ang)) * _orbit_r, 2.5)
	_tracer_t -= delta
	if _tracer_t <= 0.0:
		_tracer_mesh.clear_surfaces()
	_gun_t -= delta
	if _gun_t <= 0.0 and rel.length() < Tuning.SPEEDBOAT_RANGE and not Blockers.segment_blocked(motion.position, tp, blockers):
		_gun_t = Tuning.SPEEDBOAT_GUN_INTERVAL
		_shoot()


func _shoot() -> void:
	var from := (model.find_child("Gun") as Node3D).global_position
	var to := target.global_position + Vector3(_rng.randf_range(-2, 2), 1.5, _rng.randf_range(-2, 2))
	_tracer_mesh.clear_surfaces()
	_tracer_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	_tracer_mesh.surface_add_vertex(from)
	_tracer_mesh.surface_add_vertex(from.lerp(to, 0.7))
	_tracer_mesh.surface_end()
	_tracer_t = 0.06
	_sfx(&"enemy_gun", -6.0)
	if _rng.randf() < 0.7:
		target.call(&"apply_damage", Tuning.SPEEDBOAT_GUN_DMG)
