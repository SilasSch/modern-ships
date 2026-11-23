class_name Enemy
extends Node3D
## Base for enemy ships: health, inertial motion, buoyancy, wake, and breaking apart when sunk.

signal died(enemy: Enemy)

const FIRE := Color("#ff8a3d")

var health: Health
var motion: ShipMotion
var target: Node3D
var blockers: Array = []
var is_small: bool = false
var hit_radius: float = 3.0
var collision_radius: float = 1.5
var half_length: float = 4.0
var explosion_strength: float = 1.0
var model: Node3D
var bow: Node3D
var stern: Node3D

var throttle: float = 0.0
var rudder: float = 0.0
var dying: bool = false
var _die_t: float = 0.0
var _wake_slot: int = -1
var _ocean: Ocean
var _burn: Array[GPUParticles3D] = []
var _rng := RandomNumberGenerator.new()


## Subclasses set health/motion/model in _init via configure().
func configure(model_scene: PackedScene, hp: float, max_speed: float, accel: float, turn_rate: float, radius: float) -> void:
	health = Health.new(hp)
	motion = ShipMotion.new(max_speed, max_speed * 0.4, accel, turn_rate)
	hit_radius = radius
	model = model_scene.instantiate()
	model.name = "Model"
	add_child(model)
	bow = model.find_child("Bow")
	stern = model.find_child("Stern")


func _ready() -> void:
	add_to_group(&"enemies")
	_rng.seed = get_instance_id()
	_ocean = get_tree().get_first_node_in_group(&"ocean") as Ocean
	if _ocean:
		_wake_slot = _ocean.acquire_wake()
	motion.position = Vector2(global_position.x, global_position.z)
	motion.heading = rotation.y


static func create(kind: StringName) -> Enemy:
	match kind:
		&"speedboat":
			return Speedboat.new()
		&"frigate":
			return Frigate.new()
		&"submarine":
			return Submarine.new()
		&"destroyer":
			return Destroyer.new()
		&"cruiser":
			return Cruiser.new()
	push_error("unknown enemy type %s" % kind)
	return null


func apply_damage(amount: float, _from_dir: Vector3) -> void:
	if dying:
		return
	var killed := health.damage(amount)
	if killed:
		_die()
	elif _explosions():
		if amount >= 25.0:
			_explosions().play(global_position + Vector3(0, 1.0, 0), 0.35)
		else:
			_explosions().hit_spark(global_position + Vector3(0, 1.2, 0))


func get_hit_center() -> Vector2:
	return Vector2(global_position.x, global_position.z)


func get_hit_radius() -> float:
	return hit_radius


func can_be_hit() -> bool:
	return not dying


func _explosions() -> ExplosionFx:
	return get_tree().get_first_node_in_group(&"explosions") as ExplosionFx if is_inside_tree() else null


func _sfx(sound: StringName, volume_db: float = 0.0) -> void:
	if is_inside_tree() and has_node(^"/root/Sfx"):
		Sfx.play(sound, global_position, volume_db)


func _die() -> void:
	dying = true
	_die_t = 0.0
	_release_wake()
	if _explosions():
		_explosions().play(global_position + Vector3(0, 1.0, 0), explosion_strength)
	_sfx(&"explosion", 2.0)
	for half: Node3D in [bow, stern]:
		if half:
			var p := _make_burn()
			half.add_child(p)
			p.position = Vector3(0, 1.0, 0)
			p.emitting = true
			_burn.append(p)
	for n: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i) as StandardMaterial3D
			if m and m.resource_name == "EnemyAccent":
				var off := m.duplicate() as StandardMaterial3D
				off.emission_energy_multiplier = 0.0
				mi.set_surface_override_material(i, off)
	died.emit(self)


func _make_burn() -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 1.2 * explosion_strength
	pm.direction = Vector3.UP
	pm.spread = 15.0
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 4.0
	pm.gravity = Vector3(0.8, 1.0, 0)
	pm.scale_curve = FxUtil.curve([Vector2(0, 0.6), Vector2(1, 1.8)])
	pm.color_ramp = FxUtil.ramp([FIRE * 3.0, Color(0.6, 0.2, 0.05, 0.6), Color(0.05, 0.05, 0.06, 0.5), Color(0.05, 0.05, 0.06, 0.0)],
		PackedFloat32Array([0.0, 0.25, 0.5, 1.0]))
	var p := GPUParticles3D.new()
	p.amount = 40
	p.lifetime = 1.8
	p.local_coords = false
	p.process_material = pm
	p.draw_pass_1 = FxUtil.quad(2.2 * explosion_strength, false)
	p.visibility_aabb = AABB(Vector3(-20, -5, -20), Vector3(40, 40, 40))
	return p


func _release_wake() -> void:
	if _ocean and _wake_slot > 0:
		_ocean.set_wake(_wake_slot, global_position, 0.0, 0.0)
		_ocean.release_wake(_wake_slot)
	_wake_slot = -1


func _exit_tree() -> void:
	_release_wake()


## Override: set throttle / rudder and fire weapons.
func _ai(_delta: float) -> void:
	pass


func _process(delta: float) -> void:
	if dying:
		_process_dying(delta)
		return
	_ai(delta)
	motion.step(throttle, rudder, delta)
	motion.resolve_blockers(blockers, collision_radius, half_length)
	_apply_transform()
	if _ocean and _wake_slot > 0:
		_ocean.set_wake(_wake_slot, global_position, motion.heading, motion.speed)


func _sink_offset() -> float:
	return 0.0


func _apply_transform() -> void:
	var t := _ocean.time if _ocean else 0.0
	var amp := _ocean.wave_amp if _ocean else 0.0
	var x := motion.position.x
	var z := motion.position.y
	var h := Ocean.wave_height(x, z, t, amp)
	var f := ShipMotion.forward_of(motion.heading)
	var hb := Ocean.wave_height(x + f.x * 4.0, z + f.y * 4.0, t, amp)
	position = Vector3(x, h * 0.6 - _sink_offset(), z)
	rotation = Vector3(atan2(hb - h, 4.0) * 0.6, motion.heading, sin(t * 1.3 + float(_wake_slot)) * 0.04 * amp)


func _process_dying(delta: float) -> void:
	_die_t += delta
	var t := _die_t
	if bow:
		bow.rotation.x = minf(t * 0.55, 0.8)
		bow.position = Vector3(0, -t * 0.45, -minf(t * 0.9, 1.6))
	if stern:
		stern.rotation.x = -minf(t * 0.45, 0.65)
		stern.position = Vector3(0, -t * 0.4, minf(t * 0.7, 1.2))
	if t > 3.5:
		for p: GPUParticles3D in _burn:
			p.emitting = false
	if t > 6.0:
		queue_free()


## Shared steering: turn toward a world point; returns the remaining heading error (rad).
func steer_to(point: Vector2, gain: float = 2.0) -> float:
	var to := point - motion.position
	var err := wrapf(ShipMotion.yaw_of(to) - motion.heading, -PI, PI)
	rudder = clampf(err * gain, -1.0, 1.0)
	return err


func target_pos2() -> Vector2:
	return Vector2(target.global_position.x, target.global_position.z) if target else motion.position


func target_alive() -> bool:
	return target != null and is_instance_valid(target) and target.has_method(&"can_be_hit") and target.call(&"can_be_hit")
