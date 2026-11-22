class_name Weather
extends Node3D
## Rain streaks that follow a target, plus random lightning with a signal for thunder.

signal lightning(strength: float)

@export var follow: Node3D
@export var storm: StormEnvironment

var rain: GPUParticles3D
var _next_bolt: float = 4.0
var _flash: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 7
	rain = GPUParticles3D.new()
	rain.name = "Rain"
	rain.amount = roundi(7000 * Settings.particle_scale())
	rain.lifetime = 0.8
	rain.preprocess = 0.8
	rain.visibility_aabb = AABB(Vector3(-80, -45, -80), Vector3(160, 60, 160))
	rain.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(75, 1, 75)
	pm.direction = Vector3(0.22, -1, 0.05)
	pm.spread = 2.0
	pm.initial_velocity_min = 38.0
	pm.initial_velocity_max = 46.0
	pm.gravity = Vector3.ZERO
	rain.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.035, 1.1)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.62, 0.76, 0.84, 0.28)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.disable_receive_shadows = true
	quad.material = mat
	rain.draw_pass_1 = quad
	rain.position = Vector3(0, 30, -30)
	add_child(rain)
	if has_node(^"/root/Sfx"):
		Sfx.loop(&"rain_loop", true, -8.0)


func _process(delta: float) -> void:
	if follow:
		var fwd := -follow.global_transform.basis.z
		fwd.y = 0.0
		fwd = fwd.normalized() * 45.0 if fwd.length() > 0.01 else Vector3(0, 0, -30)
		rain.global_position = Vector3(follow.global_position.x + fwd.x, 30.0, follow.global_position.z + fwd.z)
	_next_bolt -= delta
	if _next_bolt <= 0.0:
		_next_bolt = _rng.randf_range(5.0, 11.0)
		_flash = 1.0
		var strength := _rng.randf_range(0.6, 1.0)
		lightning.emit(strength)
		_thunder(strength)
	_flash *= exp(-7.0 * delta)
	var flick := (0.6 + _rng.randf() * 0.4) if _flash > 0.05 else 1.0
	if storm:
		storm.set_flash(_flash * flick)


func _thunder(strength: float) -> void:
	if not has_node(^"/root/Sfx"):
		return
	var which := StringName("thunder_%d" % _rng.randi_range(0, 2))
	await get_tree().create_timer(_rng.randf_range(0.4, 1.0)).timeout
	Sfx.play(which, Vector3.INF, linear_to_db(strength) - 2.0)


## Forces a lightning strike now (used by capture scenarios).
func strike() -> void:
	_next_bolt = 0.0
