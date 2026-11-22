class_name Ocean
extends MeshInstance3D
## Storm ocean surface. Owns transient water effects (rings, beam trench, charge ripples).

const SIZE := 420.0
const SUBDIV := 300
const SHADER := preload("res://world/ocean.gdshader")

@export var wave_amp: float = 1.55
## The surface re-centres under this node (snapped to the grid, so waves stay put in world space).
@export var follow: Node3D

var effects := OceanEffects.new()
var time: float = 0.0

var _beam_from := Vector2.ZERO
var _beam_to := Vector2(0.01, 0.0)
var _beam_glow: float = 0.0
var _wakes := PackedVector4Array([Vector4(), Vector4(), Vector4(), Vector4(), Vector4(), Vector4(), Vector4(), Vector4()])


func _init() -> void:
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


## CPU mirror of the shader wave sum (for buoyancy).
static func wave_height(x: float, z: float, t: float, amp: float) -> float:
	var h := 0.0
	h += sin(0.13 * x + 0.05 * z + t * 1.05) * 0.32
	h += sin(-0.06 * x + 0.17 * z + t * 0.85) * 0.24
	h += sin(0.33 * x + 0.21 * z + t * 1.7) * 0.08
	h += sin(-0.29 * x + 0.43 * z + t * 2.2) * 0.05
	h += sin(0.61 * x - 0.37 * z + t * 3.1) * 0.025
	return h * amp


func height_at(x: float, z: float) -> float:
	return wave_height(x, z, time, wave_amp)


func add_ring(pos: Vector3, strength: float) -> void:
	effects.add_ring(Vector2(pos.x, pos.z), strength)


func add_trench(from: Vector3, to: Vector3, width: float) -> void:
	effects.add_trench(Vector2(from.x, from.z), Vector2(to.x, to.z), width)


func set_charge(pos: Vector3, amount: float) -> void:
	effects.set_charge(Vector2(pos.x, pos.z), amount)


func set_beam_glow(from: Vector3, to: Vector3, amount: float) -> void:
	_beam_from = Vector2(from.x, from.z)
	_beam_to = Vector2(to.x, to.z)
	_beam_glow = amount


## Kelvin wake behind a moving ship. slot 0..7; speed 0 disables.
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
	mat.set_shader_parameter("rings", effects.ring_data())
	mat.set_shader_parameter("trenches", effects.trench_data())
	mat.set_shader_parameter("trench_meta", effects.trench_meta())
	mat.set_shader_parameter("charge", Vector3(effects.charge_pos.x, effects.charge_pos.y, effects.charge_amount))
	mat.set_shader_parameter("beam_glow_line", Vector4(_beam_from.x, _beam_from.y, _beam_to.x, _beam_to.y))
	mat.set_shader_parameter("beam_glow", _beam_glow)
	mat.set_shader_parameter("wakes", _wakes)
