class_name WaveDirector
extends RefCounted
## Spawns waves of enemies; the next wave starts WAVE_DELAY after the previous one is cleared.

const DEFAULT_WAVES: Array = [
	[{"type": &"frigate", "count": 2}],
	[{"type": &"frigate", "count": 2}, {"type": &"destroyer", "count": 1}, {"type": &"submarine", "count": 1}],
	[{"type": &"cruiser", "count": 1}, {"type": &"destroyer", "count": 2}, {"type": &"submarine", "count": 1}, {"type": &"speedboat", "count": 2}],
]

var current_wave: int = 0
var alive: int = 0

var _waves: Array
var _delay: float = Tuning.WAVE_DELAY


func _init(waves: Array = DEFAULT_WAVES) -> void:
	_waves = waves


func tick(dt: float) -> Array[StringName]:
	var spawns: Array[StringName] = []
	if alive > 0 or current_wave >= _waves.size():
		return spawns
	_delay -= dt
	if _delay > 0.0:
		return spawns
	for entry: Dictionary in _waves[current_wave]:
		for i in int(entry["count"]):
			spawns.append(entry["type"])
	current_wave += 1
	alive = spawns.size()
	_delay = Tuning.WAVE_DELAY
	return spawns


func enemy_died() -> void:
	alive = maxi(0, alive - 1)


func is_complete() -> bool:
	return current_wave >= _waves.size() and alive == 0


func total_waves() -> int:
	return _waves.size()
