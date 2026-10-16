@tool
extends EditorPlugin
## Adds "Embers: Export world to server" and "Embers: Check world" to Project > Tools.

const EXPORT := "Embers: Export world to server"
const PAINT := "Embers: Paint ground textures from regions"
const TEXTURES := "Embers: Set up ground textures (like the original game)"
const LOWPOLY := "Embers: Make terrain low poly (like the original game)"
const SMOOTH := "Embers: Restore smooth terrain"
const TINT := "Embers: Clear colour tint (stray green on the terrain)"
const FACET := "Embers: Build faceted ground (flat-colour preview, like the game)"
const FACET_OFF := "Embers: Remove faceted ground (show Terrain3D)"
const STRAYS := "Embers: Remove stray overlays (leftover paint circles)"
const ORIG_IN := "Embers: Import the original world's terrain into Terrain3D"
const ORIG_OUT := "Embers: Export the original terrain for Blender (mesh + heightmap)"
const WHATS := "Embers: What is colouring my ground? (find the overlay)"
const CHECK := "Embers: Check world (writes nothing)"
var _dlg: AcceptDialog
# --- biome painting (see embers_paint.gd)
var _paint_node: EmbersBiomePaint
var _bar: VBoxContainer
var _value_lbl: Label
var _area_sel := 0
var _stroke_area := 0   # the area (or -1 = erase) chosen when the stroke began
var _before_snap := {}
var _radius: VSlider
var _radius_label: Label
var _erase: Button
var _cursor: MeshInstance3D
var _stroking := false
var _road: EmbersRoad
var _road_bar: VBoxContainer
var _road_width: VSlider
var _road_width_label: Label
var _road_smooth: Button
var _road_add: Button
var _road_drag := -1   # index of the path point being dragged, -1 = none
var _road_drag_before := PackedVector3Array()
var _status: Label
var _paint_tex: Button      # also paint Terrain3D's textures as you brush (a rough preview for sculpting)
var _tex_ctx: Variant = null
var _last_dab := Vector3(1e9, 0, 1e9)
var _last_sig := {}           # region -> fingerprint of its heights when Terrain3D's colours were last brought up to date
var _was_on_terrain := false
var _live_sig := {}      # block key -> hash of its heights, while Terrain3D is selected (live recolouring)
var _live_t := 0.0
var _live_queue: Array = []   # squares [x0, z0, x1, z1] waiting to be recoloured
var _recolour_pending := false   # a tool changed the terrain: recolour it next time you are not on Terrain3D
var _terrain_dirty := false   # Terrain3D was selected (so maybe sculpted) since the flat ground was last built
var _last_pos := Vector3.ZERO

## Menu entries that were taken out (the code is still here; add the line back to restore one): EXPORT (Send does it), PAINT (the refresh
## button does it), TINT, STRAYS.
func _enter_tree() -> void:
	set_process(true)
	add_tool_menu_item(CHECK, func() -> void: _go(false))
	add_tool_menu_item(TEXTURES, _textures)
	add_tool_menu_item(LOWPOLY, func() -> void: _lowpoly(true))
	add_tool_menu_item(SMOOTH, func() -> void: _lowpoly(false))
	add_tool_menu_item(FACET, func() -> void: _facet(true))
	add_tool_menu_item(FACET_OFF, func() -> void: _facet(false))
	add_tool_menu_item(WHATS, _whats)
	add_tool_menu_item(ORIG_IN, func() -> void: _original(true))
	add_tool_menu_item(ORIG_OUT, func() -> void: _original(false))
	_build_bar()
	_build_road_bar()
	EditorInterface.get_selection().selection_changed.connect(_on_selection)
	_dlg = AcceptDialog.new()
	_dlg.title = "Embers World"
	_dlg.min_size = Vector2i(720, 420)
	EditorInterface.get_base_control().add_child(_dlg)


func _exit_tree() -> void:
	var sel := EditorInterface.get_selection()
	if sel != null and sel.selection_changed.is_connected(_on_selection):
		sel.selection_changed.disconnect(_on_selection)
	remove_tool_menu_item(CHECK)
	remove_tool_menu_item(TEXTURES)
	remove_tool_menu_item(LOWPOLY)
	remove_tool_menu_item(SMOOTH)
	remove_tool_menu_item(FACET)
	remove_tool_menu_item(FACET_OFF)
	remove_tool_menu_item(WHATS)
	remove_tool_menu_item(ORIG_IN)
	remove_tool_menu_item(ORIG_OUT)
	if _dlg:
		_dlg.queue_free()
	if _bar:
		remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_SIDE_LEFT, _bar)
		_bar.queue_free()
	if _road_bar:
		remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_SIDE_LEFT, _road_bar)
		_road_bar.queue_free()
	_hide_cursor()


func _go(write: bool) -> void:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		_show("Open your world scene first.")
		return
	var out := "res://embers_export"
	var w := root.find_children("*", "EmbersWorld", true, false)
	if root is EmbersWorld:
		w.append(root)
	if not w.is_empty() and (w[0] as EmbersWorld).export_dir != "":
		out = (w[0] as EmbersWorld).export_dir
	_show("Working... (a big world takes a minute; the editor may pause)")
	await get_tree().process_frame
	await get_tree().process_frame
	var r := EmbersExporter.run(root, out, write)
	var t := ""
	if r["ok"]:
		t += "[OK] " + ("Exported." if write else "Looks good.") + "\n"
	else:
		t += "[PROBLEMS] Nothing was written.\n"
	for e: String in r["errors"]:
		t += "\nERROR: " + e
	for wn: String in r["warnings"]:
		t += "\nWarning: " + wn
	t += "\n\n" + JSON.stringify(r["stats"])
	if write and r["ok"]:
		t += "\n\nStart the server with:\n  embers-server --world \"%s\"" % r["stats"].get("written_to", out)
	print(t)
	_show(t)


func _paint() -> void:
	_last_sig = {}
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		_show("Open your world scene first.")
		return
	_show("Painting... (a big world takes a little while)")
	await get_tree().process_frame
	await get_tree().process_frame
	var r := EmbersPainter.run(root)
	_last_sig = _height_sig(root)   # Terrain3D's colours are now up to date with its heights
	_show(("[OK] " if r["ok"] else "[NOT DONE] ") + str(r["text"]))


func _textures() -> void:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		_show("Open your world scene first.")
		return
	var terrain: Node = EmbersPainter._find_terrain(root)
	if terrain == null:
		_show("No Terrain3D node in this scene. Add one first (Add Node > Terrain3D).")
		return
	_show("Making the textures...")
	await get_tree().process_frame
	var worlds := root.find_children("*", "EmbersWorld", true, false)
	var light := 0.0 if worlds.is_empty() else (worlds[0] as EmbersWorld).rock_lightness
	var bumpy := false if worlds.is_empty() else (worlds[0] as EmbersWorld).bumpy_ground
	_show(EmbersTextures.install(terrain, light, bumpy))


func _lowpoly(make: bool) -> void:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		_show("Open your world scene first.")
		return
	var terrain: Node = EmbersPainter._find_terrain(root)
	if terrain == null:
		_show("No Terrain3D node in this scene.")
		return
	_show("Working... a big terrain takes a while and the editor pauses.")
	await get_tree().process_frame
	await get_tree().process_frame
	var worlds := root.find_children("*", "EmbersWorld", true, false)
	var cell := 2.0 if worlds.is_empty() else (worlds[0] as EmbersWorld).facet_size_m
	var flip := false if worlds.is_empty() else (worlds[0] as EmbersWorld).flip_facet_diagonal
	var msg: String
	if make:
		msg = await EmbersLowPoly.apply(terrain, cell, flip, _show)
	else:
		msg = await EmbersLowPoly.restore(terrain, _show)
	_show(msg)
	_terrain_changed()


func _original(into_terrain: bool) -> void:
	if not into_terrain:
		_show("Writing the original terrain for Blender... (a minute; the editor may pause)")
		await get_tree().process_frame
		await get_tree().process_frame
		_show(EmbersOriginalWorld.export_blender(2))
		return
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		_show("Open your world scene first.")
		return
	var terrain: Node = null
	for t3: Node in root.find_children("*", "Terrain3D", true, false):
		terrain = t3
		break
	if terrain == null:
		_show("There is no Terrain3D node in this scene. Add one (Add Node > Terrain3D) and try again.")
		return
	_show("Putting the original terrain into Terrain3D... (a minute; the editor pauses)")
	await get_tree().process_frame
	await get_tree().process_frame
	_show(EmbersOriginalWorld.import_terrain3d(terrain))
	_terrain_changed()


## A report of everything in the scene that can put colour on the ground, so a leftover overlay can be found and named.
func _whats() -> void:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		_show("Open your world scene first.")
		return
	var t := "What can colour your ground in this scene:\n"
	var papers := root.find_children("*", "EmbersBiomePaint", true, false)
	t += "\n- Paint nodes (EmbersBiomePaint): %d\n" % papers.size()
	for pn: Node in papers:
		var pm := pn as EmbersBiomePaint
		var counts := []
		for layer: String in ["biome", "ground", "zone"]:
			var painted := 0
			for v: int in (pm.cells[layer] as PackedByteArray):
				if v != 0:
					painted += 1
			counts.append("%s %d" % [layer, painted])
		var decals := 0
		for c: Node in pm.get_children():
			if c is Decal:
				decals += 1
		t += "    %s: painted cells (%s), Show Overlay %s, %d decal(s)\n" % [pm.name, ", ".join(counts), "on" if pm.show_overlay else "off", decals]
	var regions := root.find_children("*", "EmbersRegion", true, false)
	t += "\n- Region boxes (EmbersRegion): %d (each draws a coloured sheet in the editor)\n" % regions.size()
	var ff := root.find_child(EmbersFacetGround.NODE_NAME, true, false)
	t += "\n- Flat-colour ground preview: %s\n" % ("present, %s" % ("showing" if (ff as Node3D).visible else "hidden") if ff != null else "none")
	for t3: Node in root.find_children("*", "Terrain3D", true, false):
		t += "\n- Terrain3D '%s': %s\n" % [t3.name, "showing" if (t3 as Node3D).visible else "hidden"]
		var mat: Object = t3.get("material")
		if mat != null:
			var on: Array[String] = []
			for pi: Dictionary in mat.get_property_list():
				var nm := str(pi["name"])
				if nm.begins_with("show_") and bool(mat.get(nm)):
					on.append(nm)
			t += "    debug views switched on: %s\n" % (", ".join(on) if not on.is_empty() else "none")
		var data: Object = t3.get("data")
		if data != null and data.has_method("get_color") and data.has_method("get_region_locations"):
			var tinted := 0
			var seen := 0
			var rs := int(t3.get("region_size"))
			var sp := float(t3.get("vertex_spacing"))
			for loc_v: Variant in data.call("get_region_locations"):
				var loc := Vector2i(loc_v)
				for k in 400:
					var c: Color = data.call("get_color", Vector3((loc.x * rs + (k * 37) % rs) * sp, 0.0, (loc.y * rs + (k * 91) % rs) * sp))
					seen += 1
					if c.r < 0.98 or c.g < 0.98 or c.b < 0.98:
						tinted += 1
			t += "    colour tint (Terrain3D's colour layer): %d of %d sampled points are tinted\n" % [tinted, seen]
	t += "\nPaint node cells and decals are cleared with Clear all. A tint is cleared by selecting the Terrain3D node and using its Colour tool with white, or tell me the numbers above."
	_show(t)


func _strays() -> void:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		_show("Open your world scene first.")
		return
	var gone := 0
	var others: Array[String] = []
	for pn: Node in root.find_children("*", "EmbersBiomePaint", true, false):
		gone += (pn as EmbersBiomePaint).remove_strays()
		(pn as EmbersBiomePaint)._redraw()
	for d: Node in root.find_children("*", "Decal", true, false):
		if not (d.get_parent() is EmbersBiomePaint):
			others.append(str(root.get_path_to(d)))
	var t := "Removed %d leftover overlay/brush node(s) from the paint nodes. The coloured overlay was redrawn from the painted map, so what you see now is what is really painted." % gone
	if not others.is_empty():
		t += "\n\nOther Decal nodes in your scene (not made by this tool, delete them in the Scene dock if they are the circle): " + ", ".join(others)
	_show(t)


func _facet(make: bool) -> void:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		_show("Open your world scene first.")
		return
	if not make:
		_show(EmbersFacetGround.remove(root))
		return
	_show("Building the faceted ground... (a big world takes a minute; the editor may pause)")
	await get_tree().process_frame
	await get_tree().process_frame
	_show(EmbersFacetGround.build(root))
	_terrain_dirty = false


func _clear_tint() -> void:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		_show("Open your world scene first.")
		return
	var terrain: Node = EmbersPainter._find_terrain(root)
	if terrain == null:
		_show("No Terrain3D node in this scene.")
		return
	_show("Working... a big terrain takes a while and the editor pauses.")
	await get_tree().process_frame
	await get_tree().process_frame
	_show(EmbersPainter.clear_tint(terrain))


func _show(t: String) -> void:
	_dlg.dialog_text = t
	_dlg.popup_centered()


# ================================================================ painting biomes with the mouse
## A small icon button (or toggle). The icon comes from the editor's own icon set; the first name that exists is used.
func _icon_btn(icons: Array, tip: String, toggle := false, on := false) -> Button:
	var b := Button.new()
	b.toggle_mode = toggle
	b.button_pressed = on
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(34, 34)
	b.expand_icon = false
	var th: Theme = EditorInterface.get_editor_theme()
	var found := false
	if th != null:
		for n: String in icons:
			if th.has_icon(n, "EditorIcons"):
				b.icon = th.get_icon(n, "EditorIcons")
				found = true
				break
	if not found:
		b.text = str(icons[0]).substr(0, 2)
	return b


func _small_label(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color(0.96, 0.96, 0.96))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 3)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	l.custom_minimum_size = Vector2(52, 0)
	return l


func _swatch(c: Color) -> ImageTexture:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(c)
	return ImageTexture.create_from_image(img)


func _initials(name: String) -> String:
	var t := ""
	for w: String in name.split(" "):
		if w.begins_with("("):
			continue
		t += w.substr(0, 1)
	return t.substr(0, 2)


func _build_bar() -> void:
	if _bar != null and is_instance_valid(_bar):
		remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_SIDE_LEFT, _bar)
		_bar.queue_free()
	_bar = VBoxContainer.new()
	_bar.visible = false
	_bar.add_theme_constant_override("separation", 3)
	_bar.add_child(_small_label("BIOMES"))
	# one bright coloured button per area: its colour is the colour it paints on the terrain
	var group := ButtonGroup.new()
	for i in EmbersBiomePaint.AREAS.size():
		var col: Color = EmbersBiomePaint.AREA_COLORS[i]
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = i == 0
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(72, 30)
		b.text = str(EmbersBiomePaint.AREAS[i][0])
		b.add_theme_font_size_override("font_size", 11)
		b.tooltip_text = str(EmbersBiomePaint.AREAS[i][0])
		b.add_theme_color_override("font_color", Color(0.05, 0.05, 0.05))
		b.add_theme_color_override("font_pressed_color", Color(0.05, 0.05, 0.05))
		b.add_theme_color_override("font_hover_color", Color(0.05, 0.05, 0.05))
		for st: String in ["normal", "hover", "pressed"]:
			var sb := StyleBoxFlat.new()
			sb.bg_color = col
			sb.set_corner_radius_all(4)
			if st == "pressed":
				sb.set_border_width_all(3)
				sb.border_color = Color.WHITE
			else:
				sb.bg_color = col.darkened(0.15)
			b.add_theme_stylebox_override(st, sb)
		b.pressed.connect(_on_area.bind(i))
		_bar.add_child(b)
	_bar.add_child(_small_label("PATCHES"))
	for j in EmbersBiomePaint.PATCHES.size():
		var pcol: Color = EmbersBiomePaint.GROUND_COLORS[int(EmbersBiomePaint.PATCHES[j][1]) - 1]
		var pb := Button.new()
		pb.toggle_mode = true
		pb.button_group = group
		pb.focus_mode = Control.FOCUS_NONE
		pb.custom_minimum_size = Vector2(72, 24)
		pb.text = str(EmbersBiomePaint.PATCHES[j][0])
		pb.add_theme_font_size_override("font_size", 11)
		pb.tooltip_text = "%s patch: paints just the ground (the biome underneath does not change)" % EmbersBiomePaint.PATCHES[j][0]
		for pc: String in ["font_color", "font_pressed_color", "font_hover_color"]:
			pb.add_theme_color_override(pc, Color(0.05, 0.05, 0.05) if pcol.get_luminance() > 0.45 else Color.WHITE)
		for pst: String in ["normal", "hover", "pressed"]:
			var psb := StyleBoxFlat.new()
			psb.bg_color = pcol if pst == "pressed" else pcol.darkened(0.15)
			psb.set_corner_radius_all(4)
			if pst == "pressed":
				psb.set_border_width_all(3)
				psb.border_color = Color.WHITE
			pb.add_theme_stylebox_override(pst, psb)
		pb.pressed.connect(_on_area.bind(EmbersBiomePaint.AREAS.size() + j))
		_bar.add_child(pb)
	_value_lbl = _small_label("")
	_bar.add_child(_value_lbl)
	_bar.add_child(HSeparator.new())
	_radius = VSlider.new()
	_radius.min_value = 4.0
	_radius.max_value = 150.0
	_radius.value = 30.0
	_radius.custom_minimum_size = Vector2(0, 90)
	_radius.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_radius.tooltip_text = "Brush size"
	_radius.value_changed.connect(func(v: float) -> void: _radius_label.text = "%dm" % int(v))
	_bar.add_child(_radius)
	_radius_label = _small_label("30m")
	_bar.add_child(_radius_label)
	_bar.add_child(HSeparator.new())
	_erase = _icon_btn(["Eraser", "Remove"], "Erase: brush away the painted area (the land goes back to the world's default biome)", true)
	_bar.add_child(_erase)
	_paint_tex = _icon_btn(["Paint", "ColorPick", "CanvasItemMaterial"], "Rough preview: also paint Terrain3D's own textures as you brush (grass for Meadow, forest for Thornwood, snow for Frostspine, rock on steep slopes ...), so sculpting shows roughly what it will look like. The game uses the flat colours; this does not change the world.", true, true)
	_bar.add_child(_paint_tex)
	var refresh := _icon_btn(["Reload", "Refresh"], "Repaint Terrain3D's textures everywhere from your painted biomes (after sculpting a lot, or if the colours look stale)")
	refresh.pressed.connect(_paint)
	_bar.add_child(refresh)
	var fill := _icon_btn(["Bucket", "Add"], "Fill all: paint the whole world with the chosen area")
	fill.pressed.connect(_on_fill)
	_bar.add_child(fill)
	var clear := _icon_btn(["Clear", "Remove"], "Clear all: remove everything painted")
	clear.pressed.connect(_on_clear)
	_bar.add_child(clear)
	_bar.add_child(HSeparator.new())
	var send := _icon_btn(["Upload", "Save", "Play"], "Send to server: export the world and rebuild the flat-colour ground, so the server and the game use exactly what you painted (restart the server afterwards)")
	send.pressed.connect(_send)
	_bar.add_child(send)
	_bar.add_child(_small_label("Send"))
	_status = _small_label("")
	_status.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	_bar.add_child(_status)
	add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_SIDE_LEFT, _bar)
	_on_area(0)


func _on_area(i: int) -> void:
	_area_sel = i
	var na: int = EmbersBiomePaint.AREAS.size()
	_value_lbl.text = str(EmbersBiomePaint.AREAS[i][0]) if i < na else str(EmbersBiomePaint.PATCHES[i - na][0]) + " patch"


## Terrain3D and the flat ground sit at the same height and fight when both show. Select Terrain3D to sculpt: only Terrain3D shows.
## Select anything else: only the flat ground shows, unless you may have sculpted (then Terrain3D stays until you press Send).
func _on_selection() -> void:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		return
	var holder := root.find_child(EmbersFacetGround.NODE_NAME, true, false) as Node3D
	if holder == null:
		return
	var on_terrain := false
	for n: Node in EditorInterface.get_selection().get_selected_nodes():
		if n.is_class("Terrain3D"):
			on_terrain = true
	if on_terrain:
		_terrain_dirty = true
	var show_flat := not on_terrain and not _terrain_dirty
	holder.visible = show_flat
	for t3: Node in root.find_children("*", "Terrain3D", true, false):
		(t3 as Node3D).visible = not show_flat
		if show_flat:
			t3.set_meta("embers_hidden", true)
		elif t3.has_meta("embers_hidden"):
			t3.remove_meta("embers_hidden")
	if _terrain_dirty and not on_terrain:
		_set_status("  terrain edited: press Send")
	# the old paint overlay and the flat ground take turns: let the paint node look again now that the flat ground may be hidden
	for pn: Node in root.find_children("*", "EmbersBiomePaint", true, false):
		(pn as EmbersBiomePaint)._sync_preview()
	if on_terrain and not _was_on_terrain and _last_sig.is_empty():
		_last_sig = _height_sig(root)   # a baseline before any sculpting
	if (_was_on_terrain or _recolour_pending) and not on_terrain:
		_recolour_pending = false
		_recolour_changed(root)   # you came away from sculpting: colour what changed
	_was_on_terrain = on_terrain


## Terrain3D's ground was changed by a tool (an import, low poly ...), so the flat-colour ground is out of date: show Terrain3D and keep
## the flat ground hidden until Send builds it again.
## A fingerprint of every region's heights (1000 sample points each), so we can tell which regions were sculpted.
func _height_sig(root: Node) -> Dictionary:
	var sig := {}
	var terrain := EmbersPainter._find_terrain(root)
	if terrain == null:
		return sig
	var data: Object = terrain.get("data")
	if data == null or not data.has_method("get_region_locations"):
		return sig
	var rs := int(terrain.get("region_size"))
	var sp := float(terrain.get("vertex_spacing"))
	for loc_v: Variant in data.call("get_region_locations"):
		var loc := Vector2i(loc_v)
		var h := 0
		for k in 1000:
			var v: float = data.call("get_height", Vector3((loc.x * rs + (k * 37 + 5) % rs) * sp, 0.0, (loc.y * rs + (k * 91 + 3) % rs) * sp))
			h = (h * 31 + (0 if is_nan(v) else roundi(v * 100.0))) & 0x7fffffff
		sig[loc] = h
	return sig


## Live: while Terrain3D is selected, watch the heights in 32 m blocks and recolour the blocks you just sculpted a few times a second,
## so new land, hills and sea floor show their ground as you work (no Refresh needed).
const LIVE_BLOCK := 32
const LIVE_PER_TICK := 6


func _process(delta: float) -> void:
	_live_t += delta
	if _live_t < 0.3:
		return
	_live_t = 0.0
	if _paint_tex == null or not _paint_tex.button_pressed:
		_live_sig = {}
		return
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		return
	var on_terrain := false
	for n: Node in EditorInterface.get_selection().get_selected_nodes():
		if n.is_class("Terrain3D"):
			on_terrain = true
	if not on_terrain:
		_live_sig = {}
		_live_queue.clear()
		return
	_live_tick(root)


func _live_tick(root: Node) -> void:
	var terrain := EmbersPainter._find_terrain(root)
	if terrain == null:
		return
	var data: Object = terrain.get("data")
	if data == null or not data.has_method("get_region_locations"):
		return
	var rs := int(terrain.get("region_size"))
	var sp := float(terrain.get("vertex_spacing"))
	var baseline := _live_sig.is_empty()
	var now := {}
	for loc_v: Variant in data.call("get_region_locations"):
		var loc := Vector2i(loc_v)
		var region: Object = EmbersLowPoly._region_at(data, loc, rs, sp)
		if region == null or not region.has_method("get_height_map"):
			continue
		var img: Image = region.call("get_height_map")
		if img == null or img.get_width() != rs:
			continue
		for bz in rs / LIVE_BLOCK:
			for bx in rs / LIVE_BLOCK:
				var h: int = hash(img.get_region(Rect2i(bx * LIVE_BLOCK, bz * LIVE_BLOCK, LIVE_BLOCK, LIVE_BLOCK)).get_data())
				var key := "%d,%d,%d,%d" % [loc.x, loc.y, bx, bz]
				now[key] = h
				if not baseline and (not _live_sig.has(key) or int(_live_sig[key]) != h):
					var x0 := (loc.x * rs + bx * LIVE_BLOCK) * sp - sp * 2.0
					var z0 := (loc.y * rs + bz * LIVE_BLOCK) * sp - sp * 2.0
					_live_queue.append([x0, z0, x0 + LIVE_BLOCK * sp + sp * 4.0, z0 + LIVE_BLOCK * sp + sp * 4.0])
	_live_sig = now
	if _live_queue.is_empty():
		return
	var papers := root.find_children("*", "EmbersBiomePaint", true, false)
	if papers.is_empty():
		_live_queue.clear()
		return
	var ctx: Dictionary = EmbersPainter.brush_context(root)
	if ctx.has("error"):
		_live_queue.clear()
		return
	var batch: Array = _live_queue.slice(0, LIVE_PER_TICK)
	_live_queue = _live_queue.slice(LIVE_PER_TICK)
	EmbersPainter.paint_rects(ctx, papers[0] as EmbersBiomePaint, batch)
	EmbersPainter.repaint_roads(root, ctx)
	_terrain_dirty = true
	if _live_queue.is_empty():
		_last_sig = _height_sig(root)   # leaving Terrain3D need not recolour whole regions again


## After sculpting: recolour only the regions whose heights changed (new land, hills, sea floor take their ground from their height).
func _recolour_changed(root: Node) -> void:
	if _paint_tex == null or not _paint_tex.button_pressed:
		return
	var papers := root.find_children("*", "EmbersBiomePaint", true, false)
	if papers.is_empty():
		return
	var now := _height_sig(root)
	var changed: Array[Vector2i] = []
	for loc: Vector2i in now.keys():
		if not _last_sig.has(loc) or int(_last_sig[loc]) != int(now[loc]):
			changed.append(loc)
	_last_sig = now
	if changed.is_empty():
		return
	var ctx: Dictionary = EmbersPainter.brush_context(root)
	if ctx.has("error"):
		_set_status("  no colours: " + str(ctx["error"]))
		return
	var terrain: Node = ctx["terrain"]
	var span := int(terrain.get("region_size")) * float(terrain.get("vertex_spacing"))
	var pts := 0
	for loc: Vector2i in changed:
		pts += EmbersPainter.paint_box(ctx, papers[0] as EmbersBiomePaint, loc.x * span, loc.y * span, (loc.x + 1) * span, (loc.y + 1) * span)
	EmbersPainter.repaint_roads(root, ctx)   # paths stay on top of the biome colours
	_set_status("  coloured %d region(s)" % changed.size())
	print("Embers: recoloured ", changed.size(), " region(s), ", pts, " points")


func _terrain_changed() -> void:
	_last_sig = {}   # everything may have changed (an import, low poly ...): all of it is recoloured
	_recolour_pending = true
	_terrain_dirty = true
	_on_selection()


func _send() -> void:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		_show("Open your world scene first.")
		return
	_set_status("  sending...")
	await get_tree().process_frame
	await get_tree().process_frame
	var out := "res://embers_export"
	var w := root.find_children("*", "EmbersWorld", true, false)
	if root is EmbersWorld:
		w.append(root)
	if not w.is_empty() and (w[0] as EmbersWorld).export_dir != "":
		out = (w[0] as EmbersWorld).export_dir
	var r := EmbersExporter.run(root, out, true)
	if not r["ok"]:
		_set_status("")
		_show("[PROBLEMS] Nothing was sent.\n\n" + "\n".join(r["errors"]))
		return
	var t := "[OK] Sent. The world was written to:\n  %s\n\n" % r["stats"].get("written_to", out)
	var chars: String = str(r["stats"].get("characters", ""))
	t += "Characters sent to the server: %s\n" % (chars if chars != "" else "NONE (add an EmbersPoint with Kind = NPC and an Id like tam)")
	for wn: String in r["warnings"]:
		t += "Warning: %s\n" % wn
	t += "\n"
	t += EmbersFacetGround.build(root)
	_terrain_dirty = false
	t += "\n\nNow restart the server (./start_server.command) so it loads the new world."
	_set_status("")
	_show(t)


func _set_status(text: String) -> void:
	if _status != null:
		_status.text = text.strip_edges()
	print("Embers paint:", text)


func _handles(object: Object) -> bool:
	return object is EmbersBiomePaint or object is EmbersRoad


func _edit(object: Object) -> void:
	_paint_node = object as EmbersBiomePaint
	_road = object as EmbersRoad
	if _road != null:
		_road_width.value = _road.width
		_road_smooth.button_pressed = _road.smooth_curve


func _make_visible(visible: bool) -> void:
	var scene := EditorInterface.get_edited_scene_root()
	if scene != null:
		for pn: EmbersBiomePaint in scene.find_children("*", "EmbersBiomePaint", true, false):
			pn.set_active(visible and pn == _paint_node)
	_bar.visible = visible and _paint_node != null
	_road_bar.visible = visible and _road != null
	if not visible:
		_hide_cursor()
		_stroking = false


func _on_fill() -> void:
	if _paint_node == null:
		return
	var before := _paint_node.snapshot()
	_paint_node.fill_area(-1 if _erase.button_pressed else mini(_area_sel, EmbersBiomePaint.AREAS.size() - 1))
	_commit("Fill the map", before)


func _on_clear() -> void:
	if _paint_node == null:
		return
	var before := _paint_node.snapshot()
	_paint_node.fill_area(-1)
	_paint_node.remove_strays()
	_paint_node._redraw()
	_commit("Clear the map", before)


func _commit(label: String, before: Dictionary) -> void:
	var after := _paint_node.snapshot()
	_paint_node.store()
	var ur := get_undo_redo()
	ur.create_action(label)
	ur.add_do_method(_paint_node, "restore", after)
	ur.add_undo_method(_paint_node, "restore", before)
	ur.commit_action(false)


func _forward_3d_gui_input(camera: Camera3D, event: InputEvent) -> int:
	if _road != null and _road_bar.visible:
		return _road_input(camera, event)
	if _paint_node == null or not _bar.visible:
		return 0
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.alt_pressed:
			if mb.pressed:
				var hit: Variant = _ground_hit(camera, mb.position)
				if hit == null:
					return 0
				_stroking = true
				_stroke_area = (-2 if _area_sel >= EmbersBiomePaint.AREAS.size() else -1) if _erase.button_pressed else _area_sel
				_before_snap = _paint_node.snapshot()
				_tex_ctx = null
				_last_dab = Vector3(1e9, 0, 1e9)
				if _paint_tex != null and _paint_tex.button_pressed:
					var bc: Dictionary = EmbersPainter.brush_context(EditorInterface.get_edited_scene_root())
					if bc.has("error"):
						_set_status("  no preview: " + str(bc["error"]))
					else:
						_tex_ctx = bc
				_dab(hit as Vector3)
				return 1
			elif _stroking:
				_stroking = false
				if _tex_ctx != null:
					EmbersPainter.paint_disc(_tex_ctx, _paint_node, _last_pos.x, _last_pos.z, _radius.value)   # the end of the stroke
				_tex_ctx = null
				_commit("Paint biomes", _before_snap)
				return 1
	elif event is InputEventMouseMotion:
		var hit2: Variant = _ground_hit(camera, (event as InputEventMouseMotion).position)
		if hit2 == null:
			_hide_cursor()
			return 0
		_show_cursor(hit2 as Vector3)
		if _stroking:
			_dab(hit2 as Vector3)
			return 1
	return 0


func _dab(p: Vector3) -> void:
	_last_pos = p
	var na: int = EmbersBiomePaint.AREAS.size()
	if _stroke_area >= na:
		_paint_node.paint_patch(p.x, p.z, _radius.value, int(EmbersBiomePaint.PATCHES[_stroke_area - na][1]))
	elif _stroke_area == -2:
		_paint_node.paint_patch(p.x, p.z, _radius.value, -1)   # eraser with a patch selected: only the patch goes
	else:
		_paint_node.paint_area(p.x, p.z, _radius.value, _stroke_area)
	if _tex_ctx != null and Vector2(p.x - _last_dab.x, p.z - _last_dab.z).length() >= maxf(_radius.value * 0.3, 2.0):
		_last_dab = p
		EmbersPainter.paint_disc(_tex_ctx, _paint_node, p.x, p.z, _radius.value)


## Where the mouse ray meets your terrain (walks along the ray until it goes below the ground).
func _ground_hit(camera: Camera3D, pos: Vector2) -> Variant:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		return null
	var o := camera.project_ray_origin(pos)
	var d := camera.project_ray_normal(pos)
	var t := 0.0
	var last := 0.0
	for i in 2500:
		var p := o + d * t
		var h := EmbersGround.height_at(root, p.x, p.z)
		if is_nan(h):
			h = -2.0
		if p.y <= h:
			var lo := last
			var hi := t
			for k in 10:
				var mid := (lo + hi) * 0.5
				var q := o + d * mid
				var hq := EmbersGround.height_at(root, q.x, q.z)
				if is_nan(hq):
					hq = -2.0
				if q.y <= hq:
					hi = mid
				else:
					lo = mid
			return o + d * hi
		last = t
		t += maxf(1.5, t * 0.01)
		if t > 8000.0:
			break
	return null


func _show_cursor(p: Vector3) -> void:
	if _cursor == null or not is_instance_valid(_cursor):
		_cursor = MeshInstance3D.new()
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(1, 0.85, 0.3, 0.35)
		m.no_depth_test = true
		_cursor.material_override = m
		_cursor.name = "_brush"
		_paint_node.add_child(_cursor)
	var cm := CylinderMesh.new()
	cm.top_radius = _radius.value
	cm.bottom_radius = _radius.value
	cm.height = 0.4
	cm.radial_segments = 32
	cm.rings = 1
	_cursor.mesh = cm
	_cursor.global_position = p + Vector3(0, 0.3, 0)


func _hide_cursor() -> void:
	if _cursor != null and is_instance_valid(_cursor):
		_cursor.queue_free()
	_cursor = null


# ================================================================ path builder (EmbersRoad)
func _build_road_bar() -> void:
	if _road_bar != null and is_instance_valid(_road_bar):
		remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_SIDE_LEFT, _road_bar)
		_road_bar.queue_free()
	_road_bar = VBoxContainer.new()
	_road_bar.visible = false
	_road_bar.add_theme_constant_override("separation", 3)
	_road_bar.add_child(_small_label("PATH"))
	_road_add = _icon_btn(["Add", "ToolAddNode"], "Edit the path: click the terrain to add a point at the end; press on a point and drag to move it; Ctrl+click inserts a point into the middle of the path; Shift+click removes the nearest point", true, true)
	_road_bar.add_child(_road_add)
	_road_width = VSlider.new()
	_road_width.min_value = 1.0
	_road_width.max_value = 16.0
	_road_width.step = 0.5
	_road_width.value = 4.0
	_road_width.custom_minimum_size = Vector2(0, 90)
	_road_width.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_road_width.tooltip_text = "Path width"
	_road_width.value_changed.connect(func(v: float) -> void:
		_road_width_label.text = "%.1fm" % v
		if _road != null:
			_road.width = v)
	_road_bar.add_child(_road_width)
	_road_width_label = _small_label("4.0m")
	_road_bar.add_child(_road_width_label)
	_road_smooth = _icon_btn(["Curve", "CurveCreate"], "Smooth: round the corners of the path", true, true)
	_road_smooth.toggled.connect(func(on: bool) -> void:
		if _road != null:
			_road.smooth_curve = on)
	_road_bar.add_child(_road_smooth)
	_road_bar.add_child(HSeparator.new())
	var undo := _icon_btn(["UndoRedo", "Reload"], "Remove the last point")
	undo.pressed.connect(func() -> void: _road_edit("Remove last path point", func(pts: PackedVector3Array) -> PackedVector3Array:
		if pts.size() > 0:
			pts.remove_at(pts.size() - 1)
		return pts))
	_road_bar.add_child(undo)
	var clear := _icon_btn(["Clear", "Remove"], "Clear the whole path")
	clear.pressed.connect(func() -> void: _road_edit("Clear path", func(_pts: PackedVector3Array) -> PackedVector3Array: return PackedVector3Array()))
	_road_bar.add_child(clear)
	var snap := _icon_btn(["MoveDown", "ToolMove"], "Snap the points to the ground")
	snap.pressed.connect(func() -> void:
		if _road != null:
			_road.snap_points_to_ground())
	_road_bar.add_child(snap)
	var paint := _icon_btn(["Paint", "ColorPick"], "Paint path on terrain: puts the path texture on the Terrain3D ground along this path (soft edges). Needs the ground textures set up (Project > Tools > Embers: Set up ground textures)")
	paint.pressed.connect(_road_paint)
	_road_bar.add_child(paint)
	add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_SIDE_LEFT, _road_bar)


func _road_edit(label: String, change: Callable) -> void:
	if _road == null:
		return
	var before := _road.get_points()
	var after: PackedVector3Array = change.call(before.duplicate())
	var ur := get_undo_redo()
	ur.create_action(label)
	ur.add_do_method(_road, "set_points", after)
	ur.add_undo_method(_road, "set_points", before)
	ur.commit_action()


func _road_input(camera: Camera3D, event: InputEvent) -> int:
	if not _road_add.button_pressed:
		return 0
	if event is InputEventMouseMotion and _road_drag >= 0:
		var h: Variant = _ground_hit(camera, (event as InputEventMouseMotion).position)
		if h != null:
			var pts := _road.get_points()
			if _road_drag < pts.size():
				pts[_road_drag] = h as Vector3
				_road.set_points(pts)   # live while dragging; the undo step is made on release
		return 1
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT or mb.alt_pressed:
			return 0
		if not mb.pressed:
			if _road_drag >= 0:
				var after := _road.get_points()
				var before := _road_drag_before
				_road_drag = -1
				var ur := get_undo_redo()
				ur.create_action("Move path point")
				ur.add_do_method(_road, "set_points", after)
				ur.add_undo_method(_road, "set_points", before)
				ur.commit_action(false)
				return 1
			return 1
		var hit: Variant = _ground_hit(camera, mb.position)
		if hit == null:
			return 0
		var p := hit as Vector3
		var pts2 := _road.get_points()
		var nearest := -1
		var nd := maxf(_road.width, 6.0)   # grab a point when you click within this many metres of it
		for i in pts2.size():
			var d := Vector2(pts2[i].x - p.x, pts2[i].z - p.z).length()
			if d < nd:
				nd = d
				nearest = i
		if mb.shift_pressed:
			if nearest >= 0:
				_road_edit("Remove path point", func(pts: PackedVector3Array) -> PackedVector3Array:
					pts.remove_at(nearest)
					return pts)
			return 1
		if mb.ctrl_pressed and pts2.size() >= 2:
			# insert a point into the middle of the path, on the segment nearest the click
			var seg := 0
			var sd := INF
			for i in pts2.size() - 1:
				var a := Vector2(pts2[i].x, pts2[i].z)
				var b := Vector2(pts2[i + 1].x, pts2[i + 1].z)
				var c := Geometry2D.get_closest_point_to_segment(Vector2(p.x, p.z), a, b)
				var dd := c.distance_to(Vector2(p.x, p.z))
				if dd < sd:
					sd = dd
					seg = i
			_road_edit("Insert path point", func(pts: PackedVector3Array) -> PackedVector3Array:
				pts.insert(seg + 1, p)
				return pts)
			return 1
		if nearest >= 0:
			_road_drag = nearest   # press on a point and drag it
			_road_drag_before = pts2.duplicate()
			return 1
		_road_edit("Add path point", func(pts: PackedVector3Array) -> PackedVector3Array:
			pts.append(p)
			return pts)
		return 1
	return 0


func _road_paint() -> void:
	var root := EditorInterface.get_edited_scene_root()
	if root == null or _road == null:
		return
	var ctx: Dictionary = EmbersPainter.brush_context(root)
	if ctx.has("error"):
		_show("Can't paint the path: " + str(ctx["error"]) + ". (No Terrain3D with textures in this scene? Add a Terrain3D, then run Project > Tools > Embers: Set up ground textures (like the original game).")
		return
	var n := EmbersPainter.paint_road(ctx, _road)
	EmbersPainter._update((ctx as Dictionary)["data"])
	_show("Painted the path on the terrain (%d points). It uses the path textures \"Path Meadow\", \"Path Thornwood\" and so on, chosen by the biome under each part of the path." % n)
