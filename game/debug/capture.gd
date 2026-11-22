extends Node
## Scripted screenshot harness. Inactive unless started with
##   -- --capture-scenario=<name> --capture-dir=<abs dir>
## Scenarios live in res://debug/scenarios/<name>.gd and implement: func run(capture: Node) -> void

var active: bool = false
var _dir: String = ""
var _scenario: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-scenario="):
			_scenario = arg.get_slice("=", 1)
		elif arg.begins_with("--capture-dir="):
			_dir = arg.get_slice("=", 1)
	active = _scenario != ""
	if active:
		DirAccess.make_dir_recursive_absolute(_dir)
		_run.call_deferred()


func _run() -> void:
	var script: GDScript = load("res://debug/scenarios/%s.gd" % _scenario)
	var scenario: Object = script.new()
	await scenario.run(self)
	print("capture: done ", _scenario)
	get_tree().quit()


func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := _dir.path_join(shot_name + ".png")
	img.save_png(path)
	print("capture: ", path)


func find(node_name: String) -> Node:
	return get_tree().current_scene.find_child(node_name, true, false)
