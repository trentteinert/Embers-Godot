@tool
class_name EmbersLowPoly
extends RefCounted
## Gives Terrain3D the original game's low-poly look. The game's ground is a 2 m grid of flat triangles (every square is
## cut into two triangles along the same diagonal). Terrain3D is smooth because its heightmap is finer. This resamples
## your terrain onto that same 2 m grid with the same triangles, so hills get flat facets and corners like the game's
## (and the server's ground, which is sampled on that grid, matches what you see). A backup of the smooth heights is
## kept so you can go back. Do this last, after you have finished sculpting.

const BACKUP_DIR := "res://embers_lowpoly_backup"
## A point is never moved more than this by low-polying (metres); a bigger change means a bad corner, not a real facet.
const MAX_CHANGE := 12.0


## The game's own height at (x, z): triangles on a grid of `cell` metres, diagonal from (x+1, z) to (x, z+1).
static func facet_height(c00: float, c10: float, c01: float, c11: float, tx: float, tz: float, flip := false) -> float:
	if flip:
		# the other diagonal: from (0,0) to (1,1)
		if tx >= tz:
			return c00 + (c10 - c00) * tx + (c11 - c10) * tz
		return c00 + (c11 - c01) * tx + (c01 - c00) * tz
	if tx + tz <= 1.0:
		return c00 + (c10 - c00) * tx + (c01 - c00) * tz
	return c11 + (c01 - c11) * (1.0 - tx) + (c10 - c11) * (1.0 - tz)


## Whole-region reading and writing (one call per region instead of one per height point: about a hundred times faster). The helpers
## return empty / false when this Terrain3D has no such calls, and the callers fall back to the slow per-point way.
static func _region_at(data: Object, loc: Vector2i, rs: int, sp: float) -> Object:
	if not data.has_method("get_regionp"):
		return null
	return data.call("get_regionp", Vector3((loc.x + 0.5) * rs * sp, 0.0, (loc.y + 0.5) * rs * sp))


static func _read_region(data: Object, loc: Vector2i, rs: int, sp: float) -> PackedFloat32Array:
	var r := _region_at(data, loc, rs, sp)
	if r == null or not r.has_method("get_height_map"):
		return PackedFloat32Array()
	var img: Image = r.call("get_height_map")
	if img == null or img.get_width() != rs or img.get_height() != rs or img.get_format() != Image.FORMAT_RF:
		return PackedFloat32Array()
	return img.get_data().to_float32_array()


static func _write_region(data: Object, loc: Vector2i, rs: int, sp: float, heights: PackedFloat32Array) -> bool:
	var r := _region_at(data, loc, rs, sp)
	if r == null or not r.has_method("set_height_map") or heights.size() != rs * rs:
		return false
	r.call("set_height_map", Image.create_from_data(rs, rs, false, Image.FORMAT_RF, heights.to_byte_array()))
	if r.has_method("set_modified"):
		r.call("set_modified", true)
	# check what Terrain3D now reports at a few places against what was written. If it differs (a different layout, or it did not take),
	# say so and the caller writes the region point by point instead, which is slower but always right
	for k in 24:
		var px := (k * 53 + 7) % rs
		var pz := (k * 97 + 11) % rs
		var want := heights[pz * rs + px]
		if is_nan(want):
			continue
		var got: float = data.call("get_height", Vector3((loc.x * rs + px) * sp, 0.0, (loc.y * rs + pz) * sp))
		if is_nan(got) or absf(got - want) > 0.02:
			return false
	return true


static func _tick(progress: Callable, text: String) -> void:
	if progress.is_valid():
		progress.call(text)
	await (Engine.get_main_loop() as SceneTree).process_frame


static func _info(terrain: Node) -> Dictionary:
	var data: Object = terrain.get("data")
	if data == null or not data.has_method("get_height") or not data.has_method("set_height") or not data.has_method("get_region_locations"):
		return {}
	var rs: Variant = terrain.get("region_size")
	var sp: Variant = terrain.get("vertex_spacing")
	if rs == null:
		return {}
	return {"data": data, "rs": int(rs), "sp": float(sp) if sp != null else 1.0}


## Make the terrain low poly. Returns a message for the person.
static func apply(terrain: Node, cell := 2.0, flip := false, progress := Callable()) -> String:
	var info := _info(terrain)
	if info.is_empty():
		return "This needs Terrain3D 1.0 or newer (it could not read the terrain's heights and regions)."
	var data: Object = info["data"]
	var rs: int = info["rs"]
	var sp: float = info["sp"]
	var locs: Array = data.call("get_region_locations")
	if locs.is_empty():
		return "The terrain has no regions yet. Sculpt some land first."
	DirAccess.make_dir_recursive_absolute(BACKUP_DIR)
	if not FileAccess.file_exists(BACKUP_DIR + "/spacing.txt"):
		var sf := FileAccess.open(BACKUP_DIR + "/spacing.txt", FileAccess.WRITE)
		if sf != null:
			sf.store_string(str(sp))   # the vertex spacing the backed-up heights belong to
	var corners := {}   # grid corner -> height read from the smooth terrain
	var plan := []      # [loc, PackedFloat32Array new heights]
	var smooth_values := {}
	var count := 0
	for loc_v: Variant in locs:
		var loc := Vector2i(loc_v)
		var old := PackedFloat32Array()
		var neu := PackedFloat32Array()
		old.resize(rs * rs)
		neu.resize(rs * rs)
		await _tick(progress, "Low poly: reading region %d of %d ..." % [plan.size() + 1, locs.size()])
		var fast_old := _read_region(data, loc, rs, sp)
		var have_fast := fast_old.size() == rs * rs
		for py in rs:
			for px in rs:
				var x := (loc.x * rs + px) * sp
				var z := (loc.y * rs + py) * sp
				old[py * rs + px] = fast_old[py * rs + px] if have_fast else float(data.call("get_height", Vector3(x, 0, z)))
				var gx := floori(x / cell)
				var gz := floori(z / cell)
				var tx := x / cell - gx
				var tz := z / cell - gz
				var h := facet_height(_corner(data, corners, gx, gz, cell), _corner(data, corners, gx + 1, gz, cell), _corner(data, corners, gx, gz + 1, cell), _corner(data, corners, gx + 1, gz + 1, cell), tx, tz, flip)
				# never let a bad corner (outside the terrain, or a wild value) make a spike: keep the smooth height there
				var was := old[py * rs + px]
				if is_nan(h) or is_inf(h) or (not is_nan(was) and absf(h - was) > MAX_CHANGE):
					h = was
				neu[py * rs + px] = h
		# a backup of the smooth heights, once (never overwrite an earlier backup with already low-poly data)
		var path := "%s/%d_%d.bin" % [BACKUP_DIR, loc.x, loc.y]
		if not FileAccess.file_exists(path):
			var f := FileAccess.open(path, FileAccess.WRITE)
			if f != null:
				f.store_buffer(old.to_byte_array())
		plan.append([loc, neu])
	for rec: Array in plan:
		var loc2: Vector2i = rec[0]
		var heights: PackedFloat32Array = rec[1]
		await _tick(progress, "Low poly: writing region %d of %d ..." % [plan.find(rec) + 1, plan.size()])
		if _write_region(data, loc2, rs, sp, heights):
			count += rs * rs
			continue
		for py in rs:
			for px in rs:
				var h2 := heights[py * rs + px]
				if is_nan(h2):
					continue
				data.call("set_height", Vector3((loc2.x * rs + px) * sp, 0, (loc2.y * rs + py) * sp), h2)
				count += 1
	_flat_normals(terrain, true)
	_update(data)
	return "Done: %d height points now follow the game's %.0f m triangles (%d regions). A backup of the smooth terrain is in %s; use Project > Tools > Embers: Restore smooth terrain to go back. Flat Terrain Normals was switched on in the terrain's material so the faces light flat. Save the scene and the Terrain3D data to keep it. Do this after you finish sculpting; sculpt again, then run it again." % [count, cell, locs.size(), BACKUP_DIR]


static func _corner(data: Object, cache: Dictionary, gx: int, gz: int, cell: float) -> float:
	var key := Vector2i(gx, gz)
	if not cache.has(key):
		cache[key] = float(data.call("get_height", Vector3(gx * cell, 0, gz * cell)))
	return cache[key]


## Put the smooth heights back from the backup. Regions that no longer exist are created again (any region more than 1.4 km from the
## middle of the map is skipped: that is a stray, not part of the world), and the vertex spacing is set to the one the backup was made at.
static func restore(terrain: Node, progress := Callable()) -> String:
	var info := _info(terrain)
	if info.is_empty():
		return "This needs Terrain3D 1.0 or newer."
	var data: Object = info["data"]
	var rs: int = info["rs"]
	var dir := DirAccess.open(BACKUP_DIR)
	if dir == null:
		return "No backup found (%s). Nothing to restore." % BACKUP_DIR
	var sp: float = info["sp"]
	if FileAccess.file_exists(BACKUP_DIR + "/spacing.txt"):
		sp = float(FileAccess.get_file_as_string(BACKUP_DIR + "/spacing.txt"))
	else:
		sp = 1.0   # backups made before the spacing was recorded were all at Terrain3D's default
	terrain.set("vertex_spacing", sp)
	var span := rs * sp
	var have := {}
	for l: Variant in data.call("get_region_locations"):
		have[Vector2i(l)] = true
	var n := 0
	var added := 0
	var skipped := 0
	var restored := 0
	for file in dir.get_files():
		if not file.ends_with(".bin"):
			continue
		var parts := file.get_basename().split("_")
		if parts.size() != 2:
			continue
		var loc := Vector2i(int(parts[0]), int(parts[1]))
		var centre := Vector3((loc.x + 0.5) * span, 0.0, (loc.y + 0.5) * span)
		if absf(centre.x) > 1400.0 or absf(centre.z) > 1400.0:
			skipped += 1
			continue
		var f := FileAccess.open(BACKUP_DIR + "/" + file, FileAccess.READ)
		var heights := f.get_buffer(f.get_length()).to_float32_array()
		if heights.size() != rs * rs:
			continue
		if not have.has(loc) and data.has_method("add_region_blankp"):
			data.call("add_region_blankp", centre)
			have[loc] = true
			added += 1
		restored += 1
		await _tick(progress, "Restoring region %d (%s) ..." % [restored, file.get_basename()])
		if _write_region(data, loc, rs, sp, heights):
			n += rs * rs
			continue
		for py in rs:
			for px in rs:
				var h := heights[py * rs + px]
				if is_nan(h):
					continue
				data.call("set_height", Vector3((loc.x * rs + px) * sp, 0, (loc.y * rs + py) * sp), h)
				n += 1
	_flat_normals(terrain, false)
	_update(data)
	return "Restored the smooth terrain: %d height points in %d regions (%d regions had to be created again, %d stray far-away ones skipped). Vertex spacing is %.1f m. Textures are not part of the backup: use the biome brush or the refresh icon to colour it again. The backup files are still in %s. Save the scene and the Terrain3D data." % [n, restored, added, skipped, sp, BACKUP_DIR]


## Terrain3D's material can light every triangle flat (\"Flat Terrain Normals\"): that is what makes the facets visible.
static func _flat_normals(terrain: Node, on: bool) -> void:
	var mat: Object = terrain.get("material")
	if mat != null and "flat_terrain_normals" in mat:
		mat.set("flat_terrain_normals", on)


static func _update(data: Object) -> void:
	if not data.has_method("update_maps"):
		return
	for cls in ["Terrain3DRegion", "Terrain3DStorage"]:
		if ClassDB.class_exists(cls):
			data.call("update_maps", ClassDB.class_get_integer_constant(cls, "TYPE_HEIGHT"), true, true)
			return
	data.call("update_maps")
