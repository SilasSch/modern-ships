class_name Tuning
extends RefCounted
## All gameplay numbers live here. Values are starting points for tuning.

# --- Railgun ---
const CHARGE_TIME: float = 1.2
const OVERCHARGE_TIME: float = 1.3
const COOLDOWN: float = 1.0
const BASE_DAMAGE: float = 100.0
const BEAM_RANGE: float = 260.0
const BEAM_HALF_WIDTH: float = 1.2
const BEAM_HALF_WIDTH_OVER: float = 1.2
const HEAT_PER_SHOT: float = 0.1
const HEAT_PER_SHOT_OVER: float = 0.3
const HEAT_OVERCHARGE_PER_SEC: float = 0.25
const HEAT_DECAY_PER_SEC: float = 0.2
const MISFIRE_SELF_DAMAGE: float = 40.0
const LOCK_TIME: float = 4.0
const HEAT_AFTER_MISFIRE: float = 0.6
const HITSTOP: float = 0.08

# --- Player ship ---
const PLAYER_HULL: float = 300.0
const MAX_SPEED: float = 14.0
const MAX_REVERSE: float = 5.0
const ACCEL: float = 3.0
const BRAKE: float = 5.0
const WATER_DRAG: float = 0.6
const TURN_RATE: float = 0.45
const TURN_MIN_FACTOR: float = 0.15

# --- Turret ---
const TRAVERSE_RATE: float = 1.4
const TURRET_ARC: float = deg_to_rad(150.0)

# --- Flak ---
const FLAK_RANGE: float = 60.0
const FLAK_RATE: float = 8.0
const FLAK_DAMAGE: float = 3.0

# --- Enemies ---
const SPEEDBOAT_HP: float = 60.0
const SPEEDBOAT_SPEED: float = 22.0
const SPEEDBOAT_GUN_DMG: float = 4.0
const SPEEDBOAT_GUN_INTERVAL: float = 0.5
const SPEEDBOAT_RANGE: float = 45.0
const FRIGATE_HP: float = 180.0
const FRIGATE_SPEED: float = 7.0
const FRIGATE_SALVO: int = 3
const FRIGATE_SHELL_DMG: float = 20.0
const FRIGATE_SALVO_INTERVAL: float = 5.0
const FRIGATE_RANGE: float = 110.0
const FRIGATE_STANDOFF_MIN: float = 50.0
const FRIGATE_STANDOFF_MAX: float = 85.0
const SHELL_FLIGHT_TIME: float = 1.8
const SUB_HP: float = 90.0
const SUB_SPEED: float = 9.0
const SUB_SUBMERGED_TIME: float = 7.0
const SUB_SURFACED_TIME: float = 5.0
const TORPEDO_DMG: float = 45.0
const TORPEDO_SPEED: float = 18.0
const SUB_RANGE: float = 90.0
const SUB_ATTACK_DIST: float = 55.0

# --- Flow ---
const WAVE_DELAY: float = 3.0
const MAP_HALF: float = 200.0
