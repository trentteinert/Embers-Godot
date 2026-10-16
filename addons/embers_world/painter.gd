@tool
class_name EmbersPainter
extends RefCounted
## Paints the Terrain3D ground textures from your EmbersRegion boxes and your painted map (EmbersBiomePaint), so what you
## see matches what the server and the game use (the region's ground, or the natural ground of its biome when it says
## "Keep"). Steep slopes are painted as rock, more or less depending on the biome (hills in the Frostspine turn rocky and
## snowy early, meadow hills only on the steep sides), so hills and mountains don't look like grass on a wall.
## Needs a Terrain3D node with textures added (Terrain3D > Assets > Textures). Run it from Project > Tools >
## "Embers: Paint ground textures from regions". It only touches the ground textures, never the heights.

## Which texture each ground type uses is found from the texture names. A name containing one of these words wins.
const WORDS := {
	0: ["water", "wet", "silt"],                       # Water (the lake and sea bed)
	1: ["sand", "beach", "shore"],                     # Sand
	2: ["grass", "meadow", "lawn"],                    # Grass
	3: ["forest", "leaf", "moss", "woodland", "dirt"],  # Forest
	4: ["mud", "soil", "dirt", "clay"],                # Mud
	5: ["bog", "swamp", "marsh", "peat", "mud"],       # Bog
	6: ["snow", "ice", "frost"],                       # Snow
	7: ["rock", "stone", "cliff", "gravel", "cobble"],  # Rock
}
## A region that leaves the ground on "Keep" gets the natural ground of its biome:
## Meadow, Thornwood, Mire, Frostspine, Coast
const BIOME_GROUND := [2, 3, 5, 6, 1]
const GROUND_NAMES := ["Water", "Sand", "Grass", "Forest", "Mud", "Bog", "Snow", "Rock"]
## Per biome: the slope (degrees) where rock starts to show and where it is all rock, and which texture names make
## the best rock for that biome (every word must be in the texture's name; the first match wins).
const BIOME_ROCK := [
	{"start": 20.0, "full": 38.0, "prefs": [["cliff"], ["rock"], ["stone"], ["gravel"]]},                      # Meadow
	{"start": 16.0, "full": 34.0, "prefs": [["moss", "rock"], ["dark", "rock"], ["rock"], ["stone"]]},         # Thornwood
	{"start": 28.0, "full": 46.0, "prefs": [["mud", "rock"], ["dark", "rock"], ["rock"], ["stone"]]},          # Mire (flat, boggy)
	{"start": 10.0, "full": 28.0, "prefs": [["snow", "rock"], ["frost", "rock"], ["ice", "rock"], ["rock"], ["stone"]]},  # Frostspine
	{"start": 24.0, "full": 42.0, "prefs": [["sand", "rock"], ["cliff"], ["rock"], ["stone"]]},                # Coast
]


static func run(root: Node, step_override := 0.0) -> Dictionary:
	var out := {"ok": false, "text": ""}
	var terrain: Node = _find_terrain(root)
	if terrain == null:
		out["text"] = "No Terrain3D node found in this scene. Open your world scene (the one with the Terrain3D node)."
		return out
	var regions: Array = root.find_children("*", "EmbersRegion", true, false)
	var maps: Array = root.find_children("*", "EmbersBiomePaint", true, false)
	var tex := _textures(terrain)
	if tex.is_empty():
		out["text"] = "The Terrain3D node has no textures yet. Add some under Terrain3D > Assets > Textures (grass, sand, rock, snow, mud ...) and name them like that."
		return out
	var data: Object = terrain.get("data")
	if data == null or not data.has_method("set_control_base_id"):
		out["text"] = "This Terrain3D version has no set_control_base_id. Update the Terrain3D addon (1.0 or newer)."
		return out
	var worlds: Array = root.find_children("*", "EmbersWorld", true, false)
	if root is EmbersWorld:
		worlds.append(root)
	var world: EmbersWorld = worlds[0] if not worlds.is_empty() else null
	var rocky: bool = world == null or world.rocky_slopes
	var rockiness: float = 1.0 if world == null else maxf(world.rockiness, 0.1)
	if regions.is_empty() and maps.is_empty() and not rocky and root.find_children("*", "EmbersRoad", true, false).is_empty():
		out["text"] = "No EmbersRegion boxes or EmbersBiomePaint node in this scene. Add one (Add Node > EmbersBiomePaint, then paint), or an EmbersRegion box."
		return out
	var ctx := make_context(root, terrain, tex, data, world, step_override)
	var map: Array = ctx["map"]
	var rock_for: Array = ctx["rock_for"]
	var step: float = ctx["step"]
	var report: Array[String] = []

	# 1. land nobody painted: only add rock on the steep parts (what you painted by hand stays)
	if rocky:
		var default_biome: int = 0 if world == null else world.default_biome
		var rects := _terrain_rects(terrain, data)
		var n0: int = ctx["rock_points"]
		for rc: Rect2 in rects:
			var x := rc.position.x
			while x < rc.end.x:
				var z := rc.position.y
				while z < rc.end.y:
					_point(ctx, Vector3(x, 0.0, z), -1, default_biome)
					z += step
				x += step
		var seen := maxi(int(ctx.get("visited", 0)), 1)
		report.append("Steep land everywhere: %d rock points. About %d%% of the land is rocky and %d%% is mostly rock (Rockiness %.2f). Raise Rockiness on the EmbersWorld node for more." % [int(ctx["rock_points"]) - n0, 100 * (int(ctx["rock_points"]) - n0) / seen, 100 * int(ctx.get("strong", 0)) / seen, float(ctx["rockiness"])])

	# 2. region boxes (later = higher priority wins)
	regions.sort_custom(func(a: EmbersRegion, b: EmbersRegion) -> bool: return a.priority < b.priority)
	for r: EmbersRegion in regions:
		var g: int = r.ground - 1 if r.ground > 0 else int(BIOME_GROUND[clampi(r.biome, 0, 4)])
		var id: int = int(map[g])
		if id < 0:
			continue
		var rx: float = r.size.x * 0.5 * r.global_transform.basis.x.length()
		var rz: float = r.size.y * 0.5 * r.global_transform.basis.z.length()
		var reach := sqrt(rx * rx + rz * rz)
		var c := r.global_position
		var n := 0
		var x2 := c.x - reach
		while x2 <= c.x + reach:
			var z2 := c.z - reach
			while z2 <= c.z + reach:
				if r.covers(x2, z2) and _point(ctx, Vector3(x2, 0.0, z2), id, r.biome):
					n += 1
				z2 += step
			x2 += step
		report.append("%s: %s (texture %d), %d points" % [r.name, GROUND_NAMES[g], id, n])

	# 3. the painted map, on top
	for pm: EmbersBiomePaint in maps:
		if pm.cells.is_empty():
			pm._ready()
		var np := 0
		for iz in pm.n:
			for ix in pm.n:
				var cx: float = pm.global_position.x - pm.size_m * 0.5 + ix * EmbersBiomePaint.CELL
				var cz: float = pm.global_position.z - pm.size_m * 0.5 + iz * EmbersBiomePaint.CELL
				var gx := cx + EmbersBiomePaint.CELL * 0.5
				var gz := cz + EmbersBiomePaint.CELL * 0.5
				var bt: int = pm.value_at("biome", gx, gz)
				var gt: int = pm.value_at("ground", gx, gz)
				if gt < 1:
					if bt < 0:
						continue
					gt = int(BIOME_GROUND[clampi(bt, 0, 4)])
				var tid: int = int(map[gt]) if gt < 8 else int((ctx["path_for"] as Array)[clampi(bt if bt >= 0 else 0, 0, 4)])
				if tid < 0:
					continue
				var biome_here: int = bt if bt >= 0 else _biome_of_ground(gt)
				var px := cx
				while px < cx + EmbersBiomePaint.CELL - 0.001:
					var pz := cz
					while pz < cz + EmbersBiomePaint.CELL - 0.001:
						if _point(ctx, Vector3(px, 0.0, pz), tid, biome_here):
							np += 1
						pz += step
					px += step
		report.append("%s (painted map): %d points" % [pm.name, np])

	# 4. roads and paths last, so they stay on top
	var roads: Array = root.find_children("*", "EmbersRoad", true, false)
	var rp := 0
	for rd: EmbersRoad in roads:
		rp += paint_road(ctx, rd)
	if not roads.is_empty():
		report.append("%d roads/paths: %d points" % [roads.size(), rp])

	_update(data)
	var t := "Painted %d points.\n\n" % int(ctx["count"])
	t += "Textures used:\n"
	for g in 8:
		t += "  %s -> %s\n" % [GROUND_NAMES[g], ("texture %d (%s)" % [map[g], tex[map[g]]]) if map[g] >= 0 else "none found"]
	if rocky:
		t += "Rock on steep slopes:\n"
		for b in 5:
			t += "  %s -> texture %d (%s)\n" % [EmbersBiomePaint.BIOMES[b], rock_for[b], tex.get(rock_for[b], "?")]
		t += "  %d steep points painted as rock\n" % int(ctx["rock_points"])
	var hist2: Dictionary = ctx.get("hist", {})
	if not hist2.is_empty():
		t += "Points painted per texture (what you mostly see):\n"
		var ids: Array = hist2.keys()
		ids.sort_custom(func(a: int, b: int) -> bool: return int(hist2[a]) > int(hist2[b]))
		for id2: int in ids:
			t += "  texture %d (%s): %d points\n" % [id2, tex.get(id2, "?"), int(hist2[id2])]
	t += "\n" + "\n".join(report)
	t += "\n\nA ground with no matching texture name uses the first texture. If a ground got the wrong texture, rename the texture in Terrain3D > Assets (for example \"grass\", \"sand\", \"rock\", \"snow\", \"mud\", \"bog\", \"forest\"; for hills name rocks like \"snow rock\", \"mossy rock\", \"cliff\") and run this again. Set Rocky Slopes / Rockiness on the EmbersWorld node to change the hills. Save the scene to keep the painting."
	out["ok"] = true
	out["text"] = t
	return out


## Everything a painting run needs, worked out once (also used by the brush while you paint biomes).
static func make_context(root: Node, terrain: Node, tex: Dictionary, data: Object, world: EmbersWorld, step_override := 0.0) -> Dictionary:
	var rocky: bool = world == null or world.rocky_slopes
	var rockiness: float = 1.0 if world == null else maxf(world.rockiness, 0.1)
	var map := _map(tex, root)
	var rock_for: Array = []   # per biome: the texture id used for steep ground
	for b in 5:
		var rt: int = _rock_texture(tex, b, int(map[7])) if world == null or world.use_biome_rocks else int(map[7])
		if world != null and world.rock_texture_slot >= 0 and tex.has(world.rock_texture_slot):
			rt = world.rock_texture_slot   # forced: every slope uses this texture slot
		rock_for.append(rt)
	var sp: Variant = terrain.get("vertex_spacing")
	var step: float = step_override if step_override > 0.0 else maxf(float(sp) if sp != null else 1.0, 0.5)
	var path_for: Array = []   # per biome: the path texture ("Path Meadow" ...), else any "path", else mud
	var names := ["meadow", "thornwood", "mire", "frostspine", "coast"]
	for b in 5:
		var id := -1
		for k: int in tex.keys():
			var nm := str(tex[k]).to_lower()
			if nm.contains("path") and nm.contains(names[b]):
				id = k
				break
		if id < 0:
			for k: int in tex.keys():
				if str(tex[k]).to_lower().contains("path"):
					id = k
					break
		if id < 0:
			for g: int in [4, 5, 1, 2]:   # no path texture: mud, bog, sand, grass - whichever exists (never an empty slot, that paints black)
				if int(map[g]) >= 0:
					id = int(map[g])
					break
		path_for.append(maxi(id, 0))
	var regions: Array = root.find_children("*", "EmbersRegion", true, false)
	regions.sort_custom(func(a: EmbersRegion, b2: EmbersRegion) -> bool: return a.priority < b2.priority)
	return {"terrain": terrain, "data": data, "step": step, "rocky": rocky, "rockiness": rockiness, "faceted": world == null or world.faceted_textures, "facet": 2.0 if world == null else world.facet_size_m, "flip": world != null and world.flip_facet_diagonal, "sharp": 0.0 if world == null else clampf(world.rock_sharpness, 0.0, 1.0), "rock_for": rock_for, "map": map, "tex": tex, "count": 0, "rock_points": 0,
		"water_y": 0.0 if world == null else world.water_y, "path_for": path_for, "regions": regions, "maps": root.find_children("*", "EmbersBiomePaint", true, false), "default_biome": 0 if world == null else world.default_biome}


## A context for the brush. On a problem it returns {"error": "why"} instead (shown on the toolbar).
static func brush_context(root: Node) -> Dictionary:
	var terrain: Node = _find_terrain(root)
	if terrain == null:
		return {"error": "no Terrain3D node in this scene"}
	var tex := _textures(terrain)
	if tex.is_empty():
		return {"error": "Terrain3D has no textures (run Embers: Set up ground textures)"}
	var data: Object = terrain.get("data")
	if data == null or not data.has_method("set_control_base_id"):
		return {"error": "this Terrain3D has no set_control_base_id (needs 1.0+)"}
	var worlds: Array = root.find_children("*", "EmbersWorld", true, false)
	var world: EmbersWorld = worlds[0] if not worlds.is_empty() else null
	var ctx := make_context(root, terrain, tex, data, world)
	ctx["terrain"] = terrain
	return ctx


## Paint the terrain textures inside a round brush from what is painted on the map right now (ground if painted there,
## else the biome's natural ground; steep parts become rock).
static func paint_disc(ctx: Dictionary, pm: EmbersBiomePaint, x: float, z: float, radius: float) -> int:
	var step: float = ctx["step"]
	var done := 0
	var px := snappedf(x - radius, step)
	while px <= x + radius:
		var pz := snappedf(z - radius, step)
		while pz <= z + radius:
			if (px - x) * (px - x) + (pz - z) * (pz - z) <= radius * radius:
				done += _paint_cell(ctx, pm, px, pz)
			pz += step
		px += step
	_update(ctx["data"])
	return done


## The same for a square (corner x0,z0 to x1,z1), used to recolour a region of Terrain3D after it was sculpted.
static func paint_box(ctx: Dictionary, pm: EmbersBiomePaint, x0: float, z0: float, x1: float, z1: float) -> int:
	var step: float = ctx["step"]
	var done := 0
	var px := snappedf(x0, step)
	while px < x1:
		var pz := snappedf(z0, step)
		while pz < z1:
			done += _paint_cell(ctx, pm, px, pz)
			pz += step
		px += step
	_update(ctx["data"])
	return done


## One terrain point of the brush: what the paint map says is here (or the biome's natural ground), and the rock on its slope.
static func _paint_cell(ctx: Dictionary, pm: EmbersBiomePaint, px: float, pz: float) -> int:
	var map: Array = ctx["map"]
	var bt: int = pm.value_at("biome", px, pz)
	var gt: int = pm.value_at("ground", px, pz)
	var was_unpainted: bool = bt < 0 and gt < 1
	if was_unpainted:
		bt = _biome_at(ctx, px, pz)   # nothing painted here (erased): the region box or the world's default
	if gt < 1:
		gt = int(BIOME_GROUND[clampi(bt, 0, 4)])
	var gtex: int = int(map[gt]) if gt < 8 else int((ctx["path_for"] as Array)[clampi(bt if bt >= 0 else 0, 0, 4)])   # 8 = a dirt patch: the path texture
	if gt >= 1 and gtex >= 0:
		if _point(ctx, Vector3(px, 0.0, pz), gtex, bt if bt >= 0 else _biome_of_ground(gt)):
			return 1
	return 0


## Recolour several squares (each [x0, z0, x1, z1] in world metres) and update Terrain3D once: what the live recolouring while sculpting uses.
static func paint_rects(ctx: Dictionary, pm: EmbersBiomePaint, rects: Array) -> int:
	var step: float = ctx["step"]
	var done := 0
	for r: Array in rects:
		var px := snappedf(float(r[0]), step)
		while px < float(r[2]):
			var pz := snappedf(float(r[1]), step)
			while pz < float(r[3]):
				done += _paint_cell(ctx, pm, px, pz)
				pz += step
			px += step
	_update(ctx["data"])
	return done


## Put every path (EmbersRoad) back on top of Terrain3D's colours, after a region was recoloured by biome.
static func repaint_roads(root: Node, ctx: Dictionary) -> void:
	for road: Node in root.find_children("*", "EmbersRoad", true, false):
		paint_road(ctx, road as EmbersRoad)


## Recolour Terrain3D's textures inside a square of the world (x0,z0 to x1,z1), after the ground there changed. Quietly does nothing
## when there is no paint node or no textures.
static func recolour_rect(root: Node, x0: float, z0: float, x1: float, z1: float) -> void:
	var papers := root.find_children("*", "EmbersBiomePaint", true, false)
	if papers.is_empty():
		return
	var ctx := brush_context(root)
	if ctx.has("error"):
		return
	paint_box(ctx, papers[0] as EmbersBiomePaint, x0, z0, x1, z1)
	repaint_roads(root, ctx)


## The biome at a point: the painted map, else the region box on top there, else the world's default.
static func _biome_at(ctx: Dictionary, x: float, z: float) -> int:
	for pm: EmbersBiomePaint in ctx["maps"]:
		var v: int = pm.value_at("biome", x, z)
		if v >= 0:
			return v
	var found := -1
	for r: EmbersRegion in ctx["regions"]:
		if r.covers(x, z):
			found = r.biome
	return found if found >= 0 else int(ctx["default_biome"])


## Paint the path texture along a road: full in the middle, soft at the edges, over whatever ground is there.
## Returns how many terrain points it painted.
static func paint_road(ctx: Dictionary, road: EmbersRoad) -> int:
	if road.curve == null or road.curve.point_count < 2:
		return 0
	var data: Object = ctx["data"]
	var sp: Variant = (ctx["terrain"] as Object).get("vertex_spacing") if ctx.has("terrain") else null
	var step: float = minf(float(ctx["step"]), maxf(float(sp) if sp != null else 1.0, 0.5))   # always the terrain's own spacing: the path is the same size however it was painted
	var rad: float = maxf(road.width * 0.5, step * 0.5)
	var best := {}   # Vector2i(grid) -> [blend, world pos]
	for p: Vector3 in road.curve.get_baked_points():
		var g: Vector3 = road.global_transform * p
		var x := snappedf(g.x - rad, step)
		while x <= g.x + rad:
			var z := snappedf(g.z - rad, step)
			while z <= g.z + rad:
				var d := Vector2(x - g.x, z - g.z).length()
				if d <= rad:
					var bl := 1.0 - smoothstep(rad * 0.55, rad, d)
					var key := Vector2i(roundi(x / step), roundi(z / step))
					if not best.has(key) or float((best[key] as Array)[0]) < bl:
						best[key] = [bl, Vector3(x, 0.0, z)]
				z += step
			x += step
	var n := 0
	if not ctx.get("path_logged", false):
		ctx["path_logged"] = true
		var ids: Array = ctx["path_for"]
		print("Embers: paths use texture slots ", ids, " = ", ids.map(func(i: int) -> String: return str((ctx["tex"] as Dictionary).get(i, "?"))))
	for key: Vector2i in best.keys():
		var rec: Array = best[key]
		var pos: Vector3 = rec[1]
		var h: float = data.get_height(pos)
		if is_nan(h):
			continue
		var b := _biome_at(ctx, pos.x, pos.z)
		if road.path_style > 0:
			b = road.path_style - 1
		var id: int = int((ctx["path_for"] as Array)[clampi(b, 0, 4)])
		var bl2: float = rec[0]
		if bl2 >= 0.5:
			# the middle: the path texture IS the ground there (like solid rock does); a blend of 1.0 is never used anywhere else
			data.set_control_base_id(pos, id)
			data.set_control_overlay_id(pos, id)
			data.set_control_blend(pos, 0.0)
		else:
			data.set_control_overlay_id(pos, id)
			data.set_control_blend(pos, bl2)
		if data.has_method("set_control_auto"):
			data.set_control_auto(pos, false)
		n += 1
	return n


## A plain-words report of everything that decides the ground colour at one spot (for the Inspect button).
static func describe_point(root: Node, pm: EmbersBiomePaint, x: float, z: float) -> String:
	var ctx := brush_context(root)
	if ctx.has("error"):
		return "Can't inspect: " + str(ctx["error"])
	var data: Object = ctx["data"]
	var tex: Dictionary = ctx["tex"]
	var pos := Vector3(x, 0.0, z)
	var t := "Spot (%.0f, %.0f)\n\n" % [x, z]
	var h: float = data.get_height(pos)
	t += "Terrain height: %s\n" % ("none (no terrain here)" if is_nan(h) else "%.1f m" % h)
	var step: float = ctx["step"]
	if not is_nan(h):
		var hx: float = data.get_height(pos + Vector3(step, 0, 0))
		var hz: float = data.get_height(pos + Vector3(0, 0, step))
		if not is_nan(hx) and not is_nan(hz):
			t += "Slope: %.0f degrees\n" % rad_to_deg(atan(sqrt((hx - h) * (hx - h) + (hz - h) * (hz - h)) / step))
	t += "\nWhat Terrain3D has stored here right now:\n"
	for pair: Array in [["base texture", "get_control_base_id"], ["overlay texture", "get_control_overlay_id"]]:
		if data.has_method(pair[1]):
			var id: int = int(data.call(pair[1], pos))
			t += "  %s: slot %d (%s)\n" % [pair[0], id, tex.get(id, "no such texture!")]
	if data.has_method("get_control_blend"):
		t += "  overlay blend: %.2f (0 = all base, 1 = all overlay)\n" % float(data.call("get_control_blend", pos))
	if data.has_method("get_control_auto"):
		t += "  auto shader: %s (if on, Terrain3D picks textures by itself and ignores the painting)\n" % ("ON" if bool(data.call("get_control_auto", pos)) else "off")
	t += "\nYour paint map (EmbersBiomePaint) here:\n"
	var b := pm.value_at("biome", x, z)
	var g := pm.value_at("ground", x, z)
	var zn := pm.value_at("zone", x, z)
	t += "  biome: %s\n" % (EmbersBiomePaint.BIOMES[b] if b >= 0 else "not painted")
	t += "  ground: %s\n" % (EmbersBiomePaint.GROUNDS[mini(g, 8) - 1] if g >= 1 else "not painted")
	t += "  zone: %s\n" % (EmbersBiomePaint.ZONES[zn] if zn >= 0 else "not painted")
	var covering: Array[String] = []
	for r: EmbersRegion in ctx["regions"]:
		if r.covers(x, z):
			covering.append("%s (biome %s, priority %d)" % [r.name, EmbersBiomePaint.BIOMES[r.biome], r.priority])
	t += "\nRegion boxes covering it: %s\n" % (", ".join(covering) if not covering.is_empty() else "none")
	t += "World default biome: %s\n" % EmbersBiomePaint.BIOMES[int(ctx["default_biome"])]
	var bio := _biome_at(ctx, x, z)
	t += "\nThe paint tool would use: biome %s, ground %s, rock for steep parts = %s" % [EmbersBiomePaint.BIOMES[bio], GROUND_NAMES[mini(g, 7) if g >= 1 else int(BIOME_GROUND[bio])], tex.get(int((ctx["rock_for"] as Array)[bio]), "?")]
	return t


## Terrain3D has a separate COLOUR layer that tints the ground (its colour brush paints it). A stray tint, such as green
## on a hill, shows through whatever texture is painted and cannot be fixed with textures. This puts the tint back to
## neutral white everywhere (the roughness in its alpha is kept). Returns a message.
static func clear_tint(terrain: Node) -> String:
	var data: Object = terrain.get("data")
	if data == null or not data.has_method("get_color") or not data.has_method("set_color") or not data.has_method("get_region_locations"):
		return "This Terrain3D version can't read its colour layer (needs 1.0+)."
	var rs: Variant = terrain.get("region_size")
	var sp: Variant = terrain.get("vertex_spacing")
	if rs == null:
		return "Could not read the terrain's region size."
	var size := int(rs)
	var spacing := float(sp) if sp != null else 1.0
	var changed := 0
	var total := 0
	for loc_v: Variant in data.call("get_region_locations"):
		var loc := Vector2i(loc_v)
		for py in size:
			for px in size:
				var pos := Vector3((loc.x * size + px) * spacing, 0.0, (loc.y * size + py) * spacing)
				var c: Color = data.call("get_color", pos)
				total += 1
				if c.r < 0.98 or c.g < 0.98 or c.b < 0.98:
					data.call("set_color", pos, Color(1, 1, 1, c.a))
					changed += 1
	if data.has_method("update_maps"):
		for cls in ["Terrain3DRegion", "Terrain3DStorage"]:
			if ClassDB.class_exists(cls):
				data.call("update_maps", ClassDB.class_get_integer_constant(cls, "TYPE_COLOR"), true, true)
				break
	return "Looked at %d points and cleared the colour tint on %d of them. If the green was a tint, it is gone now. Save the scene and the Terrain3D data." % [total, changed]


## Slope (rise over run) of the one triangle of the facet grid that the middle of this control pixel falls in. The triangles
## and their diagonal are exactly those of the low-poly tool (including Flip Facet Diagonal). A pixel on the diagonal itself
## goes to the lower-left or upper-right triangle depending on which side of it its centre leans, so the two split evenly.
static func _face_grad(ctx: Dictionary, pos: Vector3) -> float:
	var cell: float = ctx.get("facet", 2.0)
	var half: float = 0.5 * float(ctx.get("step", 1.0))
	var fx := (pos.x + half) / cell
	var fz := (pos.z + half) / cell
	var gx := floori(fx)
	var gz := floori(fz)
	var tx := fx - gx
	var tz := fz - gz
	var flip: bool = ctx.get("flip", false)
	var lower: bool
	if flip:
		lower = tx > tz or (is_equal_approx(tx, tz) and tx < 0.5)   # diagonal (0,0)-(1,1)
	else:
		var s := tx + tz
		lower = s < 1.0 - 0.0001 or (is_equal_approx(s, 1.0) and tx > tz)   # diagonal (1,0)-(0,1)
	var cache: Dictionary = ctx.get("_fc", {})
	var key := Vector3i(gx, gz, 1 if lower else 0)
	if not cache.has(key):
		var d: Object = ctx["data"]
		var c00: float = d.get_height(Vector3(gx * cell, 0, gz * cell))
		var c10: float = d.get_height(Vector3((gx + 1) * cell, 0, gz * cell))
		var c01: float = d.get_height(Vector3(gx * cell, 0, (gz + 1) * cell))
		var c11: float = d.get_height(Vector3((gx + 1) * cell, 0, (gz + 1) * cell))
		if is_nan(c00) or is_nan(c10) or is_nan(c01) or is_nan(c11):
			cache[key] = -1.0
		else:
			var dx: float
			var dz: float
			if flip:
				if lower:   # c00, c10, c11
					dx = c10 - c00
					dz = c11 - c10
				else:       # c00, c11, c01
					dx = c11 - c01
					dz = c01 - c00
			elif lower:     # c00, c10, c01
				dx = c10 - c00
				dz = c01 - c00
			else:           # c11, c01, c10
				dx = c11 - c01
				dz = c11 - c10
			cache[key] = sqrt(dx * dx + dz * dz) / cell
		ctx["_fc"] = cache
	return float(cache[key])


## One terrain point. base < 0 = leave the ground texture alone (only rock on slopes). Returns true if it painted.
static func _point(ctx: Dictionary, pos: Vector3, base: int, biome: int) -> bool:
	var data: Object = ctx["data"]
	var h: float = data.get_height(pos)
	if is_nan(h):   # no terrain here
		return false
	ctx["visited"] = int(ctx.get("visited", 0)) + 1
	# ground at or below the sea is seabed (the Water texture), whatever biome is painted: the game's water ground
	if base >= 0 and h <= float(ctx.get("water_y", 0.0)) + 0.05:
		var wid: int = int((ctx["map"] as Array)[0])
		if wid >= 0:
			data.set_control_base_id(pos, wid)
			data.set_control_overlay_id(pos, wid)
			data.set_control_blend(pos, 0.0)
			if data.has_method("set_control_auto"):
				data.set_control_auto(pos, false)
			ctx["count"] = int(ctx["count"]) + 1
			return true
	var blend := 0.0
	var rock := -1
	if ctx["rocky"]:
		var step: float = ctx["step"]
		var grad := -1.0
		if bool(ctx.get("faceted", false)):
			grad = _face_grad(ctx, pos)   # the slope of the whole triangle, so a face is all rock or all grass
		else:
			var hx: float = data.get_height(pos + Vector3(step, 0, 0))
			var hz: float = data.get_height(pos + Vector3(0, 0, step))
			if not is_nan(hx) and not is_nan(hz):
				grad = sqrt((hx - h) * (hx - h) + (hz - h) * (hz - h)) / step
		if grad >= 0.0:
			var prm: Dictionary = BIOME_ROCK[clampi(biome, 0, 4)]
			var k: float = ctx["rockiness"]
			var a0 := tan(deg_to_rad(float(prm["start"]) / k))
			var a1 := tan(deg_to_rad(minf(float(prm["full"]) / k, 85.0)))
			blend = smoothstep(a0, a1, grad)
			# sharpness: 0 = the soft grass-to-rock fade, 1 = a hard edge (no mixed band)
			var sh: float = ctx["sharp"]
			if bool(ctx.get("faceted", false)):
				blend = 1.0 if blend >= 0.5 else 0.0   # one texture per face, never a mix
			elif sh > 0.0:
				var w := maxf(0.5 * (1.0 - sh), 0.001)
				blend = smoothstep(0.5 - w, 0.5 + w, blend)
			if blend >= 0.5:
				ctx["strong"] = int(ctx.get("strong", 0)) + 1
			rock = int((ctx["rock_for"] as Array)[clampi(biome, 0, 4)])
	# mostly rock: make the base BE the rock (no overlay mix at all), so it shows the plain rock texture and never a murky
	# grass-and-rock blend; only the soft fringe (less than half rock) uses the overlay blend
	var solid_rock: bool = rock >= 0 and blend >= 0.5
	if base < 0:
		# a leftover path (its EmbersRoad was deleted) on land nobody painted: put the biome's ground back
		var paths: Array = ctx["path_for"]
		var cur: int = data.get_control_base_id(pos) if data.has_method("get_control_base_id") else -1
		if cur >= 0 and paths.has(cur) and not (ctx["map"] as Array).has(cur):
			var gid: int = int((ctx["map"] as Array)[int(BIOME_GROUND[clampi(biome, 0, 4)])])
			if gid >= 0:
				data.set_control_base_id(pos, gid)
				data.set_control_overlay_id(pos, gid)
				data.set_control_blend(pos, 0.0)
				return true
		if blend <= 0.0 or rock < 0:
			return false
		if solid_rock:
			data.set_control_base_id(pos, rock)
			data.set_control_overlay_id(pos, rock)
			data.set_control_blend(pos, 0.0)
		else:
			data.set_control_overlay_id(pos, rock)
			data.set_control_blend(pos, blend)
		if data.has_method("set_control_auto"):
			data.set_control_auto(pos, false)
		ctx["rock_points"] = int(ctx["rock_points"]) + 1
		return true
	var hist: Dictionary = ctx.get("hist", {})
	var shown: int = rock if blend >= 0.5 and rock >= 0 else base   # the texture you mostly see here
	hist[shown] = int(hist.get(shown, 0)) + 1
	ctx["hist"] = hist
	if solid_rock:
		data.set_control_base_id(pos, rock)
		data.set_control_overlay_id(pos, rock)
		data.set_control_blend(pos, 0.0)
	else:
		data.set_control_base_id(pos, base)
		data.set_control_overlay_id(pos, rock if rock >= 0 and blend > 0.0 else base)
		data.set_control_blend(pos, blend)
	if data.has_method("set_control_auto"):
		data.set_control_auto(pos, false)
	ctx["count"] = int(ctx["count"]) + 1
	if blend > 0.05:
		ctx["rock_points"] = int(ctx["rock_points"]) + 1
	return true


static func _biome_of_ground(g: int) -> int:
	return {1: 4, 2: 0, 3: 1, 4: 2, 5: 2, 6: 3}.get(g, 0)


## The best texture for steep ground in a biome (see BIOME_ROCK); falls back to the Rock texture.
static func _rock_texture(tex: Dictionary, biome: int, fallback: int) -> int:
	for pref: Array in BIOME_ROCK[biome]["prefs"]:
		for k: int in tex.keys():
			var nm := str(tex[k]).to_lower()
			var ok := true
			for w: String in pref:
				if not nm.contains(w):
					ok = false
					break
			if ok:
				return k
	return fallback


## World rectangles (x, z) the Terrain3D has regions in; empty if this Terrain3D version doesn't say.
static func _terrain_rects(terrain: Node, data: Object) -> Array:
	var out: Array = []
	if not data.has_method("get_region_locations"):
		return out
	var rs: Variant = terrain.get("region_size")
	var sp: Variant = terrain.get("vertex_spacing")
	if rs == null:
		return out
	var size := float(rs) * (float(sp) if sp != null else 1.0)
	for loc: Variant in data.call("get_region_locations"):
		var l := Vector2i(loc)
		out.append(Rect2(Vector2(l.x * size, l.y * size), Vector2(size, size)))
	return out


static func _find_terrain(root: Node) -> Node:
	if _is_terrain(root):
		return root
	for n in root.find_children("*", "", true, false):
		if _is_terrain(n):
			return n
	return null


static func _is_terrain(n: Node) -> bool:
	return n.get_class() == "Terrain3D" or (n.get("data") != null and n.get("assets") != null)


## texture id -> name, from Terrain3D's asset list (1.x: assets.texture_list)
static func _textures(terrain: Node) -> Dictionary:
	var out := {}
	var assets: Object = terrain.get("assets")
	if assets == null:
		return out
	# the slot of a texture is its place in the list; a texture's own "id" property can be stale (0) after re-installing
	if assets.has_method("get_texture"):
		for i in 32:
			var tx: Object = assets.call("get_texture", i)
			if tx != null:
				out[i] = str(tx.get("name"))
		if not out.is_empty():
			return out
	var list: Variant = assets.get("texture_list")
	if list is Array:
		for i in (list as Array).size():
			var t: Variant = (list as Array)[i]
			if t != null:
				out[i] = str(t.get("name"))
	return out


## ground type -> texture id (-1 = none found). A mapping can be forced on the EmbersWorld node (texture_ids, 8 numbers, -1 = auto).
static func _map(tex: Dictionary, root: Node) -> Array:
	var forced: PackedInt32Array = PackedInt32Array()
	var worlds := root.find_children("*", "EmbersWorld", true, false)
	if root is EmbersWorld:
		worlds.append(root)
	if not worlds.is_empty():
		forced = (worlds[0] as EmbersWorld).texture_ids
	var first: int = tex.keys()[0]
	var res := []
	for g in 8:
		var id := -1
		if g < forced.size() and forced[g] >= 0 and tex.has(forced[g]):
			id = forced[g]
		else:
			for w: String in WORDS[g]:
				for k: int in tex.keys():
					if str(tex[k]).to_lower().contains(w):
						id = k
						break
				if id >= 0:
					break
		res.append(id if id >= 0 else first)   # nothing matched: use the first texture rather than leaving a hole
	return res


static func _update(data: Object) -> void:
	if not data.has_method("update_maps"):
		return
	# tell Terrain3D the control (texture) map changed in every region: refreshes the editor view and makes it save
	if data.has_method("get_region_locations") and data.has_method("set_region_modified"):
		for loc: Variant in data.call("get_region_locations"):
			data.call("set_region_modified", Vector2i(loc), true)
	for cls in ["Terrain3DRegion", "Terrain3DStorage"]:
		if ClassDB.class_exists(cls):
			var t: int = ClassDB.class_get_integer_constant(cls, "TYPE_CONTROL")
			data.call("update_maps", t, true, true)
			return
	data.call("update_maps")
