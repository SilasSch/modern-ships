extends Node
## Autoload "Sfx": plays the synthesized sounds, positional (3D pool) or flat (2D), plus named loops.

const NAMES: Array[StringName] = [&"charge", &"overcharge_loop", &"fire", &"misfire", &"recharge", &"impact",
	&"explosion", &"flak", &"enemy_gun", &"shell_whistle", &"torpedo", &"splash", &"thunder_0", &"thunder_1",
	&"thunder_2", &"rain_loop", &"ui_click"]
const POOL_3D := 24
const POOL_2D := 8
const AMBIENCE: Array[StringName] = [&"rain_loop", &"thunder_0", &"thunder_1", &"thunder_2"]

var _streams: Dictionary = {}
var _p3: Array[AudioStreamPlayer3D] = []
var _p2: Array[AudioStreamPlayer] = []
var _i3: int = 0
var _i2: int = 0
var _loops: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for n: StringName in NAMES:
		_streams[n] = load("res://assets/audio/%s.wav" % n)
	for i in POOL_3D:
		var p := AudioStreamPlayer3D.new()
		p.bus = &"SFX"
		p.unit_size = 40.0
		p.max_db = 6.0
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(p)
		_p3.append(p)
	for i in POOL_2D:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_p2.append(p)


func play(sound: StringName, at: Vector3 = Vector3.INF, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var stream: AudioStream = _streams.get(sound)
	if stream == null:
		return
	if at == Vector3.INF:
		var p := _p2[_i2]
		_i2 = (_i2 + 1) % POOL_2D
		p.bus = &"Ambience" if AMBIENCE.has(sound) else &"SFX"
		p.stream = stream
		p.volume_db = volume_db
		p.pitch_scale = pitch
		p.play()
	else:
		var p3 := _p3[_i3]
		_i3 = (_i3 + 1) % POOL_3D
		p3.global_position = at
		p3.stream = stream
		p3.volume_db = volume_db
		p3.pitch_scale = pitch
		p3.play()


func loop(sound: StringName, on: bool, volume_db: float = 0.0) -> void:
	var p: AudioStreamPlayer = _loops.get(sound)
	if p == null:
		if not on:
			return
		p = AudioStreamPlayer.new()
		p.stream = _streams.get(sound)
		p.bus = &"Ambience" if AMBIENCE.has(sound) else &"SFX"
		add_child(p)
		_loops[sound] = p
	p.volume_db = volume_db
	if on and not p.playing:
		p.play()
	elif not on and p.playing:
		p.stop()
