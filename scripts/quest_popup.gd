class_name QuestPopup
extends PanelContainer
## The "Quest complete" panel: the quest's name, what the quest giver says, and what you got.
## Shown by Online when the server sends a QuestDone event. Click it to close it, or it fades after a few seconds.

const SHOW_SECS := 9.0
static var _current: QuestPopup = null


## d: {title, text, xp, gold, rewards: [{name, n, mat, item}]}
static func present(ui: Node, d: Dictionary) -> void:
	if _current != null and is_instance_valid(_current):
		_current.queue_free()
	var p := QuestPopup.new()
	_current = p
	p._build(ui, d)
	ui.hud_root.add_child(p)
	Sfx.play("trophy", Vector3.INF, -4.0)


func _build(ui: Node, d: Dictionary) -> void:
	name = "QuestPopup"
	z_index = 90
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	custom_minimum_size = Vector2(430, 0)
	offset_left = -215
	offset_right = 215
	offset_top = 70
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.11, 0.094, 0.149, 0.96)
	sb.border_color = ui.EMBER_HI
	sb.set_border_width_all(2)
	sb.border_width_top = 4
	sb.set_corner_radius_all(2)
	sb.set_content_margin_all(16)
	add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	add_child(v)
	var head: Label = ui._outlined(ui._label("QUEST COMPLETE", 26, ui.EMBER_HI, ui.font_label), 6)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(head)
	var title: Label = ui._label(str(d.get("title", "")), 22, ui.TEXT, ui.font_label)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var line := ColorRect.new()
	line.color = ui.LINE
	line.custom_minimum_size = Vector2(0, 2)
	v.add_child(line)
	var text := str(d.get("text", ""))
	if text != "":
		var t: Label = ui._label("\"%s\"" % text, 16, ui.MUTED, null, true)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(t)
	var xp_gold := HBoxContainer.new()
	xp_gold.alignment = BoxContainer.ALIGNMENT_CENTER
	xp_gold.add_theme_constant_override("separation", 22)
	if int(d.get("xp", 0)) > 0:
		xp_gold.add_child(ui._label("+%d XP" % int(d["xp"]), 19, ui.XP_COL))
	if int(d.get("gold", 0)) > 0:
		xp_gold.add_child(ui._label("+%d gold" % int(d["gold"]), 19, ui.EMBER_HI))
	var rewards: Array = d.get("rewards", [])
	if xp_gold.get_child_count() > 0 or not rewards.is_empty():
		var rh: Label = ui._label("Rewards", 15, ui.MUTED)
		rh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(rh)
	if xp_gold.get_child_count() > 0:
		v.add_child(xp_gold)
	if not rewards.is_empty():
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 14)
		v.add_child(row)
		for r: Dictionary in rewards:
			row.add_child(_reward_cell(ui, r))
	var hint: Label = ui._label("click to close", 12, ui.MUTED, ui.font_label)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)
	mouse_filter = Control.MOUSE_FILTER_STOP
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.25)
	tw.tween_interval(SHOW_SECS)
	tw.tween_property(self, "modulate:a", 0.0, 0.6)
	tw.tween_callback(queue_free)


## One reward: its icon (gear or material) with the name under it, and the amount for materials.
func _reward_cell(ui: Node, r: Dictionary) -> Control:
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(110, 0)
	v.add_theme_constant_override("separation", 2)
	var box := PanelContainer.new()
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(64, 64)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var border: Color = ui.LINE
	var name_col: Color = ui.TEXT
	var it: Variant = r.get("item")
	if it is Dictionary and not (it as Dictionary).is_empty():
		icon.texture = Items.icon(it)
		border = Items.color(it)
		name_col = Items.color(it)
	elif r.get("mat") != null and Data.MATERIALS.has(str(r["mat"])):
		icon.texture = Icons.material(str(r["mat"]))
		border = Color(Data.MATERIALS[str(r["mat"])]["color"])
	box.add_theme_stylebox_override("panel", ui._sb(Color("1a1624"), border, 2, 4))
	box.add_child(icon)
	var center := CenterContainer.new()
	center.add_child(box)
	v.add_child(center)
	var n := int(r.get("n", 1))
	var l: Label = ui._label("%s%s" % [str(r.get("name", "")), (" x%d" % n) if n > 1 else ""], 15, name_col, null, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	return v


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		accept_event()
		queue_free()
