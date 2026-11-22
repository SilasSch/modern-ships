class_name RailgunState
extends RefCounted
## Charge / overcharge / heat state machine of the railgun.
## Hold to charge (CHARGE_TIME), keep holding to overcharge (OVERCHARGE_TIME).
## Heat rises while overcharging and per shot; reaching 1.0 while charging misfires.

enum State { READY, CHARGING, COOLDOWN, LOCKED }

var state: State = State.READY
var charge: float = 0.0
var overcharge: float = 0.0
var heat: float = 0.0

var _hold_time: float = 0.0
var _timer: float = 0.0


func press() -> void:
	if state != State.READY:
		return
	state = State.CHARGING
	_hold_time = 0.0
	charge = 0.0
	overcharge = 0.0


func release() -> RailgunShot:
	if state != State.CHARGING:
		return null
	if charge < 1.0:
		_reset_charge()
		state = State.READY
		return null
	var shot := RailgunShot.new()
	shot.overcharge = overcharge
	shot.damage = Tuning.BASE_DAMAGE * (1.0 + overcharge)
	shot.half_width = Tuning.BEAM_HALF_WIDTH + Tuning.BEAM_HALF_WIDTH_OVER * overcharge
	heat = minf(1.0, heat + Tuning.HEAT_PER_SHOT + Tuning.HEAT_PER_SHOT_OVER * overcharge)
	_reset_charge()
	state = State.COOLDOWN
	_timer = Tuning.COOLDOWN
	return shot


func cancel() -> void:
	if state == State.CHARGING:
		_reset_charge()
		state = State.READY


## Advances time. Returns true exactly on the tick a misfire happens.
func tick(dt: float) -> bool:
	match state:
		State.CHARGING:
			_hold_time += dt
			charge = clampf(_hold_time / Tuning.CHARGE_TIME, 0.0, 1.0)
			var over_time := _hold_time - Tuning.CHARGE_TIME
			if over_time > 0.0:
				overcharge = clampf(over_time / Tuning.OVERCHARGE_TIME, 0.0, 1.0)
				heat = minf(1.0, heat + Tuning.HEAT_OVERCHARGE_PER_SEC * minf(dt, over_time))
			if heat >= 1.0:
				_reset_charge()
				state = State.LOCKED
				_timer = Tuning.LOCK_TIME
				heat = Tuning.HEAT_AFTER_MISFIRE
				return true
			return false
		State.COOLDOWN, State.LOCKED:
			_decay(dt)
			_timer -= dt
			if _timer <= 1e-6:
				state = State.READY
		State.READY:
			_decay(dt)
	return false


func _decay(dt: float) -> void:
	heat = maxf(0.0, heat - Tuning.HEAT_DECAY_PER_SEC * dt)


func _reset_charge() -> void:
	_hold_time = 0.0
	charge = 0.0
	overcharge = 0.0
