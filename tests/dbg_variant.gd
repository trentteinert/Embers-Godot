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
	var w: World = main.world
	main.dev_teleport(w.settlements[0]["pos"] + Vector3(0, 0, 14))
	for i in 60:
		await get_tree().process_frame
	var ed: BuildEditor = main.build_editor
	ed.toggle()
	for i in 10:
		await get_tree().process_frame
	var target: Building = null
	for n in get_tree().get_nodes_in_group("tk_buildings"):
		var b := n as Building
		if b != null and b.has_meta("tk") and String((b.get_meta("tk") as Dictionary)["kind"]) == "house":
			target = b
			break
	print("house found: ", target != null)
	if target == null:
		get_tree().quit()
		return
	ed._open_building(target)
	for i in 5:
		await get_tree().process_frame
	print("kind ", ed._kind(), " props ", ed._all_props().size())
	var t0 := Time.get_ticks_msec()
	var good := ed._variant_check(ed._layout_data())
	print("current layout warnings: ", good, " in ", Time.get_ticks_msec() - t0, " ms")
	var bad := {"v": 1, "props": {"chest_1": {"d": [0.55, 0.0, 0.0], "r": 0.0}}, "deleted": [], "added": []}
	print("bad layout warnings: ", ed._variant_check(bad))
	print("bld still set: ", ed.bld == target, " buildings in group: ", get_tree().get_nodes_in_group("tk_buildings").size())
	print("DONE")
	get_tree().quit()
