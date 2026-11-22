class_name RailgunFx
extends Node3D
## Visuals of the railgun: charge build-up on the ship and the shot itself (beam, muzzle, water).
## Child of PlayerShip. Effect nodes are top_level so they stay in world space.

const BEAM_SHADER := preload("res://fx/beam.gdshader")
const RING_SHADER := preload("res://fx/ring.gdshader")
const BEAM_COLOR := Color("#4de8ff")
const FIRE_COLOR := Color("#7ff0ff")
const BEAM_LIGHTS := 6
const BEAM_RANGE_FOR_DENSITY := 260.0
const SPIRAL_POINTS := 700

var ship: PlayerShip
var ocean: Ocean

var _energy_mat: StandardMaterial3D
var _rail_mat: StandardMaterial3D
var _arc_mesh := ImmediateMesh.new()
var _arc_inst: MeshInstance3D
var _arc_mat: StandardMaterial3D
var _arc_timer: float = 0.0
var _suction: GPUParticles3D
var _charge_light: OmniLight3D
var _rng := RandomNumberGenerator.new()

# shot state
var _beam_root: Node3D
var _core: MeshInstance3D
var _sheath: MeshInstance3D
var _outer: MeshInstance3D
var _beam_lights: Array[OmniLight3D] = []
var _flash_light: OmniLight3D
var _rings: Array[MeshInstance3D] = []
var _spiral: GPUParticles3D
var _sparks: GPUParticles3D
var _spray: GPUParticles3D
var _steam: GPUParticles3D
var _fireball: GPUParticles3D
var _muzzle_sparks: GPUParticles3D
var _smoke: GPUParticles3D
var _t: float = 99.0
var _over: float = 0.0
var _len: float = 0.0
var _from: Vector3
var _to: Vector3
var _afterglow: float = 0.0
var _prev_state: int = RailgunState.State.READY


func _ready() -> void:
	_rng.seed = 11
	ship = get_parent() as PlayerShip
	ocean = get_tree().get_first_node_in_group(&"ocean") as Ocean
	_setup_materials()
	_setup_charge()
	_setup_shot()


# ------------------------------------------------------------------ setup

func _setup_materials() -> void:
	var rg := ship.railgun_mesh as MeshInstance3D
	for i in rg.mesh.get_surface_count():
		var m := rg.mesh.surface_get_material(i) as StandardMaterial3D
		if m == null:
			continue
		if m.resource_name == "Energy":
			_energy_mat = m.duplicate() as StandardMaterial3D
			_energy_mat.emission_enabled = true
			_energy_mat.emission = BEAM_COLOR
			rg.set_surface_override_material(i, _energy_mat)
		elif m.resource_name == "Rail":
			_rail_mat = m.duplicate() as StandardMaterial3D
			_rail_mat.emission_enabled = true
			_rail_mat.emission = BEAM_COLOR
			_rail_mat.emission_energy_multiplier = 0.0
			rg.set_surface_override_material(i, _rail_mat)


func _setup_charge() -> void:
	_arc_mat = StandardMaterial3D.new()
	_arc_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_arc_mat.albedo_color = BEAM_COLOR * 5.0
	_arc_inst = MeshInstance3D.new()
	_arc_inst.mesh = _arc_mesh
	_arc_inst.material_override = _arc_mat
	_arc_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ship.railgun_mesh.add_child(_arc_inst)

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE_SURFACE
	pm.emission_sphere_radius = 4.0
	pm.radial_accel_min = -70.0
	pm.radial_accel_max = -50.0
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	pm.color = BEAM_COLOR * 3.0
	_suction = GPUParticles3D.new()
	_suction.amount = 160
	_suction.lifetime = 0.38
	_suction.local_coords = true
	_suction.emitting = false
	_suction.process_material = pm
	_suction.draw_pass_1 = FxUtil.quad(0.22, true)
	_suction.visibility_aabb = AABB(Vector3(-6, -6, -6), Vector3(12, 12, 12))
	ship.muzzle.add_child(_suction)

	_charge_light = OmniLight3D.new()
	_charge_light.light_color = BEAM_COLOR
	_charge_light.omni_range = 16.0
	_charge_light.light_energy = 0.0
	_charge_light.light_volumetric_fog_energy = 3.0
	ship.muzzle.add_child(_charge_light)


func _cylinder(power: float) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = 1.0
	cm.bottom_radius = 1.0
	cm.height = 1.0
	cm.radial_segments = 20
	cm.rings = 1
	cm.cap_top = false
	cm.cap_bottom = false
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	var mat := ShaderMaterial.new()
	mat.shader = BEAM_SHADER
	mat.set_shader_parameter("power", power)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.rotation.x = -PI / 2.0  # cylinder axis (Y) -> beam axis (-Z); UV.y 0 at the muzzle
	return mi


func _setup_shot() -> void:
	_beam_root = Node3D.new()
	_beam_root.top_level = true
	_beam_root.visible = false
	add_child(_beam_root)
	_outer = _cylinder(2.4)
	_sheath = _cylinder(1.5)
	_core = _cylinder(0.5)
	for c: MeshInstance3D in [_outer, _sheath, _core]:
		_beam_root.add_child(c)
	for i in BEAM_LIGHTS:
		var l := OmniLight3D.new()
		l.light_color = BEAM_COLOR
		l.omni_range = 18.0
		l.light_energy = 0.0
		l.light_volumetric_fog_energy = 5.0
		l.shadow_enabled = false
		_beam_root.add_child(l)
		_beam_lights.append(l)
	_flash_light = OmniLight3D.new()
	_flash_light.top_level = true
	_flash_light.light_color = Color(0.85, 0.97, 1.0)
	_flash_light.omni_range = 40.0
	_flash_light.light_energy = 0.0
	_flash_light.light_volumetric_fog_energy = 3.0
	add_child(_flash_light)
	for i in 2:
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(2, 2)
		q.mesh = qm
		var rm := ShaderMaterial.new()
		rm.shader = RING_SHADER
		rm.set_shader_parameter("color", BEAM_COLOR.lerp(Color.WHITE, 0.5))
		q.material_override = rm
		q.top_level = true
		q.visible = false
		add_child(q)
		_rings.append(q)

	_spiral = _line_burst(700, 1.4, BEAM_COLOR * 3.0, 0.35, 1.2, 0.0)
	_sparks = _line_burst(500, 0.6, BEAM_COLOR * 5.0, 0.18, 5.0, 3.0)
	_spray = _line_burst(450, 1.3, Color(0.75, 0.85, 0.92, 0.85), 0.9, 7.0, 16.0, false)
	_steam = _line_burst(90, 3.0, Color(0.6, 0.72, 0.8, 0.22), 4.5, 1.0, -0.6, false)

	var fpm := ParticleProcessMaterial.new()
	fpm.direction = Vector3(0, 0, -1)
	fpm.spread = 18.0
	fpm.initial_velocity_min = 6.0
	fpm.initial_velocity_max = 26.0
	fpm.damping_min = 18.0
	fpm.damping_max = 26.0
	fpm.gravity = Vector3(0, 1.0, 0)
	fpm.scale_min = 0.8
	fpm.scale_max = 1.6
	fpm.scale_curve = FxUtil.curve([Vector2(0, 0.4), Vector2(0.3, 1.0), Vector2(1, 1.3)])
	fpm.color_ramp = FxUtil.ramp([Color(6, 6, 6, 1), BEAM_COLOR * 3.0, Color(0.2, 0.5, 0.7, 0.0)], PackedFloat32Array([0.0, 0.3, 1.0]))
	_fireball = FxUtil.burst(18, 0.7, fpm, FxUtil.quad(3.2, true))
	_fireball.local_coords = false
	add_child(_fireball)

	var mpm := ParticleProcessMaterial.new()
	mpm.direction = Vector3(0, 0, -1)
	mpm.spread = 35.0
	mpm.initial_velocity_min = 15.0
	mpm.initial_velocity_max = 55.0
	mpm.damping_min = 3.0
	mpm.damping_max = 6.0
	mpm.gravity = Vector3(0, -9.0, 0)
	mpm.color_ramp = FxUtil.ramp([BEAM_COLOR * 4.0, Color(1.0, 1.0, 1.0, 0.0)], PackedFloat32Array([0.0, 1.0]))
	_muzzle_sparks = FxUtil.burst(140, 0.7, mpm, FxUtil.quad(0.25, true))
	add_child(_muzzle_sparks)

	var spm := ParticleProcessMaterial.new()
	spm.direction = Vector3(0, 0.3, -1)
	spm.spread = 40.0
	spm.initial_velocity_min = 2.0
	spm.initial_velocity_max = 9.0
	spm.damping_min = 2.0
	spm.damping_max = 3.0
	spm.gravity = Vector3(0, 1.2, 0)
	spm.scale_curve = FxUtil.curve([Vector2(0, 0.5), Vector2(1, 2.2)])
	spm.color_ramp = FxUtil.ramp([Color(0.25, 0.3, 0.36, 0.0), Color(0.22, 0.27, 0.33, 0.5), Color(0.2, 0.24, 0.3, 0.0)], PackedFloat32Array([0.0, 0.1, 1.0]))
	_smoke = FxUtil.burst(14, 3.0, spm, FxUtil.quad(4.0, false))
	add_child(_smoke)


## A burst emitted along a box that is aligned with the beam (box local Z = beam axis).
func _line_burst(amount: int, lifetime: float, color: Color, size: float, speed: float, grav: float, additive: bool = true) -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.1, 0.1, 40)
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0 if additive else 35.0
	pm.initial_velocity_min = speed * 0.4
	pm.initial_velocity_max = speed
	pm.damping_min = 1.0
	pm.damping_max = 2.0
	pm.gravity = Vector3(0, -grav, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.3
	pm.color_ramp = FxUtil.ramp([color, Color(color.r, color.g, color.b, 0.0)], PackedFloat32Array([0.15, 1.0]))
	var p := FxUtil.burst(amount, lifetime, pm, FxUtil.quad(size, additive))
	p.explosiveness = 0.92
	add_child(p)
	return p


# ------------------------------------------------------------------ per frame

func _process(delta: float) -> void:
	var gun := ship.railgun
	var c := gun.charge
	var o := gun.overcharge
	var c2 := c * c
	var charging := gun.state == RailgunState.State.CHARGING
	_prev_state = gun.state

	var pulse := 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.03)
	_afterglow = maxf(0.0, _afterglow - delta)
	if _energy_mat:
		_energy_mat.emission = BEAM_COLOR.lerp(Color.WHITE, o * 0.6)
		_energy_mat.emission_energy_multiplier = 0.4 + c2 * 9.0 * pulse + o * 8.0 * pulse + _afterglow * 6.0
	if _rail_mat:
		_rail_mat.emission_energy_multiplier = c2 * 1.6 + o * 2.0 + _afterglow * 2.0
	_suction.emitting = charging and c > 0.05
	_suction.amount_ratio = clampf(0.2 + c, 0.0, 1.0)
	_charge_light.light_energy = c2 * 6.0 + o * 6.0 * pulse
	if ocean:
		ocean.set_charge(ship.global_position, c if charging else 0.0)
	if has_node(^"/root/Feel"):
		Feel.set_charge(c if charging else 0.0)
	_update_arcs(delta, charging, c, o)
	_update_shot(delta)


func _update_arcs(delta: float, charging: bool, c: float, o: float) -> void:
	_arc_timer -= delta
	if not charging or c < 0.25:
		_arc_mesh.clear_surfaces()
		return
	if _arc_timer > 0.0:
		return
	_arc_timer = 0.045
	_arc_mat.albedo_color = BEAM_COLOR.lerp(Color.WHITE, o) * (4.0 + o * 4.0)
	_arc_mesh.clear_surfaces()
	_arc_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var arcs := 2 + int(c * 3.0 + o * 4.0)
	for a in arcs:
		var z0 := -_rng.randf_range(1.3, 8.4)
		var prev := Vector3(-0.27, 0.8, z0)
		for k in range(1, 9):
			var t := k / 8.0
			var p := Vector3(lerpf(-0.27, 0.27, t), 0.8 + _rng.randf_range(-0.25, 0.25), z0 + _rng.randf_range(-0.3, 0.3))
			if k == 8:
				p = Vector3(0.27, 0.8, z0 + _rng.randf_range(-0.2, 0.2))
			_arc_mesh.surface_add_vertex(prev)
			_arc_mesh.surface_add_vertex(p)
			prev = p
	_arc_mesh.surface_end()


# ------------------------------------------------------------------ shot

## Plays the shot: origin = muzzle, dir = horizontal unit vector, length = until the first island.
func play_shot(origin: Vector3, dir: Vector3, length: float, overcharge: float) -> void:
	_t = 0.0
	_over = overcharge
	_len = length
	_from = origin
	_to = origin + dir * length
	_afterglow = 1.0
	var k := 1.0 + overcharge
	var basis := Basis.looking_at(dir, Vector3.UP)
	_beam_root.global_transform = Transform3D(basis, origin)
	_beam_root.visible = true
	for i in BEAM_LIGHTS:
		_beam_lights[i].position = Vector3(0, 0, -length * (i + 0.5) / BEAM_LIGHTS)
	_set_beam(0.0)

	_flash_light.global_position = origin
	_flash_light.light_energy = 40.0 * k
	var ring_basis := Basis.looking_at(dir, Vector3.UP)
	for i in _rings.size():
		_rings[i].global_transform = Transform3D(ring_basis, origin + dir * (1.5 + i * 2.5))
		_rings[i].visible = true

	_spiral_pattern(overcharge)
	for p: GPUParticles3D in [_spiral, _sparks, _spray, _steam]:
		var pm := p.process_material as ParticleProcessMaterial
		if p != _spiral:
			pm.emission_box_extents = Vector3(0.6 if p == _spray else 0.15, 0.1, length * 0.5)
		var y := 0.3 if (p == _spray or p == _steam) else origin.y
		p.global_transform = Transform3D(basis, origin + dir * (length * 0.5) + Vector3(0, y - origin.y, 0))
		if p != _spiral:
			p.amount_ratio = clampf(length / BEAM_RANGE_FOR_DENSITY, 0.15, 1.0)
		FxUtil.fire(p)
	for p: GPUParticles3D in [_fireball, _muzzle_sparks, _smoke]:
		p.global_transform = Transform3D(basis, origin)
		p.scale = Vector3.ONE * k
		FxUtil.fire(p)

	if ocean:
		ocean.add_trench(origin, _to, 1.2 * k)
		ocean.add_ring(origin, 1.0 + overcharge * 0.6)
	if has_node(^"/root/Feel"):
		Feel.shot(overcharge)


func _spiral_pattern(overcharge: float) -> void:
	# Helix of emission points around the beam axis (local -Z = beam direction, system centered on the beam).
	var img := Image.create(SPIRAL_POINTS, 1, false, Image.FORMAT_RGBF)
	var r := 0.65 * (1.0 + overcharge * 0.6)
	for i in SPIRAL_POINTS:
		var s := float(i) / SPIRAL_POINTS * _len
		var a := s * 1.15
		img.set_pixel(i, 0, Color(cos(a) * r, sin(a) * r, _len * 0.5 - s))
	var pm := _spiral.process_material as ParticleProcessMaterial
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINTS
	pm.emission_point_texture = ImageTexture.create_from_image(img)
	pm.emission_point_count = SPIRAL_POINTS
	pm.spread = 180.0
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.9
	pm.gravity = Vector3.ZERO
	_spiral.amount_ratio = 1.0
	_spiral.explosiveness = 1.0


func _set_beam(t: float) -> void:
	var k := 1.0 + _over
	var core_left := maxf(0.0, 1.0 - t / 0.4)
	var r_core := (0.22 * k) * core_left + 0.001
	var r_sheath := (0.8 + t * 1.0) * k
	var r_outer := (2.4 + t * 5.0) * k
	for pair: Array in [[_core, r_core, core_left, 10.0], [_sheath, r_sheath, pow(maxf(0.0, 1.0 - t / 1.25), 2.5), 1.5],
			[_outer, r_outer, pow(maxf(0.0, 1.0 - t / 0.45), 2.0) * 0.5, 0.5]]:
		var mi: MeshInstance3D = pair[0]
		mi.scale = Vector3(pair[1], _len, pair[1])
		mi.position = Vector3(0, 0, -_len * 0.5)
		var mat := mi.material_override as ShaderMaterial
		mat.set_shader_parameter("color", Color.WHITE.lerp(BEAM_COLOR, 0.2) if mi == _core else BEAM_COLOR)
		mat.set_shader_parameter("opacity", pair[2])
		mat.set_shader_parameter("intensity", float(pair[3]) * k)


func _update_shot(delta: float) -> void:
	if _t > 30.0:
		return
	_t += delta
	var k := 1.0 + _over
	if _beam_root.visible:
		_set_beam(_t)
		var le := 10.0 * k * pow(maxf(0.0, 1.0 - _t / 0.9), 2.0)
		for l: OmniLight3D in _beam_lights:
			l.light_energy = le
		if _t > 1.4:
			_beam_root.visible = false
	_flash_light.light_energy = 30.0 * k * exp(-_t * 16.0)
	for i in _rings.size():
		var rt := _t - i * 0.06
		var r := _rings[i]
		if not r.visible:
			continue
		if rt < 0.0:
			r.scale = Vector3.ONE * 0.01
			continue
		r.scale = Vector3.ONE * (0.6 + rt * 34.0) * (1.0 + _over * 0.5)
		(r.material_override as ShaderMaterial).set_shader_parameter("opacity", maxf(0.0, 1.0 - rt / 0.32) * 0.9)
		if rt > 0.32:
			r.visible = false
	if ocean:
		ocean.set_beam_glow(_from, _to, pow(maxf(0.0, 1.0 - _t / 0.9), 2.5) * k * 0.75)
