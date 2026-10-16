@tool
class_name EmbersOriginalWorld
extends RefCounted
## The original game's terrain (2400 m, the heights, ground, biomes and roads of the generated world), kept in
## original_terrain.bin.gz next to this script. Use it as a starting point: put it into Terrain3D to sculpt on, or export it for
## Blender to edit and bring back (a mesh in the group "embers_ground" is read by the exporter like Terrain3D is).

const FILE := "res://addons/embers_world/original_terrain.bin.gz"
const BLENDER_DIR := "res://original_terrain_for_blender"
const GROUND_COL := ["3b6470", "c9b27a", "5f9a46", "2f5a34", "4b4a33", "2e3d34", "c4d0dc", "6f7480"]


## {n, cell, water_y, heights (metres, (n+1)^2, row = z), ground, biome, path} or {} if the file can't be read.
static func load_world() -> Dictionary:
	var packed := FileAccess.get_file_as_bytes(FILE)
	if packed.is_empty():
		return {}
	var raw := packed.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP)
	if raw.size() < 20 or raw.slice(0, 4).get_string_from_ascii() != "EMBT":
		return {}
	var n := raw.decode_u32(8)
	var cell := raw.decode_float(12)
	var water_y := raw.decode_float(16)
	var w1 := n + 1
	var off := 20
	var heights := PackedFloat32Array()
	heights.resize(w1 * w1)
	for i in w1 * w1:
		heights[i] = raw.decode_s16(off + i * 2) / 100.0
	off += w1 * w1 * 2
	var cells := n * n
	return {"n": n, "cell": cell, "water_y": water_y, "heights": heights, "ground": raw.slice(off, off + cells),
		"biome": raw.slice(off + cells, off + cells * 2), "path": raw.slice(off + cells * 4, off + cells * 5)}


## Fill a Terrain3D node with the original terrain (replacing nothing: it adds regions where the original has land). Sets the
## vertex spacing to the original's 2 m. Returns a message. Needs Terrain3D 1.0 or newer.
static func import_terrain3d(terrain: Node) -> String:
	var w := load_world()
	if w.is_empty():
		return "Could not read %s." % FILE
	var data: Object = terrain.get("data")
	if data == null:
		return "This Terrain3D node has no data yet. Add a region first (or save the scene once) and try again."
	var n: int = w["n"]
	var cell: float = w["cell"]
	var w1 := n + 1
	var heights: PackedFloat32Array = w["heights"]
	terrain.set("vertex_spacing", cell)
	var half := n * cell * 0.5
	if data.has_method("import_images"):
		var img := Image.create_from_data(w1, w1, false, Image.FORMAT_RF, heights.to_byte_array())
		var imgs: Array[Image] = [img, null, null]
		data.call("import_images", imgs, Vector3(-half, 0.0, -half), 0.0, 1.0)
		var fixed := _repair(terrain, data, w, half)
		return "Imported the original terrain (%d x %d points, one every %.0f m) with Terrain3D's importer, then checked it against the original: %s Terrain3D's vertex spacing was set to %.0f m. Now run Embers: Paint ground textures (or press Send) to colour it." % [w1, w1, cell, fixed, cell]
	if not data.has_method("add_region_blankp"):
		return "This Terrain3D version has neither import_images nor add_region_blankp. It needs 1.0 or newer."
	var rs := int(terrain.get("region_size"))
	var span := rs * cell
	var count := 0
	var rx0 := floori(-half / span)
	var rx1 := floori((half - 0.01) / span)
	for rz in range(rx0, rx1 + 1):
		for rx in range(rx0, rx1 + 1):
			data.call("add_region_blankp", Vector3(rx * span + span * 0.5, 0.0, rz * span + span * 0.5))
	for z in w1:
		for x in w1:
			data.call("set_height", Vector3(-half + x * cell, 0.0, -half + z * cell), heights[z * w1 + x])
			count += 1
	if data.has_method("update_maps"):
		data.call("update_maps")
	return "Imported the original terrain (%d points, one every %.0f m). Terrain3D's vertex spacing was set to %.0f m. Now run Embers: Paint ground textures (or press Send) to colour it." % [count, cell, cell]


## After importing: sample the terrain every 8 points and compare it with the original. Anywhere Terrain3D has no ground (a region the
## importer did not make) or a different height, make the region and write the heights there point by point. Returns a sentence.
static func _repair(terrain: Node, data: Object, w: Dictionary, half: float) -> String:
	var n: int = w["n"]
	var cell: float = w["cell"]
	var w1 := n + 1
	var heights: PackedFloat32Array = w["heights"]
	var rs := int(terrain.get("region_size"))
	var span := rs * cell
	var bad := {}   # block (8 x 8 points) -> true
	var checked := 0
	for z in range(0, w1, 8):
		for x in range(0, w1, 8):
			checked += 1
			var h: float = data.call("get_height", Vector3(-half + x * cell, 0.0, -half + z * cell))
			if is_nan(h) or absf(h - heights[z * w1 + x]) > 0.2:
				bad[Vector2i(x / 8, z / 8)] = true
	if bad.is_empty():
		return "all %d sample points match." % checked
	var made := 0
	if data.has_method("add_region_blankp"):
		var seen := {}
		for b: Vector2i in bad.keys():
			var wx := -half + b.x * 8 * cell
			var wz := -half + b.y * 8 * cell
			var key := Vector2i(floori(wx / span), floori(wz / span))
			if not seen.has(key):
				seen[key] = true
				data.call("add_region_blankp", Vector3(key.x * span + span * 0.5, 0.0, key.y * span + span * 0.5))
				made += 1
	var set_n := 0
	for b: Vector2i in bad.keys():
		for dz in 8:
			for dx in 8:
				var px := b.x * 8 + dx
				var pz := b.y * 8 + dz
				if px >= w1 or pz >= w1:
					continue
				data.call("set_height", Vector3(-half + px * cell, 0.0, -half + pz * cell), heights[pz * w1 + px])
				set_n += 1
	if data.has_method("update_maps"):
		data.call("update_maps")
	return "%d of %d sample areas were missing or wrong, so %d regions were added and %d points written by hand." % [bad.size(), checked, made, set_n]


## Write the original terrain for Blender into res://original_terrain_for_blender: a mesh (OBJ), a float heightmap (EXR) and a
## picture of the ground (PNG). `step` = cells between mesh points (1 = every 2 m: huge; 2 = every 4 m). Returns a message.
static func export_blender(step := 2) -> String:
	var w := load_world()
	if w.is_empty():
		return "Could not read %s." % FILE
	DirAccess.make_dir_recursive_absolute(BLENDER_DIR)
	var n: int = w["n"]
	var cell: float = w["cell"]
	var w1 := n + 1
	var heights: PackedFloat32Array = w["heights"]
	var half := n * cell * 0.5
	var cols := (n / step) + 1
	var obj := FileAccess.open(BLENDER_DIR + "/original_terrain.obj", FileAccess.WRITE)
	if obj == null:
		return "Can't write into %s." % BLENDER_DIR
	obj.store_string("# The original Embers terrain. Metres. Y is up. One point every %.0f m.\no OriginalTerrain\n" % (cell * step))
	var lines := PackedStringArray()
	for zi in cols:
		for xi in cols:
			var cx := mini(xi * step, n)
			var cz := mini(zi * step, n)
			lines.append("v %.2f %.2f %.2f" % [-half + cx * cell, heights[cz * w1 + cx], -half + cz * cell])
		if lines.size() > 20000:
			obj.store_string("\n".join(lines) + "\n")
			lines = PackedStringArray()
	obj.store_string("\n".join(lines) + "\n")
	lines = PackedStringArray()
	for zi in cols - 1:
		for xi in cols - 1:
			var a := zi * cols + xi + 1
			var b := a + 1
			var c := a + cols
			var d := c + 1
			# the same cut as the game: (x+1,z) to (x,z+1)
			lines.append("f %d %d %d" % [a, b, c])
			lines.append("f %d %d %d" % [b, d, c])
		if lines.size() > 20000:
			obj.store_string("\n".join(lines) + "\n")
			lines = PackedStringArray()
	obj.store_string("\n".join(lines) + "\n")
	obj.close()
	var hi := Image.create_from_data(w1, w1, false, Image.FORMAT_RF, heights.to_byte_array())
	hi.save_exr(BLENDER_DIR + "/original_heightmap.exr", true)
	var ground: PackedByteArray = w["ground"]
	var lut: Array[PackedByteArray] = []
	for hex: String in GROUND_COL:
		var c := Color(hex)
		lut.append(PackedByteArray([int(c.r8), int(c.g8), int(c.b8)]))
	var rgb := PackedByteArray()
	rgb.resize(n * n * 3)
	for i in n * n:
		var px: PackedByteArray = lut[mini(ground[i], 7)]
		rgb[i * 3] = px[0]
		rgb[i * 3 + 1] = px[1]
		rgb[i * 3 + 2] = px[2]
	Image.create_from_data(n, n, false, Image.FORMAT_RGB8, rgb).save_png(BLENDER_DIR + "/original_ground.png")
	var readme := FileAccess.open(BLENDER_DIR + "/README.txt", FileAccess.WRITE)
	readme.store_string("""The original Embers terrain, for Blender.

original_terrain.obj    the land as a mesh, one point every %.0f m (File > Import > Wavefront in Blender). Metres, Y is up.
original_heightmap.exr  the heights as a float image (R channel, metres), %d x %d. Blender: a Displace modifier on a subdivided plane.
original_ground.png     the ground type of every 2 m cell (water, sand, grass, forest, mud, bog, snow, rock) as colours.

Back into the game: sculpt it in Blender and export glTF (.glb), drop the .glb into your scene, and add the node to the group
"embers_ground" (Node tab > Groups). The exporter reads it like Terrain3D. Y is up; 1 unit = 1 metre. Keep the sea at height 0.
""" % [cell * step, w1, w1])
	readme.close()
	return "Wrote the original terrain into %s: original_terrain.obj (a point every %.0f m, %d x %d), original_heightmap.exr and original_ground.png, with a README.txt on using them in Blender and bringing the result back." % [BLENDER_DIR, cell * step, cols, cols]
