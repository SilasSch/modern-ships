class_name Settings
extends RefCounted
## Graphics quality, stored as a project-settings override (applied on next start).

static var override_path: String = "user://settings_override.cfg"

const SECTION := "rendering"
const KEY := "renderer/rendering_method"


static func set_quality(high: bool) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, KEY, "forward_plus" if high else "mobile")
	cfg.save(override_path)


static func is_high() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(override_path) != OK:
		return true
	return str(cfg.get_value(SECTION, KEY, "forward_plus")) == "forward_plus"
