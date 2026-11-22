extends Node3D
## Minimal stage for capture scenarios: storm environment, ocean, weather, fixed camera.

func _ready() -> void:
	var storm := StormEnvironment.new()
	storm.name = "Storm"
	add_child(storm)
	var ocean := Ocean.new()
	ocean.name = "Ocean"
	add_child(ocean)
	var cam := Camera3D.new()
	cam.name = "Camera"
	cam.fov = 40.0
	cam.position = Vector3(0, 46, 52)
	add_child(cam)
	cam.look_at(Vector3(0, 0, -4))
	var weather := Weather.new()
	weather.name = "Weather"
	weather.storm = storm
	weather.follow = cam
	add_child(weather)
