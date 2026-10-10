class_name World
extends Node3D
## Builds Thornvale at load time: a 3D heightmap terrain painted with a pixel texture, water,
## billboard pixel trees, and the story props (Hearth Shrine, runestones, Warden altars).
## Everything is generated from fixed seeds, so the map is the same every run.

const N := 1200           # cells per side (2.4 km)
const TOWN_CELLS := 44    # radius of the starter town clearing around the shrine (cells; 1 cell = 2 m)
const CELL := 2.0         # metres per cell
const HALF := N * CELL * 0.5
const CX := 600           # shrine cell
const CY := 600
const TEX := 8            # ground texture pixels per cell
const WATER_Y := 0.0

enum G { WATER, SAND, GRASS, FOREST, MUD, BOG, SNOW, ROCK }
enum T { OAK, DARK_OAK, DEAD, PINE, BOULDER, TUFT, FLOWER, BIRCH, WILLOW, TALL_PINE, AUTUMN, BUSH, FERN, MUSHROOM, REEDS, LOG, STUMP, SPIRE }

const GROUND_COL := {
	G.WATER: ["3b6470", "3e6874"], G.SAND: ["c9b27a", "cfb880"], G.GRASS: ["5f9a46", "649f4a"],
	G.FOREST: ["2f5a34", "325e37"], G.MUD: ["4b4a33", "4f4e36"], G.BOG: ["2e3d34", "304036"],
	G.SNOW: ["c4d0dc", "bdc9d6"], G.ROCK: ["6f7480", "767b86"],
}
const PATH_COL := ["8a7350", "6e5a3c", "5e553c", "b4c0ca", "bfa874"]
const MAP_COL := {
	G.WATER: "2b5a8a", G.SAND: "c9b27a", G.GRASS: "5f9a46", G.FOREST: "2f5a34", G.MUD: "4b4a33",
	G.BOG: "2e3d34", G.SNOW: "d8e2ea", G.ROCK: "6f7480",
}

var heights := PackedFloat32Array()   # (N+1)^2 corner heights
var ground := PackedByteArray()       # N*N ground type
var biome := PackedByteArray()        # N*N biome index (see Data.BIOME_NAMES)
var path := PackedByteArray()
var clear := PackedByteArray()        # 1 = keep free of trees

var shrine_pos := Vector3.ZERO
var merchant_pos := Vector3.ZERO
var npc_pos := {}                     # quest giver / elite lair id -> position
var rune_pos: Array[Vector3] = []
var altar_pos: Array[Vector3] = []
var rune_glyphs: Array[StandardMaterial3D] = []
var map_texture: ImageTexture
var resource_spots: Array = []        # {pos, mat} ore rocks, logs and crystals (see crafting.gd)
var forge_pos := Vector3.ZERO
var fish_spots: Array = []            # {pos, biome} rippling water for Fishing
var campfires: Array[Vector3] = []    # Cooking
var alchemy_pos := Vector3.ZERO       # Herblore table
var bench_pos := Vector3.ZERO         # Crafting workbench
var furnace_pos := Vector3.ZERO       # Smelting
var anvil_pos := Vector3.ZERO         # Smithing tools
var slayer_pos := Vector3.ZERO        # Varka, the Slayer master
var camp_pos := Vector3.ZERO          # Wanderer's Rest, the starting camp (spawn point)
var rack_pos := Vector3.ZERO          # the camp's weapon rack (bow and staff)
var camp_bench_pos := Vector3.ZERO    # the camp's crafting bench
var camp_fish_pos := Vector3.ZERO     # the camp pond's fishing spot
var camp_pond := Vector3.ZERO
var courses: Array = []               # agility courses: {i, center, gates: Array[Vector3]}
const COURSE_R := 5.0                 # gate ring radius in cells
var trees_cells: Array[Vector2i] = []   # for the map

var _shape: FastNoiseLite
var _hill: FastNoiseLite
var _lake: FastNoiseLite
var _bog: FastNoiseLite
var _shade: FastNoiseLite
var _coast: FastNoiseLite
var _roll: FastNoiseLite
static var relief_scale := 1.0   # 0 = the old gentle land (tests), 1 = full hills and highlands
var _macro: FastNoiseLite      # broad hills and basins
var _macro2: FastNoiseLite
var _hi: FastNoiseLite         # where the highlands rise
var _hir: FastNoiseLite        # ridges inside the highlands
var _ridge: FastNoiseLite
var _mtn: FastNoiseLite
var _riv := PackedFloat32Array()      # (N+1)^2 river influence 0..1 (bed = 1)
var caves: Caves
var stream_lines: Array = []
var bridges: Array = []               # {pos, dir, len}
var streamer: ChunkStreamer
var landmarks: Array = []             # {kind, pos, name, r}
var cave_sites: Array = []            # {pos, face, biome, idx}
var river_lines: Array = []           # each: Array[Vector2] of cell positions
const RIVER_BED := -0.55
var _rng := RandomNumberGenerator.new()
var _flame: Node3D
var _flame_cones: Array[MeshInstance3D] = []
var water_mat: ShaderMaterial
var _flame_light: OmniLight3D
var _wisp: Node3D
var _wisp_rig: Rig
var _ped_orbs: Array[Node3D] = []
var _altar_gems: Array = []      # per altar: Array of 3 materials
var _altar_glow: Array[OmniLight3D] = []
var _lit := 0
var _t := 0.0


static func ensure_wind() -> void:
	if not &"wind" in RenderingServer.global_shader_parameter_get_list():
		RenderingServer.global_shader_parameter_add("wind", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 1.0)


func generate() -> void:
	ensure_wind()
	add_to_group("world")
	var t0 := Time.get_ticks_msec()
	_rng.seed = 20261004
	_shape = _noise(7, 0.07)
	_hill = _noise(11, 0.035)
	_lake = _noise(31, 0.09)
	_bog = _noise(53, 0.16)
	_shade = _noise(3, 0.2)
	_coast = _noise(77, 1.0)
	_roll = _noise(91, 0.022)
	_ridge = _noise(113, 0.016)
	_ridge.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_ridge.fractal_octaves = 4
	_mtn = _noise(131, 0.03)
	_tier_n = _noise(211, 0.015)
	_tier_n.fractal_octaves = 3
	_cst_n = _noise(223, 0.0045)
	_macro = _noise(331, 0.0055)
	_macro2 = _noise(347, 0.012)
	_hi = _noise(361, 0.0038)
	_hir = _noise(367, 0.008)
	_hir.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_hir.fractal_octaves = 3
	_build_fields()
	_choose_sites()
	_build_heights()
	_place_sites()
	_classify()
	_place_caves()
	_place_fish()
	_build_terrain_global()
	_build_water()
	_build_bridges()
	_pick_landmarks()
	_build_landmarks()
	streamer = ChunkStreamer.new()
	add_child(streamer)
	streamer.setup(self)
	_place_camp_resources()
	_build_props()
	_build_town()
	_build_village()
	_build_settlements()
	_place_town_folk()
	_build_camp()
	caves = Caves.new()
	caves.name = "Caves"
	caves.sites = cave_sites
	add_child(caves)
	caves.build(self)
	_build_map()
	reset_fog()
	streamer.flush(spawn_point(), 3)
	print("World generated in %d ms" % (Time.get_ticks_msec() - t0))


# ================================================================ queries
func cell_center(cx: int, cy: int) -> Vector3:
	var x := (cx + 0.5) * CELL - HALF
	var z := (cy + 0.5) * CELL - HALF
	return Vector3(x, height_at(x, z), z)


func world_to_cell(p: Vector3) -> Vector2:
	if p.x > Caves.X0 - 150.0 and caves:
		return caves.map_cell(p)
	return Vector2((p.x + HALF) / CELL, (p.z + HALF) / CELL)


func height_at(x: float, z: float) -> float:
	if x > Caves.X0 - 150.0:
		return Caves.FLOOR_Y
	var fx := clampf((x + HALF) / CELL, 0.0, N - 0.001)
	var fz := clampf((z + HALF) / CELL, 0.0, N - 0.001)
	var ix := int(fx)
	var iz := int(fz)
	var tx := fx - ix
	var tz := fz - iz
	var w := N + 1
	var h00 := heights[iz * w + ix]
	var h10 := heights[iz * w + ix + 1]
	var h01 := heights[(iz + 1) * w + ix]
	var h11 := heights[(iz + 1) * w + ix + 1]
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz)


func _cell_index(p: Vector3) -> int:
	var c := world_to_cell(p)
	var cx := clampi(int(c.x), 0, N - 1)
	var cy := clampi(int(c.y), 0, N - 1)
	return cy * N + cx


func ground_at(p: Vector3) -> int:
	return ground[_cell_index(p)]


func biome_at(p: Vector3) -> int:
	if p.x > Caves.X0 - 150.0 and caves:
		return caves.biome_here(p)
	var c := world_to_cell(p)
	if c.x < 0 or c.y < 0 or c.x >= N or c.y >= N:
		return 4
	return biome[_cell_index(p)]


## Index into Data.ZONES for a world position, or -1 inside the caves / off the painted plan.
func zone_at(p: Vector3) -> int:
	if p.x > Caves.X0 - 150.0:
		return -1
	var c := world_to_cell(p)
	return lay.zone_at(c.x, c.y)


func zone_name(p: Vector3) -> String:
	var z := zone_at(p)
	return String(Data.ZONES[z]["name"]) if z >= 0 else Data.BIOME_NAMES[biome_at(p)]


## "TALLOWFIELDS · LV 1-8" for the HUD.
func zone_label(p: Vector3) -> String:
	var z := zone_at(p)
	if z < 0:
		return Data.BIOME_NAMES[biome_at(p)].to_upper()
	var d: Dictionary = Data.ZONES[z]
	return "%s · LV %d-%d" % [String(d["name"]).to_upper(), int(d["lo"]), int(d["hi"])]


## The level of things found at this spot: the low half of its zone's range, so wandering deeper meets tougher ones.
func rec_level(p: Vector3, elite := false) -> int:
	var z := zone_at(p)
	if z < 0:
		return int(Data.BIOME_REC_LEVEL[biome_at(p)]) + randi() % 3
	var lo: int = Data.ZONES[z]["lo"]
	var hi: int = Data.ZONES[z]["hi"]
	if elite:
		return hi
	return lo + randi() % (1 + (hi - lo) / 2)


func is_water(x: float, z: float) -> bool:
	return height_at(x, z) < WATER_Y - 0.05


func spawn_point() -> Vector3:
	var p := camp_pos + Vector3(3.2, 0, -3.4) if camp_pos != Vector3.ZERO else shrine_pos + Vector3(0, 0, 6.5)
	p.y = height_at(p.x, p.z) + 0.2
	return p


func set_lit(count: int) -> void:
	## how many Warden lights burn at the Hearth Shrine
	_lit = count
	for i in _ped_orbs.size():
		_ped_orbs[i].visible = i < count


func set_altar(i: int, active: bool, shards: int) -> void:
	if i < 0 or i >= _altar_gems.size():
		return
	var gems: Array = _altar_gems[i]
	for g in 3:
		var m: StandardMaterial3D = gems[g]
		var on := active and g < shards
		m.albedo_color = Color(Data.BOSSES[i]["color"]) if on else Color("2a2633")
		m.emission_energy_multiplier = 2.5 if on else 0.0
	_altar_glow[i].light_energy = 1.6 if active else 0.0


func set_rune_state(i: int, state: String) -> void:
	## state: "dim", "glow" (the next stone to read), or "read"
	if i < 0 or i >= rune_glyphs.size():
		return
	var m := rune_glyphs[i]
	match state:
		"glow":
			m.albedo_color = Color("ffd27a")
			m.emission = Color("f2994a")
			m.emission_energy_multiplier = 3.0
		"read":
			m.albedo_color = Color("8fb0c8")
			m.emission = Color("6a8aa8")
			m.emission_energy_multiplier = 0.6
		_:
			m.albedo_color = Color("5a5f6c")
			m.emission_energy_multiplier = 0.0


func _process(delta: float) -> void:
	_t += delta
	if _flame:
		_flame.scale = Vector3.ONE * (1.0 + _lit * 0.35)
		for fi in _flame_cones.size():
			var c := _flame_cones[fi]
			c.rotation.y = _t * (2.0 + fi) * (1.0 if fi % 2 == 0 else -1.0)
			c.scale = Vector3(1.0 + sin(_t * 11.0 + fi) * 0.08, 1.0 + sin(_t * 9.0 + fi * 2.0) * 0.18, 1.0 + cos(_t * 10.0 + fi) * 0.08)
			c.position.x = sin(_t * 6.0 + fi * 1.7) * 0.04 * fi
		for o in _ped_orbs:
			o.position.y = shrine_pos.y + 1.9 + sin(_t * 2.0 + o.position.x) * 0.12
		for i in _altar_glow.size():
			if _altar_glow[i].light_energy > 0.0:
				_altar_glow[i].light_energy = 1.6 + sin(_t * 3.0) * 0.5
		_flame_light.light_energy = 2.4 + sin(_t * 7.0) * 0.3 + sin(_t * 13.0) * 0.2
	if _wisp:
		_wisp.position = shrine_pos + Vector3(2.4 + cos(_t * 1.3) * 0.5, 3.0 + sin(_t * 2.1) * 0.2, -0.6)
		_wisp_rig.tick(delta, 0.0)


# ================================================================ generation
func _noise(seed_v: int, freq: float) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed_v
	n.frequency = freq
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = 3
	return n


## Where a road crosses a river or stream, record a bridge instead of raising a ford.
func _find_bridges() -> void:
	bridges.clear()
	var w := N + 1
	var wet: Array[Vector2i] = []
	for y in N:
		for x in N:
			if path[y * N + x] and _riv[y * w + x] + _riv[y * w + x + 1] + _riv[(y + 1) * w + x] + _riv[(y + 1) * w + x + 1] > 1.2:
				wet.append(Vector2i(x, y))
	var used := {}
	for c0 in wet:
		if used.has(c0):
			continue
		var group: Array[Vector2i] = []
		var stack: Array[Vector2i] = [c0]
		used[c0] = true
		while not stack.is_empty():
			var c: Vector2i = stack.pop_back()
			group.append(c)
			for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
				var n: Vector2i = c + o
				if not used.has(n) and n in wet:
					used[n] = true
					stack.append(n)
		var mean := Vector2.ZERO
		for g in group:
			mean += Vector2(g)
		mean /= group.size()
		# road direction: the main axis of the road cells close to the crossing (a fit, so a bend or a junction
		# further out cannot swing the bridge sideways)
		var sx := 0.0
		var sy := 0.0
		var cnt := 0
		for yy in range(int(mean.y) - 7, int(mean.y) + 8):
			for xx in range(int(mean.x) - 7, int(mean.x) + 8):
				if xx < 0 or yy < 0 or xx >= N or yy >= N or not path[yy * N + xx]:
					continue
				if Vector2(xx, yy).distance_to(mean) > 7.0:
					continue
				sx += xx
				sy += yy
				cnt += 1
		var cen := Vector2(sx, sy) / maxf(float(cnt), 1.0)
		var sxx := 0.0
		var syy := 0.0
		var sxy := 0.0
		for yy in range(int(mean.y) - 7, int(mean.y) + 8):
			for xx in range(int(mean.x) - 7, int(mean.x) + 8):
				if xx < 0 or yy < 0 or xx >= N or yy >= N or not path[yy * N + xx]:
					continue
				if Vector2(xx, yy).distance_to(mean) > 7.0:
					continue
				var dv := Vector2(xx, yy) - cen
				sxx += dv.x * dv.x
				syy += dv.y * dv.y
				sxy += dv.x * dv.y
		var ang := 0.5 * atan2(2.0 * sxy, sxx - syy)
		var dir := Vector2(cos(ang), sin(ang))
		if cnt < 6:
			dir = Vector2(1, 0)
		# a small fan around the road's own direction: the shortest way across the water, but never skewed far
		# from the road (the bridge has to meet it at both ends)
		var best_score := 1e9
		var best_len := 1e9
		var best_dir := dir
		var best_mean := mean
		for k in range(-3, 4):
			var dc := dir.rotated(deg_to_rad(k * 4.0))
			var reach := [0.0, 0.0]
			for si in 2:
				var sgn := 1.0 if si == 0 else -1.0
				var dd := 0.0
				while dd < 24.0:
					var pp: Vector2 = mean + dc * sgn * dd
					var jx := clampi(int(pp.x), 0, N - 1)
					var jy := clampi(int(pp.y), 0, N - 1)
					if _riv[jy * w + jx] < 0.12 and heights[jy * w + jx] > -0.05:
						break
					dd += 0.5
				reach[si] = dd
			var tot: float = reach[0] + reach[1]
			var cand_mean: Vector2 = mean + dc * (float(reach[0]) - float(reach[1])) * 0.5
			var score := tot + absf(k) * 3.5
			if score < best_score and not _bridge_hits_site(cand_mean, dc, tot):
				best_score = score
				best_len = tot
				best_dir = dc
				best_mean = cand_mean
		dir = best_dir
		mean = best_mean
		var half := best_len * 0.5
		# a span that is mostly dry ground does not need a bridge: leave it a ford
		var wet_len := 0.0
		var tt := -minf(half, 30.0)
		while tt <= minf(half, 30.0):
			var qq: Vector2 = mean + dir * tt
			if heights[clampi(int(qq.y), 0, N - 1) * w + clampi(int(qq.x), 0, N - 1)] < -0.05:
				wet_len += 0.5
			tt += 0.5
		if wet_len * CELL < 5.0:
			continue
		var centre := cell_center(roundi(mean.x), roundi(mean.y))
		if half * 2.0 * CELL + 3.0 > 40.0:
			continue   # a stream running along the road, not across it: leave it a ford
		var too_close := false
		for ob: Dictionary in bridges:
			if (ob["pos"] as Vector3).distance_to(centre) < 24.0:
				too_close = true
		if too_close:
			continue
		bridges.append({"pos": centre, "dir": Vector3(dir.x, 0, dir.y), "len": clampf(half * 2.0 * CELL + 3.0, 9.0, 46.0), "cell": mean})


## True when a bridge here would run over an altar, runestone, camp or village.
func _bridge_hits_site(centre: Vector2, dir: Vector2, length: float) -> bool:
	var pts: Array[Vector2] = [Vector2(_camp_cell), Vector2(village_cell), Vector2(CX, CY)]
	for c: Vector2i in boss_cells:
		pts.append(Vector2(c))
	for c: Vector2i in _rune_cells:
		pts.append(Vector2(c))
	for cd: Dictionary in CAMPS:
		pts.append(Vector2(_site(cd["pin"])))
	for sd: Dictionary in SETTLE:
		pts.append(Vector2(_site(sd["pin"])))
	var nrm := Vector2(-dir.y, dir.x)
	for p in pts:
		var v := p - centre
		if absf(v.dot(dir)) < length * 0.5 + 5.0 and absf(v.dot(nrm)) < 8.0:
			return true
	return false


func _in_bridge(x: int, y: int) -> bool:
	for b: Dictionary in bridges:
		if Vector2(x, y).distance_to(b["cell"] as Vector2) < float(b["len"]) / CELL * 0.5 + 1.0:
			return true
	return false


func _build_bridges() -> void:
	var sh := Shader.new()
	sh.code = FLORA_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("sway", 0.0)
	mat.set_shader_parameter("see_through", false)
	var root := Node3D.new()
	root.name = "Bridges"
	add_child(root)
	for b: Dictionary in bridges:
		var dir: Vector3 = b["dir"]
		var ln: float = b["len"]
		var p: Vector3 = b["pos"]
		var e1 := height_at(p.x + dir.x * ln * 0.5, p.z + dir.z * ln * 0.5)
		var e2 := height_at(p.x - dir.x * ln * 0.5, p.z - dir.z * ln * 0.5)
		var deck := maxf(maxf(e1, e2) + 0.1, WATER_Y + 0.55)
		var body := StaticBody3D.new()
		body.collision_layer = 2
		body.position = Vector3(p.x, deck, p.z)
		body.rotation.y = atan2(-dir.z, dir.x)
		root.add_child(body)
		var mi := MeshInstance3D.new()
		mi.mesh = Models.scenery_mesh("bridge", int(ln))
		mi.material_override = mat
		body.add_child(mi)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(ln, 0.3, 2.8)
		cs.shape = bs
		cs.position = Vector3(0, -0.15, 0)
		body.add_child(cs)
		for sd in [-1.0, 1.0]:
			var rs := CollisionShape3D.new()
			var rb := BoxShape3D.new()
			rb.size = Vector3(ln, 1.0, 0.15)
			rs.shape = rb
			rs.position = Vector3(0, 0.5, sd * 1.4)
			body.add_child(rs)
		# keep trees and ore off the approach
		var c: Vector2 = b["cell"]
		var rr := int(ln / CELL * 0.5) + 3
		for yy in range(int(c.y) - rr, int(c.y) + rr + 1):
			for xx in range(int(c.x) - rr, int(c.x) + rr + 1):
				if xx >= 0 and yy >= 0 and xx < N and yy < N and Vector2(xx - c.x, yy - c.y).length() <= rr:
					clear[yy * N + xx] = 1


const STREAM_BED := -0.4
const STREAM_COUNT := 16


## Small tributaries that wander from the hills down into the nearest river.
func _carve_streams() -> void:
	var w := N + 1
	var rng := RandomNumberGenerator.new()
	rng.seed = 6161
	var targets: Array[Vector2] = []
	for line: Array in river_lines:
		for i in range(8, line.size(), 4):
			targets.append(line[i])
	var camp_c := Vector2(_camp_cell)
	var made := 0
	var tries := 0
	while made < STREAM_COUNT and tries < 4000 and not targets.is_empty():
		tries += 1
		var sx := rng.randi_range(40, N - 40)
		var sy := rng.randi_range(40, N - 40)
		var si := sy * N + sx
		if _biome_xy(sx + 0.5, sy + 0.5) > 2 or clear[si] or path[si]:
			continue
		var s := Vector2(sx, sy)
		if s.distance_to(Vector2(CX, CY)) < TOWN_CELLS + 24 or s.distance_to(camp_c) < 22:
			continue
		var best := Vector2.ZERO
		var bd := 1e9
		for t in targets:
			var dd := s.distance_to(t)
			if dd < bd:
				bd = dd
				best = t
		if bd < 22.0 or bd > 75.0:
			continue
		if heights[sy * w + sx] < 0.2:
			continue
		var dir := (best - s).normalized()
		var perp := Vector2(-dir.y, dir.x)
		var phase := rng.randf() * TAU
		var amp := rng.randf_range(3.0, 7.0)
		var steps := int(bd / 0.6)
		var ok := true
		var pts: Array[Vector2] = []
		for k in steps + 1:
			var t := float(k) / steps
			var c := s.lerp(best, t) + perp * (sin(t * 7.0 + phase) * amp * sin(t * PI) + _shape.get_noise_2d(t * 30.0, made * 50.0) * 3.0 * sin(t * PI))
			var ci := clampi(roundi(c.y), 0, N - 1) * N + clampi(roundi(c.x), 0, N - 1)
			if clear[ci] and t > 0.05 and Vector2(c.x - CX, c.y - CY).length() < TOWN_CELLS + 14:
				ok = false
				break
			pts.append(c)
		if not ok:
			continue
		# the first streams are chosen to cut across a road, so there are bridges to build
		var crosses := false
		for c in pts:
			if path[clampi(roundi(c.y), 0, N - 1) * N + clampi(roundi(c.x), 0, N - 1)]:
				crosses = true
				break
		if made < 9 and not crosses:
			continue
		var n := pts.size()
		for i in n:
			var t := float(i) / (n - 1)
			var wd := lerpf(0.8, 1.5, t) + (maxf(0.0, 8.0 - i) * 0.1)
			var c: Vector2 = pts[i]
			var reach := int(wd + 5.0)
			var cx0 := roundi(c.x)
			var cy0 := roundi(c.y)
			for y in range(cy0 - reach, cy0 + reach + 1):
				for x in range(cx0 - reach, cx0 + reach + 1):
					if x < 0 or y < 0 or x > N or y > N:
						continue
					var d := Vector2(x - c.x, y - c.y).length()
					var bank := 2.0
					if d > wd + bank:
						continue
					var k := 1.0 - smoothstep(wd, wd + bank, d)
					var idx := y * w + x
					var h := heights[idx]
					heights[idx] = minf(h, lerpf(h, STREAM_BED, smoothf(k)))
					if k > _riv[idx]:
						_riv[idx] = k
		stream_lines.append(pts)
		made += 1


func smoothf(k: float) -> float:
	return k * k * (3.0 - 2.0 * k)


# ================================================================ island shape and biome patches
const GS := 4                         # coarse field step (cells)
const ISL_A := 600.0                  # island half-length (cells), along its long axis
const ISL_B := 270.0                  # island half-width
const ISL_PHI := -0.64                # long axis points north-east
const ISL_OFF := Vector2(90.0, -70.0) # the island's middle sits north-east of the town
const VILLAGE_OFF := Vector2(250.0, -230.0)   # Ashford, in cells from the shrine
const VILLAGE_R := 24.0
const SAFE_R := 190.0                 # cells of pure meadow around Hearthmoor (about 380 m)
var _tier_n: FastNoiseLite
var _cst_n: FastNoiseLite
var _gw := 0
var _tf := PackedFloat32Array()       # difficulty tier as a float (0 meadow .. 3 peaks), coarse grid
var _ce := PackedFloat32Array()       # coast value: land below ~0.95, sea above 1.0, coarse grid
var _pc_lab := PackedInt32Array()     # patch label per coarse node (-1 = sea)
var _pc_edt := PackedFloat32Array()   # distance (nodes) from the patch edge
var _pc_size: Array = []
var _pc_bio: Array = []
var _dclear := PackedFloat32Array()   # coarse distance (cells) to roads / cleared ground
var _spots := {}                      # id -> cell for quest givers and elites
var _course_cells: Array[Vector2i] = []
var _rune_cells: Array[Vector2i] = []
var boss_cells: Array[Vector2i] = []
var village_cell := Vector2i.ZERO
var village_pos := Vector3.ZERO
var village: Node3D


func _samp(a: PackedFloat32Array, x: float, y: float) -> float:
	var fx := clampf(x / GS, 0.0, _gw - 1.001)
	var fy := clampf(y / GS, 0.0, _gw - 1.001)
	var ix := int(fx)
	var iy := int(fy)
	var tx := fx - ix
	var ty := fy - iy
	var i := iy * _gw + ix
	return lerpf(lerpf(a[i], a[i + 1], tx), lerpf(a[i + _gw], a[i + _gw + 1], tx), ty)


## 0..3 for the four land biomes (from the painted zone), 4 for the beach strip, from the coarse fields.
func _biome_xy(x: float, y: float) -> int:
	# the town and its walls are all meadow, whatever the painted plan says out there
	if Vector2(x - CX, y - CY).length() < TOWN_CELLS - 2.0:
		return 0
	if _samp(_ce, x, y) > 0.955:
		return 4
	var gx := clampi(roundi(x / GS), 0, _gw - 1)
	var gy := clampi(roundi(y / GS), 0, _gw - 1)
	return int(_zb[gy * _gw + gx])


var _tfs := PackedFloat32Array()      # _tf blurred, so terrain height rolls smoothly between biomes
var _warp: Array[FastNoiseLite] = []


var _zb := PackedByteArray()          # biome per coarse node, from the painted zones
var _zn := PackedByteArray()          # zone index per coarse node
var _hb := PackedFloat32Array()       # coarse terrain base height
var _ha := PackedFloat32Array()       # coarse terrain roughness
var _hm := PackedFloat32Array()       # coarse mountain weight
var _hw := PackedFloat32Array()       # coarse inland water weight
var _hsh := PackedFloat32Array()      # coarse "shallow water" weight (fen and delta are wadeable)
var _hrk := PackedFloat32Array()      # coarse rock weight
var _hsn := PackedFloat32Array()      # coarse snow weight
var lay: LayoutMap
const ZONE_BASE := [0.8, 1.1, 0.9, 1.5, 2.0, 0.28, 0.25, 3.0, 5.0]
const ZONE_AMP := [0.6, 0.9, 0.8, 1.8, 2.6, 0.12, 0.1, 2.2, 3.0]
const ZONE_MTN := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.25, 1.0]
const ZONE_SHALLOW := [0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 0.0, 0.0]


func _build_fields() -> void:
	lay = LayoutMap.new()
	_gw = N / GS + 1
	var n := _gw * _gw
	_tf.resize(n)
	_tfs.resize(n)
	_ce.resize(n)
	_zb.resize(n)
	_zn.resize(n)
	var hb := PackedFloat32Array()
	var ha := PackedFloat32Array()
	var hm := PackedFloat32Array()
	var hsh := PackedFloat32Array()
	for a: PackedFloat32Array in [hb, ha, hm, hsh]:
		a.resize(n)
	_hw.resize(n)
	_hrk.resize(n)
	_hsn.resize(n)
	for gy in _gw:
		for gx in _gw:
			var x := float(gx * GS)
			var y := float(gy * GS)
			var i := gy * _gw + gx
			var s := lay.samp(lay.sea, x, y, 1.0)
			_ce[i] = 0.5 + 0.9 * s
			var z := lay.zone_at(x, y)
			if z < 0:
				z = 1
			_zn[i] = z
			var bz: int = Data.ZONES[z]["biome"]
			_zb[i] = bz
			_tf[i] = float(bz)
			hb[i] = ZONE_BASE[z]
			ha[i] = ZONE_AMP[z]
			hm[i] = ZONE_MTN[z]
			hsh[i] = ZONE_SHALLOW[z]
			_hw[i] = lay.samp(lay.inl, x, y)
			_hrk[i] = lay.samp(lay.rock, x, y)
			_hsn[i] = lay.samp(lay.snow, x, y)
	_tfs = _blur(_tf)
	_hb = _blur(hb)
	_ha = _blur(ha)
	_hm = _blur(hm)
	_hsh = _blur(hsh)
	_hrk = _blur(_hrk, 1)
	_hsn = _blur(_hsn, 1)
	village_cell = lay.pin("ashford")
	_camp_cell = lay.pin("wanderers_rest")


func _blur(src: PackedFloat32Array, passes := 3) -> PackedFloat32Array:
	var a := src.duplicate()
	var b := a.duplicate()
	for pass_i in passes:
		for gy in _gw:
			for gx in _gw:
				var sm := 0.0
				for ox in range(-3, 4):
					sm += a[gy * _gw + clampi(gx + ox, 0, _gw - 1)]
				b[gy * _gw + gx] = sm / 7.0
		for gy in _gw:
			for gx in _gw:
				var sm := 0.0
				for oy in range(-3, 4):
					sm += b[clampi(gy + oy, 0, _gw - 1) * _gw + gx]
				a[gy * _gw + gx] = sm / 7.0
	return a


## Label each connected patch of one biome on the coarse grid and measure how deep inside its patch each node is.
func _patch_graph() -> void:
	var n := _gw * _gw
	_pc_lab.resize(n)
	_pc_lab.fill(-1)
	var bio := PackedByteArray()
	bio.resize(n)
	for gy in _gw:
		for gx in _gw:
			var x := float(gx * GS)
			var y := float(gy * GS)
			var i := gy * _gw + gx
			bio[i] = 255 if _ce[i] > 0.9 else _biome_xy(x, y)
	_pc_size.clear()
	_pc_bio.clear()
	for s in n:
		if bio[s] == 255 or _pc_lab[s] != -1:
			continue
		var id := _pc_size.size()
		var stack: Array[int] = [s]
		_pc_lab[s] = id
		var cnt := 0
		while not stack.is_empty():
			var c: int = stack.pop_back()
			cnt += 1
			var cx := c % _gw
			var cy := c / _gw
			for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = cx + o.x
				var ny: int = cy + o.y
				if nx < 0 or ny < 0 or nx >= _gw or ny >= _gw:
					continue
				var ni := ny * _gw + nx
				if _pc_lab[ni] == -1 and bio[ni] == bio[s]:
					_pc_lab[ni] = id
					stack.append(ni)
		_pc_size.append(cnt)
		_pc_bio.append(int(bio[s]))
	# breadth-first distance from each patch edge
	_pc_edt.resize(n)
	_pc_edt.fill(-1.0)
	var queue: Array[int] = []
	for i in n:
		if _pc_lab[i] == -1:
			continue
		var cx := i % _gw
		var cy := i / _gw
		var edge := false
		for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: int = cx + o.x
			var ny: int = cy + o.y
			if nx < 0 or ny < 0 or nx >= _gw or ny >= _gw or _pc_lab[ny * _gw + nx] != _pc_lab[i]:
				edge = true
		if edge:
			_pc_edt[i] = 0.0
			queue.append(i)
	var qi := 0
	while qi < queue.size():
		var c := queue[qi]
		qi += 1
		var cx := c % _gw
		var cy := c / _gw
		for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: int = cx + o.x
			var ny: int = cy + o.y
			if nx < 0 or ny < 0 or nx >= _gw or ny >= _gw:
				continue
			var ni := ny * _gw + nx
			if _pc_lab[ni] == _pc_lab[c] and _pc_edt[ni] < 0.0:
				_pc_edt[ni] = _pc_edt[c] + 1.0
				queue.append(ni)


## A cell deep inside a patch of this biome, between dmin and dmax cells from the town and clear of
## the cells in `used`. `largest` restricts the search to the biggest patch that can satisfy it.
func _pick_in_biome(b: int, dmin: float, dmax: float, rng: RandomNumberGenerator, used: Array, largest := false, min_edt := 3.0) -> Vector2i:
	for relax in 4:
		var f := 1.0 + relax * 0.45
		var lo := dmin / f
		var hi := dmax * f
		var me := maxf(1.0, min_edt - relax)
		var cands: Array = []
		var comp_ok := {}
		for i in _gw * _gw:
			var lab := _pc_lab[i]
			if lab < 0 or int(_pc_bio[lab]) != b or _pc_edt[i] < me:
				continue
			var x := (i % _gw) * GS
			var y := (i / _gw) * GS
			var d := Vector2(x - CX, y - CY).length()
			if d < lo or d > hi:
				continue
			var near := false
			for u: Vector2i in used:
				if Vector2(x - u.x, y - u.y).length() < 50.0:
					near = true
					break
			if near:
				continue
			cands.append(i)
			comp_ok[lab] = true
		if cands.is_empty():
			continue
		if largest:
			var best_lab := -1
			for lab: int in comp_ok:
				if best_lab == -1 or int(_pc_size[lab]) > int(_pc_size[best_lab]):
					best_lab = lab
			var bi := -1
			for i: int in cands:
				if _pc_lab[i] == best_lab and (bi == -1 or _pc_edt[i] > _pc_edt[bi]):
					bi = i
			return Vector2i((bi % _gw) * GS, (bi / _gw) * GS)
		var pick: int = cands[rng.randi() % cands.size()]
		return Vector2i((pick % _gw) * GS, (pick / _gw) * GS)
	return Vector2i(-1, -1)


## Decide where the bosses, quest givers, elites and agility courses go: each one sits at a spot on the painted plan.
func _choose_sites() -> void:
	boss_cells.clear()
	_rune_cells.clear()
	for i in 4:
		var c := _land_near(lay.pin("warden%d" % i), 40)
		boss_cells.append(c)
		# the runestone stands on the way back toward town, a short way before the altar
		var to_town := (Vector2(CX, CY) - Vector2(c)).normalized()
		_rune_cells.append(_land_near(Vector2i(Vector2(c) + to_town * 13.0), 14))
	_spots.clear()
	_spots["hollis"] = _land_near(lay.pin("tallowmere") + Vector2i(7, 6), 20)
	_spots["oswin"] = _land_near(lay.pin("sunkettle") + Vector2i(7, 6), 20)
	_spots["aldric"] = _land_near(lay.pin("pilgrims_rest") + Vector2i(7, 5), 20)
	_spots["alpha"] = _land_near(lay.pin("blackbriar_lodge") + Vector2i(-30, 12), 30)
	_spots["champion"] = _land_near(lay.pin("rimewatch") + Vector2i(-28, 24), 30)
	_spots["maren"] = village_cell + Vector2i(3, 5)
	_spots["peg"] = _land_near(_site("campwater_landing") + Vector2i(7, 6), 20)
	_spots["corwin"] = _land_near(_site("blackbriar_lodge") + Vector2i(7, 6), 20)
	_spots["dunn"] = _land_near(_site("bellwharf") + Vector2i(7, 6), 20)
	_spots["ysolt"] = _land_near(_site("greyfold_steading") + Vector2i(7, 6), 20)
	_spots["barrowking"] = _land_near(lay.pin("keep_ruin") + Vector2i(6, 8), 20)
	_camp_cell = _land_near(lay.pin("wanderers_rest"), 30)
	_course_cells.clear()
	for uv: Vector2 in [Vector2(0.30, 0.64), Vector2(0.80, 0.62), Vector2(0.80, 0.21)]:
		var cc := lay.uv_cell(uv)
		_course_cells.append(_land_near(Vector2i(roundi(cc.x), roundi(cc.y)), 50))


func _land_ok(x: int, y: int) -> bool:
	return _samp(_ce, x, y) < 0.78 and _samp(_hw, x, y) < 0.2


## The nearest dry land cell to `c` within `rad` cells.
var _site_adj := {}


func _site(pin_name: String) -> Vector2i:
	if _site_adj.has(pin_name):
		return _site_adj[pin_name]
	return _land_near(lay.pin(pin_name), 16)


## How far (metres) a spot is from the nearest bridge, counting the bridge's own length.
func _bridge_gap(cell: Vector2i) -> float:
	var p := cell_center(cell.x, cell.y)
	var best := 1e9
	for b: Dictionary in bridges:
		var bp: Vector3 = b["pos"]
		best = minf(best, Vector2(p.x - bp.x, p.z - bp.z).length() - float(b["len"]) * 0.5)
	return best


## Camps must not sit on a bridge or its approach: slide them to the nearest dry spot clear of one.
func _adjust_sites() -> void:
	_site_adj.clear()
	for cd: Dictionary in CAMPS:
		var c := _site(cd["pin"])
		if _bridge_gap(c) >= 18.0:
			continue
		var done := false
		for r in range(4, 48, 3):
			if done:
				break
			for k in 16:
				var a := k * TAU / 16.0
				var q := Vector2i(c.x + roundi(cos(a) * r), c.y + roundi(sin(a) * r))
				if q.x < 14 or q.y < 14 or q.x > N - 14 or q.y > N - 14 or not _land_ok(q.x, q.y):
					continue
				if _riv[q.y * (N + 1) + q.x] > 0.05 or path[q.y * N + q.x] or _bridge_gap(q) < 18.0:
					continue
				_site_adj[cd["pin"]] = q
				_flatten(q, 9.0)
				done = true
				break


func _land_near(c: Vector2i, rad: int) -> Vector2i:
	if _land_ok(c.x, c.y):
		return c
	for r in range(2, rad + 1, 2):
		for k in 16:
			var a := k * TAU / 16.0
			var q := Vector2i(c.x + roundi(cos(a) * r), c.y + roundi(sin(a) * r))
			if q.x > 12 and q.y > 12 and q.x < N - 12 and q.y < N - 12 and _land_ok(q.x, q.y):
				return q
	return c


## Last resort when no patch of a biome fits: paint a patch of it near a land spot at roughly this distance.
func _fallback_cell(b: int, d: float) -> Vector2i:
	for k in 360:
		var a := k * 0.7
		var c := Vector2i(roundi(CX + cos(a) * d), roundi(CY + sin(a) * d))
		if c.x < 30 or c.y < 30 or c.x > N - 30 or c.y > N - 30:
			continue
		if _samp(_ce, c.x, c.y) < 0.7:
			_force_patch(c, 36.0, float(b))
			return c
	return Vector2i(CX + int(d), CY)


func _force_patch(c: Vector2i, rad: float, tier: float) -> void:
	for gy in _gw:
		for gx in _gw:
			var d := Vector2(gx * GS - c.x, gy * GS - c.y).length()
			if d < rad * 1.6:
				var k := 1.0 - smoothstep(rad * 0.7, rad * 1.6, d)
				_tf[gy * _gw + gx] = lerpf(_tf[gy * _gw + gx], tier, k)
				_tfs[gy * _gw + gx] = lerpf(_tfs[gy * _gw + gx], tier, k)


## Coarse distance (in cells) from each node to a road or cleared patch, refreshed on demand.
func _update_dclear() -> void:
	_dclear.resize(_gw * _gw)
	for gy in _gw:
		for gx in _gw:
			var x := mini(gx * GS, N - 1)
			var y := mini(gy * GS, N - 1)
			var hit := false
			for oy in [0, 1, 2, 3]:
				for ox in [0, 1, 2, 3]:
					var cx := mini(x + ox, N - 1)
					var cy := mini(y + oy, N - 1)
					if clear[cy * N + cx] or path[cy * N + cx]:
						hit = true
			_dclear[gy * _gw + gx] = 0.0 if hit else 999.0
	for gy in _gw:
		for gx in _gw:
			var i := gy * _gw + gx
			var v := _dclear[i]
			if gx > 0:
				v = minf(v, _dclear[i - 1] + 1.0)
			if gy > 0:
				v = minf(v, _dclear[i - _gw] + 1.0)
				if gx > 0:
					v = minf(v, _dclear[i - _gw - 1] + 1.414)
				if gx < _gw - 1:
					v = minf(v, _dclear[i - _gw + 1] + 1.414)
			_dclear[i] = v
	for gy in range(_gw - 1, -1, -1):
		for gx in range(_gw - 1, -1, -1):
			var i := gy * _gw + gx
			var v := _dclear[i]
			if gx < _gw - 1:
				v = minf(v, _dclear[i + 1] + 1.0)
			if gy < _gw - 1:
				v = minf(v, _dclear[i + _gw] + 1.0)
				if gx < _gw - 1:
					v = minf(v, _dclear[i + _gw + 1] + 1.414)
				if gx > 0:
					v = minf(v, _dclear[i + _gw - 1] + 1.414)
			_dclear[i] = v


func _dclear_at(x: int, y: int) -> float:
	return _dclear[clampi(y / GS, 0, _gw - 1) * _gw + clampi(x / GS, 0, _gw - 1)] * GS


func _build_heights() -> void:
	var w := N + 1
	heights.resize(w * w)
	# how far (in coarse nodes) each spot is from the painted rivers, lakes and fen: hills ease off towards water
	var gw := _gw
	var wd := PackedFloat32Array()
	wd.resize(gw * gw)
	for i in gw * gw:
		wd[i] = 0.0 if _hw[i] > 0.25 else 99.0
	for y in gw:
		for x in gw:
			var i := y * gw + x
			var d := wd[i]
			if x > 0:
				d = minf(d, wd[i - 1] + 1.0)
			if y > 0:
				d = minf(d, wd[i - gw] + 1.0)
				if x > 0:
					d = minf(d, wd[i - gw - 1] + 1.414)
				if x < gw - 1:
					d = minf(d, wd[i - gw + 1] + 1.414)
			wd[i] = d
	for y in range(gw - 1, -1, -1):
		for x in range(gw - 1, -1, -1):
			var i := y * gw + x
			var d := wd[i]
			if x < gw - 1:
				d = minf(d, wd[i + 1] + 1.0)
			if y < gw - 1:
				d = minf(d, wd[i + gw] + 1.0)
				if x < gw - 1:
					d = minf(d, wd[i + gw + 1] + 1.414)
				if x > 0:
					d = minf(d, wd[i + gw - 1] + 1.414)
			wd[i] = d
	for vy in w:
		for vx in w:
			var e := _samp(_ce, vx, vy)
			if e > 1.03:
				heights[vy * w + vx] = -2.6
				continue
			var base := _samp(_hb, vx, vy)
			var amp := _samp(_ha, vx, vy)
			var h := base + _hill.get_noise_2d(vx, vy) * amp
			h += _roll.get_noise_2d(vx, vy) * (0.5 + amp * 0.5)
			# broad relief: hills, basins and highland ridges. The start area stays gentle, fen and coast stay low and flat.
			var dtown := Vector2(vx - CX, vy - CY).length()
			var inland := smoothstep(0.9, 0.55, e)
			var bk: float = [0.9, 1.0, 0.18, 0.55, 0.2][_biome_xy(vx, vy)]
			var relief := lerpf(0.3, 1.0, smoothstep(SAFE_R * 0.35, SAFE_R * 1.0, dtown)) * bk * inland * relief_scale * smoothstep(1.0, 9.0, _samp(wd, vx, vy))
			var hills := _macro.get_noise_2d(vx, vy) * 12.0 + _macro2.get_noise_2d(vx, vy) * 4.0 + 2.0
			var hi := smoothstep(0.02, 0.5, _hi.get_noise_2d(vx, vy))
			hills += hi * (7.0 + pow((_hir.get_noise_2d(vx, vy) + 1.0) * 0.5, 2.0) * 20.0)
			if hills < 0.0:
				hills *= 0.35 * lerpf(0.15, 1.0, smoothstep(SAFE_R * 1.2, SAFE_R * 2.4, dtown))
			h += hills * relief
			var mt := _samp(_hm, vx, vy)
			if mt > 0.0:
				var rg := (_ridge.get_noise_2d(vx, vy) + 1.0) * 0.5
				var mask := smoothstep(0.1, 0.5, _mtn.get_noise_2d(vx + 400, vy - 300))
				h += pow(maxf(0.0, rg - 0.5) / 0.5, 1.4) * 13.0 * mt * (0.35 + 0.65 * mask)
			# the painted rock outcrops and snowfields stand up out of the land
			var rk := _samp(_hrk, vx, vy)
			h += rk * (1.2 + (_hill.get_noise_2d(vx * 2.0, vy * 2.0) + 1.0) * 1.1)
			h += _samp(_hsn, vx, vy) * 3.0
			# rivers, fen and delta water
			var wv := _samp(_hw, vx, vy)
			if wv > 0.05:
				var depth := lerpf(-1.9, -0.75, _samp(_hsh, vx, vy))
				h = lerpf(h, depth, smoothstep(0.22, 0.6, wv))
			h = lerpf(-2.6, h, smoothstep(1.0, 0.93, e))
			heights[vy * w + vx] = h
	path.resize(N * N)
	clear.resize(N * N)


func _classify() -> void:
	var w := N + 1
	ground.resize(N * N)
	biome.resize(N * N)
	for y in N:
		for x in N:
			var h00 := heights[y * w + x]
			var h10 := heights[y * w + x + 1]
			var h01 := heights[(y + 1) * w + x]
			var h11 := heights[(y + 1) * w + x + 1]
			if h00 < -2.5 and h10 < -2.5 and h01 < -2.5 and h11 < -2.5:
				ground[y * N + x] = G.WATER
				biome[y * N + x] = 4
				continue
			var avg := (h00 + h10 + h01 + h11) * 0.25
			var slope := maxf(maxf(h00, h10), maxf(h01, h11)) - minf(minf(h00, h10), minf(h01, h11))
			var b := _biome_xy(x + 0.5, y + 0.5)
			var g: int
			if avg < WATER_Y - 0.1:
				g = G.WATER
			elif b == 4 or (b <= 1 and avg < 0.32) or (slope < 1.3 and _samp(_ce, x + 0.5, y + 0.5) > 0.84):
				g = G.SAND
			elif b <= 2 and _riv[y * w + x] + _riv[y * w + x + 1] + _riv[(y + 1) * w + x] + _riv[(y + 1) * w + x + 1] > 0.5 and slope < 1.4:
				g = G.SAND
			elif b >= 1 and b <= 2 and avg > 7.0:
				g = G.ROCK if slope > 1.6 else G.SNOW
			elif b == 3:
				var zi := int(_zn[clampi(roundi((y + 0.5) / GS), 0, _gw - 1) * _gw + clampi(roundi((x + 0.5) / GS), 0, _gw - 1)])
				if zi == 7:
					g = G.ROCK if slope > 1.5 else (G.SNOW if avg > 7.0 else G.GRASS)
				else:
					g = G.ROCK if slope > 1.7 else G.SNOW
			elif slope > 2.2:
				g = G.ROCK
			elif b == 0:
				g = G.GRASS
			elif b == 1:
				g = G.FOREST
			else:
				g = G.BOG if _bog.get_noise_2d(x + 0.5, y + 0.5) > 0.15 else G.MUD
			ground[y * N + x] = g
			biome[y * N + x] = b


## Rivers, the fen and the delta come straight from the painted plan; so do its roads.
func _carve_rivers() -> void:
	var w := N + 1
	_riv.resize(w * w)
	_riv.fill(0.0)
	river_lines.clear()
	stream_lines.clear()
	for vy in w:
		for vx in w:
			_riv[vy * w + vx] = smoothstep(0.15, 0.7, _samp(_hw, vx, vy))
			if Vector2(vx - CX, vy - CY).length() < TOWN_CELLS - 2.0:
				_riv[vy * w + vx] = 0.0   # no stream runs through the town
	for j in LayoutData.PY:
		for i in LayoutData.PX:
			if lay.road[j * LayoutData.PX + i] == 0:
				continue
			var c := lay.uv_cell(Vector2((i + 0.5) / LayoutData.PX, (j + 0.5) / LayoutData.PY))
			var x := int(c.x)
			var y := int(c.y)
			for oy in 2:
				for ox in 2:
					var xx := x + ox
					var yy := y + oy
					if xx >= 0 and yy >= 0 and xx < N and yy < N:
						path[yy * N + xx] = 1
						clear[yy * N + xx] = 1


func _place_sites() -> void:
	var w := N + 1
	for i in boss_cells.size():
		_carve(_rune_cells[i], boss_cells[i], i * 7 + 3)
		_flatten(_rune_cells[i], 2.0)
		_flatten(boss_cells[i], 5.0)
	_flatten(Vector2i(CX, CY), TOWN_CELLS)
	_flatten(village_cell, VILLAGE_R)
	for k: String in _spots:
		if k != "maren":
			_flatten(_spots[k], 3.0 if Data.ELITES.has(k) else 2.0)
	for cc in _course_cells:
		_flatten(cc, COURSE_R + 2.0)
	for sd: Dictionary in SETTLE:
		_flatten(_site(sd["pin"]), float(sd["flat"]))
	for cd: Dictionary in CAMPS:
		_flatten(_site(cd["pin"]), 9.0)
	for fl: Dictionary in FIXED_LM:
		_flatten(lay.pin(fl["pin"]), 7.0)
	_carve_camp()
	_carve_rivers()
	_paint_town_streets()
	_find_bridges()
	_adjust_sites()
	# path cells must stay above water, except where a bridge spans the water
	for y in N:
		for x in N:
			if path[y * N + x] and not _in_bridge(x, y):
				for c: Vector2i in [Vector2i(x, y), Vector2i(x + 1, y), Vector2i(x, y + 1), Vector2i(x + 1, y + 1)]:
					var i := c.y * w + c.x
					heights[i] = maxf(heights[i], 0.3)
	# record positions now that heights are final
	shrine_pos = cell_center(CX, CY)
	var spots := _spots.duplicate()
	for q: Dictionary in Data.SIDE_QUESTS:
		if q.has("town"):
			continue
		npc_pos[q["id"]] = cell_center(spots[q["id"]].x, spots[q["id"]].y)
	for k: String in Data.ELITES:
		npc_pos[k] = cell_center(spots[k].x, spots[k].y)
	for q: Dictionary in Data.SIDE_QUESTS:
		if q.has("town"):
			var off: Array = q["town"]
			npc_pos[q["id"]] = _ground(shrine_pos + Vector3(off[0], 0, off[1]))
	village_pos = cell_center(village_cell.x, village_cell.y)
	forge_pos = shrine_pos + Vector3(7.5, 0, 2.5)
	forge_pos.y = height_at(forge_pos.x, forge_pos.z)
	merchant_pos = shrine_pos + Vector3(-7.5, 0, 2.5)
	merchant_pos.y = height_at(merchant_pos.x, merchant_pos.z)
	alchemy_pos = _ground(shrine_pos + Vector3(-6.0, 0, 8.0))
	bench_pos = _ground(shrine_pos + Vector3(6.0, 0, 8.0))
	furnace_pos = _ground(shrine_pos + Vector3(11.5, 0, -2.0))
	anvil_pos = _ground(shrine_pos + Vector3(11.5, 0, 6.5))
	slayer_pos = _ground(shrine_pos + Vector3(6.5, 0, -6.0))
	campfires.append(_ground(shrine_pos + Vector3(-6.5, 0, -6.5)))
	camp_pos = cell_center(_camp_cell.x, _camp_cell.y)
	camp_pos.y = height_at(camp_pos.x, camp_pos.z)
	campfires.append(camp_pos)
	camp_bench_pos = _ground(camp_pos + Vector3(4.2, 0, 3.6))
	rack_pos = _ground(camp_pos + Vector3(2.0, 0, -6.0))
	camp_pond = _ground(camp_pos + CAMP_POND_OFF)
	var to_camp := Vector3(-CAMP_POND_OFF.x, 0, -CAMP_POND_OFF.z).normalized()
	camp_fish_pos = camp_pond + to_camp * 3.5
	camp_fish_pos.y = WATER_Y
	npc_pos["tam"] = _ground(camp_pos + Vector3(2.4, 0, -1.2))
	for q: Dictionary in Data.SIDE_QUESTS:
		if q.has("town"):
			continue
		var qp: Vector3 = npc_pos[q["id"]]
		campfires.append(_ground(qp + Vector3(2.6, 0, 2.2)))
	for ci in _course_cells.size():
		var center := cell_center(_course_cells[ci].x, _course_cells[ci].y)
		var gates: Array[Vector3] = []
		for g in 6:
			var a := g * TAU / 6.0
			gates.append(_ground(center + Vector3(cos(a), 0, sin(a)) * COURSE_R * CELL))
		courses.append({"i": ci, "center": center, "gates": gates})
	for i in boss_cells.size():
		rune_pos.append(cell_center(_rune_cells[i].x, _rune_cells[i].y))
		altar_pos.append(cell_center(boss_cells[i].x, boss_cells[i].y))


func _place_fish() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	fish_spots.append({"pos": camp_fish_pos, "biome": 0})
	var cand: Array = []
	for y in range(2, N - 2, 2):
		for x in range(2, N - 2, 2):
			if ground[y * N + x] != G.WATER:
				continue
			var shore := false
			for d: Vector2i in [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)]:
				var gi := (y + d.y) * N + x + d.x
				if ground[gi] != G.WATER:
					shore = true
			if shore:
				cand.append(Vector2i(x, y))
	cand.shuffle()
	var per_biome := {}
	for c: Vector2i in cand:
		var b: int = biome[c.y * N + c.x]
		if int(per_biome.get(b, 0)) >= (36 if b == 4 else 21):
			continue
		var p := cell_center(c.x, c.y)
		p.y = WATER_Y
		var ok := true
		for f: Dictionary in fish_spots:
			if (f["pos"] as Vector3).distance_to(p) < (12.0 if b == 2 else 22.0):
				ok = false
				break
		if ok:
			fish_spots.append({"pos": p, "biome": b})
			per_biome[b] = int(per_biome.get(b, 0)) + 1


# ================================================================ Wanderer's Rest (the starting camp)
const CAMP_POND_OFF := Vector3(8.0, 0.0, 14.0)   # pond centre, metres from the camp fire
var _camp_cell := Vector2i(CX + 9, CY + 44)       # south of Hearthmoor, just east of the old south road


## Flat clearing, a little pond to fish in, and a dirt track out to the road.
func _carve_camp() -> void:
	var c := _camp_cell
	_flatten(c, 7.0)
	var w := N + 1
	var pcx := c.x + 0.5 + CAMP_POND_OFF.x / CELL
	var pcy := c.y + 0.5 + CAMP_POND_OFF.z / CELL
	for vy in range(int(pcy) - 6, int(pcy) + 7):
		for vx in range(int(pcx) - 6, int(pcx) + 7):
			if vx < 0 or vy < 0 or vx > N or vy > N:
				continue
			var d := Vector2(vx - pcx, vy - pcy).length()
			var k := 1.0 - smoothstep(1.5, 3.5, d)
			heights[vy * w + vx] = lerpf(heights[vy * w + vx], -0.9, k)
			if d < 4.5 and vx < N and vy < N:
				clear[vy * N + vx] = 1
	_carve(Vector2i(c.x + 1, c.y - 3), Vector2i(c.x + 1, c.y - 14), 91)


## Brush to gather twigs from and a few oaks to chop, all within a short walk of the fire.
func _place_camp_resources() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 31337
	var spots: Array[Vector3] = []
	for pass_i in 2:
		var mat := "twig" if pass_i == 0 else "oak"
		var want := 18 if pass_i == 0 else 4
		var sep := 3.2 if pass_i == 0 else 2.8
		var got := 0
		var tries := 0
		while got < want and tries < 400:
			tries += 1
			var a := rng.randf() * TAU
			var d := rng.randf_range(8.5, 15.5) if pass_i == 0 else rng.randf_range(9.5, 16.0)
			var p := camp_pos + Vector3(cos(a), 0, sin(a)) * d
			if is_water(p.x, p.z) or Vector2(p.x - camp_pond.x, p.z - camp_pond.z).length() < 9.0:
				continue
			if Vector2(p.x - camp_bench_pos.x, p.z - camp_bench_pos.z).length() < 3.0:
				continue
			var ok := true
			for q: Vector3 in spots:
				if Vector2(p.x - q.x, p.z - q.z).length() < sep:
					ok = false
					break
			if not ok:
				continue
			p.y = height_at(p.x, p.z)
			spots.append(p)
			resource_spots.append({"pos": p, "mat": mat})
			got += 1


func _build_camp() -> void:
	var camp := TownKit.camp("meadow", 5150, "tutorial")
	camp.name = "WanderersRest"
	add_child(camp)
	camp.global_position = camp_pos
	# the King holds court in front of his throne, inside the keep
	var kp := shrine_pos + Vector3(0, 0, -6.0)
	for tb: Dictionary in town_buildings:
		if tb["kind"] == "keep":
			var fwd := Vector3(sin(tb["yaw"]), 0, cos(tb["yaw"]))
			kp = (tb["pos"] as Vector3) - fwd * 2.6 * float(tb.get("scale", 1.0))
			break
	npc_pos["king"] = _ground(kp)


## Hearthmoor, the starter town, built around the shrine. The plaza is left open for the
## merchant, forge, crafting stations and quest givers; houses, the tavern, chapel, windmill and so on
## ring it, with a fence and gaps where the old roads leave town.
const TOWN_NAME := "Hearthmoor"
var town: Node3D


## The town's main avenue runs toward Ashford, the road the player first takes out of Hearthmoor.
func _grid_angle() -> float:
	return atan2(village_cell.y - CY, village_cell.x - CX)


## Dirt for the town's streets, painted into the ground so it matches the roads outside.
func _paint_town_streets() -> void:
	var theta := _grid_angle()
	for sg: Array in TownKit.grid_streets(theta, 15.0):
		var a: Vector3 = sg[0]
		var b: Vector3 = sg[1]
		var wd: float = sg[2]
		var len := a.distance_to(b)
		var n := int(len / 0.5)
		for i in n + 1:
			var p := a.lerp(b, float(i) / n)
			var cx := float(CX) + p.x / CELL
			var cy := float(CY) + p.z / CELL
			var rr := wd * 0.5 / CELL
			for yy in range(int(floor(cy - rr)), int(ceil(cy + rr)) + 1):
				for xx in range(int(floor(cx - rr)), int(ceil(cx + rr)) + 1):
					if xx < 0 or yy < 0 or xx >= N or yy >= N:
						continue
					# stay inside the flattened town: no dirt (and so no bridges) out in the wild
					if Vector2(xx - CX, yy - CY).length() > TOWN_CELLS - 3.0:
						continue
					if Vector2(xx + 0.5 - cx - 0.5, yy + 0.5 - cy - 0.5).length() <= rr + 0.35:
						path[yy * N + xx] = 1
						clear[yy * N + xx] = 1


func _build_town() -> void:
	var roads: Array = []
	for rc: Vector2i in _rune_cells:
		roads.append(atan2(rc.y - CY, rc.x - CX))
	roads.append(atan2(village_cell.y - CY, village_cell.x - CX))
	for pn: String in ["tallowmere", "sunkettle", "pilgrims_rest"]:
		var pc := lay.pin(pn)
		roads.append(atan2(pc.y - CY, pc.x - CX))
	gate_angles = roads.duplicate()
	var avoid: Array = [[Vector3.ZERO, 6.0], [Vector3(-3.0, 0, -10.5), 3.0], [Vector3(-6.5, 0, -6.5), 3.0]]   # Rowan and the cooking fire keep the plaza
	town = TownKit.village("meadow", 1207, 1.0, {"hub": true, "plaza_r": 15.0, "roads": roads, "avoid": avoid, "count": 34, "bscale": 1.45, "wall": "castle", "keep": true, "grid": true, "grid_angle": _grid_angle(),
		"kinds": ["keep", "tavern", "shop", "apothecary", "smithy", "chapel", "farm", "hall_house", "windmill", "barn", "hall_house", "farm", "townhouse", "hall_house", "house", "townhouse", "longhouse"], "house": "house", "alt": "townhouse"})
	town.name = "Hearthmoor"
	add_child(town)
	town.global_position = Vector3(shrine_pos.x, shrine_pos.y - 0.02, shrine_pos.z)
	town_radius = float(town.get_meta("radius", 40.0))
	town_buildings = []
	for tb: Dictionary in town.get_meta("buildings", []):
		town_buildings.append({"kind": tb["kind"], "pos": town.global_position + (tb["pos"] as Vector3), "yaw": tb["yaw"], "scale": tb.get("scale", 1.0)})


## Settlements and camps from the painted plan (Hearthmoor and Ashford are built separately).
const SETTLE := [
	{"pin": "tallowmere", "name": "Tallowmere", "style": "meadow", "seed": 6101, "size": 0.8, "plaza": 7.0, "wall": "fence", "flat": 23.0,
	 "kinds": ["farmhouse", "granary", "barn", "windmill", "farmhouse", "granary"], "house": "farmhouse", "alt": "cottage", "avoid": [[Vector3(14, 0, 12), 2.6]]},
	{"pin": "campwater_landing", "name": "Campwater Landing", "style": "coast", "seed": 6105, "size": 0.7, "plaza": 5.5, "wall": "", "flat": 21.0,
	 "kinds": ["fisher_cottage", "fisher_cottage", "shop", "granary", "fisher_cottage"], "house": "fisher_cottage", "alt": "cottage", "avoid": [[Vector3(14, 0, 12), 2.6]]},
	{"pin": "blackbriar_lodge", "name": "Blackbriar Lodge", "style": "briar", "seed": 6106, "size": 0.7, "plaza": 5.5, "wall": "palisade", "flat": 21.0,
	 "kinds": ["log_cabin", "lodge", "log_cabin", "smithy"], "house": "log_cabin", "alt": "log_cabin", "avoid": [[Vector3(14, 0, 12), 2.6]]},
	{"pin": "sunkettle", "name": "Sunkettle", "style": "mire", "seed": 6102, "size": 0.8, "plaza": 6.0, "wall": "", "flat": 23.0,
	 "kinds": ["stilt_hut", "reed_hut", "shop", "stilt_hut", "reed_hut", "stilt_hut"], "house": "reed_hut", "alt": "stilt_hut", "avoid": [[Vector3(14, 0, 12), 2.6]]},
	{"pin": "bellwharf", "name": "Bellwharf", "style": "tidal", "seed": 6107, "size": 0.7, "plaza": 5.5, "wall": "", "flat": 21.0,
	 "kinds": ["wreck_shack", "fisher_cottage", "wreck_shack", "shop", "wreck_shack"], "house": "wreck_shack", "alt": "fisher_cottage", "avoid": [[Vector3(14, 0, 12), 2.6]]},
	{"pin": "greyfold_steading", "name": "Greyfold Steading", "style": "downs", "seed": 6108, "size": 0.7, "plaza": 5.5, "wall": "stone", "flat": 21.0,
	 "kinds": ["turf_hut", "longhouse", "turf_hut", "granary", "turf_hut"], "house": "turf_hut", "alt": "turf_hut", "avoid": [[Vector3(14, 0, 12), 2.6]]},
	{"pin": "pilgrims_rest", "name": "Pilgrim's Rest", "style": "peaks", "seed": 6103, "size": 0.8, "plaza": 6.0, "wall": "", "flat": 22.0,
	 "kinds": ["chapel", "chalet", "lodge", "chalet", "chalet"], "house": "chalet", "alt": "chalet", "avoid": [[Vector3(14, 0, 10), 2.6]]},
	{"pin": "rimewatch", "name": "Rimewatch", "style": "peaks", "seed": 6104, "size": 0.8, "plaza": 6.0, "wall": "stone", "flat": 22.0,
	 "kinds": ["watchtower", "chalet", "smithy", "lodge"], "house": "chalet", "alt": "lodge", "avoid": []},
]
const CAMPS := [
	{"pin": "crossing_camp", "name": "Crossing Camp", "style": "meadow", "seed": 6202, "kind": "pilgrims"},
	{"pin": "southshore_camp", "name": "Southshore Camp", "style": "meadow", "seed": 6203, "kind": "hunters"},
	{"pin": "quiet_cart", "name": "The Quiet Cart", "style": "thornwood", "seed": 6204, "kind": "pilgrims"},
]
const FIXED_LM := [
	{"pin": "stones", "kind": "standing_stones", "name": "Greyfold Stones"},
	{"pin": "keep_ruin", "kind": "ruin", "name": "Greyfold Keep"},
	{"pin": "chapel_isle", "kind": "ruin", "name": "Drowned Chapel"},
	{"pin": "campwater_towers", "kind": "watchtower", "name": "Broken Towers"},
	{"pin": "campwater_arch", "kind": "ruin", "name": "Tidegate Arch"},
	{"pin": "drowned_bell", "kind": "ruin", "name": "Drowned Bell"},
]
var settlements: Array = []      # {name, pos, kind} for the map


func _build_settlements() -> void:
	settlements.clear()
	settlements.append({"name": TOWN_NAME, "pos": shrine_pos, "kind": "town"})
	settlements.append({"name": "Ashford", "pos": village_pos, "kind": "village"})
	for sd: Dictionary in SETTLE:
		var c := _site(sd["pin"])
		var pos := _ground(cell_center(c.x, c.y))
		var v := TownKit.village(sd["style"], sd["seed"], sd["size"], {"plaza_r": sd["plaza"], "roads": [], "avoid": sd["avoid"], "count": (sd["kinds"] as Array).size(), "wall": sd["wall"], "kinds": sd["kinds"], "house": sd["house"], "alt": sd["alt"]})
		v.name = String(sd["name"]).replace(" ", "").replace("'", "")
		add_child(v)
		v.global_position = Vector3(pos.x, pos.y - 0.02, pos.z)
		settlements.append({"name": sd["name"], "pos": pos, "kind": "village"})
	for cd: Dictionary in CAMPS:
		var c2 := _site(cd["pin"])
		var pos2 := _ground(cell_center(c2.x, c2.y))
		var cn := TownKit.camp(cd["style"], cd["seed"], cd["kind"])
		cn.name = String(cd["name"]).replace(" ", "")
		add_child(cn)
		cn.global_position = pos2
		campfires.append(pos2)
		settlements.append({"name": cd["name"], "pos": pos2, "kind": "camp"})


## Ashford: a small Thornwood hamlet up in the north-east with a well, a campfire, an inn and a shop.
var merchant2_pos := Vector3.ZERO
var merchant3_pos := Vector3.ZERO


## Compass word for where boss i's altar lies from Hearthmoor (the bosses no longer sit on fixed bearings).
func boss_dir(i: int) -> String:
	if i >= boss_cells.size():
		return "onward"
	var d := Vector2(boss_cells[i] - Vector2i(CX, CY))
	var names := ["east", "south-east", "south", "south-west", "west", "north-west", "north", "north-east"]
	return names[posmod(roundi(d.angle() / (PI / 4.0)), 8)]
var village_buildings: Array = []


func _build_village() -> void:
	var back := atan2(CY - village_cell.y, CX - village_cell.x)
	var avoid: Array = [[Vector3(6.0, 0, 10.0), 2.6], [Vector3(-5.0, 0, 5.0), 2.2]]   # Maren and the campfire keep their spots
	village = TownKit.village("thornwood", 5531, 0.8, {"plaza_r": 8.0, "bscale": 1.2, "roads": [back], "avoid": avoid, "count": 4, "wall": "fence", "kinds": ["tavern", "shop", "longhouse", "watchtower", "log_cabin", "log_cabin"], "house": "log_cabin", "alt": "cottage"})
	village.name = "Ashford"
	add_child(village)
	village.global_position = Vector3(village_pos.x, village_pos.y - 0.02, village_pos.z)
	village_buildings = []
	for tb: Dictionary in village.get_meta("buildings", []):
		village_buildings.append({"kind": tb["kind"], "pos": village.global_position + (tb["pos"] as Vector3), "yaw": tb["yaw"], "scale": tb.get("scale", 1.0)})
	merchant2_pos = _ground(village_pos + Vector3(-3.0, 0, -3.0))
	for tb: Dictionary in village_buildings:
		if tb["kind"] == "shop":
			merchant2_pos = _ground((tb["pos"] as Vector3) + Basis(Vector3.UP, float(tb["yaw"])) * Vector3(2.2, 0, -1.6) * float(tb.get("scale", 1.0)))
			break
	campfires.append(_ground(village_pos + Vector3(-5.0, 0, 5.0)))


## Everyone but Rowan lives in their own building: Hilde and the furnace and anvil in the smithy,
## the merchant in the shop, Varka in a house. Called once the buildings are standing.
func _bld(kind: String, nth := 0) -> Dictionary:
	var k := 0
	for tb: Dictionary in town_buildings:
		if tb["kind"] == kind:
			if k == nth:
				return tb
			k += 1
	return {}


func _bw(tb: Dictionary, local: Vector3) -> Vector3:
	return _ground((tb["pos"] as Vector3) + Basis(Vector3.UP, float(tb["yaw"])) * local * float(tb.get("scale", 1.0)))


func _place_town_folk() -> void:
	var sm := _bld("smithy")
	if not sm.is_empty():
		forge_pos = _bw(sm, Vector3(1.0, 0, -0.7))     # Hilde, behind her anvil
		anvil_pos = _bw(sm, Vector3(1.0, 0, 0.4))
		furnace_pos = _bw(sm, Vector3(-3.4, 0, -1.7))   # in front of the stone forge
	var sh := _bld("shop")
	if not sh.is_empty():
		merchant_pos = _bw(sh, Vector3(2.2, 0, -1.6))     # behind the counter of the general store
	var ap := _bld("apothecary")
	if not ap.is_empty():
		merchant3_pos = _bw(ap, Vector3(0.6, 0, -1.6))    # behind the apothecary's counter
	var ho := _bld("house")
	if not ho.is_empty():
		var tp: Vector3 = ho["pos"]
		var fwd := Vector3(sin(float(ho["yaw"])), 0, cos(float(ho["yaw"])))
		slayer_pos = _ground(tp + fwd * (TownKit.footprint("house") * float(ho.get("scale", 1.0)) + 1.6))


const POI_GLYPHS := {"tavern": ["I", "e8a050"], "shop": ["$", "ffd27a"], "apothecary": ["+", "7adf8a"], "smithy": ["F", "d08a7a"], "chapel": ["C", "bcd0f0"], "keep": ["K", "c9b8e8"]}


## Shops, the forge, the inn and the like, for the maps: [{cell, glyph, color}].
func poi_list() -> Array:
	var out: Array = []
	for lst: Array in [town_buildings, village_buildings]:
		for tb: Dictionary in lst:
			if POI_GLYPHS.has(tb["kind"]):
				var gdef: Array = POI_GLYPHS[tb["kind"]]
				out.append({"cell": world_to_cell(tb["pos"]), "glyph": gdef[0], "color": Color(gdef[1])})
	return out


var town_radius := 40.0
var gate_angles: Array = []
var town_buildings: Array = []        # {kind, pos (world), yaw} of the big buildings in Hearthmoor


func _ground(p: Vector3) -> Vector3:
	return Vector3(p.x, height_at(p.x, p.z), p.z)


func _place_caves() -> void:
	_update_dclear()
	var w := N + 1
	cave_sites.clear()
	var pins := ["cave_burrow", "cave_roots", "cave_grotto", "cave_rime", "cave_spider", "cave_barrow"]
	for i in Caves.DEFS.size():
		var want: int = Caves.DEFS[i]["biome"]
		var pc := lay.pin(pins[i])
		var best := Vector2i(-1, -1)
		var best_s := -999.0
		for y in range(pc.y - 24, pc.y + 25, 2):
			for x in range(pc.x - 24, pc.x + 25, 2):
				if x < 8 or y < 8 or x > N - 8 or y > N - 8:
					continue
				var ci := y * N + x
				var g: int = ground[ci]
				if g == G.WATER or g == G.SAND or _riv[y * w + x] > 0.05 or path[ci]:
					continue
				var h := heights[y * w + x]
				if h < 0.6:
					continue
				var slope := absf(heights[y * w + x + 1] - heights[y * w + x - 1]) + absf(heights[(y + 1) * w + x] - heights[(y - 1) * w + x])
				var sc: float = minf(h, 9.0) * 0.6 + minf(slope, 3.0) * 1.5 - Vector2(x - pc.x, y - pc.y).length() * 0.08
				if sc > best_s:
					best_s = sc
					best = Vector2i(x, y)
		if best.x < 0:
			best = _any_land_cell(want)
		_flatten(best, 3.0)
		var cp := cell_center(best.x, best.y)
		var face := Vector3(CX - best.x, 0, CY - best.y).normalized()
		cave_sites.append({"cell": best, "pos": cp, "face": face, "biome": want, "idx": i})


func _any_land_cell(want: int) -> Vector2i:
	var w := N + 1
	for y in range(20, N - 20, 3):
		for x in range(20, N - 20, 3):
			var ci := y * N + x
			if biome[ci] == want and ground[ci] != G.WATER and ground[ci] != G.SAND and heights[y * w + x] > 0.6:
				return Vector2i(x, y)
	return Vector2i(CX + 40, CY + 40)


func _carve(a: Vector2i, b: Vector2i, seed_v: int) -> void:
	var len := Vector2(b - a).length()
	var steps := int(ceil(len * 2.0))
	var ang := atan2(b.y - a.y, b.x - a.x)
	for i in steps + 1:
		var t := float(i) / steps
		var wob := sin(t * PI) * _shape.get_noise_2d(t * 30.0, seed_v * 13.0) * minf(12.0, len * 0.5)
		var x := roundi(lerpf(a.x, b.x, t) - sin(ang) * wob)
		var y := roundi(lerpf(a.y, b.y, t) + cos(ang) * wob)
		for oy in [-1, 0]:
			for ox in [-1, 0]:
				var xx: int = x + ox
				var yy: int = y + oy
				if xx >= 0 and yy >= 0 and xx < N and yy < N:
					path[yy * N + xx] = 1
					clear[yy * N + xx] = 1


func _flatten(c: Vector2i, rad: float) -> void:
	var w := N + 1
	var hc := maxf(heights[c.y * w + c.x], 0.45)
	# where the surrounding land is much higher or lower, the platform eases into it over a wider skirt
	var ring := 0.0
	for a in 8:
		var rx := clampi(c.x + roundi(cos(a * TAU / 8.0) * (rad + 3.0)), 0, N)
		var ry := clampi(c.y + roundi(sin(a * TAU / 8.0) * (rad + 3.0)), 0, N)
		ring += heights[ry * w + rx]
	var blend := clampf(absf(ring / 8.0 - hc) * 2.2, 2.5, 18.0)
	var reach := int(rad + blend + 1.0)
	for y in range(c.y - reach, c.y + reach + 1):
		for x in range(c.x - reach, c.x + reach + 1):
			if x < 0 or y < 0 or x > N or y > N:
				continue
			var d := Vector2(x - c.x, y - c.y).length()
			var k := 1.0 - smoothstep(rad, rad + blend, d)
			heights[y * w + x] = lerpf(heights[y * w + x], hc, k)
			if d <= rad + 1.0 and x < N and y < N:
				clear[y * N + x] = 1


## Whole-world pieces that never stream: the collision heightfield and a coarse, always-visible
## ground mesh for the distance (the chunks drawn on top of it replace it up close).
func _build_terrain_global() -> void:
	var w := N + 1
	var body := StaticBody3D.new()
	body.name = "TerrainBody"
	var shape := HeightMapShape3D.new()
	shape.map_width = w
	shape.map_depth = w
	var scaled := PackedFloat32Array()
	scaled.resize(heights.size())
	for i in heights.size():
		scaled[i] = heights[i] / CELL
	shape.map_data = scaled
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.scale = Vector3(CELL, CELL, CELL)
	body.add_child(cs)
	add_child(body)
	# distant ground: one vertex per STEP cells, taking the lowest nearby height so it always hides
	# under the real chunks
	const STEP := 6
	var gw := N / STEP + 1
	var lod_h := PackedFloat32Array()
	lod_h.resize(gw * gw)
	for gy in gw:
		for gx in gw:
			var m := 99.0
			for oy in range(-STEP / 2, STEP / 2 + 1, 2):
				for ox in range(-STEP / 2, STEP / 2 + 1, 2):
					var vx := clampi(gx * STEP + ox, 0, N)
					var vy := clampi(gy * STEP + oy, 0, N)
					m = minf(m, heights[vy * w + vx])
			lod_h[gy * gw + gx] = m - 0.35
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for gy in gw:
		for gx in gw:
			verts.append(Vector3(gx * STEP * CELL - HALF, lod_h[gy * gw + gx], gy * STEP * CELL - HALF))
			var hl := lod_h[gy * gw + maxi(gx - 1, 0)]
			var hr := lod_h[gy * gw + mini(gx + 1, gw - 1)]
			var hu := lod_h[maxi(gy - 1, 0) * gw + gx]
			var hd := lod_h[mini(gy + 1, gw - 1) * gw + gx]
			norms.append(Vector3(hl - hr, 2.0 * CELL * STEP, hu - hd).normalized())
			var cx := clampi(gx * STEP, 0, N - 1)
			var cy := clampi(gy * STEP, 0, N - 1)
			var g: int = ground[cy * N + cx]
			cols.append(Color(GROUND_COL[g][0]))
	for gy in gw - 1:
		for gx in gw - 1:
			var i := gy * gw + gx
			idx.append(i)
			idx.append(i + 1)
			idx.append(i + gw)
			idx.append(i + 1)
			idx.append(i + gw + 1)
			idx.append(i + gw)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	var mi := MeshInstance3D.new()
	mi.name = "FarGround"
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _build_water() -> void:
	var sh := Shader.new()
	sh.code = WATER_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	water_mat = mat
	# shoreline map: terrain height packed into one byte per corner, so the water can tint
	# shallows and draw foam where it meets land
	var w := N + 1
	var hw := N / 2 + 1
	var hb := PackedByteArray()
	hb.resize(hw * hw)
	for y in hw:
		for x in hw:
			hb[y * hw + x] = int(clampf((heights[mini(y * 2, N) * w + mini(x * 2, N)] + 1.5) / 3.0, 0.0, 1.0) * 255.0)
	mat.set_shader_parameter("hmap", ImageTexture.create_from_image(Image.create_from_data(hw, hw, false, Image.FORMAT_R8, hb)))
	mat.set_shader_parameter("world_size", N * CELL)
	var plane := PlaneMesh.new()
	plane.size = Vector2(N * CELL + 900.0, N * CELL + 900.0)
	var mi := MeshInstance3D.new()
	mi.name = "Water"
	mi.mesh = plane
	mi.material_override = mat
	mi.position.y = WATER_Y
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	# sea floor so the world edge never shows through the water
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color("24414c")
	floor_mat.roughness = 1.0
	var fl := MeshInstance3D.new()
	var fp := PlaneMesh.new()
	fp.size = Vector2(N * CELL + 900.0, N * CELL + 900.0)
	fl.mesh = fp
	fl.material_override = floor_mat
	fl.position.y = -2.7
	add_child(fl)


const LM_DEFS := {
	"ruin": {"biomes": [0, 1, 2], "count": 24, "r": 6, "name": "Old Ruin"},
	"standing_stones": {"biomes": [0, 1], "count": 16, "r": 7, "name": "Standing Stones"},
	"watchtower": {"biomes": [0, 3], "count": 16, "r": 5, "name": "Broken Watchtower"},
	"ancient_tree": {"biomes": [1, 2], "count": 16, "r": 5, "name": "Ancient Tree"},
	"obelisk": {"biomes": [2, 3], "count": 16, "r": 4, "name": "Rune Obelisk"},
	"old_camp": {"biomes": [0, 1, 3], "count": 24, "r": 4, "name": "Abandoned Camp"},
}


## Choose spots for landmarks and keep flora and ore off them. Runs before flora is scattered.
func _pick_landmarks() -> void:
	landmarks.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 9091
	_update_dclear()
	for fl: Dictionary in FIXED_LM:
		var fc := lay.pin(fl["pin"])
		var fp := cell_center(fc.x, fc.y)
		fp.y = height_at(fp.x, fp.z)
		landmarks.append({"kind": fl["kind"], "pos": fp, "name": fl["name"], "r": LM_DEFS[fl["kind"]]["r"]})
		for yy in range(fc.y - 8, fc.y + 9):
			for xx in range(fc.x - 8, fc.x + 9):
				if xx >= 0 and yy >= 0 and xx < N and yy < N and Vector2(xx - fc.x, yy - fc.y).length() <= 8.0:
					clear[yy * N + xx] = 1
	for kind: String in LM_DEFS:
		var d: Dictionary = LM_DEFS[kind]
		var placed := 0
		var tries := 0
		while placed < int(d["count"]) and tries < 12000:
			tries += 1
			var x := rng.randi_range(30, N - 30)
			var y := rng.randi_range(30, N - 30)
			var i := y * N + x
			if _dclear_at(x, y) < 10.0 or biome[i] not in d["biomes"]:
				continue
			if ground[i] in [G.WATER, G.SAND]:
				continue
			if Vector2(x - CX, y - CX).length() < TOWN_CELLS + 22:
				continue
			var p := cell_center(x, y)
			var h0 := height_at(p.x, p.z)
			var flat := true
			for o: Vector2 in [Vector2(5, 0), Vector2(-5, 0), Vector2(0, 5), Vector2(0, -5)]:
				var hh := height_at(p.x + o.x, p.z + o.y)
				if absf(hh - h0) > 0.7 or hh < 0.0:
					flat = false
			if not flat or h0 < 0.1:
				continue
			var near := false
			for l: Dictionary in landmarks:
				if (l["pos"] as Vector3).distance_to(p) < 70.0:
					near = true
			for cs: Dictionary in cave_sites:
				if (cs["pos"] as Vector3).distance_to(p) < 40.0:
					near = true
			if near:
				continue
			p.y = h0
			landmarks.append({"kind": kind, "pos": p, "name": d["name"], "r": d["r"]})
			var rr := int(d["r"]) + 2
			for yy in range(y - rr, y + rr + 1):
				for xx in range(x - rr, x + rr + 1):
					if xx >= 0 and yy >= 0 and xx < N and yy < N and Vector2(xx - x, yy - y).length() <= rr:
						clear[yy * N + xx] = 1
			placed += 1


func _build_landmarks() -> void:
	var sh := Shader.new()
	sh.code = FLORA_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("sway", 0.0)
	mat.set_shader_parameter("see_through", false)
	var root := Node3D.new()
	root.name = "Landmarks"
	add_child(root)
	var lrng := RandomNumberGenerator.new()
	lrng.seed = 31
	for l: Dictionary in landmarks:
		var kind: String = l["kind"]
		var p: Vector3 = l["pos"]
		var mi := MeshInstance3D.new()
		mi.mesh = Models.scenery_mesh(kind, lrng.randi())
		mi.material_override = mat
		mi.position = p
		mi.rotation.y = lrng.randf() * TAU
		root.add_child(mi)
		if kind != "old_camp":
			mi.create_trimesh_collision()
			for c in mi.get_children():
				if c is StaticBody3D:
					(c as StaticBody3D).collision_layer = 2
		if kind == "obelisk":
			var lt := OmniLight3D.new()
			lt.light_color = Color("6af0ff")
			lt.light_energy = 1.2
			lt.omni_range = 11.0
			lt.shadow_enabled = false
			lt.position = p + Vector3(0, 3.5, 0)
			root.add_child(lt)


func _img(w: int, h: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img


func _disc(img: Image, cx: int, cy: int, r: int, col: Color) -> void:
	for dy in range(-r, r + 1):
		var w := int(sqrt(r * r - dy * dy + 0.5))
		_rect(img, cx - w, cy + dy, w * 2 + 1, 1, col)


func _rect(img: Image, x: int, y: int, w: int, h: int, col: Color) -> void:
	var r := Rect2i(x, y, w, h).intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	if r.size.x > 0 and r.size.y > 0:
		img.fill_rect(r, col)


func _stone_material() -> StandardMaterial3D:
	var img := Image.create(16, 16, false, Image.FORMAT_RGB8)
	var greys := [Color("5c5a66"), Color("6f6e7a"), Color("7b7a86"), Color("8a8996")]
	for y in 16:
		for x in 16:
			img.set_pixel(x, y, greys[_rng.randi_range(0, 3)] if _rng.randf() < 0.5 else greys[1])
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(0.5, 0.5, 0.5)
	m.roughness = 1.0
	return m


func _add_mesh(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot_y := 0.0, collide := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation.y = rot_y
	parent.add_child(mi)
	if collide:
		mi.create_convex_collision()
		for c in mi.get_children():
			if c is StaticBody3D:
				(c as StaticBody3D).collision_layer = 2
	return mi


func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


func _cyl(top: float, bottom: float, h: float, sides := 8) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = sides
	c.rings = 1
	return c


func _build_props() -> void:
	var stone := _stone_material()
	var dark := stone.duplicate() as StandardMaterial3D
	dark.albedo_color = Color(0.7, 0.68, 0.75)
	var props := Node3D.new()
	props.name = "StoryProps"
	add_child(props)

	# --- Bramble's stall
	var m := merchant_pos
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("7a5232")
	wood.roughness = 1.0
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color("b8443a")
	cloth.roughness = 1.0
	var cloth2 := StandardMaterial3D.new()
	cloth2.albedo_color = Color("e8dcc0")
	cloth2.roughness = 1.0
	_add_mesh(props, _box(Vector3(2.6, 0.9, 0.8)), wood, m + Vector3(0, 0.45, -1.1), 0.0, true)
	_add_mesh(props, _box(Vector3(2.8, 0.1, 1.0)), cloth2, m + Vector3(0, 0.95, -1.1))
	for px_off in [-1.4, 1.4]:
		_add_mesh(props, _box(Vector3(0.14, 2.6, 0.14)), wood, m + Vector3(px_off, 1.3, -1.6))
		_add_mesh(props, _box(Vector3(0.14, 2.2, 0.14)), wood, m + Vector3(px_off, 1.1, -0.6))
	for k in 4:
		var awning := _add_mesh(props, _box(Vector3(0.75, 0.08, 1.4)), cloth if k % 2 == 0 else cloth2, m + Vector3(-1.1 + k * 0.74, 2.45, -1.1))
		awning.rotation.x = -0.35
	_add_mesh(props, _box(Vector3(0.7, 0.7, 0.7)), wood, m + Vector3(2.0, 0.35, -0.2), 0.3, true)
	_add_mesh(props, _box(Vector3(0.6, 0.6, 0.6)), wood, m + Vector3(2.1, 1.0, -0.3), 0.6)
	_add_mesh(props, _cyl(0.32, 0.36, 0.8), wood, m + Vector3(-2.0, 0.4, -0.4), 0.0, true)
	var bottle := StandardMaterial3D.new()
	bottle.albedo_color = Color("d9483b")
	bottle.emission_enabled = true
	bottle.emission = Color("d9483b")
	bottle.emission_energy_multiplier = 0.6
	for k in 3:
		_add_mesh(props, _box(Vector3(0.14, 0.24, 0.14)), bottle, m + Vector3(-0.6 + k * 0.35, 1.12, -1.2))

	# --- Hearth Shrine
	var s := shrine_pos
	_add_mesh(props, _cyl(3.2, 3.4, 0.6), stone, s + Vector3(0, 0.25, 0), 0.0, true)
	_add_mesh(props, _cyl(2.2, 2.4, 0.5), dark, s + Vector3(0, 0.75, 0), PI / 8.0, true)
	_add_mesh(props, _cyl(0.9, 0.6, 0.8), dark, s + Vector3(0, 1.4, 0))
	for k in 4:
		var a := PI * 0.25 + k * PI * 0.5
		var pp := s + Vector3(cos(a) * 4.4, 0, sin(a) * 4.4)
		pp.y = height_at(pp.x, pp.z)
		_add_mesh(props, _box(Vector3(0.7, 1.4, 0.7)), stone, pp + Vector3(0, 0.6, 0), a, true)
		_add_mesh(props, _box(Vector3(0.9, 0.15, 0.9)), dark, pp + Vector3(0, 1.35, 0), a)
		var orb := Node3D.new()
		orb.position = pp + Vector3(0, 1.9, 0)
		var om := StandardMaterial3D.new()
		om.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		om.albedo_color = Color(Data.BOSSES[k]["color"])
		var sm := SphereMesh.new()
		sm.radius = 0.28
		sm.height = 0.56
		sm.radial_segments = 8
		sm.rings = 4
		_add_mesh(orb, sm, om, Vector3.ZERO)
		var ol := OmniLight3D.new()
		ol.light_color = om.albedo_color
		ol.omni_range = 4.0
		ol.light_energy = 1.5
		orb.add_child(ol)
		orb.visible = false
		props.add_child(orb)
		_ped_orbs.append(orb)
	# the Ember: stacked low-poly flame cones that flicker
	_flame = Node3D.new()
	_flame.position = s + Vector3(0, 1.95, 0)
	var fcols := [Color("c4421a"), Color("f2994a"), Color("ffe9a0")]
	for fi in 3:
		var cone := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 0.42 - fi * 0.12
		cm.height = 1.1 - fi * 0.25
		cm.radial_segments = 5
		cm.rings = 1
		cone.mesh = cm
		var fm := StandardMaterial3D.new()
		fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fm.albedo_color = fcols[fi]
		cone.material_override = fm
		cone.position.y = cm.height * 0.5 + fi * 0.04
		cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_flame.add_child(cone)
		_flame_cones.append(cone)
	props.add_child(_flame)
	_flame_light = OmniLight3D.new()
	_flame_light.light_color = Color("ff9a4a")
	_flame_light.omni_range = 14.0
	_flame_light.light_energy = 2.4
	_flame_light.shadow_enabled = true
	_flame_light.position = s + Vector3(0, 3.0, 0)
	props.add_child(_flame_light)
	# the Wisp
	_wisp = Node3D.new()
	var ws := Models.wisp("9fe0ff")
	ws.scale = Vector3.ONE * 0.6
	ws.position.y = -0.5
	_wisp.add_child(ws)
	_wisp_rig = ws
	var wl := OmniLight3D.new()
	wl.light_color = Color("9fe0ff")
	wl.omni_range = 5.0
	wl.light_energy = 1.2
	_wisp.add_child(wl)
	props.add_child(_wisp)

	# --- runestones
	for i in rune_pos.size():
		var r := rune_pos[i]
		var face := 0.0  # carved side faces the camera
		var stone_mi := _add_mesh(props, _box(Vector3(1.1, 2.6, 0.5)), stone, r + Vector3(0, 1.1, 0), face, true)
		stone_mi.rotation.z = 0.04
		var gm := StandardMaterial3D.new()
		gm.emission_enabled = true
		gm.albedo_color = Color("5a5f6c")
		rune_glyphs.append(gm)
		var glyph := Node3D.new()
		glyph.position = r + Vector3(0, 1.2, 0)
		glyph.rotation.y = face
		props.add_child(glyph)
		_add_mesh(glyph, _box(Vector3(0.14, 1.3, 0.06)), gm, Vector3(0, 0, 0.26))
		_add_mesh(glyph, _box(Vector3(0.4, 0.12, 0.06)), gm, Vector3(-0.12, 0.35, 0.26))
		_add_mesh(glyph, _box(Vector3(0.36, 0.12, 0.06)), gm, Vector3(0.14, -0.1, 0.26))
		set_rune_state(i, "dim")

	# --- Warden altars
	for i in altar_pos.size():
		var a := altar_pos[i]
		_add_mesh(props, _box(Vector3(2.6, 0.7, 1.6)), dark, a + Vector3(0, 0.3, 0), 0.0, true)
		_add_mesh(props, _box(Vector3(2.2, 0.15, 1.2)), stone, a + Vector3(0, 0.72, 0))
		var gems: Array = []
		for g in 3:
			var gm2 := StandardMaterial3D.new()
			gm2.albedo_color = Color("2a2633")
			gm2.emission_enabled = true
			gm2.emission = Color(Data.BOSSES[i]["color"])
			gm2.emission_energy_multiplier = 0.0
			_add_mesh(props, _box(Vector3(0.3, 0.45, 0.3)), gm2, a + Vector3(-0.7 + g * 0.7, 1.0, 0), PI * 0.25)
			gems.append(gm2)
		_altar_gems.append(gems)
		var al := OmniLight3D.new()
		al.light_color = Color(Data.BOSSES[i]["color"])
		al.omni_range = 7.0
		al.light_energy = 0.0
		al.position = a + Vector3(0, 1.8, 0)
		props.add_child(al)
		_altar_glow.append(al)
		for k in 6:
			var an := k / 6.0 * TAU + 0.3
			var sp := a + Vector3(cos(an) * 5.0, 0, sin(an) * 5.0)
			sp.y = height_at(sp.x, sp.z)
			var hgt := 1.4 + _rng.randf() * 0.8
			var st_mi := _add_mesh(props, _box(Vector3(0.7, hgt, 0.5)), stone, sp + Vector3(0, hgt * 0.45, 0), an + PI * 0.5, true)
			st_mi.rotation.x = _rng.randf_range(-0.06, 0.06)


const MAP_SCALE := 0.5   # minimap texels per cell

# ---- fog of war: one byte per 8x8 cells, 255 = seen
const FOG_C := 8
const FOG_N := 150
var explored := PackedByteArray()
var _fog_img: Image
var fog_tex: ImageTexture
var _fog_cell := Vector2i(-99, -99)


func reset_fog() -> void:
	explored.resize(FOG_N * FOG_N)
	explored.fill(0)
	_fog_cell = Vector2i(-99, -99)
	reveal(shrine_pos, 80.0)
	_fog_push()


## Dev mode: uncover the whole map.
func reveal_all() -> void:
	if explored.size() != FOG_N * FOG_N:
		explored.resize(FOG_N * FOG_N)
	explored.fill(255)
	_fog_push()


func load_fog(bytes: PackedByteArray) -> void:
	if bytes.size() == FOG_N * FOG_N:
		explored = bytes
		_fog_push()
	else:
		reset_fog()


func _fog_push() -> void:
	var img := Image.create_from_data(FOG_N, FOG_N, false, Image.FORMAT_L8, explored)
	if fog_tex == null:
		fog_tex = ImageTexture.create_from_image(img)
	else:
		fog_tex.update(img)


func explored_at(cell: Vector2) -> float:
	var gx := clampi(int(cell.x / FOG_C), 0, FOG_N - 1)
	var gy := clampi(int(cell.y / FOG_C), 0, FOG_N - 1)
	return explored[gy * FOG_N + gx] / 255.0


## Uncover the ground around a spot (radius in cells). Cheap enough to call every half second.
func reveal(pos: Vector3, r := 60.0) -> void:
	if explored.size() != FOG_N * FOG_N or pos.x > Caves.X0 - 150.0:
		return
	var c := world_to_cell(pos)
	var ci := Vector2i(int(c.x / FOG_C), int(c.y / FOG_C))
	if ci == _fog_cell and r < 70.0:
		return
	_fog_cell = ci
	var rn := r / FOG_C
	var changed := false
	for gy in range(maxi(0, ci.y - int(rn) - 2), mini(FOG_N, ci.y + int(rn) + 3)):
		for gx in range(maxi(0, ci.x - int(rn) - 2), mini(FOG_N, ci.x + int(rn) + 3)):
			var d := Vector2(gx + 0.5 - c.x / FOG_C, gy + 0.5 - c.y / FOG_C).length()
			var v := int(clampf((rn - d) / (rn * 0.35), 0.0, 1.0) * 255.0)
			if v > explored[gy * FOG_N + gx]:
				explored[gy * FOG_N + gx] = v
				changed = true
	if changed:
		_fog_push()


func _build_map() -> void:
	var mw := int(N * MAP_SCALE)
	var cols := {}
	for k in MAP_COL.keys():
		cols[k] = Color(MAP_COL[k])
	var pc := Color("a08a60")
	var bytes := PackedByteArray()
	bytes.resize(mw * mw * 3)
	var step := int(1.0 / MAP_SCALE)
	for y in mw:
		for x in mw:
			var i := (y * step) * N + x * step
			var col: Color = pc if (path[i] and ground[i] != G.WATER) else cols[ground[i]]
			var o := (y * mw + x) * 3
			bytes[o] = int(col.r * 255.0)
			bytes[o + 1] = int(col.g * 255.0)
			bytes[o + 2] = int(col.b * 255.0)
	map_texture = ImageTexture.create_from_image(Image.create_from_data(mw, mw, false, Image.FORMAT_RGB8, bytes))


# ================================================================ shaders
const WATER_SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, specular_schlick_ggx;
uniform vec4 deep : source_color = vec4(0.13, 0.32, 0.52, 0.86);
uniform vec4 shallow : source_color = vec4(0.22, 0.55, 0.66, 0.8);
uniform vec4 crest : source_color = vec4(0.62, 0.8, 0.9, 0.9);
uniform sampler2D hmap : filter_linear, repeat_disable;
uniform float world_size = 800.0;
uniform vec3 sky_col : source_color = vec3(0.6, 0.75, 0.9);
uniform float night = 0.0;
varying vec3 wp;
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 q = floor(wp.xz * 2.0) / 2.0;
	float ph1 = q.x * 0.55 + TIME * 1.1;
	float ph2 = q.y * 0.47 - TIME * 0.8;
	float w = sin(ph1) * sin(ph2);
	float w2 = sin((q.x + q.y) * 0.31 + TIME * 0.6);
	float h = texture(hmap, (wp.xz + world_size * 0.5) / world_size).r * 3.0 - 1.5;
	float d = clamp(-h, 0.0, 2.0);
	vec4 c = mix(deep, shallow, step(0.2, w2 * 0.5 + 0.5));
	c = mix(shallow, c, smoothstep(0.05, 0.9, d));
	c = mix(c, crest, step(0.9, w));
	// little wave normals so the sun and moon glitter on the surface
	float dx = cos(ph1) * 0.55 * sin(ph2);
	float dz = -sin(ph1) * cos(ph2) * 0.47;
	vec3 nw = normalize(vec3(-dx * 0.16, 1.0, -dz * 0.16));
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.0);
	vec3 col = mix(c.rgb, sky_col, fres * 0.55);
	// shore foam, a pulsing band along the water line
	float band = 0.08 + 0.07 * sin(TIME * 1.6 + (wp.x + wp.z) * 0.9);
	float foam = step(d, band) * step(0.0, h + 0.4);
	foam += step(0.97, w) * 0.0;
	col = mix(col, vec3(0.92, 0.97, 1.0) * (1.0 - night * 0.55), foam);
	ALBEDO = col;
	ALPHA = mix(0.55, c.a, smoothstep(0.0, 0.5, d)) * (1.0 - foam) + foam;
	ROUGHNESS = 0.1;
	SPECULAR = 0.7;
	EMISSION = vec3(0.02, 0.04, 0.07) * night + step(0.9, w) * 0.05 * (1.0 - night);
}
"""

const FLORA_SHADER := """
shader_type spatial;
render_mode cull_disabled, diffuse_lambert;
uniform float sway = 0.03;
uniform bool see_through = true;
uniform float glow = 0.0;
global uniform vec3 player_pos;
global uniform float wind;
void vertex() {
	vec3 wp = MODEL_MATRIX[3].xyz;
	float s = sin(TIME * 1.4 * (0.7 + wind * 0.3) + wp.x * 0.37 + wp.z * 0.21) * sway * wind * max(VERTEX.y, 0.0);
	VERTEX.x += s;
	VERTEX.z += s * 0.5;
}
void fragment() {
	// see-through dither where this tree stands between the camera and the player
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
	if (COLOR.g > 0.85 && COLOR.b > 0.9 && COLOR.r < 0.5) {
		EMISSION = COLOR.rgb * (1.4 + 0.5 * sin(TIME * 1.6 + MODEL_MATRIX[3].x * 0.1));
	}
	if (glow > 0.0) {
		EMISSION = COLOR.rgb * glow * (0.6 + 0.4 * sin(TIME * 1.3 + MODEL_MATRIX[3].x));
	}
	ROUGHNESS = 1.0;
	SPECULAR = 0.1;
}
"""
