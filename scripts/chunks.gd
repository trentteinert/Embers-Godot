class_name ChunkStreamer
extends Node3D
## Streams the world in 16 x 16 cell chunks around the player: ground mesh and paint, trees, rocks,
## ground clutter and ore spots are built when a chunk comes into view range and freed when it leaves.
## The heights, ground types and biomes themselves stay in World (cheap arrays); everything heavy lives here.

const CS := 16                    # cells per chunk side (32 m)
const T := World.T
const G := World.G
const FLORA_VARIANTS := 4
const CLUTTER_VARIANTS := 3

signal chunk_loaded(coord: Vector2i)
signal chunk_unloaded(coord: Vector2i)

var world: World
var follow: Node3D
var view_chunks := 9              # radius in chunks; the setting lives in World.set_view_distance
var budget_ms := 5.0              # how long per frame streaming may take

var _loaded := {}                 # Vector2i -> Node3D
var _spots := {}                  # Vector2i -> Array of ore spots (kept so gathered state survives unloads)
var _queue: Array[Vector2i] = []
var _center := Vector2i(-99999, -99999)
var _scan := 0.0
var _base := {}                   # "kind:seed" -> {v, n, c}
var _flora_mat := {}              # "see" / "opq" / "glow" -> ShaderMaterial
var _solid_shape := CylinderShape3D.new()
var _rock_shape := CylinderShape3D.new()
var _ore_by_biome := {}           # biome -> Array of [mat, chance]

const KINDS := {
	T.OAK: ["oak", 1.45], T.DARK_OAK: ["dark_oak", 1.5], T.DEAD: ["dead", 1.4], T.PINE: ["pine", 1.45],
	T.BOULDER: ["boulder", 1.6], T.TUFT: ["tuft", 1.4], T.FLOWER: ["flower", 1.4],
	T.BIRCH: ["birch", 1.45], T.WILLOW: ["willow", 1.5], T.TALL_PINE: ["tall_pine", 1.6], T.AUTUMN: ["autumn", 1.5],
	T.BUSH: ["bush", 1.4], T.FERN: ["fern", 1.4], T.MUSHROOM: ["mushroom", 1.5], T.REEDS: ["reeds", 1.4],
	T.LOG: ["log", 1.5], T.STUMP: ["stump", 1.4], T.SPIRE: ["spire", 1.7],
}
const TREES := [T.OAK, T.DARK_OAK, T.DEAD, T.PINE, T.BIRCH, T.WILLOW, T.TALL_PINE, T.AUTUMN]
const SOLID := [T.OAK, T.DARK_OAK, T.DEAD, T.PINE, T.BIRCH, T.WILLOW, T.TALL_PINE, T.AUTUMN, T.BOULDER, T.SPIRE]
const SWAYERS := [T.TUFT, T.FLOWER, T.BUSH, T.FERN, T.REEDS]
const SEE := [T.OAK, T.DARK_OAK, T.DEAD, T.PINE, T.BIRCH, T.WILLOW, T.TALL_PINE, T.AUTUMN, T.BUSH, T.FERN, T.REEDS, T.TUFT, T.LOG, T.STUMP]
const NO_SHADOW := [T.TUFT, T.FLOWER, T.FERN, T.MUSHROOM, T.REEDS, T.BUSH]
const CLUTTER_KINDS := ["pebbles", "mossrock", "bones", "branches", "tallgrass", "glowcap", "frostweed"]
const CLUTTER_SCALE := [1.5, 1.5, 1.4, 1.4, 1.4, 1.5, 1.4]

const SHADER := """
shader_type spatial;
render_mode cull_disabled, diffuse_lambert;
uniform bool see_through = true;
uniform float glow = 0.0;
global uniform vec3 player_pos;
global uniform float wind;
varying float phase;
void vertex() {
	// UV carries the instance's base xz, UV2 its base height and how much it sways
	vec3 origin = vec3(UV.x, UV2.x, UV.y);
	phase = origin.x;
	float h = max(VERTEX.y - origin.y, 0.0) * 0.7;
	float s = sin(TIME * 1.4 * (0.7 + wind * 0.3) + origin.x * 0.37 + origin.z * 0.21) * UV2.y * wind * h;
	VERTEX.x += s;
	VERTEX.z += s * 0.5;
}
void fragment() {
	if (see_through) {
		vec3 pv = (VIEW_MATRIX * vec4(player_pos + vec3(0.0, 1.0, 0.0), 1.0)).xyz;
		if (-VERTEX.z < -pv.z - 1.2) {
			float d = length(VERTEX.xy / -VERTEX.z - pv.xy / -pv.z);
			float k = smoothstep(0.17, 0.07, d);
			if (d < 0.17 && (k > 0.85 || mod(FRAGCOORD.x + FRAGCOORD.y, 2.0) < 1.0 * k * 1.6)) {
				discard;
			}
		}
	}
	ALBEDO = COLOR.rgb;
	if (glow > 0.0) {
		EMISSION = COLOR.rgb * glow * (0.6 + 0.4 * sin(TIME * 1.3 + phase));
	}
	ROUGHNESS = 1.0;
	SPECULAR = 0.1;
}
"""


func setup(w: World) -> void:
	world = w
	name = "Chunks"
	_solid_shape.radius = 0.45
	_solid_shape.height = 4.0
	_rock_shape.radius = 0.8
	_rock_shape.height = 3.0
	var sh := Shader.new()
	sh.code = SHADER
	for k: String in ["see", "opq", "glow"]:
		var m := ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter("see_through", k == "see")
		m.set_shader_parameter("glow", 1.6 if k == "glow" else 0.0)
		_flora_mat[k] = m
	for mat: String in Data.NODES:
		var b: int = Data.NODES[mat]["biome"]
		if not _ore_by_biome.has(b):
			_ore_by_biome[b] = []
		(_ore_by_biome[b] as Array).append([mat, float(Data.NODES[mat]["chance"]) * 0.6])


func chunk_of(p: Vector3) -> Vector2i:
	var s := CS * World.CELL
	return Vector2i(floori((p.x + World.HALF) / s), floori((p.z + World.HALF) / s))


func is_loaded(c: Vector2i) -> bool:
	return _loaded.has(c)


func loaded_coords() -> Array:
	return _loaded.keys()


## ore / log / crystal spots in a chunk (generated the first time the chunk is built)
func spots_for(c: Vector2i) -> Array:
	return _spots.get(c, [])


func _process(_delta: float) -> void:
	if world == null:
		return
	if follow == null or not is_instance_valid(follow):
		follow = get_tree().get_first_node_in_group("player") as Node3D
		return
	_scan -= _delta
	if _scan <= 0.0:
		_scan = 0.2
		var c := chunk_of(follow.global_position)
		if c != _center:
			_center = c
			_refresh()
	var t0 := Time.get_ticks_usec()
	while not _queue.is_empty() and (Time.get_ticks_usec() - t0) < int(budget_ms * 1000.0):
		var q: Vector2i = _queue.pop_front()
		if not _loaded.has(q):
			_build_chunk(q)


func set_view(chunks: int) -> void:
	view_chunks = clampi(chunks, 3, 16)
	_center = Vector2i(-99999, -99999)


func _in_range(c: Vector2i, from: Vector2i, r: float) -> bool:
	return Vector2(c - from).length() <= r


func _refresh() -> void:
	# free what has fallen out of range (a little hysteresis so edges don't flicker)
	for c: Vector2i in _loaded.keys():
		if not _in_range(c, _center, view_chunks + 1.6):
			_free_chunk(c)
	# queue what is missing, nearest first
	var maxc := ceili(float(World.N) / CS)
	var need: Array[Vector2i] = []
	for dy in range(-view_chunks, view_chunks + 1):
		for dx in range(-view_chunks, view_chunks + 1):
			var c := _center + Vector2i(dx, dy)
			if c.x < 0 or c.y < 0 or c.x >= maxc or c.y >= maxc:
				continue
			if Vector2(dx, dy).length() > view_chunks or _loaded.has(c):
				continue
			need.append(c)
	need.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return Vector2(a - _center).length_squared() < Vector2(b - _center).length_squared())
	_queue = need


## Build everything within r chunks of a point right now (spawning, teleports, tests).
func flush(p: Vector3, r := 3) -> void:
	var cc := chunk_of(p)
	var maxc := ceili(float(World.N) / CS)
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var c := cc + Vector2i(dx, dy)
			if c.x < 0 or c.y < 0 or c.x >= maxc or c.y >= maxc or _loaded.has(c):
				continue
			if Vector2(dx, dy).length() <= r + 0.5:
				_build_chunk(c)


func _free_chunk(c: Vector2i) -> void:
	var n: Node = _loaded[c]
	_loaded.erase(c)
	chunk_unloaded.emit(c)
	n.queue_free()


# ================================================================ building a chunk
func _build_chunk(c: Vector2i) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = (c.x * 73856093) ^ (c.y * 19349663) ^ 20261004
	var root := Node3D.new()
	root.name = "Chunk_%d_%d" % [c.x, c.y]
	add_child(root)
	_loaded[c] = root
	var x0 := c.x * CS
	var y0 := c.y * CS
	var x1 := mini(x0 + CS, World.N)
	var y1 := mini(y0 + CS, World.N)
	_build_ground(root, x0, y0, x1, y1, rng)
	var inst: Array = []          # [kind_name, variant_seed, Transform3D, sway, group("see"/"opq"/"glow"), shadow]
	var solid_cells := {}
	var body := StaticBody3D.new()
	body.collision_layer = 2
	root.add_child(body)
	_scatter_flora(c, x0, y0, x1, y1, rng, inst, solid_cells, body)
	_scatter_clutter(x0, y0, x1, y1, rng, inst)
	_gen_spots(c, x0, y0, x1, y1, rng, solid_cells)
	_merge(root, inst)
	chunk_loaded.emit(c)


func _build_ground(root: Node3D, x0: int, y0: int, x1: int, y1: int, rng: RandomNumberGenerator) -> void:
	var W := World.N + 1
	var N := World.N
	var TEX := World.TEX
	var cw := x1 - x0
	var ch := y1 - y0
	# paint
	var img := Image.create(CS * TEX, CS * TEX, false, Image.FORMAT_RGB8)
	for y in range(y0, y1):
		for x in range(x0, x1):
			var i := y * N + x
			var g: int = world.ground[i]
			var base: Color
			var on_path: bool = world.path[i] != 0 and g != G.WATER
			if on_path:
				base = Color(World.PATH_COL[world.biome[i]])
			else:
				base = Color(World.GROUND_COL[g][(x + y) % 2])
			var s := world._shade.get_noise_2d(x, y)
			base = base.lightened(s * 0.08) if s > 0.0 else base.darkened(-s * 0.12)
			var lx := (x - x0) * TEX
			var ly := (y - y0) * TEX
			img.fill_rect(Rect2i(lx, ly, TEX, TEX), base)
			for k in 6:
				var px := lx + rng.randi_range(0, TEX - 1)
				var py := ly + rng.randi_range(0, TEX - 1)
				var r := rng.randf()
				var col := Color(0, 0, 0, 0)
				if on_path:
					col = base.darkened(0.15) if r < 0.6 else base.lightened(0.1)
				else:
					match g:
						G.GRASS:
							col = Color("82c25e")
							if r < 0.05:
								col = Color("f2d16b") if r < 0.025 else Color("e88aa6")
							elif r > 0.7:
								col = Color("4c8a3c")
						G.FOREST:
							col = Color("6b5a2a") if r < 0.2 else Color("24452a")
						G.MUD:
							col = Color("3a3a28")
						G.BOG:
							col = Color("46604f")
						G.SNOW:
							col = Color("e4ecf2") if r < 0.3 else Color("a6b4c4")
						G.SAND:
							col = Color("b39b62")
						G.ROCK:
							col = Color("9aa0aa") if r < 0.4 else Color("50545e")
						G.WATER:
							col = Color("4a7a88")
				img.set_pixel(px, py, col)
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	# mesh: normals come from the global height field so neighbouring chunks light seamlessly
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var vw := cw + 1
	for vy in range(y0, y1 + 1):
		for vx in range(x0, x1 + 1):
			var h: float = world.heights[vy * W + vx]
			verts.append(Vector3(vx * World.CELL - World.HALF, h, vy * World.CELL - World.HALF))
			var hl: float = world.heights[vy * W + maxi(vx - 1, 0)]
			var hr: float = world.heights[vy * W + mini(vx + 1, N)]
			var hu: float = world.heights[maxi(vy - 1, 0) * W + vx]
			var hd: float = world.heights[mini(vy + 1, N) * W + vx]
			norms.append(Vector3(hl - hr, 2.0 * World.CELL, hu - hd).normalized())
			uvs.append(Vector2(float(vx - x0) / CS, float(vy - y0) / CS))
	for y in ch:
		for x in cw:
			var i := y * vw + x
			idx.append(i)
			idx.append(i + 1)
			idx.append(i + vw)
			idx.append(i + 1)
			idx.append(i + vw + 1)
			idx.append(i + vw)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS_ANISOTROPIC
	mat.texture_repeat = false
	mat.roughness = 1.0
	mat.metallic_specular = 0.15
	var mi := MeshInstance3D.new()
	mi.name = "Ground"
	mi.mesh = mesh
	mi.material_override = mat
	root.add_child(mi)


func _scatter_flora(c: Vector2i, x0: int, y0: int, x1: int, y1: int, rng: RandomNumberGenerator, inst: Array, solid_cells: Dictionary, body: StaticBody3D) -> void:
	var N := World.N
	var W := N + 1
	for y in range(y0, y1):
		for x in range(x0, x1):
			var i := y * N + x
			if world.clear[i]:
				continue
			var g: int = world.ground[i]
			if g == G.WATER:
				continue
			var b: int = world.biome[i]
			var roll := rng.randf()
			var kind := -1
			var hh: float = world.heights[y * W + x]
			var pv: float = world._bog.get_noise_2d(x * 0.55, y * 0.55)
			var wet: bool = world._riv[y * W + x] > 0.12 or (hh < 0.55 and hh > -0.2)
			if g == G.SAND and b <= 2 and wet:
				if roll < 0.10:
					kind = T.REEDS
				elif roll < 0.125 and b <= 1:
					kind = T.WILLOW
				elif roll < 0.15:
					kind = T.TUFT
			elif g == G.ROCK and b <= 2:
				if roll < 0.07:
					kind = T.BOULDER
				elif roll < 0.095:
					kind = T.SPIRE
				elif roll < 0.11 and b == 1:
					kind = T.TALL_PINE
			elif g == G.SNOW and b <= 2:
				if roll < 0.05:
					kind = T.PINE
				elif roll < 0.07:
					kind = T.BOULDER
				elif roll < 0.08:
					kind = T.SPIRE
			else:
				match b:
					0:
						if g == G.GRASS:
							if roll < 0.035:
								kind = T.BIRCH if pv > 0.15 else T.OAK
							elif roll < 0.20:
								kind = T.TUFT
							elif roll < 0.24:
								kind = T.FLOWER
							elif roll < 0.255:
								kind = T.BUSH
							elif roll < 0.258:
								kind = T.STUMP
							elif roll < 0.262:
								kind = T.LOG
					1:
						if g == G.FOREST:
							var dense := 0.22 if world._hill.get_noise_2d(x * 1.7, y * 1.7) > 0.05 else 0.07
							if roll < dense:
								if pv < -0.18:
									kind = T.TALL_PINE
								elif pv > 0.3:
									kind = T.AUTUMN if rng.randf() < 0.7 else T.BIRCH
								elif pv > 0.12 and rng.randf() < 0.3:
									kind = T.BIRCH
								else:
									kind = T.DARK_OAK
							elif roll < dense + 0.07:
								kind = T.TUFT
							elif roll < dense + 0.105:
								kind = T.FERN
							elif roll < dense + 0.118:
								kind = T.BUSH
							elif roll < dense + 0.128:
								kind = T.MUSHROOM
							elif roll < dense + 0.134:
								kind = T.LOG
							elif roll < dense + 0.137:
								kind = T.STUMP
					2:
						if g == G.MUD or g == G.BOG:
							if roll < 0.05:
								kind = T.DEAD
							elif roll < 0.065 and wet:
								kind = T.WILLOW
							elif roll < 0.12 and wet:
								kind = T.REEDS
							elif roll < 0.13:
								kind = T.MUSHROOM
							elif roll > 0.9:
								kind = T.TUFT
						elif roll > 0.9:
							kind = T.TUFT
					3:
						if g == G.SNOW:
							if roll < 0.06:
								kind = T.PINE
							elif roll < 0.085:
								kind = T.BOULDER
							elif roll < 0.095:
								kind = T.SPIRE
						elif g == G.ROCK:
							if roll < 0.08:
								kind = T.BOULDER
							elif roll < 0.11:
								kind = T.SPIRE
			if kind == -1:
				continue
			var p := world.cell_center(x, y)
			p.x += rng.randf_range(-0.6, 0.6)
			p.z += rng.randf_range(-0.6, 0.6)
			p.y = world.height_at(p.x, p.z) - 0.05
			var sc: float = float(KINDS[kind][1]) * rng.randf_range(0.85, 1.15)
			var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * sc)
			if kind in TREES:
				basis = basis.scaled(Vector3(1.0, 1.3, 1.0))   # taller trunks keep the view under the canopy open
			var sway := 0.12 if kind in SWAYERS else (0.025 if (kind in TREES and kind != T.DEAD) else 0.0)
			var variant := rng.randi() % FLORA_VARIANTS
			inst.append([KINDS[kind][0], (kind * 10 + variant) * 7 + 3, Transform3D(basis, p), sway, "see" if kind in SEE else "opq", not (kind in NO_SHADOW)])
			if kind in SOLID:
				solid_cells[Vector2i(x, y)] = true
				var cs := CollisionShape3D.new()
				cs.shape = _rock_shape if kind in [T.BOULDER, T.SPIRE] else _solid_shape
				cs.position = p + Vector3(0, 1.5, 0)
				body.add_child(cs)


func _scatter_clutter(x0: int, y0: int, x1: int, y1: int, rng: RandomNumberGenerator, inst: Array) -> void:
	var N := World.N
	for y in range(y0, y1):
		for x in range(x0, x1):
			var i := y * N + x
			if world.clear[i] or world.path[i]:
				continue
			var g: int = world.ground[i]
			if g == G.WATER:
				continue
			var b: int = world.biome[i]
			var roll := rng.randf()
			var pv: float = world._bog.get_noise_2d(x * 0.55, y * 0.55)
			var k := -1
			if g == G.SAND:
				if roll < 0.04:
					k = 0
			elif g == G.ROCK:
				if roll < 0.12:
					k = 0
				elif roll < 0.135:
					k = 2
			elif g == G.SNOW:
				if roll < 0.06:
					k = 6
				elif roll < 0.075:
					k = 0
				elif roll < 0.082:
					k = 2
			else:
				match b:
					0:
						if g == G.GRASS:
							if roll < 0.07 and pv > -0.1:
								k = 4
							elif roll < 0.095:
								k = 0
							elif roll < 0.11:
								k = 3
					1:
						if roll < 0.06:
							k = 3
						elif roll < 0.09:
							k = 1
						elif roll < 0.1:
							k = 5
						elif roll < 0.105:
							k = 2
					2:
						if roll < 0.05:
							k = 5
						elif roll < 0.07:
							k = 2
						elif roll < 0.09:
							k = 3
						elif roll < 0.12:
							k = 1
			if k == -1:
				continue
			var p := world.cell_center(x, y)
			p.x += rng.randf_range(-0.7, 0.7)
			p.z += rng.randf_range(-0.7, 0.7)
			p.y = world.height_at(p.x, p.z) - 0.03
			var sc: float = float(CLUTTER_SCALE[k]) * rng.randf_range(0.8, 1.2)
			var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * sc)
			var variant := rng.randi() % CLUTTER_VARIANTS
			var grp := "glow" if k == 5 else ("see" if k in [0, 1, 3, 4] else "opq")
			inst.append([CLUTTER_KINDS[k], (k * 10 + variant) * 5 + 1, Transform3D(basis, p), 0.1 if k in [4, 6] else 0.0, grp, false])


func _gen_spots(c: Vector2i, x0: int, y0: int, x1: int, y1: int, rng: RandomNumberGenerator, solid_cells: Dictionary) -> void:
	if _spots.has(c):
		return
	var N := World.N
	var out: Array = []
	for y in range(maxi(y0, 2), mini(y1, N - 2)):
		for x in range(maxi(x0, 2), mini(x1, N - 2)):
			var i := y * N + x
			if world.clear[i] or world.path[i] or solid_cells.has(Vector2i(x, y)):
				continue
			var g: int = world.ground[i]
			if g == G.WATER or g == G.SAND:
				continue
			var list: Array = _ore_by_biome.get(world.biome[i], [])
			for e: Array in list:
				if rng.randf() < float(e[1]):
					out.append({"pos": world.cell_center(x, y), "mat": e[0], "ready_t": 0.0})
					break
	_spots[c] = out


# ================================================================ merging instances into a few meshes
func _base_arrays(kind: String, seed_v: int) -> Dictionary:
	var key := "%s:%d" % [kind, seed_v]
	if not _base.has(key):
		var m := Models.scenery_mesh(kind, seed_v)
		var a := m.surface_get_arrays(0)
		_base[key] = {"v": a[Mesh.ARRAY_VERTEX], "n": a[Mesh.ARRAY_NORMAL], "c": a[Mesh.ARRAY_COLOR]}
	return _base[key]


func _merge(root: Node3D, inst: Array) -> void:
	if inst.is_empty():
		return
	# buckets: shadow (1/0) -> group -> arrays
	var buckets := {}
	for it: Array in inst:
		var shadow: bool = it[5]
		var grp: String = it[4]
		var bk := "%d%s" % [1 if shadow else 0, grp]
		if not buckets.has(bk):
			buckets[bk] = {"v": PackedVector3Array(), "n": PackedVector3Array(), "c": PackedColorArray(), "uv": PackedVector2Array(), "uv2": PackedVector2Array()}
		var b: Dictionary = buckets[bk]
		var base := _base_arrays(it[0], it[1])
		var xf: Transform3D = it[2]
		var nb := xf.basis.orthonormalized()
		var bv: PackedVector3Array = base["v"]
		var bn: PackedVector3Array = base["n"]
		var bc: PackedColorArray = base["c"]
		var ov: PackedVector3Array = b["v"]
		var on: PackedVector3Array = b["n"]
		var oc: PackedColorArray = b["c"]
		var ouv: PackedVector2Array = b["uv"]
		var ouv2: PackedVector2Array = b["uv2"]
		var uv := Vector2(xf.origin.x, xf.origin.z)
		var uv2 := Vector2(xf.origin.y, float(it[3]))
		for k in bv.size():
			ov.append(xf * bv[k])
			on.append(nb * bn[k])
			oc.append(bc[k])
			ouv.append(uv)
			ouv2.append(uv2)
		b["v"] = ov
		b["n"] = on
		b["c"] = oc
		b["uv"] = ouv
		b["uv2"] = ouv2
	for shadow in [1, 0]:
		var mesh := ArrayMesh.new()
		for grp: String in ["see", "opq", "glow"]:
			var bk := "%d%s" % [shadow, grp]
			if not buckets.has(bk):
				continue
			var b: Dictionary = buckets[bk]
			var arr := []
			arr.resize(Mesh.ARRAY_MAX)
			arr[Mesh.ARRAY_VERTEX] = b["v"]
			arr[Mesh.ARRAY_NORMAL] = b["n"]
			arr[Mesh.ARRAY_COLOR] = b["c"]
			arr[Mesh.ARRAY_TEX_UV] = b["uv"]
			arr[Mesh.ARRAY_TEX_UV2] = b["uv2"]
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			mesh.surface_set_material(mesh.get_surface_count() - 1, _flora_mat[grp])
		if mesh.get_surface_count() == 0:
			continue
		var mi := MeshInstance3D.new()
		mi.name = "Flora" if shadow == 1 else "Low"
		mi.mesh = mesh
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow == 1 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
