class_name BuildEditor
extends Node3D
## The build editor (dev mode, F3). Freezes the game and gives you a free camera so you can pick up the furniture of any
## walk-in building and put it exactly where you want it. Your edits are saved per building kind in res://layouts/
## (see PropLayouts) and show up in every copy of that building the next time it is built, or as soon as you leave the editor.
##
## Camera:  hold right mouse + W A S D (Q down, E up, Shift fast, wheel = speed) · wheel = dolly · F focus selection · T top view
## Edit:    click a piece to select it · drag the arrows (or drag the piece itself) to move · R rotate tool · M move tool
##          arrow keys nudge (Shift bigger, Alt tiny), PageUp / PageDown height, [ ] rotate · Ctrl+D duplicate · Delete removes
##          Ctrl+Z / Ctrl+Y undo / redo · F3 leaves

const PANEL_W := 320.0
const SNAP_MOVE := [0.0, 0.01, 0.05, 0.1, 0.25, 0.5, 1.0]
const SNAP_ROT := [0.0, 1.0, 5.0, 15.0, 45.0, 90.0]

var main: Node
var active := false
var cam: Camera3D
var prev_cam: Camera3D
var bld: Building = null
var selected: Node3D = null
var tool := "move"
var snap_move := 0.25
var snap_rot := 15.0
var undo: Array = []
var redo: Array = []
var exploded := {}          # kind -> the Building that is currently opened up for editing
var touched := {}           # kinds edited this session
var site: Node3D = null     # a village or camp whose outdoor objects are being edited (when no building is open)
var dirty := false          # unsaved edits in the open building
var _discard_armed := 0.0   # second press within this time throws unsaved edits away
var _btn_save_all: Button
var _btn_save_one: Button
var _lbl_dirty: Label
var show_upper := false

var _yaw := 0.0
var _pitch := -0.5
var _look := false
var _speed := 24.0
var _drag := {}
var _gizmo: Node3D
var _g_axes: Array[Node3D] = []
var _g_plane: MeshInstance3D
var _g_ring: MeshInstance3D
var _sel_box: MeshInstance3D
var _sel_mat: StandardMaterial3D
var _lamp: OmniLight3D
var _issues: Array = []
var _reset_armed := 0.0
var _status_t := 0.0
var _last_op_ms := 0

# interface
var _layer: CanvasLayer
var _panel: PanelContainer
var _lbl_building: Label
var _lbl_sel: Label
var _lbl_issues: Label
var _lbl_status: Label
var _lbl_hover: Label
var _btn_floor: Button
var _btn_move: Button
var _btn_rot: Button
var _opt_snap_m: OptionButton
var _opt_snap_r: OptionButton
var _spin: Dictionary = {}
var _list: ItemList
var _opt_add: OptionButton
var _btn_del: Button
var _btn_reset: Button
var _upd := false


func setup(m: Node) -> void:
	main = m
	process_mode = Node.PROCESS_MODE_ALWAYS
	_make_gizmo()
	_build_ui()
	_layer.visible = false
	_gizmo.visible = false
	_sel_box.visible = false


# ================================================================ enter / leave
func toggle() -> void:
	if active:
		if _guard_unsaved("leave"):
			return
		_leave()
	else:
		_enter()


func _enter() -> void:
	if main.get("mode") != "play":
		return
	active = true
	main.mode = "editor"
	prev_cam = main.rig.camera
	cam = Camera3D.new()
	cam.top_level = true
	cam.fov = 70.0
	cam.far = 900.0
	add_child(cam)
	cam.global_transform = prev_cam.global_transform
	var e := cam.global_transform.basis.get_euler()
	_yaw = e.y
	_pitch = e.x
	_lamp = OmniLight3D.new()
	_lamp.omni_range = 30.0
	_lamp.light_energy = 1.2
	_lamp.light_color = Color("fff0d8")
	cam.add_child(_lamp)
	cam.make_current()
	main.ui.visible = false
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_layer.visible = true
	undo.clear()
	redo.clear()
	_select(null)
	for st: Node in get_tree().get_nodes_in_group("tk_sites"):
		TownKit.site_apply(st as Node3D, PropLayouts.get_file("site_" + String(st.name)), false)
		_site_prep(st as Node3D)
	var near := _nearest_building(main.player.global_position, 40.0)
	if near != null:
		_open_building(near)
		_top_view()
	else:
		_set_building_ui()
		_say("Click a building to start editing it")


func _leave() -> void:
	active = false
	dirty = false
	_end_look()
	_drag.clear()
	_select(null)
	# put every opened building back to its normal baked self, and refresh all copies of what was edited
	for k: String in exploded.keys():
		var b: Building = exploded[k]
		if is_instance_valid(b):
			_rebuild(b, false)
	exploded.clear()
	for st: Node in get_tree().get_nodes_in_group("tk_sites"):
		_site_cleanup(st as Node3D)
	site = null
	for k: String in touched.keys():
		_refresh_kind(k)
	touched.clear()
	bld = null
	cam.queue_free()
	prev_cam.make_current()
	main.ui.visible = true
	get_tree().paused = false
	main.mode = "play"
	_layer.visible = false
	_gizmo.visible = false
	_sel_box.visible = false


func _nearest_building(pos: Vector3, within: float) -> Building:
	var best: Building = null
	var bd := within
	for n: Node in get_tree().get_nodes_in_group("tk_buildings"):
		var b := n as Building
		if b == null or not b.has_meta("tk"):
			continue
		var c := b.to_global(Vector3(b.rect.get_center().x, 0, b.rect.get_center().y))
		var d := Vector2(c.x - pos.x, c.z - pos.z).length()
		if d < bd:
			bd = d
			best = b
	return best


# ================================================================ opening buildings for editing
## Replaces a building with a copy whose furniture is made of separate pieces (edit = true) or back to the baked one.
func _rebuild(old: Building, edit: bool, ov: Variant = null) -> Building:
	var tk: Dictionary = old.get_meta("tk")
	TownKit.layout_override = ov
	var nu := TownKit.build(String(tk["kind"]), String(tk["style"]), int(tk["seed"]), float(tk["length"]), edit, PropLayouts.inst_key(old.global_position))
	TownKit.layout_override = null
	if not (nu is Building):
		nu.free()
		return old
	var nb := nu as Building
	nb.transform = old.transform
	var parent := old.get_parent()
	var idx := old.get_index()
	var nm := old.name
	parent.remove_child(old)
	old.queue_free()
	nb.name = nm
	nb.frozen = edit
	parent.add_child(nb)
	parent.move_child(nb, idx)
	if edit:
		if nb.roof != null:
			nb.roof.visible = false
		if nb.upper != null:
			nb.upper.visible = show_upper
	return nb


func _refresh_kind(kind: String) -> void:
	for n: Node in get_tree().get_nodes_in_group("tk_buildings"):
		var b := n as Building
		if b != null and b.has_meta("tk") and String((b.get_meta("tk") as Dictionary)["kind"]) == kind and not b.frozen:
			_rebuild(b, false)


func _open_building(b: Building) -> void:
	if b != bld and _guard_unsaved("switch"):
		return
	dirty = false
	site = null
	if b.frozen:
		bld = b
		_set_building_ui()
		_refresh_list()
		_audit()
		return
	var kind := String((b.get_meta("tk") as Dictionary)["kind"])
	if exploded.has(kind) and is_instance_valid(exploded[kind]):
		_rebuild(exploded[kind], false)
		exploded.erase(kind)
	var nb := _rebuild(b, true)
	exploded[kind] = nb
	touched[kind] = true
	bld = nb
	undo.clear()
	redo.clear()
	_select(null)
	_set_building_ui()
	_refresh_list()
	_audit()


## True (and warns) when there are unsaved edits; a second press within 4 s discards them.
func _guard_unsaved(what: String) -> bool:
	if not dirty:
		return false
	if _discard_armed > 0.0:
		_discard_armed = 0.0
		dirty = false
		return false
	_discard_armed = 4.0
	_say("Unsaved changes in %s! Save them, or do it again to throw them away." % _kind())
	return true


func _inst() -> String:
	if bld == null:
		return ""
	return PropLayouts.inst_key(bld.global_position) if bld != null else ""


## At game start: buildings that have their own saved layout get rebuilt with it.
func apply_instances() -> void:
	for n: Node in get_tree().get_nodes_in_group("tk_buildings"):
		var b := n as Building
		if b == null or not b.has_meta("tk") or b.frozen:
			continue
		var kind := String((b.get_meta("tk") as Dictionary)["kind"])
		if PropLayouts.has_instance(kind, PropLayouts.inst_key(b.global_position)):
			_rebuild(b, false)


func _mark_dirty() -> void:
	dirty = true
	_update_save_ui()


func _update_save_ui() -> void:
	if _lbl_dirty == null:
		return
	_lbl_dirty.text = "● Unsaved changes" if dirty else "Saved"
	_lbl_dirty.modulate = Color("ff9a6a") if dirty else Color(1, 1, 1, 0.55)
	if _btn_save_all != null:
		_btn_save_all.disabled = bld == null and site == null
		_btn_save_one.disabled = bld == null


func _kind() -> String:
	if bld == null and site != null:
		return "site_" + String(site.name)
	return String((bld.get_meta("tk") as Dictionary)["kind"]) if bld != null else ""


# ================================================================ camera
func _process(delta: float) -> void:
	if not active:
		return
	_status_t -= delta
	if _discard_armed > 0.0:
		_discard_armed -= delta
	if _status_t <= 0.0 and _lbl_status.text != "":
		_lbl_status.text = ""
	if _reset_armed > 0.0:
		_reset_armed -= delta
		if _reset_armed <= 0.0:
			_btn_reset.text = "Reset building"
	if _look:
		var v := Vector3.ZERO
		if Input.is_physical_key_pressed(KEY_W):
			v.z -= 1.0
		if Input.is_physical_key_pressed(KEY_S):
			v.z += 1.0
		if Input.is_physical_key_pressed(KEY_A):
			v.x -= 1.0
		if Input.is_physical_key_pressed(KEY_D):
			v.x += 1.0
		if Input.is_physical_key_pressed(KEY_E):
			v.y += 1.0
		if Input.is_physical_key_pressed(KEY_Q):
			v.y -= 1.0
		if v != Vector3.ZERO:
			var sp := _speed * (5.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 1.0)
			var b := cam.global_transform.basis
			cam.global_position += (b.x * v.x + Vector3.UP * v.y + b.z * v.z).normalized() * sp * delta
	_apply_cam_rot()
	_update_gizmo()


func _apply_cam_rot() -> void:
	cam.rotation = Vector3(_pitch, _yaw, 0.0)


func _end_look() -> void:
	if _look:
		_look = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _top_view() -> void:
	if bld == null:
		return
	var c := bld.to_global(Vector3(bld.rect.get_center().x, 0, bld.rect.get_center().y))
	var h := clampf(maxf(bld.rect.size.x, bld.rect.size.y) * 1.05 + 5.0, 10.0, 40.0)
	cam.global_position = c + Vector3(0, h, 0)
	_pitch = -PI * 0.5 + 0.001
	_yaw = bld.global_transform.basis.get_euler().y
	_apply_cam_rot()


func _focus_selected() -> void:
	if selected == null:
		return
	var ab: AABB = selected.get_meta("aabb", AABB(Vector3(-0.5, 0, -0.5), Vector3.ONE))
	var c := selected.to_global(ab.get_center())
	var dist := maxf(3.5, ab.size.length() * 2.2)
	cam.global_position = c + cam.global_transform.basis.z * dist


# ================================================================ input
func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventKey and event.pressed:
		var k := event as InputEventKey
		if (k.keycode == KEY_F3 or k.keycode == KEY_BACKSLASH or (k.keycode == KEY_E and (k.meta_pressed or k.ctrl_pressed))) and not k.echo:
			if _guard_unsaved("leave"):
				get_viewport().set_input_as_handled()
				return
			_leave()
			get_viewport().set_input_as_handled()
			return
		if _key(k):
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				_look = true
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			else:
				_end_look()
			return
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var up := mb.button_index == MOUSE_BUTTON_WHEEL_UP
			if _look:
				_speed = clampf(_speed * (1.2 if up else 1.0 / 1.2), 2.0, 150.0)
			else:
				var step := 1.6 * (4.0 if mb.shift_pressed else 1.0) * (1.0 if up else -1.0)
				cam.global_position -= cam.global_transform.basis.z * step
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_click(mb.position)
			else:
				_release()
			return
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _look:
			_yaw -= mm.relative.x * 0.003
			_pitch = clampf(_pitch - mm.relative.y * 0.003, -PI * 0.5 + 0.001, PI * 0.5 - 0.001)
		elif not _drag.is_empty():
			_drag_to(mm.position)
		else:
			_hover(mm.position)


func _key(k: InputEventKey) -> bool:
	var cmd := k.is_command_or_control_pressed()
	match k.keycode:
		KEY_S:
			if cmd:
				_save_all()
				return true
		KEY_ESCAPE:
			_select(null)
			return true
		KEY_M:
			_set_tool("move")
			return true
		KEY_R:
			if not cmd:
				_set_tool("rotate")
				return true
		KEY_F:
			_focus_selected()
			return true
		KEY_T:
			_top_view()
			return true
		KEY_L:
			_lamp.visible = not _lamp.visible
			return true
		KEY_DELETE, KEY_BACKSPACE:
			_delete_selected()
			return true
		KEY_Z:
			if cmd:
				if k.shift_pressed:
					_redo()
				else:
					_undo()
				return true
		KEY_Y:
			if cmd:
				_redo()
				return true
		KEY_D:
			if cmd:
				_duplicate()
				return true
		KEY_LEFT:
			_nudge(Vector3(-1, 0, 0), k)
			return true
		KEY_RIGHT:
			_nudge(Vector3(1, 0, 0), k)
			return true
		KEY_UP:
			_nudge(Vector3(0, 0, -1), k)
			return true
		KEY_DOWN:
			_nudge(Vector3(0, 0, 1), k)
			return true
		KEY_PAGEUP:
			_nudge(Vector3(0, 1, 0), k)
			return true
		KEY_PAGEDOWN:
			_nudge(Vector3(0, -1, 0), k)
			return true
		KEY_BRACKETLEFT:
			_rotate_by(-1.0, k)
			return true
		KEY_BRACKETRIGHT:
			_rotate_by(1.0, k)
			return true
	return false


# ================================================================ picking
func _ray(pos: Vector2) -> Array:
	return [cam.project_ray_origin(pos), cam.project_ray_normal(pos)]


func _cast(pos: Vector2, mask: int) -> Dictionary:
	var r := _ray(pos)
	var o: Vector3 = r[0]
	var d: Vector3 = r[1]
	var excl: Array[RID] = []
	for i in 6:
		var q := PhysicsRayQueryParameters3D.create(o, o + d * 500.0, mask)
		q.exclude = excl
		var h := get_world_3d().direct_space_state.intersect_ray(q)
		if h.is_empty():
			return h
		var c := h["collider"] as Node
		var p := _prop_of(c)
		if mask == TownKit.PICK_LAYER and p != null and not p.is_visible_in_tree() and not bool(p.get_meta("deleted", false)):
			excl.append(h["rid"])
			continue
		return h
	return {}


## The building whose floor is under the mouse (a ray against the floor plane of each one).
func _building_under(pos: Vector2) -> Building:
	var r := _ray(pos)
	var o: Vector3 = r[0]
	var d: Vector3 = r[1]
	var best: Building = null
	var bt := 1e9
	for n: Node in get_tree().get_nodes_in_group("tk_buildings"):
		var b := n as Building
		if b == null or not b.has_meta("tk"):
			continue
		var inv := b.global_transform.affine_inverse()
		var lo := inv * o
		var ld := inv.basis * d
		if absf(ld.y) < 0.0001:
			continue
		for y: float in [0.6, 1.8]:
			var t: float = (y - lo.y) / ld.y
			if t <= 0.0 or t >= bt:
				continue
			var p: Vector3 = lo + ld * t
			if b.rect.grow(0.4).has_point(Vector2(p.x, p.z)):
				bt = t
				best = b
				break
	return best


func _prop_of(n: Node) -> Node3D:
	var c := n
	while c != null:
		if c.has_meta("prop_id"):
			return c as Node3D
		c = c.get_parent()
	return null


func _building_of(n: Node) -> Building:
	var c := n
	while c != null:
		if c is Building:
			return c as Building
		c = c.get_parent()
	return null


func _hover(pos: Vector2) -> void:
	if _panel.get_global_rect().has_point(pos):
		_lbl_hover.text = ""
		return
	var h := _cast(pos, TownKit.PICK_LAYER)
	if h.is_empty():
		_lbl_hover.text = ""
		return
	var p := _prop_of(h["collider"] as Node)
	_lbl_hover.text = "%s" % (p.name if p != null else "")


func _click(pos: Vector2) -> void:
	var f := get_viewport().gui_get_focus_owner()
	if f != null:
		f.release_focus()
	if selected != null:
		var hit := _gizmo_hit(pos)
		if hit != "":
			_begin_drag(hit, pos, false)
			return
	var h := _cast(pos, TownKit.PICK_LAYER)
	if h.is_empty():
		# a building that is not opened up yet? open it
		var b := _building_under(pos)
		if b != null and b != bld:
			_open_building(b)
			await get_tree().physics_frame   # let the new colliders register
			h = _cast(pos, TownKit.PICK_LAYER)
	if h.is_empty():
		_select(null)
		return
	var p := _prop_of(h["collider"] as Node)
	if p == null:
		return
	var pb := _building_of(p)
	var psite: Node3D = null if pb != null else p.get_parent() as Node3D
	if pb != bld or (pb == null and psite != site):
		if _guard_unsaved("switch"):
			return
		dirty = false
		undo.clear()
		redo.clear()
		bld = pb
		site = psite
		_set_building_ui()
		_refresh_list()
		_audit()
	_select(p)
	if tool == "move":
		_begin_drag("xz", pos, true)


func _release() -> void:
	if _drag.is_empty():
		return
	var d := _drag
	_drag = {}
	if bool(d.get("moved", false)):
		var n: Node3D = d["node"]
		_push_op({"t": "xf", "node": n, "from": d["from"], "to": n.transform})
		_after_edit()


# ================================================================ gizmo
func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.no_depth_test = true
	m.albedo_color = c
	m.render_priority = 20
	return m


func _make_gizmo() -> void:
	_gizmo = Node3D.new()
	_gizmo.top_level = true
	add_child(_gizmo)
	for spec: Array in [[Vector3.RIGHT, Color("ee5048")], [Vector3.UP, Color("5ad25a")], [Vector3.BACK, Color("4a8cf0")]]:
		var dir: Vector3 = spec[0]
		var ax := Node3D.new()
		_gizmo.add_child(ax)
		_g_axes.append(ax)
		var shaft := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.04
		cm.bottom_radius = 0.04
		cm.height = 1.0
		cm.radial_segments = 6
		shaft.mesh = cm
		shaft.material_override = _mat(spec[1])
		shaft.position = dir * 0.62
		var tip := MeshInstance3D.new()
		var tm := CylinderMesh.new()
		tm.top_radius = 0.0
		tm.bottom_radius = 0.08
		tm.height = 0.24
		tm.radial_segments = 8
		tip.mesh = tm
		tip.material_override = _mat(spec[1])
		tip.position = dir * 1.24
		for mi: MeshInstance3D in [shaft, tip]:
			if dir == Vector3.RIGHT:
				mi.rotation_degrees = Vector3(0, 0, -90)
			elif dir == Vector3.BACK:
				mi.rotation_degrees = Vector3(90, 0, 0)
			ax.add_child(mi)
	_g_plane = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.3, 0.03, 0.3)
	_g_plane.mesh = bm
	_g_plane.material_override = _mat(Color("f2d04a"))
	_gizmo.add_child(_g_plane)
	_g_ring = MeshInstance3D.new()
	var tr := TorusMesh.new()
	tr.inner_radius = 0.97
	tr.outer_radius = 1.0
	tr.rings = 48
	tr.ring_segments = 6
	_g_ring.mesh = tr
	_g_ring.material_override = _mat(Color("f0a030"))
	_gizmo.add_child(_g_ring)
	_sel_mat = _mat(Color("ffe060"))
	_sel_box = MeshInstance3D.new()
	_sel_box.top_level = true
	_sel_box.material_override = _sel_mat
	add_child(_sel_box)


func _update_gizmo() -> void:
	var show := selected != null and is_instance_valid(selected) and (bld != null or site != null)
	_gizmo.visible = show
	_sel_box.visible = show
	if not show:
		return
	var gb := (bld if bld != null else site).global_transform.basis.orthonormalized()
	var org := selected.global_position
	var dist := cam.global_position.distance_to(org)
	var sc := clampf(dist * 0.13, 0.5, 6.0)
	_gizmo.global_transform = Transform3D(gb.scaled(Vector3(sc, sc, sc)), org)
	for a in _g_axes:
		a.visible = tool == "move"
	_g_plane.visible = tool == "move"
	_g_ring.visible = tool == "rotate"
	_sel_box.global_transform = selected.global_transform


func _gizmo_axes() -> Array[Vector3]:
	var gb := (bld if bld != null else site).global_transform.basis.orthonormalized()
	return [gb.x, gb.y, gb.z]


func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	if l2 < 0.0001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _gizmo_hit(pos: Vector2) -> String:
	if selected == null or (bld == null and site == null):
		return ""
	var org := selected.global_position
	var sc := _gizmo.scale.x
	if tool == "move":
		var names := ["x", "y", "z"]
		var best := ""
		var bd := 11.0
		var axes := _gizmo_axes()
		for i in 3:
			var a: Vector3 = axes[i]
			var p0 := org + a * sc * 0.15
			var p1 := org + a * sc * 1.35
			if cam.is_position_behind(p0) or cam.is_position_behind(p1):
				continue
			var d := _seg_dist(pos, cam.unproject_position(p0), cam.unproject_position(p1))
			if d < bd:
				bd = d
				best = names[i]
		if not cam.is_position_behind(org):
			var dc := pos.distance_to(cam.unproject_position(org))
			if dc < 15.0 and dc < bd:
				best = "xz"
		return best
	else:
		var r := _ray(pos)
		var up: Vector3 = _gizmo_axes()[1]
		var hit: Variant = Plane(up, org).intersects_ray(r[0], r[1])
		if hit != null:
			var rad := ((hit as Vector3) - org).length()
			if absf(rad - sc) < 0.14 * sc:
				return "rot"
	return ""


# ================================================================ dragging
func _line_t(p0: Vector3, a: Vector3, o: Vector3, d: Vector3) -> float:
	var w0 := p0 - o
	var b := a.dot(d)
	var den := 1.0 - b * b
	if absf(den) < 0.0001:
		return 0.0
	return (b * d.dot(w0) - a.dot(w0)) / den


func _local_of(n: Node3D) -> Dictionary:
	var base: Transform3D = n.get_meta("base")
	var t := base.affine_inverse() * n.transform
	return {"at": t.origin, "yaw": atan2(t.basis.z.x, t.basis.z.z)}


func _set_local(n: Node3D, at: Vector3, yaw: float) -> void:
	var base: Transform3D = n.get_meta("base")
	var t := base * Transform3D(Basis(Vector3.UP, yaw), at)
	if n.has_meta("scale0"):
		t.basis = t.basis.scaled(n.get_meta("scale0"))
	n.transform = t


func _at_from_world(n: Node3D, w: Vector3) -> Vector3:
	var base: Transform3D = n.get_meta("base")
	var par := n.get_parent() as Node3D
	return base.affine_inverse() * (par.global_transform.affine_inverse() * w)


func _begin_drag(mode: String, pos: Vector2, armed: bool) -> void:
	var r := _ray(pos)
	var o: Vector3 = r[0]
	var d: Vector3 = r[1]
	var org := selected.global_position
	var axes := _gizmo_axes()
	var dr := {"mode": mode, "node": selected, "from": selected.transform, "p0": org, "moved": false, "armed": armed, "mouse0": pos}
	var loc := _local_of(selected)
	dr["at0"] = loc["at"]
	dr["yaw0"] = loc["yaw"]
	match mode:
		"x", "y", "z":
			var a: Vector3 = axes["xyz".find(mode)]
			dr["a"] = a
			dr["t0"] = _line_t(org, a, o, d)
		"xz":
			var hit: Variant = Plane(axes[1], org).intersects_ray(o, d)
			dr["off"] = org - (hit as Vector3) if hit != null else Vector3.ZERO
		"rot":
			var hit2: Variant = Plane(axes[1], org).intersects_ray(o, d)
			var v := ((hit2 as Vector3) - org) if hit2 != null else Vector3.BACK
			dr["ang0"] = atan2(v.dot(axes[0]), v.dot(axes[2]))
	_drag = dr


func _snap(v: float, step: float) -> float:
	return snappedf(v, step) if step > 0.0 else v


func _drag_to(pos: Vector2) -> void:
	var dr := _drag
	if bool(dr["armed"]) and pos.distance_to(dr["mouse0"]) < 4.0:
		return
	dr["armed"] = false
	var n: Node3D = dr["node"]
	var r := _ray(pos)
	var o: Vector3 = r[0]
	var d: Vector3 = r[1]
	var axes := _gizmo_axes()
	var org: Vector3 = dr["p0"]
	var at: Vector3 = dr["at0"]
	var yaw: float = dr["yaw0"]
	var mode: String = dr["mode"]
	var fine := Input.is_key_pressed(KEY_ALT)
	var sm := 0.0 if fine else snap_move
	match mode:
		"x", "y", "z":
			var a: Vector3 = dr["a"]
			var t := _line_t(org, a, o, d)
			var w := org + a * (t - float(dr["t0"]))
			var na := _at_from_world(n, w)
			var i := "xyz".find(mode)
			at[i] = _snap(na[i], sm)
		"xz":
			var hit: Variant = Plane(axes[1], org).intersects_ray(o, d)
			if hit == null:
				return
			var na2 := _at_from_world(n, (hit as Vector3) + (dr["off"] as Vector3))
			at.x = _snap(na2.x, sm)
			at.z = _snap(na2.z, sm)
		"rot":
			var hit3: Variant = Plane(axes[1], org).intersects_ray(o, d)
			if hit3 == null:
				return
			var v := (hit3 as Vector3) - org
			var ang := atan2(v.dot(axes[0]), v.dot(axes[2]))
			var ny := yaw + (ang - float(dr["ang0"]))
			var sr := 0.0 if fine else snap_rot
			if sr > 0.0:
				ny = deg_to_rad(snappedf(rad_to_deg(ny), sr))
			yaw = ny
	_set_local(n, at, yaw)
	dr["moved"] = true
	_refresh_fields()


# ================================================================ selection + operations
func _select(n: Node3D) -> void:
	selected = n
	_sel_box.mesh = null
	if n != null:
		var ab: AABB = n.get_meta("aabb", AABB(Vector3(-0.3, 0, -0.3), Vector3(0.6, 0.6, 0.6)))
		var im := ImmediateMesh.new()
		im.surface_begin(Mesh.PRIMITIVE_LINES, _sel_mat)
		var c: Array[Vector3] = []
		for i in 8:
			c.append(ab.position + Vector3(ab.size.x * (i & 1), ab.size.y * ((i >> 1) & 1), ab.size.z * ((i >> 2) & 1)))
		for e: Array in [[0, 1], [2, 3], [4, 5], [6, 7], [0, 2], [1, 3], [4, 6], [5, 7], [0, 4], [1, 5], [2, 6], [3, 7]]:
			im.surface_add_vertex(c[e[0]])
			im.surface_add_vertex(c[e[1]])
		im.surface_end()
		_sel_box.mesh = im
	_set_sel_ui()
	_refresh_fields()
	_color_box()


func _color_box() -> void:
	var bad := false
	if selected != null:
		for s: String in _issues:
			if s.begins_with(String(selected.name) + " "):
				bad = true
	_sel_mat.albedo_color = Color("ff5040") if bad else Color("ffe060")


func _push_op(op: Dictionary) -> void:
	var now := Time.get_ticks_msec()
	if op["t"] == "xf" and not undo.is_empty():
		var last: Dictionary = undo.back()
		if last["t"] == "xf" and last["node"] == op["node"] and now - _last_op_ms < 700 and not bool(op.get("fresh", false)):
			last["to"] = op["to"]
			_last_op_ms = now
			redo.clear()
			return
	_last_op_ms = now
	undo.append(op)
	redo.clear()


func _after_edit() -> void:
	_mark_dirty()
	_audit()
	_refresh_fields()
	_refresh_list()


func _apply_op(op: Dictionary, forward: bool) -> void:
	var n: Node3D = op["node"]
	if not is_instance_valid(n):
		return
	match String(op["t"]):
		"xf":
			n.transform = op["to"] if forward else op["from"]
		"del":
			_set_gone(n, bool(op["on"]) == forward)
		"add":
			_set_gone(n, not forward)


func _undo() -> void:
	if undo.is_empty():
		return
	var op: Dictionary = undo.pop_back()
	_apply_op(op, false)
	redo.append(op)
	_after_edit()


func _redo() -> void:
	if redo.is_empty():
		return
	var op: Dictionary = redo.pop_back()
	_apply_op(op, true)
	undo.append(op)
	_after_edit()


func _nudge(dir: Vector3, k: InputEventKey) -> void:
	if selected == null:
		return
	var step := snap_move if snap_move > 0.0 else 0.05
	if k.shift_pressed:
		step *= 4.0
	if k.alt_pressed:
		step = 0.01
	var before := selected.transform
	var loc := _local_of(selected)
	_set_local(selected, (loc["at"] as Vector3) + dir * step, loc["yaw"])
	_push_op({"t": "xf", "node": selected, "from": before, "to": selected.transform})
	_after_edit()


func _rotate_by(sign: float, k: InputEventKey) -> void:
	if selected == null:
		return
	var step := snap_rot if snap_rot > 0.0 else 5.0
	if k.shift_pressed:
		step *= 3.0
	if k.alt_pressed:
		step = 1.0
	var before := selected.transform
	var loc := _local_of(selected)
	_set_local(selected, loc["at"], float(loc["yaw"]) + deg_to_rad(step * sign))
	_push_op({"t": "xf", "node": selected, "from": before, "to": selected.transform})
	_after_edit()


func _delete_selected() -> void:
	if selected == null:
		return
	var gone := not bool(selected.get_meta("deleted", false))
	_set_gone(selected, gone)
	_push_op({"t": "del", "node": selected, "on": gone, "fresh": true})
	_after_edit()
	_set_sel_ui()


func _restore_all() -> void:
	if bld == null and site == null:
		return
	for n in _all_props():
		if bool(n.get_meta("deleted", false)):
			_set_gone(n, false)
			_push_op({"t": "del", "node": n, "on": false, "fresh": true})
	_after_edit()
	_say("Restored deleted pieces")


func _set_gone(n: Node3D, gone: bool) -> void:
	if n.has_meta("site_prop"):
		TownKit.site_set_gone(n, gone)
	else:
		TownKit.set_prop_deleted(n, gone)


func _all_props() -> Array[Node3D]:
	var out: Array[Node3D] = []
	if bld == null:
		if site != null:
			for ch in site.get_children():
				if ch.has_meta("prop_id"):
					out.append(ch as Node3D)
		return out
	var roots: Array[Node] = [bld]
	if bld.upper != null:
		roots.append(bld.upper)
	for r in roots:
		for ch in r.get_children():
			if ch.has_meta("prop_id"):
				out.append(ch as Node3D)
	return out


func _add_prop(kind: String, at: Vector3, yaw: float, upper: bool) -> Node3D:
	if bld == null and site != null:
		return _add_site_prop(kind, at, yaw) if kind in TownKit.OUTDOOR else null
	if bld == null or not TownKit.PALETTE.has(kind):
		return null
	var tk: Dictionary = bld.get_meta("tk")
	var nmax := 0
	for n in _all_props():
		if String(n.name).begins_with("add_"):
			nmax = maxi(nmax, int(String(n.name).substr(4)))
	var id := "add_%d" % (nmax + 1)
	var b := TownKit.B.new(TownKit.style(String(tk["style"])), 1)
	b.edit_props = true
	if upper and bld.upper != null:
		b.in_upper = true
		b.xf = Transform3D(Basis.IDENTITY, Vector3(0, bld.floor_y, 0))
	else:
		upper = false
	var fn: Callable = TownKit.PALETTE[kind]
	var home := b.xf * Transform3D(Basis(Vector3.UP, yaw), at)
	b.draw_prop(id, kind, home, home, false, true, func(p: Vector3) -> void: fn.call(b, p), b.xf, at, yaw)
	var node := b.prop_node(b.props[0])
	node.set_meta("upper", upper)
	var holder: Node = bld.upper if upper else bld
	holder.add_child(node)
	for ch in node.get_children():
		if ch is StaticBody3D and int(ch.get_meta("layer", 0)) == 18:
			bld.cam_extra.append(ch as StaticBody3D)
	return node


func _duplicate() -> void:
	if selected == null or (bld == null and site == null):
		return
	var kind := String(selected.get_meta("kind", ""))
	var loc := _local_of(selected)
	var off := Vector3(0.5, 0, 0.5)
	var n := _add_prop(kind, (loc["at"] as Vector3) + off, loc["yaw"], bool(selected.get_meta("upper", false)))
	if n == null:
		return
	_push_op({"t": "add", "node": n, "fresh": true})
	_select(n)
	_after_edit()


func _add_from_ui() -> void:
	if bld == null and site == null:
		_say("Open a building or click an outdoor object first")
		return
	var kind := _opt_add.get_item_text(_opt_add.selected)
	var at := Vector3.ZERO
	if bld != null:
		at = Vector3(bld.rect.get_center().x, 0, bld.rect.get_center().y)
	else:
		var r := _ray(get_viewport().get_visible_rect().size * 0.5)
		var o: Vector3 = r[0]
		var d: Vector3 = r[1]
		if absf(d.y) > 0.01:
			var hit: Vector3 = o + d * ((site.global_position.y - o.y) / d.y)
			at = site.to_local(hit)
	var upper := false
	if selected != null:
		var loc := _local_of(selected)
		at = (loc["at"] as Vector3) + Vector3(0.6, 0, 0.6)
		upper = bool(selected.get_meta("upper", false))
	elif bld != null and bld.upper != null and bld.upper.visible:
		upper = true
	var n := _add_prop(kind, at, 0.0, upper)
	if n == null:
		return
	_push_op({"t": "add", "node": n, "fresh": true})
	_select(n)
	_after_edit()


# ================================================================ saving + checking
func _r3(v: float) -> float:
	return snappedf(v, 0.001)


func _layout_data() -> Dictionary:
	var props := {}
	var deleted: Array = []
	var added: Array = []
	for n in _all_props():
		var loc := _local_of(n)
		var at: Vector3 = loc["at"]
		var yaw: float = loc["yaw"]
		var gone := bool(n.get_meta("deleted", false))
		if bool(n.get_meta("added", false)):
			if not gone:
				var spec := {"id": String(n.name), "kind": String(n.get_meta("kind")), "pos": [_r3(at.x), _r3(at.y), _r3(at.z)], "yaw": _r3(rad_to_deg(yaw)), "upper": bool(n.get_meta("upper", false))}
				var hw: float = float((bld.get_meta("tk") as Dictionary).get("hw", 0.0)) if bld != null and bld.has_meta("tk") else 0.0
				var tkd: Dictionary = (bld.get_meta("tk") as Dictionary) if bld != null and bld.has_meta("tk") else {}
				var hd: float = float(tkd.get("hd", 0.0))
				var zc: float = float(tkd.get("zc", 0.0))
				var px := at.x
				var pz := at.z
				# near a wall: save the distance from that wall (houses vary in size), so it stays flush in every one
				if hw > 2.0 and absf(at.x) > hw - 1.6:
					var sgn := signf(at.x)
					spec["ax"] = sgn
					px = at.x - sgn * hw
				if hd > 1.5 and absf(at.z - zc) > hd - 1.6:
					var sgz := signf(at.z - zc)
					spec["az"] = sgz
					pz = at.z - zc - sgz * hd
				if spec.has("ax") or spec.has("az"):
					spec["pos"] = [_r3(px), _r3(at.y), _r3(pz)]
				added.append(spec)
			continue
		if gone:
			deleted.append(String(n.name))
			continue
		var at0: Vector3 = n.get_meta("at0")
		var d := at - at0
		var dr := wrapf(rad_to_deg(yaw - float(n.get_meta("yaw0"))), -180.0, 180.0)
		if d.length() > 0.0005 or absf(dr) > 0.0005:
			props[String(n.name)] = {"d": [_r3(d.x), _r3(d.y), _r3(d.z)], "r": _r3(dr)}
	return {"v": 1, "props": props, "deleted": deleted, "added": added}


## After "Save for all": builds the narrowest and widest version of this kind of building (houses vary in size)
## with the layout just saved, and reports any piece that clips in one of them.
func _variant_check(data: Dictionary) -> Array:
	var out: Array = []
	if bld == null or not bld.has_meta("tk"):
		return out
	var tk: Dictionary = bld.get_meta("tk")
	var kind := String(tk["kind"])
	var lo_seed := int(tk["seed"])
	var hi_seed := lo_seed
	var lo := 1e9
	var hi := -1e9
	for sd in range(0, 40):
		TownKit.layout_override = {}
		var probe := TownKit.build(kind, String(tk["style"]), sd, float(tk["length"]), false, "")
		TownKit.layout_override = null
		var hwv := float((probe.get_meta("tk") as Dictionary).get("hw", 0.0))
		probe.free()
		if hwv < lo:
			lo = hwv
			lo_seed = sd
		if hwv > hi:
			hi = hwv
			hi_seed = sd
	if hi - lo < 0.05:
		return out
	var real_bld := bld
	for sd in [lo_seed, hi_seed]:
		TownKit.layout_override = data
		var vb := TownKit.build(kind, String(tk["style"]), int(sd), float(tk["length"]), true, "")
		TownKit.layout_override = null
		if not (vb is Building):
			vb.free()
			continue
		var holder := Node3D.new()
		add_child(holder)
		holder.add_child(vb)
		bld = vb as Building
		_audit()
		for it in _issues:
			var msg := "%s (%s house)" % [String(it), "narrowest" if sd == lo_seed else "widest"]
			if not out.has(msg) and not String(it).contains("blocks the door"):
				out.append(msg)
		bld = real_bld
		holder.remove_child(vb)
		vb.free()
		holder.free()
	_audit()
	return out


func _save_all() -> void:
	if bld == null and site == null:
		return
	if PropLayouts.save_all(_kind(), _layout_data(), _inst()):
		dirty = false
		touched[_kind()] = true
		var msg := "Saved for every %s" % _kind() + (" (replaced %d single-building edits)" % PropLayouts.last_cleared if PropLayouts.last_cleared > 0 else "")
		if bld != null:
			var warn := _variant_check(_layout_data())
			if not warn.is_empty():
				msg += "\nHeads up, in other sizes: " + ", ".join(warn.slice(0, 3))
		_say(msg, 9.0 if msg.contains("Heads up") else 3.5)
	else:
		_say("Could not write res://layouts/ (is the project folder writable?)")
	_update_save_ui()
	_set_building_ui()


func _save_one() -> void:
	if bld == null:
		_save_all()
		return
	if PropLayouts.save_instance(_kind(), _inst(), _layout_data()):
		dirty = false
		touched[_kind()] = true
		_say("Saved for this %s only" % _kind())
	else:
		_say("Could not write res://layouts/ (is the project folder writable?)")
	_update_save_ui()
	_set_building_ui()


## Throw away unsaved edits: reload the building from what is saved on disk.
func _revert() -> void:
	if bld == null and site == null:
		return
	_reload_edit(null)
	_say("Back to the last saved layout")


func _reload_edit(ov: Variant) -> void:
	if bld == null and site != null:
		_select(null)
		TownKit.site_apply(site, ov if ov is Dictionary else PropLayouts.get_file(_kind()), false)
		_site_prep(site)
		undo.clear()
		redo.clear()
		dirty = false
		_set_building_ui()
		_refresh_list()
		_update_save_ui()
		return
	var b := bld
	_select(null)
	var nb := _rebuild(b, true, ov)
	exploded[_kind_of(nb)] = nb
	bld = nb
	undo.clear()
	redo.clear()
	dirty = false
	_set_building_ui()
	_refresh_list()
	_audit()
	_update_save_ui()


## Gives every outdoor object of a village or camp a pick box and the info the editor tools need.
func _site_prep(st: Node3D) -> void:
	for ch in st.get_children():
		if not ch.has_meta("pid") or ch.has_meta("prop_id"):
			continue
		var n := ch as Node3D
		var ab := AABB()
		var first := true
		var inv := n.global_transform.affine_inverse()
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			if m.mesh == null or m.has_meta("edit_pick"):
				continue
			var rel := inv * m.global_transform
			var a := rel * m.get_aabb()
			ab = a if first else ab.merge(a)
			first = false
		if first or ab.size.length() < 0.1:
			ab = AABB(Vector3(-0.4, 0, -0.4), Vector3(0.8, 1.0, 0.8))
		n.set_meta("prop_id", String(n.get_meta("pid")))
		n.set_meta("site_prop", true)
		n.set_meta("base", Transform3D.IDENTITY)
		n.set_meta("at0", n.get_meta("pos0"))
		n.set_meta("yaw0", n.get_meta("yaw0"))
		n.set_meta("aabb", ab)
		if n.has_meta("site_added"):
			n.set_meta("added", true)
		if not n.has_meta("kind"):
			n.set_meta("kind", String((n.get_meta("tk") as Dictionary)["kind"]) if n.has_meta("tk") else String(n.name).get_slice("_", 0))
		var body := StaticBody3D.new()
		body.name = "EditPick"
		body.collision_layer = TownKit.PICK_LAYER
		body.collision_mask = 0
		body.set_meta("edit_pick", true)
		body.set_meta("layer", TownKit.PICK_LAYER)
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = ab.size.max(Vector3(0.4, 0.4, 0.4))
		cs.shape = bx
		cs.position = ab.get_center()
		body.add_child(cs)
		n.add_child(body)


func _site_cleanup(st: Node3D) -> void:
	TownKit.site_apply(st, PropLayouts.get_file("site_" + String(st.name)))
	for ch in st.get_children():
		if not ch.has_meta("prop_id"):
			continue
		for c in ch.get_children():
			if c.has_meta("edit_pick"):
				c.queue_free()
		for k in ["prop_id", "site_prop", "base", "at0", "aabb", "kind", "added"]:
			ch.remove_meta(k)


## At game start: villages and camps with a saved outdoor layout get it applied.
func apply_sites() -> void:
	for st: Node in get_tree().get_nodes_in_group("tk_sites"):
		var f := PropLayouts.get_file("site_" + String(st.name))
		if not f.is_empty():
			TownKit.site_apply(st as Node3D, f)


func _add_site_prop(kind: String, at: Vector3, yaw: float) -> Node3D:
	var nmax := 0
	for n in _all_props():
		if String(n.name).begins_with("add_"):
			nmax = maxi(nmax, int(String(n.name).substr(4)))
	var n := TownKit.site_make_prop(site, kind, at, yaw, "add_%d" % (nmax + 1))
	n.set_meta("kind", kind)
	_site_prep(site)
	return n


func _kind_of(b: Building) -> String:
	return String((b.get_meta("tk") as Dictionary)["kind"])


func _reset_building() -> void:
	if bld == null and site == null:
		return
	if _reset_armed <= 0.0:
		_reset_armed = 3.0
		_btn_reset.text = "Click again to confirm"
		return
	_reset_armed = 0.0
	_btn_reset.text = "Reset building"
	_reload_edit({})
	_mark_dirty()
	_say("Back to the code layout. Save to keep it (or Revert to undo this)")


static func _aabb_of(t: Transform3D, size: Vector3) -> AABB:
	var h := size * 0.5
	var ex := Vector3(absf(t.basis.x.x) * h.x + absf(t.basis.y.x) * h.y + absf(t.basis.z.x) * h.z,
		absf(t.basis.x.y) * h.x + absf(t.basis.y.y) * h.y + absf(t.basis.z.y) * h.z,
		absf(t.basis.x.z) * h.x + absf(t.basis.y.z) * h.y + absf(t.basis.z.z) * h.z)
	return AABB(t.origin - ex, ex * 2.0)


static func _wallish(a: AABB) -> bool:
	return a.size.y >= 1.8 and minf(a.size.x, a.size.z) <= 0.45


## Looks for pieces clipping into walls or each other, or blocking a door. Fills _issues and the panel text.
func _audit() -> void:
	_issues.clear()
	if bld == null:
		_lbl_issues.text = ""
		return
	var inv := bld.global_transform.affine_inverse()
	var items: Array = []     # [AABB, owner, is_prop]
	var doors: Array = []
	for ch in bld.get_children():
		if ch is Door:
			doors.append(ch)
		elif ch is StaticBody3D:
			for cs in ch.get_children():
				if cs is CollisionShape3D and (cs as CollisionShape3D).shape is BoxShape3D and not (cs as CollisionShape3D).disabled:
					var t: Transform3D = inv * (cs as CollisionShape3D).global_transform
					if absf(t.basis.y.normalized().y) > 0.99:
						items.append([_aabb_of(t, ((cs as CollisionShape3D).shape as BoxShape3D).size), "wall", false])
	for n in _all_props():
		if bool(n.get_meta("deleted", false)):
			continue
		for body in n.get_children():
			if body is StaticBody3D and int(body.get_meta("layer", 0)) == 18:
				for cs in body.get_children():
					if cs is CollisionShape3D and (cs as CollisionShape3D).shape is BoxShape3D:
						var t2: Transform3D = inv * (cs as CollisionShape3D).global_transform
						items.append([_aabb_of(t2, ((cs as CollisionShape3D).shape as BoxShape3D).size), String(n.name), true])
	var seen := {}
	for i in items.size():
		for j in range(i + 1, items.size()):
			var a: Array = items[i]
			var b: Array = items[j]
			if not bool(a[2]) and not bool(b[2]):
				continue
			if a[1] == b[1]:
				continue
			var ov: AABB = (a[0] as AABB).intersection(b[0] as AABB)
			if ov.size.x <= 0.1 or ov.size.y <= 0.1 or ov.size.z <= 0.1:
				continue
			var wall := not bool(a[2]) or not bool(b[2])
			if wall and minf(ov.size.x, ov.size.z) <= 0.16:
				continue
			if wall and _wallish(a[0]) == false and _wallish(b[0]) == false and ov.size.y < 0.15:
				continue
			var prop_a := String(a[1])
			var prop_b := String(b[1])
			var key := prop_a + "|" + prop_b
			if seen.has(key):
				continue
			seen[key] = true
			if wall:
				var who := prop_a if bool(a[2]) else prop_b
				_issues.append("%s is inside a wall" % who)
			else:
				_issues.append("%s overlaps %s" % [prop_a, prop_b])
	for dn in doors:
		var dp: Vector3 = (dn as Door).position
		var dw: float = (dn as Door).door_w
		var zone := AABB(Vector3(dp.x - dw * 0.5 - 0.3, 0.2, dp.z - 1.9), Vector3(dw + 0.6, 1.8, 3.4))
		for it: Array in items:
			if not bool(it[2]):
				continue
			var ab: AABB = it[0]
			if ab.size.y < 0.25:
				continue
			if ab.intersects(zone):
				var s := "%s blocks the door" % String(it[1])
				if not _issues.has(s):
					_issues.append(s)
	var txt := ""
	if _issues.is_empty():
		txt = "No clipping or blocked doors."
	else:
		txt = "%d warning(s):" % _issues.size()
		for s in _issues.slice(0, 7):
			txt += "\n  " + String(s)
		if _issues.size() > 7:
			txt += "\n  ..."
	_lbl_issues.text = txt
	_color_box()


# ================================================================ interface
func _say(t: String, secs := 3.5) -> void:
	if _lbl_status != null:
		_lbl_status.text = t
		_status_t = secs


func _set_tool(t: String) -> void:
	tool = t
	if t == "move":
		_btn_move.button_pressed = true
	else:
		_btn_rot.button_pressed = true


func _panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.05, 0.09, 0.94)
	sb.border_color = Color("ffd27a")
	sb.set_border_width_all(2)
	sb.set_content_margin_all(8)
	return sb


func _head(parent: Control, t: String) -> void:
	var l := Label.new()
	l.text = t
	l.add_theme_color_override("font_color", Color("ffd27a"))
	parent.add_child(l)


func _small_btn(text: String, cb: Callable, toggle := false) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = toggle
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if toggle:
		b.toggled.connect(func(on: bool) -> void: cb.call(on))
	else:
		b.pressed.connect(func() -> void: cb.call())
	return b


func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 90
	add_child(_layer)
	_panel = PanelContainer.new()
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 0.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -PANEL_W - 10.0
	_panel.offset_right = -10.0
	_panel.offset_top = 10.0
	_panel.offset_bottom = -10.0
	_panel.add_theme_stylebox_override("panel", _panel_style())
	_layer.add_child(_panel)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(sc)
	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.custom_minimum_size = Vector2(PANEL_W - 28.0, 0)
	root.add_theme_constant_override("separation", 5)
	sc.add_child(root)
	_head(root, "BUILD EDITOR      F3 leaves")
	_lbl_building = Label.new()
	_lbl_building.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_lbl_building)
	var sv := HBoxContainer.new()
	root.add_child(sv)
	_btn_save_all = _small_btn("Save for all", func() -> void: _save_all())
	_btn_save_one = _small_btn("Save this one only", func() -> void: _save_one())
	sv.add_child(_btn_save_all)
	sv.add_child(_btn_save_one)
	var sv2 := HBoxContainer.new()
	root.add_child(sv2)
	_lbl_dirty = Label.new()
	_lbl_dirty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sv2.add_child(_lbl_dirty)
	sv2.add_child(_small_btn("Revert", func() -> void: _revert()))
	_update_save_ui()
	var row := HBoxContainer.new()
	root.add_child(row)
	_btn_floor = _small_btn("Floor: ground", func() -> void: _toggle_floor())
	row.add_child(_btn_floor)
	row.add_child(_small_btn("Top view (T)", func() -> void: _top_view()))
	_head(root, "TOOL")
	var tr := HBoxContainer.new()
	root.add_child(tr)
	var grp := ButtonGroup.new()
	_btn_move = _small_btn("Move (M)", func(on: bool) -> void:
		if on:
			tool = "move", true)
	_btn_rot = _small_btn("Rotate (R)", func(on: bool) -> void:
		if on:
			tool = "rotate", true)
	_btn_move.button_group = grp
	_btn_rot.button_group = grp
	_btn_move.button_pressed = true
	tr.add_child(_btn_move)
	tr.add_child(_btn_rot)
	var sr := HBoxContainer.new()
	root.add_child(sr)
	var l1 := Label.new()
	l1.text = "Snap  move"
	sr.add_child(l1)
	_opt_snap_m = OptionButton.new()
	_opt_snap_m.focus_mode = Control.FOCUS_NONE
	for v: float in SNAP_MOVE:
		_opt_snap_m.add_item("off" if v == 0.0 else "%s m" % String.num(v, 2))
	_opt_snap_m.select(SNAP_MOVE.find(snap_move))
	_opt_snap_m.item_selected.connect(func(i: int) -> void:
		snap_move = SNAP_MOVE[i]
		_refresh_fields())
	sr.add_child(_opt_snap_m)
	var l2 := Label.new()
	l2.text = " rot"
	sr.add_child(l2)
	_opt_snap_r = OptionButton.new()
	_opt_snap_r.focus_mode = Control.FOCUS_NONE
	for v: float in SNAP_ROT:
		_opt_snap_r.add_item("off" if v == 0.0 else "%d°" % int(v))
	_opt_snap_r.select(SNAP_ROT.find(snap_rot))
	_opt_snap_r.item_selected.connect(func(i: int) -> void: snap_rot = SNAP_ROT[i])
	sr.add_child(_opt_snap_r)
	_head(root, "SELECTED")
	_lbl_sel = Label.new()
	_lbl_sel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_lbl_sel)
	var grid := GridContainer.new()
	grid.columns = 4
	root.add_child(grid)
	for key: String in ["x", "y", "z", "r"]:
		var lb := Label.new()
		lb.text = key.to_upper() if key != "r" else "Rot"
		grid.add_child(lb)
		var sp := SpinBox.new()
		sp.min_value = -200.0
		sp.max_value = 200.0
		sp.step = 0.001
		sp.custom_arrow_step = 0.25
		sp.custom_minimum_size = Vector2(100, 0)
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if key == "r":
			sp.min_value = -360.0
			sp.max_value = 360.0
			sp.step = 0.01
			sp.custom_arrow_step = 15.0
			sp.suffix = "°"
		sp.get_line_edit().text_submitted.connect(func(_t: String) -> void: get_viewport().gui_release_focus())
		sp.value_changed.connect(func(_v: float) -> void: _on_field())
		grid.add_child(sp)
		_spin[key] = sp
	# the grid shows x y on one row and z rot on the next (4 columns = label, field, label, field)
	var r2 := HBoxContainer.new()
	root.add_child(r2)
	r2.add_child(_small_btn("Height +", func() -> void: _nudge(Vector3(0, 1, 0), InputEventKey.new())))
	r2.add_child(_small_btn("Height −", func() -> void: _nudge(Vector3(0, -1, 0), InputEventKey.new())))
	var r3 := HBoxContainer.new()
	root.add_child(r3)
	r3.add_child(_small_btn("Duplicate", func() -> void: _duplicate()))
	_btn_del = _small_btn("Delete", func() -> void: _delete_selected())
	r3.add_child(_btn_del)
	r3.add_child(_small_btn("Focus (F)", func() -> void: _focus_selected()))
	_head(root, "ADD A PIECE")
	var ar := HBoxContainer.new()
	root.add_child(ar)
	_opt_add = OptionButton.new()
	_opt_add.focus_mode = Control.FOCUS_NONE
	_opt_add.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for k: String in TownKit.PALETTE.keys():
		_opt_add.add_item(k)
	ar.add_child(_opt_add)
	ar.add_child(_small_btn("Add", func() -> void: _add_from_ui()))
	_head(root, "PIECES IN THIS BUILDING")
	_list = ItemList.new()
	_list.custom_minimum_size = Vector2(0, 150)
	_list.focus_mode = Control.FOCUS_NONE
	_list.item_selected.connect(func(i: int) -> void:
		var n := _list.get_item_metadata(i) as Node3D
		if n != null and is_instance_valid(n):
			_select(n))
	root.add_child(_list)
	var r4 := HBoxContainer.new()
	root.add_child(r4)
	r4.add_child(_small_btn("Undo", func() -> void: _undo()))
	r4.add_child(_small_btn("Redo", func() -> void: _redo()))
	var r5 := HBoxContainer.new()
	root.add_child(r5)
	r5.add_child(_small_btn("Restore deleted", func() -> void: _restore_all()))
	_btn_reset = _small_btn("Reset building", func() -> void: _reset_building())
	r5.add_child(_btn_reset)
	_head(root, "CHECKS")
	_lbl_issues = Label.new()
	_lbl_issues.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_lbl_issues)
	var help := Label.new()
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.add_theme_font_size_override("font_size", 12)
	help.modulate = Color(1, 1, 1, 0.7)
	help.text = "Hold right mouse + WASD to fly (Q/E down/up, Shift fast, wheel speed). Wheel = dolly. Click a piece, drag the arrows or the piece itself. Arrow keys nudge (Shift bigger, Alt tiny), PageUp/Down height, [ ] rotate, Ctrl+Z undo, Delete removes. Nothing saves by itself: Ctrl/Cmd+S or 'Save for all' updates every copy of this building, 'Save this one only' changes just the one you opened."
	root.add_child(help)
	_lbl_status = Label.new()
	_lbl_status.anchor_left = 0.0
	_lbl_status.anchor_right = 1.0
	_lbl_status.anchor_top = 1.0
	_lbl_status.anchor_bottom = 1.0
	_lbl_status.offset_top = -44.0
	_lbl_status.offset_right = -PANEL_W - 20.0
	_lbl_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_status.add_theme_color_override("font_color", Color("ffd27a"))
	_lbl_status.add_theme_font_size_override("font_size", 18)
	_layer.add_child(_lbl_status)
	_lbl_hover = Label.new()
	_lbl_hover.anchor_left = 0.0
	_lbl_hover.anchor_right = 1.0
	_lbl_hover.anchor_top = 1.0
	_lbl_hover.anchor_bottom = 1.0
	_lbl_hover.offset_top = -80.0
	_lbl_hover.offset_bottom = -50.0
	_lbl_hover.offset_right = -PANEL_W - 20.0
	_lbl_hover.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_layer.add_child(_lbl_hover)


func _toggle_floor() -> void:
	if bld == null or bld.upper == null:
		return
	show_upper = not show_upper
	bld.upper.visible = show_upper
	_btn_floor.text = "Floor: upper" if show_upper else "Floor: ground"


func _fill_palette() -> void:
	if _opt_add == null:
		return
	var want: Array = TownKit.PALETTE.keys() if bld != null else (TownKit.OUTDOOR if site != null else [])
	_opt_add.clear()
	for k: String in want:
		_opt_add.add_item(k)


func _set_building_ui() -> void:
	_fill_palette()
	if bld == null and site != null:
		_lbl_building.text = "Editing outdoor objects: %s\nOnly these objects change; buildings are separate." % site.name
		_btn_floor.disabled = true
		_update_save_ui()
		return
	if bld == null:
		_lbl_building.text = "No building open. Click one in the world (or press F3 near one)."
		_btn_floor.disabled = true
		return
	_lbl_building.text = "Editing: %s\n%s" % [_kind(), "This building has its own layout." if PropLayouts.has_instance(_kind(), _inst()) else "Using the shared %s layout." % _kind()]
	_btn_floor.disabled = bld.upper == null
	_btn_floor.text = "Floor: upper" if (bld.upper != null and bld.upper.visible) else "Floor: ground"
	show_upper = bld.upper != null and bld.upper.visible


func _set_sel_ui() -> void:
	if selected == null:
		_lbl_sel.text = "Nothing selected. Click a piece, or pick one from the list."
		_btn_del.text = "Delete"
		return
	var gone := bool(selected.get_meta("deleted", false))
	_lbl_sel.text = "%s  (%s)%s" % [selected.name, selected.get_meta("kind", ""), "  — deleted" if gone else ""]
	_btn_del.text = "Restore" if gone else "Delete"


func _refresh_fields() -> void:
	if _spin.is_empty():
		return
	_upd = true
	if selected == null:
		for k: String in _spin:
			(_spin[k] as SpinBox).editable = false
	else:
		var loc := _local_of(selected)
		var at: Vector3 = loc["at"]
		(_spin["x"] as SpinBox).set_value_no_signal(snappedf(at.x, 0.001))
		(_spin["y"] as SpinBox).set_value_no_signal(snappedf(at.y, 0.001))
		(_spin["z"] as SpinBox).set_value_no_signal(snappedf(at.z, 0.001))
		(_spin["r"] as SpinBox).set_value_no_signal(snappedf(wrapf(rad_to_deg(float(loc["yaw"])), -180.0, 180.0), 0.01))
		for k: String in _spin:
			var sp := _spin[k] as SpinBox
			sp.editable = true
			sp.custom_arrow_step = (15.0 if snap_rot <= 0.0 else snap_rot) if k == "r" else (snap_move if snap_move > 0.0 else 0.05)
	_upd = false


func _on_field() -> void:
	if _upd or selected == null:
		return
	var before := selected.transform
	var at := Vector3((_spin["x"] as SpinBox).value, (_spin["y"] as SpinBox).value, (_spin["z"] as SpinBox).value)
	_set_local(selected, at, deg_to_rad((_spin["r"] as SpinBox).value))
	_push_op({"t": "xf", "node": selected, "from": before, "to": selected.transform})
	_mark_dirty()
	_audit()


func _refresh_list() -> void:
	_list.clear()
	var ids: Array[Node3D] = _all_props()
	ids.sort_custom(func(a: Node3D, b: Node3D) -> bool: return String(a.name).naturalnocasecmp_to(String(b.name)) < 0)
	for n in ids:
		var gone := bool(n.get_meta("deleted", false))
		var i := _list.add_item("%s%s" % [n.name, "  (deleted)" if gone else ""])
		_list.set_item_metadata(i, n)
		if n == selected:
			_list.select(i)
