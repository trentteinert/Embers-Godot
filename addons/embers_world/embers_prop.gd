@tool
class_name EmbersProp
extends Node3D
## One of the game's own models, placed in your scene: buildings, trees and rocks, people. It draws the real
## thing (the game's own code builds it), so what you see in the editor is what players see. Buildings and
## solid trees and rocks block players on the server automatically. This only works in the game's Godot
## project (run godot_world/apply_to_game.sh on it once).

enum Category { BUILDING, SCENERY, NPC, MONSTER, FARM, HOUSE }

const BUILDINGS := ["cottage", "house", "longhouse", "tavern", "shop", "smithy", "chapel", "watchtower", "windmill", "barn", "stilt_hut", "lodge", "hall_house", "apothecary", "farm", "farmhouse", "granary", "fisher_cottage", "townhouse", "log_cabin", "turf_hut", "reed_hut", "wreck_shack", "chalet",
	"palisade", "stone_wall", "fence", "gatehouse", "wall_tower", "keep", "castle_wall", "castle_tower", "castle_gate", "well", "stall", "lamp", "barrel", "crate", "crates", "cart", "haybale", "signpost", "bench", "banner", "notice_board", "tent", "yurt", "bedroll", "log_seat", "campfire", "spit", "weapon_rack", "dummy", "firewood", "scarecrow", "trough", "flowerbox", "pier", "bridge"]
const SCENERY := ["oak", "dark_oak", "autumn", "birch", "willow", "pine", "tall_pine", "dead", "ancient_tree", "bush", "fern", "mushroom", "reeds", "log", "stump", "boulder", "rockmass", "mossrock", "pebbles", "tuft", "tallgrass", "flower", "glowcap", "frostweed", "bones", "branches", "spire", "obelisk", "standing_stones", "ruin", "old_camp"]
const NPCS := ["tam", "king", "merchant", "hermit", "smith", "slayer", "elder", "farmer", "ranger", "pilgrim", "warrior", "rogue", "mage", "hunter"]
const STYLES := ["meadow", "coast", "briar", "downs", "tidal", "thornwood", "mire", "peaks"]
## Trees and rocks players can't walk through (radius in metres), as in the game's chunk streamer.
const SOLID_TREES := ["oak", "dark_oak", "dead", "pine", "birch", "willow", "tall_pine", "autumn"]
const SOLID_ROCKS := ["boulder", "spire"]

@export var category: Category = Category.BUILDING: set = _set_category
@export var kind := "tavern": set = _set_kind
@export_enum("meadow", "coast", "briar", "downs", "tidal", "thornwood", "mire", "peaks") var style := "meadow": set = _set_style
## Different number = a slightly different version (trees, rocks, house details).
@export var variation := 0: set = _set_variation
## Walls, fences, piers and bridges only: how long.
@export var length := 6.0: set = _set_length

## Drop onto the terrain whenever you move it in the editor.
@export var stick_to_ground := true
@export_tool_button("Snap to ground") var _snap_button: Callable = snap_to_ground
## Level the ground under a building by itself about a second after you stop moving it (only for houses, barns, towers and other big
## buildings, farm and house kit pieces; not trees, rocks, fences or small things). Ctrl+Z undoes it. Turn off to level by hand with the button.
@export var auto_level_ground := true
## "Level the ground under this": how far past the walls the flat area reaches, in metres.
@export_range(0.0, 20.0, 0.5) var level_margin := 1.5
## ... and how many metres it then takes to blend back into the hill.
@export_range(0.0, 30.0, 0.5) var level_blend := 6.0
## Press to flatten the Terrain3D ground under this building (with the margin and blend above), and sit it on the flat. A house on a slope
## cannot be tilted (the game's floors and doors are level), so the ground is cut and filled to fit it instead. Ctrl+Z does not undo
## this: save first, or use it on a copy of the scene.
@export_tool_button("Level the ground under this") var _level_button: Callable = level_ground

var _snapping := false
var _lv_token := 0
var _loaded := false   # false while the scene is loading: nothing is levelled until it has opened


## Put this at the height of the terrain under it. Returns false if there is no ground there.
func snap_to_ground() -> bool:
	var root := EmbersGround.scene_of(self)
	if root == null:
		return false
	var h := EmbersGround.height_at(root, global_position.x, global_position.z)
	if is_nan(h):
		return false
	_snapping = true
	global_position.y = h
	_snapping = false
	return true


## The size of this prop's footprint in its own x and z (half widths), from its model; {} if it has no model yet.
func footprint() -> Dictionary:
	if _model == null:
		return {}
	var inv := global_transform.affine_inverse()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for n: Node in _model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		var box := mi.mesh.get_aabb()
		var xf := inv * mi.global_transform
		for i in 8:
			var c := xf * box.get_endpoint(i)
			lo = Vector2(minf(lo.x, c.x), minf(lo.y, c.z))
			hi = Vector2(maxf(hi.x, c.x), maxf(hi.y, c.z))
	if lo.x == INF:
		return {}
	return {"lo": lo, "hi": hi}


## Flatten the ground inside `lo`..`hi` (prop-local x,z) plus `margin`, blending out over `blend` metres, to the average height under the
## footprint. Works on any Terrain3D-like `data`. Returns {"target": height, "points": count, "min": Vector2, "max": Vector2 (world x,z bounds)}.
static func level_footprint(data: Object, to_world: Transform3D, lo: Vector2, hi: Vector2, margin: float, blend: float, spacing: float, record := {}) -> Dictionary:
	var inv := to_world.affine_inverse()
	var reach := margin + blend
	var corners: Array[Vector3] = []
	for cx in [lo.x - reach, hi.x + reach]:
		for cz in [lo.y - reach, hi.y + reach]:
			corners.append(to_world * Vector3(cx, 0.0, cz))
	var wmin := Vector2(INF, INF)
	var wmax := Vector2(-INF, -INF)
	for c: Vector3 in corners:
		wmin = Vector2(minf(wmin.x, c.x), minf(wmin.y, c.z))
		wmax = Vector2(maxf(wmax.x, c.x), maxf(wmax.y, c.z))
	var step := maxf(spacing, 0.5)
	# 1. the average height under the footprint itself
	var sum := 0.0
	var n := 0
	var x := snappedf(wmin.x, step)
	while x <= wmax.x:
		var z := snappedf(wmin.y, step)
		while z <= wmax.y:
			var l := inv * Vector3(x, 0.0, z)
			if l.x >= lo.x and l.x <= hi.x and l.z >= lo.y and l.z <= hi.y:
				var h: float = data.call("get_height", Vector3(x, 0.0, z))
				if not is_nan(h):
					sum += h
					n += 1
			z += step
		x += step
	if n == 0:
		return {}
	var target := sum / n
	# 2. pull every point within reach of the footprint towards it, fully inside margin, fading to nothing at margin + blend
	var changed := 0
	var rxz := PackedVector2Array()
	var rold := PackedFloat32Array()
	var rnew := PackedFloat32Array()
	x = snappedf(wmin.x, step)
	while x <= wmax.x:
		var z2 := snappedf(wmin.y, step)
		while z2 <= wmax.y:
			var l2 := inv * Vector3(x, 0.0, z2)
			var dx := maxf(maxf(lo.x - l2.x, l2.x - hi.x), 0.0)
			var dz := maxf(maxf(lo.y - l2.z, l2.z - hi.y), 0.0)
			var d := Vector2(dx, dz).length()
			if d <= reach:
				var w := 1.0 if d <= margin else 1.0 - smoothstep(0.0, 1.0, (d - margin) / maxf(blend, 0.001))
				var pos := Vector3(x, 0.0, z2)
				var h2: float = data.call("get_height", pos)
				if not is_nan(h2):
					var nh := lerpf(h2, target, w)
					data.call("set_height", pos, nh)
					rxz.append(Vector2(x, z2))
					rold.append(h2)
					rnew.append(nh)
					changed += 1
			z2 += step
		x += step
	if data.has_method("update_maps"):
		data.call("update_maps")
	record["xz"] = rxz
	record["old"] = rold
	record["new"] = rnew
	return {"target": target, "points": changed, "min": wmin, "max": wmax}


## About a second after the last change (so dragging a building never carves the hill along the way), level the ground under it.
func _schedule_level() -> void:
	if not Engine.is_editor_hint() or not auto_level_ground or not _loaded or not is_inside_tree():
		return
	if category != Category.BUILDING and category != Category.HOUSE and category != Category.FARM:
		return
	_lv_token += 1
	var token := _lv_token
	get_tree().create_timer(1.2).timeout.connect(func() -> void:
		if token == _lv_token and is_inside_tree():
			level_ground(true))


## Write heights back (also used by Ctrl+Z / redo of a levelling): xz are world positions, `vals` the heights.
func _set_heights(terrain_path: NodePath, xz: PackedVector2Array, vals: PackedFloat32Array, y: float) -> void:
	var terrain := get_node_or_null(terrain_path)
	if terrain != null:
		var data: Object = terrain.get("data")
		if data != null:
			for i in xz.size():
				data.call("set_height", Vector3(xz[i].x, 0.0, xz[i].y), vals[i])
			if data.has_method("update_maps"):
				data.call("update_maps")
	_snapping = true
	global_position.y = y
	_snapping = false


## The button: level the Terrain3D ground under this prop and sit the prop on it. Returns a message. `auto` = called by itself after a
## move: small things and anything in or under the water are left alone, and it says nothing unless it did something.
func level_ground(auto := false) -> String:
	var msg := ""
	var root := EmbersGround.scene_of(self)
	var terrain: Node = null
	if root != null:
		for t3: Node in root.find_children("*", "Terrain3D", true, false):
			terrain = t3
			break
	var fp := footprint()
	if terrain == null:
		msg = "" if auto else "There is no Terrain3D node in this scene to level."
	elif fp.is_empty():
		msg = "" if auto else "This prop has no model to measure yet."
	else:
		var data: Object = terrain.get("data")
		var size: Vector2 = (fp["hi"] as Vector2) - (fp["lo"] as Vector2)
		if auto and (size.x * size.y < 20.0 or minf(size.x, size.y) < 3.0):
			return ""   # a barrel, a lamp, a fence: not worth a flat
		var old_y := global_position.y
		var rec := {}
		var r := EmbersProp.level_footprint(data, global_transform, fp["lo"], fp["hi"], level_margin, level_blend, float(terrain.get("vertex_spacing")), rec)
		if r.is_empty():
			msg = "There is no Terrain3D ground under this prop."
		elif auto and float(r["target"]) < 0.3:
			# in or at the water: put the ground back (nothing was meant to change), and leave it
			var xz0: PackedVector2Array = rec["xz"]
			var old0: PackedFloat32Array = rec["old"]
			for i in xz0.size():
				data.call("set_height", Vector3(xz0[i].x, 0.0, xz0[i].y), old0[i])
			if data.has_method("update_maps"):
				data.call("update_maps")
			return ""
		else:
			_snapping = true
			global_position.y = float(r["target"])
			_snapping = false
			EmbersPainter.recolour_rect(root, (r["min"] as Vector2).x, (r["min"] as Vector2).y, (r["max"] as Vector2).x, (r["max"] as Vector2).y)
			if Engine.is_editor_hint() and EditorInterface.has_method("get_editor_undo_redo"):
				var ur: Object = EditorInterface.get_editor_undo_redo()
				ur.call("create_action", "Level ground under " + kind, 0, self)
				ur.call("add_do_method", self, "_set_heights", terrain.get_path(), rec["xz"], rec["new"], float(r["target"]))
				ur.call("add_undo_method", self, "_set_heights", terrain.get_path(), rec["xz"], rec["old"], old_y)
				ur.call("commit_action", false)
			msg = "Levelled %d ground points to %.2f m under the %s and sat it there. Ctrl+Z undoes it." % [int(r["points"]), float(r["target"]), kind]
	if auto and msg == "":
		return ""
	print("Embers: ", msg)
	if Engine.is_editor_hint() and EditorInterface.has_method("get_editor_toaster"):
		EditorInterface.get_editor_toaster().push_toast(msg)
	return msg


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and Engine.is_editor_hint() and stick_to_ground and not _snapping and is_inside_tree():
		snap_to_ground()
		_schedule_level()


var _model: Node3D
var _label: Label3D


func _set_category(v: Category) -> void:
	category = v
	var list := _list()
	if not list.has(kind):
		kind = list[0]
	notify_property_list_changed()
	_rebuild()


func _set_kind(v: String) -> void:
	kind = v
	_rebuild()


func _set_style(v: String) -> void:
	style = v
	_rebuild()


func _set_variation(v: int) -> void:
	variation = v
	_rebuild()


func _set_length(v: float) -> void:
	length = v
	_rebuild()


func _validate_property(p: Dictionary) -> void:
	if p.name == "kind":
		p.hint = PROPERTY_HINT_ENUM
		p.hint_string = ",".join(_list())
	elif p.name == "length" and category != Category.BUILDING and not (category == Category.FARM and kind in EmbersFarmKit.SIZED):
		p.usage = PROPERTY_USAGE_NO_EDITOR


func _list() -> Array:
	match category:
		Category.BUILDING:
			return BUILDINGS
		Category.SCENERY:
			return SCENERY
		Category.NPC:
			return NPCS
		Category.FARM:
			return EmbersFarmKit.KINDS
		Category.HOUSE:
			return EmbersHouseKit.KINDS
	return _monsters()


func _monsters() -> Array:
	if not ResourceLoader.exists("res://scripts/data.gd"):
		return ["wolf"]
	return (load("res://scripts/data.gd") as GDScript).get("ENEMIES").keys()


func _ready() -> void:
	if Engine.is_editor_hint():
		set_notify_transform(true)
	_rebuild()
	(func() -> void: _loaded = true).call_deferred()


## A duplicated prop (Ctrl+D, copy and paste) arrives with a copy of the original's model and label as children that this script does
## not know about, so changing its kind left the old model standing there and drew the new one over it. Remove those strays.
func _clear_strays() -> void:
	for c: Node in get_children():
		if c != _model and c != _label and (c.name.begins_with("_model") or c.name.begins_with("_label")):
			remove_child(c)
			c.queue_free()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _model != null:
		remove_child(_model)
		_model.queue_free()
		_model = null
	_clear_strays()
	_model = EmbersProp.make(category, kind, style, variation, length)
	if _model == null:
		_note("Game models not found.\nUse the game's Godot project (apply_to_game.sh).")
		return
	_model.name = "_model"
	add_child(_model)   # no owner: not saved, rebuilt when the scene opens
	_note("" if not Engine.is_editor_hint() else kind)
	_schedule_level()   # a different kind has a different footprint


func _note(t: String) -> void:
	if not Engine.is_editor_hint():
		return
	if _label == null:
		_label = Label3D.new()
		_label.name = "_label"
		_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_label.no_depth_test = true
		_label.pixel_size = 0.02
		_label.font_size = 40
		_label.outline_size = 10
		_label.position.y = 3.5
		_label.modulate = Color("ffd27a")
		add_child(_label)
	_label.text = t


## Build one of the game's models (null if the game's scripts aren't in this project).
static func make(cat: int, what: String, style_name := "meadow", seed_v := 0, len := 6.0) -> Node3D:
	if not ResourceLoader.exists("res://scripts/town_kit.gd") or not ResourceLoader.exists("res://scripts/models.gd"):
		return null
	match cat:
		Category.BUILDING:
			return (load("res://scripts/town_kit.gd") as GDScript).call("build", what, style_name, seed_v, len)
		Category.SCENERY:
			var mi := MeshInstance3D.new()
			mi.mesh = (load("res://scripts/models.gd") as GDScript).call("scenery_mesh", what, seed_v)
			var m := StandardMaterial3D.new()
			m.vertex_color_use_as_albedo = true
			m.roughness = 1.0
			mi.material_override = m
			return mi
		Category.NPC:
			return (load("res://scripts/models.gd") as GDScript).call("hero", what)
		Category.MONSTER:
			return (load("res://scripts/models.gd") as GDScript).call("creature", what)
		Category.FARM:
			return EmbersFarmKit.build(what, style_name, seed_v, len)
		Category.HOUSE:
			return EmbersHouseKit.build(what, style_name, seed_v, len)
	return null


## Radius of the trunk or rock, or 0 if it doesn't block.
func solid_radius() -> float:
	if category != Category.SCENERY:
		return 0.0
	if kind in SOLID_TREES:
		return 0.45
	if kind in SOLID_ROCKS:
		return 0.8
	return 0.0
