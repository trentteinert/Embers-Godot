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
	var sites := get_tree().get_nodes_in_group("tk_sites")
	print("sites: ", sites.size())
	var hm: Node3D = null
	for s in sites:
		if String(s.name) == "Hearthmoor":
			hm = s as Node3D
	PropLayouts.reset("site_Hearthmoor")
	main.dev_teleport(hm.global_position + Vector3(0, 0, 14))
	for i in 120:
		await get_tree().process_frame
	var ed: BuildEditor = main.build_editor
	ed.toggle()
	for i in 10:
		await get_tree().process_frame
	var ids: Array = []
	for ch in hm.get_children():
		if ch.has_meta("pid"):
			ids.append(ch.name)
	print("outdoor props in Hearthmoor: ", ids.size(), " e.g. ", ids.slice(0, 8))
	var lamp: Node3D = null
	for ch in hm.get_children():
		if String(ch.name).begins_with("lamp_"):
			lamp = ch as Node3D
			break
	print("lamp ", lamp.name, " prop_id ", lamp.has_meta("prop_id"), " aabb ", lamp.get_meta("aabb"))
	var c := lamp.global_position + Vector3(0, 1.0, 0)
	ed.cam.global_position = c + Vector3(0, 12, 0)
	ed._pitch = -PI * 0.5 + 0.001
	await get_tree().process_frame
	await get_tree().process_frame
	await ed._click(ed.cam.unproject_position(c))
	print("clicked lamp -> selected ", ed.selected.name if ed.selected else "none", " site ", ed.site.name if ed.site else "none", " bld ", ed.bld)
	var p0 := lamp.global_position
	ed._nudge(Vector3(1, 0, 0), InputEventKey.new())
	ed._nudge(Vector3(1, 0, 0), InputEventKey.new())
	print("moved lamp by ", (lamp.global_position - p0), " dirty ", ed.dirty, " scale ", lamp.scale)
	var y0 := lamp.rotation.y
	ed._rotate_by(1.0, InputEventKey.new())
	print("rotate_by: yaw ", y0, " -> ", lamp.rotation.y, " scale ", lamp.scale)
	ed._set_tool("rotate")
	ed._update_gizmo()
	var org := ed.cam.unproject_position(lamp.global_position)
	var gs := ed._gizmo.scale.x
	print("ring hit candidates: ")
	for off in [Vector2(60, 0), Vector2(0, 60), Vector2(-60, 0), Vector2(40, 40)]:
		print("  ", off, " -> ", ed._gizmo_hit(org + off))
	var rp := lamp.global_position + Vector3(gs, 0, 0)
	var rs := ed.cam.unproject_position(rp)
	print("ring point hit: ", ed._gizmo_hit(rs))
	ed._begin_drag("rot", rs, false)
	ed._drag_to(rs + Vector2(0, 50))
	ed._release()
	print("ring drag: yaw now ", lamp.rotation.y)
	ed._duplicate()
	print("dup -> ", ed.selected.name, " props ", ed._all_props().size())
	ed._save_all()
	print("file: ", FileAccess.get_file_as_string("res://layouts/site_Hearthmoor.json").substr(0, 400))
	# unsaved delete then leave twice (discard)
	ed._select(lamp)
	ed._delete_selected()
	ed.toggle()
	print("unsaved: still active ", ed.active)
	ed.toggle()
	await get_tree().process_frame
	print("left: active ", ed.active, " lamp visible ", lamp.visible, " pos moved ", (lamp.global_position - p0), " children with add_1: ", hm.has_node("add_1"))
	# simulate new game start applying
	PropLayouts._cache.clear()
	for ch in hm.get_children():
		if ch.has_meta("pid") and not ch.has_meta("site_added"):
			ch.position = ch.get_meta("pos0")
	ed.apply_sites()
	print("after apply_sites: lamp moved ", (lamp.global_position - p0), " add_1 ", hm.has_node("add_1"))
	PropLayouts.reset("site_Hearthmoor")
	# deleting for real
	var l2: Node3D = hm.get_node("lamp_2")
	ed.toggle()
	for i in 5:
		await get_tree().process_frame
	print("re-entered editor, lamp_2 in tree ", l2.is_inside_tree())
	ed.bld = null
	ed.site = hm
	ed._select(l2)
	ed._delete_selected()
	print("lamp_2 hidden in editor: visible ", l2.visible, " in tree ", l2.is_inside_tree())
	ed._save_all()
	ed.toggle()
	await get_tree().process_frame
	print("after leave: lamp_2 in tree ", l2.is_inside_tree(), " exists ", is_instance_valid(l2))
	ed.toggle()
	await get_tree().process_frame
	print("re-entered: lamp_2 back as ghost: in tree ", l2.is_inside_tree(), " visible ", l2.visible, " deleted ", l2.get_meta("deleted", false))
	ed.bld = null
	ed.site = hm
	ed._select(l2)
	ed._delete_selected()
	ed._save_all()
	ed.toggle()
	await get_tree().process_frame
	# only edited objects may differ from where the village code put them
	PropLayouts._cache.clear()
	var moved := 0
	var total := 0
	for ch in hm.get_children():
		if ch.has_meta("pid") and not ch.has_meta("site_added"):
			total += 1
			if (ch as Node3D).position.distance_to(ch.get_meta("pos0")) > 0.001:
				moved += 1
	print("objects ", total, " differing from the original spot: ", moved)
	print("DONE")
	get_tree().quit()
