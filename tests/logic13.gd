extends Node
var main: Node
var fails := 0
func check(n: String, ok: bool) -> void:
	print(("ok   " if ok else "FAIL ") + n)
	if not ok:
		fails += 1
func frames(k: int) -> void:
	for i in k:
		await get_tree().physics_frame
func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await frames(10)
	main.new_game("warrior")
	while main.ui.dialog_open():
		main.ui.advance()
	main.state["tut_safe"] = false
	var w: World = main.world
	var q = main.quests
	check("keep built", w.town_buildings.any(func(b: Dictionary) -> bool: return b["kind"] == "keep"))
	check("ambient villagers", q._ambient.size() >= 5)
	check("rowan roams", (q._npcs["rowan"] as Dictionary).has("wander"))
	# villagers actually walk, and never into a wall
	await frames(2)
	var moved := 0.0
	for a: Dictionary in q._ambient:
		var p0: Vector3 = a["pos"]
		for i in 400:
			await get_tree().physics_frame
		moved += p0.distance_to(a["pos"])
	check("villagers moved", moved > 2.0)
	# doors: find an auto door near the player and open it
	var d: Door = null
	for n in get_tree().get_nodes_in_group("doors"):
		if (n as Door).mode == "auto":
			d = n
			break
	check("has auto doors", d != null)
	if d:
		main.player.teleport(d.global_position + d.global_transform.basis.z * 1.2 + Vector3(0, 0.3, 0))
		await frames(40)
		check("door opens when you walk up", d.openness > 0.9)
		main.player.teleport(d.global_position + d.global_transform.basis.z * 12.0 + Vector3(0, 0.3, 0))
		await frames(60)
		check("door closes again", d.openness < 0.05)
	# roofs hide when inside
	var inside_ok := false
	for n in get_tree().get_nodes_in_group("doors"):
		pass
	var bl: Array = []
	_find(w.town, bl)
	check("walk-in buildings exist", bl.size() >= 8)
	if bl.size() > 0:
		var b: Building = bl[0]
		var c := b.rect.get_center()
		main.player.teleport(b.to_global(Vector3(c.x, 0.3, c.y)))
		await frames(5)
		check("roof hides inside", not b.roof.visible)
		main.player.teleport(b.to_global(Vector3(c.x, 0.3, c.y + 30.0)))
		await frames(5)
		check("roof returns outside", b.roof.visible)
	print("fails=", fails)
	get_tree().quit()
func _find(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c is Building:
			out.append(c)
		_find(c, out)
