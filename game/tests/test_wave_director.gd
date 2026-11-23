extends GutTest

var w: WaveDirector


func before_each() -> void:
	w = WaveDirector.new()


func _kill(n: int) -> void:
	for i in n:
		w.enemy_died()


func test_first_wave_after_delay() -> void:
	assert_eq(w.tick(2.9).size(), 0)
	var spawns: Array[StringName] = w.tick(0.2)
	assert_eq(spawns.size(), 2)
	assert_eq(spawns.count(&"frigate"), 2)
	assert_eq(w.current_wave, 1)
	assert_eq(w.alive, 2)


func test_next_wave_only_after_all_dead() -> void:
	w.tick(3.1)
	_kill(1)
	assert_eq(w.tick(10.0).size(), 0, "one enemy still alive")
	_kill(1)
	assert_eq(w.tick(2.0).size(), 0, "delay before next wave")
	var spawns: Array[StringName] = w.tick(1.1)
	assert_eq(spawns.size(), 4)
	assert_eq(spawns.count(&"submarine"), 1)
	assert_eq(spawns.count(&"destroyer"), 1)
	assert_eq(w.current_wave, 2)


func test_complete_after_last_wave_cleared() -> void:
	var expected := [2, 4, 6]
	for i in 3:
		var spawns: Array[StringName] = w.tick(3.1)
		assert_eq(spawns.size(), expected[i])
		assert_false(w.is_complete())
		_kill(spawns.size())
	assert_true(w.is_complete())
	assert_eq(w.tick(10.0).size(), 0)
	assert_eq(w.total_waves(), 3)


func test_enemy_died_never_negative() -> void:
	_kill(3)
	assert_eq(w.alive, 0)


func test_custom_waves() -> void:
	var c := WaveDirector.new([[{"type": &"speedboat", "count": 1}]])
	assert_eq(c.tick(3.1), [&"speedboat"] as Array[StringName])
	c.enemy_died()
	assert_true(c.is_complete())


func test_default_waves_composition() -> void:
	var w3: Array = WaveDirector.DEFAULT_WAVES[2]
	var counts := {}
	for e: Dictionary in w3:
		counts[e["type"]] = e["count"]
	assert_eq(counts, {&"cruiser": 1, &"destroyer": 2, &"submarine": 1, &"speedboat": 2})
