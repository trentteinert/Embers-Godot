@tool
class_name EmbersFacetGround
extends RefCounted
## A flat-colour, low-detail copy of your ground, built exactly the way the game builds it: a grid of 2 m squares, each cut
## into two triangles, every triangle ONE flat colour. It reads the same ground the export writes (your sculpted heights, the
## painted biomes and ground, regions, paths, water), so what you see is what the game will show. No Terrain3D textures,
## texture slots, low-poly step or tint are needed for it.

const NODE_NAME := "EmbersFacetGround"
const BLOCK := 48   # cells per mesh block (so the editor can hide far blocks)
const GROUND_COL := [["3b6470", "3e6874"], ["c9b27a", "cfb880"], ["5f9a46", "649f4a"], ["2f5a34", "325e37"], ["4b4a33", "4f4e36"], ["2e3d34", "304036"], ["c4d0dc", "bdc9d6"], ["6f7480", "767b86"]]
const PATH_COL := ["8a7350", "6e5a3c", "5e553c", "b4c0ca", "bfa874"]
## The specks are drawn by this shader as small dots (0.25 m, like the game's 8 px per 2 m cell) on top of each face's one flat
## colour. The face colour is in COLOR.rgb; COLOR.a carries the ground (0 water ... 7 rock, 8 path) so dots suit the ground.
const SHADER := """
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
uniform sampler2D area_tex : filter_nearest, repeat_disable;
uniform vec4 area_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform float show_area = 0.0;
varying vec3 wp;
varying vec4 vc;
float h21(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
vec3 lin(vec3 c) { return pow(c, vec3(2.2)); }
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; vc = COLOR; }
void fragment() {
	vec3 base = lin(vc.rgb);
	int g = int(vc.a * 10.0 + 0.5);
	vec2 t = floor(wp.xz * 4.0);
	float r = h21(t);
	if (r < 0.094) {
		float k = h21(t + vec2(31.7, 11.3));
		vec3 d = base;
		if (g == 8) { d = k < 0.6 ? base * 0.8 : min(base * 1.12, vec3(1.0)); }
		else if (g == 2) { d = k < 0.05 ? (k < 0.025 ? lin(vec3(0.95, 0.82, 0.42)) : lin(vec3(0.91, 0.54, 0.65))) : (k > 0.7 ? lin(vec3(0.30, 0.54, 0.24)) : lin(vec3(0.51, 0.76, 0.37))); }
		else if (g == 3) { d = k < 0.2 ? lin(vec3(0.42, 0.35, 0.16)) : lin(vec3(0.14, 0.27, 0.16)); }
		else if (g == 4) { d = lin(vec3(0.23, 0.23, 0.16)); }
		else if (g == 5) { d = lin(vec3(0.27, 0.38, 0.31)); }
		else if (g == 6) { d = k < 0.3 ? lin(vec3(0.89, 0.93, 0.95)) : lin(vec3(0.65, 0.71, 0.77)); }
		else if (g == 1) { d = lin(vec3(0.70, 0.61, 0.38)); }
		else if (g == 7) { d = k < 0.4 ? lin(vec3(0.60, 0.63, 0.67)) : lin(vec3(0.31, 0.33, 0.37)); }
		else { d = lin(vec3(0.29, 0.48, 0.53)); }
		base = mix(base, d, 1.0 - smoothstep(30.0, 70.0, length(VERTEX)));   // far away the dots would shimmer: fade to the face colour
	}
	if (show_area > 0.5) {   // while painting: the colours you painted, solid, on top
		vec2 uv = (wp.xz - area_rect.xy) / area_rect.zw;
		if (uv.x >= 0.0 && uv.y >= 0.0 && uv.x <= 1.0 && uv.y <= 1.0) {
			vec4 a = texture(area_tex, uv);
			base = mix(base, lin(a.rgb), min(a.a * 1.7, 0.85));
		}
	}
	ALBEDO = base;
	ROUGHNESS = 1.0;
	SPECULAR = 0.15;
}
"""


static func _hash(x: int, z: int, k: int) -> float:
	var h := (x * 73856093) ^ (z * 19349663) ^ (k * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	return float((h ^ (h >> 16)) & 0xFFFF) / 65535.0


## The same smooth biome borders as the game: the weighted average of the land cells around this one.
static func _smooth(ground: PackedByteArray, n: int, x: int, z: int, g: int, base: Color, r: int) -> Color:
	if g < 2 or g > 6 or g == 7:
		return base
	var acc := Vector3.ZERO
	var wsum := 0.0
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var cx := x + dx
			var cz := z + dz
			if cx < 0 or cz < 0 or cx >= n or cz >= n:
				continue
			var d := Vector2(dx, dz).length()
			if d > r:
				continue
			var gg: int = ground[cz * n + cx]
			if gg < 2 or gg > 6:
				continue
			var wgt := 1.0 - d / (r + 1.0)
			var c := Color(GROUND_COL[gg][(cx + cz) % 2])
			acc += Vector3(c.r, c.g, c.b) * wgt
			wsum += wgt
	if wsum <= 0.0:
		return base
	return Color(acc.x / wsum, acc.y / wsum, acc.z / wsum)


## Smooth path edges: how much of a cell is path colour, from a soft blur of the path mask (radius r cells). Empty when r is 0.
static func _path_coverage(path: PackedByteArray, ground: PackedByteArray, n: int, r: int) -> Dictionary:
	var out := {}
	if r <= 0:
		return out
	var kernel: Array = []   # [dx, dz, weight]
	var total := 0.0
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var d := Vector2(dx, dz).length()
			if d > r:
				continue
			var wgt := 1.0 - d / (r + 1.0)
			kernel.append([dx, dz, wgt])
			total += wgt
	for z in n:
		for x in n:
			var i := z * n + x
			if path[i] == 0 or ground[i] == 0:
				continue
			for k: Array in kernel:
				var cx: int = x + int(k[0])
				var cz: int = z + int(k[1])
				if cx < 0 or cz < 0 or cx >= n or cz >= n:
					continue
				var j := cz * n + cx
				out[j] = float(out.get(j, 0.0)) + float(k[2])
	for j: int in out.keys():
		out[j] = minf(1.0, float(out[j]) / total * 2.2)
	for z in n:
		for x in n:
			var i2 := z * n + x
			if path[i2] != 0 and ground[i2] != 0 and out.has(i2):
				out[i2] = maxf(float(out[i2]), 0.75)   # a path cell stays clearly path
	return out


## Build (or rebuild) the preview under `root`. Returns a message for the person.
static func build(root: Node) -> String:
	var snap := EmbersExporter.ground_snapshot(root)
	if snap.has("errors") or snap.is_empty():
		return "Could not read the ground: " + "; ".join(snap.get("errors", ["no ground"]))
	remove(root)
	var made := make_holder(snap)
	var holder: Node3D = made["holder"]
	root.add_child(holder)   # no owner: a preview that is rebuilt on demand, never saved into your scene
	for pn: Node in root.find_children("*", "EmbersBiomePaint", true, false):
		(pn as EmbersBiomePaint).set_active((pn as EmbersBiomePaint)._active)   # hands it the new ground
	for t3: Node in root.find_children("*", "Terrain3D", true, false):
		(t3 as Node3D).visible = false
		t3.set_meta("embers_hidden", true)   # saved with the scene, so a reopened scene knows the preview is gone
	return "Built the faceted ground: %d flat faces in %d blocks. Terrain3D is hidden so you see only this (select the Terrain3D node and tick Visible, or run 'Remove faceted ground', to bring it back for sculpting). It is not saved with the scene: rebuild it after sculpting or painting." % [made["faces"], made["blocks"]]


## The ground meshes for a snapshot {n, half, cell, water_y, heights, ground, biome, path, smooth}: a Node3D with one MeshInstance3D per
## block. Used by the editor preview and by the game itself (custom worlds), so both show the same thing.
static func make_holder(snap: Dictionary) -> Dictionary:
	var n: int = snap["n"]
	var half: float = snap["half"]
	var cell: float = snap["cell"]
	var water_y: float = snap["water_y"]
	var sea := water_y - 3.0   # what the export writes where there is no terrain
	var heights: PackedFloat32Array = snap["heights"]
	var ground: PackedByteArray = snap["ground"]
	var biome: PackedByteArray = snap["biome"]
	var path: PackedByteArray = snap["path"]
	var smooth: int = snap.get("smooth", 0)
	var cov := _path_coverage(path, ground, n, int(snap.get("smooth_path", 0)))   # cell -> how much path colour a cell gets (smooth edges); empty = hard edges
	var w := n + 1
	var holder := Node3D.new()
	holder.name = NODE_NAME
	var sh := Shader.new()
	sh.code = SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	var shade := FastNoiseLite.new()
	shade.frequency = 0.07
	var faces := 0
	var blocks := 0
	for by in range(0, n, BLOCK):
		for bx in range(0, n, BLOCK):
			var verts := PackedVector3Array()
			var norms := PackedVector3Array()
			var cols := PackedColorArray()
			for z in range(by, mini(by + BLOCK, n)):
				for x in range(bx, mini(bx + BLOCK, n)):
					var h00 := heights[z * w + x]
					var h10 := heights[z * w + x + 1]
					var h01 := heights[(z + 1) * w + x]
					var h11 := heights[(z + 1) * w + x + 1]
					if absf(h00 - sea) < 0.02 and absf(h10 - sea) < 0.02 and absf(h01 - sea) < 0.02 and absf(h11 - sea) < 0.02:
						continue   # open sea with no terrain at all (the export's empty-sea height): nothing to see. Sculpted sea floor, however deep, is drawn.
					var i := z * n + x
					var g: int = ground[i]
					var bio: int = clampi(biome[i], 0, 4)
					var on_path: bool = path[i] != 0 and g != 0
					var p00 := Vector3(-half + x * cell, h00, -half + z * cell)
					var p10 := Vector3(-half + (x + 1) * cell, h10, p00.z)
					var p01 := Vector3(p00.x, h01, -half + (z + 1) * cell)
					var p11 := Vector3(p10.x, h11, p01.z)
					# the game's triangles: (x,z) (x+1,z) (x,z+1) and (x+1,z) (x+1,z+1) (x,z+1)
					for t in 2:
						var a: Vector3 = p00 if t == 0 else p10
						var b: Vector3 = p10 if t == 0 else p11
						var c: Vector3 = p01
						var nrm := (c - a).cross(b - a).normalized()
						var gg := g   # the cell's ground as the export decides it (the original game's rules per biome)
						var col: Color
						var pc := 0.0
						if cov.is_empty():
							pc = 1.0 if on_path else 0.0
						elif g != 0 and cov.has(i):
							pc = float(cov[i])
						if pc >= 0.999:
							col = Color(PATH_COL[bio])
						else:
							col = Color(GROUND_COL[gg][(x + z + t) % 2])
							if smooth > 0:
								col = _smooth(ground, n, x, z, gg, col, smooth)
							if pc > 0.0:
								col = col.lerp(Color(PATH_COL[bio]), pc)
						var s := shade.get_noise_2d(x * 2 + t, z * 2) * 0.5 + (_hash(x, z, t + 5) - 0.5) * 0.1
						col = col.lightened(s * 0.1) if s > 0.0 else col.darkened(-s * 0.15)
						col.a = lerpf(gg / 10.0, 0.8, pc)
						verts.append(a)
						verts.append(b)
						verts.append(c)
						for k in 3:
							norms.append(nrm)
							cols.append(col)
						faces += 1
			if verts.is_empty():
				continue
			var arr := []
			arr.resize(Mesh.ARRAY_MAX)
			arr[Mesh.ARRAY_VERTEX] = verts
			arr[Mesh.ARRAY_NORMAL] = norms
			arr[Mesh.ARRAY_COLOR] = cols
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			var mi := MeshInstance3D.new()
			mi.name = "Block_%d_%d" % [bx / BLOCK, by / BLOCK]
			mi.mesh = mesh
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			holder.add_child(mi)
			blocks += 1
	holder.set_meta("mat", mat)
	return {"holder": holder, "faces": faces, "blocks": blocks}


## Remove the preview and show Terrain3D again.
static func remove(root: Node) -> String:
	var found := false
	for c: Node in root.find_children(NODE_NAME, "Node3D", true, false):
		c.get_parent().remove_child(c)
		c.queue_free()
		found = true
	for t3: Node in root.find_children("*", "Terrain3D", true, false):
		(t3 as Node3D).visible = true
		t3.remove_meta("embers_hidden")
	return "Faceted ground removed; Terrain3D is showing again." if found else "There was no faceted ground; Terrain3D is showing."
