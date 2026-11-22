class_name Settings
extends RefCounted
## Graphics quality, stored as a project-settings override (applied on next start).

static var override_path: String = "user://settings_override.cfg"
static var _scale_cache: float = -1.0

const SECTION := "rendering"
const KEY := "renderer/rendering_method"


static func set_quality(high: bool) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, KEY, "forward_plus" if high else "mobile")
	cfg.save(override_path)
	invalidate()


static func is_high() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(override_path) != OK:
		return true
	return str(cfg.get_value(SECTION, KEY, "forward_plus")) == "forward_plus"


## Particle budget: 1.0 on "Hoch", 0.45 on "Mittel".
static func particle_scale() -> float:
	if _scale_cache < 0.0:
		_scale_cache = 1.0 if is_high() else 0.45
	return _scale_cache


static func invalidate() -> void:
	_scale_cache = -1.0
