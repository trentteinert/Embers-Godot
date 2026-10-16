@tool
class_name EmbersBiomePaint
extends Node3D
## A painted map of your world: select this node, then paint with the mouse in the 3D view to say which biome (so which
## monsters and plants), which ground and which named zone each place has. It is drawn on the terrain as a coloured
## overlay while you edit. It covers the 2400 m world square around this node (keep it at the world's middle, 0, 0).
## Painted places win over EmbersRegion boxes, so use boxes for the big picture and the brush for the details.
## How to paint: see the toolbar that appears at the top of the 3D view when this node is selected.

const CELL := 4.0   # metres per painted square
const LAYERS := ["biome", "ground", "zone"]
const BIOMES := ["Meadow", "Thornwood", "Mire", "Frostspine", "Coast"]
## ids 1..7 of the server's ground types (0 is water, which the terrain decides by itself)
const GROUNDS := ["Sand", "Grass", "Forest", "Mud", "Bog", "Snow", "Rock", "Dirt path"]
const ZONES := ["campwater", "tallowfields", "hearthmoor", "brackenwood", "blackbriar", "saltfen", "bellwater", "greyfold", "frostspine"]
## What the brush paints: the five biomes (each changes the ground: grass, forest, mud and bog, snow, sand). Zones come later.
## [name, zone id or -1, biome id]
## Ground patches: paint just the ground (dirt, sand, rock) without touching the biome. [name, ground id]
const PATCHES := [["Dirt", 8], ["Sand", 1], ["Rock", 7]]
const AREAS := [["Meadow", -1, 0], ["Thornwood", -1, 1], ["Mire", -1, 2], ["Frostspine", -1, 3], ["Coast", -1, 4]]
## One bright solid colour per biome, so you can see at a glance what you painted.
const AREA_COLORS := [Color("3dff5a"), Color("ff9a2e"), Color("8a4dff"), Color("2ec8ff"), Color("f2d84a")]
const BIOME_COLORS := [Color("6ab050"), Color("2f7a4a"), Color("8a6aaa"), Color("9fd0e8"), Color("e0d08a")]
const GROUND_COLORS := [Color("e0d08a"), Color("7cc060"), Color("2f6a3a"), Color("7a5a3a"), Color("5a6a4a"), Color("f0f4f8"), Color("8a8a90"), Color("a8844f")]

@export var size_m := 2400.0
@export var show_overlay := true: set = _set_show
## The painting itself (packed small; leave alone).
@export_storage var biome_data := PackedByteArray()
@export_storage var ground_data := PackedByteArray()
@export_storage var zone_data := PackedByteArray()

var n := 600
var cells := {}              # layer name -> PackedByteArray (n*n; 0 = not painted, else id + 1)
var _decal: Decal
var _active := false   # the overlay only shows while this node is selected, so it never tints your terrain
var _img: Image
var _tex: ImageTexture


func _ready() -> void:
	n = maxi(int(round(size_m / CELL)), 1)
	_load()
	if Engine.is_editor_hint():
		_make_overlay()


func _load() -> void:
	for pair: Array in [["biome", biome_data], ["ground", ground_data], ["zone", zone_data]]:
		var key: String = pair[0]
		var data: PackedByteArray = pair[1]
		var arr := PackedByteArray()
		if data.size() > 0:
			arr = data.decompress(n * n, FileAccess.COMPRESSION_DEFLATE)
		if arr.size() != n * n:
			arr = PackedByteArray()
			arr.resize(n * n)
			arr.fill(0)
		cells[key] = arr


## Pack the painting into the saved properties (called before the scene is saved and after each stroke).
func store() -> void:
	biome_data = (cells["biome"] as PackedByteArray).compress(FileAccess.COMPRESSION_DEFLATE)
	ground_data = (cells["ground"] as PackedByteArray).compress(FileAccess.COMPRESSION_DEFLATE)
	zone_data = (cells["zone"] as PackedByteArray).compress(FileAccess.COMPRESSION_DEFLATE)


func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE and not cells.is_empty():
		store()


## What is painted at the world point (x, z): the id (biome 0..4, ground 1..7, zone 0..8), or -1 if nothing.
func value_at(layer: String, x: float, z: float) -> int:
	if cells.is_empty():
		return -1
	var ix := floori((x - global_position.x + size_m * 0.5) / CELL)
	var iz := floori((z - global_position.z + size_m * 0.5) / CELL)
	if ix < 0 or iz < 0 or ix >= n or iz >= n:
		return -1
	var v: int = (cells[layer] as PackedByteArray)[iz * n + ix]
	if v == 0:
		return -1
	return v - 1 if layer != "ground" else v   # ground ids start at 1 (0 would be water), so stored as they are


## Paint a round brush. value is the id to paint, or -1 to erase.
func paint(layer: String, x: float, z: float, radius: float, value: int) -> void:
	var arr: PackedByteArray = cells[layer]
	var stored: int = 0 if value < 0 else (value + 1 if layer != "ground" else value)
	var cx := (x - global_position.x + size_m * 0.5) / CELL
	var cz := (z - global_position.z + size_m * 0.5) / CELL
	var r := radius / CELL
	var x0 := maxi(floori(cx - r), 0)
	var x1 := mini(ceili(cx + r), n - 1)
	var z0 := maxi(floori(cz - r), 0)
	var z1 := mini(ceili(cz + r), n - 1)
	for iz in range(z0, z1 + 1):
		for ix in range(x0, x1 + 1):
			var dx := ix + 0.5 - cx
			var dz := iz + 0.5 - cz
			if dx * dx + dz * dz <= r * r + 0.25:
				arr[iz * n + ix] = stored
				_pixel(layer, ix, iz, stored)
	cells[layer] = arr
	_flush()


func fill(layer: String, value: int) -> void:
	var arr: PackedByteArray = cells[layer]
	arr.fill(0 if value < 0 else (value + 1 if layer != "ground" else value))
	cells[layer] = arr
	_redraw()


func get_layer(layer: String) -> PackedByteArray:
	return (cells[layer] as PackedByteArray).duplicate()


func set_layer(layer: String, data: PackedByteArray) -> void:
	cells[layer] = data.duplicate()
	_redraw()


## Paint a round brush of one area (an index of AREAS): the zone, and with it the biome. The ground painted underneath is wiped, so
## the biome's own ground shows. area -1 erases it all.
func paint_area(x: float, z: float, radius: float, area: int) -> void:
	var zv := -1
	var bv := -1
	if area >= 0:
		zv = int(AREAS[area][1])
		bv = int(AREAS[area][2])
	paint("zone", x, z, radius, zv)
	paint("biome", x, z, radius, bv)
	paint("ground", x, z, radius, -1)


## A round patch of one ground (a ground id, -1 = take the patch away). The biome underneath stays as it is.
func paint_patch(x: float, z: float, radius: float, ground: int) -> void:
	paint("ground", x, z, radius, ground)


func fill_area(area: int) -> void:
	if area >= 0:
		fill("zone", int(AREAS[area][1]))
		fill("biome", int(AREAS[area][2]))
	else:
		fill("zone", -1)
		fill("biome", -1)
	fill("ground", -1)


## All three layers at once (for undo).
func snapshot() -> Dictionary:
	return {"zone": get_layer("zone"), "biome": get_layer("biome"), "ground": get_layer("ground")}


func restore(snap: Dictionary) -> void:
	for k: String in snap.keys():
		cells[k] = (snap[k] as PackedByteArray).duplicate()
	store()
	_redraw()


## Which area is painted at a map cell (an index of AREAS = the biome), or -1.
func _area_of(i: int) -> int:
	var bs: int = (cells["biome"] as PackedByteArray)[i]
	return bs - 1 if bs > 0 else -1


# ================================================================ overlay (editor only)
func _set_show(v: bool) -> void:
	show_overlay = v
	if _decal != null:
		_decal.visible = v and _active
	_sync_preview()


## Called by the editor plugin: the coloured overlay is only shown while you are painting (this node selected).
func set_active(on: bool) -> void:
	_active = on
	if _decal != null:
		_decal.visible = show_overlay and _active
	_sync_preview()


## The flat-colour ground (EmbersFacetGround) draws the painted colours itself while you paint, from this node's map.
func overlay_info() -> Dictionary:
	if _tex == null:
		return {}
	return {"tex": _tex, "rect": Vector4(global_position.x - size_m * 0.5, global_position.z - size_m * 0.5, size_m, size_m)}


func _sync_preview() -> void:
	if not is_inside_tree() or not Engine.is_editor_hint():
		return
	var root := get_tree().edited_scene_root
	if root == null:
		return
	var holder := root.find_child("EmbersFacetGround", true, false)
	if _decal != null:
		_decal.visible = show_overlay and _active and not (holder != null and (holder as Node3D).visible)   # the flat ground draws the paint itself while it shows, so no doubling
	if holder != null and holder.has_meta("mat"):
		var mat := holder.get_meta("mat") as ShaderMaterial
		var info := overlay_info()
		if mat != null and not info.is_empty():
			mat.set_shader_parameter("area_tex", info["tex"])
			mat.set_shader_parameter("area_rect", info["rect"])
			mat.set_shader_parameter("show_area", 1.0 if (show_overlay and _active) else 0.0)


func _area_color(i: int) -> Color:
	var gs: int = (cells["ground"] as PackedByteArray)[i]
	if gs > 0 and gs <= GROUND_COLORS.size():
		var gc: Color = GROUND_COLORS[gs - 1]
		gc.a = 0.75
		return gc
	var k := _area_of(i)
	if k >= 0:
		var c: Color = AREA_COLORS[k]
		c.a = 0.5
		return c
	var bs: int = (cells["biome"] as PackedByteArray)[i]
	if bs > 0:   # an old biome-only painting: shown in that biome's colour, dimmer
		var c2: Color = BIOME_COLORS[clampi(bs - 1, 0, 4)]
		c2.a = 0.3
		return c2
	return Color(0, 0, 0, 0)


## Remove overlay and brush helper nodes left behind by an older copy of this script (they are invisible in the Scene dock, so
## they cannot be selected or deleted by hand). Returns how many were removed.
func remove_strays() -> int:
	var gone := 0
	for c: Node in get_children():
		if c == _decal:
			continue
		if c is Decal or c.name.begins_with("_overlay") or c.name.begins_with("_brush"):
			remove_child(c)
			c.queue_free()
			gone += 1
	return gone


func _make_overlay() -> void:
	if _decal != null:
		return
	remove_strays()
	_img = Image.create(n, n, false, Image.FORMAT_RGBA8)
	_tex = ImageTexture.create_from_image(_img)
	_decal = Decal.new()
	_decal.name = "_overlay"
	_decal.size = Vector3(size_m, 1200.0, size_m)
	_decal.texture_albedo = _tex
	_decal.upper_fade = 0.0
	_decal.lower_fade = 0.0
	_decal.visible = show_overlay and _active
	add_child(_decal)   # no owner: never saved
	_redraw()


func _redraw() -> void:
	if _img == null:
		return
	for iz in n:
		for ix in n:
			_img.set_pixel(ix, iz, _area_color(iz * n + ix))
	_tex.update(_img)


func _pixel(_layer: String, ix: int, iz: int, _stored: int) -> void:
	if _img != null:
		_img.set_pixel(ix, iz, _area_color(iz * n + ix))


func _flush() -> void:
	if _tex != null:
		_tex.update(_img)
