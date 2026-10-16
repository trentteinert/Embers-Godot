@tool
class_name EmbersPoint
extends Marker3D
## A place the server needs to know about. Pick the kind, put it where it belongs. Shows a coloured label in
## the editor. For NPCs and Elite lairs, `id` is the character (see the list in the README).

enum Kind { SPAWN, SHRINE, CAMP, VILLAGE, FORGE, FURNACE, ANVIL, SLAYER, MERCHANT, NPC, ELITE_LAIR, CAMPFIRE, FISHING_SPOT, RESOURCE_SPOT, BANK }

@export var kind: Kind = Kind.SPAWN: set = _set_kind
## NPC / Elite lair: the character id ("tam", "king", "rowan", ...). Resource spot: the material
## ("twig", "oak", "copper", ...). Merchant: 1, 2 or 3 (1 is the main shop). Bank: "banker" (a person) or "bank_chest" (a chest).
@export var id := "": set = _set_id
## Fishing spot only: the area of water (0 Meadow, 1 Thornwood, 2 Mire, 3 Frostspine, 4 Coast).
@export_range(0, 4) var water_biome := 0

## The bosses with a lair of their own; every other known character is an NPC.
const ELITES := ["alpha", "barrowking", "champion"]
const NAMES := ["Spawn", "Shrine", "Camp", "Village", "Forge", "Furnace", "Anvil", "Slayer", "Merchant", "NPC", "Elite lair", "Campfire", "Fishing spot", "Resource", "Bank"]
const COLORS := [Color("ffd27a"), Color("c8a8ff"), Color("ff9a4a"), Color("8ad07a"), Color("e0703a"), Color("e0703a"), Color("e0703a"), Color("e8506a"), Color("f2c27a"), Color("7ac8ff"), Color("ff4a4a"), Color("ff9a4a"), Color("5ab0ff"), Color("b0b0b8"), Color("f2c27a")]
## Drop onto the terrain whenever you move it in the editor.
@export var stick_to_ground := true
@export_tool_button("Snap to ground") var _snap_button: Callable = snap_to_ground

var _snapping := false


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


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and Engine.is_editor_hint() and stick_to_ground and kind != Kind.FISHING_SPOT and not _snapping and is_inside_tree():
		snap_to_ground()


var _label: Label3D
var _shape: Node3D
var _shape_key := ""


func _set_kind(v: Kind) -> void:
	kind = v
	if not ids_for(int(v)).is_empty() and not ids_for(int(v)).has(id):
		id = ids_for(int(v))[0]   # a character of the new kind, never a stale id from the old one
	notify_property_list_changed()
	_refresh()


## The ids that make sense for a kind, shown as a drop-down in the Inspector (empty = free text).
static func ids_for(k: int) -> Array:
	var known: Dictionary = {}
	var f := FileAccess.open("res://addons/embers_world/known.json", FileAccess.READ)
	if f != null:
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			known = parsed
	match k:
		Kind.NPC:
			var out: Array = []
			for n: Variant in known.get("npcs", []):
				if not ELITES.has(str(n)):
					out.append(str(n))
			return out
		Kind.ELITE_LAIR:
			return ELITES
		Kind.MERCHANT:
			return ["1", "2", "3"]
		Kind.BANK:
			return ["banker", "bank_chest"]
		Kind.RESOURCE_SPOT:
			return known.get("materials", [])
	return []


func _validate_property(p: Dictionary) -> void:
	if p.name == "id":
		var list := ids_for(int(kind))
		if not list.is_empty():
			p.hint = PROPERTY_HINT_ENUM
			p.hint_string = ",".join(PackedStringArray(list))
		else:
			p.usage = PROPERTY_USAGE_NO_EDITOR | PROPERTY_USAGE_STORAGE   # this kind of point has no id: hide it


func _set_id(v: String) -> void:
	id = v
	_refresh()


func _ready() -> void:
	if Engine.is_editor_hint():
		set_notify_transform(true)
	_refresh()


## A duplicated marker (Ctrl+D, copy and paste) arrives with a copy of the original's character and label as children this script does
## not know about, so changing its character left the old one standing there. Remove those strays.
func _clear_strays() -> void:
	for c: Node in get_children():
		if c != _shape and c != _label and (c.name.begins_with("_shape") or c.name.begins_with("_label")):
			remove_child(c)
			c.queue_free()


func _refresh() -> void:
	if not is_inside_tree():
		return
	_clear_strays()
	if _label == null and Engine.is_editor_hint():
		_label = Label3D.new()
		_label.name = "_label"
		_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_label.no_depth_test = true
		_label.pixel_size = 0.02
		_label.font_size = 48
		_label.outline_size = 12
		_label.position.y = 2.0
		add_child(_label)   # no owner: never saved
	var k := int(kind)
	var key := "%d:%s" % [k, id]
	if _shape == null or key != _shape_key:
		if _shape != null:
			_shape.queue_free()
		_shape_key = key
		_shape = _make_shape(k)
		_shape.name = "_shape"
		add_child(_shape)   # no owner: never saved, never in the game
	if _label != null:
		var nm: String = NAMES[int(kind)]
		_label.text = nm if id == "" else "%s: %s" % [nm, id]
		_label.modulate = COLORS[int(kind)]


## The game's own character where there is one, else a simple coloured shape.
func _make_shape(k: int) -> Node3D:
	var sprite := ""
	if k == Kind.NPC:
		sprite = str(_sprites().get(id, ""))
	elif k == Kind.MERCHANT:
		sprite = "hermit" if id == "3" else "merchant"
	elif k == Kind.SLAYER:
		sprite = "slayer"
	elif k == Kind.FORGE:
		sprite = "smith"
	elif k == Kind.BANK and id != "bank_chest":
		sprite = "merchant"
	if sprite != "":
		var m := EmbersProp.make(EmbersProp.Category.NPC, sprite)
		if m != null:
			# solid like in the game: a small capsule on layer 2 (the server makes people solid too)
			var holder := Node3D.new()
			holder.add_child(m)
			var body := StaticBody3D.new()
			body.collision_layer = 2
			var cs := CollisionShape3D.new()
			var cap := CapsuleShape3D.new()
			cap.radius = 0.35
			cap.height = 1.6
			cs.shape = cap
			cs.position.y = 0.8
			body.add_child(cs)
			holder.add_child(body)
			return holder
	if k == Kind.BANK:
		return _chest_shape()
	var mi := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = COLORS[k]
	mi.material_override = mat
	if k in [Kind.NPC, Kind.ELITE_LAIR, Kind.MERCHANT, Kind.SLAYER]:
		var c := CapsuleMesh.new()
		c.radius = 0.35
		c.height = 1.8
		mi.mesh = c
		mi.position.y = 0.9
	elif k in [Kind.CAMPFIRE, Kind.SHRINE]:
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 0.5
		cm.height = 1.0
		mi.mesh = cm
		mi.position.y = 0.5
	elif k == Kind.FISHING_SPOT:
		var tm := TorusMesh.new()
		tm.inner_radius = 0.6
		tm.outer_radius = 0.8
		mi.mesh = tm
		mi.position.y = 0.05
	else:
		var b := BoxMesh.new()
		b.size = Vector3(0.8, 0.8, 0.8) if k != Kind.RESOURCE_SPOT else Vector3(0.5, 0.5, 0.5)
		mi.mesh = b
		mi.position.y = 0.4
	return mi


## The bank chest, as it looks in the game.
func _chest_shape() -> Node3D:
	var root := Node3D.new()
	var wood := Color("7a5230")
	var trim := Color("d8b04a")
	for part: Array in [[Vector3(1.1, 0.6, 0.7), Vector3(0, 0.3, 0), wood], [Vector3(1.14, 0.22, 0.74), Vector3(0, 0.71, 0), wood.darkened(0.15)], [Vector3(0.16, 0.34, 0.06), Vector3(0, 0.55, 0.37), trim], [Vector3(1.16, 0.08, 0.76), Vector3(0, 0.5, 0), trim.darkened(0.2)]]:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = part[0]
		mi.mesh = bm
		mi.position = part[1]
		var mat := StandardMaterial3D.new()
		mat.albedo_color = part[2]
		mat.roughness = 1.0
		mi.material_override = mat
		root.add_child(mi)
	return root


func _sprites() -> Dictionary:
	var f := FileAccess.open("res://addons/embers_world/known.json", FileAccess.READ)
	if f == null:
		return {}
	var d: Variant = JSON.parse_string(f.get_as_text())
	return (d as Dictionary).get("sprites", {}) if d is Dictionary else {}
