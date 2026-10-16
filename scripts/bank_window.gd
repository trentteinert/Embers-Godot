class_name BankWindow
extends PanelContainer
## The bank: your bag on the left (click to store), the bank on the right (click to take back), a search box,
## and, while the server has its development switch on, an "All items" tab to take anything for free.
## Opened by Online when the server sends the bank (you stood at a banker or a bank chest and pressed G).

static var current: BankWindow = null

const COLS_BANK := 8
const COLS_BAG := 5
const CLOSE_DIST := 8.0

var ui: Node
var online: Node
var data := {}
var tab := "bank"
var bank_pos := Vector3.INF
var _search: LineEdit
var _used: Label
var _bank_grid: GridContainer
var _bag_grid: GridContainer
var _tab_bank: Button
var _tab_dev: Button
var _dev_bar: HBoxContainer
var _rarity: OptionButton
var _level: SpinBox


static func present(ui_node: Node, online_node: Node, bank: Dictionary, at: Vector3) -> void:
	if current == null or not is_instance_valid(current):
		current = BankWindow.new()
		current._setup(ui_node, online_node, at)
		ui_node.root.add_child(current)
		Sfx.play("ui_open", Vector3.INF, -4.0)
	current.data = bank
	current.refresh()


static func close() -> void:
	if current != null and is_instance_valid(current):
		current.queue_free()
		Sfx.play("ui_close", Vector3.INF, -4.0)
	current = null


static func is_open() -> bool:
	return current != null and is_instance_valid(current)


## Your bag or bank changed (the server sent new contents).
static func changed() -> void:
	if is_open():
		current.refresh()


func _setup(ui_node: Node, online_node: Node, at: Vector3) -> void:
	ui = ui_node
	online = online_node
	bank_pos = at
	name = "BankWindow"
	z_index = 80
	set_anchors_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(1010, 600)
	offset_left = -505
	offset_right = 505
	offset_top = -310
	offset_bottom = 290
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	add_theme_stylebox_override("panel", ui._sb(Color(0.11, 0.094, 0.149, 0.97), ui.LINE, 2, 3))
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 12)
	add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	m.add_child(v)
	# title row
	var top := HBoxContainer.new()
	v.add_child(top)
	var title: Label = ui._label("BANK", 26, ui.EMBER_HI, ui.font_label)
	top.add_child(title)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	_used = ui._label("", 16, ui.MUTED)
	top.add_child(_used)
	var x := Button.new()
	x.text = " X "
	x.focus_mode = Control.FOCUS_NONE
	x.pressed.connect(BankWindow.close)
	top.add_child(x)
	# search + tabs + dev controls
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	v.add_child(bar)
	_search = LineEdit.new()
	_search.placeholder_text = "Search items..."
	_search.clear_button_enabled = true
	_search.custom_minimum_size = Vector2(300, 34)
	_search.text_changed.connect(func(_t: String) -> void: refresh())
	bar.add_child(_search)
	_tab_bank = _tab_button("Bank", "bank")
	bar.add_child(_tab_bank)
	_tab_dev = _tab_button("All items (dev)", "dev")
	bar.add_child(_tab_dev)
	_dev_bar = HBoxContainer.new()
	_dev_bar.add_theme_constant_override("separation", 6)
	bar.add_child(_dev_bar)
	_dev_bar.add_child(ui._label("Gear rarity (not armor)", 14, ui.MUTED))
	_rarity = OptionButton.new()
	for r in Items.RARITY_NAMES:
		_rarity.add_item(r)
	_rarity.focus_mode = Control.FOCUS_NONE
	_rarity.item_selected.connect(func(_i: int) -> void: refresh())
	_dev_bar.add_child(_rarity)
	_dev_bar.add_child(ui._label("Item level (0 = yours)", 14, ui.MUTED))
	_level = SpinBox.new()
	_level.min_value = 0
	_level.max_value = 20
	_dev_bar.add_child(_level)
	# the two grids
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)
	var left := VBoxContainer.new()
	body.add_child(left)
	left.add_child(ui._label("Your bag (click to store)", 16, ui.MUTED))
	_bag_grid = _scroll_grid(left, COLS_BAG, 350)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(right)
	right.add_child(ui._label("Click: take 1 / store 1    Right-click: 10    Shift-click: all", 14, ui.MUTED))
	_bank_grid = _scroll_grid(right, COLS_BANK, 0)


func _tab_button(text: String, which: String) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func() -> void:
		tab = which
		refresh())
	return b


func _scroll_grid(parent: Control, cols: int, width: int) -> GridContainer:
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if width > 0:
		sc.custom_minimum_size = Vector2(width, 0)
		sc.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(sc)
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", 4)
	g.add_theme_constant_override("v_separation", 4)
	sc.add_child(g)
	return g


func _process(_d: float) -> void:
	var p: Node3D = ui.main.player
	if p == null or bank_pos == Vector3.INF:
		return
	if Vector2(p.global_position.x - bank_pos.x, p.global_position.z - bank_pos.z).length() > CLOSE_DIST:
		BankWindow.close()


# ---------------------------------------------------------------- contents
func _query() -> PackedStringArray:
	var q := _search.text.strip_edges().to_lower()
	return q.split(" ", false)


func _hit(words: PackedStringArray, text: String) -> bool:
	var t := text.to_lower()
	for w in words:
		if not t.contains(w):
			return false
	return true


func _item_text(it: Dictionary) -> String:
	return "%s %s %s %s" % [it.get("name", ""), it.get("slot", ""), it.get("type", ""), Items.RARITY_NAMES[clampi(int(it.get("rarity", 0)), 0, 4)]]


func _mat_text(id: String) -> String:
	return "%s %s" % [Data.MATERIALS[id]["name"], id] if Data.MATERIALS.has(id) else id


func _clear(g: GridContainer) -> void:
	for c in g.get_children():
		g.remove_child(c)
		c.queue_free()


func _cell(g: GridContainer, ref: Array) -> Button:
	var sl = GameUI.ItemSlot.new(ui, "bank")
	sl.ref = ref
	g.add_child(sl)
	return sl


func refresh() -> void:
	if data.is_empty():
		return
	var dev: bool = bool(data.get("dev", false))
	if not dev:
		tab = "bank"
	_tab_dev.visible = dev
	_dev_bar.visible = dev and tab == "dev"
	_tab_bank.button_pressed = tab == "bank"
	_tab_dev.button_pressed = tab == "dev"
	_used.text = "Bank %d / %d" % [int(data.get("used", 0)), int(data.get("cap", 100))]
	var words := _query()
	_fill_bag(words)
	_clear(_bank_grid)
	if tab == "dev":
		_fill_dev(words)
	else:
		_fill_bank(words)


func _fill_bag(words: PackedStringArray) -> void:
	_clear(_bag_grid)
	var inv: Dictionary = online.inv
	var bag: Array = inv.get("bag", [])
	for i in bag.size():
		var it: Dictionary = bag[i]
		if not _hit(words, _item_text(it)):
			continue
		var sl = _cell(_bag_grid, ["bag_item", i])
		sl.set_item(it)
	var mats: Dictionary = inv.get("mats", {})
	var ids: Array = mats.keys()
	ids.sort()
	for id: String in ids:
		if id.begins_with("sturdy_") or not Data.MATERIALS.has(id) or int(mats[id]) <= 0 or not _hit(words, _mat_text(id)):
			continue
		var sl = _cell(_bag_grid, ["bag_mat", id])
		sl.set_mat(id, int(mats[id]))
		sl.tooltip_text = "%s x%d\nClick: store 1 · Right-click: 10 · Shift-click: all" % [Data.MATERIALS[id]["name"], int(mats[id])]


func _fill_bank(words: PackedStringArray) -> void:
	var shown := 0
	var items: Array = data.get("items", [])
	for i in items.size():
		var it: Dictionary = items[i]
		if not _hit(words, _item_text(it)):
			continue
		_cell(_bank_grid, ["bank_item", i]).set_item(it)
		shown += 1
	var mats: Dictionary = data.get("mats", {})
	var ids: Array = mats.keys()
	ids.sort()
	for id: String in ids:
		if not Data.MATERIALS.has(id) or not _hit(words, _mat_text(id)):
			continue
		var sl = _cell(_bank_grid, ["bank_mat", id])
		sl.set_mat(id, int(mats[id]))
		sl.tooltip_text = "%s x%d\nClick: take 1 · Right-click: 10 · Shift-click: all" % [Data.MATERIALS[id]["name"], int(mats[id])]
		shown += 1
	if words.is_empty():
		# empty spaces, so you can see how full the bank is
		var used := int(data.get("used", 0))
		for _k in maxi(0, int(data.get("cap", 100)) - used):
			_cell(_bank_grid, []).set_item({}, "")
	elif shown == 0:
		var l: Label = ui._label("Nothing in the bank matches.", 16, ui.MUTED)
		_bank_grid.add_child(l)


func _fill_dev(words: PackedStringArray) -> void:
	var sel: int = _rarity.selected
	for g: Dictionary in data.get("dev_gear", []):
		var armor_piece: bool = str(g.get("armor", "")) != ""
		var r: int = int(g.get("rarity", 0)) if armor_piece else sel   # an armor design is its rarity; the rest take the one you pick
		var fake := {"uid": 0, "name": "%s (%s)" % [g["name"], Items.RARITY_NAMES[r]], "slot": g["slot"], "type": g["kind"], "rarity": r, "ilvl": 1, "stats": {}, "mat": "b0b4bc", "armor": g.get("armor", "")}
		if not _hit(words, _item_text(fake) + " gear " + str(g.get("armor", ""))):
			continue
		var sl = _cell(_bank_grid, ["dev_gear", g])
		sl.set_item(fake)
		sl.tooltip_text = "New %s %s%s (free)\nClick: one · Set the rarity and level above" % [Items.RARITY_NAMES[r], (str(g["armor"]).capitalize() + " ") if str(g.get("armor", "")) != "" else "", g["name"]]
	for m: Dictionary in data.get("dev_mats", []):
		var id: String = str(m["id"])
		if not Data.MATERIALS.has(id) or not _hit(words, _mat_text(id)):
			continue
		var sl = _cell(_bank_grid, ["dev_mat", id])
		sl.set_mat(id, 1)
		sl.tooltip_text = "%s (free)\nClick: 1 · Right-click: 10 · Shift-click: 99" % Data.MATERIALS[id]["name"]


# ---------------------------------------------------------------- clicks
static func cell_click(sl: Button, right: bool, shift: bool) -> void:
	if not is_open() or sl.ref.is_empty():
		return
	var w := current
	var kind: String = sl.ref[0]
	var n := 99 if shift else (10 if right else 1)
	match kind:
		"bag_item":
			w.online.send({"t": "bank_deposit", "bag": int(sl.ref[1])})
		"bag_mat":
			w.online.send({"t": "bank_deposit", "mat": sl.ref[1], "n": n})
		"bank_item":
			w.online.send({"t": "bank_withdraw", "item": int(sl.ref[1])})
		"bank_mat":
			w.online.send({"t": "bank_withdraw", "mat": sl.ref[1], "n": n})
		"dev_mat":
			w.online.send({"t": "bank_dev_give", "mat": sl.ref[1], "n": n})
		"dev_gear":
			var g: Dictionary = sl.ref[1]
			w.online.send({"t": "bank_dev_give", "slot": g["slot"], "kind": g["kind"], "armor": g.get("armor", ""), "base": g["name"], "rarity": w._rarity.selected, "ilvl": int(w._level.value)})
	Sfx.play("ui_click", Vector3.INF, -8.0)
