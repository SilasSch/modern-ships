class_name RailgunFx
extends Node3D
## Railgun visuals on the ship: reload glow, hold/overcharge build-up and the muzzle blast.
## The round itself is a RailgunRound. Child of PlayerShip; blast nodes are top_level.

const RING_SHADER := preload("res://fx/ring.gdshader")
const CYAN := Color("#4de8ff")
const PLASMA := Color("#ffb46b")
# Rail geometry of battlecruiser.glb (Railgun local space)
const RAIL_X := 0.42
const RAIL_Y := 1.25
const RAIL_Z0 := -1.8
const RAIL_Z1 := -14.0

var ship: PlayerShip
var ocean: Ocean

var _energy_mat: StandardMaterial3D
var _rail_mat: StandardMaterial3D
var _arc_mesh := ImmediateMesh.new()
var _arc_mat: StandardMaterial3D
var _arc_timer: float = 0.0
var _suction: GPUParticles3D
var _charge_light: OmniLight3D
var _rng := RandomNumberGenerator.new()

var _flash_light: OmniLight3D
var _rings: Array[MeshInstance3D] = []
var _fireball: GPUParticles3D
var _core_flash: GPUParticles3D
var _muzzle_sparks: GPUParticles3D
var _arc_burst: GPUParticles3D
var _smoke: GPUParticles3D
var _t: float = 99.0
var _over: float = 0.0
var _afterglow: float = 0.0
var _prev_state: int = RailgunState.State.LOADING
var _prev_over: float = 0.0


func _ready() -> void:
	_rng.seed = 11
	ship = get_parent() as PlayerShip
	ocean = get_tree().get_first_node_in_group(&"ocean") as Ocean
	_setup_materials()
	_setup_hold()
	_setup_muzzle()
	ship.fired.connect(func(shot: RailgunShot, origin: Vector3, _dir: Vector3) -> void:
		_sfx(&"fire", origin, 3.0, 1.0 - 0.12 * shot.overcharge))
	ship.misfired.connect(func() -> void: _sfx(&"misfire", ship.global_position, 0.0))


func _sfx(sound: StringName, at: Vector3, db: float, pitch: float = 1.0) -> void:
	if has_node(^"/root/Sfx"):
		Sfx.play(sound, at, db, pitch)


func _setup_materials() -> void:
	var rg := ship.railgun_mesh as MeshInstance3D
	for i in rg.mesh.get_surface_count():
		var m := rg.mesh.surface_get_material(i) as StandardMaterial3D
		if m == null:
			continue
		if m.resource_name == "Energy":
			_energy_mat = m.duplicate() as StandardMaterial3D
			_energy_mat.emission_enabled = true
			_energy_mat.emission = CYAN
			rg.set_surface_override_material(i, _energy_mat)
		elif m.resource_name == "Rail":
			_rail_mat = m.duplicate() as StandardMaterial3D
			_rail_mat.emission_enabled = true
			_rail_mat.emission = CYAN
			_rail_mat.emission_energy_multiplier = 0.0
			rg.set_surface_override_material(i, _rail_mat)


func _setup_hold() -> void:
	_arc_mat = StandardMaterial3D.new()
	_arc_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_arc_mat.albedo_color = CYAN * 5.0
	var arc := MeshInstance3D.new()
	arc.mesh = _arc_mesh
	arc.material_override = _arc_mat
	arc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ship.railgun_mesh.add_child(arc)

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE_SURFACE
	pm.emission_sphere_radius = 6.0
	pm.radial_accel_min = -110.0
	pm.radial_accel_max = -80.0
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	pm.color = CYAN * 3.0
	_suction = GPUParticles3D.new()
	_suction.amount = roundi(180 * Settings.particle_scale())
	_suction.lifetime = 0.36
	_suction.local_coords = true
	_suction.emitting = false
	_suction.process_material = pm
	_suction.draw_pass_1 = FxUtil.quad(0.3, true)
	_suction.visibility_aabb = AABB(Vector3(-8, -8, -8), Vector3(16, 16, 16))
	ship.muzzle.add_child(_suction)

	_charge_light = OmniLight3D.new()
	_charge_light.light_color = CYAN
	_charge_light.omni_range = 22.0
	_charge_light.light_energy = 0.0
	_charge_light.light_volumetric_fog_energy = 3.0
	ship.muzzle.add_child(_charge_light)


func _setup_muzzle() -> void:
	_flash_light = OmniLight3D.new()
	_flash_light.top_level = true
	_flash_light.light_color = Color(1.0, 0.72, 0.45)
	_flash_light.omni_range = 70.0
	_flash_light.light_energy = 0.0
	_flash_light.light_volumetric_fog_energy = 4.0
	add_child(_flash_light)
	for i in 3:
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(2, 2)
		q.mesh = qm
		var rm := ShaderMaterial.new()
		rm.shader = RING_SHADER
		rm.set_shader_parameter("color", Color(1.0, 0.92, 0.8))
		q.material_override = rm
		q.top_level = true
		q.visible = false
		add_child(q)
		_rings.append(q)

	# White-hot core flash -> orange plasma fireball -> smoke (after the Navy test footage).
	var cpm := ParticleProcessMaterial.new()
	cpm.direction = Vector3(0, 0, -1)
	cpm.spread = 4.0
	cpm.initial_velocity_min = 10.0
	cpm.initial_velocity_max = 30.0
	cpm.damping_min = 30.0
	cpm.damping_max = 40.0
	cpm.gravity = Vector3.ZERO
	cpm.scale_curve = FxUtil.curve([Vector2(0, 0.6), Vector2(0.3, 1.0), Vector2(1, 1.2)])
	cpm.color_ramp = FxUtil.ramp([Color(5, 4.6, 4, 1), Color(4, 2.4, 1.1, 0.8), Color(1.5, 0.6, 0.2, 0)], PackedFloat32Array([0.0, 0.25, 1.0]))
	_core_flash = FxUtil.burst(5, 0.22, cpm, FxUtil.quad(6.5, true))
	add_child(_core_flash)

	var fpm := ParticleProcessMaterial.new()
	fpm.direction = Vector3(0, 0.05, -1)
	fpm.spread = 22.0
	fpm.initial_velocity_min = 10.0
	fpm.initial_velocity_max = 45.0
	fpm.damping_min = 22.0
	fpm.damping_max = 32.0
	fpm.gravity = Vector3(0, 1.5, 0)
	fpm.scale_min = 0.8
	fpm.scale_max = 1.7
	fpm.scale_curve = FxUtil.curve([Vector2(0, 0.35), Vector2(0.25, 1.0), Vector2(1, 1.5)])
	fpm.color_ramp = FxUtil.ramp([Color(4, 3.2, 2.2, 1), PLASMA * 2.6, Color(0.9, 0.32, 0.08, 0.7), Color(0.08, 0.08, 0.09, 0.0)],
		PackedFloat32Array([0.0, 0.12, 0.5, 1.0]))
	_fireball = FxUtil.burst(26, 1.1, fpm, FxUtil.quad(5.5, true))
	add_child(_fireball)

	var mpm := ParticleProcessMaterial.new()
	mpm.direction = Vector3(0, 0.1, -1)
	mpm.spread = 40.0
	mpm.initial_velocity_min = 20.0
	mpm.initial_velocity_max = 80.0
	mpm.damping_min = 2.0
	mpm.damping_max = 5.0
	mpm.gravity = Vector3(0, -9.0, 0)
	mpm.color_ramp = FxUtil.ramp([Color(5, 4, 2.5, 1), PLASMA * 2.0, Color(1, 0.5, 0.2, 0.0)], PackedFloat32Array([0.0, 0.4, 1.0]))
	_muzzle_sparks = FxUtil.burst(260, 1.0, mpm, FxUtil.quad(0.3, true))
	add_child(_muzzle_sparks)

	var apm := ParticleProcessMaterial.new()
	apm.direction = Vector3(0, 0, -1)
	apm.spread = 70.0
	apm.initial_velocity_min = 8.0
	apm.initial_velocity_max = 30.0
	apm.damping_min = 6.0
	apm.damping_max = 9.0
	apm.gravity = Vector3.ZERO
	apm.color_ramp = FxUtil.ramp([CYAN * 5.0, Color(0.3, 0.9, 1.0, 0.0)], PackedFloat32Array([0.0, 1.0]))
	_arc_burst = FxUtil.burst(90, 0.4, apm, FxUtil.quad(0.4, true))
	add_child(_arc_burst)

	var spm := ParticleProcessMaterial.new()
	spm.direction = Vector3(0, 0.4, -1)
	spm.spread = 35.0
	spm.initial_velocity_min = 3.0
	spm.initial_velocity_max = 14.0
	spm.damping_min = 2.0
	spm.damping_max = 3.0
	spm.gravity = Vector3(0, 1.4, 0)
	spm.scale_curve = FxUtil.curve([Vector2(0, 0.5), Vector2(1, 2.6)])
	spm.color_ramp = FxUtil.ramp([Color(0.25, 0.26, 0.28, 0.0), Color(0.22, 0.23, 0.26, 0.55), Color(0.18, 0.19, 0.22, 0.0)], PackedFloat32Array([0.0, 0.12, 1.0]))
	_smoke = FxUtil.burst(20, 4.0, spm, FxUtil.quad(7.0, false))
	add_child(_smoke)


# ------------------------------------------------------------------ per frame

func _process(delta: float) -> void:
	var gun := ship.railgun
	var holding := gun.state == RailgunState.State.HOLDING
	var o := gun.overcharge
	if gun.state == RailgunState.State.READY and _prev_state == RailgunState.State.LOADING:
		_sfx(&"reload_done", ship.global_position, -4.0)
	_prev_state = gun.state
	if holding and o > 0.0 and _prev_over <= 0.0:
		_sfx(&"charge", ship.muzzle.global_position, -2.0)
	_prev_over = o
	if has_node(^"/root/Sfx"):
		Sfx.loop(&"overcharge_loop", holding and o > 0.0, linear_to_db(clampf(0.3 + o, 0.0, 1.0)) - 4.0)

	var pulse := 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.03)
	_afterglow = maxf(0.0, _afterglow - delta)
	var loaded := gun.state == RailgunState.State.READY or holding
	if _energy_mat:
		var level := 1.0 if loaded else gun.reload
		_energy_mat.emission = CYAN.lerp(Color.WHITE, o * 0.6)
		_energy_mat.emission_energy_multiplier = 0.3 + level * level * 3.0 + (2.5 * pulse if holding else 0.0) + o * 8.0 * pulse + _afterglow * 6.0
	if _rail_mat:
		_rail_mat.emission_energy_multiplier = (0.6 if holding else 0.0) + o * 2.4 + _afterglow * 2.0
	_suction.emitting = holding
	_suction.amount_ratio = clampf(0.35 + o, 0.0, 1.0)
	_charge_light.light_energy = (3.0 if holding else 0.0) + o * 8.0 * pulse
	if ocean:
		ocean.set_charge(ship.global_position, (0.4 + 0.6 * o) if holding else 0.0)
	if has_node(^"/root/Feel"):
		Feel.set_charge((0.3 + 0.7 * o) if holding else 0.0)
	_update_arcs(delta, holding, o)
	_update_blast(delta)


func _update_arcs(delta: float, holding: bool, o: float) -> void:
	_arc_timer -= delta
	if not holding:
		_arc_mesh.clear_surfaces()
		return
	if _arc_timer > 0.0:
		return
	_arc_timer = 0.045
	_arc_mat.albedo_color = CYAN.lerp(Color.WHITE, o) * (4.0 + o * 4.0)
	_arc_mesh.clear_surfaces()
	_arc_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for a in 2 + int(o * 5.0):
		var z0 := _rng.randf_range(RAIL_Z1 + 0.5, RAIL_Z0 - 0.5)
		var prev := Vector3(-RAIL_X, RAIL_Y, z0)
		for k in range(1, 9):
			var t := k / 8.0
			var p := Vector3(lerpf(-RAIL_X, RAIL_X, t), RAIL_Y + _rng.randf_range(-0.4, 0.4), z0 + _rng.randf_range(-0.45, 0.45))
			if k == 8:
				p = Vector3(RAIL_X, RAIL_Y, z0 + _rng.randf_range(-0.3, 0.3))
			_arc_mesh.surface_add_vertex(prev)
			_arc_mesh.surface_add_vertex(p)
			prev = p
	_arc_mesh.surface_end()


# ------------------------------------------------------------------ muzzle blast

## Muzzle blast for a fired round. trench_end: where the sonic trench in the water ends.
func play_muzzle(origin: Vector3, dir: Vector3, overcharge: float, trench_end: Vector3) -> void:
	_t = 0.0
	_over = overcharge
	_afterglow = 1.0
	var k := 1.0 + overcharge
	var basis := Basis.looking_at(dir, Vector3.UP)
	_flash_light.global_position = origin
	_flash_light.light_energy = 45.0 * k
	for i in _rings.size():
		_rings[i].global_transform = Transform3D(basis, origin + dir * (2.0 + i * 3.5))
		_rings[i].visible = true
	for p: GPUParticles3D in [_core_flash, _fireball, _muzzle_sparks, _arc_burst, _smoke]:
		p.global_transform = Transform3D(basis, origin)
		p.scale = Vector3.ONE * k
		FxUtil.fire(p)
	if ocean:
		ocean.add_trench(origin, trench_end, 1.6 * k, Tuning.PROJECTILE_SPEED)
		ocean.add_ring(origin, 1.2 + overcharge * 0.6)
	if has_node(^"/root/Feel"):
		Feel.shot(overcharge)


func _update_blast(delta: float) -> void:
	if _t > 30.0:
		return
	_t += delta
	var k := 1.0 + _over
	_flash_light.light_energy = 45.0 * k * exp(-_t * 9.0)
	for i in _rings.size():
		var rt := _t - i * 0.05
		var r := _rings[i]
		if not r.visible:
			continue
		if rt < 0.0:
			r.scale = Vector3.ONE * 0.01
			continue
		r.scale = Vector3.ONE * (1.0 + rt * 55.0) * (1.0 + _over * 0.5)
		(r.material_override as ShaderMaterial).set_shader_parameter("opacity", maxf(0.0, 1.0 - rt / 0.35) * 0.9)
		if rt > 0.35:
			r.visible = false
