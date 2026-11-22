extends Node
## Autoload "Feel": hitstop, screenshake, camera kick, flash, bloom pulse, chromatic aberration, vignette.
## Runs on real time so the frozen hitstop frame still shakes.

const POST_SHADER := preload("res://fx/post.gdshader")

var state := FeelState.new()
var charge: float = 0.0

var _last_usec: int = 0
var _post: ShaderMaterial
var _clock: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_last_usec = Time.get_ticks_usec()
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_post = ShaderMaterial.new()
	_post.shader = POST_SHADER
	rect.material = _post
	layer.add_child(rect)


func shot(overcharge: float) -> void:
	state.add_shot(overcharge)
	Engine.time_scale = 0.0


func impact(strength: float, _at: Vector3) -> void:
	state.add_impact(strength)


func set_charge(value: float) -> void:
	charge = value


func reset() -> void:
	state = FeelState.new()
	charge = 0.0
	Engine.time_scale = 1.0


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var real_dt := clampf((now - _last_usec) / 1000000.0, 0.0, 0.1)
	_last_usec = now
	var capture := get_node_or_null(^"/root/Capture")
	if capture != null and capture.get(&"active"):
		real_dt = 1.0 / 30.0  # deterministic in capture runs (--fixed-fps 30)
	_advance(real_dt)


func _advance(real_dt: float) -> void:
	_clock += real_dt
	Engine.time_scale = state.tick(real_dt)
	var c2 := charge * charge
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam is FollowCamera:
		(cam as FollowCamera).set_feel(state.shake_offset(_clock) * 1.4, state.kick, state.kick * 5.0 - c2 * 2.5, c2)
	var storm := get_tree().get_first_node_in_group(&"storm") as StormEnvironment if is_inside_tree() else null
	if storm and storm.environment:
		storm.environment.glow_intensity = 0.8 + state.pulse * 0.5 + c2 * 0.3
		storm.environment.tonemap_exposure = 1.0 + state.flash * 0.3
	if _post:
		_post.set_shader_parameter("ca", 0.002 + state.pulse * 0.012 + c2 * 0.005)
		_post.set_shader_parameter("vignette", c2 * 0.45 + state.pulse * 0.2)
		_post.set_shader_parameter("flash", state.flash * 0.22)
