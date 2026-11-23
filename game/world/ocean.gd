class_name Ocean
extends MeshInstance3D
## Storm ocean surface. Owns transient water effects (rings, beam trench, charge ripples).

const SIZE := 520.0
const FAR_SIZE := 2400.0
const FAR_SUBDIV := 160
const SUBDIV := 300
const SHADER := preload("res://world/ocean.gdshader")
const WAKE_SLOTS := 16

@export var wave_amp: float = 1.55
## The surface re-centres under this node (snapped to the grid, so waves stay put in world space).
@export var follow: Node3D

var effects := OceanEffects.new()
var time: float = 0.0

var _beam_from := Vector2.ZERO
var _beam_to := Vector2(0.01, 0.0)
var _beam_glow: float = 0.0
var _wakes := PackedVector4Array()
var _wake_used: Array[bool] = []


func _init() -> void:
	_wakes.resize(WAKE_SLOTS)
	_wake_used.resize(WAKE_SLOTS)
	_wake_used[0] = true  # player
	add_to_group(&"ocean")
	var plane := PlaneMesh.new()
	plane.size = Vector2(SIZE, SIZE)
	plane.subdivide_width = SUBDIV
	plane.subdivide_depth = SUBDIV
	mesh = plane
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	material_override = mat
	custom_aabb = AABB(Vector3(-SIZE / 2.0, -6.0, -SIZE / 2.0), Vector3(SIZE, 12.0, SIZE))
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Coarse far ring: same shader, big waves only, no effects, cut out where the near plane is.
	var far := MeshInstance3D.new()
	far.name = "FarOcean"
	var fp := PlaneMesh.new()
	fp.size = Vector2(FAR_SIZE, FAR_SIZE)
	fp.subdivide_width = FAR_SUBDIV
	fp.subdivide_depth = FAR_SUBDIV
	far.mesh = fp
	var fmat := ShaderMaterial.new()
	fmat.shader = SHADER
	fmat.set_shader_parameter("far_lod", true)
	fmat.set_shader_parameter("cut_inner", SIZE * 0.5 - 6.0)
	far.material_override = fmat
	far.custom_aabb = AABB(Vector3(-FAR_SIZE / 2.0, -6.0, -FAR_SIZE / 2.0), Vector3(FAR_SIZE, 12.0, FAR_SIZE))
	far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(far)


## CPU mirror of the shader wave sum (for buoyancy).
static func wave_height(x: float, z: float, t: float, amp: float, detail: float = 1.0) -> float:
	var wx := x + sin(z * 0.013 + t * 0.1) * 9.0
	var wz := z + sin(x * 0.011 - t * 0.08) * 9.0
	var px := wx + sin(wz * 0.031 + t * 0.2) * 2.0
	var pz := wz + sin(wx * 0.027 - t * 0.17) * 2.0
	var h := 0.0
	h += sin(0.1052 * px + 0.0322 * pz + t * 1.0) * 0.27
	h += sin(-0.0661 * px + 0.0535 * pz + t * 0.85) * 0.23
	h += sin(0.0441 * px + 0.1538 * pz + t * 1.25) * 0.1
	h += detail * sin(-0.3038 * px + -0.1289 * pz + t * 1.7) * 0.065
	h += detail * sin(0.2491 * px + -0.3986 * pz + t * 2.2) * 0.035
	h += detail * sin(-0.2312 * px + -0.6713 * pz + t * 3.1) * 0.02
	return h * amp


func height_at(x: float, z: float) -> float:
	return wave_height(x, z, time, wave_amp)


func add_ring(pos: Vector3, strength: float) -> void:
	effects.add_ring(Vector2(pos.x, pos.z), strength)


func add_trench(from: Vector3, to: Vector3, width: float, speed: float = 0.0) -> void:
	effects.add_trench(Vector2(from.x, from.z), Vector2(to.x, to.z), width, speed)


func set_charge(pos: Vector3, amount: float) -> void:
	effects.set_charge(Vector2(pos.x, pos.z), amount)


func set_beam_glow(from: Vector3, to: Vector3, amount: float) -> void:
	_beam_from = Vector2(from.x, from.z)
	_beam_to = Vector2(to.x, to.z)
	_beam_glow = amount


## Reserves a wake slot for an enemy (slot 0 is the player's). Returns -1 when all are taken.
func acquire_wake() -> int:
	for i in range(1, WAKE_SLOTS):
		if not _wake_used[i]:
			_wake_used[i] = true
			return i
	return -1


func release_wake(slot: int) -> void:
	if slot > 0 and slot < WAKE_SLOTS:
		_wake_used[slot] = false
		_wakes[slot] = Vector4()


## Kelvin wake behind a moving ship. slot 0..WAKE_SLOTS-1; speed 0 disables.
func set_wake(slot: int, pos: Vector3, heading: float, speed: float) -> void:
	_wakes[slot] = Vector4(pos.x, pos.z, heading, speed)


func _process(delta: float) -> void:
	time += delta
	if follow and is_instance_valid(follow):
		var step := SIZE / SUBDIV
		global_position = Vector3(snappedf(follow.global_position.x, step), 0.0, snappedf(follow.global_position.z, step))
	effects.tick(delta)
	var mat := material_override as ShaderMaterial
	mat.set_shader_parameter("u_time", time)
	mat.set_shader_parameter("wave_amp", wave_amp)
	var fmat := (get_node(^"FarOcean") as MeshInstance3D).material_override as ShaderMaterial
	fmat.set_shader_parameter("u_time", time)
	fmat.set_shader_parameter("wave_amp", wave_amp)
	fmat.set_shader_parameter("cut_center", Vector2(global_position.x, global_position.z))
	mat.set_shader_parameter("rings", effects.ring_data())
	mat.set_shader_parameter("trenches", effects.trench_data())
	mat.set_shader_parameter("trench_meta", effects.trench_meta())
	mat.set_shader_parameter("charge", Vector3(effects.charge_pos.x, effects.charge_pos.y, effects.charge_amount))
	mat.set_shader_parameter("beam_glow_line", Vector4(_beam_from.x, _beam_from.y, _beam_to.x, _beam_to.y))
	mat.set_shader_parameter("beam_glow", _beam_glow)
	mat.set_shader_parameter("wakes", _wakes)
