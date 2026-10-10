class_name DevPanel
extends PanelContainer
## Dev mode tools: fly toggle and teleports to key places. Opened with F2 while dev mode is on.

var main: Node
var _lm_i := {}
var _biome_pts: Array = []


func setup(m: Node) -> void:
	main = m
	visible = false
	anchor_left = 1.0
	anchor_right = 1.0
	offset_left = -280.0
	offset_right = -12.0
	offset_top = 210.0
	z_index = 100
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.05, 0.09, 0.92)
	sb.border_color = Color("ffd27a")
	sb.set_border_width_all(2)
	sb.set_content_margin_all(8)
	add_theme_stylebox_override("panel", sb)


func toggle() -> void:
	if visible:
		visible = false
		return
	_build()
	visible = true


func _build() -> void:
	for c in get_children():
		c.queue_free()
	var w: World = main.world
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	add_child(root)
	var t := Label.new()
	t.text = "DEV TOOLS   (F2 close · F1 fly)"
	root.add_child(t)
	var fly := CheckButton.new()
	fly.text = "Fly  (Space up, C down, Shift fast)"
	fly.button_pressed = main.player.flying
	fly.toggled.connect(func(on: bool) -> void: main.set_flying(on))
	root.add_child(fly)
	var be := Button.new()
	be.text = "Open Build Editor  (\\ or Cmd+E)"
	be.pressed.connect(func() -> void:
		visible = false
		main.build_editor.toggle())
	root.add_child(be)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(250, 300)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(sc)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(box)
	_head(box, "START")
	_btn(box, "Wanderer's Rest", w.camp_pos)
	_head(box, "TOWNS AND CAMPS")
	for st: Dictionary in w.settlements:
		_btn(box, String(st["name"]), st["pos"])
	_head(box, "BOSSES")
	for i in w.altar_pos.size():
		_btn(box, String(Data.BOSSES[i]["name"]), w.altar_pos[i] + Vector3(0, 0, 8))
	_head(box, "ZONES")
	if _biome_pts.is_empty():
		_biome_pts = _zone_centres(w)
	for z in _biome_pts.size():
		if _biome_pts[z] != Vector3.INF:
			var d: Dictionary = Data.ZONES[z]
			_btn(box, "%s  (%d-%d)" % [d["name"], d["lo"], d["hi"]], _biome_pts[z])
	_head(box, "CAVES")
	for i in w.cave_sites.size():
		var s: Dictionary = w.cave_sites[i]
		_btn(box, "Cave %d (%s)" % [i + 1, Data.BIOME_NAMES[int(s["biome"])]], s["pos"])
	_head(box, "LANDMARKS (click again for the next)")
	for kind: String in World.LM_DEFS:
		var kk := kind
		var b := Button.new()
		b.text = String(World.LM_DEFS[kind]["name"])
		b.pressed.connect(func() -> void: _next_landmark(kk))
		box.add_child(b)


func _head(p: Control, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.modulate = Color(1, 0.82, 0.48)
	p.add_child(l)


func _btn(p: Control, text: String, pos: Vector3) -> void:
	var b := Button.new()
	b.text = text
	b.pressed.connect(func() -> void: main.dev_teleport(pos))
	p.add_child(b)


func _next_landmark(kind: String) -> void:
	var list: Array = []
	for lm: Dictionary in main.world.landmarks:
		if String(lm["kind"]) == kind:
			list.append(lm)
	if list.is_empty():
		main.ui.toast("None of those")
		return
	var i: int = int(_lm_i.get(kind, 0)) % list.size()
	_lm_i[kind] = i + 1
	main.dev_teleport((list[i] as Dictionary)["pos"] + Vector3(4, 0, 4))


## A dry land cell near the middle of each zone.
func _zone_centres(w: World) -> Array:
	var sum: Array = []
	var cnt: Array = []
	for z in Data.ZONES.size():
		sum.append(Vector2.ZERO)
		cnt.append(0)
	var st := 8
	for y in range(0, World.N, st):
		for x in range(0, World.N, st):
			var p := w.cell_center(x, y)
			var z := w.lay.zone_at(x, y)
			if z >= 0 and w.height_at(p.x, p.z) > 0.6:
				sum[z] += Vector2(x, y)
				cnt[z] += 1
	var out: Array = []
	for z in Data.ZONES.size():
		if cnt[z] == 0:
			out.append(Vector3.INF)
			continue
		var c: Vector2 = sum[z] / float(cnt[z])
		var best := Vector3.INF
		var bd := 1e18
		for y in range(0, World.N, st):
			for x in range(0, World.N, st):
				if w.lay.zone_at(x, y) != z:
					continue
				var p := w.cell_center(x, y)
				if w.height_at(p.x, p.z) <= 0.6 or w._riv[y * (World.N + 1) + x] > 0.1:
					continue
				var d := Vector2(x, y).distance_squared_to(c)
				if d < bd:
					bd = d
					best = p
		out.append(best)
	return out
