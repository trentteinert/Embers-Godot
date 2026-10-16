@tool
class_name Building
extends Node3D
## A walk-in building. While you are inside, its roof and ceiling disappear so you can see
## the room from the camera. Two-storey buildings also hide the upper floor while you are
## downstairs, and show it again once you climb up.

var rect := Rect2()     # the floor, in this node's local x/z
var roof: Node3D
var upper: Node3D
var floor_y := 0.0
var max_y := 4.5
static var inside_any := false   # the camera zooms in while the player is in any building
static var cam_exclude: Array[RID] = []   # wall bodies the camera ray ignores while you are in or at the door
var cam_extra: Array[StaticBody3D] = []   # furniture bodies of an editor build (they are separate nodes there)
var frozen := false                       # the build editor owns this building: no roof / upper-floor switching
var _near := false
var _inside := false
var _deep := false
var _up_vis := true


func _ready() -> void:
	add_to_group("tk_buildings")


func _bodies() -> Array[StaticBody3D]:
	var out: Array[StaticBody3D] = []
	for ch in get_children():
		if ch is StaticBody3D:
			out.append(ch as StaticBody3D)
	out.append_array(cam_extra)
	return out


func _exit_tree() -> void:
	for sb in _bodies():
		cam_exclude.erase(sb.get_rid())


func _process(_delta: float) -> void:
	if roof == null or frozen:
		return
	var pl := get_tree().get_first_node_in_group("player") as Node3D
	if pl == null:
		return
	var l := to_local(pl.global_position)
	var inside := rect.has_point(Vector2(l.x, l.z)) and l.y > -1.0 and l.y < max_y
	if inside != _inside:
		_inside = inside
	# standing in or at the doorway: the camera sails through this building's walls instead of shrinking in
	# enter at the doorway, but only let go once you are a few metres clear (so the roof and the camera do not snap back)
	var pad := 5.5 if _near else 1.8
	var near := rect.grow(pad).has_point(Vector2(l.x, l.z)) and l.y > -1.0 and l.y < max_y + 2.0
	if near != _near:
		_near = near
		roof.visible = not near   # the roof lifts as you reach the door, so you can see yourself
		for sb in _bodies():
			var rid := sb.get_rid()
			if near and not cam_exclude.has(rid):
				cam_exclude.append(rid)
			elif not near:
				cam_exclude.erase(rid)
	# the camera only eases in once you are well inside, not when you pass the doorway
	var deep := inside and rect.grow(0.3).has_point(Vector2(l.x, l.z))
	if deep != _deep:
		_deep = deep
		if deep:
			inside_any = true
		elif inside_any:
			inside_any = false
	if upper != null:
		var show_up := not (inside and l.y < floor_y - 0.4)
		if show_up != _up_vis:
			_up_vis = show_up
			upper.visible = show_up
