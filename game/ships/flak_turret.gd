class_name FlakTurret
extends Node3D
## Automatic point-defence gun: engages the nearest small target in range, outside the bow arc.

const BOW_BLOCK := deg_to_rad(30.0)  # ±30° ahead belongs to the railgun -> 300° coverage

var ship: PlayerShip
var _cool: float = 0.0
var _rng := RandomNumberGenerator.new()
var _tracer_mesh := ImmediateMesh.new()
var _tracer: MeshInstance3D
var _tracer_t: float = 0.0
var _shots: int = 0


static func pick_target(origin: Vector3, heading: float, candidates: Array) -> Node3D:
	var best: Node3D = null
	var best_d := Tuning.FLAK_RANGE
	for c: Node3D in candidates:
		if c == null or not is_instance_valid(c):
			continue
		if not c.get(&"is_small") or not c.call(&"can_be_hit"):
			continue
		var rel := Vector2(c.global_position.x - origin.x, c.global_position.z - origin.z)
		var d := rel.length()
		if d > best_d:
			continue
		var rel_angle := wrapf(ShipMotion.yaw_of(rel) - heading, -PI, PI)
		if absf(rel_angle) < BOW_BLOCK:
			continue
		best = c
		best_d = d
	return best


func _ready() -> void:
	_rng.seed = 99
	_tracer = MeshInstance3D.new()
	_tracer.mesh = _tracer_mesh
	_tracer.top_level = true
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(4.0, 3.2, 1.6)
	_tracer.material_override = m
	add_child(_tracer)


func _process(delta: float) -> void:
	if ship == null or ship.health.is_dead():
		return
	_tracer_t -= delta
	if _tracer_t <= 0.0:
		_tracer_mesh.clear_surfaces()
	_cool -= delta
	var target := pick_target(global_position, ship.motion.heading, get_tree().get_nodes_in_group(&"enemies"))
	if target == null:
		return
	var to := target.global_position - global_position
	rotation.y = wrapf(atan2(-to.x, -to.z) - ship.rotation.y, -PI, PI)
	if _cool > 0.0:
		return
	_cool = 1.0 / Tuning.FLAK_RATE
	_shots += 1
	var aim := target.global_position + Vector3(_rng.randf_range(-1.5, 1.5), 0.8, _rng.randf_range(-1.5, 1.5))
	_tracer_mesh.clear_surfaces()
	_tracer_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var from := global_position + Vector3(0, 0.4, 0)
	_tracer_mesh.surface_add_vertex(from.lerp(aim, 0.15))
	_tracer_mesh.surface_add_vertex(from.lerp(aim, 0.85))
	_tracer_mesh.surface_end()
	_tracer_t = 0.04
	if _shots % 2 == 0 and has_node(^"/root/Sfx"):
		Sfx.play(&"flak", global_position, -8.0, _rng.randf_range(0.9, 1.1))
	if _rng.randf() < 0.85:
		target.call(&"apply_damage", Tuning.FLAK_DAMAGE, to.normalized())
