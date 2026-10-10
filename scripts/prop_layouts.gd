class_name PropLayouts
extends RefCounted
## Hand-made furniture layouts. One JSON file per building kind in res://layouts/ (shop.json, tavern.json ...).
## They are applied on top of what the building code generates, so your edits survive code changes:
##   "props":   { "bed_2": {"d": [dx, dy, dz], "r": degrees} }   moved / turned pieces (offset from where the code put them)
##   "deleted": [ "barrel_3" ]                                     pieces you removed
##   "added":   [ {"id": "add_1", "kind": "barrel", "pos": [x, y, z], "yaw": degrees, "upper": false} ]
##   "instances": { "<x>_<z>": {props, deleted, added} }          a layout for ONE building only (keyed by its world position)
## Piece names are the kind plus a counter in build order: the 3rd barrel a building creates is "barrel_3".

const DIR := "res://layouts"
static var _cache := {}


static func path_for(kind: String) -> String:
	return "%s/%s.json" % [DIR, kind]


## Whole file for a kind (shared layout plus any single-building overrides).
static func get_file(kind: String) -> Dictionary:
	if _cache.has(kind):
		return _cache[kind]
	var out := {}
	var p := path_for(kind)
	if FileAccess.file_exists(p):
		var f := FileAccess.open(p, FileAccess.READ)
		if f:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				out = parsed
	_cache[kind] = out
	return out


## Key of one particular building: its world position, rounded.
static func inst_key(pos: Vector3) -> String:
	return "%d_%d" % [roundi(pos.x), roundi(pos.z)]


## The saved key that belongs to the building at `inst` (exact, or within 1.5 m in case the village shifted a little).
static func match_instance(kind: String, inst: String) -> String:
	if inst == "":
		return ""
	var insts: Dictionary = get_file(kind).get("instances", {})
	if insts.has(inst):
		return inst
	var a := inst.split("_")
	if a.size() != 2:
		return ""
	var p := Vector2(float(a[0]), float(a[1]))
	var best := ""
	var bd := 1.5
	for k: String in insts:
		var kk := k.split("_")
		if kk.size() == 2:
			var dd := p.distance_to(Vector2(float(kk[0]), float(kk[1])))
			if dd <= bd:
				bd = dd
				best = k
	return best


static func has_instance(kind: String, inst: String) -> bool:
	return match_instance(kind, inst) != ""


## The layout a building should use: its own override if it has one, else the shared one for the kind.
static func get_layout(kind: String, inst := "") -> Dictionary:
	var f := get_file(kind)
	var k := match_instance(kind, inst)
	if k != "":
		return (f["instances"] as Dictionary)[k]
	return f


static func _is_empty(d: Dictionary) -> bool:
	return d.get("props", {}).is_empty() and d.get("deleted", []).is_empty() and d.get("added", []).is_empty()


static func _write(kind: String, f: Dictionary) -> bool:
	if (f.get("instances", {}) as Dictionary).is_empty():
		f.erase("instances")
	if _is_empty(f) and not f.has("instances"):
		_cache[kind] = {}
		if FileAccess.file_exists(path_for(kind)):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path_for(kind)))
		return true
	_cache[kind] = f
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	_backup(kind)
	var fa := FileAccess.open(path_for(kind), FileAccess.WRITE)
	if fa == null:
		return false
	fa.store_string(JSON.stringify(f, "\t"))
	return true


## How many single-building layouts the last save_all() replaced.
static var last_cleared := 0


## Keeps the last 15 versions of each layout file in res://layouts/backup/ (so a bad save can always be undone).
static func _backup(kind: String) -> void:
	var p := path_for(kind)
	if not FileAccess.file_exists(p):
		return
	var bdir := ProjectSettings.globalize_path(DIR + "/backup")
	DirAccess.make_dir_recursive_absolute(bdir)
	var src := FileAccess.open(p, FileAccess.READ)
	if src == null:
		return
	var txt := src.get_as_text()
	src.close()
	var dst := FileAccess.open("%s/%s_%d.json" % [bdir, kind, int(Time.get_unix_time_from_system() * 10.0)], FileAccess.WRITE)
	if dst:
		dst.store_string(txt)
		dst.close()
	var names: Array[String] = []
	for fn in DirAccess.get_files_at(bdir):
		if fn.begins_with(kind + "_") and fn.ends_with(".json") and not fn.contains("_instances_"):
			names.append(fn)
	names.sort()
	while names.size() > 15:
		DirAccess.remove_absolute(bdir + "/" + names[0])
		names.remove_at(0)


## Save as the layout for every building of this kind. Every single-building override is dropped too, so all
## of them really follow the new shared layout (the dropped ones are kept in res://layouts/backup/).
static func save_all(kind: String, data: Dictionary, _inst := "") -> bool:
	var f := get_file(kind).duplicate(true)
	var instances: Dictionary = f.get("instances", {})
	last_cleared = instances.size()
	if not instances.is_empty():
		var bdir := ProjectSettings.globalize_path(DIR + "/backup")
		DirAccess.make_dir_recursive_absolute(bdir)
		var fb := FileAccess.open("%s/%s_instances_%d.json" % [bdir, kind, int(Time.get_unix_time_from_system())], FileAccess.WRITE)
		if fb:
			fb.store_string(JSON.stringify(instances, "\t"))
	f = {"v": 1, "props": data.get("props", {}), "deleted": data.get("deleted", []), "added": data.get("added", [])}
	return _write(kind, f)


## Save as the layout for this one building only.
static func save_instance(kind: String, inst: String, data: Dictionary) -> bool:
	var f := get_file(kind).duplicate(true)
	var instances: Dictionary = f.get("instances", {})
	var mk := match_instance(kind, inst)
	instances[mk if mk != "" else inst] = {"v": 1, "props": data.get("props", {}), "deleted": data.get("deleted", []), "added": data.get("added", [])}
	f["instances"] = instances
	return _write(kind, f)


static func remove_instance(kind: String, inst: String) -> bool:
	var f := get_file(kind).duplicate(true)
	var mk := match_instance(kind, inst)
	(f.get("instances", {}) as Dictionary).erase(mk if mk != "" else inst)
	return _write(kind, f)


## Back-compat: save the shared layout.
static func save_layout(kind: String, data: Dictionary) -> bool:
	return save_all(kind, data)


static func reset(kind: String) -> void:
	_write(kind, {})
