class_name OceanEffects
extends RefCounted
## Fixed slots for transient water effects, packed for shader uniforms.

const RING_SLOTS := 8
const TRENCH_SLOTS := 2
const INACTIVE_AGE := 99.0

var charge_pos: Vector2 = Vector2.ZERO
var charge_amount: float = 0.0

var _rings := PackedVector4Array()
var _trenches := PackedVector4Array()
var _trench_meta := PackedVector2Array()
var _ring_i: int = 0
var _trench_i: int = 0


func _init() -> void:
	_rings.resize(RING_SLOTS)
	for i in RING_SLOTS:
		_rings[i] = Vector4(0, 0, INACTIVE_AGE, 0)
	_trenches.resize(TRENCH_SLOTS)
	_trench_meta.resize(TRENCH_SLOTS)
	for i in TRENCH_SLOTS:
		_trenches[i] = Vector4.ZERO
		_trench_meta[i] = Vector2(INACTIVE_AGE, 1.0)


func add_ring(pos: Vector2, strength: float) -> void:
	_rings[_ring_i] = Vector4(pos.x, pos.y, 0.0, strength)
	_ring_i = (_ring_i + 1) % RING_SLOTS


func add_trench(from: Vector2, to: Vector2, width: float) -> void:
	_trenches[_trench_i] = Vector4(from.x, from.y, to.x, to.y)
	_trench_meta[_trench_i] = Vector2(0.0, width)
	_trench_i = (_trench_i + 1) % TRENCH_SLOTS


func set_charge(pos: Vector2, amount: float) -> void:
	charge_pos = pos
	charge_amount = amount


func tick(dt: float) -> void:
	for i in RING_SLOTS:
		var r := _rings[i]
		if r.z < INACTIVE_AGE:
			r.z = minf(INACTIVE_AGE, r.z + dt)
			_rings[i] = r
	for i in TRENCH_SLOTS:
		var m := _trench_meta[i]
		if m.x < INACTIVE_AGE:
			m.x = minf(INACTIVE_AGE, m.x + dt)
			_trench_meta[i] = m


func ring_data() -> PackedVector4Array:
	return _rings


func trench_data() -> PackedVector4Array:
	return _trenches


func trench_meta() -> PackedVector2Array:
	return _trench_meta
