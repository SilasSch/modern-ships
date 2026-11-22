class_name FollowCamera
extends Camera3D
## 2.5D chase camera: pitched view that trails the ship and leads toward the aim point.
## Also projects the mouse onto the sea (y = 0) to set the ship's aim point.

@export var target: PlayerShip
@export var pitch_deg: float = 50.0
@export var distance: float = 58.0
@export var lead: float = 12.0
@export var mouse_aim: bool = true

var base_fov: float = 40.0
var _focus: Vector3
var _feel_offset := Vector3.ZERO
var _kick: float = 0.0
var _fov_add: float = 0.0
var _charge_zoom: float = 0.0


func _ready() -> void:
	fov = base_fov
	if target:
		_focus = target.global_position


func set_feel(offset: Vector3, kick: float, fov_add: float, charge_zoom: float) -> void:
	_feel_offset = offset
	_kick = kick
	_fov_add = fov_add
	_charge_zoom = charge_zoom


func _process(delta: float) -> void:
	if target == null:
		return
	if mouse_aim:
		var hit: Variant = mouse_on_sea()
		if hit != null:
			target.aim_point = hit
	var ship_pos := target.global_position
	var to_aim := target.aim_point - ship_pos
	to_aim.y = 0.0
	var lead_vec := to_aim.limit_length(lead)
	var desired := Vector3(ship_pos.x, 0.0, ship_pos.z) + lead_vec * (1.0 - _charge_zoom * 0.4)
	_focus = _focus.lerp(desired, 1.0 - exp(-3.5 * delta))
	var pitch := deg_to_rad(pitch_deg)
	var dist := distance * (1.0 - _charge_zoom * 0.12) + _kick * 2.5
	var offset := Vector3(0.0, sin(pitch), cos(pitch)) * dist
	global_position = _focus + offset + _feel_offset
	look_at(_focus + _feel_offset * 0.35, Vector3.UP)
	fov = base_fov + _fov_add


## Mouse ray hit on the plane y = 0, or null.
func mouse_on_sea() -> Variant:
	var mp := get_viewport().get_mouse_position()
	var o := project_ray_origin(mp)
	var d := project_ray_normal(mp)
	if absf(d.y) < 0.0001:
		return null
	var t := -o.y / d.y
	return o + d * t if t > 0.0 else null
