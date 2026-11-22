class_name FxPool
extends RefCounted
## Caps concurrent effects: acquire() hands out a free slot or recycles the oldest active one.

var _capacity: int
var _active: Array[int] = []  # oldest first


func _init(capacity: int) -> void:
	_capacity = capacity


func acquire() -> int:
	for i in _capacity:
		if not _active.has(i):
			_active.append(i)
			return i
	var oldest: int = _active.pop_front()
	_active.append(oldest)
	return oldest


func release(i: int) -> void:
	_active.erase(i)


func active_count() -> int:
	return _active.size()
