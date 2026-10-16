@tool
class_name EmbersGround
extends RefCounted
## Finds the height of your terrain at a point, for "stick to ground". Works with a Terrain3D node, or any
## mesh in the group "embers_ground" (the same sources the exporter uses).


## Ground height at (x, z) in the scene `root` is in, or NAN if there is no ground there.
static func height_at(root: Node, x: float, z: float) -> float:
	var best := NAN
	var t := _find_terrain(root)
	if t != null and "data" in t and t.data != null:
		best = t.data.get_height(Vector3(x, 0, z))
	for mi: MeshInstance3D in _ground_meshes(root):
		var xf := mi.global_transform
		var box: AABB = xf * mi.mesh.get_aabb()
		if x < box.position.x or x > box.end.x or z < box.position.z or z > box.end.z:
			continue
		var tm: TriangleMesh = mi.mesh.generate_triangle_mesh()
		if tm == null:
			continue
		var inv := xf.affine_inverse()
		var from: Vector3 = inv * Vector3(x, box.end.y + 10.0, z)
		var to: Vector3 = inv * Vector3(x, box.position.y - 10.0, z)
		var hit := tm.intersect_ray(from, (to - from).normalized())
		if not hit.is_empty():
			var y: float = (xf * (hit["position"] as Vector3)).y
			if is_nan(best) or y > best:
				best = y
	return best


static func _find_terrain(n: Node) -> Node:
	if n.get_class() == "Terrain3D" or n.is_class("Terrain3D"):
		return n
	for c in n.get_children():
		if c is EmbersProp or c is EmbersPoint:
			continue
		var f := _find_terrain(c)
		if f != null:
			return f
	return null


static func _ground_meshes(n: Node) -> Array:
	var out: Array = []
	if n is MeshInstance3D and n.is_in_group("embers_ground") and (n as MeshInstance3D).mesh != null:
		out.append(n)
	for c in n.get_children():
		if c is EmbersProp or c is EmbersPoint:
			continue
		out.append_array(_ground_meshes(c))
	return out


## The scene a node belongs to (the edited scene in the editor, else the running scene).
static func scene_of(n: Node) -> Node:
	if Engine.is_editor_hint() and n.get_tree() != null and n.get_tree().edited_scene_root != null:
		return n.get_tree().edited_scene_root
	if n.get_tree() == null:
		return null
	return n.get_tree().current_scene if n.get_tree().current_scene != null else n.get_tree().root
