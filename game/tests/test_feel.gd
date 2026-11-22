extends GutTest

const FeelScript := preload("res://fx/feel.gd")

var feel: Node


func before_each() -> void:
	feel = FeelScript.new()
	add_child_autofree(feel)


func after_each() -> void:
	Engine.time_scale = 1.0


func test_feel_restores_time_scale() -> void:
	feel.shot(0.0)
	assert_eq(Engine.time_scale, 0.0, "hitstop freezes the simulation")
	feel._advance(0.05)
	assert_eq(Engine.time_scale, 0.0)
	feel._advance(0.05)
	feel._advance(0.05)
	assert_eq(Engine.time_scale, 1.0, "time runs again after the hitstop")


func test_feel_overcharge_hitstop_longer() -> void:
	feel.shot(1.0)
	assert_almost_eq(feel.state.hitstop_left, Tuning.HITSTOP * 1.5, 0.0001)
	feel._advance(0.1)
	assert_eq(Engine.time_scale, 0.0, "overcharged hitstop still running after 0.1 s")
