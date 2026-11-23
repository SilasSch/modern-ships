extends GutTest

const SOUNDS := ["charge", "overcharge_loop", "fire", "misfire", "recharge", "impact", "explosion", "flak",
	"enemy_gun", "shell_whistle", "torpedo", "splash", "thunder_0", "thunder_1", "thunder_2", "rain_loop", "ui_click"]
const LOOPS := ["overcharge_loop", "rain_loop"]


func test_all_sounds_present_and_long_enough() -> void:
	for n: String in SOUNDS:
		var s := load("res://assets/audio/%s.wav" % n) as AudioStreamWAV
		assert_not_null(s, n)
		if s:
			assert_gte(s.get_length(), 0.05, n)


func test_charge_matches_charge_time() -> void:
	var s := load("res://assets/audio/charge.wav") as AudioStreamWAV
	assert_almost_eq(s.get_length(), 1.2, 0.05)


func test_loops_are_looping() -> void:
	for n: String in LOOPS:
		var s := load("res://assets/audio/%s.wav" % n) as AudioStreamWAV
		assert_eq(s.loop_mode, AudioStreamWAV.LOOP_FORWARD, n)


func test_new_sounds_present() -> void:
	for n: String in ["reload_done", "telegraph", "projectile_whoosh"]:
		var s := load("res://assets/audio/%s.wav" % n) as AudioStreamWAV
		assert_not_null(s, n)
	var fire := load("res://assets/audio/fire.wav") as AudioStreamWAV
	assert_gte(fire.get_length(), 2.8, "heavier, longer railgun report")
