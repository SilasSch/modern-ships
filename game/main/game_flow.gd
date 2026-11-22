extends Node
## Autoload "Flow": scene switching between title and battle.

const TITLE := "res://ui/title.tscn"
const BATTLE := "res://main/battle.tscn"


func goto_title() -> void:
	_reset()
	get_tree().change_scene_to_file(TITLE)


func start_battle() -> void:
	_reset()
	get_tree().change_scene_to_file(BATTLE)


func quit() -> void:
	get_tree().quit()


func _reset() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	if has_node(^"/root/Feel"):
		Feel.reset()
	if has_node(^"/root/Sfx"):
		Sfx.loop(&"overcharge_loop", false)
