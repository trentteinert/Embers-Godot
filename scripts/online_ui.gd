class_name OnlineUI
extends CanvasLayer
## The online-only interface: the Workshop (recipe book that says exactly what you are missing and where to
## get it), the progress bar for gathering and crafting, and the "you can make X now" nudges.
## It only draws what the server sends (`recipes`, `skills`, `nodes`); every button is a request.

const BG := Color(0.075, 0.06, 0.105, 0.96)
const LINE := Color("5a4a6a")
const TEXT := Color("e8dcc8")
const MUTED := Color("9a8fa8")
const EMBER := Color("f2994a")
const GOOD := Color("8ad07a")
const BAD := Color("e8806a")
const WARN := Color("e8c06a")

const TABS := [["all", "All"], ["cook", "Cooking"], ["brew", "Potions"], ["smith", "Smelt & Tools"], ["craft", "Crafts"], ["gear", "Gear"]]

var online: Online
var win: PanelContainer
var _list: VBoxContainer
var _detail: VBoxContainer
var _tab_row: HBoxContainer
var _status: Label
var _search: LineEdit
var _only_can: CheckBox
var _tab := "all"
var _selected := ""
var _bar: PanelContainer
var _bar_label: Label
var _bar_fill: ProgressBar
var _fire_btn: Button
var _rec: Label
var _built_for := ""


func setup(o: Online) -> void:
	online = o
	layer = 30
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_window(root)
	_build_bar(root)
	win.visible = false


func _sb(col: Color, border := LINE, w := 2, r := 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = col
	s.border_color = border
	s.set_border_width_all(w)
	s.set_corner_radius_all(r)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s


func _label(t: String, size := 14, col := TEXT, wrap := false) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _button(t: String, cb: Callable, col := TEXT) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_color_override("font_color", col)
	b.pressed.connect(cb)
	return b


# ================================================================ the workshop window
func _build_window(root: Control) -> void:
	win = PanelContainer.new()
	win.add_theme_stylebox_override("panel", _sb(BG))
	win.set_anchors_preset(Control.PRESET_CENTER)
	win.custom_minimum_size = Vector2(900, 560)
	win.offset_left = -450
	win.offset_right = 450
	win.offset_top = -290
	win.offset_bottom = 270
	root.add_child(win)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	win.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	v.add_child(head)
	var title := _label("WORKSHOP", 20, EMBER)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_status = _label("", 13, MUTED)
	head.add_child(_status)
	head.add_child(_button("Skills (U)", func() -> void: online.main.ui.toggle_side("skills")))
	head.add_child(_button("X", toggle))
	var hint := _label("Everything you can make. Pick one to see exactly what it needs and where to get it. You keep making until you move.", 12, MUTED, true)
	v.add_child(hint)
	_tab_row = HBoxContainer.new()
	_tab_row.add_theme_constant_override("separation", 4)
	v.add_child(_tab_row)
	for t: Array in TABS:
		var b := _button(t[1], func() -> void: _set_tab(t[0]))
		b.toggle_mode = true
		b.name = "tab_" + t[0]
		_tab_row.add_child(b)
	_only_can = CheckBox.new()
	_only_can.text = "Can make now"
	_only_can.focus_mode = Control.FOCUS_NONE
	_only_can.add_theme_font_size_override("font_size", 13)
	_only_can.toggled.connect(func(_on: bool) -> void: _rebuild())
	_tab_row.add_child(_only_can)
	_search = LineEdit.new()
	_search.placeholder_text = "Search..."
	_search.custom_minimum_size = Vector2(160, 0)
	_search.text_changed.connect(func(_t: String) -> void: _rebuild())
	_search.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE:
			_search.release_focus())
	_tab_row.add_child(_search)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(330, 0)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(sc)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 2)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_list)
	var dp := PanelContainer.new()
	dp.add_theme_stylebox_override("panel", _sb(Color(0.11, 0.09, 0.15, 1.0), LINE, 1, 6))
	dp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(dp)
	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 6)
	dp.add_child(_detail)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 10)
	v.add_child(foot)
	_fire_btn = _button("Light a fire (F)", func() -> void: online.send({"t": "light_fire"}), EMBER)
	_fire_btn.visible = false   # fires are not placed by hand any more
	foot.add_child(_fire_btn)
	var tip := _label("Gather: click trees, rocks, plants and ripples in the world.  Cook at a fire.  Smelt and forge in a town.", 12, MUTED, true)
	foot.add_child(tip)
	_set_tab("all")


func toggle() -> void:
	win.visible = not win.visible
	if win.visible:
		_rebuild()


func open(tab := "") -> void:
	if tab != "":
		_set_tab(tab)
	win.visible = true
	_rebuild()


func _set_tab(t: String) -> void:
	_tab = t
	for c: Node in _tab_row.get_children():
		if c is Button:
			(c as Button).button_pressed = c.name == "tab_" + t
	if win.visible:
		_rebuild()


func _category(r: Dictionary) -> String:
	if bool(r["gear"]):
		return "gear"
	match str(r["skill"]):
		"cooking":
			return "cook"
		"herblore":
			return "brew"
		"smithing":
			return "smith"
	return "craft"


func _rebuild() -> void:
	if not is_instance_valid(_list):
		return
	for c: Node in _list.get_children():
		c.queue_free()
	var q := _search.text.strip_edges().to_lower()
	var rows: Array = []
	for r: Dictionary in online.recipes:
		if _tab != "all" and _category(r) != _tab:
			continue
		if _only_can.button_pressed and str(r["state"]) != "ok":
			continue
		if q != "" and not (str(r["name"]).to_lower().contains(q) or str(r["desc"]).to_lower().contains(q)):
			continue
		# gear you cannot reach for a long while is just noise
		if bool(r["gear"]) and str(r["state"]) == "level" and int(r["lvl"]) > _lvl(str(r["skill"])) + 8:
			continue
		rows.append(r)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ra := _rank(a)
		var rb := _rank(b)
		return ra < rb if ra != rb else int(a["lvl"]) < int(b["lvl"]))
	if rows.is_empty():
		_list.add_child(_label("Nothing here yet. Try another tab.", 13, MUTED))
	var found := false
	for r: Dictionary in rows:
		if str(r["id"]) == _selected:
			found = true
		_list.add_child(_row(r))
	if not found and not rows.is_empty():
		_selected = str(rows[0]["id"])
	_show_detail()
	_status.text = "%d can be made now" % _count_ok()
	_fire_btn.disabled = online.inv_count("flint_steel") == 0 or (online.inv_count("oak") + online.inv_count("heartwood")) == 0


func _lvl(skill: String) -> int:
	return online.skill_level(skill)


func _rank(r: Dictionary) -> int:
	return {"ok": 0, "mats": 1, "tool": 1, "station": 2, "level": 3, "have": 4}.get(str(r["state"]), 5)


func _count_ok() -> int:
	var n := 0
	for r: Dictionary in online.recipes:
		if str(r["state"]) == "ok":
			n += 1
	return n


func _row(r: Dictionary) -> Control:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.toggle_mode = true
	b.button_pressed = str(r["id"]) == _selected
	var tag := ""
	var col := TEXT
	match str(r["state"]):
		"ok":
			tag = "  ✓"
			col = GOOD
		"mats":
			tag = "  need items"
			col = WARN
		"station":
			tag = "  go to " + ("a fire" if str(r["station"]) == "fire" else "a town")
			col = MUTED
		"tool":
			tag = "  need a hammer"
			col = WARN
		"level":
			tag = "  %s %d" % [Data.SKILLS[str(r["skill"])]["name"], int(r["lvl"])]
			col = MUTED
		"have":
			tag = "  owned"
			col = MUTED
	b.text = "%s%s" % [r["name"], tag]
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_color_override("font_color", col)
	b.add_theme_color_override("font_pressed_color", col)
	b.add_theme_color_override("font_hover_color", col.lightened(0.25))
	var rid: String = str(r["id"])
	b.pressed.connect(func() -> void:
		_selected = rid
		_rebuild())
	return b


func _show_detail() -> void:
	for c: Node in _detail.get_children():
		c.queue_free()
	var r: Dictionary = {}
	for x: Dictionary in online.recipes:
		if str(x["id"]) == _selected:
			r = x
	if r.is_empty():
		_detail.add_child(_label("Pick something on the left.", 14, MUTED))
		return
	var skill: String = str(r["skill"])
	var sk: Dictionary = Data.SKILLS[skill]
	_detail.add_child(_label(str(r["name"]), 20, TEXT))
	if str(r["desc"]) != "":
		_detail.add_child(_label(str(r["desc"]), 13, MUTED, true))
	var made := _label("Trains %s (+%d XP)" % [sk["name"], int(r["xp"])], 13, Color(sk["color"]).lightened(0.2))
	_detail.add_child(made)
	_detail.add_child(HSeparator.new())
	# the three things that stop you, each ticked or crossed
	var lvl := _lvl(skill)
	_detail.add_child(_check("%s level %d" % [sk["name"], int(r["lvl"])], lvl >= int(r["lvl"]), "(you are %d)" % lvl if lvl < int(r["lvl"]) else ""))
	var where := {"anywhere": "Anywhere", "fire": "At a fire (or in a town)", "forge": "In a town (furnace and anvil)"}
	var st: String = str(r["station"])
	_detail.add_child(_check(str(where.get(st, st)), str(r["state"]) != "station", ""))
	_detail.add_child(_label("You need:", 13, MUTED))
	for c: Dictionary in r["cost"]:
		_detail.add_child(_cost_row(str(c["mat"]), str(c["name"]), int(c["need"]), int(c["have"])))
	if int(r["gold"]) > 0:
		_detail.add_child(_check("%d gold" % int(r["gold"]), online.gold() >= int(r["gold"]), "(you have %d)" % online.gold()))
	var out_txt := "Makes: %s" % ("a piece of gear for your class" if bool(r["gear"]) else "%d × %s" % [int(r["qty"]), _out_name(r)])
	_detail.add_child(_label(out_txt, 13, TEXT))
	if bool(r["burn"]):
		_detail.add_child(_label("Food can burn at low level. Cook more and it burns less.", 12, MUTED, true))
	var why: String = str(r["why"])
	if why != "":
		var box := PanelContainer.new()
		box.add_theme_stylebox_override("panel", _sb(Color(0.2, 0.1, 0.1, 0.9) if str(r["state"]) != "have" else Color(0.1, 0.12, 0.2, 0.9), Color("7a3a3a"), 1, 4))
		box.add_child(_label(why, 13, BAD if str(r["state"]) != "have" else MUTED, true))
		_detail.add_child(box)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail.add_child(sp)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_detail.add_child(row)
	var ok: bool = str(r["state"]) == "ok"
	var can: int = maxi(1, int(r["can"]))
	var multi: bool = not bool(r["gear"]) and can > 1
	var rid: String = str(r["id"])
	var b1 := _button("Make", func() -> void: online.send({"t": "craft", "id": rid, "qty": 1}), GOOD)
	b1.disabled = not ok
	row.add_child(b1)
	if multi:
		var b5 := _button("Make 5", func() -> void: online.send({"t": "craft", "id": rid, "qty": 5}), GOOD)
		b5.disabled = not ok or can < 2
		row.add_child(b5)
		var bm := _button("Make all (%d)" % can, func() -> void: online.send({"t": "craft", "id": rid, "qty": can}), GOOD)
		bm.disabled = not ok
		row.add_child(bm)


func _out_name(r: Dictionary) -> String:
	var o: String = str(r["out"])
	if Data.MATERIALS.has(o):
		return str(Data.MATERIALS[o]["name"])
	return str(r["name"])


func _check(text: String, ok: bool, extra: String) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.add_child(_label("✓" if ok else "✗", 15, GOOD if ok else BAD))
	h.add_child(_label(text + ("  " + extra if extra != "" else ""), 14, TEXT if ok else BAD, true))
	return h


func _cost_row(mat: String, nm: String, need: int, have: int) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var ok := have >= need
	h.add_child(_label("✓" if ok else "✗", 15, GOOD if ok else BAD))
	if Data.MATERIALS.has(mat):
		var tr := TextureRect.new()
		tr.texture = Icons.material(mat)
		tr.custom_minimum_size = Vector2(22, 22)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		h.add_child(tr)
	var l := _label("%s   %d / %d" % [nm, mini(have, need) if ok else have, need], 14, TEXT if ok else BAD)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	if not ok:
		var src := online.source_of(mat)
		if src != "":
			h.tooltip_text = src
	return h


# ================================================================ progress bar
func _build_bar(root: Control) -> void:
	_bar = PanelContainer.new()
	_bar.add_theme_stylebox_override("panel", _sb(Color(0.07, 0.055, 0.1, 0.92), LINE, 1, 6))
	_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_bar.offset_left = -190
	_bar.offset_right = 190
	_bar.offset_top = -168
	_bar.offset_bottom = -118
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_bar)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.add_child(v)
	_bar_label = _label("", 14, TEXT)
	_bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_bar_label)
	_bar_fill = ProgressBar.new()
	_bar_fill.show_percentage = false
	_bar_fill.custom_minimum_size = Vector2(0, 10)
	_bar_fill.max_value = 1.0
	_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_bar_fill)
	_bar.visible = false


## A red "REC" tag at the top of the screen while the movement recorder (F10) is running.
func set_recording(on: bool, frames := 0) -> void:
	if _rec == null:
		_rec = _label("", 20, Color("ff4a4a"))
		_rec.set_anchors_preset(Control.PRESET_CENTER_TOP)
		_rec.offset_left = -170
		_rec.offset_right = 170
		_rec.offset_top = 10
		_rec.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_rec.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		_rec.add_theme_constant_override("outline_size", 6)
		_rec.mouse_filter = Control.MOUSE_FILTER_IGNORE
		get_child(0).add_child(_rec)
	_rec.visible = on
	if on:
		_rec.text = "● REC  %d frames  (F10 to stop and save)" % frames


## Called with your own snapshot entry every tick.
func show_action(kind: String, p: float, label: String) -> void:
	_bar.visible = kind != ""
	if kind == "":
		return
	_bar_label.text = label
	_bar_fill.value = p
