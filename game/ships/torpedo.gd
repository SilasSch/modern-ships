class_name Torpedo
extends Node3D
## Straight-running torpedo with a visible bubble track. Explodes near the target.

const HIT_DIST := 4.0
const LIFETIME := 9.0

var dir := Vector3.FORWARD
var target: Node3D
var _t: float = 0.0
var _done: bool = false
var _trail: GPUParticles3D


func setup(p_from: Vector3, p_dir: Vector3, p_target: Node3D) -> void:
	global_position = Vector3(p_from.x, -0.3, p_from.z)
	dir = Vector3(p_dir.x, 0, p_dir.z).normalized()
	target = p_target


func _ready() -> void:
	top_level = true
	var head := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.25
	cm.height = 1.6
	head.mesh = cm
	head.rotation.x = PI / 2.0
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("#1a1d22")
	m.emission_enabled = true
	m.emission = Color("#ff3b3b")
	m.emission_energy_multiplier = 1.5
	head.material_override = m
	add_child(head)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.4
	pm.gravity = Vector3(0, 0.6, 0)
	pm.scale_curve = FxUtil.curve([Vector2(0, 0.5), Vector2(1, 1.6)])
	pm.color_ramp = FxUtil.ramp([Color(0.8, 0.9, 1.0, 0.8), Color(0.6, 0.75, 0.85, 0.0)], PackedFloat32Array([0.0, 1.0]))
	_trail = GPUParticles3D.new()
	_trail.amount = 90
	_trail.lifetime = 2.5
	_trail.local_coords = false
	_trail.process_material = pm
	_trail.draw_pass_1 = FxUtil.quad(0.9, false)
	_trail.visibility_aabb = AABB(Vector3(-100, -5, -100), Vector3(200, 20, 200))
	_trail.position = Vector3(0, 0.5, 0)
	add_child(_trail)
	if has_node(^"/root/Sfx"):
		Sfx.play(&"torpedo", global_position, 0.0)


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	global_position += dir * Tuning.TORPEDO_SPEED * delta
	if dir != Vector3.ZERO and is_inside_tree():
		look_at(global_position + dir, Vector3.UP)
	if target and is_instance_valid(target) and target.call(&"can_be_hit"):
		var d := Vector2(target.global_position.x - global_position.x, target.global_position.z - global_position.z).length()
		if d < HIT_DIST:
			target.call(&"apply_damage", Tuning.TORPEDO_DMG)
			_explode()
			return
	if _t > LIFETIME:
		queue_free()


func _explode() -> void:
	_done = true
	if is_inside_tree():
		var ex := get_tree().get_first_node_in_group(&"explosions") as ExplosionFx
		if ex:
			ex.play(global_position, 0.9)
	queue_free()
