extends GutTest

const TEST_PATH := "user://test_settings_override.cfg"
var _old_path: String


func before_each() -> void:
	_old_path = Settings.override_path
	Settings.override_path = TEST_PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))


func after_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	Settings.override_path = _old_path


func test_default_is_high() -> void:
	assert_true(Settings.is_high())


func test_quality_roundtrip() -> void:
	Settings.set_quality(false)
	assert_false(Settings.is_high())
	assert_string_contains(FileAccess.get_file_as_string(TEST_PATH), "mobile")
	Settings.set_quality(true)
	assert_true(Settings.is_high())
	assert_string_contains(FileAccess.get_file_as_string(TEST_PATH), "forward_plus")
