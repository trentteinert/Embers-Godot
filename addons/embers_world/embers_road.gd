@tool
class_name EmbersRoad
extends Path3D
## A road or path. Cells along it count as road for the server: faster travel and the road look in the game's map.
## In the editor, select it and use the "Path" toolbar at the top of the 3D view: click on the terrain to add points,
## Shift+click to remove one, and "Paint path on terrain" to put the path texture on the ground. It doesn't make
## a road mesh; the path is a ground texture, like in the original game.

@export var width := 4.0: set = _set_width
## Rounds the corners (curved path through your points).
@export var smooth_curve := true: set = _set_smooth
## Which biome's path colours to use when it can't tell from the painted map (Meadow, Thornwood, Mire, Frostspine, Coast).
@export_enum("Auto", "Meadow", "Thornwood", "Mire", "Frostspine", "Coast") var path_style := 0

var _preview: MeshInstance3D


func _ready() -> void:
	if curve == null:
		curve = Curve3D.new()
	curve.bake_interval = 1.0
	if Engine.is_editor_hint():
		call_deferred("refresh")


func _set_width(v: float) -> void:
	width = maxf(v, 0.5)
	if is_inside_tree():
		refresh()


func _set_smooth(v: bool) -> void:
	smooth_curve = v
	if is_inside_tree():
		refresh()


## The points as world positions.
func get_points() -> PackedVector3Array:
	var out := PackedVector3Array()
	if curve == null:
		return out
	for i in curve.point_count:
		out.append(global_transform * curve.get_point_position(i))
	return out


## Replace all points (world positions).
func set_points(pts: PackedVector3Array) -> void:
	if curve == null:
		curve = Curve3D.new()
	curve.clear_points()
	for p in pts:
		curve.add_point(global_transform.affine_inverse() * p)
	refresh()


func add_point_world(p: Vector3) -> void:
	var pts := get_points()
	pts.append(p)
	set_points(pts)


## Remove the point nearest to p (if within 12 m).
func remove_nearest(p: Vector3) -> bool:
	var pts := get_points()
	var best := -1
	var bd := 12.0
	for i in pts.size():
		var d := Vector2(pts[i].x - p.x, pts[i].z - p.z).length()
		if d < bd:
			bd = d
			best = i
	if best < 0:
		return false
	pts.remove_at(best)
	set_points(pts)
	return true


## Put every point on the terrain.
func snap_points_to_ground() -> void:
	var root := EmbersGround.scene_of(self)
	if root == null:
		return
	var pts := get_points()
	for i in pts.size():
		var h := EmbersGround.height_at(root, pts[i].x, pts[i].z)
		if not is_nan(h):
			pts[i].y = h
	set_points(pts)


## Round corners (Catmull-Rom through the points) or leave them straight, then redraw the preview.
func refresh() -> void:
	if curve == null:
		return
	curve.bake_interval = 1.0
	var n := curve.point_count
	for i in n:
		if smooth_curve and n > 2:
			var prev := curve.get_point_position(maxi(i - 1, 0))
			var next := curve.get_point_position(mini(i + 1, n - 1))
			var t := (next - prev) / 6.0
			curve.set_point_in(i, -t)
			curve.set_point_out(i, t)
		else:
			curve.set_point_in(i, Vector3.ZERO)
			curve.set_point_out(i, Vector3.ZERO)
	_draw_preview()


## The path as a thin brown ribbon on the terrain while you edit (not saved, not in the game).
func _draw_preview() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	if _preview == null:
		_preview = MeshInstance3D.new()
		_preview.name = "_preview"
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(0.85, 0.65, 0.3, 0.55)
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_preview.material_override = m
		add_child(_preview)
	var pts := curve.get_baked_points() if curve != null and curve.point_count > 1 else PackedVector3Array()
	if pts.size() < 2:
		_preview.mesh = null
		return
	var root := EmbersGround.scene_of(self)
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var inv := global_transform.affine_inverse()
	for i in pts.size():
		var a := global_transform * pts[i]
		var b := global_transform * pts[mini(i + 1, pts.size() - 1)]
		var prev := global_transform * pts[maxi(i - 1, 0)]
		var d := Vector3(b.x - prev.x, 0, b.z - prev.z)
		if d.length() < 0.001:
			continue
		d = d.normalized()
		var side := Vector3(-d.z, 0, d.x) * width * 0.5
		for s in [-1.0, 1.0]:
			var q: Vector3 = a + side * s
			var h := EmbersGround.height_at(root, q.x, q.z) if root != null else NAN
			q.y = (h if not is_nan(h) else a.y) + 0.35
			im.surface_add_vertex(inv * q)
	im.surface_end()
	_preview.mesh = im
