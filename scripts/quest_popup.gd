class_name QuestPopup
extends PanelContainer
## The "Quest complete" panel: the quest's name, what the quest giver says, and what you got.
## Shown by Online when the server sends a QuestDone event. Click it to close it, or it fades after a few seconds.

const SHOW_SECS := 9.0
static var _current: QuestPopup = null


## d: {title, text, xp, gold, rewards: [String]}
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
	var rows: Array = []
	if int(d.get("xp", 0)) > 0:
		rows.append(["+%d XP" % int(d["xp"]), ui.XP_COL])
	if int(d.get("gold", 0)) > 0:
		rows.append(["+%d gold" % int(d["gold"]), ui.EMBER_HI])
	for r in d.get("rewards", []):
		rows.append([str(r), ui.TEXT])
	if not rows.is_empty():
		var rh: Label = ui._label("Rewards", 15, ui.MUTED)
		rh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(rh)
		for r: Array in rows:
			var l: Label = ui._label(str(r[0]), 19, r[1])
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			v.add_child(l)
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


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		accept_event()
		queue_free()
