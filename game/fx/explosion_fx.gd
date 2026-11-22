class_name ExplosionFx
extends Node3D
## Pooled ship explosions: flash, fireballs, smoke, sparks, water column, debris, light, water ring.

const SLOTS := 8
const FIRE := Color("#ff8a3d")

var pool := FxPool.new(SLOTS)
var _spark_pool := FxPool.new(6)
var _sparks: Array[GPUParticles3D] = []
var _slots: Array[Dictionary] = []
var _ocean: Ocean


func _ready() -> void:
	add_to_group(&"explosions")
	_ocean = get_tree().get_first_node_in_group(&"ocean") as Ocean
	for i in SLOTS:
		_slots.append(_build_slot())
	for i in 6:
		var pm := _pm(Vector3.UP, 70.0, 4.0, 12.0, 14.0, 1.0)
		pm.color_ramp = FxUtil.ramp([FIRE * 3.5, Color(1, 0.6, 0.2, 0.0)], PackedFloat32Array([0.0, 1.0]))
		var p := FxUtil.burst(14, 0.45, pm, FxUtil.quad(0.25, true))
		p.top_level = true
		add_child(p)
		_sparks.append(p)


## Light hit feedback (flak, gunfire): a few sparks, outside the explosion pool, no screen shake.
func hit_spark(at: Vector3) -> void:
	var i := _spark_pool.acquire()
	_sparks[i].global_position = at
	FxUtil.fire(_sparks[i])
	_spark_pool.release(i)


func _pm(dir: Vector3, spread: float, vmin: float, vmax: float, grav: float, damping: float) -> ParticleProcessMaterial:
	var pm := ParticleProcessMaterial.new()
	pm.direction = dir
	pm.spread = spread
	pm.initial_velocity_min = vmin
	pm.initial_velocity_max = vmax
	pm.gravity = Vector3(0, -grav, 0)
	pm.damping_min = damping
	pm.damping_max = damping * 1.5
	pm.scale_min = 0.7
	pm.scale_max = 1.3
	return pm


func _build_slot() -> Dictionary:
	var root := Node3D.new()
	root.top_level = true
	add_child(root)
	var parts: Array[GPUParticles3D] = []

	var flash := _pm(Vector3.UP, 0.0, 0.0, 0.0, 0.0, 0.0)
	flash.scale_curve = FxUtil.curve([Vector2(0, 0.3), Vector2(0.4, 1.0), Vector2(1, 1.1)])
	flash.color_ramp = FxUtil.ramp([Color(8, 7, 6, 1), Color(3, 1.4, 0.6, 0.6), Color(1, 0.4, 0.1, 0)], PackedFloat32Array([0.0, 0.35, 1.0]))
	parts.append(FxUtil.burst(1, 0.32, flash, FxUtil.quad(16.0, true)))

	var fb := _pm(Vector3.UP, 75.0, 4.0, 14.0, -1.5, 3.0)
	fb.scale_curve = FxUtil.curve([Vector2(0, 0.4), Vector2(0.25, 1.0), Vector2(1, 1.4)])
	fb.color_ramp = FxUtil.ramp([Color(5, 4, 2.5, 1), FIRE * 2.2, Color(0.5, 0.15, 0.05, 0.0)], PackedFloat32Array([0.0, 0.3, 1.0]))
	parts.append(FxUtil.burst(16, 1.1, fb, FxUtil.quad(4.5, true)))

	var smoke := _pm(Vector3.UP, 40.0, 2.0, 6.0, -1.0, 1.0)
	smoke.scale_curve = FxUtil.curve([Vector2(0, 0.4), Vector2(1, 2.4)])
	smoke.color_ramp = FxUtil.ramp([Color(0.08, 0.08, 0.09, 0.0), Color(0.07, 0.07, 0.08, 0.75), Color(0.05, 0.05, 0.06, 0.0)], PackedFloat32Array([0.0, 0.1, 1.0]))
	parts.append(FxUtil.burst(18, 4.0, smoke, FxUtil.quad(6.0, false)))

	var sparks := _pm(Vector3.UP, 85.0, 8.0, 30.0, 18.0, 1.0)
	sparks.color_ramp = FxUtil.ramp([FIRE * 4.0, Color(1, 0.6, 0.2, 0.0)], PackedFloat32Array([0.0, 1.0]))
	parts.append(FxUtil.burst(120, 1.2, sparks, FxUtil.quad(0.3, true)))

	var column := _pm(Vector3.UP, 14.0, 10.0, 26.0, 14.0, 0.4)
	column.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	column.emission_sphere_radius = 2.0
	column.scale_curve = FxUtil.curve([Vector2(0, 0.5), Vector2(1, 1.6)])
	column.color_ramp = FxUtil.ramp([Color(0.7, 0.8, 0.88, 0.75), Color(0.6, 0.7, 0.8, 0.0)], PackedFloat32Array([0.35, 1.0]))
	var streak := QuadMesh.new()
	streak.size = Vector2(0.45, 1.8)
	streak.material = FxUtil.billboard_material(false)
	var col_p := FxUtil.burst(140, 1.8, column, streak)
	col_p.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
	parts.append(col_p)

	var debris := _pm(Vector3.UP, 70.0, 6.0, 18.0, 22.0, 0.2)
	debris.angle_min = 0.0
	debris.angle_max = 360.0
	debris.angular_velocity_min = -400.0
	debris.angular_velocity_max = 400.0
	debris.scale_curve = FxUtil.curve([Vector2(0, 1.0), Vector2(0.8, 1.0), Vector2(1, 0.0)])
	var box := BoxMesh.new()
	box.size = Vector3(0.5, 0.25, 0.4)
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color("#2a2e33")
	dm.roughness = 0.9
	box.material = dm
	parts.append(FxUtil.burst(14, 2.2, debris, box))

	for p: GPUParticles3D in parts:
		root.add_child(p)
	var light := OmniLight3D.new()
	light.light_color = FIRE
	light.omni_range = 30.0
	light.light_energy = 0.0
	light.light_volumetric_fog_energy = 4.0
	light.position = Vector3(0, 3, 0)
	root.add_child(light)
	return {"root": root, "parts": parts, "light": light, "t": 99.0, "k": 1.0}


## water_only: just a water column + ring (shell splashes), no fire.
func play(at: Vector3, strength: float, water_only: bool = false) -> void:
	var i := pool.acquire()
	var s: Dictionary = _slots[i]
	s["t"] = 0.0
	s["k"] = strength
	var root: Node3D = s["root"]
	root.global_position = Vector3(at.x, maxf(at.y, 0.5), at.z)
	root.scale = Vector3.ONE * clampf(0.7 + strength * 0.5, 0.6, 1.8)
	s["k"] = 0.0 if water_only else strength
	var parts: Array = s["parts"]
	for idx in parts.size():
		if water_only and idx != 4:
			continue
		FxUtil.fire(parts[idx])
	if _ocean:
		_ocean.add_ring(at, clampf(strength, 0.3, 1.5))
	if has_node(^"/root/Feel") and not water_only:
		Feel.impact(clampf(strength * 0.6, 0.2, 1.0), at)


func _process(delta: float) -> void:
	for i in SLOTS:
		var s: Dictionary = _slots[i]
		if float(s["t"]) > 30.0:
			continue
		s["t"] = float(s["t"]) + delta
		var t: float = s["t"]
		(s["light"] as OmniLight3D).light_energy = 30.0 * float(s["k"]) * exp(-t * 4.0) * (0.8 + randf() * 0.4)
		if t > 4.5:
			s["t"] = 99.0
			pool.release(i)
