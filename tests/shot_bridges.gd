extends Node
func _ready() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	for i in 20:
		await get_tree().process_frame
	main.new_game("warrior")
	while main.ui.dialog_open():
		main.ui.advance()
	main.set_dev_mode(true)
	main.ui.visible = false
	var w: World = main.world
	var cam := Camera3D.new()
	cam.fov = 50.0
	cam.far = 400.0
	add_child(cam)
	cam.make_current()
	print("bridges: ", w.bridges.size())
	var i := 0
	for b: Dictionary in w.bridges:
		var p: Vector3 = b["pos"]
		var d: Vector3 = b["dir"]
		main.dev_teleport(p + Vector3(0, 0, 6))
		for f in 100:
			await get_tree().process_frame
		var ln: float = b["len"]
		cam.global_position = p + Vector3(0, ln * 1.4 + 20.0, 0.01)
		cam.look_at(p, Vector3.FORWARD)
		for f in 6:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("/tmp/claude-0/shots/br_top_%d.png" % i)
		var side := Vector3(-d.z, 0, d.x)
		cam.global_position = p + side * (ln * 0.9 + 8.0) + Vector3(0, 12, 0)
		cam.look_at(p + Vector3(0, 1, 0))
		for f in 6:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("/tmp/claude-0/shots/br_side_%d.png" % i)
		print("BR ", i, " pos ", p.snapped(Vector3.ONE), " dir ", d.snapped(Vector3.ONE * 0.01), " len ", snapped(ln, 0.1))
		i += 1
		if i >= 8:
			break
	print("DONE")
	get_tree().quit()
