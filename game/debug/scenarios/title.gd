extends RefCounted


func run(c: Node) -> void:
	await c.wait(2.5)
	await c.shot("title")
