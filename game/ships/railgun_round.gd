class_name RailgunRound
extends Node3D
## A railgun round in flight: white-hot slug with a plasma streak, a fading ionised path,
## a travelling light and plasma sparks. Hit resolution via ProjectileSim; driven by Battle.step().

const TRACER := preload("res://fx/tracer.gdshader")
const CORE := Color("#e9fbff")
const CYAN := Color("#4de8ff")
const STREAK_LEN := 28.0
const HAZE := Color(0.55, 0.62, 0.7)

var sim: ProjectileSim
var origin: Vector3
var dir: Vector3
var overcharge: float = 0.0
var half_width: float = 1.2
var blockers: Array = []
var targets_provider: Callable

var _height: float
var _t: float = 0.0
var _done_t: float = -1.0
var _streak: MeshInstance3D
var _path: MeshInstance3D
var _head: MeshInstance3D
var _light: OmniLight3D
var _sparks: GPUParticles3D
var _ocean: Ocean
var _ex: ExplosionFx


func setup(p_origin: Vector3, p_dir: Vector3, shot: RailgunShot, p_targets: Callable, p_blockers: Array) -> void:
	origin = p_origin
	dir = Vector3(p_dir.x, 0.0, p_dir.z).normalized()
	overcharge = shot.overcharge
	half_width = shot.half_width
	targets_provider = p_targets
	blockers = p_blockers
	_height = p_origin.y
	sim = ProjectileSim.new(Vector2(origin.x, origin.z), Vector2(dir.x, dir.z), Tuning.PROJECTILE_SPEED,
		Tuning.PROJECTILE_RANGE, shot.damage, shot.pierce)


func _ready() -> void:
	top_level = true
	_ocean = get_tree().get_first_node_in_group(&"ocean") as Ocean
	_ex = get_tree().get_first_node_in_group(&"explosions") as ExplosionFx
	var k := 1.0 + overcharge
	_streak = _cylinder(1.4, 1.0)
	_path = _cylinder(2.0, 0.0)
	var hm := SphereMesh.new()
	hm.radius = 0.45 * k
	hm.height = 0.9 * k
	_head = MeshInstance3D.new()
	_head.mesh = hm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = CORE * 14.0
	_head.material_override = mat
	add_child(_head)
	_light = OmniLight3D.new()
	_light.light_color = CORE.lerp(CYAN, 0.5)
	_light.light_energy = 10.0 * k
	_light.omni_range = 28.0
	_light.light_volumetric_fog_energy = 4.0
	add_child(_light)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.3, 0.3, 5.0)
	pm.direction = Vector3.UP
	pm.spread = 180.0
	pm.initial_velocity_min = 1.0
	pm.initial_velocity_max = 5.0
	pm.gravity = Vector3(0, -2.0, 0)
	pm.damping_min = 2.0
	pm.damping_max = 3.0
	pm.color_ramp = FxUtil.ramp([CORE * 4.0, CYAN * 2.0, Color(0.2, 0.5, 0.7, 0.0)], PackedFloat32Array([0.0, 0.3, 1.0]))
	_sparks = GPUParticles3D.new()
	_sparks.amount = roundi(500 * Settings.particle_scale())
	_sparks.lifetime = 0.9
	_sparks.local_coords = false
	_sparks.process_material = pm
	_sparks.draw_pass_1 = FxUtil.quad(0.35 * k, true)
	_sparks.visibility_aabb = AABB(Vector3(-20, -10, -20), Vector3(40, 30, 40))
	add_child(_sparks)
	_place(Vector3(origin.x, _height, origin.z))
	if has_node(^"/root/Sfx"):
		Sfx.play(&"projectile_whoosh", origin, 0.0)


func _cylinder(power: float, tail_fade: float) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = 1.0
	cm.bottom_radius = 1.0
	cm.height = 1.0
	cm.radial_segments = 16
	cm.rings = 1
	cm.cap_top = false
	cm.cap_bottom = false
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	var m := ShaderMaterial.new()
	m.shader = TRACER
	m.set_shader_parameter("power", power)
	m.set_shader_parameter("tail_fade", tail_fade)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


## Orients a unit cylinder (Y axis) from a to b.
func _span(mi: MeshInstance3D, a: Vector3, b: Vector3, radius: float) -> void:
	var len := maxf(a.distance_to(b), 0.01)
	var y := (b - a) / len
	var x := y.cross(Vector3.UP).normalized() if absf(y.y) < 0.99 else Vector3.RIGHT
	var z := x.cross(y)
	mi.global_transform = Transform3D(Basis(x * radius, y * len, z * radius), (a + b) * 0.5)


func _place(head: Vector3) -> void:
	var k := 1.0 + overcharge
	_head.global_position = head
	_light.global_position = head
	var start := Vector3(origin.x, _height, origin.z)
	var tail := head - dir * minf(STREAK_LEN, head.distance_to(start))
	_span(_streak, tail, head, 0.28 * k)
	_span(_path, start, head, 0.9 * k)


func _process(_delta: float) -> void:
	pass  # Battle drives step() so hits are deterministic.


## Advances the round. Returns false once it can be freed.
func step(delta: float) -> bool:
	_t += delta
	var k := 1.0 + overcharge
	if not sim.done:
		var from := sim.position
		var targets: Array = targets_provider.call() if targets_provider.is_valid() else []
		for h: Dictionary in sim.advance(delta, targets, blockers, half_width):
			_hit(h)
		var head := Vector3(sim.position.x, _height, sim.position.y)
		_place(head)
		var seg := (sim.position - from)
		_sparks.global_transform = Transform3D(Basis.looking_at(dir, Vector3.UP), Vector3((from.x + sim.position.x) * 0.5, _height, (from.y + sim.position.y) * 0.5))
		(_sparks.process_material as ParticleProcessMaterial).emission_box_extents = Vector3(0.3, 0.3, maxf(seg.length() * 0.5, 0.5))
		_sparks.emitting = true
		if sim.done:
			_finish()
	else:
		_done_t += delta
	var path_op := maxf(0.0, 1.0 - _t / 0.9)
	_set_tracer(_path, HAZE, 0.22 * k, path_op * path_op)
	var streak_op := 1.0 if not sim.done else maxf(0.0, 1.0 - _done_t / 0.12)
	_set_tracer(_streak, CORE.lerp(Color(1.0, 0.8, 0.55), 0.3), 9.0 * k, streak_op)
	if _ocean:
		var head2 := Vector3(sim.position.x, 0.0, sim.position.y)
		var glow := (0.5 * k) if not sim.done else 0.0
		_ocean.set_beam_glow(head2 - dir * 30.0, head2, glow)
	return _done_t < 1.4


func _set_tracer(mi: MeshInstance3D, color: Color, intensity: float, opacity: float) -> void:
	var m := mi.material_override as ShaderMaterial
	m.set_shader_parameter("color", color)
	m.set_shader_parameter("intensity", intensity)
	m.set_shader_parameter("opacity", opacity)


func _hit(h: Dictionary) -> void:
	var target: Object = h["target"]
	var p2: Vector2 = h["point"]
	var p := Vector3(p2.x, _height - 0.5, p2.y)
	if is_instance_valid(target) and target.has_method(&"apply_damage"):
		target.call(&"apply_damage", float(h["damage"]), dir)
	if _ex:
		_ex.exit_spray(p, dir, 1.0 + overcharge)
	if has_node(^"/root/Feel"):
		Feel.impact(0.8 + overcharge * 0.4, p)
	if has_node(^"/root/Sfx"):
		Sfx.play(&"impact", p, 2.0)


func _finish() -> void:
	_done_t = 0.0
	_head.visible = false
	_light.visible = false
	_sparks.emitting = false
	var end := Vector3(sim.stop_point.x, 0.0, sim.stop_point.y)
	if _ex == null:
		return
	if sim.travelled >= Tuning.PROJECTILE_RANGE - 1.0:
		_ex.play(end, 0.6, true)
	elif _hit_island():
		_ex.play(end + Vector3(0, 2.0, 0), 0.9)


func _hit_island() -> bool:
	for b: Dictionary in blockers:
		if sim.stop_point.distance_to(b["center"]) <= float(b["radius"]) + 1.0:
			return true
	return false
