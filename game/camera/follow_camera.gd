class_name FollowCamera
extends Camera3D
## 2.5D chase camera: pitched view that trails the ship and leads toward the aim point.
## Also projects the mouse onto the sea (y = 0) to set the ship's aim point.

@export var target: PlayerShip
## Zoom levels: [distance, pitch]. Far levels look flatter so more sea ahead is visible.
const ZOOM_LEVELS: Array[Vector2] = [Vector2(140, 60), Vector2(210, 54), Vector2(300, 48), Vector2(420, 44)]
@export var zoom_index: int = 1
var pitch_deg: float = 54.0
var distance: float = 210.0
@export var mouse_aim: bool = true

var base_fov: float = 46.0
var _focus: Vector3
var _feel_offset := Vector3.ZERO
var _kick: float = 0.0
var _fov_add: float = 0.0
var _charge_zoom: float = 0.0


func _ready() -> void:
	fov = base_fov
	distance = ZOOM_LEVELS[zoom_index].x
	pitch_deg = ZOOM_LEVELS[zoom_index].y
	if target:
		_focus = target.global_position


func zoom_in() -> void:
	zoom_index = maxi(zoom_index - 1, 0)


func zoom_out() -> void:
	zoom_index = mini(zoom_index + 1, ZOOM_LEVELS.size() - 1)


func _unhandled_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.pressed:
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_in()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_out()


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
	var level := ZOOM_LEVELS[zoom_index]
	distance = lerpf(distance, level.x, 1.0 - exp(-2.5 * delta))
	pitch_deg = lerpf(pitch_deg, level.y, 1.0 - exp(-2.5 * delta))
	var lead_vec := to_aim.limit_length(distance * 0.15)
	var desired := Vector3(ship_pos.x, 0.0, ship_pos.z) + lead_vec * (1.0 - _charge_zoom * 0.4)
	_focus = _focus.lerp(desired, 1.0 - exp(-1.8 * delta))
	var pitch := deg_to_rad(pitch_deg)
	var dist := distance * (1.0 - _charge_zoom * 0.08) + _kick * 4.0
	var offset := Vector3(0.0, sin(pitch), cos(pitch)) * dist
	global_position = _focus + offset + _feel_offset
	look_at(_focus + _feel_offset * 0.35, Vector3.UP)
	fov = _aspect_fov() + _fov_add


## base_fov is the vertical FOV at 16:9. Narrower screens (16:10, 3:2, 4:3) keep the same
## horizontal coverage instead of losing the sides; wider screens keep the vertical FOV.
func _aspect_fov() -> float:
	var vp := get_viewport().get_visible_rect().size
	var aspect := vp.x / maxf(vp.y, 1.0)
	if aspect >= 16.0 / 9.0:
		return base_fov
	var half_h := atan(tan(deg_to_rad(base_fov) * 0.5) * 16.0 / 9.0)
	return rad_to_deg(2.0 * atan(tan(half_h) / aspect))


## Mouse ray hit on the plane y = 0, or null.
func mouse_on_sea() -> Variant:
	var mp := get_viewport().get_mouse_position()
	var o := project_ray_origin(mp)
	var d := project_ray_normal(mp)
	if absf(d.y) < 0.0001:
		return null
	var t := -o.y / d.y
	return o + d * t if t > 0.0 else null
