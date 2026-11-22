extends RefCounted


func run(c: Node) -> void:
	await c.wait(1.5)
	await c.shot("calm")
	var ocean: Ocean = c.find("Ocean")
	ocean.add_ring(Vector3(-20, 0, 8), 1.0)
	ocean.add_trench(Vector3(-30, 0, 8), Vector3(70, 0, -20), 1.2)
	ocean.set_beam_glow(Vector3(-30, 0, 8), Vector3(70, 0, -20), 1.0)
	await c.wait(0.3)
	await c.shot("fx")
	ocean.set_beam_glow(Vector3.ZERO, Vector3.ONE, 0.0)
	(c.find("Weather") as Weather).strike()
	await c.wait(0.05)
	await c.shot("lightning")
