extends Node
var main: Node
func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	for i in 20:
		await get_tree().process_frame
	main.new_game("warrior")
	while main.ui.dialog_open():
		main.ui.advance()
	main.set_dev_mode(true)
	var w: World = main.world
	var hm: Vector3 = w.settlements[0]["pos"]
	for st: Dictionary in w.settlements:
		if String(st["name"]).begins_with("Hearth"):
			hm = st["pos"]
	main.dev_teleport(hm + Vector3(0, 0, 14))
	for i in 150:
		await get_tree().process_frame
	var n0 := get_tree().get_nodes_in_group("tk_buildings").size()
	print("tk buildings in world: ", n0)
	print("mode before: ", main.mode, " dialog ", main.ui.dialog_open(), " dev ", main.dev_mode)
	# simulate F3
	var ev := InputEventKey.new()
	ev.keycode = KEY_F3
	ev.pressed = true
	main._unhandled_input(ev)
	for i in 10:
		await get_tree().process_frame
	var ed: BuildEditor = main.build_editor
	if not ed.active:
		print("F3 key did not toggle; calling toggle() directly")
		ed.toggle()
		for i in 10:
			await get_tree().process_frame
	print("editor active ", ed.active, " mode ", main.mode, " paused ", get_tree().paused, " bld ", ed._kind(), " props ", ed._all_props().size(), " issues ", ed._issues.size())
	var t0 := Time.get_ticks_msec()
	# click an unrelated far building through the mouse path
	ed._top_view()
	for i in 5:
		await get_tree().process_frame
	var vp := get_viewport().get_visible_rect().size
	# open another building by clicking it: find a different kind
	var other: Building = null
	for n: Node in get_tree().get_nodes_in_group("tk_buildings"):
		var b := n as Building
		if b != ed.bld and b.has_meta("tk") and String((b.get_meta("tk") as Dictionary)["kind"]) != ed._kind() and b.global_position.distance_to(ed.bld.global_position) < 40.0:
			other = b
			break
	if other != null:
		var c := other.to_global(Vector3(other.rect.get_center().x, 0.5, other.rect.get_center().y))
		ed.cam.global_position = c + Vector3(0, 14, 0)
		ed._pitch = -PI * 0.5 + 0.001
		await get_tree().process_frame
		await get_tree().process_frame
		var sp := ed.cam.unproject_position(c)
		var okind: String = String((other.get_meta("tk") as Dictionary)["kind"])
		await ed._click(sp)
		print("clicked other building ", okind, " -> bld now ", ed._kind(), " selected ", ed.selected.name if ed.selected else "none")
	ev = InputEventKey.new()
	ev.keycode = KEY_F3
	ev.pressed = true
	ed._unhandled_input(ev)
	for i in 10:
		await get_tree().process_frame
	print("left: active ", ed.active, " mode ", main.mode, " paused ", get_tree().paused, " ui visible ", main.ui.visible, " buildings ", get_tree().get_nodes_in_group("tk_buildings").size())
	print("DONE")
	get_tree().quit()
