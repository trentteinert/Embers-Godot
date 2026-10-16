@tool
class_name EmbersExporter
extends RefCounted
## Reads the open scene and writes what the Embers server needs: the ground (heights, water, biomes, roads),
## the solid things (buildings, trees, rocks) and every EmbersPoint. Used by the editor menu and by the
## command line (export_cli.gd). Returns {ok, errors, warnings, stats}.
##
## Ground heights come from (first match wins per source, the highest surface counts):
##   - a Terrain3D node, if you use that addon
##   - any MeshInstance3D in the group "embers_ground" (a heightmap mesh, a Blender terrain, ...)
## Where there is no ground the world is deep sea, so an island is just terrain in the middle.
## Solid things: put a node in the group "embers_solid". Every CollisionShape3D inside it blocks the player;
## a plain mesh with no collision blocks as its bounding box. A wall on an upper floor only blocks people
## standing up there (each shape remembers its height).
## Things you can stand on (upper floors, stair ramps, bridge decks): put the node in the group "embers_walkable".
## Every BoxShape3D inside it becomes a walkable surface; a tilted box is a ramp.

const GROUND_GROUP := "embers_ground"
const SOLID_GROUP := "embers_solid"
const WALK_GROUP := "embers_walkable"

var errors: Array[String] = []
var warnings: Array[String] = []
var stats := {}

var _world: EmbersWorld
var _terrain3d: Object
var _meshes: Array = []        # {tm: TriangleMesh, xf: Transform3D, inv: Transform3D, box: AABB}
var _n := 0
var _cell := 2.0
var _half := 1200.0
var _circles: Array = []
var _boxes: Array = []
var _surfaces: Array = []
var _known: Dictionary = {}
## The ground arrays of the last run (for the faceted ground preview): n, half, cell, water_y, heights, ground, biome, path.
var snapshot := {}
var _bog: FastNoiseLite
var _ground_ref := PackedByteArray()
var _biome_ref := PackedByteArray()
var _heights_ref := PackedFloat32Array()
var _snow_noise: FastNoiseLite
var _dirt_cells := {}   # cell index -> true, painted with the Dirt patch
var _patch_cells := {}   # cell index -> the ground id painted there with a Dirt/Sand/Rock patch
var _explicit := PackedByteArray()   # 1 = this cell's ground was chosen by you (region or brush), so the biome's natural ground leaves it alone


## The ground of the scene exactly as the export would write it (heights, ground, biome, path), without writing anything.
## Returns {} with the problems in "errors" when there is no ground.
static func ground_snapshot(root: Node) -> Dictionary:
	var e := EmbersExporter.new()
	var r := e._run(root, "", false)
	if not r["ok"]:
		return {"errors": r["errors"]}
	return e.snapshot


static func run(root: Node, out_dir: String, write := true) -> Dictionary:
	var e := EmbersExporter.new()
	return e._run(root, out_dir, write)


func _fail(msg: String) -> void:
	errors.append(msg)


func _run(root: Node, out_dir: String, write: bool) -> Dictionary:
	var t0 := Time.get_ticks_msec()
	var kf := FileAccess.open("res://addons/embers_world/known.json", FileAccess.READ)
	if kf != null:
		_known = JSON.parse_string(kf.get_as_text())
	_world = _find_world(root)
	if _world == null:
		_fail("There is no EmbersWorld node in this scene. Add one (Add Node > EmbersWorld) at the top.")
		return _result()
	_cell = _world.cell_m
	_n = roundi(_world.size_m / _cell)
	if _world.pad_to_game_size and is_equal_approx(_cell, 2.0) and _n < 1200:
		_n = 1200   # the game is 2400 m wide: pad with open sea
	_half = _n * _cell * 0.5
	_collect_ground(root)
	if _meshes.is_empty() and _terrain3d == null:
		_fail("No ground found. Put your terrain mesh in the group \"embers_ground\" (Node tab > Groups), or use a Terrain3D node.")
		return _result()
	var points := _collect_points(root)
	_collect_solids(root)
	_collect_walkable(root)
	_collect_props(root)
	stats["walkable_surfaces"] = _surfaces.size()
	stats["solid_circles"] = _circles.size()
	stats["solid_boxes"] = _boxes.size()
	print("embers: sampling the ground (%d x %d) ..." % [_n + 1, _n + 1])
	var heights := PackedFloat32Array()
	heights.resize((_n + 1) * (_n + 1))
	var missing := 0
	for iz in _n + 1:
		for ix in _n + 1:
			var h := _height(-_half + ix * _cell, -_half + iz * _cell)
			if is_nan(h):
				h = _world.water_y - 3.0
				missing += 1
			heights[iz * (_n + 1) + ix] = h
	stats["sea_corners"] = missing
	var ground := PackedByteArray()
	var biome := PackedByteArray()
	var zone := PackedByteArray()
	var path := PackedByteArray()
	ground.resize(_n * _n)
	biome.resize(_n * _n)
	zone.resize(_n * _n)
	path.resize(_n * _n)
	biome.fill(_world.default_biome)
	zone.fill(255)
	var land := 0
	for iz in _n:
		for ix in _n:
			var h := (heights[iz * (_n + 1) + ix] + heights[iz * (_n + 1) + ix + 1] + heights[(iz + 1) * (_n + 1) + ix] + heights[(iz + 1) * (_n + 1) + ix + 1]) * 0.25
			var g := _world.default_ground
			if h < _world.water_y:
				g = 0
			elif h < _world.water_y + 0.45:
				g = 1
			else:
				land += 1
			ground[iz * _n + ix] = g
	stats["land_cells"] = land
	_explicit.resize(_n * _n)
	_explicit.fill(0)
	_paint_regions(root, ground, biome, zone, heights)
	_paint_maps(root, ground, biome, zone)
	_natural_ground(ground, biome, heights)
	_paint_roads(root, path)
	_soften_edges(ground, path, heights)
	snapshot = {"smooth": _blend_cells() if _world.smooth_biome_blend else 0, "n": _n, "half": _half, "cell": _cell, "water_y": _world.water_y, "heights": heights, "ground": ground, "biome": biome, "path": path, "smooth_path": _smooth_path_cells()}
	_ground_ref = ground
	_biome_ref = biome
	_heights_ref = heights
	var meta := _meta(points, heights)
	if write and errors.is_empty():
		_write(out_dir, heights, ground, biome, zone, path, meta)
		_write_clutter_mask(out_dir, points)
	stats["seconds"] = snappedf((Time.get_ticks_msec() - t0) / 1000.0, 0.1)
	return _result()


func _result() -> Dictionary:
	return {"ok": errors.is_empty(), "errors": errors, "warnings": warnings, "stats": stats}


func _find_world(n: Node) -> EmbersWorld:
	if n is EmbersWorld:
		return n
	for c in n.get_children():
		var f := _find_world(c)
		if f != null:
			return f
	return null


# ================================================================ ground
func _collect_ground(n: Node) -> void:
	if n.get_class() == "Terrain3D" or n.is_class("Terrain3D"):
		_terrain3d = n
	if n is MeshInstance3D and (n as Node).is_in_group(GROUND_GROUP):
		_add_mesh(n as MeshInstance3D)
	elif n.is_in_group(GROUND_GROUP):
		for m in n.find_children("*", "MeshInstance3D", true, false):
			_add_mesh(m as MeshInstance3D)
	for c in n.get_children():
		_collect_ground(c)


func _add_mesh(mi: MeshInstance3D) -> void:
	if mi.mesh == null:
		return
	var tm: TriangleMesh = mi.mesh.generate_triangle_mesh()
	if tm == null:
		return
	var xf := mi.global_transform
	_meshes.append({"tm": tm, "xf": xf, "inv": xf.affine_inverse(), "box": xf * mi.mesh.get_aabb()})


func _height(x: float, z: float) -> float:
	var best := NAN
	if _terrain3d != null:
		var h: float = _terrain3d.data.get_height(Vector3(x, 0, z))
		if not is_nan(h):
			best = h
	for m: Dictionary in _meshes:
		var box: AABB = m["box"]
		if x < box.position.x or x > box.end.x or z < box.position.z or z > box.end.z:
			continue
		var inv: Transform3D = m["inv"]
		var from: Vector3 = inv * Vector3(x, box.end.y + 10.0, z)
		var to: Vector3 = inv * Vector3(x, box.position.y - 10.0, z)
		var hit: Dictionary = (m["tm"] as TriangleMesh).intersect_ray(from, (to - from).normalized())
		if not hit.is_empty():
			var y: float = ((m["xf"] as Transform3D) * (hit["position"] as Vector3)).y
			if is_nan(best) or y > best:
				best = y
	return best


func _ground_y(x: float, z: float) -> float:
	var h := _height(x, z)
	return _world.water_y - 3.0 if is_nan(h) else h


# ================================================================ regions and roads
func _paint_regions(root: Node, ground: PackedByteArray, biome: PackedByteArray, zone: PackedByteArray, heights: PackedFloat32Array) -> void:
	var regions: Array = root.find_children("*", "EmbersRegion", true, false)
	regions.sort_custom(func(a: EmbersRegion, b: EmbersRegion) -> bool: return a.priority < b.priority)
	for r: EmbersRegion in regions:
		var rx: float = r.size.x * 0.5 * r.global_transform.basis.x.length()
		var rz: float = r.size.y * 0.5 * r.global_transform.basis.z.length()
		var reach := sqrt(rx * rx + rz * rz)
		var c := r.global_position
		var x0 := clampi(floori((c.x - reach + _half) / _cell), 0, _n - 1)
		var x1 := clampi(ceili((c.x + reach + _half) / _cell), 0, _n - 1)
		var z0 := clampi(floori((c.z - reach + _half) / _cell), 0, _n - 1)
		var z1 := clampi(ceili((c.z + reach + _half) / _cell), 0, _n - 1)
		for iz in range(z0, z1 + 1):
			for ix in range(x0, x1 + 1):
				if not r.covers(-_half + (ix + 0.5) * _cell, -_half + (iz + 0.5) * _cell):
					continue
				var i := iz * _n + ix
				biome[i] = r.biome
				if r.zone > 0:
					zone[i] = r.zone - 1
				if r.ground > 0 and ground[i] != 0:
					ground[i] = r.ground - 1
					_explicit[i] = 1
	stats["regions"] = regions.size()


## The brush-painted map (EmbersBiomePaint) wins over the region boxes.
func _paint_maps(root: Node, ground: PackedByteArray, biome: PackedByteArray, zone: PackedByteArray) -> void:
	var maps: Array = root.find_children("*", "EmbersBiomePaint", true, false)
	var painted := 0
	for m: EmbersBiomePaint in maps:
		if m.cells.is_empty():
			m._ready()
		for iz in _n:
			for ix in _n:
				var x := -_half + (ix + 0.5) * _cell
				var z := -_half + (iz + 0.5) * _cell
				var i := iz * _n + ix
				var b := m.value_at("biome", x, z)
				if b >= 0:
					biome[i] = b
					painted += 1
				var g := m.value_at("ground", x, z)
				if g == 8 and ground[i] != 0:
					_dirt_cells[i] = true   # a dirt patch: drawn exactly like a path (the path layer), natural ground underneath stays
				elif g > 0 and g < 8 and ground[i] != 0:
					ground[i] = g
					_explicit[i] = 1
					_patch_cells[i] = g
				var zn := m.value_at("zone", x, z)
				if zn >= 0:
					zone[i] = zn
	stats["painted_cells"] = painted


## The original game's ground for each biome, wherever you did not choose a ground yourself: Meadow is grass, Thornwood forest,
## Mire mud with patches of bog, Frostspine snow, Coast sand; high ground (above the snow line, 7 m by default) in Thornwood and Mire turns to snow, and steep
## cells turn to rock. Land touching water gets a strip of sand (Meadow, Thornwood and Mire); water stays water.
func _natural_ground(ground: PackedByteArray, biome: PackedByteArray, heights: PackedFloat32Array) -> void:
	_bog = FastNoiseLite.new()
	_bog.seed = 53
	_bog.frequency = 0.16
	_bog.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_bog.fractal_type = FastNoiseLite.FRACTAL_FBM
	_bog.fractal_octaves = 3
	_snow_noise = FastNoiseLite.new()
	_snow_noise.seed = 91
	_snow_noise.frequency = 0.3
	_snow_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	var changed := 0
	for iz in _n:
		for ix in _n:
			var i := iz * _n + ix
			if _explicit[i] == 1 or ground[i] == 0 or ground[i] == 1:
				continue   # chosen by you, water, or shore sand
			var g := _natural_cell(int(biome[i]), ix, iz, heights, ground)
			if g != ground[i]:
				ground[i] = g
				changed += 1
	stats["natural_ground_cells"] = changed
	var r := _blend_cells()
	if r > 0 and not _world.smooth_biome_blend:
		stats["blended_cells"] = _dither_biomes(ground, biome, heights, r)


## The natural ground of one cell if it were in biome `b`.
func _natural_cell(b: int, ix: int, iz: int, heights: PackedFloat32Array, ground: PackedByteArray) -> int:
	var w := _n + 1
	var h00 := heights[iz * w + ix]
	var h10 := heights[iz * w + ix + 1]
	var h01 := heights[(iz + 1) * w + ix]
	var h11 := heights[(iz + 1) * w + ix + 1]
	var up := (h00 + h10 + h01 + h11) * 0.25 - _world.water_y
	var slope := maxf(maxf(h00, h10), maxf(h01, h11)) - minf(minf(h00, h10), minf(h01, h11))
	var g := 2
	if b == 4:
		g = 1
	elif b <= 2 and slope < 1.4 and _next_to_water(ground, ix, iz):
		g = 1   # a strip of sand along the water's edge (rivers, lakes and the sea), as in the original
	elif ((b == 0 and _world.snow_in_meadow) or (b == 1 and _world.snow_in_thornwood) or (b == 2 and _world.snow_in_mire)) and _snowy(up, ix, iz, _snow_noise):
		g = 7 if (slope > 1.6 and _world.rocky_slopes) else 6
	elif b == 3:
		g = 7 if (slope > 1.7 and _world.rocky_slopes) else (6 if _world.snow_in_frostspine else 2)
	elif slope > 2.2 and _world.rocky_slopes:
		g = 7
	elif b == 1:
		g = 3
	elif b == 2:
		g = 5 if _bog.get_noise_2d(ix + 0.5, iz + 0.5) > 0.15 else 4
	return g


## Half the biome blend width in cells (0 = no blending).
func _blend_cells() -> int:
	if _world.biome_blend_m <= 0.01:
		return 0
	return maxi(1, ceili(_world.biome_blend_m / _cell * 0.5))


## Patchy biome borders: next to a border, a growing share of cells (in patches) takes the neighbour biome's ground. Every cell
## stays one ground. Coast, water, sand, rock and anything you painted yourself are left alone. Returns how many cells changed.
func _dither_biomes(ground: PackedByteArray, biome: PackedByteArray, heights: PackedFloat32Array, r: int) -> int:
	var near := {}   # cell index -> [distance in cells, the other biome]
	for iz in _n:
		for ix in _n:
			var i := iz * _n + ix
			var b: int = biome[i]
			if b > 3:
				continue
			var other := -1
			for off: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
				var x2 := ix + off.x
				var z2 := iz + off.y
				if x2 < _n and z2 < _n:
					var nb: int = biome[z2 * _n + x2]
					if nb != b and nb <= 3:
						other = nb
						# the neighbouring cell is across the border too: it fades into this biome
						_mark_near(near, biome, ix, iz, r, b, nb)
						_mark_near(near, biome, x2, z2, r, nb, b)
	var done := 0
	for i: int in near.keys():
		var rec: Array = near[i]
		var g0: int = ground[i]
		if _explicit[i] == 1 or g0 < 2 or g0 > 6:
			continue
		var ix2 := i % _n
		var iz2 := i / _n
		var chance := 0.5 * (1.0 - float(rec[0]) / float(r + 1))
		var rnd := (_snow_noise.get_noise_2d(ix2 + 500, iz2 + 500) + 1.0) * 0.5 * 0.7 + fposmod(sin(ix2 * 12.9898 + iz2 * 78.233) * 43758.5453, 1.0) * 0.3
		if rnd < chance:
			var g := _natural_cell(int(rec[1]), ix2, iz2, heights, ground)
			if g >= 2 and g <= 6 and g != g0:
				ground[i] = g
				done += 1
	return done


## Blend the edge of every path and every patch into the ground around it, the same way two biomes blend where they meet: along the
## border the cells on BOTH sides take a little of the other side, with a chance that falls with the distance from the border,
## so you get a mixed band instead of a hard line. (A path edge is eroded less than it grows, so a thin path stays whole.)
## With Smooth Biome Blend on, path edges blend as a colour gradient (drawn by the ground); the cell-scatter below is for the patchy mode.
func _smooth_path_cells() -> int:
	return ceili(_world.path_blend_m / _cell + 0.01) if _world.smooth_biome_blend and _world.path_blend_m > 0.0 else 0


func _soften_edges(ground: PackedByteArray, path: PackedByteArray, heights: PackedFloat32Array) -> void:
	var smooth_paths := _smooth_path_cells() > 0   # then the path layer stays a clean mask and the ground draws the gradient
	var r := ceili(_world.path_blend_m / _cell + 0.01) if _world.path_blend_m > 0.0 else 0
	if r <= 0:
		return
	var out_d := {}   # non-path cell -> distance to the nearest path cell
	var in_d := {}    # path cell -> distance to the nearest border path cell (0 = on the border)
	var ground_new := {}
	for iz in _n:
		for ix in _n:
			var i := iz * _n + ix
			var pg: int = int(_patch_cells.get(i, 0))
			var is_path: bool = path[i] != 0
			if not is_path and pg == 0:
				continue
			var border := false
			if is_path:
				for off: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var x2 := ix + off.x
					var z2 := iz + off.y
					if x2 >= 0 and z2 >= 0 and x2 < _n and z2 < _n and path[z2 * _n + x2] == 0 and ground[z2 * _n + x2] != 0:
						border = true
						break
				if not border:
					continue
			for dz in range(-r, r + 1):
				for dx in range(-r, r + 1):
					var x := ix + dx
					var z := iz + dz
					if x < 0 or z < 0 or x >= _n or z >= _n:
						continue
					var d := Vector2(dx, dz).length()
					if d > r:
						continue
					var j := z * _n + x
					if ground[j] == 0:
						continue
					if is_path:
						if path[j] != 0:
							if not in_d.has(j) or float(in_d[j]) > d:
								in_d[j] = d
						elif not _patch_cells.has(j):
							if not out_d.has(j) or float(out_d[j]) > d:
								out_d[j] = d
					elif d >= 0.5 and path[j] == 0 and not _patch_cells.has(j) and ground[j] != 1:
						var chance_p := 0.85 * (1.0 - (d - 0.5) / float(r + 0.5))
						if _edge_rnd(x, z) < chance_p:
							ground_new[j] = pg
	var grow := {}
	var shrink := {}
	for j: int in out_d.keys():
		var d1: float = out_d[j]
		if _edge_rnd(j % _n, j / _n) < 0.85 * (1.0 - (d1 - 0.5) / float(r + 0.5)):
			grow[j] = true
	for j: int in in_d.keys():
		var d2: float = in_d[j]
		if _edge_rnd(j % _n + 333, j / _n + 333) < 0.35 * (1.0 - d2 / float(r)):
			shrink[j] = true
	if smooth_paths:
		grow.clear()
		shrink.clear()
	for j: int in grow.keys():
		path[j] = 1
	for j: int in shrink.keys():
		path[j] = 0
	for j: int in ground_new.keys():
		ground[j] = int(ground_new[j])
	stats["edge_cells_softened"] = grow.size() + shrink.size() + ground_new.size()


func _edge_rnd(x: int, z: int) -> float:
	return (_snow_noise.get_noise_2d(x + 900, z + 900) + 1.0) * 0.5 * 0.6 + fposmod(sin(x * 12.9898 + z * 78.233) * 43758.5453, 1.0) * 0.4


func _mark_near(near: Dictionary, biome: PackedByteArray, cx: int, cz: int, r: int, own: int, other: int) -> void:
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var x := cx + dx
			var z := cz + dz
			if x < 0 or z < 0 or x >= _n or z >= _n:
				continue
			var d := Vector2(dx, dz).length()
			if d > r or biome[z * _n + x] != own:
				continue
			var i := z * _n + x
			if not near.has(i) or float((near[i] as Array)[0]) > d:
				near[i] = [d, other]


## Snow above the snow line, fading in: at the line none, `snow_fade_m` metres higher all of it; in between a growing share of
## the cells (in patches, from noise) is snow. A fade of 0 is a hard line.
func _snowy(up: float, ix: int, iz: int, noise: FastNoiseLite) -> bool:
	if up <= _world.snow_line_m:
		return false
	if _world.snow_fade_m <= 0.01:
		return true
	var chance := (up - _world.snow_line_m) / _world.snow_fade_m
	if chance >= 1.0:
		return true
	var r := (noise.get_noise_2d(ix, iz) + 1.0) * 0.5 * 0.7 + fposmod(sin(ix * 12.9898 + iz * 78.233) * 43758.5453, 1.0) * 0.3
	return r < chance


## True if one of the 8 cells around (ix, iz) is water.
func _next_to_water(ground: PackedByteArray, ix: int, iz: int) -> bool:
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var x := ix + dx
			var z := iz + dz
			if x < 0 or z < 0 or x >= _n or z >= _n:
				continue
			if ground[z * _n + x] == 0:
				return true
	return false


func _paint_roads(root: Node, path: PackedByteArray) -> void:
	var roads: Array = root.find_children("*", "EmbersRoad", true, false)
	for r: EmbersRoad in roads:
		if r.curve == null:
			continue
		var rad: float = maxf(r.width * 0.5, _cell * 0.5)
		for p: Vector3 in r.curve.get_baked_points():
			var g: Vector3 = r.global_transform * p
			var x0 := clampi(floori((g.x - rad + _half) / _cell), 0, _n - 1)
			var x1 := clampi(floori((g.x + rad + _half) / _cell), 0, _n - 1)
			var z0 := clampi(floori((g.z - rad + _half) / _cell), 0, _n - 1)
			var z1 := clampi(floori((g.z + rad + _half) / _cell), 0, _n - 1)
			for iz in range(z0, z1 + 1):
				for ix in range(x0, x1 + 1):
					var cx := -_half + (ix + 0.5) * _cell
					var cz := -_half + (iz + 0.5) * _cell
					if Vector2(cx - g.x, cz - g.z).length() <= maxf(rad, _cell * 0.75):   # cells whose middle is inside the path: no wider than the path
						path[iz * _n + ix] = 1
	for di: int in _dirt_cells.keys():
		path[di] = 1
	stats["roads"] = roads.size()


# ================================================================ solids
func _collect_solids(n: Node) -> void:
	if n.is_in_group(SOLID_GROUP):
		var shapes := n.find_children("*", "CollisionShape3D", true, false)
		if n is CollisionShape3D:
			shapes.append(n)
		if shapes.is_empty():
			if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
				_box_from_aabb(n as MeshInstance3D)
			else:
				for m in n.find_children("*", "MeshInstance3D", true, false):
					_box_from_aabb(m as MeshInstance3D)
		for cs: CollisionShape3D in shapes:
			_shape(cs)
		return   # everything below was handled
	for c in n.get_children():
		_collect_solids(c)


## The game's own buildings and trees (EmbersProp): same rules as the game's exporter. Floors, upper floors and stair
## ramps become walkable surfaces; walls, furniture and trunks become solids with their height range.
func _collect_props(n: Node) -> void:
	if n is EmbersProp:
		var pr := n as EmbersProp
		if pr.category == EmbersProp.Category.SCENERY:
			var r := pr.solid_radius()
			if r > 0.0:
				var sc := maxf(pr.global_transform.basis.x.length(), pr.global_transform.basis.z.length())
				_circles.append([pr.global_position.x, pr.global_position.z, r * sc, pr.global_position.y, pr.global_position.y + 3.0 * sc])
		elif pr.category in [EmbersProp.Category.BUILDING, EmbersProp.Category.FARM, EmbersProp.Category.HOUSE]:
			for cs: CollisionShape3D in pr.find_children("*", "CollisionShape3D", true, false):
				if _in_door(cs):
					continue
				var body := cs.get_parent()
				if body is StaticBody3D and ((body as StaticBody3D).collision_layer & 2) != 0:
					_game_shape(cs, body as StaticBody3D)
		return
	for c in n.get_children():
		_collect_props(c)


func _in_door(n: Node) -> bool:
	var p: Node = n
	while p != null:
		var sc: Script = p.get_script()
		if sc != null and sc.get_global_name() == "Door":
			return true
		p = p.get_parent()
	return false


func _game_shape(cs: CollisionShape3D, body: StaticBody3D) -> void:
	if cs.disabled or cs.shape == null:
		return
	var xf := cs.global_transform
	var pos := xf.origin
	var sh := cs.shape
	if sh is CylinderShape3D:
		var cy := sh as CylinderShape3D
		var ch := cy.height * xf.basis.y.length()
		_circles.append([pos.x, pos.z, cy.radius * maxf(xf.basis.x.length(), xf.basis.z.length()), pos.y - ch * 0.5, pos.y + ch * 0.5])
	elif sh is BoxShape3D:
		var bx := sh as BoxShape3D
		var half := Vector3(bx.size.x * xf.basis.x.length(), bx.size.y * xf.basis.y.length(), bx.size.z * xf.basis.z.length()) * 0.5
		var ny := xf.basis.y.normalized().y
		var thick := half.y * 2.0
		var wide := minf(half.x, half.z) * 2.0
		var layer2_only := (body.collision_layer & 16) == 0
		if ny < 0.9:
			if layer2_only and ny >= 0.6:
				_surface(xf, bx.size * 0.5)
			return
		if thick <= 0.5 and ((layer2_only and wide >= 0.9) or (wide >= 1.2 and half.x * half.z * 4.0 >= 3.5)):
			_surface(xf, bx.size * 0.5)
			return
		if thick < 0.9:
			return
		if pos.y + half.y < _ground_y(pos.x, pos.z) + 0.5:
			return
		_add_box(pos, xf.basis, bx.size * 0.5)
	else:
		var dm: ArrayMesh = sh.get_debug_mesh()
		if dm != null:
			var a := dm.get_aabb()
			if a.size.y >= 0.9:
				_add_box(xf * a.get_center(), xf.basis, a.size * 0.5)


func _box_from_aabb(mi: MeshInstance3D) -> void:
	if mi.mesh == null:
		return
	var xf := mi.global_transform
	var a := mi.mesh.get_aabb()
	_add_box(xf * a.get_center(), xf.basis, a.size * 0.5)


func _collect_walkable(n: Node) -> void:
	if n.is_in_group(WALK_GROUP):
		var shapes := n.find_children("*", "CollisionShape3D", true, false)
		if n is CollisionShape3D:
			shapes.append(n)
		for cs: CollisionShape3D in shapes:
			if cs.shape is BoxShape3D and not cs.disabled:
				_surface(cs.global_transform, (cs.shape as BoxShape3D).size * 0.5)
		if shapes.is_empty():
			for m in ([n] if n is MeshInstance3D else n.find_children("*", "MeshInstance3D", true, false)):
				var mi := m as MeshInstance3D
				if mi.mesh != null:
					_surface(Transform3D(mi.global_transform.basis, mi.global_transform * mi.mesh.get_aabb().get_center()), mi.mesh.get_aabb().size * 0.5)
		return
	for c in n.get_children():
		_collect_walkable(c)


## The top face of a box as a surface: footprint plus the plane (tilted boxes are ramps).
func _surface(xf: Transform3D, half: Vector3) -> void:
	var sc := xf.basis.get_scale()
	var h := half * sc
	var n := xf.basis.y.normalized()
	if n.y < 0.5:
		warnings.append("A walkable box at (%.0f, %.0f) is steeper than 60 degrees; it is a wall, not a ramp." % [xf.origin.x, xf.origin.z])
		return
	var top := xf.origin + n * h.y
	var gx := -n.x / n.y
	var gz := -n.z / n.y
	var u := Vector2(xf.basis.x.x, xf.basis.x.z)
	if u.length() < 0.001:
		return
	var hu := u.length() / maxf(sc.x, 0.001) * half.x
	u = u.normalized()
	var bz := Vector2(xf.basis.z.x, xf.basis.z.z)
	var by := Vector2(xf.basis.y.x, xf.basis.y.z)
	var hv := bz.length() / maxf(sc.z, 0.001) * half.z + by.length() / maxf(sc.y, 0.001) * half.y
	var y_c := top.y + gx * (xf.origin.x - top.x) + gz * (xf.origin.z - top.z)
	_surfaces.append([xf.origin.x, xf.origin.z, u.x, u.y, hu, hv, y_c, gx, gz])


func _add_box(center: Vector3, basis: Basis, half: Vector3) -> void:
	var ux := Vector2(basis.x.x, basis.x.z)
	var hu := half.x * ux.length()
	var hv := half.z * Vector2(basis.z.x, basis.z.z).length()
	if ux.length() < 0.001:
		return
	ux = ux.normalized()
	_boxes.append([center.x, center.z, ux.x, ux.y, hu, hv, center.y - half.y * basis.y.length(), center.y + half.y * basis.y.length()])


func _shape(cs: CollisionShape3D) -> void:
	if cs.disabled or cs.shape == null:
		return
	var xf := cs.global_transform
	var sh := cs.shape
	var sc := maxf(xf.basis.x.length(), xf.basis.z.length())
	if sh is BoxShape3D:
		_add_box(xf.origin, xf.basis, (sh as BoxShape3D).size * 0.5)
	elif sh is CylinderShape3D:
		var hh := (sh as CylinderShape3D).height * 0.5 * xf.basis.y.length()
		_circles.append([xf.origin.x, xf.origin.z, (sh as CylinderShape3D).radius * sc, xf.origin.y - hh, xf.origin.y + hh])
	elif sh is SphereShape3D:
		var rr := (sh as SphereShape3D).radius * sc
		_circles.append([xf.origin.x, xf.origin.z, rr, xf.origin.y - rr, xf.origin.y + rr])
	elif sh is CapsuleShape3D:
		var hc := (sh as CapsuleShape3D).height * 0.5 * xf.basis.y.length()
		_circles.append([xf.origin.x, xf.origin.z, (sh as CapsuleShape3D).radius * sc, xf.origin.y - hc, xf.origin.y + hc])
	else:
		var a: AABB = sh.get_debug_mesh().get_aabb()
		_add_box(xf * a.get_center(), xf.basis, a.size * 0.5)


func _blocked(x: float, z: float, feet: float) -> bool:
	for c: Array in _circles:
		if Vector2(x - c[0], z - c[1]).length() < c[2] and c[4] > feet + 0.2 and c[3] < feet + 1.7:
			return true
	for b: Array in _boxes:
		var d := Vector2(x - b[0], z - b[1])
		var u := Vector2(b[2], b[3])
		var v := Vector2(-b[3], b[2])
		if absf(d.dot(u)) < b[4] and absf(d.dot(v)) < b[5] and b[7] > feet + 0.2 and b[6] < feet + 1.7:
			return true
	return false


# ================================================================ points and metadata
func _collect_points(root: Node) -> Array:
	var pts: Array = root.find_children("*", "EmbersPoint", true, false)
	if root is EmbersPoint:
		pts.append(root)
	return pts


func _xz(p: EmbersPoint) -> Array:
	return [snappedf(p.global_position.x, 0.01), snappedf(p.global_position.z, 0.01)]


func _meta(points: Array, heights: PackedFloat32Array) -> Dictionary:
	var K := EmbersPoint.Kind
	var meta := {"n": _n, "cell": _cell, "half": _half, "water_y": _world.water_y, "town_radius": _world.town_radius,
		"npcs": {}, "campfires": [], "fish_spots": [], "resource_spots": [], "merchants": [],
		"smooth_blend_cells": _blend_cells() if _world.smooth_biome_blend else 0,
		"smooth_path_cells": _smooth_path_cells(),
		"flat_ground": _world.flat_ground_in_game, "ground_clutter": _world.ground_clutter}
	var single := {K.SPAWN: "spawn", K.SHRINE: "shrine", K.CAMP: "camp", K.VILLAGE: "village", K.FORGE: "forge", K.FURNACE: "furnace", K.ANVIL: "anvil", K.SLAYER: "slayer"}
	var merchants: Array = []
	var known_npcs: Array = _known.get("npcs", [])
	var known_mats: Array = _known.get("materials", [])
	for p: EmbersPoint in points:
		var xz := _xz(p)
		var label := "%s%s" % [EmbersPoint.NAMES[int(p.kind)], (" '%s'" % p.id) if p.id != "" else ""]
		if absf(xz[0]) > _half or absf(xz[1]) > _half:
			_fail("%s (%s) is outside the world (size %d m)." % [label, p.name, _world.size_m])
			continue
		var h := _ground_y(xz[0], xz[1])
		if p.kind != K.FISHING_SPOT and h < _world.water_y:
			warnings.append("%s (%s) is in the water or off the terrain. Move it onto land." % [label, p.name])
		elif p.kind == K.FISHING_SPOT and h >= _world.water_y:
			warnings.append("Fishing spot (%s) is on dry land. Put it on shallow water at the shore." % p.name)
		if p.kind != K.FISHING_SPOT and p.kind != K.RESOURCE_SPOT and _blocked(xz[0], xz[1], h):
			warnings.append("%s (%s) is inside something solid (a building or rock). Players can't reach it." % [label, p.name])
		if single.has(p.kind):
			var key: String = single[p.kind]
			if meta.has(key):
				warnings.append("There are two %s points; the second (%s) is ignored." % [EmbersPoint.NAMES[int(p.kind)], p.name])
			else:
				meta[key] = xz
		elif p.kind == K.MERCHANT:
			merchants.append([p.id if p.id != "" else "9", xz])
		elif p.kind == K.NPC or p.kind == K.ELITE_LAIR:
			if p.id == "":
				_fail("%s (%s) needs an id, like \"tam\"." % [label, p.name])
			elif known_npcs.size() > 0 and not known_npcs.has(p.id):
				warnings.append("%s: the server doesn't know a character called \"%s\". Known: %s" % [p.name, p.id, ", ".join(known_npcs)])
			else:
				meta["npcs"][p.id] = xz
		elif p.kind == K.BANK:
			meta["npcs"][p.id if p.id != "" else "banker"] = xz   # the server makes a bank of it (see Zone::npc_defs)
		elif p.kind == K.CAMPFIRE:
			meta["campfires"].append(xz)
		elif p.kind == K.FISHING_SPOT:
			meta["fish_spots"].append([xz[0], xz[1], p.water_biome])
		elif p.kind == K.RESOURCE_SPOT:
			if known_mats.size() > 0 and not known_mats.has(p.id):
				warnings.append("Resource spot (%s): \"%s\" isn't a resource. Use one of: %s" % [p.name, p.id, ", ".join(known_mats)])
			else:
				meta["resource_spots"].append([xz[0], xz[1], p.id])
	merchants.sort_custom(func(a: Array, b: Array) -> bool: return str(a[0]) < str(b[0]))
	for m: Array in merchants:
		meta["merchants"].append(m[1])
	if not meta.has("spawn"):
		_fail("Add an EmbersPoint of kind Spawn: where new players appear.")
		meta["spawn"] = [0.0, 0.0]
	for key: String in ["shrine", "camp", "village", "forge", "slayer", "furnace", "anvil"]:
		if not meta.has(key):
			meta[key] = meta["spawn"]
			if key in ["shrine", "forge"]:
				warnings.append("No %s point; using the spawn instead." % key.capitalize())
	meta["merchant"] = meta["merchants"][0] if not meta["merchants"].is_empty() else meta["spawn"]
	if meta["merchants"].is_empty():
		warnings.append("No Merchant point: nobody sells potions or gear.")
	for need: String in _known.get("required_npcs", []):
		if not meta["npcs"].has(need):
			warnings.append("The tutorial quest line needs the character \"%s\"; add an NPC point with that id." % need)
	var sx: float = meta["spawn"][0]
	var sz: float = meta["spawn"][1]
	if _ground_y(sx, sz) < _world.water_y:
		_fail("The spawn point is not on land.")
	if _world.auto_fishing_spots:
		var made := _auto_fishing(Vector2(sx, sz), meta["fish_spots"])
		for s: Array in made:
			meta["fish_spots"].append(s)
		stats["auto_fishing_spots"] = made.size()
	if meta["resource_spots"].is_empty() and meta["fish_spots"].is_empty():
		warnings.append("No resource or fishing points near the start. The server scatters trees, rocks and herbs by itself, but a fishing spot near the spawn helps the tutorial.")
	stats["points"] = points.size()
	stats["characters"] = ", ".join(PackedStringArray((meta["npcs"] as Dictionary).keys()))
	return meta


## 1 for every 2 m cell that ground clutter must stay out of: around solid things (buildings, walls, trees, rocks: you placed them), on
## walkable floors and ramps, and around your marker points, each a little larger than the thing itself.
func _keep_clear_mask(points: Array) -> PackedByteArray:
	var n := _n
	var mask := PackedByteArray()
	mask.resize(n * n)
	mask.fill(0)
	var pad := 1.5
	for c: Array in _circles:
		_mark_disc(mask, float(c[0]), float(c[1]), float(c[2]) + pad)
	for q: Array in _boxes:
		_mark_rect(mask, q, pad)
	for sf: Array in _surfaces:
		_mark_rect(mask, sf, pad)
	for pt: Variant in points:
		var xz := _xz(pt)
		_mark_disc(mask, xz[0], xz[1], 2.0)
	return mask


func _mark_disc(mask: PackedByteArray, x: float, z: float, r: float) -> void:
	var x0 := clampi(floori((x - r + _half) / _cell), 0, _n - 1)
	var x1 := clampi(floori((x + r + _half) / _cell), 0, _n - 1)
	var z0 := clampi(floori((z - r + _half) / _cell), 0, _n - 1)
	var z1 := clampi(floori((z + r + _half) / _cell), 0, _n - 1)
	for iz in range(z0, z1 + 1):
		for ix in range(x0, x1 + 1):
			var cx := -_half + (ix + 0.5) * _cell
			var cz := -_half + (iz + 0.5) * _cell
			if Vector2(cx - x, cz - z).length() <= r + _cell * 0.5:
				mask[iz * _n + ix] = 1


## A box or walkable surface: [centre x, centre z, axis x, axis z, half length along the axis, half width across it, ...].
func _mark_rect(mask: PackedByteArray, b: Array, pad: float) -> void:
	var cx0 := float(b[0])
	var cz0 := float(b[1])
	var ax := Vector2(float(b[2]), float(b[3])).normalized()
	var hu := float(b[4]) + pad
	var hv := float(b[5]) + pad
	var reach := Vector2(hu, hv).length()
	var x0 := clampi(floori((cx0 - reach + _half) / _cell), 0, _n - 1)
	var x1 := clampi(floori((cx0 + reach + _half) / _cell), 0, _n - 1)
	var z0 := clampi(floori((cz0 - reach + _half) / _cell), 0, _n - 1)
	var z1 := clampi(floori((cz0 + reach + _half) / _cell), 0, _n - 1)
	var perp := Vector2(-ax.y, ax.x)
	for iz in range(z0, z1 + 1):
		for ix in range(x0, x1 + 1):
			var d := Vector2(-_half + (ix + 0.5) * _cell - cx0, -_half + (iz + 0.5) * _cell - cz0)
			if absf(d.dot(ax)) <= hu + _cell * 0.5 and absf(d.dot(perp)) <= hv + _cell * 0.5:
				mask[iz * _n + ix] = 1


## The original game's fishing spots: water cells that are shallow and touch land, in a seeded shuffle, at least `fishing_spacing_m` apart
## (12 m in the Mire), a limited number per biome (the biome of the shore), and one close to the spawn so the first fishing lesson works.
## `have` are spots that exist already (yours); they count for spacing. Returns [[x, z, biome], ...].
func _auto_fishing(spawn: Vector2, have: Array) -> Array:
	var n := _n
	var cands: Array[Vector3i] = []   # x, z, biome of the shore
	for iz in range(1, n - 1):
		for ix in range(1, n - 1):
			var i := iz * n + ix
			if _ground_ref[i] != 0 or _heights_ref[iz * (n + 1) + ix] < _world.water_y - 0.9:
				continue
			var shore_biome := -1
			for off: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var j := (iz + off.y) * n + ix + off.x
				if _ground_ref[j] != 0:
					shore_biome = _biome_ref[j]
					break
			if shore_biome >= 0:
				cands.append(Vector3i(ix, iz, shore_biome))
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for k in range(cands.size() - 1, 0, -1):
		var r := rng.randi_range(0, k)
		var tmp := cands[k]
		cands[k] = cands[r]
		cands[r] = tmp
	# the candidate nearest the spawn goes first
	var best := -1
	var best_d := 150.0
	for k in cands.size():
		var c := cands[k]
		var d := Vector2(-_half + (c.x + 0.5) * _cell, -_half + (c.y + 0.5) * _cell).distance_to(spawn)
		if d < best_d:
			best_d = d
			best = k
	if best > 0:
		var tmp2 := cands[0]
		cands[0] = cands[best]
		cands[best] = tmp2
	var chosen: Array = []
	var pts: Array[Vector3] = []   # x, z, biome of everything placed so far
	for h: Variant in have:
		pts.append(Vector3(float(h[0]), float(h[1]), float(h[2])))
	var per_biome := {}
	for c: Vector3i in cands:
		var b: int = clampi(c.z, 0, 4)
		var cap := _world.fishing_max_per_biome if b != 4 else int(_world.fishing_max_per_biome * 1.7)
		if int(per_biome.get(b, 0)) >= cap:
			continue
		var x := -_half + (c.x + 0.5) * _cell
		var z := -_half + (c.y + 0.5) * _cell
		var gap := _world.fishing_spacing_m * (12.0 / 22.0 if b == 2 else 1.0)
		var ok := true
		for q: Vector3 in pts:
			if Vector2(q.x, q.y).distance_to(Vector2(x, z)) < gap:
				ok = false
				break
		if ok:
			chosen.append([x, z, b])
			pts.append(Vector3(x, z, b))
			per_biome[b] = int(per_biome.get(b, 0)) + 1
	return chosen


# ================================================================ writing
## Where ground clutter must not go, deflate-packed (the game unpacks it into World.clear).
func _write_clutter_mask(dir: String, points: Array) -> void:
	var f := FileAccess.open(dir.path_join("clutter_clear.bin"), FileAccess.WRITE)
	if f == null:
		return
	f.store_buffer(_keep_clear_mask(points).compress(FileAccess.COMPRESSION_DEFLATE))


func _write(dir: String, heights: PackedFloat32Array, ground: PackedByteArray, biome: PackedByteArray, zone: PackedByteArray, path: PackedByteArray, meta: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(dir.path_join("terrain.bin"), FileAccess.WRITE)
	if f == null:
		_fail("Can't write to %s" % dir)
		return
	f.store_buffer("EMBT".to_utf8_buffer())
	f.store_32(1)
	f.store_32(_n)
	f.store_float(_cell)
	f.store_float(_world.water_y)
	var hb := PackedByteArray()
	hb.resize(heights.size() * 2)
	for i in heights.size():
		hb.encode_s16(i * 2, clampi(roundi(heights[i] * 100.0), -32768, 32767))
	f.store_buffer(hb)
	f.store_buffer(ground)
	f.store_buffer(biome)
	f.store_buffer(zone)
	f.store_buffer(path)
	f.close()
	var o := FileAccess.open(dir.path_join("obstacles.bin"), FileAccess.WRITE)
	o.store_buffer("EMBO".to_utf8_buffer())
	o.store_32(2)
	o.store_32(_circles.size())
	o.store_32(_boxes.size())
	o.store_32(_surfaces.size())
	for c: Array in _circles:
		for v: float in c:
			o.store_float(v)
	for b: Array in _boxes:
		for v: float in b:
			o.store_float(v)
	for sf: Array in _surfaces:
		for v: float in sf:
			o.store_float(v)
	o.close()
	var mf := FileAccess.open(dir.path_join("terrain_meta.json"), FileAccess.WRITE)
	mf.store_string(JSON.stringify(meta, " "))
	mf.close()
	stats["written_to"] = ProjectSettings.globalize_path(dir) if dir.begins_with("res://") else dir
