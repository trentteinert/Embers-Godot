class_name GameUI
extends CanvasLayer
## All 2D interface: title screen, HUD (vitals, ability bar, quest, minimap), dialog box,
## world map and the pause menu. Built in code so it's easy to restyle in one place.

const PANEL := Color(0.11, 0.094, 0.149, 0.92)
const PANEL2 := Color("272136")
const LINE := Color("463c5c")
const TEXT := Color("f1e8d4")
const MUTED := Color("a89dba")
const EMBER := Color("f2994a")
const EMBER_HI := Color("ffd27a")
const HP_COL := Color("d9483b")
const XP_COL := Color("6fb3e0")
const STA_COL := Color("b8d05a")
const OUTLINE := Color("0a0810")
const MAX_BAG := 64
const BODY_SCALE := 1.25    # Jersey 10 (body font) runs small, so body text is sized up

const CD_SHADER := """
shader_type canvas_item;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec2 d = UV - vec2(0.5);
	float a = fract(atan(d.x, -d.y) / 6.2831853 + 1.0);
	COLOR = a < progress ? vec4(0.04, 0.03, 0.07, 0.78) : vec4(0.0);
}
"""

var main: Node
var font_body: Font
var font_label: Font

var root: Control
var title_root: Control
var hud_root: Control
var pause_root: Control
var map_root: Control
var dialog_panel: PanelContainer

var _title_classes: GridContainer
var _continue_btn: Button
var _pause_classes: GridContainer
var _dialog_who: Label
var _dialog_text: Label
var _dialog_lines: Array = []
var _dialog_done := Callable()

var _lbl_class: Label
var _lbl_lvl: Label
var _bar_xp: ProgressBar
var _bar_hp: ProgressBar
var _bar_res: ProgressBar
var _bar_sta: ProgressBar
var _buffs: HBoxContainer
var _q_title: Label
var _q_text: Label
var _q_rec: Label
var _q_checks: VBoxContainer
var _q_checks_key := ""
var _minimap: MapView
var _bigmap: MapView
var _lbl_biome: Label
var _tod_icon: MicroIcon
var _tod_label: Label
var ui_scale := 1.0
var _prompt_panel: PanelContainer
var _prompt: Label
var _toasts: VBoxContainer
var _ability_bar: HBoxContainer
var _slots: Array = []
var _last_toast := ""
var _last_toast_t := 0
var _cd_shader: Shader
var _boss_panel: PanelContainer
var _boss_name: Label
var _boss_bar: ProgressBar
var _dead_root: Control
var _low_hp: ColorRect
var _overlay: CombatOverlay
var inv_root: Control
var _inv_slots := {}
var _bag_grid: GridContainer
var _bag_label: Label
var _inv_title: Label
var _inv_doll: SubViewportContainer
var _stats_grid: GridContainer
var _gold_label: Label
var _xp_ticks: Control
const SIDE_BOTTOM := 78.0      # sits right above the gold line and the buttons
const SIDE_W := 332            # matches the width of the button row under it
var side_tab := ""              # "", char, bag, skills, book, settings, cooking, herblore, crafting
var _side: PanelContainer
var _side_title: Label
var _side_char: VBoxContainer
var _side_bag: VBoxContainer
var _side_dyn: VBoxContainer
var _micro_btns := {}
var _micro_row: Control
var _tracker: Control
var _skill_sel := ""
var _win_kind := ""
var _player_portrait: SubViewportContainer
var _dev_tag: Control
var _tgt_root: Control
var _tgt_portrait: SubViewportContainer
var _tgt_name: Label
var _tgt_lvl: Label
var _tgt_hp: ProgressBar
var _tgt_res: ProgressBar
var _sigil_row: HBoxContainer
var _sigil_label: Label
var _sigil_pips: Control
var inv_parts := {"bag": true, "char": true}
var _inv_left: Control
var _inv_right: Control
var _win_root: Control
var _win_vbox: VBoxContainer
var _side_scroll: ScrollContainer
var _side_content: VBoxContainer
var _win_overlay: Control
var _win_title: Label
var _win_body: VBoxContainer
var show_damage_numbers := true
var _side_box: VBoxContainer
var shop_root: Control
var _shop_grid: GridContainer
var _shop_bag: GridContainer
var _shop_gold: Label
var _potion_btn: Button
var forge_root: Control
var _forge_tab := "upgrade"
var _forge_tier := 0
var _forge_slot := "weapon"
var _forge_master := false
var _upg_ref: Array = []
var _forge_views := {}
var _forge_tabs := {}
var _forge_mats: VBoxContainer
var _forge_gold: Label
var _tier_btns: Array = []
var _piece_btns := {}
var _recipe_box: VBoxContainer
var _upg_equip: GridContainer
var _upg_bag: GridContainer
var _upg_detail: VBoxContainer
var _salv_bag: GridContainer
var _inv_mats: Label
var drag_slot: ItemSlot   # bag slot being dragged (drop it outside the panel to drop the item)
var use_src := ""         # material picked up with "Use": the next bag item you click is the target
var _use_ghost: TextureRect
var _ctx_catch: Control
var _ctx_panel: PanelContainer
var _slot_keys: Array = []   # what sits in each bag cell: "" or a stable key
var _restock_btn: Button


# ================================================================ inventory slot
class ItemSlot extends Button:
	var gui: GameUI
	var item := {}
	var kind := "bag"          # "bag" or "equip"
	var index := -1
	var slot_name := ""
	var _icon: TextureRect
	var _empty_label: Label
	var _badge: Label
	var _count: Label
	var mat_id := ""
	var mat_n := 0
	var ref: Array = []
	var pos := -1          # cell in the bag grid

	func _init(g: GameUI, k: String) -> void:
		gui = g
		kind = k
		custom_minimum_size = Vector2(60, 60)
		focus_mode = Control.FOCUS_NONE
		_icon = TextureRect.new()
		_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		_icon.offset_left = 7
		_icon.offset_top = 7
		_icon.offset_right = -7
		_icon.offset_bottom = -7
		_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_icon)
		_empty_label = Label.new()
		_empty_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_empty_label.add_theme_font_override("font", g.font_label)
		_empty_label.add_theme_font_size_override("font_size", 9)
		_empty_label.add_theme_color_override("font_color", Color("5a5068"))
		_empty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_empty_label)
		_badge = Label.new()
		_badge.add_theme_font_override("font", g.font_label)
		_badge.add_theme_font_size_override("font_size", 10)
		_badge.add_theme_color_override("font_color", Color("ffd27a"))
		_badge.add_theme_color_override("font_outline_color", Color("0a0810"))
		_badge.add_theme_constant_override("outline_size", 3)
		_badge.position = Vector2(4, 1)
		_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_badge)
		_count = Label.new()
		_count.add_theme_font_override("font", g.font_label)
		_count.add_theme_font_size_override("font_size", 11)
		_count.add_theme_color_override("font_color", Color.WHITE)
		_count.add_theme_color_override("font_outline_color", Color("0a0810"))
		_count.add_theme_constant_override("outline_size", 3)
		_count.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		_count.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		_count.grow_vertical = Control.GROW_DIRECTION_BEGIN
		_count.offset_right = -4
		_count.offset_bottom = -1
		_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_count)

	## A stack of crafting material in the bag (display only).
	func set_mat(id: String, n: int) -> void:
		item = {}
		mat_id = id
		mat_n = n
		_icon.texture = Icons.material(id)
		var d: Dictionary = Data.MATERIALS[id]
		var col := Color(d["color"])
		var words: PackedStringArray = String(d["name"]).split(" ")
		var ab := ""
		if words.size() > 1:
			for w in words:
				ab += w.substr(0, 1)
		else:
			ab = String(d["name"]).substr(0, 3)
		_empty_label.text = ""
		_empty_label.add_theme_font_size_override("font_size", 13)
		_empty_label.add_theme_color_override("font_color", col.lightened(0.25))
		_badge.text = ""
		_count.text = str(n) if n > 1 else ""
		var armed: bool = gui.use_src == id
		for st in ["normal", "hover", "pressed"]:
			var sb := StyleBoxFlat.new()
			sb.bg_color = col.darkened(0.7).lightened(0.06 if st == "hover" else 0.0)
			sb.border_color = Color("ffd27a") if armed else col.darkened(0.15).lightened(0.3 if st == "hover" else 0.0)
			sb.set_border_width_all(3 if armed else 2)
			add_theme_stylebox_override(st, sb)
		add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		tooltip_text = "%s%s\n%s\nRight-click for options. Drag to move." % [d["name"], (" x%d" % n) if n > 1 else "", d.get("desc", "Crafting material. Stacks up to %d per slot." % Data.STACK_MAX)]

	func set_item(it: Dictionary, label := "") -> void:
		item = it
		mat_id = ""
		mat_n = 0
		_icon.texture = Items.icon(it) if not it.is_empty() else null
		_empty_label.text = "" if not it.is_empty() else label
		_empty_label.add_theme_font_size_override("font_size", 9)
		_empty_label.add_theme_color_override("font_color", Color("5a5068"))
		_count.text = ""
		_badge.text = ("+%d" % int(it.get("upg", 0))) if (not it.is_empty() and int(it.get("upg", 0)) > 0) else ""
		var border := Items.color(it) if not it.is_empty() else Color("3a3248")
		var bg := Color("1a1624") if it.is_empty() else Color("272136")
		var unusable := not it.is_empty() and not Items.can_equip(it, gui.main.player.class_id)
		if unusable:
			bg = Color("3a1a20")
		for st in ["normal", "hover", "pressed"]:
			var sb := StyleBoxFlat.new()
			sb.bg_color = bg.lightened(0.08) if st == "hover" else bg
			sb.border_color = border.lightened(0.3) if st == "hover" else border
			sb.set_border_width_all(2 if st != "hover" else 3)
			add_theme_stylebox_override(st, sb)
		add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		tooltip_text = " " if not it.is_empty() else ("%s (empty)" % label if label != "" else "")

	func _make_custom_tooltip(_for_text: String) -> Object:
		if item.is_empty():
			return null
		var cls: String = gui.main.player.class_id
		var eq: Dictionary = {}
		if kind != "equip":
			eq = (gui.main.state.get("equip", {}) as Dictionary).get(item["slot"], {})
		var p := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.08, 0.065, 0.11, 0.97)
		sb.border_color = Items.color(item)
		sb.set_border_width_all(2)
		sb.set_content_margin_all(12)
		p.add_theme_stylebox_override("panel", sb)
		var r := RichTextLabel.new()
		r.bbcode_enabled = true
		r.fit_content = true
		r.scroll_active = false
		r.custom_minimum_size = Vector2(300, 0)
		r.add_theme_font_override("normal_font", gui.font_body)
		r.add_theme_font_size_override("normal_font_size", 20)
		var hint := ""
		var price := Data.sell_price(item)
		match kind:
			"bag":
				hint = "\n[color=#6a6078]Click to equip · Right-click for options · Drag to move, or out of the bag to drop[/color]"
			"equip":
				hint = "\n[color=#6a6078]Click to unequip[/color]"
			"shop":
				var afford := int(gui.main.state.get("gold", 0)) >= price * 4
				hint = "\n[color=#%s]Price: %d gold[/color]\n[color=#6a6078]Click to buy[/color]" % ["ffd27a" if afford else "e05a4a", price * 4]
			"sell":
				hint = "\n[color=#ffd27a]Sells for %d gold[/color]\n[color=#6a6078]Click to sell[/color]" % price
			"upg":
				hint = "\n[color=#6a6078]Click to choose for upgrading[/color]"
			"salvage":
				var y := Data.salvage_yield(item)
				var parts: Array[String] = []
				for k: String in y["mats"]:
					parts.append("%d %s" % [y["mats"][k], Data.MATERIALS[k]["name"]])
				if float(y["ember_chance"]) > 0.0:
					parts.append("%d%% chance of Ember Shard" % roundi(float(y["ember_chance"]) * 100.0))
				hint = "\n[color=#9fe0a0]Salvage: %s[/color]\n[color=#6a6078]Click to salvage[/color]" % ", ".join(parts)
		r.text = Items.tooltip(item, cls, eq) + hint
		p.add_child(r)
		return p

	func _get_drag_data(_at: Vector2) -> Variant:
		if kind != "bag" or (item.is_empty() and mat_id == ""):
			return null
		gui.drag_slot = self
		gui.cancel_use()
		var prev := Label.new()
		prev.text = ("  %s  " % item["name"]) if not item.is_empty() else ("  %d %s  " % [mat_n, Data.MATERIALS[mat_id]["name"]])
		prev.add_theme_font_size_override("font_size", 19)
		prev.add_theme_color_override("font_color", Items.color(item) if not item.is_empty() else Color(Data.MATERIALS[mat_id]["color"]).lightened(0.3))
		prev.add_theme_stylebox_override("normal", gui._sb(Color("1a1624"), Color("ffd27a"), 2, 4))
		set_drag_preview(prev)
		return {"bag_drag": true, "from": pos}

	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		return kind == "bag" and data is Dictionary and (data as Dictionary).has("bag_drag")

	func _drop_data(_at: Vector2, data: Variant) -> void:
		gui.move_bag(int((data as Dictionary)["from"]), pos)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_DRAG_END and gui != null and gui.drag_slot == self:
			gui.drag_slot = null
			var mp := get_global_mouse_position()
			if gui.over_inventory(mp):
				return
			if mat_id != "":
				gui.main.drop_from_bag(-1, mat_id, mat_n)
			elif not item.is_empty():
				gui.main.drop_from_bag(index, "", 0)

	func _gui_input(event: InputEvent) -> void:
		if kind == "bank":
			if event is InputEventMouseButton and event.pressed and (event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT):
				accept_event()
				BankWindow.cell_click(self, event.button_index == MOUSE_BUTTON_RIGHT, event.shift_pressed)
			return
		# bag slots act on release so that dragging one out to drop it doesn't also trigger it
		if kind == "bag":
			if event is InputEventMouseButton and (event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT):
				accept_event()
				if not event.pressed:
					gui.bag_click(self, event.button_index == MOUSE_BUTTON_RIGHT, event.shift_pressed, event.global_position)
			return
		if event is InputEventMouseButton and event.pressed and (event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT):
			accept_event()
			if item.is_empty():
				return
			match kind:
				"equip":
					gui.main.unequip(slot_name)
				"shop":
					gui.main.buy_item(index)
				"sell":
					gui.main.sell_item(index)
				"upg":
					gui.select_upgrade(ref)
				"salvage":
					gui.main.crafting.salvage(index)


# ================================================================ damage numbers + enemy bars
class CombatOverlay extends Control:
	var main: Node
	var font: Font

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if main == null or not main.combat.active():
			return
		var cam: Camera3D = main.rig.camera
		for e: Enemy in main.combat.enemies:
			if e.is_boss or e.dead:
				continue
			if e.is_elite:
				var wpn := e.global_position + Vector3(0, e.height + 0.8, 0)
				if not cam.is_position_behind(wpn):
					var spn := cam.unproject_position(wpn)
					draw_string_outline(font, spn + Vector2(-100, 0), e.display_name, HORIZONTAL_ALIGNMENT_CENTER, 200, 21, 6, Color(0.04, 0.03, 0.06))
					draw_string(font, spn + Vector2(-100, 0), e.display_name, HORIZONTAL_ALIGNMENT_CENTER, 200, 21, Color("ff8a5a"))
			if e.burrowed or e.global_position.distance_to(main.player.global_position) > 30.0:
				continue
			var wp := e.global_position + Vector3(0, e.height + 0.3, 0)
			if cam.is_position_behind(wp):
				continue
			var sp := cam.unproject_position(wp)
			var w := 54.0 if e.is_elite else 40.0
			var is_tgt: bool = main.target == e
			draw_rect(Rect2(sp.x - w * 0.5 - 2, sp.y - 2, w + 4, 9), Color.WHITE if is_tgt else Color.BLACK)
			draw_rect(Rect2(sp.x - w * 0.5 - 1, sp.y - 1, w + 2, 7), Color(0.08, 0.04, 0.05))
			draw_rect(Rect2(sp.x - w * 0.5, sp.y, w * clampf(e.hp / e.max_hp, 0.0, 1.0), 5), Color("e05a4a") if e.aggro else Color("d8a040"))
		# names over loot on the ground
		var me: Vector3 = main.player.global_position
		for k: Dictionary in main.combat._pickups:
			var lp: Vector3 = k["pos"]
			if lp.distance_to(me) > 22.0:
				continue
			var lw := lp + Vector3(0, 1.3, 0)
			if cam.is_position_behind(lw):
				continue
			var ls := cam.unproject_position(lw)
			var lc: Color = k.get("color", Color("e8d6b0"))
			var ltxt: String = k["name"] if k["kind"] == "item" else "Loot"
			draw_string_outline(font, ls + Vector2(-120, 0), ltxt, HORIZONTAL_ALIGNMENT_CENTER, 240, 16, 5, Color(0.04, 0.03, 0.06, 0.9))
			draw_string(font, ls + Vector2(-120, 0), ltxt, HORIZONTAL_ALIGNMENT_CENTER, 240, 16, lc)
		# gathering progress over your head
		if main.skills.busy():
			var pw: Vector3 = main.player.global_position + Vector3(0, 2.7, 0)
			if not cam.is_position_behind(pw):
				var ps := cam.unproject_position(pw)
				var pcol := Color(Data.SKILLS[main.skills.action["skill"]]["color"]).lightened(0.2)
				draw_rect(Rect2(ps.x - 31, ps.y - 1, 62, 8), Color.BLACK)
				draw_rect(Rect2(ps.x - 30, ps.y, 60 * main.skills.progress(), 6), pcol)
		# what's under the mouse
		var ht: String = main.clicker.hover_text
		if ht != "":
			var hfs := roundi(19 * BODY_SCALE)
			var tw := font.get_string_size(ht, HORIZONTAL_ALIGNMENT_LEFT, -1, hfs).x
			var bw := tw + 20.0
			var bh := font.get_height(hfs) + 10.0
			var bp := get_local_mouse_position() + Vector2(16, 18)
			bp.x = minf(bp.x, size.x - bw - 4.0)
			bp.y = minf(bp.y, size.y - bh - 4.0)
			draw_rect(Rect2(bp, Vector2(bw, bh)), Color(0.07, 0.06, 0.1, 0.92))
			draw_rect(Rect2(bp, Vector2(bw, bh)), Color("f2994a"), false, 1.0)
			draw_string(font, bp + Vector2(10, 5 + font.get_ascent(hfs)), ht, HORIZONTAL_ALIGNMENT_LEFT, -1, hfs, Color("ffd27a"))
		if not main.ui.show_damage_numbers:
			return
		for t: Dictionary in main.combat.texts:
			var wp2: Vector3 = t["pos"]
			if cam.is_position_behind(wp2):
				continue
			var sp2 := cam.unproject_position(wp2)
			var a := clampf(float(t["life"]) * 2.0, 0.0, 1.0)
			var col: Color = t["color"]
			var size := 22 if String(t["text"]).ends_with("!") else 18
			draw_string_outline(font, sp2 + Vector2(-80, 0), t["text"], HORIZONTAL_ALIGNMENT_CENTER, 160, roundi(size * BODY_SCALE), 6, Color(0.04, 0.03, 0.06, a))
			draw_string(font, sp2 + Vector2(-80, 0), t["text"], HORIZONTAL_ALIGNMENT_CENTER, 160, roundi(size * BODY_SCALE), Color(col, a))


# ================================================================ map widget
class MapView extends Control:
	const FOG_SHADER := """
shader_type canvas_item;
uniform sampler2D fog : filter_linear, repeat_disable;
uniform vec4 region;
uniform float world_cells = 1200.0;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1.0, 0.0)), f.x), mix(h(i + vec2(0.0, 1.0)), h(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
	float a = 0.5;
	float s = 0.0;
	for (int k = 0; k < 4; k++) {
		s += a * vn(p);
		p = p * 2.03 + vec2(17.0, 9.0);
		a *= 0.5;
	}
	return s;
}
void fragment() {
	vec2 cell = region.xy + UV * region.zw;
	float e = texture(fog, cell / world_cells).r;
	vec2 q = cell / 70.0;
	float n = fbm(q + vec2(TIME * 0.035, TIME * 0.012));
	float n2 = fbm(q * 1.6 - vec2(TIME * 0.02, -TIME * 0.016) + 5.0);
	float edge = e + (n - 0.5) * 0.7;
	float cover = 1.0 - smoothstep(0.3, 0.6, edge);
	vec3 cl = mix(vec3(0.34, 0.37, 0.47), vec3(0.8, 0.82, 0.9), smoothstep(0.25, 0.8, n2));
	cl = mix(cl, vec3(0.95, 0.96, 1.0), smoothstep(0.35, 0.0, edge) * 0.0);
	COLOR = vec4(cl, cover * 0.98);
}
"""
	var world: World
	var player: Node3D
	var span := 0.0            # cells across; 0 shows the whole map
	var markers: Array = []    # {cell: Vector2, color: Color, size: float, pulse: bool}
	var interactive := false   # the big map: wheel zooms, drag pans
	var min_span := 120.0
	var max_span := float(World.N)
	var center := Vector2(World.N, World.N) * 0.5
	var _t := 0.0
	var _fog: ColorRect
	var _ov: Control
	var _hover := Vector2(-1, -1)
	var _dragging := false

	func _ready() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
		_fog = ColorRect.new()
		_fog.set_anchors_preset(Control.PRESET_FULL_RECT)
		_fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sh := Shader.new()
		sh.code = FOG_SHADER
		var mat := ShaderMaterial.new()
		mat.shader = sh
		_fog.material = mat
		add_child(_fog)
		_ov = Control.new()
		_ov.set_anchors_preset(Control.PRESET_FULL_RECT)
		_ov.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ov.draw.connect(_draw_overlay)
		add_child(_ov)

	func _process(delta: float) -> void:
		_t += delta
		if is_visible_in_tree():
			queue_redraw()
			_ov.queue_redraw()

	func recenter() -> void:
		if player:
			center = world.world_to_cell(player.global_position)
			_clamp_center()

	func _clamp_center() -> void:
		var half := span * 0.5
		center.x = clampf(center.x, half, World.N - half) if span < World.N else World.N * 0.5
		center.y = clampf(center.y, half, World.N - half) if span < World.N else World.N * 0.5

	func _region() -> Rect2:
		var sp := span if span > 0.0 else float(World.N)
		var c := Vector2(World.N, World.N) * 0.5
		if interactive:
			c = center
		elif span > 0.0 and player:
			c = world.world_to_cell(player.global_position)
		return Rect2(c - Vector2(sp, sp) * 0.5, Vector2(sp, sp))

	## Zoom around the middle of the view (the + and - keys).
	func zoom_by(factor: float) -> void:
		span = clampf(span * factor, min_span, max_span)
		_clamp_center()
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if not interactive:
			return
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				var reg := _region()
				var before := reg.position + mb.position / size * reg.size
				span = clampf(span * (0.8 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.25), min_span, max_span)
				# keep the spot under the cursor where it was
				center = before - (mb.position / size - Vector2(0.5, 0.5)) * span
				_clamp_center()
				accept_event()
			elif mb.button_index == MOUSE_BUTTON_LEFT:
				_dragging = mb.pressed
				if mb.pressed and mb.double_click:
					recenter()
				accept_event()
		elif event is InputEventMouseMotion:
			var mm := event as InputEventMouseMotion
			if _dragging:
				center -= mm.relative / size.x * span
				_clamp_center()
			var reg2 := _region()
			_hover = reg2.position + mm.position / size * reg2.size

	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_EXIT:
			_hover = Vector2(-1, -1)
			_dragging = false

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("0b0912"))
		if world == null or world.map_texture == null:
			return
		var region := _region()
		var sc := size.x / region.size.x
		var r := region.intersection(Rect2(0, 0, World.N, World.N))
		if r.size.x > 0 and r.size.y > 0:
			var ms := World.MAP_SCALE
			draw_texture_rect_region(world.map_texture, Rect2((r.position - region.position) * sc, r.size * sc), Rect2(r.position * ms, r.size * ms))
		var mat := _fog.material as ShaderMaterial
		mat.set_shader_parameter("fog", world.fog_tex)
		mat.set_shader_parameter("region", Vector4(region.position.x, region.position.y, region.size.x, region.size.y))
		mat.set_shader_parameter("world_cells", float(World.N))

	## A teardrop centred near p, its point toward dir.
	func _drop(p: Vector2, dir: Vector2, r: float, tip: float) -> PackedVector2Array:
		var c := p - dir * r * 0.35
		var a := dir.angle()
		var cut := 0.95
		var pts := PackedVector2Array([c + dir * tip])
		for i in 11:
			var ang := a + cut + (TAU - 2.0 * cut) * float(i) / 10.0
			pts.append(c + Vector2(cos(ang), sin(ang)) * r)
		return pts

	func _draw_overlay() -> void:
		if world == null:
			return
		var region := _region()
		var sc := size.x / region.size.x
		var drawn_badges: Array[Rect2] = []
		for m: Dictionary in markers:
			var cell: Vector2 = m["cell"]
			if not m.get("pulse", false) and world.explored_at(cell) < 0.4:
				continue
			var p: Vector2 = (cell - region.position) * sc
			var s: float = m["size"]
			if not Rect2(Vector2.ZERO, size).grow(s).has_point(p):
				continue
			if m.has("glyph"):
				# a small labelled badge: ! quest, ? ready, $ shop, + apothecary, F forge, I inn, C chapel, K keep
				if m.get("poi", false) and interactive and span > 300.0:
					continue
				var gb := 6.0 if interactive else 4.5
				var rect_g := Rect2(p - Vector2(gb, gb), Vector2(gb, gb) * 2.0)
				var clash := false
				for dr: Rect2 in drawn_badges:
					if dr.grow(1.5).intersects(rect_g):
						clash = true
				if clash and not m.get("pulse", false):
					continue
				drawn_badges.append(rect_g)
				_ov.draw_rect(rect_g.grow(1.0), Color.BLACK)
				_ov.draw_rect(rect_g, m["color"])
				var gf := ThemeDB.fallback_font
				_ov.draw_string(gf, p + (Vector2(-4.0, 4.5) if interactive else Vector2(-3.0, 3.5)), String(m["glyph"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12 if interactive else 9, Color("1a1420"))
				if m.get("pulse", false) and fmod(_t, 1.0) < 0.5:
					_ov.draw_rect(rect_g.grow(4.0), m["color"], false, 1.0)
				continue
			_ov.draw_rect(Rect2(p - Vector2(s + 1, s + 1), Vector2(s + 1, s + 1) * 2), Color.BLACK)
			_ov.draw_rect(Rect2(p - Vector2(s, s), Vector2(s, s) * 2), m["color"])
			if m.get("pulse", false) and fmod(_t, 1.0) < 0.5:
				_ov.draw_rect(Rect2(p - Vector2(s + 4, s + 4), Vector2(s + 4, s + 4) * 2), m["color"], false, 1.0)
		if player:
			var pp := (world.world_to_cell(player.global_position) - region.position) * sc
			# a raindrop that points the way you face
			var fy: float = (player as Object).get("face_yaw") if player.get("face_yaw") != null else 0.0
			var fd := Vector2(-sin(fy), -cos(fy))
			_ov.draw_colored_polygon(_drop(pp, fd, 5.2, 10.5), Color.BLACK)
			_ov.draw_colored_polygon(_drop(pp, fd, 3.8, 8.6), Color.WHITE)
		if interactive and _hover.x >= 0.0 and _hover.x < World.N and _hover.y >= 0.0 and _hover.y < World.N and world.explored_at(_hover) > 0.6:
			var zi := world.zone_at_cell(_hover.x, _hover.y)
			var txt: String = String(Data.ZONES[zi]["name"]) if zi >= 0 else Data.BIOME_NAMES[int(world.biome[int(_hover.y) * World.N + int(_hover.x)])]
			var font := ThemeDB.fallback_font
			_ov.draw_string_outline(font, Vector2(8, size.y - 8), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 5, Color(0.04, 0.03, 0.06))
			_ov.draw_string(font, Vector2(8, size.y - 8), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("e8d6b0"))


# ================================================================ little HUD widgets
## Divider marks on the XP bar (WoW-style "bubbles").
class XpTicks extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		for i in range(1, 10):
			var x := roundf(size.x * i / 10.0)
			draw_line(Vector2(x, 1), Vector2(x, size.y - 1), Color(0, 0, 0, 0.55), 1.0)


## Simple drawn icons for the micro menu buttons.
class MicroIcon extends Control:
	var kind := ""
	var col := Color("e8d6b0")

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var dark := Color("2a2030")
		match kind:
			"char":
				draw_circle(c + Vector2(0, -5), 5.0, col)
				draw_colored_polygon(PackedVector2Array([c + Vector2(-9, 10), c + Vector2(-7, 3), c + Vector2(0, 1), c + Vector2(7, 3), c + Vector2(9, 10)]), col)
			"bag":
				draw_rect(Rect2(c + Vector2(-8, -3), Vector2(16, 13)), col)
				draw_colored_polygon(PackedVector2Array([c + Vector2(-5, -3), c + Vector2(-3, -8), c + Vector2(3, -8), c + Vector2(5, -3)]), col)
				draw_rect(Rect2(c + Vector2(-6, -4), Vector2(12, 2)), dark)
				draw_rect(Rect2(c + Vector2(-2, 1), Vector2(4, 4)), Color("d8b04a"))
			"book":
				draw_rect(Rect2(c + Vector2(-9, -8), Vector2(18, 16)), Color("8a3a2a"))
				draw_rect(Rect2(c + Vector2(-7, -7), Vector2(6, 14)), col)
				draw_rect(Rect2(c + Vector2(1, -7), Vector2(6, 14)), col)
				for k in 3:
					draw_line(c + Vector2(2, -4 + k * 4), c + Vector2(6, -4 + k * 4), dark, 1.0)
			"map":
				draw_colored_polygon(PackedVector2Array([c + Vector2(-10, -6), c + Vector2(-4, -8), c + Vector2(-4, 8), c + Vector2(-10, 10)]), col)
				draw_colored_polygon(PackedVector2Array([c + Vector2(-4, -8), c + Vector2(4, -6), c + Vector2(4, 10), c + Vector2(-4, 8)]), col.darkened(0.2))
				draw_colored_polygon(PackedVector2Array([c + Vector2(4, -6), c + Vector2(10, -8), c + Vector2(10, 8), c + Vector2(4, 10)]), col)
				draw_circle(c + Vector2(-1, 1), 2.0, Color("d9483b"))
			"gear":
				for k in 8:
					var a := k * TAU / 8.0
					var d := Vector2(cos(a), sin(a))
					var n := Vector2(-d.y, d.x)
					draw_colored_polygon(PackedVector2Array([c + d * 6 + n * 2.2, c + d * 10 + n * 2.2, c + d * 10 - n * 2.2, c + d * 6 - n * 2.2]), col)
				draw_circle(c, 7.0, col)
				draw_circle(c, 3.0, dark)
			"talents":
				# a small branching tree
				draw_line(c + Vector2(0, 10), c + Vector2(0, -2), col, 2.0)
				draw_line(c + Vector2(0, 3), c + Vector2(-7, -3), col, 2.0)
				draw_line(c + Vector2(0, 3), c + Vector2(7, -3), col, 2.0)
				draw_circle(c + Vector2(0, -5), 3.2, col)
				draw_circle(c + Vector2(-7, -6), 2.6, col)
				draw_circle(c + Vector2(7, -6), 2.6, col)
			"abilities":
				var star := PackedVector2Array()
				for k in 10:
					var ang := -PI * 0.5 + k * TAU / 10.0
					var rad := 10.0 if k % 2 == 0 else 4.2
					star.append(c + Vector2(cos(ang), sin(ang)) * rad)
				draw_colored_polygon(star, col)
			"skills":
				for k in 3:
					var hgt := 6.0 + k * 5.0
					draw_rect(Rect2(c + Vector2(-9 + k * 6, 9 - hgt), Vector2(5, hgt)), col)
			"sun":
				draw_circle(c, 4.0, Color("ffd27a"))
				for k in 8:
					var a2 := k * TAU / 8.0
					draw_line(c + Vector2(cos(a2), sin(a2)) * 6.0, c + Vector2(cos(a2), sin(a2)) * 8.5, Color("ffd27a"), 1.5)
			"moon":
				draw_circle(c, 6.0, Color("b8c8f0"))
				draw_circle(c + Vector2(3.5, -2.5), 5.2, Color(0.11, 0.094, 0.149))
			"menu":
				for k in 3:
					draw_rect(Rect2(c + Vector2(-8, -6 + k * 5), Vector2(16, 2.5)), col)


## Little ember-coloured corner ticks that give every panel the same hand-made frame.
class Brackets extends Control:
	var col := Color("f2994a")

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var l := 7.0
		var w := size.x
		var h := size.y
		for c: Array in [[Vector2(0, 0), 1, 1], [Vector2(w, 0), -1, 1], [Vector2(0, h), 1, -1], [Vector2(w, h), -1, -1]]:
			var o: Vector2 = c[0]
			var sx: float = c[1]
			var sy: float = c[2]
			draw_line(o, o + Vector2(l * sx, 0), col, 2.0)
			draw_line(o, o + Vector2(0, l * sy), col, 2.0)


## Portrait + name + bars, used for both the player frame and the target frame.
func _unit_frame(is_player: bool) -> Dictionary:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _sb(PANEL, LINE if is_player else Color("6a3a3a"), 2, 5))
	panel.custom_minimum_size = Vector2(250 if is_player else 280, 0)
	panel.add_child(Brackets.new())
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 7)
	panel.add_child(h)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", _sb(Color("15121e"), EMBER if is_player else Color("b8324a"), 2, 0))
	var por := portrait("warrior" if is_player else "", Vector2(52, 52), false, true)
	frame.add_child(por)
	h.add_child(frame)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(v)
	var who := HBoxContainer.new()
	var nm := _label("", 15)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.clip_text = true
	var lv := _label("", 9, EMBER_HI, font_label)
	who.add_child(nm)
	who.add_child(lv)
	v.add_child(who)
	var hp := _bar(HP_COL if is_player else Color("c0392b"), 14, true)
	var res := _bar(Color.BLUE, 11, true)
	v.add_child(hp)
	v.add_child(res)
	return {"root": panel, "portrait": por, "name": nm, "lvl": lv, "hp": hp, "res": res, "bars": v}


func _update_target() -> void:
	var on: bool = main.has_target() and not (main.target as Enemy).is_boss
	_tgt_root.visible = on
	if not on:
		return
	var e: Enemy = main.target
	_tgt_name.text = e.title()
	_tgt_name.add_theme_color_override("font_color", Color("ff8a5a") if (e.is_elite or e.is_boss) else TEXT)
	_tgt_lvl.text = ("BOSS " if e.is_boss else ("ELITE " if e.is_elite else "")) + "LV %d" % e.level
	_tgt_hp.max_value = e.max_hp
	_tgt_hp.value = e.hp
	(_tgt_hp.get_node("Text") as Label).text = "%d / %d" % [ceili(e.hp), roundi(e.max_hp)]
	_tgt_res.visible = false   # no enemy uses a resource yet; the bar is ready if one does
	var key := ("boss:%d" % e.boss_index) if e.is_boss else ("enemy:%s:%s" % [e.type_id, e.elite_id])
	set_portrait(_tgt_portrait, key)


## Three little diamonds for the sigils you've collected.
class SigilPips extends Control:
	var count := 0
	var col := Color.WHITE

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		for i in 3:
			var c := Vector2(9 + i * 20, size.y * 0.5)
			var pts := PackedVector2Array([c + Vector2(0, -8), c + Vector2(7, 0), c + Vector2(0, 8), c + Vector2(-7, 0)])
			draw_colored_polygon(pts, Color(0.04, 0.03, 0.06))
			var inner := PackedVector2Array([c + Vector2(0, -6), c + Vector2(5, 0), c + Vector2(0, 6), c + Vector2(-5, 0)])
			draw_colored_polygon(inner, col if i < count else Color(0.25, 0.22, 0.3))


func _micro_button(kind: String, title: String, key: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(38, 38)
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = "%s  (%s)" % [title, key]
	b.add_theme_stylebox_override("normal", _sb(PANEL, LINE, 2, 0))
	b.add_theme_stylebox_override("hover", _sb(PANEL2, EMBER_HI, 2, 0))
	b.add_theme_stylebox_override("pressed", _sb(PANEL2, Color.WHITE, 2, 0))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var ic := MicroIcon.new()
	ic.kind = kind
	_full(ic)
	b.add_child(ic)
	var fn: Callable
	match kind:
		"map":
			fn = func() -> void: toggle_map(not map_open())
		_:
			var tab: String = {"char": "char", "bag": "bag", "book": "book", "skills": "skills", "abilities": "abilities", "talents": "talents", "gear": "settings"}.get(kind, "settings")
			fn = func() -> void: toggle_side(tab)
	b.pressed.connect(fn)
	return b


# ================================================================ setup
var _spinners: Array[Node3D] = []


var _bag_sig := 0


func _process(delta: float) -> void:
	# keep an open bag in step with what you pick up, make and use
	if _side != null and _side.visible and (side_tab == "bag" or side_tab == "char") and not main.state.is_empty():
		var sg := hash([main.state.get("mats", {}), main.state.get("potions", 0), main.state.get("bag", []), main.state.get("gold", 0), main.state.get("equip", {}), main.state.get("bag_pos", {})])
		if sg != _bag_sig:
			_bag_sig = sg
			refresh_inventory()
	if _cp_root != null and main != null and main.skills != null:
		_update_craft_progress()
	if _use_ghost != null and _use_ghost.visible:
		_use_ghost.position = get_viewport().get_mouse_position() + Vector2(12, 12)
	for t in _spinners:
		if is_instance_valid(t) and t.is_visible_in_tree():
			t.rotation.y += delta * 0.7


func setup(m: Node) -> void:
	main = m
	process_mode = Node.PROCESS_MODE_ALWAYS
	font_body = load("res://assets/fonts/Jersey10.ttf")
	for fnt: FontFile in [font_body as FontFile, load("res://assets/fonts/Silkscreen.ttf") as FontFile]:
		fnt.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		fnt.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		fnt.hinting = TextServer.HINTING_NONE
	font_label = load("res://assets/fonts/Silkscreen.ttf")
	_cd_shader = Shader.new()
	_cd_shader.code = CD_SHADER
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _make_theme()
	add_child(root)
	_build_hud()
	_build_dialog()
	_build_dead()
	_build_map()
	_build_pause()
	_build_inventory()
	_build_shop()
	_build_forge()
	_build_windows()
	_build_chat()
	_build_title()
	_build_creator()
	_load_game_settings()


func _sb(bg: Color, border: Color, bw := 2, pad := 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_content_margin_all(pad)
	return s


func _make_theme() -> Theme:
	var th := Theme.new()
	th.default_font = font_body
	th.default_font_size = 20
	th.set_stylebox("panel", "PanelContainer", _sb(PANEL, LINE))
	th.set_stylebox("normal", "Button", _sb(PANEL2, LINE, 2, 5))
	th.set_stylebox("hover", "Button", _sb(PANEL2.lightened(0.06), EMBER, 2, 5))
	th.set_stylebox("pressed", "Button", _sb(PANEL2.darkened(0.2), EMBER_HI, 2, 5))
	var focus := _sb(Color(0, 0, 0, 0), EMBER_HI, 2, 8)
	focus.draw_center = false
	th.set_stylebox("focus", "Button", focus)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		th.set_color(c, "Button", TEXT)
	th.set_font("font", "Button", font_label)
	th.set_font_size("font_size", "Button", 12)
	for st: String in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		var cbs := _sb(Color(0, 0, 0, 0) if st != "hover" else Color(1, 1, 1, 0.05), Color(0, 0, 0, 0), 0, 3)
		th.set_stylebox(st, "CheckBox", cbs)
	th.set_font_size("font_size", "CheckBox", 18)
	th.set_color("font_color", "Label", TEXT)
	th.set_stylebox("panel", "TooltipPanel", _sb(PANEL, EMBER, 2, 10))
	th.set_color("font_color", "TooltipLabel", TEXT)
	th.set_font_size("font_size", "TooltipLabel", 20)
	return th


## A little 3D stage showing a hero or NPC model (rendered at half resolution for a chunky look).
func portrait(id: String, min_size: Vector2, spin := false, close := false) -> SubViewportContainer:
	var box := SubViewportContainer.new()
	box.stretch = true
	box.stretch_shrink = 2
	box.custom_minimum_size = min_size
	box.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_DISABLED
	box.add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.52, 0.6)
	env.environment.ambient_light_energy = 1.0
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.6, 0.5, 0)
	sun.light_color = Color("ffe6c4")
	vp.add_child(sun)
	var rim := DirectionalLight3D.new()
	rim.rotation = Vector3(-0.3, PI + 0.6, 0)
	rim.light_color = Color("e08a4a")
	rim.light_energy = 0.6
	vp.add_child(rim)
	var cam := Camera3D.new()
	cam.fov = 32.0
	cam.position = Vector3(0, 1.05, 3.6)
	cam.rotation.x = -0.1
	vp.add_child(cam)
	var turn := Node3D.new()
	turn.name = "Turn"
	vp.add_child(turn)
	turn.rotation.y = 0.45
	if spin:
		_spinners.append(turn)
	box.set_meta("turn", turn)
	box.set_meta("cam", cam)
	box.set_meta("close", close)
	if id != "":
		set_portrait(box, id)
	return box


func set_portrait(box: SubViewportContainer, id: String) -> void:
	var key := id
	if id.begins_with("me:") and main.player != null:
		key = "%s|%d|%d" % [id, main.player.look.hash(), main.player.equipped.hash()]
	if str(box.get_meta("id", "")) == key:
		return
	box.set_meta("id", key)
	var turn: Node3D = box.get_meta("turn")
	for c in turn.get_children():
		c.queue_free()
	var r: Rig
	if id.begins_with("boss:"):
		r = Models.boss(int(id.get_slice(":", 1)))
	elif id.begins_with("enemy:"):
		var d: Dictionary = Data.ENEMIES[id.get_slice(":", 1)]
		var pal: Dictionary = (d["pal"] as Dictionary).duplicate()
		var el := id.get_slice(":", 2)
		if el != "":
			pal.merge(Data.ELITES[el]["pal"], true)
		var rg: Dictionary = d.get("ranged", {})
		if rg.get("kind", "") == "arrow":
			pal["kind"] = "archer"
		elif rg.has("color"):
			pal["orb"] = rg["color"]
		r = Models.creature(d["sprite"], pal)
	elif id.begins_with("me:"):
		r = Models.hero_geared(id.get_slice(":", 1), main.player.equipped, main.player.look)
	elif id == "wisp":
		r = Models.wisp("9fe0ff")
	else:
		r = Models.hero(id)
	turn.add_child(r)
	r.tick(0.016, 0.0)
	_frame_portrait(box, r)


func _frame_portrait(box: SubViewportContainer, r: Rig) -> void:
	var cam: Camera3D = box.get_meta("cam")
	var h := maxf(r.height, 0.5)
	var close: bool = box.get_meta("close", false)
	var look: Vector3
	if close and r.kind == "humanoid":
		look = Vector3(0, h * 0.8, 0)
		cam.position = Vector3(0, h * 0.86, h * 0.95)
	elif close:
		look = Vector3(0, h * 0.5, 0)
		cam.position = Vector3(0, h * 0.75, h * 2.1 + 0.4)
	else:
		look = Vector3(0, h * 0.55, 0)
		cam.position = Vector3(0, h * 0.66, h * 2.25)
	cam.look_at_from_position(cam.position, look, Vector3.UP)


func _label(text: String, size := 18, color := TEXT, font: Font = null, wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size if font != null else roundi(size * BODY_SCALE))
	l.add_theme_color_override("font_color", color)
	if font:
		l.add_theme_font_override("font", font)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _outlined(l: Label, px := 4) -> Label:
	l.add_theme_color_override("font_outline_color", OUTLINE)
	l.add_theme_constant_override("outline_size", px)
	return l


func _bar(col: Color, h: int, with_text: bool) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, h)
	b.max_value = 100
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("0c0a12")
	bg.border_color = Color.BLACK
	bg.set_border_width_all(1)
	var fill := StyleBoxFlat.new()
	fill.bg_color = col
	fill.border_color = col.lightened(0.25)
	fill.border_width_top = 1 if h >= 10 else 0
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fill)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if with_text:
		var l := _outlined(_label("", 11, Color.WHITE, font_label), 3)
		l.set_anchors_preset(Control.PRESET_FULL_RECT)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.name = "Text"
		b.add_child(l)
	return b


func _anchor(c: Control, ax: float, ay: float, ox: float, oy: float, gh: int, gv: int) -> void:
	c.anchor_left = ax
	c.anchor_right = ax
	c.anchor_top = ay
	c.anchor_bottom = ay
	c.offset_left = ox
	c.offset_right = ox
	c.offset_top = oy
	c.offset_bottom = oy
	c.grow_horizontal = gh
	c.grow_vertical = gv


func _full(c: Control) -> Control:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	return c


# ================================================================ HUD
func _build_hud() -> void:
	hud_root = _full(Control.new())
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.visible = false
	root.add_child(hud_root)
	_low_hp = _full(ColorRect.new())
	_low_hp.color = Color(0.55, 0.05, 0.05, 0.0)
	_low_hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(_low_hp)
	_overlay = CombatOverlay.new()
	_full(_overlay)
	_overlay.main = main
	_overlay.font = font_body
	hud_root.add_child(_overlay)
	_boss_panel = PanelContainer.new()
	_boss_panel.add_theme_stylebox_override("panel", _sb(PANEL, Color("b8324a"), 2, 8))
	_anchor(_boss_panel, 0.5, 0, 0, 14, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_END)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 4)
	_boss_panel.add_child(bv)
	_boss_name = _outlined(_label("", 22, Color("ffd6dd")), 4)
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bv.add_child(_boss_name)
	_boss_bar = _bar(Color("b8324a"), 14, false)
	_boss_bar.custom_minimum_size = Vector2(460, 14)
	bv.add_child(_boss_bar)
	_boss_panel.visible = false
	hud_root.add_child(_boss_panel)

	# --- player frame (top left): portrait badge, health, resource, stamina
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	_anchor(left, 0, 0, 14, 14, Control.GROW_DIRECTION_END, Control.GROW_DIRECTION_END)
	hud_root.add_child(left)
	var pf := _unit_frame(true)
	left.add_child(pf["root"])
	_player_portrait = pf["portrait"]
	_lbl_class = pf["name"]
	_lbl_lvl = pf["lvl"]
	_bar_hp = pf["hp"]
	_bar_res = pf["res"]
	_bar_sta = _bar(STA_COL, 5, false)
	(pf["bars"] as VBoxContainer).add_child(_bar_sta)
	_buffs = HBoxContainer.new()
	_buffs.add_theme_constant_override("separation", 6)
	left.add_child(_buffs)
	_dev_tag = _tag("DEV MODE  ·  F1 fly  ·  F2 teleports  ·  unlimited gold, objectives auto-complete", true)
	left.add_child(_dev_tag)
	# --- target frame (to the right of the player frame)
	var tf := _unit_frame(false)
	_tgt_root = tf["root"]
	_tgt_portrait = tf["portrait"]
	_tgt_name = tf["name"]
	_tgt_lvl = tf["lvl"]
	_tgt_hp = tf["hp"]
	_tgt_res = tf["res"]
	_anchor(_tgt_root, 0.5, 0, 0, 14, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_END)
	_tgt_root.visible = false
	hud_root.add_child(_tgt_root)

	# --- minimap (top right)
	var mp := PanelContainer.new()
	mp.add_theme_stylebox_override("panel", _sb(PANEL, LINE, 2, 5))
	mp.add_child(Brackets.new())
	_anchor(mp, 1, 0, -14, 14, Control.GROW_DIRECTION_BEGIN, Control.GROW_DIRECTION_END)
	hud_root.add_child(mp)
	var mv := VBoxContainer.new()
	mv.add_theme_constant_override("separation", 4)
	mp.add_child(mv)
	_minimap = MapView.new()
	_minimap.custom_minimum_size = Vector2(124, 124)
	_minimap.span = 80.0
	_minimap.world = main.world
	_minimap.player = main.player
	_minimap.min_span = 36.0
	_minimap.max_span = 240.0
	mv.add_child(_minimap)
	# + and - to zoom the minimap
	for zb: Array in [["+", 0.75, 0.0], ["-", 1.33, 1.0]]:
		var zbtn := Panel.new()
		var zsb := StyleBoxFlat.new()
		zsb.bg_color = Color(0.05, 0.04, 0.08, 0.8)
		zsb.border_color = Color("f2994a")
		zsb.set_border_width_all(1)
		zbtn.add_theme_stylebox_override("panel", zsb)
		zbtn.custom_minimum_size = Vector2(14, 12)
		zbtn.size = Vector2(14, 12)
		zbtn.position = Vector2(3.0 + float(zb[2]) * 17.0, 106.0)
		zbtn.z_index = 10
		zbtn.mouse_filter = Control.MOUSE_FILTER_STOP
		var zl := Label.new()
		zl.text = zb[0]
		zl.add_theme_font_size_override("font_size", 10)
		zl.add_theme_color_override("font_color", Color("f1e8d4"))
		zl.set_anchors_preset(Control.PRESET_FULL_RECT)
		zl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		zl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		zl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		zbtn.add_child(zl)
		var fct: float = zb[1]
		zbtn.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
				_minimap.zoom_by(fct))
		_minimap.add_child(zbtn)
	_lbl_biome = _label("", 9, MUTED, font_label)
	_lbl_biome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_biome.custom_minimum_size = Vector2(124, 0)
	_lbl_biome.clip_text = true
	mv.add_child(_lbl_biome)
	var tod_row := HBoxContainer.new()
	tod_row.alignment = BoxContainer.ALIGNMENT_CENTER
	tod_row.add_theme_constant_override("separation", 4)
	_tod_icon = MicroIcon.new()
	_tod_icon.custom_minimum_size = Vector2(18, 16)
	_tod_icon.kind = "sun"
	tod_row.add_child(_tod_icon)
	_tod_label = _label("", 9, EMBER_HI, font_label)
	tod_row.add_child(_tod_label)
	mv.add_child(tod_row)

	# --- quest tracker (right side, under the map): just text, no box
	var tracker := VBoxContainer.new()
	tracker.name = "Tracker"
	tracker.add_theme_constant_override("separation", 2)
	tracker.custom_minimum_size = Vector2(250, 0)
	tracker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchor(tracker, 1, 0, -14, 186, Control.GROW_DIRECTION_BEGIN, Control.GROW_DIRECTION_END)
	hud_root.add_child(tracker)
	_q_title = _outlined(_label("", 17, EMBER_HI), 6)
	_q_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_q_text = _outlined(_label("", 14, TEXT, null, true), 6)
	_q_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_q_text.custom_minimum_size = Vector2(250, 0)
	_q_rec = _outlined(_label("", 10, MUTED, font_label), 3)
	_q_rec.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tracker.add_child(_q_title)
	tracker.add_child(_q_text)
	_q_checks = VBoxContainer.new()
	_q_checks.add_theme_constant_override("separation", 1)
	_q_checks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tracker.add_child(_q_checks)
	tracker.add_child(_q_rec)
	_sigil_row = HBoxContainer.new()
	_sigil_row.alignment = BoxContainer.ALIGNMENT_END
	_sigil_row.add_theme_constant_override("separation", 6)
	_sigil_label = _outlined(_label("", 13, TEXT), 5)
	_sigil_row.add_child(_sigil_label)
	_sigil_pips = SigilPips.new()
	_sigil_pips.custom_minimum_size = Vector2(60, 18)
	_sigil_row.add_child(_sigil_pips)
	tracker.add_child(_sigil_row)
	_side_box = VBoxContainer.new()
	_side_box.add_theme_constant_override("separation", 1)
	_side_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tracker.add_child(_side_box)

	# --- bottom: vitals + ability bar
	var bottom := VBoxContainer.new()
	bottom.add_theme_constant_override("separation", 8)
	_anchor(bottom, 0.5, 1, -44, -16, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_BEGIN)   # nudged left to clear the menu buttons
	hud_root.add_child(bottom)
	# XP bar sits right on top of the skills
	_bar_xp = _bar(Color("9a6ae0"), 8, false)
	_bar_xp.mouse_filter = Control.MOUSE_FILTER_PASS
	bottom.add_child(_bar_xp)
	_xp_ticks = XpTicks.new()
	_full(_xp_ticks)
	_bar_xp.add_child(_xp_ticks)
	_ability_bar = HBoxContainer.new()
	_ability_bar.add_theme_constant_override("separation", 6)
	_ability_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_child(_ability_bar)
	bottom.add_theme_constant_override("separation", 6)

	# --- micro menu (bottom right), like WoW
	var br := VBoxContainer.new()
	br.add_theme_constant_override("separation", 6)
	_anchor(br, 1, 1, -12, -12, Control.GROW_DIRECTION_BEGIN, Control.GROW_DIRECTION_BEGIN)
	hud_root.add_child(br)
	_gold_label = _outlined(_label("", 16, EMBER_HI), 5)
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	br.add_child(_gold_label)
	var micro := HBoxContainer.new()
	micro.add_theme_constant_override("separation", 4)
	br.add_child(micro)
	_micro_row = micro
	for spec: Array in [["char", "Character", "K"], ["skills", "Skills", "U"], ["abilities", "Abilities", "N"], ["talents", "Talents", "T"], ["bag", "Bags", "B"], ["book", "Quest Book", "L"], ["map", "World Map", "M"], ["gear", "Settings & menu", "O / Esc"]]:
		var mbt := _micro_button(spec[0], spec[1], spec[2])
		_micro_btns[spec[0]] = mbt
		micro.add_child(mbt)

	# --- the side panel (RuneScape style): sits above the buttons, the game keeps running
	_side = PanelContainer.new()
	_side.add_theme_stylebox_override("panel", _sb(Color(0.09, 0.075, 0.12, 0.94), LINE, 2, 8))
	_side.add_child(Brackets.new())
	_anchor(_side, 1, 1, -14, -SIDE_BOTTOM, Control.GROW_DIRECTION_BEGIN, Control.GROW_DIRECTION_BEGIN)
	_side.custom_minimum_size = Vector2(SIDE_W, 460)
	_side.visible = false
	hud_root.add_child(_side)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 5)
	_side.add_child(sv)
	var sh := HBoxContainer.new()
	_side_title = _label("", 15, EMBER_HI, font_label)
	_side_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sh.add_child(_side_title)
	var sx := Button.new()
	sx.text = "x"
	sx.focus_mode = Control.FOCUS_NONE
	sx.custom_minimum_size = Vector2(26, 22)
	sx.pressed.connect(func() -> void: close_side())
	sh.add_child(sx)
	sv.add_child(sh)
	var ssc := ScrollContainer.new()
	ssc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ssc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ssc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sv.add_child(ssc)
	_side_scroll = ssc
	var sb := VBoxContainer.new()
	_side_content = sb
	sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ssc.add_child(sb)
	_side_char = VBoxContainer.new()
	_side_bag = VBoxContainer.new()
	_side_dyn = VBoxContainer.new()
	_side_dyn.add_theme_constant_override("separation", 8)
	for c: Control in [_side_char, _side_bag, _side_dyn]:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sb.add_child(c)
	_tracker = tracker

	# --- interaction prompt
	_prompt_panel = PanelContainer.new()
	_prompt_panel.add_theme_stylebox_override("panel", _sb(PANEL, EMBER, 2, 8))
	_anchor(_prompt_panel, 0.5, 1, 0, -125, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_BEGIN)
	_prompt = _label("", 13, TEXT, font_label)
	_prompt_panel.add_child(_prompt)
	_prompt_panel.visible = false
	hud_root.add_child(_prompt_panel)

	# --- toasts
	_toasts = VBoxContainer.new()
	_toasts.alignment = BoxContainer.ALIGNMENT_BEGIN
	_toasts.add_theme_constant_override("separation", 6)
	_anchor(_toasts, 0.5, 0, 0, 90, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_END)
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_toasts)


func build_ability_bar(class_id: String) -> void:
	for c in _ability_bar.get_children():
		c.queue_free()
	_slots.clear()
	var res_name: String = Data.CLASSES[class_id]["resource"]
	var abil: Array = Data.ABILITIES[class_id]
	for slot in 6:
		var idx: int = main.bar_ability(slot) if main != null else -1
		var filled := idx >= 0 and idx < abil.size()
		var a: Dictionary = main.ability_view(abil[idx]) if filled else {}
		var hue := Color(a["hue"]) if filled else Color("3a3448")
		var b := _slot_button(hue)
		if filled:
			var cost: int = a["cost"]
			var cost_txt := ("%d %s" % [cost, res_name]) if cost > 0 else "No cost"
			b.tooltip_text = "%s   [%s]\n%s · %ss cooldown · unlocks at level %d\n\n%s\n\nRight-click to remove from bar." % [a["name"], Data.ABILITY_KEYS[slot], cost_txt, str(a["cd"]), a["lvl"], a["desc"]]
		else:
			b.tooltip_text = "Empty slot [%s]\nPress N to open Abilities and add one." % Data.ABILITY_KEYS[slot]
		var aic: Texture2D = Icons.ability(String(a["id"])) if filled else null
		var ab: Control
		if aic != null:
			var ait := _mini_icon(aic, 40)
			ab = ait
			_full(ait)
			ait.offset_left = 6
			ait.offset_top = 6
			ait.offset_right = -6
			ait.offset_bottom = -6
			b.add_child(ait)
		else:
			var abl := _outlined(_label(a["ab"] if filled else "+", 22 if filled else 20, Color.WHITE if filled else MUTED), 4)
			_full(abl)
			abl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			abl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			b.add_child(abl)
			ab = abl
		var key := _outlined(_label(Data.ABILITY_KEYS[slot], 11, Color.WHITE, font_label), 3)
		key.position = Vector2(5, 2)
		b.add_child(key)
		var mat := ShaderMaterial.new()
		var cdl: Label = null
		var lock: ColorRect = null
		var lock_lbl: Label = null
		if filled:
			var cost2: int = a["cost"]
			if cost2 > 0:
				var cl := _outlined(_label(str(cost2), 10, Color.WHITE, font_label), 3)
				_anchor(cl, 1, 1, -4, -2, Control.GROW_DIRECTION_BEGIN, Control.GROW_DIRECTION_BEGIN)
				b.add_child(cl)
			var cd := ColorRect.new()
			_full(cd)
			cd.mouse_filter = Control.MOUSE_FILTER_IGNORE
			mat.shader = _cd_shader
			cd.material = mat
			b.add_child(cd)
			cdl = _outlined(_label("", 16, Color.WHITE, font_label), 3)
			_full(cdl)
			cdl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cdl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			b.add_child(cdl)
			lock = ColorRect.new()
			_full(lock)
			lock.color = Color(0.03, 0.02, 0.05, 0.7)
			lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var ll := _outlined(_label("LV %d" % a["lvl"], 11, MUTED, font_label), 3)
			_full(ll)
			ll.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			ll.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			lock.add_child(ll)
			b.add_child(lock)
			lock_lbl = ll
		var sl := slot
		b.pressed.connect(func() -> void: main.cast(sl))
		b.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
				main.clear_bar_slot(sl))
		_ability_bar.add_child(b)
		_slots.append({"btn": b, "cd": mat, "cdl": cdl, "lock": lock, "ll": lock_lbl, "ab": ab, "a": a, "idx": idx})
	var res_col := Color(Data.CLASSES[class_id]["res_color"])
	var fill := _bar_res.get_theme_stylebox("fill").duplicate() as StyleBoxFlat
	fill.bg_color = res_col
	fill.border_color = res_col.lightened(0.25)
	_bar_res.add_theme_stylebox_override("fill", fill)


func _slot_button(hue: Color) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(54, 54)
	b.focus_mode = Control.FOCUS_NONE
	var n := _sb(hue.darkened(0.3), OUTLINE, 2, 0)
	n.border_width_top = 3
	n.border_color = OUTLINE
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", _sb(hue.darkened(0.12), EMBER_HI, 2, 0))
	b.add_theme_stylebox_override("pressed", _sb(hue, Color.WHITE, 2, 0))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b


func flash_slot(i: int) -> void:
	if i < 0 or i >= _slots.size():
		return
	var b: Button = _slots[i]["btn"]
	b.modulate = Color(1.6, 0.6, 0.6)
	var tw := create_tween()
	tw.tween_property(b, "modulate", Color.WHITE, 0.3)


func update_hud(p: Player, state: Dictionary, quest: Dictionary, cooldowns: Array) -> void:
	var c: Dictionary = Data.CLASSES[p.class_id]
	_lbl_class.text = String(main.state.get("name", "")) if String(main.state.get("name", "")) != "" else c["name"]
	_lbl_lvl.text = "LV %d" % p.level
	_bar_xp.max_value = maxf(1.0, state.get("xp_need", 1.0))
	_bar_xp.value = state.get("xp", 0)
	_bar_xp.tooltip_text = "Level %d · %d / %d XP" % [p.level, int(state.get("xp", 0)), int(state.get("xp_need", 1))]
	_bar_hp.max_value = p.max_hp
	_bar_hp.value = p.hp
	(_bar_hp.get_node("Text") as Label).text = "%d / %d" % [ceili(p.hp), p.max_hp]
	_bar_res.max_value = p.res_max
	_bar_res.value = p.res
	(_bar_res.get_node("Text") as Label).text = "%s %d / %d" % [c["resource"], floori(p.res), p.res_max]
	_bar_sta.max_value = p.sta_max
	_bar_sta.value = p.sta
	_q_title.text = quest.get("title", "")
	_q_text.text = quest.get("text", "")
	_q_rec.text = quest.get("rec", "")
	_q_text.visible = _q_text.text != ""
	var checks: Array = quest.get("checks", [])
	var ckey := str(checks)
	if ckey != _q_checks_key:
		_q_checks_key = ckey
		for ch in _q_checks.get_children():
			ch.queue_free()
		for c2: Array in checks:
			var done: bool = c2[1]
			var row := _outlined(_label("%s  %s" % ["[x]" if done else "[  ]", c2[0]], 14, Color("8ad07a") if done else TEXT), 6)
			row.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			_q_checks.add_child(row)
	_gold_label.text = "%d gold" % int(state.get("gold", 0))
	set_portrait(_player_portrait, "me:" + p.class_id)
	_dev_tag.visible = main.dev_mode
	var sig_on: bool = int(state.get("step", 0)) == 1 and not state.get("done", false) and main.combat.boss == null
	_sigil_row.visible = sig_on
	if sig_on:
		var bd: Dictionary = Data.BOSSES[int(state["bi"])]
		_sigil_label.text = bd["sigil"] + "s"
		_sigil_pips.count = int(state.get("shards", 0))
		_sigil_pips.col = Color(bd["color"])
		_sigil_pips.queue_redraw()
	_update_target()
	var track: Array = main.quests.tracker()
	var st_task: Dictionary = main.skills.task()
	if not st_task.is_empty():
		var tl_txt := "Return to %s" % Data.SLAYER_NAME if int(st_task["left"]) <= 0 else "%s %d/%d" % [Data.ENEMIES[st_task["enemy"]]["name"], int(st_task["total"]) - int(st_task["left"]), st_task["total"]]
		track = track.duplicate()
		track.append(["Slayer task", tl_txt])
	if _side_box.get_child_count() != track.size() * 2 or Engine.get_process_frames() % 15 == 0:
		for ch in _side_box.get_children():
			ch.queue_free()
		for t: Array in track:
			var tl := _outlined(_label(t[0], 14, TEXT), 6)
			tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			_side_box.add_child(tl)
			var pl2 := _outlined(_label(t[1], 12, Color("d8cce8")), 5)
			pl2.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			_side_box.add_child(pl2)
	_lbl_biome.text = main.world.zone_label(p.global_position)
	var ph := _phase(main.daynight.tod)
	var wxn: String = main.daynight.weather_name()
	_tod_label.text = ph[0] if wxn == "" else "%s · %s" % [ph[0], wxn]
	var ik: String = "sun" if ph[1] else "moon"
	if _tod_icon.kind != ik:
		_tod_icon.kind = ik
		_tod_icon.queue_redraw()
	var over := false
	if _side.visible:
		over = _tracker.get_global_rect().intersects(_side.get_global_rect())
	_tracker.modulate.a = lerpf(_tracker.modulate.a, 0.2 if over else 1.0, 0.2)
	for i in _slots.size():
		var s: Dictionary = _slots[i]
		var a: Dictionary = s["a"]
		if a.is_empty():
			continue
		var why: String = main.ability_locked(int(s["idx"]))
		var locked: bool = why != ""
		(s["ll"] as Label).text = why
		(s["lock"] as Control).visible = locked
		(s["ab"] as Control).visible = not locked
		var cd: float = cooldowns[int(s["idx"])]
		(s["cd"] as ShaderMaterial).set_shader_parameter("progress", cd / float(a["cd"]) if cd > 0.0 else 0.0)
		(s["cdl"] as Label).text = ("%.1f" % cd if cd < 1.0 else str(ceili(cd))) if cd > 0.0 else ""
		(s["ab"] as Control).modulate.a = 0.45 if (not locked and p.res < float(a["cost"])) else 1.0
	# low health warning
	var low := p.hp < p.max_hp * 0.3 and not p.dead
	_low_hp.color.a = (0.12 + 0.08 * sin(Time.get_ticks_msec() * 0.006)) if low else 0.0
	# buffs row
	for ch in _buffs.get_children():
		ch.queue_free()
	var names := {"might": "Might", "swift": "Swift", "shout": "Battle Shout", "stand": "Last Stand", "poison": "Poison Blade", "stealth": "Hidden", "flurry": "Flurry", "barrier": "Barrier"}
	for k: String in p.buffs:
		_buffs.add_child(_tag("%s %ds" % [names.get(k, k), ceili(p.buffs[k])], true))
	if main.combat.pet_time() > 0.0:
		_buffs.add_child(_tag("Wolf %ds" % ceili(main.combat.pet_time()), true))
	var pulse: String = main.quests.tutorial_pulse()
	for pk: String in _micro_btns:
		(_micro_btns[pk] as Button).modulate = Color(1, 1, 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.008)) if pk == pulse else Color.WHITE
	var markers: Array = main.map_markers()
	_minimap.markers = markers
	if _bigmap.is_visible_in_tree():
		_bigmap.markers = markers


func _tag(text: String, buff := false) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _sb(PANEL2, EMBER if buff else LINE, 1, 3))
	p.add_child(_label(text, 10, EMBER_HI if buff else MUTED, font_label))
	return p


func set_boss(boss_name: String, ratio: float) -> void:
	_boss_panel.visible = boss_name != ""
	_boss_name.text = boss_name
	_boss_bar.value = clampf(ratio, 0.0, 1.0) * 100.0


func show_dead(on: bool) -> void:
	_dead_root.visible = on


func set_prompt(text: String) -> void:
	_prompt_panel.visible = text != ""
	_prompt.text = text


func toast_item(item: Dictionary) -> void:
	toast("Picked up %s" % item["name"], Items.color(item))


## Messages go to the chat box. Only "center" ones (area names) pop up over the world.
func toast(text: String, col := EMBER_HI, center := false) -> void:
	var now := Time.get_ticks_msec()
	if text == _last_toast and now - _last_toast_t < 1200:
		return
	chat_say(text, col)
	if not center:
		_last_toast = text
		_last_toast_t = now
		return
	_last_toast = text
	_last_toast_t = now
	while _toasts.get_child_count() >= 5:
		var oldest := _toasts.get_child(0)
		_toasts.remove_child(oldest)
		oldest.queue_free()
	var l := _outlined(_label(text, 22, col), 6)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toasts.add_child(l)
	var tw := create_tween()
	tw.tween_interval(2.0)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)


func show_hud(on: bool) -> void:
	hud_root.visible = on
	if not on:
		set_prompt("")


# ================================================================ dialog
func _build_dead() -> void:
	_dead_root = _full(ColorRect.new())
	(_dead_root as ColorRect).color = Color(0.12, 0.02, 0.03, 0.7)
	_dead_root.visible = false
	root.add_child(_dead_root)
	var cc := _full(CenterContainer.new())
	_dead_root.add_child(cc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	cc.add_child(v)
	var t := _outlined(_label("You have fallen", 56, Color("e06a5a")), 10)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var sub := _outlined(_label("The Wisp carries you back to the Hearth Shrine...", 19, MUTED), 4)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)


func _build_dialog() -> void:
	dialog_panel = PanelContainer.new()
	dialog_panel.add_theme_stylebox_override("panel", _sb(PANEL, LINE, 2, 16))
	dialog_panel.custom_minimum_size = Vector2(660, 0)
	dialog_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchor(dialog_panel, 0.5, 1, 0, -24, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_BEGIN)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog_panel.add_child(v)
	_dialog_who = _label("", 12, EMBER, font_label)
	_dialog_text = _label("", 21, TEXT, null, true)
	_dialog_text.custom_minimum_size = Vector2(620, 0)
	var nx := _label("SPACE / CLICK TO CONTINUE", 10, MUTED, font_label)
	nx.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(_dialog_who)
	v.add_child(_dialog_text)
	v.add_child(nx)
	dialog_panel.visible = false
	root.add_child(dialog_panel)


func say(lines: Array, done := Callable()) -> void:
	_dialog_lines = lines.duplicate()
	_dialog_done = done
	_next_line()


func dialog_open() -> bool:
	return _dlg_on


func advance() -> void:
	_next_line()


func _next_line() -> void:
	if _dialog_lines.is_empty():
		_dlg_on = false
		dialog_panel.visible = false
		_apply_chat_view()
		var d := _dialog_done
		_dialog_done = Callable()
		if d.is_valid():
			d.call()
		return
	var l: Array = _dialog_lines.pop_front()
	_dlg_who.text = l[0]
	_dlg_text.text = l[1]
	var pid := _dlg_portrait_id(String(l[0]))
	_dlg_por.visible = pid != ""
	if pid != "":
		set_portrait(_dlg_por, pid)
	if not _dlg_on:
		_dlg_on = true
		_apply_chat_view()
		_flash_chat()
	chat_say("%s: %s" % [String(l[0]).capitalize(), l[1]], MUTED)


## Who is talking -> the hero model to show beside their words ("" = no head).
func _dlg_portrait_id(who: String) -> String:
	var w := who.to_lower()
	if w.contains("wisp"):
		return "wisp"
	if w == Data.SMITH_NAME.to_lower():
		return "smith"
	if w == Data.SLAYER_NAME.to_lower():
		return "slayer"
	for q: Dictionary in Data.SIDE_QUESTS:
		if String(q["name"]).to_lower() == w and Models.HEROES.has(String(q["sprite"])):
			return String(q["sprite"])
	return ""


# ================================================================ world map
func _build_map() -> void:
	map_root = _full(ColorRect.new())
	(map_root as ColorRect).color = Color(0.04, 0.03, 0.06, 0.8)
	map_root.visible = false
	root.add_child(map_root)
	var cc := _full(CenterContainer.new())
	map_root.add_child(cc)
	var p := PanelContainer.new()
	cc.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	var head := HBoxContainer.new()
	var t := _label("Thornvale", 28)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var close := Button.new()
	close.text = "Close (M)"
	close.pressed.connect(func() -> void: toggle_map(false))
	head.add_child(close)
	v.add_child(head)
	_bigmap = MapView.new()
	_bigmap.interactive = true
	_bigmap.span = 500.0
	_bigmap.custom_minimum_size = Vector2(560, 560)
	_bigmap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_bigmap.world = main.world
	_bigmap.player = main.player
	v.add_child(_bigmap)
	var leg := HBoxContainer.new()
	leg.add_theme_constant_override("separation", 16)
	for pair in [["Hearth Shrine", EMBER], ["Runestone", EMBER_HI], ["Warden altar", Color("e0566e")], ["You", Color.WHITE], ["Scroll or + -: zoom  Drag: pan  Double-click: find me", MUTED]]:
		var sw := ColorRect.new()
		sw.color = pair[1]
		sw.custom_minimum_size = Vector2(10, 10)
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		leg.add_child(sw)
		leg.add_child(_label(pair[0], 10, MUTED, font_label))
	v.add_child(leg)


func map_open() -> bool:
	return map_root.visible


func map_zoom(factor: float) -> void:
	if _bigmap != null:
		_bigmap.zoom_by(factor)


func toggle_map(on: bool) -> void:
	map_root.visible = on
	if on:
		if main.dev_mode:
			main.world.reveal_all()   # dev mode: nothing is hidden on the map
		_bigmap.markers = main.map_markers()
		_bigmap.recenter()


# ================================================================ class cards
func _class_card(id: String, on_pick: Callable, current := false, compact := false) -> Button:
	var c: Dictionary = Data.CLASSES[id]
	var b := Button.new()
	b.custom_minimum_size = Vector2(196, 150 if compact else 272)
	if current:
		b.add_theme_stylebox_override("normal", _sb(PANEL2, EMBER_HI, 2, 8))
	b.pressed.connect(on_pick.bind(id))
	var v := VBoxContainer.new()
	_full(v)
	v.offset_left = 10
	v.offset_right = -10
	v.offset_top = 12
	v.offset_bottom = -10
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var tr := portrait(id, Vector2(0, 56 if compact else 96))
	v.add_child(tr)
	var n := _label(c["name"], 22)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(n)
	if not compact:
		var d := _label(c["desc"], 15, MUTED, null, true)
		d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(d)
	var names: Array = []
	for a: Dictionary in Data.ABILITIES[id]:
		if not a.has("talent"):
			names.append(a["name"])
	var r := _label(c["resource"].to_upper(), 10, Color(c["res_color"]), font_label)
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(r)
	if not compact:
		var sk := _label(", ".join(names), 12, MUTED, null, true)
		sk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(sk)
	return b


# ================================================================ title
func _build_title() -> void:
	title_root = _full(ColorRect.new())
	(title_root as ColorRect).color = Color(0.067, 0.055, 0.094, 0.55)
	root.add_child(title_root)
	var cc := _full(CenterContainer.new())
	title_root.add_child(cc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	cc.add_child(v)
	var small := _label("A SMALL OPEN-WORLD RPG", 12, MUTED, font_label)
	small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(small)
	var logo := _label("Embers of Thornvale", 72, EMBER_HI)
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.add_theme_color_override("font_outline_color", Color("2a1408"))
	logo.add_theme_constant_override("outline_size", 14)
	logo.add_theme_color_override("font_shadow_color", Color("8a3d14"))
	logo.add_theme_constant_override("shadow_offset_y", 5)
	logo.add_theme_constant_override("shadow_offset_x", 0)
	v.add_child(logo)
	var blurb := _outlined(_label("The Ember at the Hearth Shrine has gone dim, and the four Wardens who guarded Thornvale have turned on it. Wake, keeper. Choose who you were.", 19, TEXT, null, true), 5)
	blurb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	blurb.custom_minimum_size = Vector2(640, 0)
	var bc := CenterContainer.new()
	bc.add_child(blurb)
	v.add_child(bc)
	_title_classes = GridContainer.new()
	_title_classes.columns = 1
	_title_classes.add_theme_constant_override("h_separation", 12)
	var nb := Button.new()
	nb.text = "New journey"
	nb.add_theme_stylebox_override("normal", _sb(PANEL2, EMBER_HI, 2, 10))
	nb.pressed.connect(func() -> void: open_creator("warrior"))
	_title_classes.add_child(nb)
	v.add_child(_title_classes)
	_continue_btn = Button.new()
	_continue_btn.text = "Continue journey"
	_continue_btn.add_theme_stylebox_override("normal", _sb(PANEL2, EMBER, 2, 10))
	_continue_btn.pressed.connect(func() -> void: main.continue_game())
	var cbc := CenterContainer.new()
	cbc.add_child(_continue_btn)
	v.add_child(cbc)
	var ctl := _outlined(_label("WASD move · Q E strafe · Right-drag steer · Left-drag camera · 1-6 bar · N abilities · Tab target · Space jump · Shift sprint · G interact · B bags · M map · Esc menu", 11, MUTED, font_label), 3)
	ctl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(ctl)


func show_title(has_save: bool) -> void:
	_dlg_on = false
	_apply_chat_view()
	title_root.visible = true
	_continue_btn.visible = has_save
	show_hud(false)
	pause_root.visible = false
	map_root.visible = false
	dialog_panel.visible = false


func hide_title() -> void:
	title_root.visible = false
	creator_root.visible = false

# ================================================================ character creation
var creator_root: Control
var _cr_cls := "warrior"
var _cr_look := {}
var _cr_name: LineEdit
var _cr_box: SubViewportContainer
var _cr_syncs: Array[Callable] = []
var _cr_class_btns := {}
var _cr_begin: Button
var _cr_facial_row: Control
var _cr_info: Label
var _cr_edit := false
var _cr_class_box: Control
var _cr_back: Button
var _cr_title: Label


func _build_creator() -> void:
	creator_root = _full(ColorRect.new())
	(creator_root as ColorRect).color = Color(0.05, 0.04, 0.08, 0.86)
	creator_root.visible = false
	root.add_child(creator_root)
	var m := MarginContainer.new()
	_full(m)
	for s: String in ["left", "right"]:
		m.add_theme_constant_override("margin_" + s, 60)
	m.add_theme_constant_override("margin_top", 28)
	m.add_theme_constant_override("margin_bottom", 28)
	creator_root.add_child(m)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	m.add_child(outer)
	var title := _label("Create your keeper", 44, EMBER_HI)
	title.add_theme_color_override("font_outline_color", Color("2a1408"))
	title.add_theme_constant_override("outline_size", 10)
	_cr_title = title
	outer.add_child(title)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 18)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(cols)

	# --- left: options
	var lp := PanelContainer.new()
	lp.add_theme_stylebox_override("panel", _sb(PANEL, LINE, 2, 14))
	lp.custom_minimum_size = Vector2(470, 0)
	cols.add_child(lp)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lp.add_child(sc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)

	var cbox := VBoxContainer.new()
	cbox.add_theme_constant_override("separation", 6)
	_cr_class_box = cbox
	v.add_child(cbox)
	cbox.add_child(_cr_heading("STARTING WEAPON"))
	var crow := HBoxContainer.new()
	crow.add_theme_constant_override("separation", 6)
	for id: String in Data.CLASS_ORDER:
		var cb := Button.new()
		cb.text = {"warrior": "Sword", "rogue": "Daggers", "mage": "Staff", "hunter": "Bow"}[id]
		cb.focus_mode = Control.FOCUS_NONE
		cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cid := id
		cb.pressed.connect(func() -> void: _cr_set_class(cid))
		crow.add_child(cb)
		_cr_class_btns[id] = cb
	cbox.add_child(crow)

	v.add_child(_cr_heading("NAME"))
	var nrow := HBoxContainer.new()
	nrow.add_theme_constant_override("separation", 6)
	_cr_name = LineEdit.new()
	_cr_name.max_length = 16
	_cr_name.placeholder_text = "Your name"
	_cr_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cr_name.text_changed.connect(func(t: String) -> void:
		var clean := ""
		for ch in t:
			if ch.is_valid_identifier() or ch == " " or ch == "'" or ch == "-":
				if ch != "_" and not ch.is_valid_int():
					clean += ch
		if clean != t:
			var cp := _cr_name.caret_column
			_cr_name.text = clean
			_cr_name.caret_column = mini(cp, clean.length())
		_cr_sync_all())
	nrow.add_child(_cr_name)
	var dice := Button.new()
	dice.text = "Random"
	dice.focus_mode = Control.FOCUS_NONE
	dice.pressed.connect(func() -> void:
		_cr_name.text = Models.random_name()
		_cr_sync_all())
	nrow.add_child(dice)
	v.add_child(nrow)

	v.add_child(_cr_heading("BODY"))
	v.add_child(_cr_choice("body", [["a", "Body A"], ["b", "Body B"]]))
	v.add_child(_cr_heading("SKIN"))
	v.add_child(_cr_colors("skin", Models.SKIN_TONES))
	v.add_child(_cr_heading("HAIR"))
	v.add_child(_cr_arrows("hair_style", Models.HAIR_STYLES))
	v.add_child(_cr_colors("hair", Models.HAIR_COLORS))
	var fh := VBoxContainer.new()
	fh.add_theme_constant_override("separation", 6)
	fh.add_child(_cr_heading("FACIAL HAIR"))
	fh.add_child(_cr_arrows("facial", Models.FACIAL_STYLES))
	_cr_facial_row = fh
	v.add_child(fh)
	v.add_child(_cr_heading("EYES"))
	v.add_child(_cr_colors("eye", Models.EYE_COLORS))
	v.add_child(_cr_heading("CLOTHES"))
	for spec: Array in [["shirt", "Shirt"], ["pants", "Trousers"], ["boots", "Boots"], ["belt", "Belt"]]:
		v.add_child(_cr_colors(spec[0], Models.CLOTH_COLORS, spec[1]))
	var note := _label("Armor you find covers your clothes. Hair and skin always show.", 12, MUTED, null, true)
	v.add_child(note)

	# --- right: preview
	var rp := PanelContainer.new()
	rp.add_theme_stylebox_override("panel", _sb(Color(0.06, 0.05, 0.09, 0.7), LINE, 2, 14))
	rp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(rp)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 6)
	rp.add_child(rv)
	_cr_box = portrait("", Vector2(300, 400), true)
	_cr_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_cr_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cr_box.stretch_shrink = 1
	rv.add_child(_cr_box)
	_cr_info = _label("", 16, MUTED, null, true)
	_cr_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rv.add_child(_cr_info)

	# --- footer
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 10)
	outer.add_child(foot)
	var back := Button.new()
	back.text = "Back"
	back.pressed.connect(func() -> void: close_creator())
	foot.add_child(back)
	_cr_back = back
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(sp)
	var rnd := Button.new()
	rnd.text = "Randomize look"
	rnd.pressed.connect(func() -> void:
		_cr_look = Models.random_look(_cr_cls)
		_cr_sync_all())
	foot.add_child(rnd)
	_cr_begin = Button.new()
	_cr_begin.text = "Begin journey"
	_cr_begin.add_theme_stylebox_override("normal", _sb(PANEL2, EMBER_HI, 2, 10))
	_cr_begin.pressed.connect(func() -> void:
		var nm := _cr_name.text.strip_edges()
		if nm == "":
			return
		var look := _cr_look.duplicate()
		creator_root.visible = false
		if _cr_edit:
			_cr_edit = false
			get_tree().paused = false
			main.apply_appearance(look, nm)
		else:
			main.new_game(_cr_cls, look, nm))
	foot.add_child(_cr_begin)


func _cr_heading(t: String) -> Label:
	return _label(t, 11, EMBER, font_label)


func _cr_swatch_style(col: Color, on: bool) -> StyleBoxFlat:
	var sb := _sb(col, EMBER_HI if on else Color(0.12, 0.1, 0.16), 3 if on else 2, 0)
	return sb


## A row of colour swatches plus a custom picker. `key` is the look entry it edits.
func _cr_colors(key: String, presets: Array, label := "") -> Control:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	if label != "":
		var l := _label(label, 14, TEXT)
		l.custom_minimum_size = Vector2(72, 0)
		hb.add_child(l)
	var fl := HFlowContainer.new()
	fl.add_theme_constant_override("h_separation", 4)
	fl.add_theme_constant_override("v_separation", 4)
	fl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(fl)
	var btns: Array[Button] = []
	for hex: String in presets:
		var b := Button.new()
		b.custom_minimum_size = Vector2(24, 24)
		b.focus_mode = Control.FOCUS_NONE
		var hx := hex
		b.pressed.connect(func() -> void:
			_cr_look[key] = hx
			_cr_sync_all())
		fl.add_child(b)
		btns.append(b)
	var pick := ColorPickerButton.new()
	pick.custom_minimum_size = Vector2(34, 24)
	pick.edit_alpha = false
	pick.focus_mode = Control.FOCUS_NONE
	pick.tooltip_text = "Pick any colour"
	pick.color_changed.connect(func(c: Color) -> void:
		_cr_look[key] = c.to_html(false)
		_cr_sync_all())
	fl.add_child(pick)
	_cr_syncs.append(func() -> void:
		var cur := String(_cr_look.get(key, ""))
		for i in btns.size():
			var col := Color(presets[i])
			var on := cur == String(presets[i])
			for st: String in ["normal", "hover", "pressed"]:
				btns[i].add_theme_stylebox_override(st, _cr_swatch_style(col.lightened(0.12) if st == "hover" else col, on))
		if cur != "" and Color(cur) != pick.color:
			pick.color = Color(cur))
	return hb


## Left / right arrows through a list of [id, label].
func _cr_arrows(key: String, opts: Array) -> Control:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	var lb := Button.new()
	lb.text = "<"
	lb.focus_mode = Control.FOCUS_NONE
	lb.custom_minimum_size = Vector2(40, 0)
	var rb := Button.new()
	rb.text = ">"
	rb.focus_mode = Control.FOCUS_NONE
	rb.custom_minimum_size = Vector2(40, 0)
	var nm := _label("", 17, TEXT)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var step := func(d: int) -> void:
		var idx := 0
		for i in opts.size():
			if opts[i][0] == _cr_look.get(key, ""):
				idx = i
		_cr_look[key] = opts[posmod(idx + d, opts.size())][0]
		_cr_sync_all()
	lb.pressed.connect(step.bind(-1))
	rb.pressed.connect(step.bind(1))
	hb.add_child(lb)
	hb.add_child(nm)
	hb.add_child(rb)
	_cr_syncs.append(func() -> void:
		for o: Array in opts:
			if o[0] == _cr_look.get(key, ""):
				nm.text = o[1])
	return hb


## A short row of exclusive buttons.
func _cr_choice(key: String, opts: Array) -> Control:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	var btns := {}
	for o: Array in opts:
		var b := Button.new()
		b.text = o[1]
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var oid: String = o[0]
		b.pressed.connect(func() -> void:
			_cr_look[key] = oid
			_cr_sync_all())
		hb.add_child(b)
		btns[oid] = b
	_cr_syncs.append(func() -> void:
		for oid2: String in btns:
			var on: bool = _cr_look.get(key, "") == oid2
			(btns[oid2] as Button).add_theme_stylebox_override("normal", _sb(PANEL2, EMBER_HI if on else LINE, 2, 8)))
	return hb


func open_creator(cid: String) -> void:
	Sfx.play("ui_click", Vector3.INF, -6.0)
	title_root.visible = false
	_cr_edit = false
	_cr_class_box.visible = false   # everyone starts with the sword; bow and staff wait at camp
	_cr_back.text = "Back"
	_cr_begin.text = "Begin journey"
	_cr_title.text = "Create your keeper"
	creator_root.visible = true
	_cr_name.text = Models.random_name()
	_cr_cls = cid
	_cr_look = Models.default_look(cid)
	_cr_sync_all()


## Change your look and name in a running game (from the character panel).
func open_appearance() -> void:
	if main.state.is_empty() or main.mode != "play":
		return
	Sfx.play("ui_click", Vector3.INF, -6.0)
	close_side()
	_cr_edit = true
	_cr_class_box.visible = false
	_cr_back.text = "Cancel"
	_cr_begin.text = "Apply"
	_cr_title.text = "Change your look"
	_cr_cls = main.player.class_id
	_cr_look = Models.default_look(_cr_cls)
	_cr_look.merge(main.player.look, true)
	_cr_name.text = String(main.state.get("name", "")) if String(main.state.get("name", "")) != "" else Models.random_name()
	root.move_child(creator_root, -1)
	creator_root.visible = true
	get_tree().paused = true
	_cr_sync_all()


func close_creator() -> void:
	creator_root.visible = false
	if _cr_edit:
		_cr_edit = false
		get_tree().paused = false
	else:
		title_root.visible = true


func _cr_set_class(cid: String) -> void:
	# keep the look, but follow the class's usual clothing / hair if they haven't changed anything
	var old := Models.default_look(_cr_cls)
	var nl := Models.default_look(cid)
	for k: String in ["shirt", "hair"]:
		if _cr_look.get(k, "") == old[k]:
			_cr_look[k] = nl[k]
	_cr_cls = cid
	Sfx.play("ui_click", Vector3.INF, -6.0)
	_cr_sync_all()


func _cr_sync_all() -> void:
	for f: Callable in _cr_syncs:
		f.call()
	for id: String in _cr_class_btns:
		(_cr_class_btns[id] as Button).add_theme_stylebox_override("normal", _sb(PANEL2, EMBER_HI if id == _cr_cls else LINE, 2, 8))
	_cr_facial_row.visible = _cr_look.get("body", "a") == "a"
	if not _cr_facial_row.visible and _cr_look.get("facial", "none") != "none":
		_cr_look["facial"] = "none"
	_cr_begin.disabled = _cr_name.text.strip_edges() == ""
	var c: Dictionary = Data.CLASSES[_cr_cls]
	_cr_info.text = "%s style · %s" % [Data.SKILLS[Data.COMBAT_SKILL[_cr_cls]]["name"], c["desc"]]
	var turn: Node3D = _cr_box.get_meta("turn")
	for ch in turn.get_children():
		ch.queue_free()
	var equip := {}
	if _cr_edit:
		equip = main.player.equipped
	else:
		for it: Dictionary in Items.starter_kit(_cr_cls):
			if it.get("offhand", false):
				equip["offhand"] = it
			elif it["slot"] == "weapon":
				equip["weapon"] = it
	var r := Models.hero_geared(_cr_cls, equip, _cr_look)
	turn.add_child(r)
	r.tick(0.016, 0.0)
	_frame_portrait(_cr_box, r)



# ================================================================ character + bag
func _build_inventory() -> void:
	inv_root = _full(ColorRect.new())
	(inv_root as ColorRect).color = Color(0.04, 0.03, 0.06, 0.78)
	inv_root.visible = false
	root.add_child(inv_root)
	var cc := _full(CenterContainer.new())
	inv_root.add_child(cc)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _sb(PANEL, LINE, 2, 18))
	cc.add_child(p)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 26)
	p.add_child(h)

	# --- left: what you're wearing + stats
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	h.add_child(left)
	_inv_left = left
	_inv_title = _label("", 17, EMBER_HI)
	_inv_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(_inv_title)
	var doll := HBoxContainer.new()
	doll.add_theme_constant_override("separation", 6)
	left.add_child(doll)
	var lcol := VBoxContainer.new()
	var rcol := VBoxContainer.new()
	for c in [lcol, rcol]:
		c.add_theme_constant_override("separation", 4)
	for sname in ["head", "chest", "hands", "legs"]:
		lcol.add_child(_equip_slot(sname))
	for sname in ["feet", "ring", "amulet", "weapon", "offhand"]:
		rcol.add_child(_equip_slot(sname))
	doll.add_child(lcol)
	var mid := PanelContainer.new()
	mid.add_theme_stylebox_override("panel", _sb(Color("15121e"), Color("2a2436"), 2, 6))
	_inv_doll = portrait("warrior", Vector2(96, 0), true)
	mid.add_child(_inv_doll)
	doll.add_child(mid)
	doll.add_child(rcol)
	left.add_child(_label("STATS", 11, EMBER, font_label))
	_stats_grid = GridContainer.new()
	_stats_grid.columns = 4
	_stats_grid.add_theme_constant_override("h_separation", 6)
	_stats_grid.add_theme_constant_override("v_separation", 1)
	left.add_child(_stats_grid)

	# --- right: bag
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 6)
	h.add_child(right)
	_inv_right = right
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	var bt := VBoxContainer.new()
	bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bag_label = _label("", 15, TEXT)
	bt.add_child(_bag_label)
	head.add_child(bt)
	var sort := Button.new()
	sort.text = "Sort"
	sort.size_flags_vertical = Control.SIZE_SHRINK_END
	sort.pressed.connect(func() -> void: main.sort_bag())
	head.add_child(sort)
	right.add_child(head)
	_bag_grid = GridContainer.new()
	_bag_grid.columns = 6
	_bag_grid.add_theme_constant_override("h_separation", 4)
	_bag_grid.add_theme_constant_override("v_separation", 4)
	for i in MAX_BAG:
		var sl := ItemSlot.new(self, "bag")
		sl.custom_minimum_size = Vector2(40, 40)
		sl.index = i
		_bag_grid.add_child(sl)
	right.add_child(_bag_grid)
	_inv_mats = _label("", 13, TEXT, null, true)
	_inv_mats.custom_minimum_size = Vector2(300, 0)
	right.add_child(_inv_mats)
	# live in the side panel, not a pop-up
	_inv_left.reparent(_side_char)
	_inv_right.reparent(_side_bag)


## Put everything you carry into cells: where you left it, otherwise the first free cell.
func _layout_bag(bag: Array, stacks: Array, shown: int) -> void:
	var saved: Dictionary = main.state.get("bag_pos", {})
	var seen := {}
	var entries: Array = []
	for i in bag.size():
		var it: Dictionary = bag[i]
		var uid := int(it.get("uid", 0))
		if uid <= 0 or seen.has(uid):
			uid = int(main.state.get("uid_n", 0)) + 1
			main.state["uid_n"] = uid
			it["uid"] = uid
		seen[uid] = true
		entries.append({"key": "i%d" % uid, "item": it, "index": i})
	var kn := {}
	for st: Dictionary in stacks:
		var k := int(kn.get(st["id"], 0))
		kn[st["id"]] = k + 1
		entries.append({"key": "m:%s:%d" % [st["id"], k], "mat": st["id"], "n": int(st["count"])})
	var cells: Array = []
	cells.resize(shown)
	cells.fill(null)
	var rest: Array = []
	for e: Dictionary in entries:
		var want := int(saved.get(e["key"], -1))
		if want >= 0 and want < shown and cells[want] == null:
			cells[want] = e
		else:
			rest.append(e)
	var c := 0
	for e: Dictionary in rest:
		while c < shown and cells[c] != null:
			c += 1
		if c >= shown:
			break
		cells[c] = e
	var newpos := {}
	_slot_keys.resize(MAX_BAG)
	_slot_keys.fill("")
	for i in MAX_BAG:
		var sl: ItemSlot = _bag_grid.get_child(i)
		sl.pos = i
		sl.visible = i < shown
		sl.index = -1
		if i >= shown or cells[i] == null:
			sl.set_item({})
			continue
		var e: Dictionary = cells[i]
		_slot_keys[i] = e["key"]
		newpos[e["key"]] = i
		if e.has("item"):
			sl.index = int(e["index"])
			sl.set_item(e["item"])
		else:
			sl.set_mat(e["mat"], int(e["n"]))
	main.state["bag_pos"] = newpos


## Drag one cell onto another: swap them (or just move into an empty cell).
func move_bag(from: int, to: int) -> void:
	if from == to or from < 0 or to < 0 or from >= _slot_keys.size() or to >= _slot_keys.size():
		return
	var ka: String = _slot_keys[from]
	var kb: String = _slot_keys[to]
	if ka == "":
		return
	var bp: Dictionary = main.state.get("bag_pos", {})
	bp[ka] = to
	if kb != "":
		bp[kb] = from
	main.state["bag_pos"] = bp
	Sfx.play("ui_click", Vector3.INF, -8.0)
	refresh_inventory()


# ---- clicks, the right-click menu and "use X on Y"
func bag_click(sl: ItemSlot, right: bool, shift: bool, at: Vector2) -> void:
	if use_src != "":
		var src := use_src
		cancel_use()
		if right:
			return
		if sl.mat_id != "" and sl.mat_id != src:
			main.use_on(src, sl.mat_id)
		elif sl.mat_id == "":
			chat_say("Nothing interesting happens.", MUTED)
		return
	if sl.item.is_empty() and sl.mat_id == "":
		return
	if right:
		_open_ctx(sl, at)
		return
	if not sl.item.is_empty():
		if shift:
			main.discard(sl.index)
		else:
			main.equip_from_bag(sl.index)
		return
	var id := sl.mat_id
	if id in ["hpot", "greater", "might", "swift", "minnow", "trout", "eel", "icefin", "kindling_oak", "kindling_heart"]:
		main.use_mat(id)
	elif main.combo_item(id):
		start_use(id)
	else:
		main.use_mat(id)


func start_use(id: String) -> void:
	use_src = id
	chat_say("Use %s on..." % Data.MATERIALS[id]["name"], Color("ffd27a"), Icons.material(id))
	if _use_ghost == null:
		_use_ghost = TextureRect.new()
		_use_ghost.custom_minimum_size = Vector2(34, 34)
		_use_ghost.size = Vector2(34, 34)
		_use_ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_use_ghost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_use_ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_use_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_use_ghost.z_index = 100
		hud_root.add_child(_use_ghost)
	_use_ghost.texture = Icons.material(id)
	_use_ghost.visible = true
	Sfx.play("ui_click", Vector3.INF, -8.0)
	refresh_inventory()


func cancel_use() -> void:
	if use_src == "":
		return
	use_src = ""
	if _use_ghost != null:
		_use_ghost.visible = false
	refresh_inventory()


func _close_ctx() -> void:
	for n in [_ctx_panel, _ctx_catch]:
		if n != null and is_instance_valid(n):
			n.queue_free()
	_ctx_panel = null
	_ctx_catch = null


func _open_ctx(sl: ItemSlot, at: Vector2) -> void:
	_close_ctx()
	var opts: Array = []   # [label, callable]
	var m := main
	if not sl.item.is_empty():
		var idx := sl.index
		opts.append(["Equip", func() -> void: m.equip_from_bag(idx)])
		opts.append(["Drop", func() -> void: m.drop_from_bag(idx, "", 0)])
	else:
		var id := sl.mat_id
		var n := sl.mat_n
		if id in ["hpot", "greater", "might", "swift"]:
			opts.append(["Drink", func() -> void: m.use_mat(id)])
		elif id in ["minnow", "trout", "eel", "icefin"]:
			opts.append(["Eat", func() -> void: m.use_mat(id)])
		elif id in ["oak", "heartwood"]:
			opts.append(["Light fire" if m.online != null else "Cut kindling", func() -> void: m.use_mat(id)])
		elif id in ["kindling_oak", "kindling_heart"]:
			opts.append(["Light fire", func() -> void: m.use_mat(id)])
		if m.combo_item(id):
			opts.append(["Use", func() -> void: start_use(id)])
		opts.append(["Examine", func() -> void: toast("%s: %s" % [Data.MATERIALS[id]["name"], Data.MATERIALS[id].get("desc", "A crafting material.")])])
		opts.append(["Drop", func() -> void: m.drop_from_bag(-1, id, n)])
	_ctx_catch = _full(Control.new())
	_ctx_catch.mouse_filter = Control.MOUSE_FILTER_STOP
	_ctx_catch.z_index = 150
	_ctx_catch.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed:
			_close_ctx()
			get_viewport().set_input_as_handled())
	hud_root.add_child(_ctx_catch)
	_ctx_panel = PanelContainer.new()
	_ctx_panel.z_index = 151
	_ctx_panel.add_theme_stylebox_override("panel", _sb(Color(0.08, 0.065, 0.11, 0.97), EMBER, 2, 4))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	_ctx_panel.add_child(v)
	for o: Array in opts:
		var b := Button.new()
		b.text = o[0]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(104, 28)
		b.add_theme_font_size_override("font_size", 15)
		b.add_theme_color_override("font_color", TEXT)
		b.add_theme_color_override("font_hover_color", EMBER_HI)
		var cb: Callable = o[1]
		b.pressed.connect(func() -> void:
			_close_ctx()
			cb.call())
		v.add_child(b)
	hud_root.add_child(_ctx_panel)
	var vp := get_viewport().get_visible_rect().size
	var sz := _ctx_panel.get_combined_minimum_size()
	_ctx_panel.position = Vector2(clampf(at.x - 6.0, 0.0, vp.x - sz.x), clampf(at.y - 6.0, 0.0, vp.y - sz.y))


func _equip_slot(sname: String) -> ItemSlot:
	var sl := ItemSlot.new(self, "equip")
	sl.custom_minimum_size = Vector2(42, 42)
	sl.slot_name = sname
	_inv_slots[sname] = sl
	return sl


func show_inventory(on: bool) -> void:
	if on:
		open_side("bag" if inv_parts.get("bag", true) else "char")
	elif side_tab in ["char", "bag"]:
		close_side()


## Is the point over the side panel or the button row (so a drag was not "out of the bag")?
func over_inventory(mp: Vector2) -> bool:
	if _side != null and _side.visible and _side.get_global_rect().has_point(mp):
		return true
	if _micro_row != null and _micro_row.get_global_rect().has_point(mp):
		return true
	return false


func refresh_inventory() -> void:
	if _side == null or not _side.visible or not (side_tab in ["char", "bag"]) or main.state.is_empty():
		return
	var p: Player = main.player
	var c: Dictionary = Data.CLASSES[p.class_id]
	_inv_title.text = "%s · Level %d" % [c["name"], p.level]
	set_portrait(_inv_doll, "me:" + p.class_id)
	var eq: Dictionary = main.state.get("equip", {})
	for sname: String in _inv_slots:
		(_inv_slots[sname] as ItemSlot).set_item(eq.get(sname, {}), Items.SLOT_NAMES[sname].to_upper())
	if _inv_slots.has("offhand"):
		(_inv_slots["offhand"] as ItemSlot).visible = true   # shields go here (the Dual Wield talent also uses it)
	var bag: Array = main.state.get("bag", [])
	var stacks: Array = main.mat_stacks()
	var shown := mini(MAX_BAG, maxi(main.bag_size(), bag.size() + stacks.size()))
	_layout_bag(bag, stacks, shown)
	_bag_label.text = "%d / %d · %d gold" % [bag.size() + stacks.size(), main.bag_size(), int(main.state.get("gold", 0))]
	_inv_mats.text = ""
	_inv_mats.visible = false
	# stat sheet
	for ch in _stats_grid.get_children():
		ch.queue_free()
	var main_stat: String = Items.MAIN_STAT[p.class_id]
	var rows := [
		["Health", "%d" % p.max_hp, "Stamina adds health."],
		[c["resource"], "%d" % p.res_max, "Intellect adds Mana for Mages."],
		["Damage", "%d" % roundi(p.dmg), "Damage of a basic attack. Weapon damage and your main stat raise it."],
		["Critical", "%.1f%%" % (p.crit * 100.0), "Chance to deal double damage. Agility adds 0.1% per point."],
		["Armor", "%d" % roundi(p.armor), "Reduces damage you take."],
		["Blocked", "%d%%" % roundi(p.armor_red * 100.0), "Share of each hit your armor stops."],
	]
	for k in ["str", "agi", "int", "sta"]:
		var note := ""
		match k:
			"str":
				note = "Main stat for Warriors: +2.5% damage per point."
			"agi":
				note = "Main stat for Rogues and Hunters: +2.5% damage per point. Everyone gains 0.1% crit per point."
			"int":
				note = "Main stat for Mages: +2.5% damage and +2 Mana per point."
			"sta":
				note = "Adds health."
		var name: String = Items.STAT_NAMES[k] + (" ★" if k == main_stat else "")
		rows.append([name, "%d" % roundi(float(p.attrs.get(k, 0.0))), note])
	for r: Array in rows:
		var l := _label(r[0], 13, MUTED)
		l.mouse_filter = Control.MOUSE_FILTER_PASS
		l.tooltip_text = r[2]
		var v := _label(r[1], 13, TEXT)
		v.custom_minimum_size = Vector2(40, 0)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		v.mouse_filter = Control.MOUSE_FILTER_PASS
		v.tooltip_text = r[2]
		_stats_grid.add_child(l)
		_stats_grid.add_child(v)
	_fit_side.call_deferred()


# ================================================================ merchant
var _shop_title: Label
var _shop_face_box: HBoxContainer


## Who is behind the counter: the shop panel shows their name and face.
func set_shop_keeper(nm: String, sprite: String) -> void:
	if _shop_title == null:
		return
	_shop_title.text = "%s's Wares" % nm
	for ch in _shop_face_box.get_children():
		ch.queue_free()
	_shop_face_box.add_child(portrait(sprite, Vector2(72, 96)))

func _build_shop() -> void:
	shop_root = _full(ColorRect.new())
	(shop_root as ColorRect).color = Color(0.04, 0.03, 0.06, 0.78)
	shop_root.visible = false
	root.add_child(shop_root)
	var cc := _full(CenterContainer.new())
	shop_root.add_child(cc)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _sb(PANEL, LINE, 2, 18))
	p.add_child(Brackets.new())
	cc.add_child(p)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 26)
	p.add_child(h)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	h.add_child(left)
	left.add_child(_label("MERCHANT", 11, EMBER, font_label))
	var who := HBoxContainer.new()
	who.add_theme_constant_override("separation", 12)
	_shop_face_box = HBoxContainer.new()
	_shop_face_box.add_child(portrait("merchant", Vector2(72, 96)))
	who.add_child(_shop_face_box)
	var wv := VBoxContainer.new()
	_shop_title = _label("%s's Wares" % Data.MERCHANT_NAME, 26, EMBER_HI)
	wv.add_child(_shop_title)
	var note := _label("New stock arrives when you level up or rekindle a light.", 14, MUTED, null, true)
	note.custom_minimum_size = Vector2(300, 0)
	wv.add_child(note)
	who.add_child(wv)
	left.add_child(who)
	_shop_grid = GridContainer.new()
	_shop_grid.columns = 3
	_shop_grid.add_theme_constant_override("h_separation", 8)
	_shop_grid.add_theme_constant_override("v_separation", 8)
	for i in Data.SHOP_SLOTS:
		var sl := ItemSlot.new(self, "shop")
		sl.custom_minimum_size = Vector2(72, 72)
		sl.index = i
		_shop_grid.add_child(sl)
	left.add_child(_shop_grid)
	_potion_btn = Button.new()
	_potion_btn.pressed.connect(func() -> void: main.buy_potion())
	left.add_child(_potion_btn)
	_restock_btn = Button.new()
	_restock_btn.pressed.connect(func() -> void: main.paid_restock())
	left.add_child(_restock_btn)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	h.add_child(right)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	var bt := VBoxContainer.new()
	bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bt.add_child(_label("YOUR BAG", 11, EMBER, font_label))
	_shop_gold = _label("", 26, EMBER_HI)
	bt.add_child(_shop_gold)
	head.add_child(bt)
	var sellc := Button.new()
	sellc.text = "Sell all Common"
	sellc.size_flags_vertical = Control.SIZE_SHRINK_END
	sellc.pressed.connect(func() -> void: main.sell_commons())
	head.add_child(sellc)
	var close := Button.new()
	close.text = "Close (G)"
	close.size_flags_vertical = Control.SIZE_SHRINK_END
	close.pressed.connect(func() -> void: main.toggle_shop())
	head.add_child(close)
	right.add_child(head)
	_shop_bag = GridContainer.new()
	_shop_bag.columns = 6
	_shop_bag.add_theme_constant_override("h_separation", 6)
	_shop_bag.add_theme_constant_override("v_separation", 6)
	for i in MAX_BAG:
		var sl2 := ItemSlot.new(self, "sell")
		sl2.index = i
		_shop_bag.add_child(sl2)
	right.add_child(_shop_bag)
	right.add_child(_label("Click an item in your bag to sell it · Hover to see prices", 14, MUTED))


func show_shop(on: bool) -> void:
	shop_root.visible = on
	if on:
		refresh_shop()


func refresh_shop() -> void:
	if shop_root == null or not shop_root.visible:
		return
	var st: Dictionary = main.state
	var stock: Array = st.get("shop", [])
	for i in Data.SHOP_SLOTS:
		var sl: ItemSlot = _shop_grid.get_child(i)
		sl.index = i
		sl.set_item(stock[i] if i < stock.size() else {}, "SOLD")
	var bag: Array = st.get("bag", [])
	for i in MAX_BAG:
		var sl2: ItemSlot = _shop_bag.get_child(i)
		sl2.index = i
		sl2.set_item(bag[i] if i < bag.size() else {})
		sl2.visible = i < main.bag_size()
	_shop_gold.text = "%d gold" % int(st.get("gold", 0))
	var lvl := int(st.get("lvl", 1))
	_potion_btn.text = "Buy health potion · %d gold   (you have %d)" % [Data.potion_price(lvl), int(st.get("potions", 0))]
	_restock_btn.text = "Ask for new stock · %d gold" % Data.restock_price(lvl)


# ================================================================ forge
func _build_forge() -> void:
	forge_root = _full(ColorRect.new())
	(forge_root as ColorRect).color = Color(0.04, 0.03, 0.06, 0.78)
	forge_root.visible = false
	root.add_child(forge_root)
	var cc := _full(CenterContainer.new())
	forge_root.add_child(cc)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _sb(PANEL, LINE, 2, 18))
	p.add_child(Brackets.new())
	cc.add_child(p)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 24)
	p.add_child(h)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	left.custom_minimum_size = Vector2(640, 0)
	h.add_child(left)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	var face := portrait("smith", Vector2(60, 80))
	head.add_child(face)
	var hv := VBoxContainer.new()
	hv.add_child(_label("HEARTH FORGE", 11, EMBER, font_label))
	hv.add_child(_label("%s the Smith" % Data.SMITH_NAME, 26, EMBER_HI))
	hv.add_child(_label("Upgrade your gear or break it down. New pieces are made at an anvil.", 14, MUTED))
	head.add_child(hv)
	left.add_child(head)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	for t in [["upgrade", "Upgrade"], ["salvage", "Salvage"]]:
		var b := Button.new()
		b.text = t[1]
		b.custom_minimum_size = Vector2(120, 0)
		var tid: String = t[0]
		b.pressed.connect(func() -> void:
			_forge_tab = tid
			Sfx.play("ui_click", Vector3.INF, -6.0)
			refresh_forge())
		tabs.add_child(b)
		_forge_tabs[tid] = b
	left.add_child(tabs)

	# craft view
	var craft := VBoxContainer.new()
	craft.add_theme_constant_override("separation", 8)
	craft.add_child(_label("MATERIAL TIER", 11, EMBER, font_label))
	var tr := HBoxContainer.new()
	tr.add_theme_constant_override("separation", 6)
	for i in Data.CRAFT_TIERS.size():
		var b2 := Button.new()
		b2.custom_minimum_size = Vector2(150, 0)
		var ti := i
		b2.pressed.connect(func() -> void:
			_forge_tier = ti
			Sfx.play("ui_click", Vector3.INF, -6.0)
			refresh_forge())
		tr.add_child(b2)
		_tier_btns.append(b2)
	craft.add_child(tr)
	craft.add_child(_label("PIECE", 11, EMBER, font_label))
	var pr := HBoxContainer.new()
	pr.add_theme_constant_override("separation", 6)
	for sname: String in Items.SLOTS:
		var b3 := Button.new()
		b3.custom_minimum_size = Vector2(64, 64)
		b3.expand_icon = true
		b3.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b3.tooltip_text = Items.SLOT_NAMES[sname]
		b3.add_theme_constant_override("icon_max_width", 40)
		var sn := sname
		b3.pressed.connect(func() -> void:
			_forge_slot = sn
			Sfx.play("ui_click", Vector3.INF, -6.0)
			refresh_forge())
		pr.add_child(b3)
		_piece_btns[sname] = b3
	craft.add_child(pr)
	_recipe_box = VBoxContainer.new()
	_recipe_box.add_theme_constant_override("separation", 4)
	craft.add_child(_recipe_box)
	left.add_child(craft)
	craft.visible = false   # gear is made at the anvil now; Hilde upgrades and salvages

	# upgrade view
	var upg := VBoxContainer.new()
	upg.add_theme_constant_override("separation", 8)
	var uh := HBoxContainer.new()
	uh.add_theme_constant_override("separation", 18)
	var ulist := VBoxContainer.new()
	ulist.add_theme_constant_override("separation", 6)
	ulist.add_child(_label("WEARING", 11, EMBER, font_label))
	_upg_equip = GridContainer.new()
	_upg_equip.columns = 4
	_upg_equip.add_theme_constant_override("h_separation", 5)
	_upg_equip.add_theme_constant_override("v_separation", 5)
	for sname: String in Items.SLOTS:
		var sl := ItemSlot.new(self, "upg")
		sl.custom_minimum_size = Vector2(52, 52)
		sl.ref = ["equip", sname]
		sl.slot_name = sname
		_upg_equip.add_child(sl)
	ulist.add_child(_upg_equip)
	ulist.add_child(_label("BAG", 11, EMBER, font_label))
	_upg_bag = GridContainer.new()
	_upg_bag.columns = 6
	_upg_bag.add_theme_constant_override("h_separation", 5)
	_upg_bag.add_theme_constant_override("v_separation", 5)
	for i in MAX_BAG:
		var sl2 := ItemSlot.new(self, "upg")
		sl2.custom_minimum_size = Vector2(44, 44)
		sl2.ref = ["bag", i]
		_upg_bag.add_child(sl2)
	ulist.add_child(_upg_bag)
	uh.add_child(ulist)
	_upg_detail = VBoxContainer.new()
	_upg_detail.add_theme_constant_override("separation", 6)
	_upg_detail.custom_minimum_size = Vector2(250, 0)
	uh.add_child(_upg_detail)
	upg.add_child(uh)
	left.add_child(upg)
	_forge_views["upgrade"] = upg

	# salvage view
	var salv := VBoxContainer.new()
	salv.add_theme_constant_override("separation", 8)
	var srow := HBoxContainer.new()
	var sl3 := _label("Break gear down into materials. Rare and better can give Ember Shards.", 15, MUTED, null, true)
	sl3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	srow.add_child(sl3)
	var sall := Button.new()
	sall.text = "Salvage all Common"
	sall.pressed.connect(func() -> void: main.crafting.salvage_commons())
	srow.add_child(sall)
	salv.add_child(srow)
	_salv_bag = GridContainer.new()
	_salv_bag.columns = 8
	_salv_bag.add_theme_constant_override("h_separation", 6)
	_salv_bag.add_theme_constant_override("v_separation", 6)
	for i in MAX_BAG:
		var sl4 := ItemSlot.new(self, "salvage")
		sl4.index = i
		_salv_bag.add_child(sl4)
	salv.add_child(_salv_bag)
	left.add_child(salv)
	_forge_views["salvage"] = salv

	# right: materials
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	right.custom_minimum_size = Vector2(230, 0)
	h.add_child(right)
	var close := Button.new()
	close.text = "Close (G)"
	close.pressed.connect(func() -> void: main.toggle_forge())
	right.add_child(close)
	right.add_child(_label("MATERIALS", 11, EMBER, font_label))
	_forge_mats = VBoxContainer.new()
	_forge_mats.add_theme_constant_override("separation", 3)
	right.add_child(_forge_mats)
	_forge_gold = _label("", 20, EMBER_HI)
	right.add_child(_forge_gold)
	var tip := _label("Ore, logs and crystals are mined from nodes out in the world. Creatures drop the rest. Elites and Wardens drop Ember Shards.", 13, MUTED, null, true)
	tip.custom_minimum_size = Vector2(220, 0)
	right.add_child(tip)


func show_forge(on: bool) -> void:
	forge_root.visible = on
	if on:
		_upg_ref = []
		refresh_forge()


func select_upgrade(ref: Array) -> void:
	_upg_ref = ref
	Sfx.play("ui_click", Vector3.INF, -6.0)
	refresh_forge()


func _cost_rows(box: Container, cost: Dictionary) -> void:
	var cr: Crafting = main.crafting
	for k: String in cost:
		var need := int(cost[k])
		var have := int(main.state.get("gold", 0)) if k == "gold" else cr.count(k)
		var name: String = "Gold" if k == "gold" else Data.MATERIALS[k]["name"]
		var row := HBoxContainer.new()
		if k == "gold":
			var gs := ColorRect.new()
			gs.color = Color("ffd27a")
			gs.custom_minimum_size = Vector2(12, 12)
			gs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(gs)
		else:
			row.add_child(_mini_icon(Icons.material(k)))
		var l := _label("  %s  %d / %d" % [name, have, need], 16, Color("9fe0a0") if have >= need else Color("e05a4a"))
		row.add_child(l)
		box.add_child(row)


func refresh_forge() -> void:
	if forge_root == null or not forge_root.visible:
		return
	var cr: Crafting = main.crafting
	for k: String in _forge_views:
		(_forge_views[k] as Control).visible = k == _forge_tab
		(_forge_tabs[k] as Button).add_theme_stylebox_override("normal", _sb(PANEL2, EMBER_HI if k == _forge_tab else LINE, 2, 8))
	# materials
	for ch in _forge_mats.get_children():
		ch.queue_free()
	for k: String in Data.MAT_ORDER:
		if String(Data.MATERIALS[k].get("kind", "")) in ["tool", "potion", "bait"] or cr.held(k) <= 0:
			continue
		var row := HBoxContainer.new()
		row.add_child(_mini_icon(Icons.material(k)))
		var nl := _label("  " + String(Data.MATERIALS[k]["name"]), 15, TEXT)
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(nl)
		row.add_child(_label(str(cr.held(k)), 15, EMBER_HI if cr.held(k) > 0 else MUTED))
		_forge_mats.add_child(row)
	_forge_gold.text = "%d gold" % int(main.state.get("gold", 0))
	var cls: String = main.player.class_id
	match _forge_tab:
		"craft":
			for i in _tier_btns.size():
				var t: Dictionary = Data.CRAFT_TIERS[i]
				var b: Button = _tier_btns[i]
				var ok := cr.tier_unlocked(i, _forge_slot)
				b.text = t["name"] if ok else "%s · %s %d" % [t["name"], Data.SKILLS[Crafting.skill_for_slot(_forge_slot)]["name"], Data.TIER_SKILL_LVL[i]]
				b.disabled = not ok
				b.add_theme_stylebox_override("normal", _sb(PANEL2, EMBER_HI if i == _forge_tier else LINE, 2, 8))
			var mat_hex: String = Items.TIER_MATERIAL[_forge_tier][1]
			for sname: String in _piece_btns:
				var b4: Button = _piece_btns[sname]
				var ty: String = Items.WEAPON_FOR[cls] if sname == "weapon" else sname
				b4.icon = Items.icon({"type": ty, "mat": mat_hex, "rarity": 2, "armor": Items.ARMOR_FOR.get(cls, "") if sname != "weapon" else ""})
				b4.add_theme_stylebox_override("normal", _sb(PANEL2, EMBER_HI if sname == _forge_slot else LINE, 2, 4))
			for ch in _recipe_box.get_children():
				ch.queue_free()
			var tt: Dictionary = Data.CRAFT_TIERS[_forge_tier]
			var ty2: String = Items.WEAPON_FOR[cls] if _forge_slot == "weapon" else _forge_slot
			var nm := "%s %s %s" % ["Masterwork" if _forge_master else "Forged", tt["name"], Items.base_names(ty2, Items.ARMOR_FOR[cls] if ty2 in Items.ARMOR_SLOTS else "")[0]]
			_recipe_box.add_child(_label(nm, 22, Color(Items.RARITY_COLORS[3 if _forge_master else 2])))
			_recipe_box.add_child(_label("%s · Item level %d · stats favor your class" % ["Epic" if _forge_master else "Rare", tt["ilvl"]], 14, MUTED))
			_cost_rows(_recipe_box, Data.craft_cost(_forge_tier, _forge_slot, _forge_master))
			var mw := CheckBox.new()
			mw.text = "Masterwork (+1 Ember Shard)"
			mw.button_pressed = _forge_master
			mw.toggled.connect(func(on: bool) -> void:
				_forge_master = on
				refresh_forge())
			_recipe_box.add_child(mw)
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			var cb := Button.new()
			cb.text = "Craft"
			cb.custom_minimum_size = Vector2(140, 0)
			cb.disabled = not cr.tier_unlocked(_forge_tier, _forge_slot)
			cb.pressed.connect(func() -> void: cr.craft(_forge_tier, _forge_slot, _forge_master))
			row.add_child(cb)
			_recipe_box.add_child(row)
		"upgrade":
			var eq: Dictionary = main.state.get("equip", {})
			for sl: ItemSlot in _upg_equip.get_children():
				sl.set_item(eq.get(sl.slot_name, {}), Items.SLOT_NAMES[sl.slot_name].to_upper())
			var bag: Array = main.state.get("bag", [])
			for i in MAX_BAG:
				var sl2: ItemSlot = _upg_bag.get_child(i)
				sl2.set_item(bag[i] if i < bag.size() else {})
				sl2.visible = i < main.bag_size()
			for ch in _upg_detail.get_children():
				ch.queue_free()
			var item: Dictionary = main.item_ref(_upg_ref) if not _upg_ref.is_empty() else {}
			if item.is_empty():
				_upg_detail.add_child(_label("Pick an item to upgrade.", 16, MUTED, null, true))
				_upg_detail.add_child(_label("Each upgrade adds 10% to all of its stats, up to +5. The last step needs an Ember Shard.", 14, MUTED, null, true))
			else:
				var rt := RichTextLabel.new()
				rt.bbcode_enabled = true
				rt.fit_content = true
				rt.scroll_active = false
				rt.custom_minimum_size = Vector2(250, 0)
				rt.text = Items.tooltip(item, cls)
				_upg_detail.add_child(rt)
				var u := int(item.get("upg", 0))
				if u >= Data.UPGRADE_MAX:
					_upg_detail.add_child(_label("Fully upgraded.", 16, EMBER_HI))
				else:
					_upg_detail.add_child(_label("Next: +%d  (all stats +10%%)" % (u + 1), 16, EMBER_HI))
					_cost_rows(_upg_detail, Data.upgrade_cost(item))
					var ub := Button.new()
					ub.text = "Upgrade to +%d" % (u + 1)
					var r := _upg_ref.duplicate()
					ub.pressed.connect(func() -> void: cr.upgrade(r))
					_upg_detail.add_child(ub)
		"salvage":
			var bag2: Array = main.state.get("bag", [])
			for i in MAX_BAG:
				var sl3: ItemSlot = _salv_bag.get_child(i)
				sl3.index = i
				sl3.set_item(bag2[i] if i < bag2.size() else {})
				sl3.visible = i < main.bag_size()


# ================================================================ pause
func _build_pause() -> void:
	pause_root = _full(ColorRect.new())
	(pause_root as ColorRect).color = Color(0.04, 0.03, 0.06, 0.82)
	pause_root.visible = false
	root.add_child(pause_root)
	var cc := _full(CenterContainer.new())
	pause_root.add_child(cc)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _sb(PANEL, LINE, 2, 20))
	cc.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	p.add_child(v)
	v.add_child(_label("Paused", 36, EMBER_HI))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var resume := Button.new()
	resume.text = "Resume"
	resume.pressed.connect(func() -> void: main.toggle_pause())
	var menu := Button.new()
	menu.text = "Save & main menu"
	menu.pressed.connect(func() -> void: main.to_main_menu())
	var sett := Button.new()
	sett.text = "Settings"
	sett.pressed.connect(func() -> void: main.toggle_window("settings"))
	row.add_child(resume)
	row.add_child(sett)
	row.add_child(menu)
	v.add_child(row)
	v.add_child(_label("SWITCH CLASS", 11, EMBER, font_label))
	v.add_child(_label("Story progress and skills carry over. Each class levels its own combat skill (Warrior and Rogue share Melee).", 15, MUTED))
	_pause_classes = GridContainer.new()
	_pause_classes.columns = 4
	_pause_classes.add_theme_constant_override("h_separation", 10)
	v.add_child(_pause_classes)
	v.add_child(_label("TESTING: SET COMBAT LEVEL", 11, EMBER, font_label))
	v.add_child(_label("Abilities unlock at levels 1, 1, 3, 5, 8 and 12.", 15, MUTED))
	var lv := HBoxContainer.new()
	lv.add_theme_constant_override("separation", 8)
	for l in [1, 3, 5, 8, 12, 15]:
		var b := Button.new()
		b.text = "LV %d" % l
		b.custom_minimum_size = Vector2(64, 0)
		b.pressed.connect(func() -> void: main.set_level(l))
		lv.add_child(b)
	var mx := Button.new()
	mx.text = "All skills %d" % Data.MAX_SKILL
	mx.pressed.connect(func() -> void: main.max_all_skills())
	lv.add_child(mx)
	v.add_child(lv)


func show_pause(on: bool) -> void:
	pause_root.visible = on
	if on:
		for c in _pause_classes.get_children():
			c.queue_free()
		for id: String in Data.CLASS_ORDER:
			_pause_classes.add_child(_class_card(id, func(cid: String) -> void: main.switch_class(cid), id == main.player.class_id, true))


# ================================================================ quest book + settings windows
func _build_windows() -> void:
	## quest book, skills, settings and crafting stations draw into the side panel
	# crafting stations, skills, quest book, settings: a centered window like the talent tree
	_win_overlay = _full(CenterContainer.new())
	_win_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_win_overlay.visible = false
	root.add_child(_win_overlay)
	var wp := PanelContainer.new()
	wp.add_theme_stylebox_override("panel", _sb(PANEL, LINE, 2, 12))
	wp.add_child(Brackets.new())
	_win_overlay.add_child(wp)
	var wv := VBoxContainer.new()
	wv.add_theme_constant_override("separation", 10)
	wp.add_child(wv)
	var wh := HBoxContainer.new()
	_win_title = _label("", 16, EMBER_HI, font_label)
	_win_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wh.add_child(_win_title)
	var wx := Button.new()
	wx.text = "X"
	wx.focus_mode = Control.FOCUS_NONE
	wx.custom_minimum_size = Vector2(28, 24)
	wx.pressed.connect(func() -> void: close_side())
	wh.add_child(wx)
	wv.add_child(wh)
	_win_body = VBoxContainer.new()
	_win_body.add_theme_constant_override("separation", 8)
	_win_body.custom_minimum_size = Vector2(560, 0)
	wv.add_child(_win_body)
	_win_root = wp
	_win_vbox = wv


## Open a tab in the side panel. The game keeps running behind it.
func open_side(tab: String) -> void:
	if tab == "talents":
		toggle_talents(true)
		return
	side_tab = tab
	var in_side: bool = tab in ["char", "bag", "skills", "abilities", "book"]
	var in_chat: bool = tab in STATIONS
	_side.visible = in_side
	_win_overlay.visible = not in_side and not in_chat
	if not in_chat:
		_craft_open = false
		_set_chat_mode(false)
	_side_char.visible = tab == "char"
	_side_bag.visible = tab == "bag"
	_side_dyn.visible = in_side and not (tab in ["char", "bag"])
	var vh := get_viewport().get_visible_rect().size.y
	var h := clampf(vh - SIDE_BOTTOM - 250.0, 300.0, 540.0)
	# exactly as wide as the button row underneath it, right edges lined up
	var w := 330.0
	_side.custom_minimum_size = Vector2(w, h)
	_side.offset_right = -14.0
	_side.offset_left = -14.0 - w
	_side.offset_bottom = -SIDE_BOTTOM
	_side.offset_top = -SIDE_BOTTOM - 10.0    # grows up to fit its contents, no scrolling
	_side.custom_minimum_size = Vector2(w, 0)
	match tab:
		"char":
			_side_title.text = "Character"
			refresh_inventory()
		"bag":
			_side_title.text = "Bag"
			refresh_inventory()
		_:
			show_window(tab)
	_fit_side.call_deferred()
	for k: String in _micro_btns:
		var on: bool = {"char": "char", "bag": "bag", "book": "book", "skills": "skills", "abilities": "abilities", "talents": "talents", "gear": "settings"}.get(k, "") == tab
		(_micro_btns[k] as Button).add_theme_stylebox_override("normal", _sb(PANEL2 if on else PANEL, EMBER_HI if on else LINE, 2, 0))
	_place_tracker()
	main.on_side_changed()


func close_side() -> void:
	if not _side.visible and not _win_overlay.visible and not _craft_open:
		return
	side_tab = ""
	_win_kind = ""
	_craft_target = ""
	cancel_use()
	_close_ctx()
	_craft_open = false
	_set_chat_mode(false)
	_side.visible = false
	_win_overlay.visible = false
	for k: String in _micro_btns:
		(_micro_btns[k] as Button).add_theme_stylebox_override("normal", _sb(PANEL, LINE, 2, 0))
	_place_tracker()
	main.on_side_changed()
	Sfx.play("ui_close", Vector3.INF, -8.0)


## Use item on item: open the chat-box grid for `station`, narrowed to recipes that take `target`.
func open_combo(station: String, target: String) -> void:
	_craft_target = target
	Sfx.play("ui_open", Vector3.INF, -8.0)
	open_side(station)


func toggle_side(tab: String) -> void:
	if tab in STATIONS and not (side_tab == tab and _craft_open):
		_craft_target = ""
	if tab == "talents":
		toggle_talents()
		return
	if side_tab == tab and (_side.visible or _win_overlay.visible or _craft_open):
		close_side()
	else:
		if not _side.visible and not _win_overlay.visible and not _craft_open:
			Sfx.play("ui_open", Vector3.INF, -8.0)
		open_side(tab)


## The quest tracker stays put. If a side panel ends up over it, it just fades back.
func _place_tracker() -> void:
	pass


func show_window(w: String) -> void:
	if w == "":
		close_side()
		return
	for c in _win_body.get_children():
		_win_body.remove_child(c)
		c.queue_free()
	_win_kind = w
	var docked := w in ["skills", "abilities", "book"]
	if w in STATIONS:
		_win_overlay.visible = false
		_side.visible = false
		_craft_open = true
		_set_chat_mode(true)
		_fill_craft(w)
		return
	_craft_open = false
	_set_chat_mode(false)
	var want: Node = _side_dyn if docked else _win_vbox
	if _win_body.get_parent() != want:
		_win_body.reparent(want)
	var ttl: Label = _side_title if docked else _win_title
	_win_body.custom_minimum_size = Vector2(300 if docked else (540 if w == "settings" else 560), 0)
	match w:
		"skills":
			ttl.text = "Skills · Total %d" % main.skills.total_level()
			_fill_skills()
		"abilities":
			ttl.text = "Abilities"
			_fill_abilities()
		"anvil":
			ttl.text = "What would you like to make?"
			_fill_make_popup(w)
		"book":
			ttl.text = "Quest Book"
			_fill_book()
		"settings":
			ttl.text = "Settings"
			_fill_settings()
	_fit_side.call_deferred()


func _section(text: String) -> void:
	var l := _label(text, 11, EMBER, font_label)
	_win_body.add_child(l)


func _book_entry(title: String, status: String, status_col: Color, body: String) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _sb(PANEL2, LINE, 1, 6))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	p.add_child(v)
	var t := _label(title, 14, TEXT, null, true)
	t.custom_minimum_size = Vector2(280, 0)
	v.add_child(t)
	v.add_child(_label(status, 10, status_col, font_label))
	if body != "":
		var b := _label(body, 12, MUTED, null, true)
		b.custom_minimum_size = Vector2(280, 0)
		v.add_child(b)
	_win_body.add_child(p)


## Lay the cards of the open window out in two columns so it fits on screen without scrolling.
func _two_cols(skip := 0) -> void:
	var cards: Array = []
	for c in _win_body.get_children():
		if c is PanelContainer:
			cards.append(c)
	if cards.size() < skip + 2:
		return
	var idx: int = (cards[skip] as Control).get_index()
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for i in range(skip, cards.size()):
		var c: Control = cards[i]
		_win_body.remove_child(c)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(c)
	_win_body.add_child(grid)
	_win_body.move_child(grid, idx)


## Split the open window's rows into two balanced columns (settings).
func _split_cols(tail := 0) -> void:
	var kids: Array = _win_body.get_children()
	var tail_nodes: Array = kids.slice(kids.size() - tail) if tail > 0 else []
	kids = kids.slice(0, kids.size() - tail)
	var total := 0.0
	for c: Control in kids:
		total += c.get_combined_minimum_size().y + 8.0
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 24)
	var cols: Array[VBoxContainer] = []
	for i in 2:
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 8)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(v)
		cols.append(v)
	var acc := 0.0
	var col := 0
	for c: Control in kids:
		var hh := c.get_combined_minimum_size().y + 8.0
		var is_head: bool = c is Label and (c as Label).text == (c as Label).text.to_upper()
		if col == 0 and is_head and acc + hh * 0.5 > total * 0.5:
			col = 1
		_win_body.remove_child(c)
		cols[col].add_child(c)
		acc += hh
	_win_body.add_child(hb)
	for t: Control in tail_nodes:
		_win_body.move_child(t, -1)


func _fill_book() -> void:
	var st: Dictionary = main.state
	var done: bool = st.get("done", false)
	var bi := int(st.get("bi", 0))
	_section("MAIN STORY")
	if done:
		_book_entry("The Four Wardens", "DEFEATED", Color("8ad07a"), "")
	else:
		var b: Dictionary = Data.BOSSES[bi]
		var q: Dictionary = main.quest_info(false)
		_book_entry(b["name"], "WARDEN %d OF 4 · LV %d" % [bi + 1, b["rec"]], EMBER_HI, q["text"])
	_section("QUESTS YOU HAVE")
	var shown := 0
	if main.online != null:
		for e: Dictionary in main.online.journal:
			if not bool(e["active"]):
				continue   # only the quests you have taken, not every quest in the world
			shown += 1
			var ready: bool = str(e["status"]) == "ready"
			var body := PackedStringArray()
			var tip := ""
			for stp: Dictionary in e["steps"]:
				var prog := "" if int(stp["count"]) <= 1 else " (%d/%d)" % [int(stp["progress"]), int(stp["count"])]
				if bool(stp["done"]):
					body.append("[x] %s" % stp["title"])
				elif bool(stp["current"]):
					body.append("[>] %s: %s%s" % [stp["title"], stp["label"], prog])
					tip = str(stp["tip"])
				else:
					body.append("[ ] %s" % stp["title"])
			var text := "\n".join(body)
			if tip != "":
				text += "\n\nHow: %s" % tip
			if ready:
				text += "\n\nGo back to %s to hand it in." % e["npc_name"]
			_book_entry(str(e["quest"]), ("READY TO HAND IN" if ready else "IN PROGRESS") + " - " + str(e["npc_name"]), Color("8ad07a") if ready else Color("9fd0ff"), text)
	else:
		var q2 = main.quests
		for sq: Dictionary in Data.SIDE_QUESTS:
			var id: String = sq["id"]
			var stage := int(q2._qs(id)["stage"])
			var chain: Array = sq["quests"]
			if stage >= chain.size():
				continue
			var c: Dictionary = chain[stage]
			var where: String = sq["name"]
			match q2.status(id):
				"active":
					shown += 1
					var prog2 := "" if int(c["count"]) <= 1 else " %d/%d" % [int(q2._qs(id)["progress"]), int(c["count"])]
					_book_entry(c["title"], "IN PROGRESS", Color("9fd0ff"), "%s%s" % [c.get("tip", c["label"]), prog2])
				"ready":
					shown += 1
					_book_entry(c["title"], "COMPLETE", Color("8ad07a"), "Return to %s" % where)
	if shown == 0:
		_win_body.add_child(_label("No quests yet. Talk to the people around you: look for the ! above their heads.", 14, MUTED))


func _fill_settings() -> void:
	_section("GAME")
	var gr := HBoxContainer.new()
	gr.add_theme_constant_override("separation", 6)
	var sv_btn := Button.new()
	sv_btn.text = "Save"
	sv_btn.pressed.connect(func() -> void:
		main.save_game()
		toast("Game saved"))
	gr.add_child(sv_btn)
	var mm := Button.new()
	mm.text = "Save & main menu"
	mm.pressed.connect(func() -> void: main.to_main_menu())
	gr.add_child(mm)
	_win_body.add_child(gr)
	_section("SOUND")
	var vol := VBoxContainer.new()
	vol.add_theme_constant_override("separation", 4)
	for bus: Array in [["Master", "Master"], ["Music", "Music"], ["SFX", "Effects"]]:
		var box := VBoxContainer.new()
		box.add_child(_label(bus[1], 14, MUTED))
		var sl := HSlider.new()
		sl.min_value = 0.0
		sl.max_value = 1.0
		sl.step = 0.05
		sl.custom_minimum_size = Vector2(230, 16)
		sl.value = Sfx.inst.volumes.get(bus[0], 0.8) if Sfx.inst else 0.8
		var bn: String = bus[0]
		var on_vol := func(val: float) -> void:
			if Sfx.inst:
				Sfx.inst.set_volume(bn, val)
				Sfx.play("ui_click", Vector3.INF, -6.0)
		sl.value_changed.connect(on_vol)
		box.add_child(sl)
		vol.add_child(box)
	_win_body.add_child(vol)
	_section("DISPLAY")
	var us := HBoxContainer.new()
	us.add_theme_constant_override("separation", 6)
	us.add_child(_label("UI size", 14, MUTED))
	var us_val := _label("%d%%" % roundi(ui_scale * 100.0), 14, TEXT)
	us_val.custom_minimum_size = Vector2(48, 0)
	us_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var us_dn := Button.new()
	us_dn.text = "-"
	us_dn.custom_minimum_size = Vector2(30, 0)
	us_dn.pressed.connect(func() -> void:
		set_ui_scale(ui_scale - 0.1)
		show_window("settings"))
	var us_up := Button.new()
	us_up.text = "+"
	us_up.custom_minimum_size = Vector2(30, 0)
	us_up.pressed.connect(func() -> void:
		set_ui_scale(ui_scale + 0.1)
		show_window("settings"))
	var us_rs := Button.new()
	us_rs.text = "Reset"
	us_rs.pressed.connect(func() -> void:
		set_ui_scale(1.0)
		show_window("settings"))
	us.add_child(us_dn)
	us.add_child(us_val)
	us.add_child(us_up)
	us.add_child(us_rs)
	us.add_child(_label("(Ctrl +/-)", 11, MUTED))
	_win_body.add_child(us)
	var vd := HBoxContainer.new()
	vd.add_theme_constant_override("separation", 6)
	vd.add_child(_label("Draw distance", 14, MUTED))
	var vd_val := _label("%d m" % (main.world.streamer.view_chunks * 32), 14, TEXT)
	vd_val.custom_minimum_size = Vector2(64, 0)
	vd_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var vd_dn := Button.new()
	vd_dn.text = "-"
	vd_dn.custom_minimum_size = Vector2(30, 0)
	vd_dn.pressed.connect(func() -> void:
		set_view_distance(main.world.streamer.view_chunks - 1)
		show_window("settings"))
	var vd_up := Button.new()
	vd_up.text = "+"
	vd_up.custom_minimum_size = Vector2(30, 0)
	vd_up.pressed.connect(func() -> void:
		set_view_distance(main.world.streamer.view_chunks + 1)
		show_window("settings"))
	vd.add_child(vd_dn)
	vd.add_child(vd_val)
	vd.add_child(vd_up)
	_win_body.add_child(vd)
	var fs := CheckBox.new()
	fs.text = "Fullscreen"
	fs.button_pressed = DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
	fs.toggled.connect(func(on: bool) -> void:
		_set_fullscreen(on)
		_save_game_setting("fullscreen", on))
	_win_body.add_child(fs)
	var dn := CheckBox.new()
	dn.text = "Show damage numbers"
	dn.button_pressed = show_damage_numbers
	dn.toggled.connect(func(on: bool) -> void:
		show_damage_numbers = on
		_save_game_setting("damage_numbers", on))
	_win_body.add_child(dn)
	var cf2 := CheckBox.new()
	cf2.text = "Camera drifts behind me when walking"
	cf2.button_pressed = main.rig.follow_enabled
	cf2.toggled.connect(func(on: bool) -> void:
		main.rig.follow_enabled = on
		_save_game_setting("camera_follow", on))
	_win_body.add_child(cf2)
	_section("TESTING")
	var dv := CheckBox.new()
	dv.text = "Dev mode"
	dv.tooltip_text = "unlimited gold, quests fill themselves. F1 fly, F2 teleport panel"
	dv.button_pressed = main.dev_mode
	dv.toggled.connect(func(on: bool) -> void:
		main.set_dev_mode(on)
		_save_game_setting("dev_mode", on))
	_win_body.add_child(dv)
	_win_body.add_child(_label("Switch style (testing only)", 13, MUTED))
	var cg := GridContainer.new()
	cg.columns = 4
	for cid: String in Data.CLASS_ORDER:
		var cb2 := Button.new()
		cb2.text = Data.CLASSES[cid]["name"]
		cb2.disabled = cid == main.player.class_id
		var c_id := cid
		cb2.pressed.connect(func() -> void: main.switch_class(c_id))
		cg.add_child(cb2)
	_win_body.add_child(cg)
	_win_body.add_child(_label("Set combat level", 13, MUTED))
	var lg := GridContainer.new()
	lg.columns = 4
	for l: int in [1, 3, 5, 8, 12, 15]:
		var lb := Button.new()
		lb.text = "LV %d" % l
		lb.pressed.connect(func() -> void: main.set_level(l))
		lg.add_child(lb)
	var mxb := Button.new()
	mxb.text = "All skills %d" % Data.MAX_SKILL
	mxb.pressed.connect(func() -> void: main.max_all_skills())
	lg.add_child(mxb)
	_win_body.add_child(lg)
	_section("CAMERA")
	var cb := VBoxContainer.new()
	cb.add_child(_label("Mouse orbit speed", 14, MUTED))
	var cs := HSlider.new()
	cs.min_value = 0.002
	cs.max_value = 0.02
	cs.step = 0.001
	cs.custom_minimum_size = Vector2(280, 18)
	cs.value = main.rig.drag_sensitivity
	cs.value_changed.connect(func(val: float) -> void:
		main.rig.drag_sensitivity = val
		_save_game_setting("orbit_speed", val))
	cb.add_child(cs)
	_win_body.add_child(cb)
	_section("STUCK?")
	var stuck := Button.new()
	stuck.text = "I'm stuck: take me to the shrine"
	stuck.custom_minimum_size = Vector2(230, 0)
	stuck.pressed.connect(func() -> void: main.unstick())
	_win_body.add_child(stuck)
	_section("CONTROLS")
	var ctl := _label("W S move · A D turn (strafe while right mouse is held) · Q E strafe\nRight-drag: steer · Left-drag: orbit camera · both: run forward\nClick / Tab: target · right-click enemy: attack\n1-6 action bar · N abilities (fill your bar) · G interact\nR autorun · Space jump · Shift sprint\nRight-click potions/food in your bag to use them (or H · X · Y · V)\nK character · U skills · B bag · L quests · M map · O / Esc menu\nWheel: zoom (all the way in = first person)", 12, TEXT, null, true)
	ctl.custom_minimum_size = Vector2(300, 0)
	ctl.custom_minimum_size = Vector2(520, 0)
	_win_body.add_child(ctl)
	_split_cols(2)


func _set_fullscreen(on: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)


func _save_game_setting(key: String, val: Variant) -> void:
	var cf := ConfigFile.new()
	cf.load("user://settings.cfg")
	cf.set_value("game", key, val)
	cf.save("user://settings.cfg")


func _load_game_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load("user://settings.cfg") != OK:
		return
	set_ui_scale(float(cf.get_value("game", "ui_scale", 1.0)), false)
	set_view_distance(int(cf.get_value("game", "view_chunks", 9)), false)
	show_damage_numbers = bool(cf.get_value("game", "damage_numbers", true))
	main.dev_mode = bool(cf.get_value("game", "dev_mode", false))
	main.rig.drag_sensitivity = float(cf.get_value("game", "orbit_speed", main.rig.drag_sensitivity))
	main.rig.follow_enabled = bool(cf.get_value("game", "camera_follow", true))
	if bool(cf.get_value("game", "fullscreen", false)):
		_set_fullscreen(true)


func refresh_window() -> void:
	refresh_talents()
	if (_win_overlay.visible or _side_dyn.visible or _craft_open) and _win_kind != "" and not (_win_kind in ["char", "bag"]):
		show_window(_win_kind)


# ---------------------------------------------------------------- skills window
## A small pixel icon for lists. Ignores the mouse so buttons around it still work.
func _mini_icon(tex: Texture2D, px := 20) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.custom_minimum_size = Vector2(px, px)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


func _skill_bar(id: String, h := 6) -> ProgressBar:
	var sk = main.skills
	var lvl: int = sk.level(id)
	var b := _bar(Color(Data.SKILLS[id]["color"]), h, false)
	if lvl >= Data.MAX_SKILL:
		b.max_value = 1
		b.value = 1
	else:
		b.max_value = Data.xp_needed(lvl)
		b.value = sk.xp(id) - Data.xp_for_level(lvl)
	return b


func _fill_skills() -> void:
	var sk = main.skills
	if _skill_sel != "":
		_fill_skill_detail(sk)
		return
	var hint := _label("Click a skill to see what it unlocks.", 13, MUTED, null, true)
	hint.custom_minimum_size = Vector2(290, 0)
	_win_body.add_child(hint)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)
	for id: String in Data.SKILL_ORDER:
		var d: Dictionary = Data.SKILLS[id]
		var col := Color(d["color"])
		var b := Button.new()
		b.custom_minimum_size = Vector2(150, 40)
		b.focus_mode = Control.FOCUS_NONE
		var sel := id == _skill_sel
		b.add_theme_stylebox_override("normal", _sb(PANEL2, col if sel else LINE, 2, 6))
		b.add_theme_stylebox_override("hover", _sb(PANEL2, col.lightened(0.3), 2, 6))
		b.add_theme_stylebox_override("pressed", _sb(PANEL2, Color.WHITE, 2, 6))
		var v := VBoxContainer.new()
		_full(v)
		v.offset_left = 6
		v.offset_right = -6
		v.offset_top = 5
		v.offset_bottom = -5
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_theme_constant_override("separation", 3)
		var hh := HBoxContainer.new()
		hh.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sw := _mini_icon(Icons.skill(id), 22)
		hh.add_child(sw)
		var nm := _label(" " + String(d["name"]), 13, TEXT)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.clip_text = true
		hh.add_child(nm)
		hh.add_child(_label(str(sk.level(id)), 15, EMBER_HI))
		v.add_child(hh)
		var bar := _skill_bar(id)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(bar)
		b.add_child(v)
		var sid := id
		b.pressed.connect(func() -> void:
			_skill_sel = sid
			Sfx.play("ui_click", Vector3.INF, -6.0)
			show_window("skills"))
		grid.add_child(b)
	_win_body.add_child(grid)


## One skill's guide, shown over the skill list. Back returns to the list.
func _fill_skill_detail(sk: Variant) -> void:
	var back := Button.new()
	back.text = "‹  All skills"
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(func() -> void:
		_skill_sel = ""
		Sfx.play("ui_click", Vector3.INF, -6.0)
		show_window("skills"))
	_win_body.add_child(back)
	# detail: the skill guide
	var d2: Dictionary = Data.SKILLS[_skill_sel]
	var lvl: int = sk.level(_skill_sel)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _sb(PANEL2, Color(d2["color"]), 2, 12))
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 6)
	p.add_child(dv)
	var head := HBoxContainer.new()
	head.add_child(_mini_icon(Icons.skill(_skill_sel), 30))
	var t := _label(" %s  %d" % [d2["name"], lvl], 18, Color(d2["color"]).lightened(0.3))
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	dv.add_child(head)
	var nxt := "MAX LEVEL" if lvl >= Data.MAX_SKILL else "%d xp to level %d" % [Data.xp_for_level(lvl + 1) - sk.xp(_skill_sel), lvl + 1]
	dv.add_child(_label(nxt.to_upper(), 10, EMBER_HI, font_label))
	var desc := _label(d2["desc"], 14, MUTED, null, true)
	desc.custom_minimum_size = Vector2(270, 0)
	dv.add_child(desc)
	if _skill_sel == sk.combat_id():
		var cl := _label("Your combat skill as a %s: this is your level." % Data.CLASSES[main.state["cls"]]["name"], 13, EMBER_HI, null, true)
		cl.custom_minimum_size = Vector2(270, 0)
		dv.add_child(cl)
	for u: Array in d2["unlocks"]:
		var have := lvl >= int(u[0])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var lv := _label("%2d" % int(u[0]), 14, Color("8ad07a") if have else MUTED)
		lv.custom_minimum_size = Vector2(24, 0)
		row.add_child(lv)
		var ut := _label(String(u[1]), 14, TEXT if have else MUTED, null, true)
		ut.custom_minimum_size = Vector2(215, 0)
		row.add_child(ut)
		dv.add_child(row)
	_win_body.add_child(p)


# ---------------------------------------------------------------- abilities window
var _abil_style := ""
const STYLE_KITS := {"melee": ["warrior"], "ranged": ["hunter"], "magic": ["mage"]}
const KIT_NEEDS := {"warrior": "a melee weapon", "hunter": "a bow", "mage": "a staff"}


func _fill_abilities() -> void:
	var cid: String = main.player.class_id
	var cur_style: String = Data.COMBAT_SKILL[cid]
	if _abil_style == "":
		_abil_style = cur_style
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	for st: String in ["melee", "ranged", "magic"]:
		var tb := Button.new()
		tb.text = String(Data.SKILLS[st]["name"])
		tb.focus_mode = Control.FOCUS_NONE
		tb.custom_minimum_size = Vector2(90, 28)
		var sel := st == _abil_style
		for stn: String in ["normal", "hover", "pressed"]:
			tb.add_theme_stylebox_override(stn, _sb(PANEL2 if not sel else Color("3a2a1a"), EMBER_HI if sel else LINE, 2, 6))
		tb.add_theme_color_override("font_color", EMBER_HI if sel else (TEXT if st == cur_style else MUTED))
		tb.tooltip_text = "Your current style" if st == cur_style else "Equip a %s weapon to use these" % String(Data.SKILLS[st]["name"]).to_lower()
		var stc := st
		tb.pressed.connect(func() -> void:
			_abil_style = stc
			refresh_window())
		tabs.add_child(tb)
	_win_body.add_child(tabs)
	var hint := _label("Pick a key (1-6) to put an ability on your bar. Each style keeps its own bar, and your weapon picks the style. Learn more in Talents.", 12, MUTED, null, true)
	hint.custom_minimum_size = Vector2(290, 0)
	_win_body.add_child(hint)
	for kit: String in STYLE_KITS[_abil_style]:
		var mine: bool = kit == cid
		if (STYLE_KITS[_abil_style] as Array).size() > 1 or not mine:
			var hl := _label(("%s  ·  %s" % [Data.CLASSES[kit]["name"], Data.CLASSES[kit]["resource"]]).to_upper() + ("" if mine else "  ·  needs " + String(KIT_NEEDS[kit])), 11, EMBER_HI if mine else MUTED, font_label)
			_win_body.add_child(hl)
		_fill_kit_abilities(kit, mine)


func _fill_kit_abilities(cid: String, interactive: bool) -> void:
	var res_name: String = Data.CLASSES[cid]["resource"]
	var abil: Array = Data.ABILITIES[cid]
	var style_lvl: int = Data.level_for_xp(main.skills.xp(Data.COMBAT_SKILL[cid]))
	for i in abil.size():
		var a: Dictionary = main.ability_view(abil[i]) if interactive else abil[i]
		var hue := Color(a["hue"])
		var why: String = main.ability_locked(i) if interactive else ("LV %d" % int(a["lvl"]) if style_lvl < int(a["lvl"]) else ("TALENT" if a.has("talent") and main.talent_rank(a["talent"]) <= 0 else ""))
		var locked: bool = why != ""
		if locked:
			continue
		var slot: int = main.ability_slot(i) if interactive else -1
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", _sb(PANEL2, hue if slot >= 0 else LINE, 2 if slot >= 0 else 1, 5))
		p.tooltip_text = "%s\n%s" % [a["name"], a["desc"]]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		p.add_child(row)
		var ic := PanelContainer.new()
		ic.custom_minimum_size = Vector2(36, 36)
		ic.add_theme_stylebox_override("panel", _sb(hue.darkened(0.3), OUTLINE, 2, 0))
		var aic2: Texture2D = Icons.ability(String(a["id"]))
		if aic2 != null:
			ic.add_child(_mini_icon(aic2, 32))
		else:
			var il := _outlined(_label(a["ab"], 15, Color.WHITE), 4)
			il.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			il.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			ic.add_child(il)
		row.add_child(ic)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cost: int = a["cost"]
		var cost_txt := ("%d %s" % [cost, res_name]) if cost > 0 else "No cost"
		v.add_child(_label(String(a["name"]), 14, MUTED if locked else TEXT))
		var meta := "%s · %ss" % [cost_txt, str(a["cd"])]
		meta += (" · " + ("LEARN IN TALENTS" if why == "TALENT" else why)) if locked else (" · LV %d" % a["lvl"] if int(a["lvl"]) > 1 else "")
		v.add_child(_label(meta.to_upper(), 10, EMBER_HI if not locked else MUTED, font_label))
		row.add_child(v)
		var keys := HBoxContainer.new()
		keys.visible = interactive
		keys.add_theme_constant_override("separation", 4)
		keys.add_child(_label("KEY", 10, MUTED, font_label))
		var bar_now: Array = main.state.get("bar", [])
		for k in 6:
			var kb := Button.new()
			kb.focus_mode = Control.FOCUS_NONE
			kb.custom_minimum_size = Vector2(34, 26)
			kb.text = str(Data.ABILITY_KEYS[k])
			var mine := slot == k
			var taken: bool = (not mine) and bar_now.size() > k and int(bar_now[k]) >= 0
			var fill := hue.darkened(0.2) if mine else PANEL
			var edge := hue.lightened(0.4) if mine else (LINE if not taken else Color(0.3, 0.28, 0.34))
			for st: String in ["normal", "hover", "pressed"]:
				kb.add_theme_stylebox_override(st, _sb(fill.lightened(0.12) if st == "hover" else fill, edge.lightened(0.3) if st == "hover" else edge, 2, 4))
			kb.add_theme_color_override("font_color", Color.WHITE if mine else (MUTED if taken else TEXT))
			kb.tooltip_text = "Remove from key %s" % Data.ABILITY_KEYS[k] if mine else ("Put on key %s%s" % [Data.ABILITY_KEYS[k], " (replaces what's there)" if taken else ""])
			var ii := i
			var kk := k
			kb.pressed.connect(func() -> void: main.set_bar_slot(ii, kk))
			keys.add_child(kb)
		p.modulate = Color(1, 1, 1, 1.0 if interactive else 0.55)
		var col2 := VBoxContainer.new()
		col2.add_theme_constant_override("separation", 5)
		p.remove_child(row)
		col2.add_child(row)
		col2.add_child(keys)
		p.add_child(col2)
		_win_body.add_child(p)


# ---------------------------------------------------------------- talents window (centred, WoW-style)
const TAL_CW := 84.0
const TAL_CH := 74.0
const TAL_COLS := 4
const TAL_TIERS := 6
var talent_root: Control
var _tal_body: VBoxContainer


func talents_open() -> bool:
	return talent_root != null and talent_root.visible


func toggle_talents(on: bool = not talents_open()) -> void:
	if talent_root == null:
		talent_root = _full(ColorRect.new())
		(talent_root as ColorRect).color = Color(0.03, 0.02, 0.05, 0.6)
		root.add_child(talent_root)
		var cc := _full(CenterContainer.new())
		talent_root.add_child(cc)
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", _sb(PANEL, LINE, 2, 16))
		cc.add_child(p)
		_tal_body = VBoxContainer.new()
		_tal_body.add_theme_constant_override("separation", 10)
		p.add_child(_tal_body)
	talent_root.visible = on
	if on:
		Sfx.play("ui_open", Vector3.INF, -8.0)
		refresh_talents()
		var k := "talents"
		if _micro_btns.has(k):
			(_micro_btns[k] as Button).add_theme_stylebox_override("normal", _sb(PANEL2, EMBER_HI, 2, 0))
	else:
		Sfx.play("ui_close", Vector3.INF, -8.0)
		if _micro_btns.has("talents"):
			(_micro_btns["talents"] as Button).add_theme_stylebox_override("normal", _sb(PANEL, LINE, 2, 0))


func _initials(nm: String) -> String:
	var parts := nm.split(" ", false)
	if parts.size() >= 2:
		return (parts[0].substr(0, 1) + parts[1].substr(0, 1)).to_upper()
	return nm.substr(0, 2).to_upper()


func refresh_talents() -> void:
	if not talents_open():
		return
	for c in _tal_body.get_children():
		c.queue_free()
	var cid: String = main.player.class_id
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	_tal_body.add_child(head)
	var title := _label("Talents", 22, EMBER_HI, font_label)
	head.add_child(title)
	var close := Button.new()
	close.text = "X"
	close.focus_mode = Control.FOCUS_NONE
	close.custom_minimum_size = Vector2(34, 30)
	close.pressed.connect(func() -> void: toggle_talents(false))
	if not Data.TALENT_TREES.has(cid):
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(sp)
		head.add_child(close)
		var soon := _label("%s talents are coming soon. Rogues are first." % Data.CLASSES[cid]["name"], 14, MUTED, null, true)
		soon.custom_minimum_size = Vector2(420, 0)
		_tal_body.add_child(soon)
		return
	var trees: Array = Data.TALENT_TREES[cid]
	var left: int = main.talent_points_left()
	var total: int = main.talent_points_total()
	var pts := _label("Points available: %d" % left, 17, EMBER_HI if left > 0 else MUTED)
	head.add_child(pts)
	var spent_txt := "  ·  spent %d of %d  (" % [main.talent_points_spent(), total]
	var bits: Array = []
	for t: Dictionary in trees:
		bits.append("%s %d" % [t["name"], main.talent_points_spent(t["id"])])
	spent_txt += " / ".join(bits) + ")"
	var sub := _label(spent_txt, 13, MUTED)
	head.add_child(sub)
	var sp2 := Control.new()
	sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp2)
	var reset := Button.new()
	reset.text = "Reset all"
	reset.focus_mode = Control.FOCUS_NONE
	reset.tooltip_text = "Refund every talent point (free)"
	reset.disabled = main.talent_points_spent() == 0
	reset.pressed.connect(func() -> void: main.reset_talents())
	head.add_child(reset)
	head.add_child(close)
	_tal_body.add_child(_label("Put points into more than one tree for a hybrid build.   Round icons are passives, square icons teach an ability.   Left-click adds a point, right-click takes one back. You earn one every 2 levels (15 total). Each row opens after 2 more points in that tree, and the bottom ability needs 10, so a true hybrid cannot reach it.", 12, MUTED, null, true))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_tal_body.add_child(row)
	for t: Dictionary in trees:
		row.add_child(_talent_tree_panel(cid, t))


func _talent_tree_panel(cid: String, tree: Dictionary) -> Control:
	var tcol := Color(tree["color"])
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _sb(PANEL2, tcol.darkened(0.35), 2, 10))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	var hh := HBoxContainer.new()
	v.add_child(hh)
	var nm := _label(String(tree["name"]), 17, tcol.lightened(0.25), font_label)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hh.add_child(nm)
	hh.add_child(_label("%d points" % main.talent_points_spent(tree["id"]), 14, TEXT))
	var d := _label(String(tree["desc"]), 12, MUTED, null, true)
	d.custom_minimum_size = Vector2(TAL_CW * TAL_COLS, 0)
	v.add_child(d)
	var canvas := Control.new()
	canvas.custom_minimum_size = Vector2(TAL_CW * TAL_COLS, TAL_CH * TAL_TIERS)
	v.add_child(canvas)
	var spent: int = main.talent_points_spent(tree["id"])
	var nodes: Array = []
	for n: Dictionary in Data.TALENTS[cid]:
		if n["tree"] == tree["id"]:
			nodes.append(n)
	# prerequisite arrows, drawn under the icons
	var lines := Control.new()
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(lines)
	var centers := {}
	for n: Dictionary in nodes:
		centers[n["id"]] = Vector2((int(n["col"]) + 0.5) * TAL_CW, int(n["tier"]) * TAL_CH + 27.0)
	lines.draw.connect(func() -> void:
		for n: Dictionary in nodes:
			if not n.has("req"):
				continue
			var a: Vector2 = centers[n["req"]]
			var b: Vector2 = centers[n["id"]]
			var on: bool = main.talent_rank(String(n["req"])) >= 1
			var col := tcol if on else Color(0.35, 0.33, 0.4)
			var dir := (b - a).normalized()
			var s := a + dir * 29.0
			var e := b - dir * 31.0
			lines.draw_line(s, e, col, 4.0, true)
			var side := Vector2(-dir.y, dir.x)
			lines.draw_colored_polygon(PackedVector2Array([e + dir * 8.0, e + side * 7.0, e - side * 7.0]), col))
	for n: Dictionary in nodes:
		canvas.add_child(_talent_node(n, tcol, centers[n["id"]]))
	return p


func _talent_node(n: Dictionary, tcol: Color, center: Vector2) -> Control:
	var rank: int = main.talent_rank(n["id"])
	var block: String = main.talent_block(n["id"])
	var is_ab: bool = n.has("ability")
	var can: bool = block == ""
	var maxed: bool = rank >= int(n["max"])
	var box := Control.new()
	box.size = Vector2(TAL_CW, TAL_CH)
	box.position = center - Vector2(TAL_CW * 0.5, 27.0)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.size = Vector2(50, 50)
	b.position = Vector2((TAL_CW - 50.0) * 0.5, 2)
	var fill := tcol.darkened(0.55)
	var border := Color(0.3, 0.28, 0.34)
	if rank > 0:
		fill = tcol.darkened(0.2)
		border = tcol.lightened(0.5) if maxed else tcol.lightened(0.2)
	elif can:
		fill = tcol.darkened(0.6)
		border = EMBER_HI
	var sbn := StyleBoxFlat.new()
	sbn.bg_color = fill
	sbn.border_color = border
	sbn.set_border_width_all(3)
	sbn.set_corner_radius_all(25 if not is_ab else 6)
	var sbh: StyleBoxFlat = sbn.duplicate()
	sbh.bg_color = fill.lightened(0.15)
	sbh.border_color = border.lightened(0.3)
	for st: String in ["normal", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, sbn)
	b.add_theme_stylebox_override("hover", sbh)
	b.text = _initials(String(n["name"]))
	if is_ab and Icons.ability(String(n["ability"])) != null:
		b.text = ""
		b.icon = Icons.ability(String(n["ability"]))
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_theme_constant_override("icon_max_width", 34)
	elif not is_ab and Icons.talent(String(n["id"])) != null:
		b.text = ""
		b.icon = Icons.talent(String(n["id"]))
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_theme_constant_override("icon_max_width", 30)
	b.add_theme_font_size_override("font_size", 22)
	var tc: Color = TEXT if (rank > 0 or can) else Color(0.5, 0.48, 0.55)
	for cn: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(cn, tc)
	var tip := "%s  (%s)\n%s\nRank %d / %d" % [n["name"], "Ability" if is_ab else "Passive", n["desc"], rank, n["max"]]
	if block != "" and block != "Maxed":
		tip += "\n\n" + block
	b.tooltip_text = tip
	var nid: String = n["id"]
	b.pressed.connect(func() -> void: main.learn_talent(nid))
	b.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
			main.unlearn_talent(nid))
	box.add_child(b)
	var rk := _label("%d/%d" % [rank, n["max"]], 11, EMBER_HI if can else (TEXT if rank > 0 else MUTED), font_label)
	rk.position = Vector2(TAL_CW * 0.5 + 14.0, 44)
	rk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rkp := PanelContainer.new()
	rkp.add_theme_stylebox_override("panel", _sb(Color(0.05, 0.04, 0.08, 0.95), border, 1, 2))
	rkp.position = Vector2(TAL_CW * 0.5 + 6.0, 38)
	rkp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rk.position = Vector2.ZERO
	rkp.add_child(rk)
	box.add_child(rkp)
	var nl := _label(String(n["name"]), 10, TEXT if (rank > 0 or can) else MUTED, null, true)
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nl.position = Vector2(2, 54)
	nl.size = Vector2(TAL_CW - 4.0, 20)
	nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(nl)
	return box


# ---------------------------------------------------------------- crafting stations
const STATIONS := ["cooking", "herblore", "crafting", "furnace", "anvil"]   # all crafted inside the chat box
var _craft_target := ""   # material used on a tool: the grid only shows recipes that take it
var _chat: PanelContainer
var _chat_log: VBoxContainer
var _chat_scroll: ScrollContainer
var _chat_log_box: Control
var _craft_box: VBoxContainer
var _chat_input: LineEdit
var _chat_title: Label
var _craft_open := false
var _craft_mode := false
var _dlg_on := false
var _dlg_box: HBoxContainer
var _dlg_por: SubViewportContainer
var _dlg_who: Label
var _dlg_text: Label
var _craft_scroll := 0
var _make_qty := 1                      # 1, 5, or 0 for all
var _qty_btns: Array = []
var _cp_vis := false
var _cp_root: Control
var _cp_fill: ProgressBar
var _cp_name: Label
var _cp_left: Label
var _cp_icon: TextureRect


# ================================================================ chat box (bottom left)
## A message log in the bottom-left corner. Crafting stations cover it with a grid of icons while you work.
func _build_chat() -> void:
	_chat = PanelContainer.new()
	_chat.add_theme_stylebox_override("panel", _sb(Color(0.08, 0.065, 0.11, 0.86), LINE, 2, 8))
	_chat.add_child(Brackets.new())
	_anchor(_chat, 0, 1, 14, -14, Control.GROW_DIRECTION_END, Control.GROW_DIRECTION_BEGIN)
	_chat.custom_minimum_size = Vector2(CHAT_W, 250)
	_chat.offset_right = 14.0 + CHAT_W
	_chat.offset_top = -14.0 - 250.0
	hud_root.add_child(_chat)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_chat.add_child(v)
	var head := HBoxContainer.new()
	_chat_title = _label("CHAT", 11, EMBER, font_label)
	_chat_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_chat_title)
	v.add_child(head)
	# the log
	_chat_log_box = VBoxContainer.new()
	_chat_log_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_chat_log_box)
	_chat_scroll = ScrollContainer.new()
	_chat_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chat_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_chat_scroll.custom_minimum_size = Vector2(CHAT_W - 24, 60)
	_chat_log_box.add_child(_chat_scroll)
	_chat_log = VBoxContainer.new()
	_chat_log.add_theme_constant_override("separation", 2)
	_chat_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_scroll.add_child(_chat_log)
	_chat_input = LineEdit.new()
	_chat_input.placeholder_text = "Chat arrives with multiplayer..."
	_chat_input.editable = false
	_chat_input.focus_mode = Control.FOCUS_NONE
	_chat_input.add_theme_font_size_override("font_size", 13)
	_chat_log_box.add_child(_chat_input)
	# the crafting view (icons only) covers the log
	_craft_box = VBoxContainer.new()
	_craft_box.add_theme_constant_override("separation", 6)
	_craft_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_craft_box.visible = false
	v.add_child(_craft_box)
	# NPC speech covers the log too, with the speaker's head beside the words
	_dlg_box = HBoxContainer.new()
	_dlg_box.add_theme_constant_override("separation", 10)
	_dlg_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dlg_box.visible = false
	v.add_child(_dlg_box)
	_dlg_por = portrait("", Vector2(104, 150), false, true)
	_dlg_por.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dlg_box.add_child(_dlg_por)
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 6)
	dv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dv.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dlg_box.add_child(dv)
	_dlg_who = _label("", 14, EMBER, font_label)
	dv.add_child(_dlg_who)
	_dlg_text = _label("", 16, TEXT, null, true)
	_dlg_text.custom_minimum_size = Vector2(240, 0)
	_dlg_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dv.add_child(_dlg_text)
	var dn := _label("CLICK TO CONTINUE", 10, MUTED, font_label)
	dn.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	dv.add_child(dn)
	_build_craft_progress(v)
	chat_say("Welcome to Thornvale.", MUTED)


const CHAT_W := 400.0
const CHAT_H := 250.0   # the box never changes size, whatever it is showing


func chat_say(text: String, col := TEXT, icon: Texture2D = null) -> void:
	if _chat_log == null:
		return
	var l := _label(text, 13, col, null, true)
	l.custom_minimum_size = Vector2(CHAT_W - 44, 0)
	if icon == null:
		_chat_add(l)
		return
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.add_child(_mini_icon(icon, 20))
	l.custom_minimum_size = Vector2(CHAT_W - 74, 0)
	h.add_child(l)
	_chat_add(h)


func _chat_add(n: Control) -> void:
	while _chat_log.get_child_count() >= 60:
		var o := _chat_log.get_child(0)
		_chat_log.remove_child(o)
		o.queue_free()
	_chat_log.add_child(n)
	_chat_scroll.scroll_vertical = 100000
	(func() -> void: _chat_scroll.scroll_vertical = 100000).call_deferred()


## A level-up card in the chat box: the skill's icon, a congratulation and anything it unlocked.
func chat_levelup(skill_id: String, lvl: int, extra := "") -> void:
	if _chat_log == null:
		return
	var col := Color(Data.SKILLS[skill_id]["color"]).lightened(0.3)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _sb(Color(0.2, 0.15, 0.08, 0.9), col.darkened(0.2), 2, 6))
	p.custom_minimum_size = Vector2(CHAT_W - 44, 0)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	p.add_child(h)
	h.add_child(_mini_icon(Icons.skill(skill_id), 36))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 1)
	h.add_child(v)
	v.add_child(_label("Congratulations!", 15, EMBER_HI, font_label))
	var m := _label("Your %s level is now %d." % [Data.SKILLS[skill_id]["name"], lvl], 13, TEXT, null, true)
	m.custom_minimum_size = Vector2(CHAT_W - 110, 0)
	v.add_child(m)
	if extra != "":
		var x := _label(extra, 12, col, null, true)
		x.custom_minimum_size = Vector2(CHAT_W - 110, 0)
		v.add_child(x)
	_chat_add(p)
	_flash_chat()


func _flash_chat() -> void:
	if _chat == null:
		return
	_chat.modulate = Color(1.35, 1.25, 1.0)
	create_tween().tween_property(_chat, "modulate", Color.WHITE, 0.7)


func _set_chat_mode(craft: bool) -> void:
	_craft_mode = craft
	_apply_chat_view()


func _apply_chat_view() -> void:
	if _chat == null:
		return
	var craft := _craft_mode and not _dlg_on
	_chat_log_box.visible = not craft and not _dlg_on
	_craft_box.visible = craft
	_dlg_box.visible = _dlg_on
	_chat_title.visible = not craft and not _dlg_on
	_chat.mouse_filter = Control.MOUSE_FILTER_IGNORE if _dlg_on else Control.MOUSE_FILTER_STOP
	_layout_chat()


func _layout_chat() -> void:
	var craft := _craft_box != null and _craft_box.visible
	var busy: bool = main != null and main.skills != null and main.skills.busy() and main.skills.action.get("kind", "") == "job"
	_cp_vis = (craft or busy) and not _dlg_on
	if _cp_root:
		_cp_root.visible = _cp_vis
	var ch := CHAT_H
	_chat.custom_minimum_size = Vector2(CHAT_W, ch)
	_chat.offset_left = 14.0
	_chat.offset_right = 14.0 + CHAT_W
	_chat.offset_bottom = -14.0
	_chat.offset_top = -14.0 - ch


## Icon for a recipe result (tool upgrades and bags have no material of their own).
func _recipe_icon(r: Dictionary) -> Texture2D:
	if r.has("icon_item"):
		return Items.icon(r["icon_item"])
	var out := String(r["out"])
	if out.begins_with("tool:"):
		return Icons.material({"mining": "pickaxe", "woodcutting": "axe", "fishing": "rod"}.get(out.get_slice(":", 1), "pickaxe"))
	if out == "potion":
		return Icons.material("hpot")
	return Icons.material(out)


## What a recipe asks for, with how many you hold: "2 Copper Bar (have 5)".
func _cost_text(r: Dictionary, with_have := true) -> String:
	var parts: Array[String] = []
	for k: String in r["cost"]:
		var have: int = int(main.state.get("gold", 0)) if k == "gold" else main.crafting.count(k)
		var nm: String = "gold" if k == "gold" else String(Data.MATERIALS[k]["name"])
		parts.append("%d %s%s" % [int(r["cost"][k]), nm, (" (have %d)" % have) if with_have else ""])
	return ", ".join(parts)


## Recipes worth showing (narrowed to the item you used a tool on): what you can make now, then what you lack
## materials for, then ones you already own. Locked ones are only counted.
func _recipe_groups(station: String) -> Dictionary:
	var sk = main.skills
	var skid: String = Data.STATIONS[station]["skill"]
	var ready: Array = []
	var short: Array = []
	var owned: Array = []
	var locked: Array = []
	for r: Dictionary in main.recipes_for(station):
		if _craft_target != "" and station in Data.COMBO_TOOLS and not (r["cost"] as Dictionary).has(_craft_target):
			continue
		if r.get("master", false) and _craft_target != "ember":
			continue   # masterwork gear: use the hammer on an Ember Shard
		var why: String = sk.can_make(station, r)
		if why == "Already made" or why == "You already have one":
			owned.append(r)
		elif sk.level(String(r.get("skill", skid))) < int(r["lvl"]):
			locked.append(r)
		elif why == "":
			ready.append(r)
		else:
			short.append(r)
	return {"ready": ready, "short": short, "owned": owned, "locked": locked}


func _qty_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	_qty_btns.clear()
	for spec: Array in [[1, "1"], [5, "5"], [0, "All"]]:
		var b := Button.new()
		b.text = spec[1]
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(34, 24)
		var q: int = spec[0]
		b.pressed.connect(func() -> void:
			_make_qty = q
			Sfx.play("ui_click", Vector3.INF, -8.0)
			_paint_qty())
		row.add_child(b)
		_qty_btns.append([b, q])
	_paint_qty()
	return row


func _paint_qty() -> void:
	for e: Array in _qty_btns:
		var b: Button = e[0]
		if not is_instance_valid(b):
			continue
		var on: bool = int(e[1]) == _make_qty
		b.add_theme_stylebox_override("normal", _sb(PANEL2 if on else PANEL, EMBER_HI if on else LINE, 2, 4))


func _make_n(station: String, r: Dictionary) -> int:
	var mx: int = main.skills.max_make(station, r)
	if r.get("once", false):
		return 1
	return maxi(1, mx if _make_qty == 0 else mini(_make_qty, mx))


## Crafting inside the chat box: only what you can make from your bag, as icons (hover for details),
## with the amount you could make on the icon. Click to make; the 1 / 5 / All buttons pick how many.
func _fill_craft(station: String) -> void:
	_win_kind = station
	if _craft_box.get_child_count() > 1:
		var oldmid := _craft_box.get_child(1) as HBoxContainer
		if oldmid and oldmid.get_child_count() > 0 and oldmid.get_child(0) is ScrollContainer:
			_craft_scroll = (oldmid.get_child(0) as ScrollContainer).scroll_vertical
	for c in _craft_box.get_children():
		_craft_box.remove_child(c)
		c.queue_free()
	var sk = main.skills
	var skid: String = Data.STATIONS[station]["skill"]
	var col := Color(Data.SKILLS[skid]["color"])
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.add_child(_mini_icon(Icons.skill(skid), 24))
	var tl := _label("%s" % Data.STATIONS[station]["title"], 14, EMBER_HI, font_label)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tl)
	if _craft_target != "" and Data.MATERIALS.has(_craft_target):
		head.add_child(_mini_icon(Icons.material(_craft_target), 22))
	head.add_child(_label("LV %d" % sk.level(skid), 14, col.lightened(0.3)))
	var x := Button.new()
	x.text = "X"
	x.focus_mode = Control.FOCUS_NONE
	x.custom_minimum_size = Vector2(26, 26)
	x.pressed.connect(func() -> void: close_side())
	head.add_child(x)
	_craft_box.add_child(head)
	var mid := HBoxContainer.new()
	mid.add_theme_constant_override("separation", 6)
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_craft_box.add_child(mid)
	var sc := ScrollContainer.new()
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(0, 100)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 4)
	sc.add_child(body)
	mid.add_child(sc)
	var g := _recipe_groups(station)
	var grid := GridContainer.new()
	var shown_n := (g["ready"] as Array).size() + (g["short"] as Array).size() + (g["owned"] as Array).size()
	var cell := 60 if shown_n <= 10 else 42     # few recipes: big icons that fill the box
	grid.columns = 5 if shown_n <= 10 else 7
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)
	body.add_child(grid)
	var n_ready := (g["ready"] as Array).size()
	for r: Dictionary in (g["ready"] as Array) + (g["short"] as Array) + (g["owned"] as Array):
		grid.add_child(_recipe_button(station, r, cell))
	if grid.get_child_count() == 0:
		var hint := _label("Nothing to make from that yet.", 12, MUTED, null, true)
		hint.custom_minimum_size = Vector2(CHAT_W - 100, 0)
		body.add_child(hint)
	elif n_ready == 0:
		body.add_child(_label("Gather what the dim ones need.", 11, MUTED, font_label))
	var nl := (g["locked"] as Array).size()
	if nl > 0:
		body.add_child(_label("%d more at higher levels" % nl, 11, MUTED, font_label))
	# 1 / 5 / All down the right-hand side
	var qc := VBoxContainer.new()
	qc.add_theme_constant_override("separation", 5)
	_qty_btns.clear()
	for spec: Array in [[1, "1"], [5, "5"], [0, "All"]]:
		var qb := Button.new()
		qb.text = spec[1]
		qb.focus_mode = Control.FOCUS_NONE
		qb.size_flags_vertical = Control.SIZE_EXPAND_FILL
		qb.custom_minimum_size = Vector2(44, 36)
		var q: int = spec[0]
		qb.pressed.connect(func() -> void:
			_make_qty = q
			Sfx.play("ui_click", Vector3.INF, -8.0)
			_paint_qty())
		qc.add_child(qb)
		_qty_btns.append([qb, q])
	_paint_qty()
	mid.add_child(qc)
	(func() -> void: sc.scroll_vertical = _craft_scroll).call_deferred()
	_layout_chat()


## One icon button for a recipe. `size` is the icon cell; the badge shows how many you could make.
func _recipe_button(station: String, r: Dictionary, size: int) -> Button:
	var sk = main.skills
	var why: String = sk.can_make(station, r)
	var skid: String = String(r.get("skill", Data.STATIONS[station]["skill"]))
	var locked: bool = sk.level(skid) < int(r["lvl"])
	var b := Button.new()
	b.custom_minimum_size = Vector2(size, size)
	b.focus_mode = Control.FOCUS_NONE
	var owned := why == "Already made" or why == "You already have one"
	var edge := Color("5aa05a") if why == "" else (Color("8a3a3a") if locked else (Color("4a7a9a") if owned else Color("a0743a")))
	b.add_theme_stylebox_override("normal", _sb(PANEL2, edge, 2, 5))
	b.add_theme_stylebox_override("hover", _sb(PANEL2.lightened(0.08), edge.lightened(0.35), 2, 5))
	b.add_theme_stylebox_override("pressed", _sb(PANEL2, Color.WHITE, 2, 5))
	var ic := _mini_icon(_recipe_icon(r), size - 12)
	_full(ic)
	ic.offset_left = 6
	ic.offset_right = -6
	ic.offset_top = 6
	ic.offset_bottom = -6
	ic.modulate = Color(1, 1, 1, 0.35) if locked else (Color(1, 1, 1, 0.8) if owned else (Color(1, 1, 1, 0.5) if why != "" else Color.WHITE))
	b.add_child(ic)
	var n: int = sk.max_make(station, r)
	if why == "" and n > 1 and not r.get("once", false):
		var bd := _outlined(_label(str(n), 12, EMBER_HI, font_label), 3)
		bd.position = Vector2(size - 18, size - 18)
		bd.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(bd)
	if locked:
		var lv := _outlined(_label(str(r["lvl"]), 11, Color("e05a4a"), font_label), 3)
		lv.position = Vector2(5, 2)
		lv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(lv)
	var tip := "%s   (level %d)\n%s" % [r["name"], r["lvl"], String(r.get("desc", ""))]
	if owned:
		tip += "\nYou already have this."
	if station == "cooking" and not locked:
		tip += " · %d%% burn" % roundi(sk.burn_chance(r) * 100.0)
	tip += "\nNeeds: %s" % _cost_text(r)
	if why != "":
		tip += "\n" + why
	b.tooltip_text = tip
	var rr := r
	b.pressed.connect(func() -> void:
		sk.make(station, rr, _make_n(station, rr)))
	return b


## The anvil's tools are many and costly, so it keeps a pop-up: icon, name and cost under each, like a smithing menu.
func _fill_make_popup(station: String) -> void:
	var sk = main.skills
	var skid: String = Data.STATIONS[station]["skill"]
	var col := Color(Data.SKILLS[skid]["color"])
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	top.add_child(_mini_icon(Icons.skill(skid), 22))
	top.add_child(_label("%s level %d" % [Data.SKILLS[skid]["name"], sk.level(skid)], 14, col.lightened(0.3)))
	var xb := _skill_bar(skid, 8)
	xb.custom_minimum_size = Vector2(200, 8)
	xb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(xb)
	_win_body.add_child(top)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_win_body.add_child(row)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	row.add_child(grid)
	var g := _recipe_groups(station)
	for r: Dictionary in (g["ready"] as Array) + (g["short"] as Array) + (g["locked"] as Array):
		var why: String = sk.can_make(station, r)
		var locked: bool = sk.level(skid) < int(r["lvl"])
		var cell := Button.new()
		cell.focus_mode = Control.FOCUS_NONE
		cell.custom_minimum_size = Vector2(118, 112)
		var edge := LINE if why == "" else (Color("8a3a3a") if locked else Color("6a4a30"))
		cell.add_theme_stylebox_override("normal", _sb(PANEL2, edge, 1, 5))
		cell.add_theme_stylebox_override("hover", _sb(PANEL2.lightened(0.1), EMBER_HI, 2, 5))
		cell.add_theme_stylebox_override("pressed", _sb(PANEL2, Color.WHITE, 2, 5))
		var v := VBoxContainer.new()
		_full(v)
		v.offset_left = 4
		v.offset_right = -4
		v.offset_top = 6
		v.offset_bottom = -4
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_theme_constant_override("separation", 2)
		var ic := _mini_icon(_recipe_icon(r), 44)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		if why != "":
			ic.modulate = Color(1, 1, 1, 0.4 if locked else 0.6)
		v.add_child(ic)
		var nm := _label(r["name"], 12, MUTED if why != "" else TEXT, null, true)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.custom_minimum_size = Vector2(104, 0)
		v.add_child(nm)
		for k: String in r["cost"]:
			var need := int(r["cost"][k])
			var enough: bool = main.crafting.count(k) >= need
			var cl := _label("%d %s" % [need, Data.MATERIALS[k]["name"]], 11, Color("6fd05a") if enough else Color("e05a4a"))
			cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			v.add_child(cl)
		if locked:
			var ll := _label("Level %d" % int(r["lvl"]), 11, Color("e05a4a"), font_label)
			ll.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			v.add_child(ll)
		cell.add_child(v)
		cell.tooltip_text = "%s\n%s" % [r["name"], String(r.get("desc", ""))]
		var rr := r
		cell.pressed.connect(func() -> void:
			sk.make(station, rr, _make_n(station, rr))
			if sk.busy():
				close_side())
		grid.add_child(cell)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 6)
	_qty_btns.clear()
	for spec: Array in [[1, "1"], [5, "5"], [0, "All"]]:
		var b := Button.new()
		b.text = spec[1]
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(52, 40)
		var q: int = spec[0]
		b.pressed.connect(func() -> void:
			_make_qty = q
			Sfx.play("ui_click", Vector3.INF, -8.0)
			_paint_qty())
		side.add_child(b)
		_qty_btns.append([b, q])
	_paint_qty()
	row.add_child(side)


## The "now making" strip: icon, name, progress and a stop button. Lives at the bottom of the chat box.
func _build_craft_progress(parent: Control) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _sb(PANEL2, LINE, 1, 6))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	p.add_child(row)
	_cp_icon = _mini_icon(null, 34)
	row.add_child(_cp_icon)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 4)
	row.add_child(col)
	var head := HBoxContainer.new()
	_cp_name = _label("Pick something to make", 14, MUTED)
	_cp_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_cp_name)
	_cp_left = _label("", 12, MUTED)
	head.add_child(_cp_left)
	col.add_child(head)
	_cp_fill = _bar(EMBER, 10, false)
	_cp_fill.max_value = 1.0
	_cp_fill.value = 0.0
	col.add_child(_cp_fill)
	var cancel := Button.new()
	cancel.text = "X"
	cancel.focus_mode = Control.FOCUS_NONE
	cancel.custom_minimum_size = Vector2(26, 26)
	cancel.tooltip_text = "Stop"
	cancel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cancel.pressed.connect(func() -> void: main.skills.stop("Stopped."))
	row.add_child(cancel)
	p.visible = false
	_cp_root = p
	parent.add_child(p)


func _update_craft_progress() -> void:
	var sk = main.skills
	var busy: bool = sk.busy() and sk.action.get("kind", "") == "job"
	var want: bool = busy or (_craft_box != null and _craft_box.visible)
	if want != _cp_vis:
		_layout_chat()
	if not busy:
		_cp_name.text = "Pick something to make"
		_cp_name.add_theme_color_override("font_color", MUTED)
		_cp_left.text = ""
		_cp_fill.value = 0.0
		_cp_icon.texture = null
		return
	var a: Dictionary = sk.action
	_cp_name.text = String(a.get("label", "Working..."))
	_cp_name.add_theme_color_override("font_color", TEXT)
	var left := int(a.get("left", 1))
	_cp_left.text = "%d left" % left if left > 1 else ""
	_cp_fill.value = sk.progress()
	var fc := Color(Data.SKILLS[a["skill"]]["color"]).lightened(0.15)
	var fs := StyleBoxFlat.new()
	fs.bg_color = fc
	fs.border_color = fc.lightened(0.25)
	fs.border_width_top = 1
	_cp_fill.add_theme_stylebox_override("fill", fs)
	var ic := String(a.get("icon", ""))
	_cp_icon.texture = Icons.material(ic) if ic != "" else null


func _fill_station(station: String) -> void:
	var sk = main.skills
	var cr = main.crafting
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	var skid: String = Data.STATIONS[station]["skill"]
	var nm := _label("%s level %d" % [Data.SKILLS[skid]["name"], sk.level(skid)], 14, Color(Data.SKILLS[skid]["color"]).lightened(0.3))
	top.add_child(nm)
	var bar := _skill_bar(skid, 8)
	bar.custom_minimum_size = Vector2(220, 8)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(bar)
	_win_body.add_child(top)
	if station == "cooking":
		var bl := _label("Raw fish can burn. Higher Cooking burns less.", 13, MUTED, null, true)
		bl.custom_minimum_size = Vector2(290, 0)
		_win_body.add_child(bl)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	_win_body.add_child(grid)
	for r: Dictionary in Data.RECIPES[station]:
		var why: String = sk.can_make(station, r)
		var locked: bool = sk.level(skid) < int(r["lvl"])
		var pnl := PanelContainer.new()
		pnl.custom_minimum_size = Vector2(272, 0)
		pnl.add_theme_stylebox_override("panel", _sb(PANEL2, LINE, 1, 6))
		var h := VBoxContainer.new()
		h.add_theme_constant_override("separation", 2)
		pnl.add_child(h)
		var title := HBoxContainer.new()
		title.add_theme_constant_override("separation", 8)
		var rico := _mini_icon(Icons.material(String(r["out"])), 30)
		if locked:
			rico.modulate = Color(1, 1, 1, 0.45)
		title.add_child(rico)
		var tl := _label(r["name"], 15, MUTED if locked else TEXT)
		tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.add_child(tl)
		title.add_child(_label("LV %d" % r["lvl"], 10, Color("8ad07a") if not locked else Color("e05a4a"), font_label))
		h.add_child(title)
		var parts: Array[String] = []
		for k: String in r["cost"]:
			parts.append("%d %s" % [int(r["cost"][k]), Data.MATERIALS[k]["name"]])
		var info := String(r.get("desc", ""))
		if station == "cooking" and not locked:
			info += " · %d%% burn" % roundi(sk.burn_chance(r) * 100.0)
		var il := _label(info, 12, MUTED, null, true)
		il.custom_minimum_size = Vector2(250, 0)
		h.add_child(il)
		var nl := _label(", ".join(parts), 12, TEXT if why != "Missing materials" else Color("e0a080"), null, true)
		nl.custom_minimum_size = Vector2(250, 0)
		h.add_child(nl)
		var btns := HBoxContainer.new()
		btns.add_theme_constant_override("separation", 6)
		var n: int = sk.max_make(station, r)
		var one := Button.new()
		one.text = "Make" if why == "" else why
		one.disabled = why != ""
		one.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var rr := r
		one.pressed.connect(func() -> void: sk.make(station, rr, 1))
		btns.add_child(one)
		if not r.get("once", false) and n > 1:
			var all := Button.new()
			all.text = "All (%d)" % n
			all.pressed.connect(func() -> void: sk.make(station, rr, n))
			btns.add_child(all)
		title.add_child(btns)
		grid.add_child(pnl)


## Turn a full-screen pop-up into a panel docked on the right; clicks elsewhere still reach the game.
func _dock(r: Control) -> void:
	(r as ColorRect).color = Color(0, 0, 0, 0)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cc: Control = r.get_child(0)
	var pn := cc.get_child(0) as PanelContainer
	cc.remove_child(pn)
	r.remove_child(cc)
	cc.queue_free()
	r.add_child(pn)
	pn.add_theme_stylebox_override("panel", _sb(Color(0.09, 0.075, 0.12, 0.94), LINE, 2, 8))
	pn.add_child(Brackets.new())
	pn.anchor_left = 1.0
	pn.anchor_right = 1.0
	pn.anchor_top = 1.0
	pn.anchor_bottom = 1.0
	pn.offset_right = -14.0
	pn.offset_left = -14.0 - 330.0
	pn.offset_bottom = -SIDE_BOTTOM
	pn.offset_top = -SIDE_BOTTOM - 10.0
	pn.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	pn.grow_vertical = Control.GROW_DIRECTION_BEGIN
	pn.custom_minimum_size = Vector2(330, 0)


func _phase(t: float) -> Array:
	var nm := "NIGHT"
	if t >= 0.2 and t < 0.3:
		nm = "DAWN"
	elif t >= 0.3 and t < 0.45:
		nm = "MORNING"
	elif t >= 0.45 and t < 0.58:
		nm = "MIDDAY"
	elif t >= 0.58 and t < 0.7:
		nm = "AFTERNOON"
	elif t >= 0.7 and t < 0.82:
		nm = "DUSK"
	return [nm, t >= 0.22 and t < 0.78]


# ================================================================ draw distance
func set_view_distance(chunks: int, save := true) -> void:
	var s: ChunkStreamer = main.world.streamer if main and main.world else null
	if s == null:
		return
	s.set_view(chunks)
	if save:
		_save_game_setting("view_chunks", s.view_chunks)


# ================================================================ UI size
func set_ui_scale(v: float, save := true) -> void:
	ui_scale = clampf(snappedf(v, 0.05), 0.7, 1.5)
	var w := get_window()
	if w != null:
		w.content_scale_factor = ui_scale
	if save:
		_save_game_setting("ui_scale", ui_scale)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE and (use_src != "" or _ctx_panel != null):
		_close_ctx()
		cancel_use()
		get_viewport().set_input_as_handled()
		return
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo or not (k.ctrl_pressed or k.meta_pressed):
		return
	if k.keycode in [KEY_EQUAL, KEY_PLUS, KEY_KP_ADD]:
		set_ui_scale(ui_scale + 0.1)
	elif k.keycode in [KEY_MINUS, KEY_KP_SUBTRACT]:
		set_ui_scale(ui_scale - 0.1)
	else:
		return
	if _win_kind == "settings":
		show_window("settings")
	toast("UI size %d%%" % roundi(ui_scale * 100.0))
	get_viewport().set_input_as_handled()


## Make the docked panel as tall as its contents, or as tall as the screen allows (then it scrolls).
func _fit_side() -> void:
	await get_tree().process_frame
	if _side == null or not _side.visible or _side_scroll == null:
		return
	var vh := get_viewport().get_visible_rect().size.y
	var max_h := vh - SIDE_BOTTOM - 170.0 - 50.0   # keep clear of the minimap
	var ch := _side_content.get_combined_minimum_size().y
	_side_scroll.custom_minimum_size = Vector2(0, minf(ch, max_h))
	_side_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if ch > max_h else ScrollContainer.SCROLL_MODE_DISABLED
