extends GutTest

const FakeTarget := preload("res://tests/support/fake_target.gd")


func _cast(targets: Array, half_width: float = 1.2, blockers: Array = []) -> Dictionary:
	return BeamHit.cast(Vector2.ZERO, Vector2(1, 0), 260.0, half_width, targets, blockers)


func test_pierces_all_targets_in_line() -> void:
	var a := FakeTarget.new(Vector2(50, 0))
	var b := FakeTarget.new(Vector2(10, 0))
	var c := FakeTarget.new(Vector2(30, 0))
	var hits: Array = _cast([a, b, c])["hits"]
	assert_eq(hits.size(), 3)
	assert_eq(hits[0]["target"], b)
	assert_eq(hits[1]["target"], c)
	assert_eq(hits[2]["target"], a)
	assert_almost_eq(float(hits[0]["distance"]), 10.0, 0.01)


func test_misses_target_outside_width() -> void:
	var t := FakeTarget.new(Vector2(20, 5))
	assert_eq(_cast([t], 1.2)["hits"].size(), 0)
	assert_eq(_cast([t], 3.1)["hits"].size(), 1)


func test_ignores_targets_behind_and_beyond_range() -> void:
	var behind := FakeTarget.new(Vector2(-10, 0))
	var far := FakeTarget.new(Vector2(300, 0))
	assert_eq(_cast([behind, far])["hits"].size(), 0)


func test_island_blocks_beam() -> void:
	var near := FakeTarget.new(Vector2(20, 0))
	var hidden := FakeTarget.new(Vector2(60, 0))
	var result := _cast([near, hidden], 1.2, [{"center": Vector2(40, 0), "radius": 8.0}])
	assert_eq(result["hits"].size(), 1)
	assert_eq(result["hits"][0]["target"], near)
	assert_almost_eq(float(result["end_distance"]), 32.0, 0.01)


func test_skips_targets_that_cannot_be_hit() -> void:
	var sub := FakeTarget.new(Vector2(20, 0), 2.0, false)
	assert_eq(_cast([sub])["hits"].size(), 0)


func test_unnormalized_direction_is_normalized() -> void:
	var t := FakeTarget.new(Vector2(30, 0))
	var r := BeamHit.cast(Vector2.ZERO, Vector2(5, 0), 260.0, 1.2, [t], [])
	assert_almost_eq(float(r["hits"][0]["distance"]), 30.0, 0.01)
	assert_almost_eq(float(r["end_distance"]), 260.0, 0.01)
