class_name RailgunState
extends RefCounted
## Railgun cycle: LOADING (RELOAD_TIME) -> READY -> press = HOLDING -> release fires.
## A click fires a base round; holding past CLICK_GRACE overcharges (more damage and pierce)
## and heats the gun. Heat reaching 1.0 while holding misfires and locks the gun.

enum State { LOADING, READY, HOLDING, LOCKED }

var state: State = State.LOADING
var reload: float = 0.0
var overcharge: float = 0.0
var heat: float = 0.0

var _hold: float = 0.0
var _timer: float = 0.0


func press() -> void:
	if state != State.READY:
		return
	state = State.HOLDING
	_hold = 0.0
	overcharge = 0.0


func release() -> RailgunShot:
	if state != State.HOLDING:
		return null
	var shot := RailgunShot.new()
	shot.overcharge = overcharge
	shot.damage = Tuning.BASE_DAMAGE * (1.0 + overcharge)
	shot.half_width = Tuning.BEAM_HALF_WIDTH + Tuning.BEAM_HALF_WIDTH_OVER * overcharge
	shot.pierce = 2 + roundi(overcharge * 2.0)
	heat = minf(1.0, heat + Tuning.HEAT_PER_SHOT + Tuning.HEAT_PER_SHOT_OVER * overcharge)
	overcharge = 0.0
	reload = 0.0
	state = State.LOADING
	return shot


func cancel() -> void:
	if state == State.HOLDING:
		overcharge = 0.0
		state = State.READY


## Advances time. Returns true exactly on the tick a misfire happens.
func tick(dt: float) -> bool:
	match state:
		State.LOADING:
			_decay(dt)
			reload = minf(1.0, reload + dt / Tuning.RELOAD_TIME)
			if reload >= 1.0 - 1e-6:
				reload = 1.0
				state = State.READY
		State.READY:
			_decay(dt)
		State.HOLDING:
			_hold += dt
			var over := _hold - Tuning.CLICK_GRACE
			if over > 0.0:
				overcharge = clampf(over / Tuning.OVERCHARGE_TIME, 0.0, 1.0)
				heat = minf(1.0, heat + Tuning.HEAT_OVERCHARGE_PER_SEC * minf(dt, over))
			if heat >= 1.0:
				state = State.LOCKED
				_timer = Tuning.LOCK_TIME
				heat = Tuning.HEAT_AFTER_MISFIRE
				overcharge = 0.0
				reload = 0.0
				return true
		State.LOCKED:
			_decay(dt)
			_timer -= dt
			if _timer <= 1e-6:
				state = State.LOADING
	return false


func _decay(dt: float) -> void:
	heat = maxf(0.0, heat - Tuning.HEAT_DECAY_PER_SEC * dt)
