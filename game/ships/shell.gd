class_name Shell
extends Node3D
## Artillery shell on a ballistic arc. A red ring marks the impact point for the whole flight.

const RING_SHADER := preload("res://fx/ring.gdshader")
const BLAST_RADIUS := 5.0
const APEX := 25.0

var from: Vector3
var to: Vector3
var flight_time: float = 1.8
var damage: float = 20.0
var target: Node3D

var _t: float = 0.0
var _done: bool = false
var _ball: MeshInstance3D
var _marker: MeshInstance3D
var _trail: GPUParticles3D


func setup(p_from: Vector3, p_to: Vector3, p_flight: float, p_damage: float, p_target: Node3D) -> void:
	from = p_from
	to = Vector3(p_to.x, 0.0, p_to.z)
	flight_time = p_flight
	damage = p_damage
	target = p_target
	if is_inside_tree() and has_node(^"/root/Sfx"):
		Sfx.play(&"shell_whistle", to, -4.0)


func _ready() -> void:
	top_level = true
	_ball = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.35
	sm.height = 0.7
	_ball.mesh = sm
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.albedo_color = Color(6.0, 2.2, 0.8)
	_ball.material_override = bm
	add_child(_ball)
	_marker = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(BLAST_RADIUS * 2.0, BLAST_RADIUS * 2.0)
	q.orientation = PlaneMesh.FACE_Y
	_marker.mesh = q
	var rm := ShaderMaterial.new()
	rm.shader = RING_SHADER
	rm.set_shader_parameter("color", Color("#ff3b3b"))
	rm.set_shader_parameter("intensity", 2.5)
	_marker.material_override = rm
	_marker.top_level = true
	add_child(_marker)
	_marker.global_position = to + Vector3(0, 0.6, 0)
	var pm := ParticleProcessMaterial.new()
	pm.gravity = Vector3.ZERO
	pm.color_ramp = FxUtil.ramp([Color(3.0, 1.2, 0.5, 0.8), Color(0.4, 0.4, 0.45, 0.0)], PackedFloat32Array([0.0, 1.0]))
	_trail = GPUParticles3D.new()
	_trail.amount = 50
	_trail.lifetime = 0.5
	_trail.local_coords = false
	_trail.process_material = pm
	_trail.draw_pass_1 = FxUtil.quad(0.6, true)
	_trail.visibility_aabb = AABB(Vector3(-100, -10, -100), Vector3(200, 60, 200))
	_ball.add_child(_trail)


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	var k := clampf(_t / flight_time, 0.0, 1.0) if flight_time > 0.0 else 1.0
	var p := from.lerp(to, k)
	p.y += APEX * 4.0 * k * (1.0 - k)
	global_position = p
	if _marker.is_inside_tree():
		_marker.global_position = to + Vector3(0, 0.6, 0)
		var pulse := 0.6 + 0.4 * sin(_t * 18.0)
		(_marker.material_override as ShaderMaterial).set_shader_parameter("opacity", (0.4 + 0.6 * k) * pulse)
	if k >= 1.0:
		_impact()


func _impact() -> void:
	_done = true
	if target and is_instance_valid(target) and target.call(&"can_be_hit"):
		var d := Vector2(target.global_position.x - to.x, target.global_position.z - to.z).length()
		if d <= BLAST_RADIUS:
			target.call(&"apply_damage", damage)
	if is_inside_tree():
		var ocean := get_tree().get_first_node_in_group(&"ocean") as Ocean
		if ocean:
			ocean.add_ring(to, 0.5)
		var ex := get_tree().get_first_node_in_group(&"explosions") as ExplosionFx
		if ex:
			ex.play(to, 0.5, true)
		if has_node(^"/root/Sfx"):
			Sfx.play(&"splash", to, -2.0)
	queue_free()
