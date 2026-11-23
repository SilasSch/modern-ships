class_name PlayerShip
extends Node3D
## The player's stealth destroyer: inertial movement, buoyancy, railgun turret, recoil.

signal fired(shot: RailgunShot, origin: Vector3, dir: Vector3)
signal misfired()
signal damaged(amount: float)
signal died()
signal charge_started()

const MODEL := preload("res://assets/models/destroyer.glb")
const HIT_RADIUS := 4.0
const HULL_RADIUS := 2.4
const HALF_LENGTH := 12.0

var motion := ShipMotion.new(Tuning.MAX_SPEED, Tuning.MAX_REVERSE, Tuning.ACCEL, Tuning.TURN_RATE)
var turret := TurretAim.new()
var railgun := RailgunState.new()
var health := Health.new(Tuning.PLAYER_HULL)
var aim_point: Vector3 = Vector3(0, 0, -100)
var input_enabled: bool = true
var use_device_input: bool = true
var throttle_input: float = 0.0
var rudder_input: float = 0.0
var blockers: Array = []
var recoil: float = 0.0
var _sink: float = 0.0

var model: Node3D
var turret_pivot: Node3D
var railgun_mesh: Node3D
var muzzle: Node3D
var fx: RailgunFx
var flak: FlakTurret
var _ocean: Ocean
var _railgun_rest: Vector3


func _ready() -> void:
	InputSetup.ensure()
	model = MODEL.instantiate()
	model.name = "Model"
	add_child(model)
	turret_pivot = model.get_node("TurretPivot")
	railgun_mesh = model.get_node("TurretPivot/Railgun")
	muzzle = model.get_node("TurretPivot/Railgun/Muzzle")
	_railgun_rest = railgun_mesh.position
	motion.position = Vector2(position.x, position.z)
	motion.heading = rotation.y
	_ocean = get_tree().get_first_node_in_group(&"ocean") as Ocean
	flak = FlakTurret.new()
	flak.name = "Flak"
	flak.ship = self
	model.get_node("FlakPivot").add_child(flak)
	model.get_node("FlakPivot/FlakGun").reparent(flak, false)
	var deck_light := OmniLight3D.new()
	deck_light.light_color = Color("#bfe9ff")
	deck_light.light_energy = 1.6
	deck_light.omni_range = 28.0
	deck_light.light_volumetric_fog_energy = 0.0
	deck_light.position = Vector3(0, 12, 0)
	add_child(deck_light)
	fx = RailgunFx.new()
	fx.name = "RailgunFx"
	add_child(fx)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		railgun.cancel()


func _unhandled_input(event: InputEvent) -> void:
	if not use_device_input:
		return
	if event.is_action_pressed(&"fire"):
		_handle_fire_input(true)
	elif event.is_action_released(&"fire"):
		_handle_fire_input(false)


func _handle_fire_input(pressed: bool) -> void:
	if not input_enabled or health.is_dead():
		railgun.cancel()
		return
	if pressed:
		var was_ready := railgun.state == RailgunState.State.READY
		railgun.press()
		if was_ready and railgun.state == RailgunState.State.HOLDING:
			charge_started.emit()
		return
	var shot := railgun.release()
	if shot == null:
		return
	var origin := muzzle_transform().origin
	var f := ShipMotion.forward_of(turret.world_yaw(motion.heading))
	recoil = 1.0
	fired.emit(shot, origin, Vector3(f.x, 0.0, f.y))


## Keeps the gun in sync with the held button: a press held through cooldown starts charging,
## and a lost release event (focus change, overlay) still ends the charge.
func _poll_fire() -> void:
	if not use_device_input or not input_enabled or health.is_dead():
		return
	var held := Input.is_action_pressed(&"fire")
	if held and railgun.state == RailgunState.State.READY:
		_handle_fire_input(true)
	elif not held and railgun.state == RailgunState.State.HOLDING:
		_handle_fire_input(false)


func _process(delta: float) -> void:
	if use_device_input:
		var active := input_enabled and not health.is_dead()
		throttle_input = Input.get_axis(&"move_back", &"move_forward") if active else 0.0
		rudder_input = Input.get_axis(&"rudder_right", &"rudder_left") if active else 0.0
	if health.is_dead():
		throttle_input = 0.0
		rudder_input = 0.0
	motion.step(throttle_input, rudder_input, delta)
	motion.resolve_blockers(blockers, HULL_RADIUS, HALF_LENGTH)
	var piv := turret_pivot.global_position
	var to_aim := Vector2(aim_point.x - piv.x, aim_point.z - piv.z)
	if to_aim.length() > 3.0 and not health.is_dead():
		turret.step(ShipMotion.yaw_of(to_aim), motion.heading, delta)
	if railgun.tick(delta):
		apply_damage(Tuning.MISFIRE_SELF_DAMAGE)
		misfired.emit()
	_poll_fire()
	recoil *= exp(-3.2 * delta)
	if health.is_dead():
		_sink = minf(_sink + delta * 0.7, 9.0)
	_apply_transform()
	if _ocean:
		_ocean.set_wake(0, global_position, motion.heading, motion.speed)


func _apply_transform() -> void:
	var back := -ShipMotion.forward_of(motion.heading) * recoil * 0.7
	var x := motion.position.x + back.x
	var z := motion.position.y + back.y
	var t := _ocean.time if _ocean else 0.0
	var amp := _ocean.wave_amp if _ocean else 0.0
	var f := ShipMotion.forward_of(motion.heading)
	var side := Vector2(-f.y, f.x)
	var h_bow := Ocean.wave_height(x + f.x * 9.0, z + f.y * 9.0, t, amp)
	var h_stern := Ocean.wave_height(x - f.x * 9.0, z - f.y * 9.0, t, amp)
	var h_port := Ocean.wave_height(x + side.x * 2.5, z + side.y * 2.5, t, amp)
	var h_star := Ocean.wave_height(x - side.x * 2.5, z - side.y * 2.5, t, amp)
	position = Vector3(x, (h_bow + h_stern + h_port + h_star) * 0.25 * 0.6 - _sink, z)
	rotation = Vector3(atan2(h_bow - h_stern, 18.0) * 0.6 + recoil * 0.035 + _sink * 0.05, motion.heading, atan2(h_port - h_star, 5.0) * -0.5 + _sink * 0.04)
	turret_pivot.rotation.y = turret.angle
	railgun_mesh.position = _railgun_rest + Vector3(0, 0, recoil * 0.9)


func apply_damage(amount: float) -> void:
	if health.is_dead():
		return
	var killed := health.damage(amount)
	damaged.emit(amount)
	if killed:
		railgun.cancel()
		died.emit()


func muzzle_transform() -> Transform3D:
	return muzzle.global_transform


func get_hit_center() -> Vector2:
	return motion.position


func get_hit_radius() -> float:
	return HIT_RADIUS


func can_be_hit() -> bool:
	return not health.is_dead()
