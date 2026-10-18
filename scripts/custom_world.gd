class_name CustomWorld
extends RefCounted
## Plays the game in a world you built with the Embers World addon, instead of the generated one.
##   --world res://scenes/my_world.tscn      the scene you built (terrain, buildings, trees, markers)
##   --world-data /path/to/embers_export      (optional) the folder written by "Embers: Export world to server";
##                                            default: the export_dir of your EmbersWorld node, else res://embers_export
## The game's own landscape, trees and towns are not built at all. The ground you see is yours (Terrain3D or
## meshes); what the game needs to know (heights, water, biomes, where the shrine, forge, NPCs and camp are) is
## read from the export, which is the same data the server uses. Without --world nothing here runs.

static func scene_path() -> String:
	if bool(Online.cfg.get("auto", false)):
		return str(Online.cfg.get("world", ""))   # chosen on the login screen ("" = the original world)
	var a: PackedStringArray = OS.get_cmdline_user_args()
	var i: int = a.find("--world")
	return a[i + 1] if i >= 0 and i + 1 < a.size() else ""


static func requested() -> bool:
	return scene_path() != ""


static func data_dir(scene: Node) -> String:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	var i: int = a.find("--world-data")
	if i >= 0 and i + 1 < a.size():
		return a[i + 1]
	for n: Node in scene.find_children("*", "EmbersWorld", true, false):
		var d: String = str(n.get("export_dir"))
		if d != "":
			return d
	return "res://embers_export"


## Say what is wrong in a window (not just the log) and stop: a half-built world only gives errors and a blank sky.
static func fail(msg: String) -> bool:
	push_error("--world: " + msg)
	OS.alert(msg, "Embers custom world")
	return false


static func _v3(w: World, p: Variant) -> Vector3:
	return Vector3(float(p[0]), w.height_at(float(p[0]), float(p[1])), float(p[1]))


## Fill `w` (a World) from the exported world and add the author's scene. Returns false (and says why) on failure.
static func build(w: World) -> bool:
	World.ensure_wind()
	w.add_to_group("world")
	var path := scene_path()
	w.set_meta("custom_world", path)   # the login screen compares this with the world you picked
	var ps: PackedScene = load(path)
	if ps == null:
		return fail("Cannot load the scene %s" % path)
	var scene: Node = ps.instantiate()
	var dir := data_dir(scene)
	if not _load_terrain(w, dir):
		return false
	var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("terrain_meta.json")))
	if not meta is Dictionary:
		return fail("There is no terrain_meta.json in %s. Run Project > Tools > Embers: Export world to server first." % dir)
	_apply_meta(w, meta)
	w.clear.resize(World.N * World.N)
	w.clear.fill(0)
	# where ground clutter must stay out (around buildings, walls, trees and your marker points), written by the export
	var cf := FileAccess.open(dir.path_join("clutter_clear.bin"), FileAccess.READ)
	if cf != null:
		var packed := cf.get_buffer(cf.get_length())
		var mask := packed.decompress(World.N * World.N, FileAccess.COMPRESSION_DEFLATE)
		if mask.size() == World.N * World.N:
			w.clear = mask
	w.caves = Caves.new()
	w.caves.name = "Caves"
	w.caves.sites = []
	w.add_child(w.caves)
	var stub := StubStreamer.new()
	w.streamer = stub
	w.add_child(stub)
	stub.setup(w)
	stub.density = float(meta.get("ground_clutter", 1.0))
	w._build_water()
	_prepare_scene(scene)   # before it joins the tree: a test walker would otherwise start and take over the camera
	w.add_child(scene)
	var t3d: Node = _find_terrain(scene)
	if bool(meta.get("flat_ground", true)):
		# the flat-colour ground (one colour per triangle, the original game's look) built from the exported world; it is exactly
		# the server's 2 m grid, so Terrain3D's finer ground is hidden and not followed
		var snap := {"n": World.N, "half": World.HALF, "cell": World.CELL, "water_y": float(meta.get("water_y", 0.0)), "heights": w.heights,
			"ground": w.ground, "biome": w.biome, "path": w.path, "smooth": int(meta.get("smooth_blend_cells", 0)), "smooth_path": int(meta.get("smooth_path_cells", 0))}
		var made: Dictionary = EmbersFacetGround.make_holder(snap)
		w.add_child(made["holder"])
		print("CustomWorld: flat-colour ground built (%d faces)" % int(made["faces"]))
		for t: Node in scene.find_children("*", "Terrain3D", true, false):
			(t as Node3D).visible = false
			# its collision must go too: it is finer than the server's grid and sticks out of the flat triangles, which held people above the ground
			if "collision_mode" in t:
				t.set("collision_mode", 0)
		w.add_child(_ground_body(w))
	elif t3d != null:
		# the ground you see is finer than the server's 2 m grid: follow it, or players would float above bumps
		w.custom_ground = Callable(CustomWorld, "_terrain_height").bind(t3d)
	w.build_custom_shrine()
	w._build_map()
	w.reset_fog()
	print("CustomWorld ready: %s, data %s" % [path, dir])
	return true


static func _load_terrain(w: World, dir: String) -> bool:
	var f := FileAccess.open(dir.path_join("terrain.bin"), FileAccess.READ)
	if f == null:
		return fail("There is no terrain.bin in %s. Run Project > Tools > Embers: Export world to server first." % dir)
	var raw := f.get_buffer(f.get_length())
	if raw.size() < 20 or raw.slice(0, 4).get_string_from_ascii() != "EMBT":
		return fail("terrain.bin is not an Embers terrain file")
	var n := raw.decode_u32(8)
	if n != World.N:
		return fail("Your exported world is %d cells wide but the game needs %d (2400 m). Export again with the updated addon (EmbersWorld > pad_to_game_size on), then start the game again." % [n, World.N])
	var w1 := n + 1
	var off := 20
	w.heights.resize(w1 * w1)
	for i in w1 * w1:
		w.heights[i] = raw.decode_s16(off + i * 2) / 100.0
	off += w1 * w1 * 2
	var cells := n * n
	w.ground = raw.slice(off, off + cells)
	off += cells
	w.biome = raw.slice(off, off + cells)
	off += cells
	w.custom_zone = raw.slice(off, off + cells)
	off += cells
	w.path = raw.slice(off, off + cells)
	return true


static func _apply_meta(w: World, m: Dictionary) -> void:
	w.shrine_pos = _v3(w, m["shrine"])
	w.camp_pos = _v3(w, m["camp"])
	w.village_pos = _v3(w, m["village"])
	w.forge_pos = _v3(w, m["forge"])
	w.furnace_pos = _v3(w, m["furnace"])
	w.anvil_pos = _v3(w, m["anvil"])
	w.slayer_pos = _v3(w, m["slayer"])
	w.merchant_pos = _v3(w, m["merchant"])
	var ms: Array = m.get("merchants", [])
	w.merchant2_pos = _v3(w, ms[1]) if ms.size() > 1 else w.merchant_pos + Vector3(4, 0, 0)
	w.merchant3_pos = _v3(w, ms[2]) if ms.size() > 2 else w.merchant_pos + Vector3(-4, 0, 0)
	w.town_radius = float(m.get("town_radius", 40.0))
	var smooth := int(m.get("smooth_blend_cells", 0))
	if smooth > 0:
		w.set_meta("smooth_ground", smooth)   # colours blend smoothly across biome borders (read by the ground builder)
	w.camp_fish_pos = w.camp_pos
	w.camp_pond = w.camp_pos
	w.alchemy_pos = w.camp_pos
	w.bench_pos = w.camp_pos
	w.camp_bench_pos = w.camp_pos
	w.rack_pos = _v3(w, m["rack"]) if m.has("rack") else w.camp_pos + Vector3(3, 0, 3)   # the Weapon rack point, or beside the camp
	var npcs: Dictionary = m.get("npcs", {})
	for id: String in npcs:
		w.npc_pos[id] = _v3(w, npcs[id])
	w.gate_angles = [0.0, PI * 0.5, PI, PI * 1.5]
	# characters and lairs the author hasn't placed live far below the map, so the game's quest code has a spot for everyone
	var all_ids: Array = []
	for g: Dictionary in Data.SIDE_QUESTS:
		all_ids.append(str(g["id"]))
	for id: Variant in Data.ELITES.keys():
		all_ids.append(str(id))
	for id: String in all_ids:
		if not w.npc_pos.has(id):
			w.npc_pos[id] = Vector3(0, -900, 0)
	for c: Variant in m.get("campfires", []):
		w.campfires.append(_v3(w, c))
	# the story's runestones and altars live far below the map: they are not in custom worlds
	w.rune_pos = [Vector3(0, -900, 0), Vector3(0, -900, 0), Vector3(0, -900, 0), Vector3(0, -900, 0)]
	w.altar_pos = [Vector3(0, -900, 0), Vector3(0, -900, 0), Vector3(0, -900, 0), Vector3(0, -900, 0)]


## The walkable ground: a heightfield over the server's grid, so it is exactly the drawn triangles.
static func _ground_body(w: World) -> StaticBody3D:
	var n1 := World.N + 1
	var body := StaticBody3D.new()
	body.name = "TerrainBody"
	var shape := HeightMapShape3D.new()
	shape.map_width = n1
	shape.map_depth = n1
	var scaled := PackedFloat32Array()
	scaled.resize(w.heights.size())
	for i in w.heights.size():
		scaled[i] = w.heights[i] / World.CELL
	shape.map_data = scaled
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.scale = Vector3(World.CELL, World.CELL, World.CELL)
	body.add_child(cs)
	return body


static func _find_terrain(n: Node) -> Node:
	if n.get_class() == "Terrain3D" or n.is_class("Terrain3D"):
		return n
	for c in n.get_children():
		var f := _find_terrain(c)
		if f != null:
			return f
	return null


## Terrain3D's own height (NAN where there is no terrain, so the grid answers there).
static func _terrain_height(x: float, z: float, t: Node) -> float:
	if not is_instance_valid(t) or t.data == null:
		return NAN
	return t.data.get_height(Vector3(x, 0, z))


## The author's scene is only visuals here: no walker (it would make its own camera), no editor markers
## (the game draws people itself).
static func _prepare_scene(scene: Node) -> void:
	var walkers: Array = []
	for n: Node in scene.find_children("*", "", true, false):
		var sc: Script = n.get_script()
		var cls: String = sc.get_global_name() if sc != null else ""
		if cls == "EmbersWalker":
			walkers.append(n)
		elif cls == "EmbersPoint":
			(n as Node3D).visible = false
	for n: Node in walkers:
		n.get_parent().remove_child(n)
		n.free()
