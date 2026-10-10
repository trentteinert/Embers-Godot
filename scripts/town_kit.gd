class_name TownKit
extends RefCounted
## Low-poly building kit for towns, villages and camps. Every asset is built from simple shapes
## into one vertex-coloured mesh (plus a glowing surface for windows, lamps and fires), with
## box collision. Each region has its own look (see STYLES). Things face +Z (doors on +Z) and
## stand on y = 0, so the caller only needs to place, turn and flatten the ground under them.
##
##   var house := TownKit.build("cottage", "meadow", 7)
##   var town := TownKit.village("meadow", 42)      # a whole village (radius ~30 m)
##   var camp := TownKit.camp("thornwood", 3)        # a small camp
##
## Windmill blades are put in the group "spin" (rotate them on Z) and flags/banners in "sway".

const STYLES := {
	"meadow": {"wall": "e8dcc0", "wall2": "d8c8a8", "timber": "6b4a2c", "roof": "c8a050", "roof2": "b08a40", "stone": "9a9488",
		"door": "5a3a22", "trim": "a8503a", "cloth": "b8443a", "cloth2": "e8dcc0", "ground": "8a7350", "fence": "fence", "snow": false},
	"coast": {"wall": "f0ece0", "wall2": "e0dccc", "timber": "4a5a6a", "roof": "5a7088", "roof2": "4a6078", "stone": "a8a8a0",
		"door": "2a5a7a", "trim": "3a8ab0", "cloth": "3a7a9a", "cloth2": "f0ece0", "ground": "b8a880", "fence": "fence", "snow": false},
	"briar": {"wall": "5a4430", "wall2": "4a3828", "timber": "2a1e14", "roof": "3a4a30", "roof2": "2e3c26", "stone": "4e4c44",
		"door": "20160e", "trim": "8a4a6a", "cloth": "5a2a3a", "cloth2": "a89870", "ground": "3e3226", "fence": "palisade", "snow": false},
	"downs": {"wall": "a8a490", "wall2": "98947f", "timber": "5a4a38", "roof": "6a8048", "roof2": "5a7040", "stone": "8a8a80",
		"door": "3a3024", "trim": "c8a040", "cloth": "7a6a3a", "cloth2": "d8d0b0", "ground": "8a8a60", "fence": "stone", "snow": false},
	"tidal": {"wall": "7a8a8a", "wall2": "6a7a7a", "timber": "3a4448", "roof": "4a5a60", "roof2": "3a4a50", "stone": "5a6464",
		"door": "2a3436", "trim": "5ab0a0", "cloth": "3a6a6a", "cloth2": "b8c8c0", "ground": "6a6a58", "fence": "none", "snow": false},
	"thornwood": {"wall": "8a6a48", "wall2": "7a5a3c", "timber": "3e2a1c", "roof": "4a6a3a", "roof2": "3a5a30", "stone": "6a6458",
		"door": "2e2016", "trim": "6a8a3a", "cloth": "3e6a4a", "cloth2": "c8b890", "ground": "5e4a30", "fence": "palisade", "snow": false},
	"mire": {"wall": "6a6048", "wall2": "5a5040", "timber": "3a3226", "roof": "6a6a42", "roof2": "5a5a38", "stone": "5a5a50",
		"door": "2a241a", "trim": "7a6ab0", "cloth": "5a4a7a", "cloth2": "a89a70", "ground": "4b4a33", "fence": "none", "snow": false},
	"peaks": {"wall": "a8a29a", "wall2": "8f8a84", "timber": "4a3a2c", "roof": "5a6070", "roof2": "4a5060", "stone": "8a8a92",
		"door": "3a2e22", "trim": "2a7fd0", "cloth": "2f4f7a", "cloth2": "e8f0f6", "ground": "8a8a90", "fence": "stone", "snow": true},
}
## Everything build() knows how to make (handy for galleries and editors).
const BUILDINGS := ["cottage", "house", "longhouse", "tavern", "shop", "smithy", "chapel", "watchtower", "windmill", "barn", "stilt_hut", "lodge", "keep",
	"hall_house", "apothecary", "farmhouse", "granary", "fisher_cottage", "townhouse", "log_cabin", "turf_hut", "reed_hut", "wreck_shack", "chalet"]
const DEFENSES := ["palisade", "stone_wall", "fence", "gatehouse", "wall_tower", "castle_wall", "castle_tower", "castle_gate"]
const PROPS := ["well", "stall", "lamp", "barrel", "crate", "crates", "cart", "haybale", "signpost", "bench", "banner", "notice_board",
	"tent", "yurt", "bedroll", "log_seat", "campfire", "spit", "weapon_rack", "dummy", "firewood", "scarecrow", "trough", "flowerbox", "pier", "bridge"]

## Pieces you can drop into a building from the build editor (kind -> draw function taking the builder and a position).
static var PALETTE: Dictionary = {
	"barrel": func(b: B, p: Vector3) -> void: _barrel_geo(b, p),
	"crate": func(b: B, p: Vector3) -> void: _crate_geo(b, p, 0.8, 0.0),
	"chest": func(b: B, p: Vector3) -> void: _chest_geo(b, p),
	"table": func(b: B, p: Vector3) -> void: _table_geo(b, p, 1.4, 0.9),
	"table_long": func(b: B, p: Vector3) -> void: _table_geo(b, p, 2.6, 1.0),
	"stool": func(b: B, p: Vector3) -> void: _stool_geo(b, p),
	"bed": func(b: B, p: Vector3) -> void: _bed_geo(b, p),
	"shelf": func(b: B, p: Vector3) -> void: _shelf_geo(b, p, 2.0),
	"shelf_short": func(b: B, p: Vector3) -> void: _shelf_geo(b, p, 1.2),
	"shelf_long": func(b: B, p: Vector3) -> void: _shelf_geo(b, p, 3.4),
	"counter": func(b: B, p: Vector3) -> void: _counter_geo(b, p, 3.0),
	"counter_long": func(b: B, p: Vector3) -> void: _counter_geo(b, p, 5.0),
	"pew": func(b: B, p: Vector3) -> void: _pew_geo(b, p, 1.5),
	"carpet": func(b: B, p: Vector3) -> void: _carpet_geo(b, p, 2.0, 1.5, b.c("cloth")),
	"hearth": func(b: B, p: Vector3) -> void: _hearth_geo(b, p),
	"haybale": func(b: B, p: Vector3) -> void: _haybale_at_geo(b, p, 0.0, 1.0),
	"bench": func(b: B, p: Vector3) -> void: _bench_at_geo(b, p, 0.0),
	"firewood": func(b: B, p: Vector3) -> void: _firewood_at_geo(b, p, 0.0),
	"flowerbox": func(b: B, p: Vector3) -> void: _flowerbox_geo(b, p, 0.0),
	"weapon_rack": func(b: B, p: Vector3) -> void: _weapon_rack_at_geo(b, p),
}


static var _solid_mat: ShaderMaterial
static var _glow_mat: ShaderMaterial
static var _cache := {}

## Surfaces get a chunky pixel texture like the shrine's stone. Which pattern is chosen by the
## vertex colour's alpha: 1.0 grain (plaster, cloth), 0.75 planks (timber), 0.5 stone blocks, 0.25 shingles/thatch.
const SHADER := """
shader_type spatial;
render_mode cull_disabled, diffuse_lambert;
uniform float glow = 0.0;
uniform bool see_through = true;
uniform sampler2D pattern : filter_nearest, repeat_enable;
global uniform vec3 player_pos;
varying vec3 wpos;
varying vec3 wnrm;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	if (see_through) {
		// dither away whatever stands between the camera and the player
		vec3 pv = (VIEW_MATRIX * vec4(player_pos + vec3(0.0, 1.0, 0.0), 1.0)).xyz;
		if (-VERTEX.z < -pv.z - 1.5) {
			float d = length(VERTEX.xy / -VERTEX.z - pv.xy / -pv.z);
			if (d < 0.11 && mod(FRAGCOORD.x + FRAGCOORD.y, 2.0) < 1.0) {
				discard;
			}
		}
	}
	// blocky world-space projection, 8 texels per metre like the shrine stone
	vec3 an = abs(wnrm);
	vec2 uv = an.y > 0.6 ? wpos.xz : (an.x > an.z ? wpos.zy : wpos.xy);
	uv *= 0.5;
	float idx = clamp(floor((1.0 - COLOR.a) * 4.0 + 0.5), 0.0, 3.0);
	vec2 cell = fract(uv);
	vec3 t = texture(pattern, vec2((idx + cell.x) / 4.0, 1.0 - cell.y)).rgb * 1.25;
	vec3 base = COLOR.rgb * (glow > 0.0 ? vec3(1.0) : t);
	ALBEDO = base;
	EMISSION = COLOR.rgb * glow;
	ROUGHNESS = 1.0;
	SPECULAR = 0.15;
}
"""


# ================================================================ builder
## Collects triangles (with a local transform you can push), collision boxes and lights.
class B:
	var st := SurfaceTool.new()
	var gl := SurfaceTool.new()
	var xf := Transform3D.IDENTITY
	var shapes: Array = []     # [Transform3D, Vector3 size]
	var lights: Array = []     # [Vector3, Color, float range]
	var children: Array[Node3D] = []
	var rng := RandomNumberGenerator.new()
	var hd := 0.0              # half the depth, and zc the centre line of the hall (for wall-anchored pieces)
	var zc := 0.0
	var hw := 0.0              # half the width of the building's hall (houses are a little wider or narrower each time)
	var has_glow := false
	var s: Dictionary          # style palette
	var rt := SurfaceTool.new()   # roof and ceiling: a separate mesh that hides when you walk in
	var in_roof := false
	var in_upper := false      # the second floor: its own mesh, hidden while you are downstairs inside
	var up := SurfaceTool.new()
	var ugl := SurfaceTool.new()
	var has_upper := false
	var has_uglow := false
	var floor_y := 0.0         # height of the second floor, if any
	var max_y := 4.5
	var has_roof := false
	var doors: Array = []      # [Transform3D, w, h, mode, mirror]
	var interior := Rect2()    # walkable floor, if this is a walk-in building
	# --- furniture as separate, movable pieces (see prop() and PropLayouts)
	var layout := {}           # hand-made edits applied while building
	var edit_props := false    # true: every piece becomes its own node (the build editor); false: baked into one mesh
	var props: Array = []      # edit mode: one record per piece
	var cur: Dictionary = {}   # the piece being recorded right now
	var _prop_count := {}
	var _depth := 0

	func _init(style: Dictionary, seed_v: int) -> void:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		gl.begin(Mesh.PRIMITIVE_TRIANGLES)
		rt.begin(Mesh.PRIMITIVE_TRIANGLES)
		up.begin(Mesh.PRIMITIVE_TRIANGLES)
		ugl.begin(Mesh.PRIMITIVE_TRIANGLES)
		s = style
		rng.seed = seed_v

	func c(key: String) -> Color:
		var col := Color(s.get(key, key))
		# pick a surface pattern from what the colour is for (see SHADER)
		if key in ["timber", "door", "fence"]:
			col.a = 0.75
		elif key in ["stone"]:
			col.a = 0.5
		elif key in ["roof", "roof2"]:
			col.a = 0.25
		return col

	func tri(a: Vector3, b: Vector3, d: Vector3, col: Color, glow := false) -> void:
		if not cur.is_empty():
			var pt: SurfaceTool = cur["gl"] if glow else cur["st"]
			cur["has_glow" if glow else "has_solid"] = true
			for p: Vector3 in [xf * a, xf * b, xf * d]:
				pt.set_color(col)
				pt.add_vertex(p)
				cur["mn"] = (cur["mn"] as Vector3).min(p)
				cur["mx"] = (cur["mx"] as Vector3).max(p)
			return
		var t := gl if glow else (rt if in_roof else st)
		if in_upper and not in_roof:
			t = ugl if glow else up
			if glow:
				has_uglow = true
			else:
				has_upper = true
		elif glow:
			has_glow = true
		elif in_roof:
			has_roof = true
		for p: Vector3 in [xf * a, xf * b, xf * d]:
			t.set_color(col)
			t.add_vertex(p)

	func quad(a: Vector3, b: Vector3, d: Vector3, e: Vector3, col: Color, glow := false) -> void:
		tri(a, b, d, col, glow)
		tri(a, d, e, col, glow)

	## An axis-aligned box (optionally turned by yaw, tipped by pitch/roll around its centre).
	func box(center: Vector3, size: Vector3, col: Color, yaw := 0.0, glow := false, pitch := 0.0, roll := 0.0) -> void:
		var bs := Basis.from_euler(Vector3(pitch, yaw, roll))
		var h := size * 0.5
		var p := []
		for z in [-1, 1]:
			for y in [-1, 1]:
				for x in [-1, 1]:
					p.append(center + bs * Vector3(h.x * x, h.y * y, h.z * z))
		# indices: x + 2y + 4z
		var top := col.lightened(0.06)
		var side := col.darkened(0.06)
		quad(p[2], p[3], p[7], p[6], top, glow)        # +y
		quad(p[0], p[4], p[5], p[1], col.darkened(0.25), glow)  # -y
		quad(p[4], p[6], p[7], p[5], col, glow)        # +z
		quad(p[0], p[1], p[3], p[2], side, glow)       # -z
		quad(p[1], p[5], p[7], p[3], side, glow)       # +x
		quad(p[0], p[2], p[6], p[4], col, glow)        # -x

	## A beam between two points (square cross-section).
	func beam(a: Vector3, b: Vector3, w: float, col: Color) -> void:
		var mid := (a + b) * 0.5
		var d := b - a
		var length := d.length()
		var bs := Basis.looking_at(d.normalized(), Vector3.UP if absf(d.normalized().y) < 0.95 else Vector3.RIGHT)
		var h := Vector3(w, w, length) * 0.5
		var p := []
		for z in [-1, 1]:
			for y in [-1, 1]:
				for x in [-1, 1]:
					p.append(mid + bs * Vector3(h.x * x, h.y * y, h.z * z))
		quad(p[2], p[3], p[7], p[6], col.lightened(0.05))
		quad(p[0], p[4], p[5], p[1], col.darkened(0.2))
		quad(p[1], p[5], p[7], p[3], col.darkened(0.06))
		quad(p[0], p[2], p[6], p[4], col)
		quad(p[4], p[6], p[7], p[5], col)
		quad(p[0], p[1], p[3], p[2], col)

	## Gable roof: ridge runs along X. base = centre at eave height.
	func gable(base: Vector3, w: float, d: float, h: float, col: Color, gable_col: Color, thick := 0.12) -> void:
		var x := w * 0.5
		var z := d * 0.5
		var r0 := base + Vector3(-x, h, 0)
		var r1 := base + Vector3(x, h, 0)
		var f0 := base + Vector3(-x, 0, z)
		var f1 := base + Vector3(x, 0, z)
		var b0 := base + Vector3(-x, 0, -z)
		var b1 := base + Vector3(x, 0, -z)
		quad(f0, f1, r1, r0, col)
		quad(b1, b0, r0, r1, col.darkened(0.1))
		# thickness lip along the eaves
		var dn := Vector3(0, -thick, 0)
		quad(f0 + dn, f1 + dn, f1, f0, col.darkened(0.3))
		quad(b1 + dn, b0 + dn, b0, b1, col.darkened(0.3))
		# gable ends (inset a little so the roof overhangs)
		var ins := 0.3
		tri(base + Vector3(-x + ins, 0, z - ins), base + Vector3(-x + ins, h - 0.1, 0), base + Vector3(-x + ins, 0, -z + ins), gable_col)
		tri(base + Vector3(x - ins, 0, -z + ins), base + Vector3(x - ins, h - 0.1, 0), base + Vector3(x - ins, 0, z - ins), gable_col)

	## Four-sided pyramid roof.
	func pyramid(base: Vector3, w: float, d: float, h: float, col: Color) -> void:
		var tip := base + Vector3(0, h, 0)
		var x := w * 0.5
		var z := d * 0.5
		var pts := [base + Vector3(-x, 0, z), base + Vector3(x, 0, z), base + Vector3(x, 0, -z), base + Vector3(-x, 0, -z)]
		for i in 4:
			tri(pts[i], pts[(i + 1) % 4], tip, col.darkened(0.07 * (i % 2)))

	func cyl(base: Vector3, rb: float, rt: float, h: float, col: Color, segs := 7, glow := false, cap := true) -> void:
		for i in segs:
			var a0 := TAU * i / segs
			var a1 := TAU * (i + 1) / segs
			var b0 := base + Vector3(cos(a0) * rb, 0, sin(a0) * rb)
			var b1 := base + Vector3(cos(a1) * rb, 0, sin(a1) * rb)
			var t0 := base + Vector3(cos(a0) * rt, h, sin(a0) * rt)
			var t1 := base + Vector3(cos(a1) * rt, h, sin(a1) * rt)
			var sh := col.darkened(0.08 * (i % 2))
			quad(b0, b1, t1, t0, sh, glow)
			if cap and rt > 0.0:
				tri(base + Vector3(0, h, 0), t0, t1, col.lightened(0.05), glow)

	## Horizontal cylinder (log, barrel lying down) along X.
	func log_x(center: Vector3, r: float, length: float, col: Color, segs := 6) -> void:
		var save := xf
		xf = xf * Transform3D(Basis(Vector3.FORWARD, PI * 0.5), center - Vector3(length * 0.5, 0, 0))
		cyl(Vector3.ZERO, r, r, length, col, segs)
		xf = save

	func cone(base: Vector3, r: float, h: float, col: Color, segs := 7, glow := false) -> void:
		cyl(base, r, 0.0, h, col, segs, glow, false)

	func window(center: Vector3, w: float, h: float, facing: Vector3) -> void:
		## a lit window with a dark frame, on a wall facing +Z/-Z/+X/-X
		var yaw := atan2(facing.x, facing.z)
		var out := facing.normalized()
		box(center + out * 0.04, Vector3(w + 0.16, h + 0.16, 0.06), c("timber"), yaw)
		box(center + out * 0.07, Vector3(w, h, 0.04), Color("f2c26a"), yaw, true)
		box(center + out * 0.1, Vector3(0.05, h, 0.03), c("timber"), yaw)

	func door(center_bottom: Vector3, w: float, h: float, facing: Vector3) -> void:
		var yaw := atan2(facing.x, facing.z)
		var out := facing.normalized()
		box(center_bottom + Vector3(0, h * 0.5, 0) + out * 0.04, Vector3(w + 0.2, h + 0.1, 0.08), c("timber"), yaw)
		box(center_bottom + Vector3(0, h * 0.5, 0) + out * 0.07, Vector3(w, h, 0.06), c("door"), yaw)
		box(center_bottom + Vector3(w * 0.3, h * 0.5, 0) + out * 0.12, Vector3(0.06, 0.06, 0.06), Color("d8b04a"), yaw)
		box(center_bottom + Vector3(0, 0.06, 0) + out * 0.35, Vector3(w + 0.4, 0.12, 0.6), c("stone"), yaw)

	## A doorframe with a step. mode: "auto" (swings open as you walk up), "open" (propped open) or "none".
	func doorway(bottom: Vector3, w: float, h: float, mode: String, mirror := false) -> void:
		var tcol := c("timber")
		for sx in [-1, 1]:
			box(bottom + Vector3(sx * (w * 0.5 + 0.07), h * 0.5, 0.0), Vector3(0.16, h, 0.34), tcol)
		box(bottom + Vector3(0, h + 0.08, 0.0), Vector3(w + 0.3, 0.18, 0.36), tcol)
		box(bottom + Vector3(0, 0.03, 0.35), Vector3(w + 0.4, 0.06, 0.8), c("stone"))
		if mode != "none":
			doors.append([xf * Transform3D(Basis.IDENTITY, bottom + Vector3(0, 0, -0.15)), w, h, mode, mirror])

	func solid(center: Vector3, size: Vector3, yaw := 0.0) -> void:
		(cur["shapes"] if not cur.is_empty() else shapes).append([xf * Transform3D(Basis(Vector3.UP, yaw), center), size, true])

	## A collision box that the camera ignores (floors, stair ramps), optionally tipped.
	func floor_solid(center: Vector3, size: Vector3, pitch := 0.0) -> void:
		(cur["shapes"] if not cur.is_empty() else shapes).append([xf * Transform3D(Basis.from_euler(Vector3(pitch, 0, 0)), center), size, false])

	func light(pos: Vector3, col: Color, rng_m: float) -> void:
		(cur["lights"] if not cur.is_empty() else lights).append([xf * pos, col, rng_m])

	## One piece of furniture. `draw` is a Callable taking the position to draw at. The piece gets a stable name
	## (kind + counter, e.g. "barrel_3"), and any hand-made edit for that name is applied (see PropLayouts).
	func prop(kind: String, at: Vector3, yaw: float, draw: Callable) -> void:
		if _depth > 0:
			draw.call(at)
			return
		var n: int = int(_prop_count.get(kind, 0)) + 1
		_prop_count[kind] = n
		var id := "%s_%d" % [kind, n]
		var ov: Dictionary = (layout.get("props", {}) as Dictionary).get(id, {})
		var gone: bool = id in (layout.get("deleted", []) as Array)
		var d: Array = ov.get("d", [0.0, 0.0, 0.0])
		var dy := deg_to_rad(float(ov.get("r", 0.0)))
		var home := xf * Transform3D(Basis(Vector3.UP, yaw), at)
		var fin := xf * Transform3D(Basis(Vector3.UP, yaw + dy), at + Vector3(float(d[0]), float(d[1]), float(d[2])))
		draw_prop(id, kind, home, fin, gone, false, draw, xf, at, yaw)

	## Like prop(), for blocks of code that draw with absolute coordinates: the piece pivots around `at`.
	func piece(kind: String, at: Vector3, yaw: float, draw: Callable) -> void:
		prop(kind, at, yaw, func(_p: Vector3) -> void:
			var save := xf
			xf = xf * Transform3D(Basis.IDENTITY, -at)
			draw.call()
			xf = save)

	func draw_prop(id: String, kind: String, home: Transform3D, fin: Transform3D, gone: bool, added: bool, draw: Callable, base: Transform3D, at0: Vector3, yaw0: float) -> void:
		var save := xf
		_depth += 1
		if edit_props:
			var rec := {"id": id, "kind": kind, "home": home, "xf": fin, "base": base, "at0": at0, "yaw0": yaw0, "upper": in_upper, "deleted": gone, "added": added,
				"st": SurfaceTool.new(), "gl": SurfaceTool.new(), "has_solid": false, "has_glow": false, "shapes": [], "lights": [],
				"mn": Vector3(1e9, 1e9, 1e9), "mx": Vector3(-1e9, -1e9, -1e9)}
			(rec["st"] as SurfaceTool).begin(Mesh.PRIMITIVE_TRIANGLES)
			(rec["gl"] as SurfaceTool).begin(Mesh.PRIMITIVE_TRIANGLES)
			cur = rec
			xf = Transform3D.IDENTITY
			draw.call(Vector3.ZERO)
			cur = {}
			props.append(rec)
		elif not gone:
			xf = fin
			draw.call(Vector3.ZERO)
		xf = save
		_depth -= 1

	## Pieces added by hand in the build editor.
	func add_layout_props() -> void:
		for spec: Dictionary in (layout.get("added", []) as Array):
			var kind := String(spec.get("kind", ""))
			if not TownKit.PALETTE.has(kind):
				continue
			var pa: Array = spec.get("pos", [0, 0, 0])
			var pos := Vector3(float(pa[0]), float(pa[1]), float(pa[2]))
			# pieces saved against a side wall are anchored to that wall, so they stay flush in wider or narrower houses
			pos.x += float(spec.get("ax", 0.0)) * hw
			pos.z += float(spec.get("az", 0.0)) * hd + (zc if spec.has("az") else 0.0)
			var yaw := deg_to_rad(float(spec.get("yaw", 0.0)))
			var save_xf := xf
			var save_up := in_upper
			if bool(spec.get("upper", false)) and floor_y > 0.0:
				in_upper = true
				xf = Transform3D(Basis.IDENTITY, Vector3(0, floor_y, 0))
			var fn: Callable = TownKit.PALETTE[kind]
			var home := xf * Transform3D(Basis(Vector3.UP, yaw), pos)
			draw_prop(String(spec.get("id", "add_0")), kind, home, home, false, true, func(p: Vector3) -> void: fn.call(self, p), xf, pos, yaw)
			xf = save_xf
			in_upper = save_up

	## The node for one recorded piece (edit mode).
	func prop_node(rec: Dictionary) -> Node3D:
		var n := Node3D.new()
		n.name = String(rec["id"])
		n.transform = rec["xf"]
		for k: String in ["kind", "base", "at0", "yaw0", "upper", "added", "home"]:
			n.set_meta(k, rec[k])
		n.set_meta("prop_id", rec["id"])
		var mesh := ArrayMesh.new()
		if rec["has_solid"]:
			var s0: SurfaceTool = rec["st"]
			s0.generate_normals()
			s0.commit(mesh)
			mesh.surface_set_material(mesh.get_surface_count() - 1, TownKit.solid_material())
		if rec["has_glow"]:
			var g0: SurfaceTool = rec["gl"]
			g0.generate_normals()
			g0.commit(mesh)
			mesh.surface_set_material(mesh.get_surface_count() - 1, TownKit.glow_material())
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		n.add_child(mi)
		var shp: Array = rec["shapes"]
		if not shp.is_empty():
			var body := StaticBody3D.new()
			body.collision_layer = 18
			var fbody := StaticBody3D.new()
			fbody.collision_layer = 2
			for sh: Array in shp:
				var cs := CollisionShape3D.new()
				var bx := BoxShape3D.new()
				bx.size = sh[1]
				cs.shape = bx
				cs.transform = sh[0]
				if sh.size() > 2 and not sh[2]:
					fbody.add_child(cs)
				else:
					body.add_child(cs)
			if body.get_child_count() > 0:
				body.set_meta("layer", 18)
				n.add_child(body)
			else:
				body.free()
			if fbody.get_child_count() > 0:
				fbody.set_meta("layer", 2)
				n.add_child(fbody)
			else:
				fbody.free()
		for l: Array in rec["lights"]:
			var ol := OmniLight3D.new()
			ol.position = l[0]
			ol.light_color = l[1]
			ol.omni_range = l[2]
			ol.light_energy = 1.1
			ol.set_meta("base", 1.1)
			ol.add_to_group("lamp")
			ol.visible = false
			n.add_child(ol)
		# a box that only the editor's mouse picking sees
		var mn: Vector3 = rec["mn"]
		var mx: Vector3 = rec["mx"]
		if mn.x < mx.x:
			var aabb := AABB(mn, mx - mn).grow(0.03)
			n.set_meta("aabb", aabb)
			var pick := StaticBody3D.new()
			pick.collision_layer = TownKit.PICK_LAYER
			pick.collision_mask = 0
			pick.set_meta("layer", TownKit.PICK_LAYER)
			var pc := CollisionShape3D.new()
			var pb := BoxShape3D.new()
			pb.size = aabb.size
			pc.shape = pb
			pc.position = aabb.get_center()
			pick.add_child(pc)
			n.add_child(pick)
		if rec["deleted"]:
			TownKit.set_prop_deleted(n, true)
		return n

	func build(name: String) -> Node3D:
		add_layout_props()
		var root: Node3D
		if interior.size != Vector2.ZERO:
			var bd := Building.new()
			bd.rect = interior
			root = bd
		else:
			root = Node3D.new()
		root.name = name
		var mesh := ArrayMesh.new()
		st.generate_normals()
		st.commit(mesh)
		mesh.surface_set_material(0, TownKit.solid_material())
		if has_glow:
			gl.generate_normals()
			gl.commit(mesh)
			mesh.surface_set_material(1, TownKit.glow_material())
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		root.add_child(mi)
		if has_roof:
			rt.generate_normals()
			var rm := ArrayMesh.new()
			rt.commit(rm)
			rm.surface_set_material(0, TownKit.solid_material())
			var rmi := MeshInstance3D.new()
			rmi.mesh = rm
			rmi.name = "Roof"
			root.add_child(rmi)
			if root is Building:
				(root as Building).roof = rmi
		if has_upper and root is Building:
			var um := ArrayMesh.new()
			up.generate_normals()
			up.commit(um)
			um.surface_set_material(0, TownKit.solid_material())
			if has_uglow:
				ugl.generate_normals()
				ugl.commit(um)
				um.surface_set_material(1, TownKit.glow_material())
			var umi := MeshInstance3D.new()
			umi.mesh = um
			umi.name = "Upper"
			root.add_child(umi)
			(root as Building).upper = umi
			(root as Building).floor_y = floor_y
			(root as Building).max_y = max_y
		for dspec: Array in doors:
			root.add_child(TownKit.make_door(dspec, s, rng.randi()))
		if not shapes.is_empty():
			var body := StaticBody3D.new()
			body.collision_layer = 18   # solid + blocks the camera
			var fbody := StaticBody3D.new()
			fbody.collision_layer = 2   # floors and stair ramps: solid, but the camera sees through
			for sh: Array in shapes:
				var cs := CollisionShape3D.new()
				var bx := BoxShape3D.new()
				bx.size = sh[1]
				cs.shape = bx
				cs.transform = sh[0]
				if sh.size() > 2 and not sh[2]:
					fbody.add_child(cs)
				else:
					body.add_child(cs)
			root.add_child(body)
			if fbody.get_child_count() > 0:
				root.add_child(fbody)
			else:
				fbody.free()
		for l: Array in lights:
			var ol := OmniLight3D.new()
			ol.position = l[0]
			ol.light_color = l[1]
			ol.omni_range = l[2]
			ol.light_energy = 1.1
			ol.set_meta("base", 1.1)
			ol.add_to_group("lamp")
			ol.visible = false
			root.add_child(ol)
		for ch in children:
			root.add_child(ch)
		for rec: Dictionary in props:
			var pn := prop_node(rec)
			var holder: Node = root
			if bool(rec["upper"]) and root is Building and (root as Building).upper != null:
				holder = (root as Building).upper
			holder.add_child(pn)
			if root is Building:
				for ch in pn.get_children():
					if ch is StaticBody3D and int(ch.get_meta("layer", 0)) == 18:
						(root as Building).cam_extra.append(ch as StaticBody3D)
		return root


static func solid_material() -> ShaderMaterial:
	if _solid_mat == null:
		var sh := Shader.new()
		sh.code = SHADER
		_solid_mat = ShaderMaterial.new()
		_solid_mat.shader = sh
		_solid_mat.set_shader_parameter("pattern", pattern_texture())
		_glow_mat = ShaderMaterial.new()
		_glow_mat.shader = sh
		_glow_mat.set_shader_parameter("glow", 1.4)
		_glow_mat.set_shader_parameter("see_through", false)
	return _solid_mat


static var _pattern: ImageTexture


## Four 16x16 greyscale patterns side by side: grain, planks, stone blocks, shingles.
## Values are brightness multipliers (x1.25 in the shader), so 0.8 = unchanged.
static func pattern_texture() -> ImageTexture:
	if _pattern:
		return _pattern
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	var img := Image.create(64, 16, false, Image.FORMAT_RGB8)
	var g := func(v: float) -> Color:
		return Color(v, v, v)
	for y in 16:
		for x in 16:
			# 0: grain (like the shrine stone)
			var v0: float = 0.8 + ([-0.07, 0.0, 0.04, 0.08][rng.randi() % 4] if rng.randf() < 0.5 else 0.0)
			img.set_pixel(x, y, g.call(v0))
			# 1: planks, 4 px tall boards with a dark seam
			var board := y / 4
			var v1 := 0.78 + (board % 2) * 0.05 + rng.randf_range(-0.03, 0.03)
			if y % 4 == 3:
				v1 = 0.6
			if (x + board * 5) % 16 == 0:
				v1 = 0.64
			img.set_pixel(16 + x, y, g.call(v1))
			# 2: stone blocks, 8x4 staggered with mortar
			var row := y / 4
			var bx := (x + (row % 2) * 4) % 8
			var v2 := 0.8 + rng.randf_range(-0.05, 0.05) + ((row * 3 + (x + (row % 2) * 4) / 8) % 3) * 0.03
			if y % 4 == 3 or bx == 0:
				v2 = 0.6
			img.set_pixel(32 + x, y, g.call(v2))
			# 3: shingles / thatch, staggered rows with a dark lower lip
			var srow := y / 4
			var sx := (x + (srow % 2) * 2) % 4
			var v3 := 0.82 - (y % 4) * 0.035 + rng.randf_range(-0.03, 0.03)
			if y % 4 == 3:
				v3 = 0.62
			if sx == 0:
				v3 -= 0.06
			img.set_pixel(48 + x, y, g.call(v3))
	_pattern = ImageTexture.create_from_image(img)
	return _pattern


static func glow_material() -> ShaderMaterial:
	solid_material()
	return _glow_mat


static func style(name: String) -> Dictionary:
	return STYLES.get(name, STYLES["meadow"])


# ================================================================ public
## Build any asset by name in a region style. length is used by walls, fences, piers and bridges.
static var layout_override: Variant = null   # build editor: build with this layout instead of the saved one


static func build(kind: String, style_name := "meadow", seed_v := 0, length := 6.0, edit := false, inst := "") -> Node3D:
	var b := B.new(style(style_name), seed_v * 7919 + kind.hash())
	b.layout = layout_override if layout_override is Dictionary else PropLayouts.get_layout(kind, inst)
	b.edit_props = edit
	match kind:
		"cottage": _cottage(b)
		"house": _house(b)
		"longhouse": _longhouse(b)
		"tavern": _tavern(b)
		"shop": _shop(b)
		"smithy": _smithy(b)
		"chapel": _chapel(b)
		"watchtower": _watchtower(b)
		"windmill": _windmill(b)
		"barn": _barn(b)
		"stilt_hut": _stilt_hut(b)
		"lodge": _lodge(b)
		"hall_house": _hall_house(b)
		"apothecary": _apothecary(b)
		"farm": _farm(b)
		"farmhouse": _farmhouse(b)
		"granary": _granary(b)
		"fisher_cottage": _fisher_cottage(b)
		"townhouse": _townhouse(b)
		"log_cabin": _log_cabin(b)
		"turf_hut": _turf_hut(b)
		"reed_hut": _reed_hut(b)
		"wreck_shack": _wreck_shack(b)
		"chalet": _chalet(b)
		"palisade": _palisade(b, length)
		"stone_wall": _stone_wall(b, length)
		"fence": _fence(b, length)
		"gatehouse": _gatehouse(b)
		"wall_tower": _wall_tower(b)
		"keep": _keep(b)
		"castle_wall": _castle_wall(b, length)
		"castle_tower": _castle_tower(b)
		"castle_gate": _castle_gate(b)
		"well": _well(b)
		"stall": _stall(b)
		"lamp": _lamp(b)
		"barrel": _barrel(b, Vector3.ZERO)
		"crate": _crate(b, Vector3.ZERO, 0.8, 0.0)
		"crates": _crates(b)
		"cart": _cart(b)
		"haybale": _haybale(b)
		"signpost": _signpost(b)
		"bench": _bench(b)
		"banner": _banner(b)
		"notice_board": _notice_board(b)
		"tent": _tent(b)
		"yurt": _yurt(b)
		"bedroll": _bedroll(b)
		"log_seat": _log_seat(b)
		"campfire": _campfire(b)
		"spit": _spit(b)
		"weapon_rack": _weapon_rack(b)
		"dummy": _dummy(b)
		"firewood": _firewood(b)
		"scarecrow": _scarecrow(b)
		"trough": _trough(b)
		"flowerbox": _flowerbox(b, Vector3(0, 0.25, 0), 0.0)
		"pier": _pier(b, length)
		"bridge": _bridge(b, length)
		_:
			b.box(Vector3(0, 0.5, 0), Vector3.ONE, Color.MAGENTA)
	var root := b.build(kind)
	root.set_meta("tk", {"kind": kind, "style": style_name, "seed": seed_v, "length": length, "hw": b.hw, "hd": b.hd, "zc": b.zc})
	return root


## Collision layer that only the build editor's mouse picking looks at.
const PICK_LAYER := 1 << 20


## Hides / shows one edited piece and switches its collision off / on.
static func set_prop_deleted(n: Node3D, gone: bool) -> void:
	n.visible = not gone
	n.set_meta("deleted", gone)
	for ch in n.get_children():
		if ch is StaticBody3D:
			(ch as StaticBody3D).collision_layer = 0 if gone else int(ch.get_meta("layer", 0))


# ---- outdoor objects (lamps, carts ...) that the build editor can move around; see PropLayouts "site_<name>"
const OUTDOOR := ["stall", "lamp", "barrel", "crate", "crates", "cart", "haybale", "signpost", "bench", "banner", "tent", "yurt", "bedroll",
	"log_seat", "weapon_rack", "firewood", "scarecrow", "trough", "flowerbox", "campfire", "spit", "dummy"]


## Marks a freshly placed village/camp object so the editor can find, move and save it.
const SITE_EXTRA := ["fence", "palisade", "stone_wall", "castle_wall", "castle_tower", "castle_gate", "gatehouse", "well", "notice_board", "campfire", "spit", "dummy"]


## Tags everything else a village or camp holds that is not a walk-in building (walls, gates, wells, fire pits ...).
static func _tag_rest(root: Node3D, counters: Dictionary) -> void:
	for ch in root.get_children():
		if ch.has_meta("pid") or not ch.has_meta("tk") or ch is Building:
			continue
		var kind := String((ch.get_meta("tk") as Dictionary)["kind"])
		if kind in SITE_EXTRA:
			_tag_site_prop(ch as Node3D, kind, counters, true)


static func _tag_site_prop(n: Node3D, kind: String, counters: Dictionary, force := false) -> void:
	if not force and not (kind in OUTDOOR):
		return
	counters[kind] = int(counters.get(kind, 0)) + 1
	var id := "%s_%d" % [kind, counters[kind]]
	n.name = id
	n.set_meta("pid", id)
	n.set_meta("pos0", n.position)
	n.set_meta("yaw0", n.rotation.y)
	n.set_meta("scale0", n.scale)


static func _mark_site(root: Node3D, style_name: String, bscale: float) -> void:
	root.set_meta("site", {"style": style_name, "bscale": bscale})
	root.add_to_group("tk_sites")


## Shows or hides an outdoor object (hidden ones also stop colliding).
static func site_set_gone(n: Node3D, gone: bool) -> void:
	n.visible = not gone
	n.set_meta("deleted", gone)
	for c in n.find_children("*", "CollisionObject3D", true, false):
		var co := c as CollisionObject3D
		if co.has_meta("edit_pick"):
			continue
		if not co.has_meta("layer0"):
			co.set_meta("layer0", co.collision_layer)
			co.set_meta("mask0", co.collision_mask)
		co.collision_layer = 0 if gone else int(co.get_meta("layer0"))
		co.collision_mask = 0 if gone else int(co.get_meta("mask0"))


## Builds an extra outdoor object (one the editor added) inside a village or camp.
static func site_make_prop(site: Node3D, kind: String, at: Vector3, yaw: float, id: String) -> Node3D:
	var info: Dictionary = site.get_meta("site", {})
	var n := build(kind, String(info.get("style", "meadow")), 1)
	var sc := Vector3.ONE * _bsc(kind, float(info.get("bscale", 1.0)))
	n.name = id
	n.set_meta("pid", id)
	n.set_meta("site_added", true)
	n.set_meta("pos0", at)
	n.set_meta("yaw0", yaw)
	n.set_meta("scale0", sc)
	n.transform = Transform3D(Basis(Vector3.UP, yaw).scaled(sc), at)
	site.add_child(n)
	return n


## Applies a saved layout ({props, deleted, added}) to a village or camp: moves, hides and adds objects.
## runtime = true (the game): deleted objects are taken out of the world completely. runtime = false (the editor):
## they stay as hidden ghosts so Restore works.
static func site_apply(site: Node3D, lay: Dictionary, runtime := true) -> void:
	var props: Dictionary = lay.get("props", {})
	var gone: Array = lay.get("deleted", [])
	var removed: Array = site.get_meta("removed", [])
	for rn in removed:
		if is_instance_valid(rn) and (rn as Node).get_parent() == null:
			site.add_child(rn)
	removed = []
	if not site.has_meta("removed_hook"):
		site.set_meta("removed_hook", true)
		site.tree_exiting.connect(func() -> void:
			for n: Variant in site.get_meta("removed", []):
				if is_instance_valid(n) and not (n as Node).is_inside_tree():
					(n as Node).free())
	for ch in site.get_children():
		if ch.has_meta("site_added"):
			site.remove_child(ch)
			ch.queue_free()
			continue
		if not ch.has_meta("pid"):
			continue
		var id := String(ch.get_meta("pid"))
		var pos: Vector3 = ch.get_meta("pos0")
		var yaw: float = ch.get_meta("yaw0")
		var ov: Dictionary = props.get(id, {})
		if not ov.is_empty():
			var da: Array = ov["d"]
			pos += Vector3(float(da[0]), float(da[1]), float(da[2]))
			yaw += deg_to_rad(float(ov.get("r", 0.0)))
		(ch as Node3D).transform = Transform3D(Basis(Vector3.UP, yaw).scaled(ch.get_meta("scale0")), pos)
		if runtime and id in gone:
			site.remove_child(ch)
			removed.append(ch)
		else:
			site_set_gone(ch as Node3D, id in gone)
	site.set_meta("removed", removed)
	for spec: Dictionary in (lay.get("added", []) as Array):
		var kind := String(spec.get("kind", ""))
		if not (kind in OUTDOOR):
			continue
		var pa: Array = spec.get("pos", [0, 0, 0])
		site_make_prop(site, kind, Vector3(float(pa[0]), float(pa[1]), float(pa[2])), deg_to_rad(float(spec.get("yaw", 0.0))), String(spec.get("id", "add_0")))


## Builds one hinged door (see door.gd). spec = [Transform3D, w, h, mode, mirror]
static func make_door(spec: Array, st: Dictionary, seed_v: int) -> Node3D:
	var w: float = spec[1]
	var h: float = spec[2]
	var mirror: bool = spec.size() > 4 and bool(spec[4])
	var d := Door.new()
	d.transform = spec[0]
	d.door_w = w
	d.door_h = h
	d.mode = spec[3]
	d.mirror = mirror
	var sg := -1.0 if mirror else 1.0
	var hinge := Node3D.new()
	hinge.position = Vector3(-w * 0.5 * sg, 0, 0)
	d.add_child(hinge)
	d.hinge = hinge
	var pb := B.new(st, seed_v)
	var dc := pb.c("door")
	pb.box(Vector3(0, h * 0.5, 0), Vector3(w - 0.04, h - 0.04, 0.09), dc)
	for k in [-1, 0, 1]:
		pb.box(Vector3(k * w * 0.25, h * 0.5, 0.0), Vector3(0.03, h - 0.1, 0.11), dc.darkened(0.3))
	for y in [0.3, h - 0.3]:
		pb.box(Vector3(0, y, 0.0), Vector3(w - 0.08, 0.09, 0.12), Color("2a2a30"))
	pb.box(Vector3(-w * 0.35 * sg, h * 0.48, 0.0), Vector3(0.09, 0.09, 0.2), Color("d8b04a"))
	var panel := pb.build("Panel")
	panel.position = Vector3(w * 0.5 * sg, 0, 0)
	hinge.add_child(panel)
	var body := StaticBody3D.new()
	body.collision_layer = 18
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(w, h, 0.14)
	cs.shape = bx
	cs.position = Vector3(w * 0.5 * sg, h * 0.5, 0)
	body.add_child(cs)
	hinge.add_child(body)
	d.shape = cs
	return d


## Picks how a building's door behaves from its random seed: mostly swinging, some propped open, a few with none.
static func _door_mode(b: B, auto_w := 0.6, open_w := 0.25) -> String:
	var r := b.rng.randf()
	if r < auto_w:
		return "auto"
	if r < auto_w + open_w:
		return "open"
	return "none"


## A walk-in room: back and side walls, a front wall with a doorway at x = dx, a floor, and a ceiling that
## is part of the roof (so it hides when you step inside), plus a warm light. oz shifts the room along z.
static func _hall(b: B, w: float, d: float, h: float, dx: float, dw: float, dh: float, mode: String, oz := 0.0, ceil_h := -1.0, wall_key := "wall", light_col := Color("ffb870")) -> void:
	b.hw = w * 0.5
	b.hd = d * 0.5
	b.zc = oz
	var t := 0.3
	var wc := b.c(wall_key)
	var zf := oz + d * 0.5
	var zb := oz - d * 0.5
	var ch := ceil_h if ceil_h > 0.0 else h
	b.box(Vector3(0, h * 0.5, zb + t * 0.5), Vector3(w, h, t), wc)
	b.solid(Vector3(0, h * 0.5, zb + t * 0.5), Vector3(w, h, t))
	for sx in [-1, 1]:
		b.box(Vector3(sx * (w * 0.5 - t * 0.5), h * 0.5, oz), Vector3(t, h, d), wc)
		b.solid(Vector3(sx * (w * 0.5 - t * 0.5), h * 0.5, oz), Vector3(t, h, d))
	var lw := w * 0.5 + dx - dw * 0.5
	var rw := w * 0.5 - dx - dw * 0.5
	var lx := -w * 0.5 + lw * 0.5
	var rx := w * 0.5 - rw * 0.5
	for pc: Array in [[lx, lw], [rx, rw]]:
		b.box(Vector3(pc[0], h * 0.5, zf - t * 0.5), Vector3(pc[1], h, t), wc)
		b.solid(Vector3(pc[0], h * 0.5, zf - t * 0.5), Vector3(pc[1], h, t))
		b.box(Vector3(pc[0], 0.2, zf + 0.02), Vector3(pc[1] + 0.1, 0.4, 0.2), b.c("stone"))
	b.box(Vector3(dx, dh + (h - dh) * 0.5, zf - t * 0.5), Vector3(dw, h - dh, t), wc)
	b.solid(Vector3(dx, dh + (h - dh) * 0.5, zf - t * 0.5), Vector3(dw, h - dh, t))
	# stone footing and timber frame
	b.box(Vector3(0, 0.2, zb - 0.02), Vector3(w + 0.16, 0.4, 0.2), b.c("stone"))
	for sx in [-1, 1]:
		b.box(Vector3(sx * (w * 0.5 + 0.0), 0.2, oz), Vector3(0.2, 0.4, d + 0.16), b.c("stone"))
	var tc := b.c("timber")
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			b.box(Vector3(sx * w * 0.5, h * 0.5, oz + sz * d * 0.5), Vector3(0.24, h, 0.24), tc)
	b.box(Vector3(0, h - 0.1, zf), Vector3(w + 0.1, 0.2, 0.18), tc)
	b.box(Vector3(0, h - 0.1, zb), Vector3(w + 0.1, 0.2, 0.18), tc)
	b.box(Vector3(w * 0.5, h - 0.1, oz), Vector3(0.18, 0.2, d + 0.1), tc)
	b.box(Vector3(-w * 0.5, h - 0.1, oz), Vector3(0.18, 0.2, d + 0.1), tc)
	# floor and ceiling
	b.box(Vector3(0, 0.03, oz), Vector3(w - 0.2, 0.06, d - 0.2), tc.lightened(0.12))
	b.in_roof = true
	b.box(Vector3(0, ch, oz), Vector3(w, 0.14, d), tc.darkened(0.2))
	b.in_roof = false
	b.light(Vector3(0, ch - 0.7, oz), light_col, maxf(w, d) * 0.85)
	b.doorway(Vector3(dx, 0.0, zf), dw, dh, mode)
	b.interior = Rect2(Vector2(-w * 0.5 + t, zb + t), Vector2(w - 2.0 * t, d - 2.0 * t))


# --- furniture: all of it is solid, and sits on the floor at y = 0
static func _table(b: B, at: Vector3, sx: float, sz: float) -> void:
	b.prop("table", at, 0.0, func(p: Vector3) -> void: _table_geo(b, p, sx, sz))


static func _table_geo(b: B, at: Vector3, sx: float, sz: float) -> void:
	var tc := b.c("timber")
	b.box(at + Vector3(0, 0.8, 0), Vector3(sx, 0.1, sz), tc.lightened(0.15))
	for x in [-1, 1]:
		for z in [-1, 1]:
			b.box(at + Vector3(x * (sx * 0.5 - 0.1), 0.38, z * (sz * 0.5 - 0.1)), Vector3(0.1, 0.76, 0.1), tc)
	b.solid(at + Vector3(0, 0.45, 0), Vector3(sx, 0.9, sz))


static func _stool(b: B, at: Vector3) -> void:
	b.prop("stool", at, 0.0, func(p: Vector3) -> void: _stool_geo(b, p))


static func _stool_geo(b: B, at: Vector3) -> void:
	b.cyl(at, 0.2, 0.17, 0.46, b.c("timber"), 6)
	b.solid(at + Vector3(0, 0.23, 0), Vector3(0.38, 0.46, 0.38))


static func _bed(b: B, at: Vector3) -> void:
	b.prop("bed", at, 0.0, func(p: Vector3) -> void: _bed_geo(b, p))


static func _bed_geo(b: B, at: Vector3) -> void:
	var tc := b.c("timber")
	b.box(at + Vector3(0, 0.22, 0), Vector3(1.0, 0.3, 2.0), tc)
	b.box(at + Vector3(0, 0.45, 0.05), Vector3(0.92, 0.16, 1.85), b.c("cloth"))
	b.box(at + Vector3(0, 0.58, -0.7), Vector3(0.7, 0.14, 0.4), b.c("cloth2"))
	b.box(at + Vector3(0, 0.5, -1.0), Vector3(1.0, 0.8, 0.08), tc)
	b.solid(at + Vector3(0, 0.35, 0), Vector3(1.0, 0.7, 2.0))


static func _hearth(b: B, at: Vector3) -> void:
	b.prop("hearth", at, 0.0, func(p: Vector3) -> void: _hearth_geo(b, p))


static func _hearth_geo(b: B, at: Vector3) -> void:
	## against a back wall, fire facing +z
	var sc := b.c("stone")
	b.box(at + Vector3(0, 0.55, 0), Vector3(1.8, 1.1, 0.7), sc)
	b.box(at + Vector3(0, 1.9, -0.1), Vector3(1.2, 1.7, 0.5), sc.darkened(0.08))
	b.box(at + Vector3(0, 0.5, 0.33), Vector3(1.0, 0.7, 0.08), Color("1a1210"))
	b.box(at + Vector3(0, 0.34, 0.37), Vector3(0.7, 0.26, 0.06), Color("ff7a2a"), 0.0, true)
	b.light(at + Vector3(0, 1.0, 1.0), Color("ff8a3a"), 6.0)
	b.solid(at + Vector3(0, 1.1, 0), Vector3(1.8, 2.2, 0.7))


static func _shelf(b: B, at: Vector3, length: float, yaw := 0.0) -> void:
	b.prop("shelf", at, yaw, func(p: Vector3) -> void: _shelf_geo(b, p, length))


static func _shelf_geo(b: B, at: Vector3, length: float) -> void:
	var tc := b.c("timber")
	b.box(at + Vector3(0, 1.0, 0), Vector3(length, 2.0, 0.08), tc.darkened(0.1))
	for y in [0.35, 0.95, 1.55]:
		b.box(at + Vector3(0, y, 0.18), Vector3(length, 0.07, 0.4), tc)
		for k in int(length / 0.55):
			var gc: Color = [Color("d9483b"), Color("ffd27a"), Color("6ad050"), Color("c87a3a"), Color("9a6ae0"), Color("9fe0ff")][b.rng.randi() % 6]
			b.box(at + Vector3(-length * 0.5 + 0.3 + k * 0.55, y + 0.17, 0.18), Vector3(0.28, 0.26, 0.28), gc)
	b.solid(at + Vector3(0, 1.0, 0.1), Vector3(length, 2.0, 0.4))


## A bookshelf against a side wall (side -1 = left wall, +1 = right wall), its front facing into the room.
static func _shelf_side(b: B, w: float, side: float, z: float, length: float) -> void:
	_shelf(b, Vector3(side * (w * 0.5 - 0.45), 0, z), length, -side * PI * 0.5)


## A bookshelf turned by yaw (0 = back to the -z wall, PI = back against a +z wall).
static func _shelf_yaw(b: B, at: Vector3, length: float, yaw: float) -> void:
	_shelf(b, at, length, yaw)


static func _counter(b: B, at: Vector3, length: float) -> void:
	b.prop("counter", at, 0.0, func(p: Vector3) -> void: _counter_geo(b, p, length))


static func _counter_geo(b: B, at: Vector3, length: float) -> void:
	var tc := b.c("timber")
	b.box(at + Vector3(0, 0.5, 0), Vector3(length, 1.0, 0.7), tc)
	b.box(at + Vector3(0, 1.03, 0), Vector3(length + 0.1, 0.1, 0.85), tc.lightened(0.2))
	b.solid(at + Vector3(0, 0.55, 0), Vector3(length, 1.1, 0.8))


static func _pew(b: B, at: Vector3, length: float) -> void:
	b.prop("pew", at, 0.0, func(p: Vector3) -> void: _pew_geo(b, p, length))


static func _pew_geo(b: B, at: Vector3, length: float) -> void:
	var tc := b.c("timber")
	b.box(at + Vector3(0, 0.45, 0), Vector3(length, 0.1, 0.5), tc)
	b.box(at + Vector3(0, 0.85, -0.25), Vector3(length, 0.7, 0.08), tc)
	for x in [-1, 1]:
		b.box(at + Vector3(x * (length * 0.5 - 0.1), 0.22, 0), Vector3(0.1, 0.44, 0.45), tc.darkened(0.1))
	b.solid(at + Vector3(0, 0.45, -0.05), Vector3(length, 0.9, 0.6))


static func _carpet(b: B, at: Vector3, sx: float, sz: float, col: Color) -> void:
	b.prop("carpet", at, 0.0, func(p: Vector3) -> void: _carpet_geo(b, p, sx, sz, col))


static func _carpet_geo(b: B, at: Vector3, sx: float, sz: float, col: Color) -> void:
	b.box(at + Vector3(0, 0.07, 0), Vector3(sx, 0.03, sz), col)
	b.box(at + Vector3(0, 0.085, 0), Vector3(sx - 0.25, 0.02, sz - 0.25), col.lightened(0.18))


static func _torch(b: B, at: Vector3) -> void:
	b.prop("torch", at, 0.0, func(p: Vector3) -> void:
		b.box(p, Vector3(0.1, 0.5, 0.1), Color("2a2430"))
		b.box(p + Vector3(0, 0.34, 0), Vector3(0.2, 0.22, 0.2), Color("ffcf7a"), 0.0, true)
		b.light(p + Vector3(0, 0.5, 0.5), Color("ffb060"), 5.0))


## These were rebuilt at full size (roomy inside, some two-storey), so village() leaves them unscaled.
const ROOMY := ["tavern", "shop", "house", "townhouse", "hall_house", "apothecary", "smithy", "chapel"]


static func _bsc(kind: String, bscale: float) -> float:
	if kind in ROOMY:
		return 1.0
	return bscale if kind in BUILDINGS else 1.0


## Rough footprint radius of an asset (for spacing and flattening ground).
static func footprint(kind: String) -> float:
	return {"cottage": 3.6, "house": 5.4, "longhouse": 6.0, "tavern": 7.4, "shop": 7.2, "hall_house": 7.0, "apothecary": 5.8, "smithy": 6.9, "chapel": 8.4,
		"farm": 7.4, "watchtower": 2.6, "windmill": 4.5, "barn": 6.2, "stilt_hut": 3.6, "lodge": 4.6, "farmhouse": 6.4, "granary": 2.6, "fisher_cottage": 4.4, "townhouse": 5.2, "log_cabin": 4.6, "turf_hut": 3.6, "reed_hut": 3.8, "wreck_shack": 4.4, "chalet": 4.6, "gatehouse": 5.0, "wall_tower": 2.2,
		"well": 1.6, "stall": 2.0, "tent": 2.0, "yurt": 2.6, "keep": 9.5}.get(kind, 1.2)


# ================================================================ houses
static func _walls(b: B, w: float, d: float, h: float, timbered := true) -> void:
	## the body of a building with corner posts and a beam around the top
	b.box(Vector3(0, h * 0.5, 0), Vector3(w, h, d), b.c("wall"))
	b.box(Vector3(0, 0.2, 0), Vector3(w + 0.16, 0.4, d + 0.16), b.c("stone"))
	b.solid(Vector3(0, h * 0.5, 0), Vector3(w, h, d))
	if not timbered:
		return
	var tc := b.c("timber")
	for x in [-1, 1]:
		for z in [-1, 1]:
			b.box(Vector3(x * w * 0.5, h * 0.5, z * d * 0.5), Vector3(0.24, h, 0.24), tc)
	b.box(Vector3(0, h - 0.1, d * 0.5), Vector3(w + 0.1, 0.2, 0.18), tc)
	b.box(Vector3(0, h - 0.1, -d * 0.5), Vector3(w + 0.1, 0.2, 0.18), tc)
	b.box(Vector3(w * 0.5, h - 0.1, 0), Vector3(0.18, 0.2, d + 0.1), tc)
	b.box(Vector3(-w * 0.5, h - 0.1, 0), Vector3(0.18, 0.2, d + 0.1), tc)


static func _braces(b: B, w: float, h0: float, h1: float, z: float) -> void:
	## diagonal timber braces on a wall at depth z
	var tc := b.c("timber")
	var side := signf(z)
	for x in [-1, 1]:
		var a := Vector3(x * (w * 0.5 - 0.15), h0 + 0.1, z + side * 0.04)
		var e := Vector3(x * (w * 0.5 - 0.15 - (h1 - h0) * 0.6), h1 - 0.15, z + side * 0.04)
		b.beam(a, e, 0.09, tc)


static func _chimney(b: B, pos: Vector3, h: float) -> void:
	# part of the roof mesh, so it lifts off with the roof instead of standing in the camera's way
	var was := b.in_roof
	b.in_roof = true
	b.box(pos + Vector3(0, h * 0.5, 0), Vector3(0.6, h, 0.6), b.c("stone"))
	b.box(pos + Vector3(0, h + 0.08, 0), Vector3(0.75, 0.16, 0.75), b.c("stone").darkened(0.15))
	b.in_roof = was


static func _roof(b: B, base: Vector3, w: float, d: float, h: float) -> void:
	b.in_roof = true
	b.gable(base, w, d, h, b.c("roof"), b.c("wall2"))
	if b.s["snow"]:
		# snow over the upper half of both slopes
		b.gable(base + Vector3(0, h * 0.45 + 0.07, 0), w * 0.99, d * 0.55, h * 0.55, Color("eef4fa"), Color("eef4fa"))
	b.in_roof = false


static func _cottage(b: B) -> void:
	var w := 5.0 + b.rng.randf_range(-0.4, 0.6)
	var d := 4.0
	var h := 2.6
	_hall(b, w, d, h, -w * 0.18, 0.95, 1.85, _door_mode(b))
	_braces(b, w, 0.4, h, -d * 0.5)
	_roof(b, Vector3(0, h, 0), w + 0.8, d + 1.0, 1.9)
	b.window(Vector3(w * 0.25, 1.5, d * 0.5), 0.7, 0.6, Vector3.BACK)
	b.window(Vector3(w * 0.5, 1.5, 0), 0.6, 0.6, Vector3.RIGHT)
	b.window(Vector3(-w * 0.5, 1.5, 0), 0.6, 0.6, Vector3.LEFT)
	_flowerbox(b, Vector3(w * 0.25, 1.05, d * 0.5 + 0.2), 0.0)
	if b.rng.randf() < 0.7:
		_chimney(b, Vector3(w * 0.3, h, -0.6), 2.5)
	# inside: a bed, a hearth, a table with stools
	_bed(b, Vector3(-w * 0.5 + 0.95, 0, -d * 0.5 + 1.3))
	_hearth(b, Vector3(w * 0.25, 0, -d * 0.5 + 0.65))
	_table(b, Vector3(w * 0.22, 0, 0.45), 1.1, 0.8)
	_stool(b, Vector3(w * 0.22 - 0.9, 0, 0.45))
	_stool(b, Vector3(w * 0.22 + 0.9, 0, 0.45))
	_carpet(b, Vector3(-0.2, 0, 0.1), 1.6, 1.2, b.c("cloth"))


static func _house(b: B) -> void:
	var w := 8.4 + b.rng.randf_range(-0.4, 0.8)
	var d := 6.6
	var h := 5.0
	_hall(b, w, d, h, -1.0, 1.1, 1.95, _door_mode(b, 0.7, 0.2), 0.0, 3.1)
	var tc := b.c("timber")
	b.box(Vector3(0, 2.6, d * 0.5 + 0.02), Vector3(w, 0.2, 0.2), tc)
	b.box(Vector3(0, 2.6, -d * 0.5 - 0.02), Vector3(w, 0.2, 0.2), tc)
	_braces(b, w, 2.7, h, d * 0.5)
	_braces(b, w, 0.4, 2.5, -d * 0.5)
	_roof(b, Vector3(0, h, 0), w + 0.9, d + 1.1, 2.4)
	for x in [-w * 0.3, w * 0.3]:
		b.window(Vector3(x, 1.5, d * 0.5), 0.8, 0.8, Vector3.BACK)
		b.window(Vector3(x, 3.8, d * 0.5), 0.8, 0.8, Vector3.BACK)
		b.window(Vector3(x, 3.8, -d * 0.5), 0.8, 0.8, Vector3.FORWARD)
		_flowerbox(b, Vector3(x, 3.35, d * 0.5 + 0.2), 0.0)
	_chimney(b, Vector3(-w * 0.32, h, 0.8), 2.8)
	# inside: living end on the left, a bed nook on the right; the way in from the door stays clear
	_hearth(b, Vector3(-w * 0.25, 0, -d * 0.5 + 0.65))
	_bed(b, Vector3(w * 0.5 - 0.95, 0, -d * 0.5 + 1.4))
	_bed(b, Vector3(w * 0.5 - 2.1, 0, -d * 0.5 + 1.4))
	_chest(b, Vector3(w * 0.5 - 0.9, 0, 0.4))
	_table(b, Vector3(-w * 0.2, 0, -0.1), 1.8, 1.0)
	for x in [-0.6, 0.0, 0.6]:
		_stool(b, Vector3(-w * 0.2 + x * 1.1, 0, 0.85))
	_stool(b, Vector3(-w * 0.2 - 1.2, 0, -0.1))
	_shelf_side(b, w, -1.0, -1.4, 1.8)
	_carpet(b, Vector3(0.6, 0, 0.0), 2.4, 2.0, b.c("cloth"))


## A long hall-house: a living room with the hearth, a doorway, and a sleeping room beyond.
static func _hall_house(b: B) -> void:
	var w := 11.5 + b.rng.randf_range(-0.5, 1.0)
	var d := 6.6
	var h := 3.1
	var t := 0.3
	_hall(b, w, d, h, -w * 0.5 + 3.2, 1.2, 2.0, _door_mode(b, 0.7, 0.2))
	var px := w * 0.5 - 3.6
	var zb := -d * 0.5 + t
	var zf := d * 0.5 - t
	for pc: Array in [[zb, -0.9], [0.5, zf]]:
		var zc: float = (pc[0] + pc[1]) * 0.5
		var zl: float = pc[1] - pc[0]
		b.box(Vector3(px, h * 0.5, zc), Vector3(0.2, h, zl), b.c("wall"))
		b.solid(Vector3(px, h * 0.5, zc), Vector3(0.2, h, zl))
	b.box(Vector3(px, h - 0.4, -0.2), Vector3(0.24, 0.8, 1.6), b.c("timber"))
	_braces(b, w, 0.4, h, -d * 0.5)
	_roof(b, Vector3(0, h, 0), w + 1.0, d + 1.3, 2.2)
	for x in [-w * 0.5 + 1.2, -w * 0.5 + 5.4, w * 0.5 - 1.6]:
		b.window(Vector3(x, 1.6, d * 0.5), 0.8, 0.7, Vector3.BACK)
	b.window(Vector3(w * 0.5, 1.6, 0), 0.7, 0.7, Vector3.RIGHT)
	b.window(Vector3(-w * 0.5, 1.6, 0), 0.7, 0.7, Vector3.LEFT)
	_flowerbox(b, Vector3(-w * 0.5 + 5.4, 1.15, d * 0.5 + 0.2), 0.0)
	_chimney(b, Vector3(-w * 0.5 + 3.2, h, -d * 0.5 + 0.8), 2.8)
	# living room (left of the partition): hearth on the back wall, table, shelves, carpet
	_hearth(b, Vector3(-w * 0.5 + 3.2, 0, -d * 0.5 + 0.65))
	_table(b, Vector3(-w * 0.5 + 5.3, 0, -0.9), 1.8, 1.0)
	_stool(b, Vector3(-w * 0.5 + 5.3, 0, 0.05))
	_stool(b, Vector3(-w * 0.5 + 4.2, 0, -0.9))
	_stool(b, Vector3(-w * 0.5 + 6.4, 0, -0.9))
	_shelf_side(b, w, -1.0, -1.0, 1.8)
	_carpet(b, Vector3(-w * 0.5 + 3.8, 0, -0.6), 3.0, 2.0, b.c("cloth"))
	# sleeping room (right of the partition)
	_bed(b, Vector3(px + 1.0, 0, -d * 0.5 + 1.45))
	_bed(b, Vector3(px + 2.3, 0, -d * 0.5 + 1.45))
	_chest(b, Vector3(w * 0.5 - 1.0, 0, 0.2))
	_shelf_yaw(b, Vector3(px + 1.6, 0, d * 0.5 - 0.45), 1.5, PI)
	_carpet(b, Vector3(px + 1.7, 0, 0.5), 1.6, 1.4, b.c("cloth"))


static func _longhouse(b: B) -> void:
	var w := 10.0
	var d := 5.0
	var h := 2.3
	_hall(b, w, d, h, 0.0, 1.3, 1.85, _door_mode(b, 0.8, 0.2), 0.0, -1.0, "wall", Color("ffa860"))
	_roof(b, Vector3(0, h, 0), w + 1.2, d + 1.6, 2.8)
	var tc := b.c("timber")
	# carved ridge ends
	b.in_roof = true
	for x in [-1, 1]:
		b.beam(Vector3(x * (w * 0.5 + 0.6), h + 2.6, 0), Vector3(x * (w * 0.5 + 1.1), h + 3.4, 0), 0.12, tc)
	b.in_roof = false
	for x in [-3.2, 3.2]:
		b.window(Vector3(x, 1.4, d * 0.5), 0.6, 0.5, Vector3.BACK)
	# shields along the wall
	for x in [-1.8, 1.8]:
		b.box(Vector3(x, 1.5, d * 0.5 + 0.08), Vector3(0.6, 0.6, 0.06), b.c("trim"))
		b.box(Vector3(x, 1.5, d * 0.5 + 0.12), Vector3(0.18, 0.18, 0.04), Color("d8b04a"))
	_chimney(b, Vector3(2.0, h, -0.5), 3.0)
	# inside: a long table with benches, and a fire pit
	_table(b, Vector3(-1.6, 0, -0.8), 4.2, 0.9)
	for k in 4:
		_stool(b, Vector3(-3.1 + k * 1.1, 0, -0.05))
		_stool(b, Vector3(-3.1 + k * 1.1, 0, -1.55))
	b.piece("fire_pit", Vector3(2.6, 0, -0.2), 0.0, func() -> void:
		b.box(Vector3(2.6, 0.12, -0.2), Vector3(1.4, 0.24, 1.4), b.c("stone"))
		b.box(Vector3(2.6, 0.28, -0.2), Vector3(0.9, 0.1, 0.9), Color("ff7a2a"), 0.0, true)
		b.light(Vector3(2.6, 1.0, -0.2), Color("ff8a3a"), 6.5)
		b.solid(Vector3(2.6, 0.15, -0.2), Vector3(1.4, 0.3, 1.4)))
	_bed(b, Vector3(-w * 0.5 + 0.9, 0, -d * 0.5 + 1.3))
	_bed(b, Vector3(w * 0.5 - 0.9, 0, -d * 0.5 + 1.3))
	_carpet(b, Vector3(-1.6, 0, -0.8), 4.8, 2.4, b.c("cloth"))


## Turn on the second floor: everything built until _up_off() lands on it (own mesh, shifted up).
static func _up_on(b: B) -> void:
	b.in_upper = true
	b.xf = Transform3D(Basis.IDENTITY, Vector3(0, b.floor_y, 0))


static func _up_off(b: B) -> void:
	b.in_upper = false
	b.xf = Transform3D.IDENTITY


## Second floor: a slab with a stair opening, steps and a ramp up to it, and the upper walls.
## side = -1 puts the stairs along the left wall, +1 along the right. run = how far they climb.
static func _storey(b: B, w: float, d: float, oz: float, fy: float, h2: float, side: float, run: float, wall_key := "wall") -> void:
	var t := 0.3
	var zf := oz + d * 0.5
	var zb := oz - d * 0.5
	var z0 := zf - t - 1.0   # a metre of free floor in front of the bottom step, to step onto the stairs from
	# always leave at least 1.4 m of clear floor beyond the top step, so you walk off the stairs cleanly
	var zend := maxf(z0 - run, zb + t + 1.4)
	run = z0 - zend
	var sw := 1.5
	var xin := w * 0.5 - t
	var sx0 := -xin if side < 0.0 else xin - sw - 0.1
	var sx1 := sx0 + sw + 0.1
	var sc := (sx0 + sx1) * 0.5
	var tc := b.c("timber")
	var wc := b.c(wall_key)
	b.floor_y = fy
	b.max_y = fy + h2 + 0.4
	# the steps (look) and the ramp that carries you up them (feel)
	var n := int(fy / 0.22 + 0.5)
	for i in n:
		var top := (i + 1) * fy / n
		b.box(Vector3(sc, top * 0.5, z0 - (i + 0.5) * run / n), Vector3(sw, top, run / n + 0.02), tc.lightened(0.1))
	var ang := atan2(fy, run)
	var ramp_len := sqrt(run * run + fy * fy)
	b.floor_solid(Vector3(sc, fy * 0.5 - 0.12, (z0 + zend) * 0.5), Vector3(sw, 0.2, ramp_len), ang)
	var edge := sx1 + 0.05 if side < 0.0 else sx0 - 0.05
	b.box(Vector3(edge, fy * 0.5, (z0 + zend) * 0.5), Vector3(0.1, fy, run), tc)
	b.floor_solid(Vector3(edge, fy * 0.5, (z0 + zend) * 0.5), Vector3(0.1, fy, run))
	_up_on(b)
	var pieces: Array
	if side < 0.0:
		pieces = [[sx1, xin, zb + t, zf - t], [-xin, sx1, z0, zf - t], [-xin, sx1, zb + t, zend]]
	else:
		pieces = [[-xin, sx0, zb + t, zf - t], [sx0, xin, z0, zf - t], [sx0, xin, zb + t, zend]]
	for pc: Array in pieces:
		var sx: float = pc[1] - pc[0]
		var sz: float = pc[3] - pc[2]
		if sx <= 0.05 or sz <= 0.05:
			continue
		var cen := Vector3((pc[0] + pc[1]) * 0.5, -0.125, (pc[2] + pc[3]) * 0.5)
		b.box(cen, Vector3(sx, 0.25, sz), tc.lightened(0.1))
		b.floor_solid(cen, Vector3(sx, 0.25, sz))
	# upper walls
	b.box(Vector3(0, h2 * 0.5, zb + t * 0.5), Vector3(w, h2, t), wc)
	b.solid(Vector3(0, h2 * 0.5, zb + t * 0.5), Vector3(w, h2, t))
	b.box(Vector3(0, h2 * 0.5, zf - t * 0.5), Vector3(w, h2, t), wc)
	b.solid(Vector3(0, h2 * 0.5, zf - t * 0.5), Vector3(w, h2, t))
	for sx in [-1, 1]:
		b.box(Vector3(sx * (w * 0.5 - t * 0.5), h2 * 0.5, oz), Vector3(t, h2, d), wc)
		b.solid(Vector3(sx * (w * 0.5 - t * 0.5), h2 * 0.5, oz), Vector3(t, h2, d))
		for sz in [-1, 1]:
			b.box(Vector3(sx * w * 0.5, h2 * 0.5, oz + sz * d * 0.5), Vector3(0.24, h2, 0.24), tc)
	b.box(Vector3(0, 0.0, zf), Vector3(w + 0.12, 0.2, 0.2), tc)
	b.box(Vector3(0, 0.0, zb), Vector3(w + 0.12, 0.2, 0.2), tc)
	b.box(Vector3(w * 0.5, 0.0, oz), Vector3(0.2, 0.2, d + 0.12), tc)
	b.box(Vector3(-w * 0.5, 0.0, oz), Vector3(0.2, 0.2, d + 0.12), tc)
	b.light(Vector3(0, h2 - 0.7, oz), Color("ffb870"), maxf(w, d) * 0.8)
	_up_off(b)


static func _tavern(b: B) -> void:
	var w := 12.0
	var d := 8.0
	var fy := 3.4
	var h2 := 3.0
	_hall(b, w, d, fy, 1.5, 1.6, 2.2, "open", 0.0, -1.0, "wall", Color("ffa860"))
	_storey(b, w, d, 0.0, fy, h2, -1.0, 5.0)
	var tc := b.c("timber")
	_braces(b, w, 0.4, fy, -d * 0.5)
	_roof(b, Vector3(0, fy + h2, 0), w + 1.2, d + 1.4, 3.0)
	for x in [-3.8, 4.2]:
		b.window(Vector3(x, 1.5, d * 0.5), 1.2, 0.9, Vector3.BACK)
	b.window(Vector3(w * 0.5, 1.5, 0), 0.9, 0.8, Vector3.RIGHT)
	b.window(Vector3(-w * 0.5, 1.5, 0), 0.9, 0.8, Vector3.LEFT)
	_up_on(b)
	for x in [-4.0, -1.5, 1.0, 3.5, 5.0]:
		b.window(Vector3(x, 1.6, d * 0.5), 0.7, 0.8, Vector3.BACK)
	b.window(Vector3(w * 0.5, 1.6, 0), 0.8, 0.8, Vector3.RIGHT)
	b.window(Vector3(-w * 0.5, 1.6, 0), 0.8, 0.8, Vector3.LEFT)
	# bedrooms upstairs: beds along the back wall, chests, a washstand and a table
	for k in 4:
		_bed(b, Vector3(-0.9 + k * 2.0, 0, -d * 0.5 + 1.35))   # the strip beside the stairs stays clear to walk off them
	_chest(b, Vector3(0.1, 0, -d * 0.5 + 0.6))
	_chest(b, Vector3(4.1, 0, -d * 0.5 + 0.6))
	_table(b, Vector3(2.0, 0, 1.2), 1.6, 1.0)
	_stool(b, Vector3(1.2, 0, 2.1))
	_stool(b, Vector3(2.8, 0, 2.1))
	_shelf_side(b, w, 1.0, 0.0, 2.0)
	_carpet(b, Vector3(0.4, 0, 0.6), 4.0, 2.8, b.c("cloth"))
	_up_off(b)
	_chimney(b, Vector3(w * 0.3, fy + h2, -1.4), 3.2)
	_chimney(b, Vector3(-w * 0.3, fy + h2, -1.4), 2.6)
	# hanging sign: a tankard
	b.piece("tavern_sign", Vector3(3.2, 2.4, d * 0.5 + 1.0), 0.0, func() -> void:
		b.box(Vector3(3.2, 3.0, d * 0.5 + 0.7), Vector3(0.1, 0.1, 1.4), tc)
		b.box(Vector3(3.2, 2.4, d * 0.5 + 1.2), Vector3(0.9, 0.7, 0.08), b.c("wall2"))
		b.box(Vector3(3.2, 2.4, d * 0.5 + 1.26), Vector3(0.36, 0.4, 0.04), Color("d8b04a")))
	for x in [0.4, 2.6]:
		b.piece("porch_lamp", Vector3(x, 2.4, d * 0.5 + 0.2), 0.0, func() -> void:
			b.box(Vector3(x, 2.4, d * 0.5 + 0.2), Vector3(0.22, 0.3, 0.22), Color("ffcf7a"), 0.0, true)
			b.light(Vector3(x, 2.4, d * 0.5 + 0.5), Color("ffb060"), 4.5))
	# out front: benches, barrels, a table to sit at
	_bench_at(b, Vector3(-3.8, 0, d * 0.5 + 1.2), 0.0)
	_barrel(b, Vector3(5.4, 0, d * 0.5 + 0.8))
	_barrel(b, Vector3(5.4, 0, d * 0.5 + 1.6))
	# inside: the bar, barrels behind it, a hearth, tables; the way in from the door stays clear
	_counter(b, Vector3(2.4, 0, -1.2), 6.0)
	for k in 5:
		_barrel(b, Vector3(-0.2 + k * 1.15, 0, -d * 0.5 + 0.6))
	_hearth(b, Vector3(-2.7, 0, -d * 0.5 + 0.65))
	_table(b, Vector3(-2.2, 0, -0.5), 1.3, 1.1)
	_stool(b, Vector3(-3.3, 0, -0.5))
	_stool(b, Vector3(-1.1, 0, -0.5))
	_table(b, Vector3(-2.2, 0, 1.1), 1.3, 1.1)
	_stool(b, Vector3(-3.3, 0, 1.1))
	_stool(b, Vector3(-1.1, 0, 1.1))
	_table(b, Vector3(4.2, 0, 1.4), 1.3, 1.1)
	_stool(b, Vector3(3.1, 0, 1.4))
	_stool(b, Vector3(5.1, 0, 1.4))
	_carpet(b, Vector3(1.5, 0, 1.0), 2.6, 3.0, b.c("cloth"))


## The general store: wide front, a long counter with the shopkeeper behind it, shelves on three walls.
static func _shop(b: B) -> void:
	var w := 12.0
	var d := 8.0
	var h := 3.4
	_hall(b, w, d, h, -3.2, 1.4, 2.1, "open")
	_roof(b, Vector3(0, h, 0), w + 1.2, d + 1.4, 2.4)
	# big shop windows + striped awning over the front
	for x in [0.8, 4.4]:
		b.window(Vector3(x, 1.5, d * 0.5), 1.8, 1.0, Vector3.BACK)
	for k in 9:
		var col := b.c("cloth") if k % 2 == 0 else b.c("cloth2")
		b.box(Vector3(-w * 0.5 + 0.7 + k * 1.3, 2.7, d * 0.5 + 0.8), Vector3(1.3, 0.06, 1.7), col, 0.0, false, 0.3)
	b.window(Vector3(w * 0.5, 1.6, 1.0), 0.8, 0.8, Vector3.RIGHT)
	b.window(Vector3(-w * 0.5, 1.6, 1.0), 0.8, 0.8, Vector3.LEFT)
	_chimney(b, Vector3(w * 0.32, h, -1.5), 2.4)
	# stock outside
	_crate(b, Vector3(w * 0.5 - 0.8, 0, d * 0.5 + 0.9), 0.8, 0.3)
	_crate(b, Vector3(w * 0.5 - 0.8, 0.8, d * 0.5 + 0.9), 0.6, -0.2)
	_barrel(b, Vector3(w * 0.5 - 1.8, 0, d * 0.5 + 0.8))
	_barrel(b, Vector3(-w * 0.5 + 0.8, 0, d * 0.5 + 0.8))
	# inside: shelves on the back and both side walls, counter in the middle, sacks and crates
	_shelf(b, Vector3(-3.0, 0, -d * 0.5 + 0.45), 5.0)
	_shelf(b, Vector3(3.2, 0, -d * 0.5 + 0.45), 5.0)
	_shelf_side(b, w, -1.0, -0.6, 4.0)
	_shelf_side(b, w, 1.0, -0.6, 4.0)
	_counter(b, Vector3(2.2, 0, -0.5), 6.0)
	# stock sits in the corners, well clear of the door (left of the front wall) and the way to the counter
	b.piece("sacks", Vector3(-w * 0.5 + 0.9, 0, 3.2), 0.0, func() -> void:
		for k in 2:
			b.box(Vector3(-w * 0.5 + 0.9, 0.3 + k * 0.6, 3.2), Vector3(0.8, 0.6, 0.6), Color("c9b48a").darkened(0.1 * k), 0.12 * k)
		b.solid(Vector3(-w * 0.5 + 0.9, 0.6, 3.2), Vector3(0.8, 1.2, 0.6)))
	_barrel(b, Vector3(-w * 0.5 + 0.8, 0, 2.3))
	_barrel(b, Vector3(-w * 0.5 + 0.8, 0, 1.6))
	_crate(b, Vector3(w * 0.5 - 0.9, 0, 3.0), 0.8, 0.2)
	_crate(b, Vector3(w * 0.5 - 0.9, 0, 2.2), 0.7, -0.2)
	_carpet(b, Vector3(-2.4, 0, 0.8), 3.0, 2.4, b.c("cloth"))
	for x in [-2.5, 2.5]:
		b.piece("ceiling_lamp", Vector3(x, h - 0.5, 0.5), 0.0, func() -> void:
			b.box(Vector3(x, h - 0.5, 0.5), Vector3(0.22, 0.3, 0.22), Color("ffcf7a"), 0.0, true)
			b.light(Vector3(x, h - 0.9, 0.5), Color("ffb060"), 5.0))


## The apothecary: herbs, a bubbling cauldron, a counter and a keeper behind it.
static func _apothecary(b: B) -> void:
	var w := 9.0
	var d := 7.0
	var h := 3.2
	_hall(b, w, d, h, -2.2, 1.2, 2.0, "open", 0.0, -1.0, "stone", Color("b8ffc0"))
	_roof(b, Vector3(0, h, 0), w + 1.0, d + 1.2, 2.2)
	for x in [0.8, 3.0]:
		b.window(Vector3(x, 1.5, d * 0.5), 0.9, 0.9, Vector3.BACK)
	b.window(Vector3(w * 0.5, 1.6, 0.5), 0.7, 0.8, Vector3.RIGHT)
	b.window(Vector3(-w * 0.5, 1.6, 0.5), 0.7, 0.8, Vector3.LEFT)
	_chimney(b, Vector3(-w * 0.3, h, -1.2), 2.6)
	# a hanging sign with a green leaf, and herb planters out front
	var tc := b.c("timber")
	b.piece("shop_sign", Vector3(2.0, 2.1, d * 0.5 + 1.0), 0.0, func() -> void:
		b.box(Vector3(2.0, 2.6, d * 0.5 + 0.7), Vector3(0.1, 0.1, 1.4), tc)
		b.box(Vector3(2.0, 2.1, d * 0.5 + 1.2), Vector3(0.8, 0.7, 0.08), b.c("wall2"))
		b.box(Vector3(2.0, 2.1, d * 0.5 + 1.26), Vector3(0.36, 0.4, 0.04), Color("5fc06a")))
	_flowerbox(b, Vector3(0.8, 0.75, d * 0.5 + 0.35), 0.0)
	_flowerbox(b, Vector3(3.0, 0.75, d * 0.5 + 0.35), 0.0)
	# inside: shelves of jars on the back wall and the left wall, drying herbs on the right
	_shelf(b, Vector3(-1.4, 0, -d * 0.5 + 0.45), 5.0)
	_shelf(b, Vector3(3.0, 0, -d * 0.5 + 0.45), 2.0)
	_shelf_side(b, w, -1.0, -0.2, 3.6)
	_counter(b, Vector3(0.6, 0, -0.6), 4.6)
	# the cauldron, glowing green
	var cp := Vector3(3.2, 0, 0.6)
	b.piece("cauldron", cp, 0.0, func() -> void:
		b.cyl(cp, 0.7, 0.85, 0.8, Color("2a2a30"), 8)
		b.box(cp + Vector3(0, 0.82, 0), Vector3(1.1, 0.06, 1.1), Color("6ae07a"), 0.0, true)
		b.light(cp + Vector3(0, 1.2, 0), Color("7aff8a"), 5.0)
		b.solid(cp + Vector3(0, 0.45, 0), Vector3(1.6, 0.9, 1.6)))
	# drying rack of herbs
	b.piece("herb_rack", Vector3(w * 0.5 - 0.6, 0, -1.2), 0.0, func() -> void:
		for k in 5:
			b.box(Vector3(w * 0.5 - 0.6, 1.6, -2.2 + k * 0.5), Vector3(0.12, 0.7, 0.12), [Color("6aa84f"), Color("8a6ae0"), Color("c8a84f"), Color("6aa84f"), Color("d9483b")][k])
		b.box(Vector3(w * 0.5 - 0.6, 2.0, -1.2), Vector3(0.1, 0.1, 3.2), tc))
	_table(b, Vector3(w * 0.5 - 1.5, 0, 2.3), 1.0, 1.4)
	_stool(b, Vector3(w * 0.5 - 2.5, 0, 2.3))
	_crate(b, Vector3(-w * 0.5 + 0.8, 0, 1.95), 0.7, 0.2)
	_barrel(b, Vector3(-w * 0.5 + 0.8, 0, 2.7))
	_carpet(b, Vector3(-2.2, 0, 1.4), 2.4, 2.0, Color("3a6a4a"))


static func _chest(b: B, at: Vector3) -> void:
	b.prop("chest", at, 0.0, func(p: Vector3) -> void: _chest_geo(b, p))


static func _chest_geo(b: B, at: Vector3) -> void:
	var tc := b.c("timber")
	b.box(at + Vector3(0, 0.3, 0), Vector3(1.0, 0.6, 0.6), tc.darkened(0.1))
	b.box(at + Vector3(0, 0.65, 0), Vector3(1.04, 0.12, 0.64), tc.lightened(0.1))
	b.box(at + Vector3(0, 0.45, 0.31), Vector3(0.14, 0.14, 0.04), Color("d8b04a"))
	b.solid(at + Vector3(0, 0.35, 0), Vector3(1.0, 0.7, 0.6))


static func _smithy(b: B) -> void:
	# a proper working forge: walk-in hall with the stone forge on the back wall, Hilde's anvil in the middle,
	# a bench, grindstone and racks, and an open awning out front
	var w := 11.0
	var d := 8.0
	var h := 3.8
	var tc := b.c("timber")
	_hall(b, w, d, h, 0.0, 2.8, 2.7, "open", 0.0, -1.0, "wall", Color("ffa860"))
	_roof(b, Vector3(0, h, 0), w + 1.2, d + 1.4, 2.6)
	for x in [-3.5, -0.8, 3.8]:
		b.window(Vector3(x, 2.3, -d * 0.5 + 0.02), 0.7, 0.6, Vector3.FORWARD)
	b.window(Vector3(w * 0.5, 2.1, 1.8), 0.7, 0.7, Vector3.RIGHT)
	b.window(Vector3(-w * 0.5, 2.1, 1.8), 0.7, 0.7, Vector3.LEFT)
	# awning over the front: posts and a slab, with the grindstone and a cutting stump under it
	for x in [-4.6, 4.6]:
		b.box(Vector3(x, 1.5, d * 0.5 + 1.9), Vector3(0.24, 3.0, 0.24), tc)
		b.solid(Vector3(x, 1.5, d * 0.5 + 1.9), Vector3(0.3, 3.0, 0.3))
	b.box(Vector3(0, 3.05, d * 0.5 + 1.0), Vector3(10.2, 0.18, 2.0), tc.darkened(0.1))
	b.piece("grindstone", Vector3(-3.4, 0, d * 0.5 + 1.2), 0.0, func() -> void:
		b.cyl(Vector3(-3.4, 0, d * 0.5 + 1.2), 0.5, 0.5, 0.18, b.c("stone"), 8)
		b.box(Vector3(-3.4, 0.55, d * 0.5 + 1.2), Vector3(0.1, 0.7, 0.1), tc)
		b.solid(Vector3(-3.4, 0.5, d * 0.5 + 1.2), Vector3(0.9, 1.0, 0.9)))
	b.piece("stump", Vector3(3.5, 0, d * 0.5 + 1.2), 0.0, func() -> void:
		b.cyl(Vector3(3.5, 0, d * 0.5 + 1.2), 0.45, 0.45, 0.8, tc.lightened(0.1), 7)
		b.solid(Vector3(3.5, 0.4, d * 0.5 + 1.2), Vector3(0.9, 0.8, 0.9)))
	# outside: firewood, a coal heap and spare barrels
	_firewood_at(b, Vector3(-w * 0.5 - 1.0, 0, 0.5), PI * 0.5)
	b.piece("coal_heap", Vector3(w * 0.5 + 1.1, 0, -1.4), 0.0, func() -> void:
		b.cone(Vector3(w * 0.5 + 1.1, 0, -1.4), 0.95, 0.9, Color("26222a"), 7))
	_barrel(b, Vector3(w * 0.5 + 1.0, 0, 1.0))
	_barrel(b, Vector3(w * 0.5 + 1.0, 0, 1.9))
	# the stone forge against the back wall, flue to the roof
	var fz := -d * 0.5 + 1.0
	b.piece("forge", Vector3(-3.4, 0, fz), 0.0, func() -> void:
		b.box(Vector3(-3.4, 0.5, fz), Vector3(2.6, 1.0, 1.5), b.c("stone"))
		b.solid(Vector3(-3.4, 0.5, fz), Vector3(2.6, 1.0, 1.5))
		b.box(Vector3(-3.4, 1.02, fz + 0.05), Vector3(1.8, 0.08, 1.0), Color("ff7a2a"), 0.0, true)
		b.box(Vector3(-3.4, 2.4, fz - 0.45), Vector3(1.5, 2.8, 0.6), b.c("stone").darkened(0.08))
		b.box(Vector3(-3.4, 1.55, fz - 0.05), Vector3(2.0, 0.2, 1.3), b.c("stone").darkened(0.12))
		b.light(Vector3(-3.4, 1.7, fz + 0.9), Color("ff8a3a"), 7.0))
	_chimney(b, Vector3(-3.4, h, fz - 0.4), 2.2)
	# bellows beside it
	b.piece("bellows", Vector3(-1.4, 0, fz), 0.0, func() -> void:
		b.box(Vector3(-1.4, 0.55, fz), Vector3(0.9, 0.5, 0.5), Color("5a3a2a"))
		b.box(Vector3(-1.4, 0.4, fz), Vector3(0.3, 0.8, 0.3), tc)
		b.solid(Vector3(-1.4, 0.45, fz), Vector3(0.9, 0.9, 0.6)))
	# anvil (Hilde stands behind it), quench trough
	b.piece("anvil", Vector3(1.0, 0, 0.4), 0.0, func() -> void:
		b.box(Vector3(1.0, 0.35, 0.4), Vector3(0.5, 0.7, 0.4), tc)
		b.box(Vector3(1.0, 0.8, 0.4), Vector3(0.9, 0.25, 0.4), Color("4a4a52"))
		b.box(Vector3(1.0, 0.98, 0.4), Vector3(0.28, 0.1, 0.3), Color("4a4a52"))
		b.solid(Vector3(1.0, 0.5, 0.4), Vector3(0.9, 1.0, 0.5)))
	b.piece("trough_quench", Vector3(3.0, 0, 0.2), 0.0, func() -> void:
		b.box(Vector3(3.0, 0.3, 0.2), Vector3(1.8, 0.6, 0.8), tc.darkened(0.1))
		b.box(Vector3(3.0, 0.52, 0.2), Vector3(1.6, 0.06, 0.6), Color("2a4a6a"))
		b.solid(Vector3(3.0, 0.35, 0.2), Vector3(1.8, 0.7, 0.8)))
	# racks of weapons along the back, a long workbench and tools on the side walls
	_weapon_rack_at(b, Vector3(1.8, 0, -d * 0.5 + 0.4))
	_weapon_rack_at(b, Vector3(3.8, 0, -d * 0.5 + 0.4))
	_table(b, Vector3(w * 0.5 - 0.9, 0, -1.9), 1.0, 2.4)
	for k in 3:
		b.box(Vector3(w * 0.5 - 0.9, 0.9, -2.7 + k * 0.5), Vector3(0.7, 0.1, 0.18), Color("8a8a96"))
	for k in 6:
		b.box(Vector3(-w * 0.5 + 0.38, 1.9, -1.2 + k * 0.55), Vector3(0.08, 0.7, 0.08), Color("5a5a62"))
		b.box(Vector3(-w * 0.5 + 0.38, 2.3, -1.2 + k * 0.55), Vector3(0.14, 0.14, 0.1), tc)
	# coal bin, ingot crates, a barrel of water, a cot for the helper
	b.piece("coal_bin", Vector3(-w * 0.5 + 1.0, 0, 0.9), 0.0, func() -> void:
		b.box(Vector3(-w * 0.5 + 1.0, 0.4, 0.9), Vector3(1.6, 0.8, 1.4), tc.darkened(0.15))
		b.box(Vector3(-w * 0.5 + 1.0, 0.82, 0.9), Vector3(1.4, 0.06, 1.2), Color("26222a"))
		b.solid(Vector3(-w * 0.5 + 1.0, 0.45, 0.9), Vector3(1.6, 0.9, 1.4)))
	_crate(b, Vector3(-w * 0.5 + 0.8, 0, 3.0), 0.8, 0.2)
	_crate(b, Vector3(-w * 0.5 + 1.8, 0, 3.1), 0.7, -0.3)
	_barrel(b, Vector3(w * 0.5 - 0.8, 0, 3.0))
	_bed(b, Vector3(w * 0.5 - 1.0, 0, 1.2))


static func _chapel(b: B) -> void:
	# a proper chapel: tall stone nave with a pillared aisle either side, pews, a pulpit, a font, an altar on a dais
	# and a bell tower on the front
	var w := 8.0
	var d := 14.0
	var h := 4.6
	var oz := 0.0
	var sc := b.c("stone")
	_hall(b, w, d, h, 0.0, 2.0, 3.0, "open", oz, -1.0, "stone", Color("ffc88a"))
	b.in_roof = true
	var save := b.xf
	b.xf = b.xf * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, 0, oz))
	b.gable(Vector3(0, h, 0), d + 0.9, w + 1.0, 3.2, b.c("roof2"), sc.lightened(0.15))
	b.xf = save
	var th := 10.0
	var tz := oz + d * 0.5 - 1.5
	b.box(Vector3(0, (th + h) * 0.5, tz), Vector3(3.2, th - h, 3.2), sc)
	b.box(Vector3(0, th - 1.2, tz + 1.62), Vector3(1.1, 1.5, 0.06), Color("1a1420"))
	b.cyl(Vector3(0, th - 1.6, tz), 0.4, 0.22, 0.8, Color("d8b04a"), 7)
	b.pyramid(Vector3(0, th, tz), 3.8, 3.8, 4.2, b.c("roof2"))
	b.box(Vector3(0, th + 4.6, tz), Vector3(0.14, 1.0, 0.14), Color("d8b04a"))
	b.box(Vector3(0, th + 4.7, tz), Vector3(0.6, 0.14, 0.14), Color("d8b04a"))
	b.in_roof = false
	# tall windows down both sides, a rose window over the door
	for z in [-4.5, -1.5, 1.5, 4.5]:
		b.window(Vector3(w * 0.5, 2.7, z + oz), 0.8, 2.2, Vector3.RIGHT)
		b.window(Vector3(-w * 0.5, 2.7, z + oz), 0.8, 2.2, Vector3.LEFT)
	b.window(Vector3(0, 3.9, oz + d * 0.5), 1.4, 1.3, Vector3.BACK)
	# stone buttresses outside
	for z in [-4.5, 0.0, 4.5]:
		for sx in [-1, 1]:
			b.box(Vector3(sx * (w * 0.5 + 0.3), 1.7, z + oz), Vector3(0.6, 3.4, 0.7), sc.darkened(0.05))
			b.solid(Vector3(sx * (w * 0.5 + 0.3), 1.7, z + oz), Vector3(0.6, 3.4, 0.7))
	# pillars either side of the aisle, with a candle stand between each pair
	for k in 5:
		var pz := oz + 4.4 - k * 2.2
		for sx in [-1, 1]:
			b.piece("pillar", Vector3(sx * 2.7, 0, pz), 0.0, func() -> void:
				b.cyl(Vector3(sx * 2.7, 0, pz), 0.3, 0.3, h - 0.1, sc.lightened(0.1), 6)
				b.solid(Vector3(sx * 2.7, h * 0.5, pz), Vector3(0.6, h, 0.6)))
	for z in [3.3, -1.1]:
		for sx in [-1, 1]:
			var cp := Vector3(sx * 3.5, 0, z + oz)
			b.piece("candle_stand", cp, 0.0, func() -> void:
				b.box(cp + Vector3(0, 0.6, 0), Vector3(0.12, 1.2, 0.12), Color("2a2430"))
				b.box(cp + Vector3(0, 1.3, 0), Vector3(0.2, 0.22, 0.2), Color("ffcf7a"), 0.0, true)
				b.solid(cp + Vector3(0, 0.6, 0), Vector3(0.3, 1.2, 0.3)))
		b.light(Vector3(0, 2.6, z + oz), Color("ffd8a0"), 6.0)
	# inside: a red carpet to the altar, five rows of pews
	_carpet(b, Vector3(0, 0, oz - 0.3), 1.5, d - 1.6, Color("8a2a3a"))
	for k in 5:
		_pew(b, Vector3(-1.5, 0, oz + 4.4 - k * 1.6), 1.5)
		_pew(b, Vector3(1.5, 0, oz + 4.4 - k * 1.6), 1.5)
	# font by the door, bookshelf and pulpit toward the front of the altar
	b.piece("font", Vector3(2.8, 0, oz + d * 0.5 - 0.9), 0.0, func() -> void:
		b.cyl(Vector3(2.8, 0, oz + d * 0.5 - 0.9), 0.5, 0.4, 0.9, sc.lightened(0.15), 8)
		b.box(Vector3(2.8, 0.9, oz + d * 0.5 - 0.9), Vector3(0.7, 0.05, 0.7), Color("9fd0ff"), 0.0, true)
		b.solid(Vector3(2.8, 0.45, oz + d * 0.5 - 0.9), Vector3(1.0, 0.9, 1.0)))
	var az := oz - d * 0.5 + 1.0
	b.piece("altar", Vector3(0, 0, az), 0.0, func() -> void:
		b.box(Vector3(0, 0.09, az + 0.5), Vector3(5.0, 0.18, 3.0), sc.lightened(0.1))
		b.box(Vector3(0, 0.75, az), Vector3(2.4, 1.1, 0.9), sc.lightened(0.2))
		b.solid(Vector3(0, 0.75, az), Vector3(2.4, 1.1, 0.9)))
	for x in [-0.8, 0.8]:
		b.box(Vector3(x, 1.45, az), Vector3(0.1, 0.3, 0.1), Color("fff0c0"), 0.0, true)
	b.box(Vector3(0, 2.8, oz - d * 0.5 + 0.35), Vector3(1.2, 2.0, 0.05), Color("9fd0ff"), 0.0, true)
	b.light(Vector3(0, 2.0, az + 0.9), Color("ffd8a0"), 6.0)
	b.piece("pulpit", Vector3(-3.1, 0, az + 2.7), 0.0, func() -> void:
		b.box(Vector3(-3.1, 0.55, az + 2.7), Vector3(0.9, 1.1, 0.8), b.c("timber"))
		b.box(Vector3(-3.1, 1.15, az + 2.7), Vector3(1.0, 0.1, 0.9), b.c("timber").lightened(0.2))
		b.solid(Vector3(-3.1, 0.6, az + 2.7), Vector3(0.9, 1.2, 0.8)))
	_shelf(b, Vector3(2.5, 0, oz - d * 0.5 + 0.6), 2.0)


static func _watchtower(b: B) -> void:
	var tc := b.c("timber")
	var h := 6.5
	for x in [-1, 1]:
		for z in [-1, 1]:
			b.beam(Vector3(x * 1.4, 0, z * 1.4), Vector3(x * 1.1, h + 1.6, z * 1.1), 0.14, tc)
			b.solid(Vector3(x * 1.3, h * 0.5, z * 1.3), Vector3(0.3, h, 0.3))
	for y in [2.0, 4.2]:
		b.beam(Vector3(-1.3, y, 1.3), Vector3(1.3, y + 1.2, 1.3), 0.08, tc)
		b.beam(Vector3(1.3, y, -1.3), Vector3(-1.3, y + 1.2, -1.3), 0.08, tc)
	b.box(Vector3(0, h, 0), Vector3(3.0, 0.2, 3.0), tc.lightened(0.15))
	for k in 4:
		var a := k * PI * 0.5
		b.box(Vector3(sin(a) * 1.45, h + 0.5, cos(a) * 1.45), Vector3(2.9, 0.8, 0.12), tc, a)
	b.pyramid(Vector3(0, h + 1.7, 0), 3.6, 3.6, 1.8, b.c("roof"))
	# ladder
	for x in [-0.25, 0.25]:
		b.beam(Vector3(x, 0, 2.2), Vector3(x, h, 1.5), 0.05, tc)
	for k in 9:
		var y := 0.5 + k * 0.7
		b.box(Vector3(0, y, 2.2 - (y / h) * 0.7), Vector3(0.55, 0.05, 0.05), tc)
	_banner_at(b, Vector3(1.4, h + 1.6, 1.4), 1.6)


static func _windmill(b: B) -> void:
	b.cyl(Vector3(0, 0, 0), 2.6, 1.7, 7.5, b.c("stone").lightened(0.1), 8)
	b.solid(Vector3(0, 3.7, 0), Vector3(3.6, 7.4, 3.6))
	b.cone(Vector3(0, 7.5, 0), 2.2, 2.4, b.c("roof"), 8)
	b.door(Vector3(0, 0.0, 2.5), 1.0, 2.0, Vector3.BACK)
	b.window(Vector3(0, 4.5, 2.0), 0.6, 0.7, Vector3.BACK)
	b.box(Vector3(0, 7.6, 2.0), Vector3(0.5, 0.5, 0.9), b.c("timber"))
	# the blades are their own node, so they can turn
	var bb := B.new(b.s, 1)
	var tc := b.c("timber")
	for k in 4:
		var a := k * PI * 0.5
		var dir := Vector3(cos(a), sin(a), 0)
		var perp := Vector3(-sin(a), cos(a), 0)
		bb.beam(Vector3.ZERO, dir * 5.5, 0.1, tc)
		bb.box(dir * 3.4 + perp * 0.5, Vector3(0.9, 0.9, 0.04) + Vector3(absf(dir.x), absf(dir.y), 0) * 3.4, b.c("cloth2"), 0.0)
	bb.cyl(Vector3(0, 0, -0.2), 0.35, 0.35, 0.0, tc)
	var blades := bb.build("Blades")
	blades.position = Vector3(0, 7.6, 2.55)
	blades.add_to_group("spin")
	b.children.append(blades)


static func _barn(b: B) -> void:
	var w := 8.0
	var d := 11.0
	var h := 3.4
	var red := Color("8a3a2a") if not b.s["snow"] else b.c("wall")
	_hall(b, w, d, h, 0.0, 3.0, 2.7, "open", 0.0, -1.0, red.to_html(false), Color("ffc080"))
	b.in_roof = true
	var save := b.xf
	b.xf = b.xf * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3.ZERO)
	b.gable(Vector3(0, h, 0), d + 0.8, w + 1.2, 3.4, b.c("roof2"), red)
	b.xf = save
	b.in_roof = false
	var tc := b.c("wall") if not b.s["snow"] else b.c("timber")
	# white X bracing and a loft window above the big doors
	for x in [-1.9, 1.9]:
		b.beam(Vector3(x - 0.45, 0.2, d * 0.5 + 0.08), Vector3(x + 0.45, 2.6, d * 0.5 + 0.08), 0.07, tc)
		b.beam(Vector3(x + 0.45, 0.2, d * 0.5 + 0.08), Vector3(x - 0.45, 2.6, d * 0.5 + 0.08), 0.07, tc)
	b.box(Vector3(0, 4.6, d * 0.5 + 0.05), Vector3(1.2, 1.0, 0.06), Color("1a1420"))
	_haybale_at(b, Vector3(-3.9, 0, d * 0.5 + 1.1), 0.3)
	_haybale_at(b, Vector3(-3.3, 0, d * 0.5 + 2.3), -0.2)
	# inside: hay, crates, a cart
	for k in 3:
		_haybale_at(b, Vector3(-2.6, 0, -d * 0.5 + 1.0 + k * 1.1), 0.1 * k)
	_crate(b, Vector3(2.8, 0, -d * 0.5 + 0.9), 0.9, 0.2)
	_crate(b, Vector3(2.8, 0, -d * 0.5 + 1.9), 0.8, -0.3)
	_crate(b, Vector3(2.8, 0.8, -d * 0.5 + 1.0), 0.7, 0.1)


static func _stilt_hut(b: B) -> void:
	var tc := b.c("timber")
	var up := 1.6
	for x in [-1, 1]:
		for z in [-1, 1]:
			b.box(Vector3(x * 1.7, up * 0.5 - 0.3, z * 1.5), Vector3(0.22, up + 0.6, 0.22), tc)
	b.box(Vector3(0, up, 0.4), Vector3(4.4, 0.18, 4.4), tc.lightened(0.12))
	b.solid(Vector3(0, up * 0.5, 0.4), Vector3(4.4, up, 4.4))
	var save := b.xf
	b.xf = b.xf * Transform3D(Basis.IDENTITY, Vector3(0, up, -0.3))
	_walls(b, 3.6, 3.0, 2.2, false)
	b.xf = save
	b.gable(Vector3(0, up + 2.2, -0.3), 4.6, 4.2, 2.0, b.c("roof"), b.c("wall2"))
	b.door(Vector3(0, up, 1.2), 0.8, 1.6, Vector3.BACK)
	b.window(Vector3(1.8, up + 1.3, -0.3), 0.5, 0.5, Vector3.RIGHT)
	# ladder and a lantern
	for x in [-0.25, 0.25]:
		b.beam(Vector3(x, 0, 3.2), Vector3(x, up + 0.1, 2.6), 0.05, tc)
	for k in 3:
		b.box(Vector3(0, 0.45 + k * 0.5, 3.2 - (k + 1) * 0.15), Vector3(0.55, 0.05, 0.05), tc)
	b.box(Vector3(1.9, up + 1.0, 2.4), Vector3(0.2, 0.28, 0.2), Color("b8f070"), 0.0, true)
	b.light(Vector3(1.9, up + 1.0, 2.6), Color("b8f070"), 4.0)


static func _lodge(b: B) -> void:
	var w := 7.0
	var d := 5.5
	var h := 3.0
	_hall(b, w, d, h, 0.0, 1.2, 2.1, _door_mode(b, 0.7, 0.2), 0.0, -1.0, "stone", Color("ffb870"))
	for y in [0.8, 1.6, 2.4]:
		b.box(Vector3(0, y, d * 0.5 + 0.03), Vector3(w, 0.06, 0.04), b.c("stone").darkened(0.2))
	_roof(b, Vector3(0, h, 0), w + 1.0, d + 1.2, 2.0)
	for x in [-2.2, 2.2]:
		b.window(Vector3(x, 1.6, d * 0.5), 0.8, 0.7, Vector3.BACK)
	_chimney(b, Vector3(w * 0.32, h, 0.0), 3.4)
	_firewood_at(b, Vector3(-w * 0.5 - 0.6, 0, 0.5), PI * 0.5)
	_hearth(b, Vector3(w * 0.22, 0, -d * 0.5 + 0.65))
	_bed(b, Vector3(-w * 0.5 + 0.95, 0, -d * 0.5 + 1.3))
	_table(b, Vector3(-1.9, 0, 0.3), 1.4, 0.9)
	_stool(b, Vector3(-1.9, 0, 1.2))
	_stool(b, Vector3(-2.95, 0, 0.3))
	_carpet(b, Vector3(-1.9, 0, 0.3), 2.0, 1.6, b.c("cloth"))


# ---------------------------------------------------------------- zone houses
## Campwater / Tallowfields: a low farmhouse with an open cart shed built onto the side.
static func _farmhouse(b: B) -> void:
	var w := 5.6
	var d := 4.2
	var h := 2.4
	_hall(b, w, d, h, -w * 0.2, 0.95, 1.85, _door_mode(b))
	_roof(b, Vector3(0, h, 0), w + 0.8, d + 0.9, 1.7)
	b.window(Vector3(w * 0.28, 1.5, d * 0.5), 0.7, 0.6, Vector3.BACK)
	b.window(Vector3(-w * 0.5, 1.5, 0), 0.6, 0.6, Vector3.LEFT)
	# hay-loft hatch in the gable and a pulley beam
	b.box(Vector3(w * 0.5 + 0.02, h + 0.7, 0), Vector3(0.06, 0.7, 0.7), Color("1a1420"))
	b.beam(Vector3(w * 0.5 + 0.2, h + 1.5, 0), Vector3(w * 0.5 + 1.0, h + 1.5, 0), 0.12, b.c("timber"))
	# cart shed
	var sx := w * 0.5 + 1.9
	var tc := b.c("timber")
	for px in [-1, 1]:
		for pz in [-1, 1]:
			b.box(Vector3(sx + px * 1.4, 1.1, pz * 1.5), Vector3(0.2, 2.2, 0.2), tc)
			b.solid(Vector3(sx + px * 1.4, 1.1, pz * 1.5), Vector3(0.3, 2.2, 0.3))
	b.in_roof = true
	b.gable(Vector3(sx, 2.2, 0), 3.8, 3.8, 0.9, b.c("roof2"), b.c("wall2"))
	b.in_roof = false
	b.box(Vector3(sx, 0.05, 0), Vector3(3.0, 0.1, 3.0), Color(b.s["ground"]).darkened(0.1))
	_haybale_at(b, Vector3(sx + 0.7, 0, -0.8), 0.2)
	_haybale_at(b, Vector3(sx + 0.9, 0.5, -0.7), 0.5, 0.8)
	var sv := b.xf
	b.xf = b.xf * Transform3D(Basis(Vector3.UP, 0.3).scaled(Vector3(0.8, 0.8, 0.8)), Vector3(sx - 0.4, 0, 0.5))
	_cart(b)
	b.xf = sv
	if b.rng.randf() < 0.8:
		_chimney(b, Vector3(-w * 0.3, h, -0.5), 2.4)
	_bed(b, Vector3(-w * 0.5 + 0.95, 0, -d * 0.5 + 1.3))
	_hearth(b, Vector3(w * 0.2, 0, -d * 0.5 + 0.65))
	_table(b, Vector3(w * 0.15, 0, 0.5), 1.2, 0.8)
	_stool(b, Vector3(w * 0.15 - 0.9, 0, 0.5))
	_carpet(b, Vector3(0, 0, 0.2), 1.6, 1.2, b.c("cloth"))


## A small store-house on staddle stones, with a ladder. No interior.
static func _granary(b: B) -> void:
	var tc := b.c("timber")
	for x in [-1, 1]:
		for z in [-1, 1]:
			b.cyl(Vector3(x * 1.1, 0, z * 0.9), 0.3, 0.2, 0.8, b.c("stone"), 6)
	b.box(Vector3(0, 0.88, 0), Vector3(2.8, 0.16, 2.4), tc)
	b.box(Vector3(0, 1.95, 0), Vector3(2.5, 2.0, 2.1), b.c("wall2"))
	for x in [-1, 1]:
		for z in [-1, 1]:
			b.box(Vector3(x * 1.25, 1.95, z * 1.05), Vector3(0.18, 2.0, 0.18), tc)
	b.solid(Vector3(0, 1.0, 0), Vector3(2.8, 2.9, 2.4))
	_roof(b, Vector3(0, 2.95, 0), 3.4, 3.0, 1.5)
	b.box(Vector3(0, 1.7, 1.06), Vector3(0.8, 1.2, 0.08), b.c("door"))
	for x in [-0.2, 0.2]:
		b.beam(Vector3(x, 0, 2.3), Vector3(x, 1.0, 1.4), 0.06, tc)
	for k in 3:
		b.box(Vector3(0, 0.25 + k * 0.28, 2.1 - k * 0.24), Vector3(0.5, 0.05, 0.05), tc)
	_barrel(b, Vector3(-1.9, 0, 1.0))


## Coast (Campwater): whitewashed fisher's cottage with an upturned boat and a drying rack.
static func _fisher_cottage(b: B) -> void:
	var w := 4.6
	var d := 3.8
	var h := 2.3
	_hall(b, w, d, h, -w * 0.2, 0.95, 1.85, _door_mode(b))
	_roof(b, Vector3(0, h, 0), w + 0.8, d + 0.9, 1.4)
	b.window(Vector3(w * 0.25, 1.5, d * 0.5), 0.7, 0.6, Vector3.BACK)
	b.window(Vector3(-w * 0.5, 1.5, 0), 0.6, 0.6, Vector3.LEFT)
	_chimney(b, Vector3(w * 0.3, h, -0.5), 2.2)
	# upturned boat leaning on the side
	var tc := b.c("timber")
	var bx := w * 0.5 + 1.2
	b.box(Vector3(bx, 0.55, 0.0), Vector3(1.6, 0.9, 3.6), tc.lightened(0.1), 0.0, false, 0.0, 0.0)
	b.box(Vector3(bx, 0.95, 0.0), Vector3(1.0, 0.3, 3.0), tc.darkened(0.1))
	b.box(Vector3(bx, 0.2, 1.9), Vector3(1.0, 0.4, 0.4), tc.lightened(0.1))
	b.box(Vector3(bx, 0.2, -1.9), Vector3(1.0, 0.4, 0.4), tc.lightened(0.1))
	b.solid(Vector3(bx, 0.6, 0), Vector3(1.6, 1.2, 3.8))
	# net rack
	for z in [-1.0, 1.0]:
		b.beam(Vector3(-w * 0.5 - 1.6, 0, z + 0.8), Vector3(-w * 0.5 - 1.6, 2.0, z + 0.8), 0.1, tc)
	b.beam(Vector3(-w * 0.5 - 1.6, 1.9, -0.2), Vector3(-w * 0.5 - 1.6, 1.9, 1.8), 0.08, tc)
	b.box(Vector3(-w * 0.5 - 1.6, 1.2, 0.8), Vector3(0.04, 1.3, 1.9), b.c("cloth2").darkened(0.3))
	b.box(Vector3(-w * 0.5 - 0.9, 0.25, -1.2), Vector3(0.5, 0.5, 0.5), tc.lightened(0.15))
	_bed(b, Vector3(-w * 0.5 + 0.95, 0, -d * 0.5 + 1.2))
	_hearth(b, Vector3(w * 0.25, 0, -d * 0.5 + 0.65))
	_table(b, Vector3(w * 0.2, 0, 0.5), 1.0, 0.8)
	_stool(b, Vector3(w * 0.2 - 0.8, 0, 0.5))


## Hearthmoor: a tall narrow townhouse, stone below and a timbered floor jutting out above.
static func _townhouse(b: B) -> void:
	var w := 7.4
	var d := 6.6
	var fy := 3.0
	var h2 := 2.7
	_hall(b, w, d, fy, 0.5, 1.2, 2.0, _door_mode(b, 0.7, 0.2), 0.0, -1.0, "stone")
	_storey(b, w, d, 0.0, fy, h2, -1.0, 4.6)
	var tc := b.c("timber")
	_roof(b, Vector3(0, fy + h2, 0), w + 1.2, d + 1.4, 2.0)
	for x in [-w * 0.3, w * 0.3]:
		b.window(Vector3(x, 1.6, d * 0.5), 0.8, 0.7, Vector3.BACK)
	_up_on(b)
	for x in [-w * 0.3, 0.0, w * 0.3]:
		b.window(Vector3(x, 1.5, d * 0.5), 0.8, 0.8, Vector3.BACK)
		_flowerbox(b, Vector3(x, 1.05, d * 0.5 + 0.2), 0.0)
	b.window(Vector3(w * 0.5, 1.5, 0), 0.7, 0.8, Vector3.RIGHT)
	b.window(Vector3(-w * 0.5, 1.5, 0), 0.7, 0.8, Vector3.LEFT)
	# upstairs: two beds, chests, a table
	_bed(b, Vector3(w * 0.5 - 1.0, 0, -d * 0.5 + 1.45))
	_bed(b, Vector3(w * 0.5 - 2.3, 0, -d * 0.5 + 1.45))
	_chest(b, Vector3(-0.2, 0, -d * 0.5 + 0.6))
	_table(b, Vector3(1.6, 0, 1.0), 1.4, 0.9)
	_stool(b, Vector3(1.6, 0, 1.9))
	_shelf_side(b, w, 1.0, 1.2, 1.6)
	_carpet(b, Vector3(0.8, 0, 0.2), 2.4, 2.0, b.c("cloth"))
	_up_off(b)
	_chimney(b, Vector3(w * 0.3, fy + h2, -1.2), 2.4)
	# hanging sign
	b.beam(Vector3(w * 0.5 + 0.1, 2.5, d * 0.5 + 0.2), Vector3(w * 0.5 + 1.1, 2.5, d * 0.5 + 0.2), 0.07, tc)
	b.box(Vector3(w * 0.5 + 0.9, 2.1, d * 0.5 + 0.2), Vector3(0.6, 0.5, 0.05), b.c("trim"))
	# downstairs: kitchen hearth, table, shelves, a bench; clear from the door to the stairs
	_hearth(b, Vector3(w * 0.22, 0, -d * 0.5 + 0.65))
	_table(b, Vector3(1.4, 0, -0.4), 1.6, 1.0)
	_stool(b, Vector3(0.3, 0, -0.4))
	_stool(b, Vector3(2.5, 0, -0.4))
	_stool(b, Vector3(1.4, 0, 0.55))
	_shelf_side(b, w, 1.0, 1.2, 1.8)
	_barrel(b, Vector3(w * 0.5 - 0.8, 0, 2.4))
	_carpet(b, Vector3(1.0, 0, 1.4), 2.4, 1.6, b.c("cloth"))


## Blackbriar / Brackenwood: a log cabin with a covered porch, steep roof and corner log-ends.
static func _log_cabin(b: B) -> void:
	var w := 5.4
	var d := 4.2
	var h := 2.5
	_hall(b, w, d, h, -w * 0.18, 0.95, 1.9, _door_mode(b), 0.0, -1.0, "wall2")
	var lc := b.c("timber").lightened(0.1)
	for y in [0.55, 0.95, 1.35, 1.75, 2.15]:
		b.box(Vector3(0, y, d * 0.5 + 0.03), Vector3(w + 0.1, 0.07, 0.05), lc.darkened(0.25))
		b.box(Vector3(0, y, -d * 0.5 - 0.03), Vector3(w + 0.1, 0.07, 0.05), lc.darkened(0.25))
		b.box(Vector3(w * 0.5 + 0.03, y, 0), Vector3(0.05, 0.07, d), lc.darkened(0.25))
		b.box(Vector3(-w * 0.5 - 0.03, y, 0), Vector3(0.05, 0.07, d), lc.darkened(0.25))
	# log ends sticking out at the corners
	for y in [0.7, 1.1, 1.5, 1.9, 2.3]:
		for sx in [-1, 1]:
			b.box(Vector3(sx * (w * 0.5 + 0.12), y, d * 0.5 + 0.12), Vector3(0.3, 0.3, 0.3), lc)
	_roof(b, Vector3(0, h, 0), w + 1.2, d + 1.2, 2.5)
	# porch
	var tc := b.c("timber")
	var pz := d * 0.5 + 1.1
	for x in [-1, 1]:
		b.box(Vector3(-w * 0.18 + x * 1.5, 1.2, pz), Vector3(0.22, 2.4, 0.22), tc)
		b.solid(Vector3(-w * 0.18 + x * 1.5, 1.2, pz), Vector3(0.3, 2.4, 0.3))
	b.box(Vector3(-w * 0.18, 2.5, d * 0.5 + 0.55), Vector3(3.8, 0.18, 1.7), tc.darkened(0.1), 0.0, false, 0.18)
	b.box(Vector3(-w * 0.18, 0.06, pz - 0.2), Vector3(3.2, 0.12, 1.8), tc.lightened(0.1))
	b.window(Vector3(w * 0.28, 1.5, d * 0.5), 0.7, 0.6, Vector3.BACK)
	b.window(Vector3(w * 0.5, 1.5, 0), 0.6, 0.6, Vector3.RIGHT)
	_chimney(b, Vector3(-w * 0.35, h, -0.8), 3.0)
	_firewood_at(b, Vector3(w * 0.5 + 0.7, 0, 0.8), PI * 0.5)
	_bed(b, Vector3(w * 0.5 - 0.95, 0, -d * 0.5 + 1.3))
	_hearth(b, Vector3(-w * 0.25, 0, -d * 0.5 + 0.65))
	_table(b, Vector3(0.5, 0, 0.6), 1.1, 0.8)
	_stool(b, Vector3(0.5, 0, 1.4))
	_stool(b, Vector3(1.5, 0, 0.6))
	_carpet(b, Vector3(0.5, 0, 0.4), 1.6, 1.2, b.c("cloth"))


## Greyfold Downs: a low dry-stone hut roofed in turf, held down with stones, with a peat stack.
static func _turf_hut(b: B) -> void:
	var w := 4.6
	var d := 3.8
	var h := 1.9
	_hall(b, w, d, h, -w * 0.15, 0.9, 1.7, _door_mode(b), 0.0, -1.0, "stone")
	for y in [0.5, 0.9, 1.3, 1.7]:
		b.box(Vector3(0, y, d * 0.5 + 0.03), Vector3(w, 0.05, 0.04), b.c("stone").darkened(0.25))
	b.in_roof = true
	var turf := Color("6a8a46")
	turf.a = 0.25
	b.gable(Vector3(0, h, 0), w + 0.9, d + 0.9, 1.2, turf, b.c("stone"))
	for k in 6:
		var sxp := -1.8 + k * 0.7
		var zz := 0.75 if k % 2 == 0 else -0.75
		b.box(Vector3(sxp, h + 0.6 - 0.0, zz * 0.9), Vector3(0.4, 0.22, 0.4), b.c("stone"), float(k))
	b.in_roof = false
	b.box(Vector3(0, h + 1.15, 0), Vector3(w + 0.9, 0.12, 0.2), turf.darkened(0.15))
	b.window(Vector3(w * 0.28, 1.2, d * 0.5), 0.5, 0.45, Vector3.BACK)
	# smoke hole chimney and a peat stack
	_chimney(b, Vector3(w * 0.25, h + 0.4, -0.5), 1.5)
	var pc := Color("3a2c22")
	for k in 6:
		b.box(Vector3(w * 0.5 + 0.6, 0.15 + (k / 3) * 0.3, -0.6 + (k % 3) * 0.5), Vector3(0.5, 0.28, 0.4), pc)
	b.solid(Vector3(w * 0.5 + 0.6, 0.3, -0.1), Vector3(0.6, 0.6, 1.5))
	_bed(b, Vector3(-w * 0.5 + 0.95, 0, -d * 0.5 + 1.2))
	_hearth(b, Vector3(w * 0.25, 0, -d * 0.5 + 0.65))
	_stool(b, Vector3(0.3, 0, 0.3))
	_carpet(b, Vector3(0, 0, 0.2), 1.4, 1.0, b.c("cloth"))


## Saltfen: a mud-and-reed hut on a raised timber base (the stilt huts sit over water, this one on peat).
static func _reed_hut(b: B) -> void:
	var w := 4.2
	var d := 3.8
	var h := 2.0
	var tc := b.c("timber")
	b.box(Vector3(0, 0.12, 0.2), Vector3(w + 1.2, 0.24, d + 1.6), tc.lightened(0.08))
	b.solid(Vector3(0, 0.12, 0.2), Vector3(w + 1.2, 0.24, d + 1.6))
	var save := b.xf
	b.xf = b.xf * Transform3D(Basis.IDENTITY, Vector3(0, 0.24, 0))
	_hall(b, w, d, h, 0.0, 0.9, 1.75, _door_mode(b))
	b.xf = save
	var reed := b.c("roof")
	b.in_roof = true
	b.gable(Vector3(0, h + 0.24, 0), w + 1.0, d + 1.0, 2.6, reed, b.c("wall2"))
	b.gable(Vector3(0, h + 0.24, 0), w + 1.3, d + 1.3, 2.2, reed.darkened(0.12), b.c("wall2"))
	b.in_roof = false
	b.window(Vector3(w * 0.5, 1.5, 0), 0.5, 0.5, Vector3.RIGHT)
	# ridge poles crossing, hanging eel traps and a lantern
	b.beam(Vector3(-w * 0.5 - 0.5, h + 2.9, 0), Vector3(-w * 0.5 - 0.1, h + 2.3, 0), 0.08, tc)
	b.beam(Vector3(w * 0.5 + 0.5, h + 2.9, 0), Vector3(w * 0.5 + 0.1, h + 2.3, 0), 0.08, tc)
	b.box(Vector3(-w * 0.5 - 0.5, 0.65, 1.0), Vector3(0.35, 0.8, 0.35), tc.darkened(0.1))
	b.box(Vector3(-w * 0.5 - 0.5, 0.45, 0.3), Vector3(0.35, 0.8, 0.35), tc.darkened(0.1))
	b.box(Vector3(0.9, 1.9, d * 0.5 + 0.7), Vector3(0.2, 0.28, 0.2), Color("b8f070"), 0.0, true)
	b.beam(Vector3(0.9, 0.0, d * 0.5 + 0.7), Vector3(0.9, 2.0, d * 0.5 + 0.7), 0.07, tc)
	b.light(Vector3(0.9, 1.9, d * 0.5 + 0.9), Color("b8f070"), 4.0)
	_bed(b, Vector3(-w * 0.5 + 0.95, 0.24, -d * 0.5 + 1.2))
	_hearth(b, Vector3(w * 0.22, 0.24, -d * 0.5 + 0.65))
	_stool(b, Vector3(1.0, 0.24, 0.4))


## Bellwater: a shack built out of a wrecked ship's hull, with a stump of mast and a torn sail.
static func _wreck_shack(b: B) -> void:
	var w := 5.0
	var d := 3.8
	var h := 2.2
	_hall(b, w, d, h, -w * 0.2, 0.9, 1.75, _door_mode(b))
	var tc := b.c("timber")
	b.in_roof = true
	b.gable(Vector3(0, h, 0), w + 0.8, d + 0.8, 0.9, b.c("roof"), b.c("wall2"))
	b.in_roof = false
	# hull ribs along the back wall rising above the roofline
	for k in 6:
		var x := -w * 0.5 + 0.5 + k * (w - 1.0) / 5.0
		b.beam(Vector3(x, 0.0, -d * 0.5 - 0.2), Vector3(x, h + 0.2, -d * 0.5 - 0.7), 0.16, tc.darkened(0.15))
	b.beam(Vector3(-w * 0.5 + 0.5, 1.0, -d * 0.5 - 0.45), Vector3(w * 0.5 - 0.5, 1.0, -d * 0.5 - 0.45), 0.12, tc.darkened(0.15))
	# mast and sail
	b.beam(Vector3(w * 0.5 + 0.6, 0, 0.6), Vector3(w * 0.5 + 0.5, 4.6, 0.6), 0.2, tc)
	b.solid(Vector3(w * 0.5 + 0.6, 1.0, 0.6), Vector3(0.4, 2.0, 0.4))
	b.beam(Vector3(w * 0.5 + 0.5, 4.0, -0.4), Vector3(w * 0.5 + 0.5, 4.0, 1.6), 0.12, tc)
	var sail := b.c("cloth2").darkened(0.15)
	b.box(Vector3(w * 0.5 + 0.5, 3.2, 0.7), Vector3(0.04, 1.6, 1.3), sail, 0.0, false, 0.0, 0.08)
	b.window(Vector3(w * 0.28, 1.5, d * 0.5), 0.5, 0.5, Vector3.BACK)
	b.window(Vector3(-w * 0.5, 1.5, 0), 0.5, 0.5, Vector3.LEFT)
	_barrel(b, Vector3(-w * 0.5 - 0.8, 0, 1.0))
	_crate(b, Vector3(-w * 0.5 - 0.8, 0, -0.3), 0.7, 0.3)
	_bed(b, Vector3(w * 0.5 - 0.95, 0, -d * 0.5 + 1.2))
	_hearth(b, Vector3(-w * 0.1, 0, -d * 0.5 + 0.65))
	_table(b, Vector3(0.6, 0, 0.95), 1.1, 0.8)
	_stool(b, Vector3(0.0, 0, 1.55))


## Frostspine: a stone-based chalet with a jutting timber upper floor and a balcony.
static func _chalet(b: B) -> void:
	var w := 5.4
	var d := 4.4
	var h := 2.5
	_hall(b, w, d, h, 0.0, 1.0, 1.95, _door_mode(b, 0.7, 0.2), 0.0, -1.0, "stone")
	var tc := b.c("timber")
	b.box(Vector3(0, h + 1.0, -0.2), Vector3(w + 0.2, 2.0, d - 0.4), b.c("wall2"))
	b.solid(Vector3(0, h + 1.0, -0.2), Vector3(w + 0.2, 2.0, d - 0.4))
	for x in [-1, 1]:
		b.box(Vector3(x * (w * 0.5 + 0.1), h + 1.0, d * 0.5 - 0.4), Vector3(0.22, 2.0, 0.22), tc)
	for k in 4:
		b.box(Vector3(-2.0 + k * 1.33, h + 1.0, d * 0.5 - 0.38), Vector3(0.1, 2.0, 0.06), tc.lightened(0.1))
	# balcony over the door
	b.box(Vector3(0, h + 0.06, d * 0.5 + 0.5), Vector3(w * 0.7, 0.14, 1.2), tc.lightened(0.1))
	for x in [-1, 1]:
		b.box(Vector3(x * w * 0.35, h + 0.45, d * 0.5 + 1.05), Vector3(0.1, 0.8, 0.1), tc)
	b.box(Vector3(0, h + 0.85, d * 0.5 + 1.05), Vector3(w * 0.7, 0.08, 0.08), tc)
	b.box(Vector3(0, h + 0.5, d * 0.5 + 1.05), Vector3(w * 0.7, 0.05, 0.05), tc)
	for x in [-1.2, 1.2]:
		b.window(Vector3(x, h + 1.1, d * 0.5 - 0.35), 0.6, 0.8, Vector3.BACK)
		b.window(Vector3(x, 1.6, d * 0.5), 0.6, 0.6, Vector3.BACK)
	_roof(b, Vector3(0, h + 2.0, -0.2), w + 1.6, d + 1.2, 2.6)
	_chimney(b, Vector3(w * 0.3, h + 2.0, -1.0), 2.6)
	_hearth(b, Vector3(w * 0.22, 0, -d * 0.5 + 0.65))
	_bed(b, Vector3(-w * 0.5 + 0.95, 0, -d * 0.5 + 1.3))
	_table(b, Vector3(1.1, 0, 0.3), 1.3, 0.9)
	_stool(b, Vector3(1.1, 0, 1.2))
	_stool(b, Vector3(2.0, 0, 0.3))
	_firewood_at(b, Vector3(-w * 0.5 - 0.6, 0, 0.5), PI * 0.5)
	_carpet(b, Vector3(1.1, 0, 0.3), 1.8, 1.4, b.c("cloth"))


## The castle keep: a big square hall with corner turrets, a throne at the back and a long table.
static func _keep(b: B) -> void:
	var w := 12.0
	var d := 12.0
	var h := 6.0
	_hall(b, w, d, h, 0.0, 2.4, 3.2, "auto", 0.0, -1.0, "stone", Color("ffc890"))
	var sc := b.c("stone")
	for k in [-1.0, 1.0]:
		b.box(Vector3(k * 3.4, 4.1, d * 0.5 + 0.05), Vector3(0.5, 4.4, 0.2), sc.darkened(0.12))   # buttresses by the door
	b.in_roof = true
	b.box(Vector3(0, h + 0.15, 0), Vector3(w + 0.8, 0.3, d + 0.8), sc.darkened(0.1))
	for i in 10:
		var x := -w * 0.5 + 0.5 + i * (w - 0.6) / 9.0
		for z in [-1, 1]:
			b.box(Vector3(x, h + 0.7, z * (d * 0.5 + 0.2)), Vector3(0.7, 0.8, 0.5), sc)
		for sx in [-1, 1]:
			if i > 0 and i < 9:
				b.box(Vector3(sx * (w * 0.5 + 0.2), h + 0.7, -d * 0.5 + 0.5 + i * (d - 0.6) / 9.0), Vector3(0.5, 0.8, 0.7), sc)
	b.in_roof = false
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			var tp := Vector3(sx * w * 0.5, 0, sz * d * 0.5)
			b.cyl(tp, 1.5, 1.35, h + 3.0, sc.lightened(0.05), 8)
			b.solid(tp + Vector3(0, (h + 3.0) * 0.5, 0), Vector3(2.8, h + 3.0, 2.8))
			b.cone(tp + Vector3(0, h + 3.0, 0), 1.9, 2.6, b.c("roof"), 8)
			if sz > 0:
				b.window(tp + Vector3(0, 4.2, 1.35), 0.35, 0.7, Vector3.BACK)
			_banner_at(b, tp + Vector3(0, h + 5.4, 0), 1.2)
	for x in [-3.0, 3.0]:
		b.window(Vector3(x, 3.6, d * 0.5), 0.7, 1.2, Vector3.BACK)
	# inside: red carpet from the door to a throne, long tables, torches
	_carpet(b, Vector3(0, 0, 0.0), 2.4, d - 1.0, Color("8a2a3a"))
	var tz := -d * 0.5 + 1.2
	b.piece("throne", Vector3(0, 0, tz), 0.0, func() -> void:
		b.box(Vector3(0, 0.2, tz), Vector3(4.0, 0.4, 2.0), sc.darkened(0.1))
		b.box(Vector3(0, 0.75, tz - 0.2), Vector3(1.1, 0.7, 0.9), b.c("timber"))
		b.box(Vector3(0, 1.6, tz - 0.55), Vector3(1.1, 1.8, 0.2), b.c("timber").darkened(0.1))
		b.box(Vector3(0, 1.0, tz - 0.1), Vector3(0.9, 0.12, 0.7), b.c("cloth"))
		b.solid(Vector3(0, 0.8, tz), Vector3(4.0, 1.6, 2.0)))
	for sx in [-1, 1]:
		_table(b, Vector3(sx * 3.4, 0, 0.5), 1.1, 5.0)
		for k in 3:
			_stool(b, Vector3(sx * 2.4, 0, -0.8 + k * 1.6))
			_stool(b, Vector3(sx * 4.4, 0, -0.8 + k * 1.6))
		_torch(b, Vector3(sx * (w * 0.5 - 0.5), 2.4, -1.5))
		_torch(b, Vector3(sx * (w * 0.5 - 0.5), 2.4, 2.5))
		_banner_at(b, Vector3(sx * 1.8, 5.2, -d * 0.5 + 0.5), 2.4)


# ================================================================ walls & defenses
static func _palisade(b: B, length: float) -> void:
	var tc := b.c("timber").lightened(0.15)
	var n := maxi(2, int(length / 0.55))
	for i in n:
		var x := -length * 0.5 + (i + 0.5) * length / n
		var hh := 3.0 + b.rng.randf_range(-0.25, 0.25)
		b.cyl(Vector3(x, 0, 0), 0.27, 0.25, hh, tc.darkened(b.rng.randf() * 0.15), 6)
		b.cone(Vector3(x, hh, 0), 0.25, 0.55, tc.darkened(0.1), 6)
	b.box(Vector3(0, 2.2, -0.3), Vector3(length, 0.2, 0.12), b.c("timber"))
	b.box(Vector3(0, 0.9, -0.3), Vector3(length, 0.2, 0.12), b.c("timber"))
	b.solid(Vector3(0, 1.6, 0), Vector3(length, 3.2, 0.6))


static func _stone_wall(b: B, length: float) -> void:
	var sc := b.c("stone")
	b.box(Vector3(0, 1.4, 0), Vector3(length, 2.8, 1.0), sc)
	b.box(Vector3(0, 0.3, 0), Vector3(length + 0.1, 0.6, 1.2), sc.darkened(0.15))
	var n := maxi(2, int(length / 1.2))
	for i in n:
		if i % 2 == 0:
			b.box(Vector3(-length * 0.5 + (i + 0.5) * length / n, 3.05, 0), Vector3(length / n, 0.5, 1.0), sc.lightened(0.05))
	if b.s["snow"]:
		b.box(Vector3(0, 2.83, 0), Vector3(length, 0.06, 1.02), Color("eef4fa"))
	b.solid(Vector3(0, 1.6, 0), Vector3(length, 3.2, 1.0))


static func _fence(b: B, length: float) -> void:
	var tc := b.c("timber").lightened(0.2)
	var n := maxi(1, int(length / 2.0))
	for i in n + 1:
		var x := -length * 0.5 + i * length / n
		b.box(Vector3(x, 0.55, 0), Vector3(0.14, 1.1, 0.14), tc)
	for y in [0.45, 0.85]:
		b.box(Vector3(0, y, 0.06), Vector3(length, 0.1, 0.05), tc.darkened(0.1), 0.0, false, 0.0, b.rng.randf_range(-0.02, 0.02))
	b.solid(Vector3(0, 0.6, 0), Vector3(length, 1.2, 0.3))


static func _gatehouse(b: B) -> void:
	var stone_style: bool = b.s["fence"] == "stone"
	var sc := b.c("stone") if stone_style else b.c("timber").lightened(0.1)
	for x in [-1, 1]:
		b.box(Vector3(x * 3.0, 2.6, 0), Vector3(2.0, 5.2, 2.0), sc)
		b.solid(Vector3(x * 3.0, 2.6, 0), Vector3(2.0, 5.2, 2.0))
		b.pyramid(Vector3(x * 3.0, 5.2, 0), 2.5, 2.5, 1.6, b.c("roof"))
		b.window(Vector3(x * 3.0, 3.8, 1.0), 0.4, 0.6, Vector3.BACK)
	b.box(Vector3(0, 4.6, 0), Vector3(4.2, 1.0, 1.6), sc.darkened(0.08))
	b.solid(Vector3(0, 4.6, 0), Vector3(4.2, 1.0, 1.6))
	# open doors swung back
	for x in [-1, 1]:
		b.box(Vector3(x * 1.85, 1.7, 1.0), Vector3(0.1, 3.4, 1.6), b.c("door"), x * 0.3)
	_banner_at(b, Vector3(-3.0, 5.2 + 1.6, 0), 1.4)
	_banner_at(b, Vector3(3.0, 5.2 + 1.6, 0), 1.4)
	for x in [-1.6, 1.6]:
		b.box(Vector3(x, 3.4, 1.0), Vector3(0.22, 0.3, 0.22), Color("ffcf7a"), 0.0, true)
	b.light(Vector3(0, 3.6, 1.6), Color("ffb060"), 6.0)


static func _wall_tower(b: B) -> void:
	var stone_style: bool = b.s["fence"] == "stone"
	var sc := b.c("stone") if stone_style else b.c("timber").lightened(0.1)
	b.cyl(Vector3.ZERO, 1.7, 1.5, 5.0, sc, 8)
	b.solid(Vector3(0, 2.5, 0), Vector3(2.8, 5.0, 2.8))
	b.cone(Vector3(0, 5.0, 0), 2.0, 2.2, b.c("roof"), 8)
	b.window(Vector3(0, 3.4, 1.55), 0.35, 0.6, Vector3.BACK)


static func _castle_wall(b: B, length: float) -> void:
	var sc := b.c("stone")
	b.box(Vector3(0, 2.4, 0), Vector3(length, 4.8, 1.6), sc)
	b.box(Vector3(0, 0.45, 0), Vector3(length + 0.1, 0.9, 1.9), sc.darkened(0.15))
	b.box(Vector3(0, 4.85, 0), Vector3(length, 0.14, 1.9), sc.darkened(0.1))   # parapet ledge
	var n := maxi(2, int(length / 1.3))
	for i in n:
		if i % 2 == 0:
			b.box(Vector3(-length * 0.5 + (i + 0.5) * length / n, 5.35, 0.0), Vector3(length / n, 0.9, 1.8), sc.lightened(0.06))
	for i in maxi(1, int(length / 3.0)):
		b.box(Vector3(-length * 0.5 + (i + 0.5) * length / maxi(1, int(length / 3.0)), 3.0, 0.82), Vector3(0.14, 0.7, 0.06), Color("1a1420"))   # arrow slits
	b.solid(Vector3(0, 2.8, 0), Vector3(length, 5.6, 1.7))


static func _castle_tower(b: B) -> void:
	var sc := b.c("stone").lightened(0.04)
	b.cyl(Vector3.ZERO, 2.3, 2.0, 7.2, sc, 8)
	b.cyl(Vector3(0, 7.0, 0), 2.45, 2.45, 0.5, sc.darkened(0.1), 8)
	for i in 8:
		var a := TAU * i / 8.0
		b.box(Vector3(cos(a) * 2.3, 7.8, sin(a) * 2.3), Vector3(0.8, 0.8, 0.8), sc.lightened(0.06), -a)
	b.cone(Vector3(0, 7.5, 0), 2.0, 3.4, b.c("roof"), 8)
	for a in [0.0, 1.57, 3.14, 4.71]:
		b.box(Vector3(cos(a) * 2.05, 4.6, sin(a) * 2.05), Vector3(0.14, 0.8, 0.14), Color("1a1420"), -a)
	_banner_at(b, Vector3(0, 10.9, 0), 1.4)
	b.solid(Vector3(0, 3.8, 0), Vector3(3.8, 7.6, 3.8))


## Castle gate: two towers, an arch over the road and a pair of big doors propped open.
static func _castle_gate(b: B) -> void:
	var sc := b.c("stone")
	for x in [-1, 1]:
		var tp := Vector3(x * 4.2, 0, 0)
		b.cyl(tp, 2.2, 1.95, 8.0, sc.lightened(0.04), 8)
		b.cyl(tp + Vector3(0, 7.8, 0), 2.4, 2.4, 0.5, sc.darkened(0.1), 8)
		b.cone(tp + Vector3(0, 8.3, 0), 2.1, 3.6, b.c("roof"), 8)
		b.solid(tp + Vector3(0, 4.0, 0), Vector3(3.6, 8.0, 3.6))
		b.window(tp + Vector3(0, 5.2, 1.95), 0.4, 0.8, Vector3.BACK)
		_banner_at(b, tp + Vector3(0, 11.6, 0), 1.4)
	b.box(Vector3(0, 6.2, 0), Vector3(4.3, 3.2, 2.6), sc.darkened(0.06))
	b.solid(Vector3(0, 6.6, 0), Vector3(4.3, 2.4, 2.6))
	for i in 5:
		b.box(Vector3(-1.7 + i * 0.85, 8.15, 0.0), Vector3(0.6, 0.7, 2.6), sc.lightened(0.06))
	# portcullis, raised
	for k in 5:
		b.box(Vector3(-1.6 + k * 0.8, 4.35, 0.2), Vector3(0.08, 0.9, 0.08), Color("3a3a42"))
	b.box(Vector3(0, 4.6, 0.2), Vector3(4.0, 0.08, 0.1), Color("3a3a42"))
	for x in [-2.1, 2.1]:
		b.box(Vector3(x, 3.6, 1.6), Vector3(0.22, 0.3, 0.22), Color("ffcf7a"), 0.0, true)
	b.light(Vector3(0, 3.4, 1.8), Color("ffb060"), 7.0)
	# the two big doors, hinged at the towers and propped open
	b.doors.append([b.xf * Transform3D(Basis.IDENTITY, Vector3(-1.0, 0, 0.9)), 2.0, 3.6, "open", false])
	b.doors.append([b.xf * Transform3D(Basis.IDENTITY, Vector3(1.0, 0, 0.9)), 2.0, 3.6, "open", true])


# ================================================================ props
static func _well(b: B) -> void:
	b.cyl(Vector3.ZERO, 1.1, 1.1, 0.9, b.c("stone"), 8)
	b.cyl(Vector3(0, 0.88, 0), 0.85, 0.85, 0.02, Color("2a4a5a"), 8)
	b.solid(Vector3(0, 0.45, 0), Vector3(2.0, 0.9, 2.0))
	var tc := b.c("timber")
	for x in [-1, 1]:
		b.box(Vector3(x * 0.95, 1.5, 0), Vector3(0.16, 2.0, 0.16), tc)
	b.log_x(Vector3(0, 1.9, 0), 0.08, 1.9, tc)
	b.gable(Vector3(0, 2.45, 0), 2.4, 1.8, 0.8, b.c("roof"), tc)
	b.cyl(Vector3(0.1, 1.2, 0), 0.18, 0.2, 0.3, tc.lightened(0.2), 6)


static func _stall(b: B) -> void:
	var tc := b.c("timber")
	var cloth: Color = [Color("b8443a"), Color("3e6a8a"), Color("6a8a3a"), Color("a0603a")][b.rng.randi() % 4]
	b.box(Vector3(0, 0.45, 0), Vector3(2.4, 0.9, 0.9), tc)
	b.solid(Vector3(0, 0.45, 0), Vector3(2.4, 0.9, 0.9))
	b.box(Vector3(0, 0.93, 0), Vector3(2.6, 0.08, 1.0), b.c("cloth2"))
	for x in [-1.25, 1.25]:
		b.box(Vector3(x, 1.2, -0.5), Vector3(0.12, 2.4, 0.12), tc)
		b.box(Vector3(x, 1.05, 0.5), Vector3(0.12, 2.1, 0.12), tc)
	for k in 4:
		var col: Color = cloth if k % 2 == 0 else Color("e8dcc0")
		b.box(Vector3(-0.98 + k * 0.65, 2.2, 0), Vector3(0.66, 0.06, 1.3), col, 0.0, false, -0.3)
	# goods: produce or pots
	for k in 5:
		var gc: Color = [Color("d9483b"), Color("ffd27a"), Color("6ad050"), Color("c87a3a"), Color("9a6ae0")][b.rng.randi() % 5]
		b.box(Vector3(-0.9 + k * 0.45, 1.06, b.rng.randf_range(-0.2, 0.2)), Vector3(0.28, 0.18, 0.28), gc)


static func _lamp(b: B) -> void:
	var tc := Color("2a2430")
	b.box(Vector3(0, 1.5, 0), Vector3(0.14, 3.0, 0.14), tc)
	b.box(Vector3(0, 0.1, 0), Vector3(0.4, 0.2, 0.4), tc)
	b.box(Vector3(0.3, 2.95, 0), Vector3(0.6, 0.08, 0.08), tc)
	b.box(Vector3(0.55, 2.65, 0), Vector3(0.26, 0.36, 0.26), Color("ffcf7a"), 0.0, true)
	b.pyramid(Vector3(0.55, 2.83, 0), 0.36, 0.36, 0.18, tc)
	b.light(Vector3(0.55, 2.5, 0), Color("ffc070"), 7.0)
	b.solid(Vector3(0, 1.5, 0), Vector3(0.2, 3.0, 0.2))


static func _barrel(b: B, at: Vector3) -> void:
	b.prop("barrel", at, 0.0, func(p: Vector3) -> void: _barrel_geo(b, p))


static func _barrel_geo(b: B, at: Vector3) -> void:
	var tc := b.c("timber").lightened(0.15)
	b.cyl(at, 0.36, 0.4, 0.45, tc, 8)
	b.cyl(at + Vector3(0, 0.45, 0), 0.4, 0.36, 0.45, tc, 8)
	b.cyl(at + Vector3(0, 0.2, 0), 0.39, 0.39, 0.05, Color("4a4a52"), 8, false, false)
	b.cyl(at + Vector3(0, 0.7, 0), 0.39, 0.39, 0.05, Color("4a4a52"), 8, false, false)
	b.solid(at + Vector3(0, 0.45, 0), Vector3(0.7, 0.9, 0.7))


static func _crate(b: B, at: Vector3, s: float, yaw: float) -> void:
	b.prop("crate", at, yaw, func(p: Vector3) -> void: _crate_geo(b, p, s, 0.0))


static func _crate_geo(b: B, at: Vector3, s: float, yaw: float) -> void:
	var tc := b.c("timber").lightened(0.3)
	b.box(at + Vector3(0, s * 0.5, 0), Vector3(s, s, s), tc, yaw)
	b.box(at + Vector3(0, s * 0.5, 0), Vector3(s + 0.04, s * 0.18, s + 0.04), tc.darkened(0.2), yaw)
	b.solid(at + Vector3(0, s * 0.5, 0), Vector3(s, s, s), yaw)


static func _crates(b: B) -> void:
	_crate(b, Vector3(0, 0, 0), 0.9, 0.0)
	_crate(b, Vector3(1.0, 0, 0.1), 0.8, 0.3)
	_crate(b, Vector3(0.4, 0.9, 0.0), 0.7, -0.2)
	_barrel(b, Vector3(-0.9, 0, 0.3))


static func _cart(b: B) -> void:
	var tc := b.c("timber").lightened(0.1)
	b.box(Vector3(0, 0.9, 0), Vector3(2.4, 0.15, 1.4), tc)
	for z in [-0.7, 0.7]:
		b.box(Vector3(0, 1.2, z), Vector3(2.4, 0.5, 0.08), tc)
	b.box(Vector3(-1.2, 1.2, 0), Vector3(0.08, 0.5, 1.4), tc)
	for z in [-0.78, 0.78]:
		var save := b.xf
		b.xf = b.xf * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.2, 0.6, z))
		b.cyl(Vector3(0, -0.06, 0), 0.6, 0.6, 0.12, tc.darkened(0.25), 8)
		b.xf = save
	b.beam(Vector3(1.2, 0.9, -0.3), Vector3(2.8, 0.5, -0.3), 0.06, tc)
	b.beam(Vector3(1.2, 0.9, 0.3), Vector3(2.8, 0.5, 0.3), 0.06, tc)
	_haybale_at(b, Vector3(-0.2, 1.0, 0), 0.0, 0.55)
	b.solid(Vector3(0, 0.8, 0), Vector3(2.6, 1.6, 1.6))


static func _haybale(b: B) -> void:
	_haybale_at(b, Vector3.ZERO, 0.0)


static func _haybale_at(b: B, at: Vector3, yaw: float, s := 1.0) -> void:
	b.prop("haybale", at, yaw, func(p: Vector3) -> void: _haybale_at_geo(b, p, 0.0, s))


static func _haybale_at_geo(b: B, at: Vector3, yaw: float, s := 1.0) -> void:
	b.box(at + Vector3(0, 0.4 * s, 0), Vector3(1.2, 0.8, 0.8) * s, Color("d8b860"), yaw)
	b.box(at + Vector3(0, 0.4 * s, 0), Vector3(1.22, 0.06, 0.82) * s, Color("b08a40"), yaw)
	b.solid(at + Vector3(0, 0.4 * s, 0), Vector3(1.2, 0.8, 0.8) * s, yaw)


static func _signpost(b: B) -> void:
	var tc := b.c("timber").lightened(0.15)
	b.box(Vector3(0, 1.2, 0), Vector3(0.16, 2.4, 0.16), tc)
	for k in 3:
		var a: float = [0.4, -0.6, 2.4][k]
		b.box(Vector3(cos(a) * 0.45, 2.1 - k * 0.32, -sin(a) * 0.45), Vector3(1.0, 0.24, 0.06), tc.lightened(0.1), a)
	b.solid(Vector3(0, 1.2, 0), Vector3(0.2, 2.4, 0.2))


static func _bench(b: B) -> void:
	_bench_at(b, Vector3.ZERO, 0.0)


static func _bench_at(b: B, at: Vector3, yaw: float) -> void:
	b.prop("bench", at, yaw, func(p: Vector3) -> void: _bench_at_geo(b, p, 0.0))


static func _bench_at_geo(b: B, at: Vector3, yaw: float) -> void:
	var tc := b.c("timber").lightened(0.2)
	b.box(at + Vector3(0, 0.45, 0), Vector3(1.8, 0.1, 0.45), tc, yaw)
	for x in [-0.7, 0.7]:
		var off := Basis(Vector3.UP, yaw) * Vector3(x, 0, 0)
		b.box(at + off + Vector3(0, 0.22, 0), Vector3(0.12, 0.44, 0.4), tc.darkened(0.15), yaw)


static func _banner(b: B) -> void:
	b.box(Vector3(0, 2.0, 0), Vector3(0.1, 4.0, 0.1), b.c("timber"))
	_banner_at(b, Vector3(0, 4.0, 0), 1.8)
	b.solid(Vector3(0, 2.0, 0), Vector3(0.2, 4.0, 0.2))


static func _banner_at(b: B, top: Vector3, h: float) -> void:
	b.box(top + Vector3(0.45, -0.05, 0), Vector3(0.9, 0.06, 0.06), b.c("timber"))
	b.box(top + Vector3(0.45, -h * 0.5 - 0.1, 0), Vector3(0.75, h, 0.03), b.c("cloth"))
	b.box(top + Vector3(0.45, -h * 0.5 + 0.1, 0.02), Vector3(0.3, 0.3, 0.02), Color("d8b04a"))
	b.tri(top + Vector3(0.08, -h - 0.1, 0), top + Vector3(0.82, -h - 0.1, 0), top + Vector3(0.45, -h - 0.45, 0), b.c("cloth"))


static func _notice_board(b: B) -> void:
	var tc := b.c("timber")
	for x in [-0.9, 0.9]:
		b.box(Vector3(x, 1.1, 0), Vector3(0.14, 2.2, 0.14), tc)
	b.box(Vector3(0, 1.4, 0), Vector3(1.9, 1.1, 0.08), tc.lightened(0.2))
	b.gable(Vector3(0, 2.15, 0), 2.3, 0.6, 0.4, b.c("roof"), tc)
	for k in 4:
		b.box(Vector3(-0.6 + k * 0.4, 1.4 + b.rng.randf_range(-0.2, 0.2), 0.06), Vector3(0.3, 0.38, 0.02), Color("f1e8d4"), 0.0, false, 0.0, b.rng.randf_range(-0.15, 0.15))
	b.solid(Vector3(0, 1.1, 0), Vector3(2.0, 2.2, 0.3))


static func _tent(b: B) -> void:
	var col := b.c("cloth2").darkened(b.rng.randf() * 0.15)
	var w := 2.2
	var d := 3.0
	var h := 1.9
	# A-frame: two slopes and back triangle; front is open with flaps
	b.quad(Vector3(-w * 0.5, 0, d * 0.5), Vector3(0, h, d * 0.5), Vector3(0, h, -d * 0.5), Vector3(-w * 0.5, 0, -d * 0.5), col)
	b.quad(Vector3(0, h, d * 0.5), Vector3(w * 0.5, 0, d * 0.5), Vector3(w * 0.5, 0, -d * 0.5), Vector3(0, h, -d * 0.5), col.darkened(0.1))
	b.tri(Vector3(-w * 0.5, 0, -d * 0.5), Vector3(0, h, -d * 0.5), Vector3(w * 0.5, 0, -d * 0.5), col.darkened(0.15))
	b.tri(Vector3(-w * 0.5, 0, d * 0.5), Vector3(-0.35, h * 0.82, d * 0.5 + 0.1), Vector3(-0.5, 0, d * 0.5 + 0.4), col.darkened(0.05))
	b.tri(Vector3(w * 0.5, 0, d * 0.5), Vector3(0.5, 0, d * 0.5 + 0.4), Vector3(0.35, h * 0.82, d * 0.5 + 0.1), col.darkened(0.05))
	var tc := b.c("timber")
	b.box(Vector3(0, h * 0.5, d * 0.5 + 0.05), Vector3(0.07, h + 0.2, 0.07), tc)
	b.box(Vector3(0, h * 0.5, -d * 0.5 - 0.05), Vector3(0.07, h + 0.2, 0.07), tc)
	b.box(Vector3(0, h + 0.02, 0), Vector3(0.06, 0.06, d + 0.2), tc)
	b.solid(Vector3(0, 0.8, -0.2), Vector3(w * 0.8, 1.6, d * 0.8))


static func _yurt(b: B) -> void:
	var col := b.c("cloth2").darkened(0.05)
	b.cyl(Vector3.ZERO, 2.4, 2.4, 1.8, col, 10)
	b.cone(Vector3(0, 1.8, 0), 2.6, 1.4, b.c("cloth"), 10)
	b.cyl(Vector3(0, 0.9, 0), 2.43, 2.43, 0.15, b.c("cloth"), 10, false, false)
	b.box(Vector3(0, 0.85, 2.38), Vector3(0.9, 1.7, 0.08), b.c("door"))
	b.cyl(Vector3(0, 3.2, 0), 0.2, 0.15, 0.3, b.c("timber"), 6)
	b.solid(Vector3(0, 1.2, 0), Vector3(4.0, 2.4, 4.0))


static func _bedroll(b: B) -> void:
	var col: Color = [Color("6a4a8a"), Color("3e6a4a"), Color("8a3a3a"), Color("3e5a8a")][b.rng.randi() % 4]
	b.box(Vector3(0, 0.08, 0), Vector3(0.8, 0.16, 1.9), col)
	b.log_x(Vector3(0, 0.18, -0.85), 0.16, 0.8, col.lightened(0.2), 6)


static func _log_seat(b: B) -> void:
	b.log_x(Vector3(0, 0.3, 0), 0.3, 2.0, b.c("timber").lightened(0.2), 7)
	b.solid(Vector3(0, 0.3, 0), Vector3(2.0, 0.6, 0.6))


static func _campfire(b: B) -> void:
	for k in 7:
		var a := k * TAU / 7.0
		b.box(Vector3(cos(a) * 0.65, 0.12, sin(a) * 0.65), Vector3(0.3, 0.24, 0.24), b.c("stone"), -a)
	for k in 3:
		b.beam(Vector3(cos(k * 2.1) * 0.5, 0.05, sin(k * 2.1) * 0.5), Vector3(0, 0.5, 0), 0.07, b.c("timber"))
	b.cone(Vector3(0, 0.1, 0), 0.32, 0.8, Color("ff9a3a"), 5, true)
	b.cone(Vector3(0, 0.1, 0), 0.18, 1.0, Color("ffe08a"), 5, true)
	b.light(Vector3(0, 0.9, 0), Color("ff9a4a"), 7.0)


static func _spit(b: B) -> void:
	_campfire(b)
	var tc := b.c("timber")
	for x in [-0.9, 0.9]:
		b.beam(Vector3(x, 0, -0.15), Vector3(x, 1.2, 0), 0.05, tc)
		b.beam(Vector3(x, 0, 0.15), Vector3(x, 1.2, 0), 0.05, tc)
	b.log_x(Vector3(0, 1.15, 0), 0.03, 2.0, tc)
	b.cyl(Vector3(0, 0.95, 0), 0.22, 0.18, 0.3, Color("a0603a"), 6)


static func _weapon_rack(b: B) -> void:
	_weapon_rack_at(b, Vector3.ZERO)


static func _weapon_rack_at(b: B, at: Vector3) -> void:
	b.prop("weapon_rack", at, 0.0, func(p: Vector3) -> void: _weapon_rack_at_geo(b, p))


static func _weapon_rack_at_geo(b: B, at: Vector3) -> void:
	var tc := b.c("timber")
	for x in [-0.7, 0.7]:
		b.box(at + Vector3(x, 0.7, 0), Vector3(0.1, 1.4, 0.1), tc)
	b.box(at + Vector3(0, 1.3, 0), Vector3(1.6, 0.08, 0.1), tc)
	for k in 4:
		var x := -0.5 + k * 0.33
		b.beam(at + Vector3(x, 0.1, 0.12), at + Vector3(x + 0.05, 1.6, 0.05), 0.035, Color("aab0ba") if k % 2 == 0 else tc.lightened(0.2))
	b.solid(at + Vector3(0, 0.7, 0), Vector3(1.6, 1.4, 0.4))


static func _dummy(b: B) -> void:
	var tc := b.c("timber")
	b.box(Vector3(0, 0.9, 0), Vector3(0.12, 1.8, 0.12), tc)
	b.box(Vector3(0, 1.35, 0), Vector3(1.2, 0.1, 0.1), tc)
	b.cyl(Vector3(0, 0.8, 0), 0.3, 0.32, 0.8, Color("c8b070"), 7)
	b.cyl(Vector3(0, 1.75, 0), 0.2, 0.18, 0.35, Color("c8b070"), 7)
	b.solid(Vector3(0, 0.9, 0), Vector3(0.6, 1.8, 0.6))


static func _firewood(b: B) -> void:
	_firewood_at(b, Vector3.ZERO, 0.0)


static func _firewood_at(b: B, at: Vector3, yaw: float) -> void:
	b.prop("firewood", at, yaw, func(p: Vector3) -> void: _firewood_at_geo(b, p, 0.0))


static func _firewood_at_geo(b: B, at: Vector3, yaw: float) -> void:
	var save := b.xf
	b.xf = b.xf * Transform3D(Basis(Vector3.UP, yaw), at)
	for row in 3:
		for k in 4 - row:
			b.log_x(Vector3(-0.8, 0.15 + row * 0.27, -0.45 + k * 0.3 + row * 0.15), 0.14, 1.6, b.c("timber").lightened(0.25 + 0.05 * (k % 2)), 6)
	b.xf = save
	b.solid(at + Vector3(0, 0.45, 0), Vector3(1.6, 0.9, 1.2), yaw)


static func _scarecrow(b: B) -> void:
	var tc := b.c("timber")
	b.box(Vector3(0, 1.0, 0), Vector3(0.1, 2.0, 0.1), tc)
	b.box(Vector3(0, 1.5, 0), Vector3(1.4, 0.08, 0.08), tc)
	b.box(Vector3(0, 1.3, 0), Vector3(0.5, 0.6, 0.3), Color("6a8ac0"))
	b.cyl(Vector3(0, 1.85, 0), 0.2, 0.2, 0.32, Color("d8b860"), 6)
	b.cyl(Vector3(0, 2.15, 0), 0.4, 0.0, 0.3, Color("8a6a3a"), 8)
	b.solid(Vector3(0, 1.0, 0), Vector3(0.4, 2.0, 0.4))


## A small family farm: a fenced plot of crop rows, a scarecrow, hay and a water barrel.
static func _farm(b: B) -> void:
	var w := 11.0 + b.rng.randf_range(-1.0, 1.0)
	var d := 8.0
	var tc := b.c("timber").lightened(0.2)
	var crop := b.rng.randi() % 3
	b.box(Vector3(0, 0.03, 0), Vector3(w, 0.06, d), Color("5a4030"))
	var rows := int(d / 1.3)
	for i in rows:
		var z := -d * 0.5 + 0.9 + i * 1.3
		b.box(Vector3(0, 0.15, z), Vector3(w - 1.0, 0.24, 0.6), Color("4a3426"))
		var n := int((w - 1.4) / 0.75)
		for k in n:
			var x := -w * 0.5 + 0.9 + k * 0.75
			if crop == 0:
				b.box(Vector3(x, 0.55, z), Vector3(0.14, 0.7, 0.14), Color("d8b860"))
				b.box(Vector3(x, 0.95, z), Vector3(0.2, 0.28, 0.2), Color("e8cc70"))
			elif crop == 1:
				b.cyl(Vector3(x, 0.25, z), 0.32, 0.22, 0.34, Color("6aa84f").darkened(0.06 * (k % 3)), 6)
			else:
				b.cone(Vector3(x, 0.25, z), 0.22, 0.7, Color("4a8a3a"), 5)
	# fence on three sides, open at the front (+Z) so you can walk in
	for sx in [-1, 1]:
		for z in range(-3, 4):
			b.box(Vector3(sx * (w * 0.5 + 0.2), 0.55, z * 1.2), Vector3(0.14, 1.1, 0.14), tc)
		b.box(Vector3(sx * (w * 0.5 + 0.2), 0.5, 0), Vector3(0.06, 0.1, d + 0.4), tc.darkened(0.1))
		b.box(Vector3(sx * (w * 0.5 + 0.2), 0.9, 0), Vector3(0.06, 0.1, d + 0.4), tc.darkened(0.1))
		b.solid(Vector3(sx * (w * 0.5 + 0.2), 0.6, 0), Vector3(0.3, 1.2, d + 0.4))
	for k in int(w / 1.4) + 1:
		b.box(Vector3(-w * 0.5 + k * 1.4, 0.55, -d * 0.5 - 0.2), Vector3(0.14, 1.1, 0.14), tc)
	b.box(Vector3(0, 0.5, -d * 0.5 - 0.2), Vector3(w + 0.5, 0.1, 0.06), tc.darkened(0.1))
	b.box(Vector3(0, 0.9, -d * 0.5 - 0.2), Vector3(w + 0.5, 0.1, 0.06), tc.darkened(0.1))
	b.solid(Vector3(0, 0.6, -d * 0.5 - 0.2), Vector3(w + 0.5, 1.2, 0.3))
	var save := b.xf
	b.xf = save * Transform3D(Basis.IDENTITY, Vector3(0.5, 0, 0.3))
	_scarecrow(b)
	b.xf = save
	_haybale_at(b, Vector3(w * 0.5 + 1.2, 0, 1.0), 0.4)
	_haybale_at(b, Vector3(w * 0.5 + 1.2, 0, 2.4), -0.3)
	_barrel(b, Vector3(-w * 0.5 - 0.8, 0, d * 0.5 - 0.5))
	b.xf = save * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-w * 0.5 - 1.2, 0, -1.0))
	_trough(b)
	b.xf = save


static func _trough(b: B) -> void:
	var tc := b.c("timber").lightened(0.1)
	b.box(Vector3(0, 0.35, 0), Vector3(1.8, 0.7, 0.7), tc)
	b.box(Vector3(0, 0.66, 0), Vector3(1.6, 0.04, 0.5), Color("3b6470"))
	b.solid(Vector3(0, 0.35, 0), Vector3(1.8, 0.7, 0.7))


static func _flowerbox(b: B, at: Vector3, yaw: float) -> void:
	b.prop("flowerbox", at, yaw, func(p: Vector3) -> void: _flowerbox_geo(b, p, 0.0))


static func _flowerbox_geo(b: B, at: Vector3, yaw: float) -> void:
	b.box(at, Vector3(0.9, 0.2, 0.25), b.c("timber"), yaw)
	for k in 4:
		var col: Color = [Color("e8604a"), Color("f2d16b"), Color("e88aa6"), Color("9a6ae0")][(k + b.rng.randi()) % 4]
		var off := Basis(Vector3.UP, yaw) * Vector3(-0.3 + k * 0.2, 0.16, 0)
		b.box(at + off, Vector3(0.12, 0.12, 0.12), col, yaw)


static func _pier(b: B, length: float) -> void:
	var tc := b.c("timber").lightened(0.15)
	b.box(Vector3(0, 0.6, length * 0.5), Vector3(2.2, 0.14, length), tc)
	var n := maxi(1, int(length / 2.0))
	for i in n + 1:
		for x in [-1.0, 1.0]:
			b.box(Vector3(x, -0.4, i * length / n), Vector3(0.22, 2.2, 0.22), tc.darkened(0.2))
	for i in int(length / 0.5):
		b.box(Vector3(0, 0.68, 0.25 + i * 0.5), Vector3(2.2, 0.02, 0.05), tc.darkened(0.15))
	b.solid(Vector3(0, 0.6, length * 0.5), Vector3(2.2, 0.14, length))


static func _bridge(b: B, length: float) -> void:
	var tc := b.c("timber").lightened(0.15)
	var n := int(length / 0.45)
	for i in n:
		var z := -length * 0.5 + (i + 0.5) * length / n
		var y := 0.5 + sin(PI * (i + 0.5) / n) * 0.8
		b.box(Vector3(0, y, z), Vector3(2.4, 0.12, length / n - 0.04), tc.darkened(0.06 * (i % 2)))
		if i % 3 == 0:
			for x in [-1.15, 1.15]:
				b.box(Vector3(x, y + 0.5, z), Vector3(0.1, 1.0, 0.1), tc.darkened(0.15))
	for x in [-1.15, 1.15]:
		for i in n - 1:
			var z0 := -length * 0.5 + (i + 0.5) * length / n
			var z1 := z0 + length / n
			var y0 := 1.5 + sin(PI * (i + 0.5) / n) * 0.8 - 0.5
			var y1 := 1.5 + sin(PI * (i + 1.5) / n) * 0.8 - 0.5
			b.beam(Vector3(x, y0, z0), Vector3(x, y1, z1), 0.05, tc)
	b.solid(Vector3(0, 0.9, 0), Vector3(2.4, 0.3, length))


# ================================================================ layouts
## The street plan of a grid town, in the town's own space: [[from, to, width], ...]. theta is the
## direction of the main avenue (it points at the main gate); the cross avenue is square to it.
## Used by both village() and the world (which paints the dirt).
const GRID_STEP := 26.0


static func grid_streets(theta: float, plaza_r: float, rmax := 76.0) -> Array:
	var u := Vector3(cos(theta), 0, sin(theta))
	var v := Vector3(-sin(theta), 0, cos(theta))
	var out: Array = []
	# main avenue: through the plaza and out the gate; cross avenue: plaza to the keep side, and the other way
	out.append([u * -rmax, u * (rmax + 10.0), 5.0])
	out.append([v * -(plaza_r + 3.0), v * rmax, 5.0])
	for k in [-3, -2, -1, 1, 2, 3]:
		var off: float = k * GRID_STEP
		var half := sqrt(maxf(rmax * rmax - off * off, 100.0))
		out.append([u * -half + v * off, u * half + v * off, 2.4])
		out.append([v * -half + u * off, v * half + u * off, 2.4])
	return out


## Footprint of a building (along the street, deep) at its own scale, roof overhang included.
static func _dims(kind: String) -> Vector2:
	var d := {"tavern": Vector2(13.0, 9.2), "shop": Vector2(13.0, 9.2), "apothecary": Vector2(10.0, 8.0), "house": Vector2(9.6, 8.0),
		"hall_house": Vector2(12.8, 8.0), "townhouse": Vector2(8.8, 8.0), "farm": Vector2(13.0, 10.0)}
	if d.has(kind):
		return d[kind]
	var f := footprint(kind)
	match kind:
		"smithy": return Vector2(12.4, 9.2)
		"chapel": return Vector2(9.6, 15.4)
		"longhouse": return Vector2(11.6, 7.5)
		_: return Vector2(f * 1.5, f * 1.5)


## A whole village laid out around a plaza with a well. Returns a Node3D (ground at y = 0).
## Its meta "radius" says how much flat ground it wants.
## opts: "hub" (true = the plaza is left empty for your own NPCs/stations), "plaza_r", "roads" (angles that
## must stay clear; gates go there), "avoid" ([[Vector3, radius], ...] spots to keep free), "count" (houses).
static func village(style_name := "meadow", seed_v := 1, size := 1.0, opts := {}) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var st := style(style_name)
	var root := Node3D.new()
	root.name = "Village"
	var placed: Array = []     # [Vector3 pos, float radius]
	var buildings: Array = []  # {kind, pos, yaw} of everything big, for placing villagers
	var site_counts := {}

	var bscale: float = opts.get("bscale", 1.3)
	_mark_site(root, style_name, bscale)
	var add := func(kind: String, pos: Vector3, yaw: float, length := 6.0) -> Node3D:
		var n := build(kind, style_name, rng.randi() % 1000, length)
		var bs := _bsc(kind, bscale)
		n.position = pos
		n.rotation.y = yaw
		n.scale = Vector3.ONE * bs
		root.add_child(n)
		_tag_site_prop(n, kind, site_counts)
		placed.append([pos, footprint(kind) * bs])
		buildings.append({"kind": kind, "pos": pos, "yaw": yaw, "scale": bs})
		return n
	var gap_extra: float = -0.2
	var is_free := func(pos: Vector3, r: float) -> bool:
		for p: Array in placed:
			if Vector2(pos.x - (p[0] as Vector3).x, pos.z - (p[0] as Vector3).z).length() < r + float(p[1]) + 0.8 + gap_extra:
				return false
		return true
	var face_center := func(pos: Vector3) -> float:
		return atan2(-pos.x, -pos.z)

	var hub: bool = opts.get("hub", false)
	var roads: Array = opts.get("roads", [])
	for av: Array in opts.get("avoid", []):
		placed.append([av[0], float(av[1])])
	# plaza
	var plaza_r: float = opts.get("plaza_r", 7.0 * size)
	var plaza := B.new(st, seed_v)
	plaza.cyl(Vector3(0, -0.04, 0), plaza_r, plaza_r, 0.08, Color(st["ground"]).lightened(0.15), 18)
	root.add_child(plaza.build("Plaza"))
	if not hub:
		add.call("well", Vector3.ZERO, rng.randf() * TAU)
		add.call("notice_board", Vector3(2.6, 0, -2.0), -0.6)
		for k in 3:
			var a := 0.6 + k * 0.9 + rng.randf_range(-0.1, 0.1)
			var sp := Vector3(cos(a), 0, sin(a)) * (plaza_r - 1.8)
			add.call("stall", sp, face_center.call(sp))
	if hub:
		# a market on the plaza's rim: stalls, carts, a well, benches (not across the gate roads)
		var rim := plaza_r - 2.2
		for k in 7:
			var am := 0.35 + k * TAU / 7.0
			var clear := true
			for ra: float in roads:
				if absf(angle_difference(am, ra)) < 0.3:
					clear = false
			if not clear:
				continue
			var mp := Vector3(cos(am), 0, sin(am)) * rim
			add.call("stall" if k % 3 != 2 else "cart", mp, face_center.call(mp))
		for k in 4:
			var ab := 0.9 + k * TAU / 4.0
			var bp := Vector3(cos(ab), 0, sin(ab)) * (plaza_r * 0.55)
			add.call("bench", bp, ab + PI * 0.5)
		add.call("well", Vector3(plaza_r * 0.62, 0, -plaza_r * 0.35), 0.0)
	var n_lamps := 6 if not hub else 10
	for k in n_lamps:
		var a2 := k * TAU / n_lamps + 0.3
		var lp := Vector3(cos(a2), 0, sin(a2)) * (plaza_r + 0.6)
		var near_road := false
		for ra: float in roads:
			if absf(angle_difference(a2, ra)) < 0.2:
				near_road = true
		if not near_road:
			add.call("lamp", lp, a2)
	# landmarks first, then houses in a ring
	var ring: float = plaza_r + (3.5 if hub else 5.0) * size
	var kinds := ["tavern", "shop", "smithy"]
	if opts.get("keep", false):
		kinds = ["keep"] + kinds
	if style_name == "meadow":
		kinds += ["chapel", "windmill", "barn"]
	elif style_name == "thornwood":
		kinds += ["longhouse", "watchtower"]
	elif style_name == "mire":
		kinds = ["stilt_hut", "stilt_hut", "shop", "stilt_hut"]
	else:
		kinds += ["lodge", "chapel", "watchtower"]
	if opts.has("kinds"):
		kinds = (opts["kinds"] as Array).duplicate()
	var house_kind: String = {"meadow": "cottage", "thornwood": "cottage", "mire": "stilt_hut", "peaks": "lodge"}.get(style_name, "cottage")
	house_kind = opts.get("house", house_kind)
	var alt_kind: String = opts.get("alt", "house" if style_name != "mire" else house_kind)
	var count: int = opts.get("count", int(8 * size))
	for i in count:
		kinds.append(alt_kind if i % 3 == 0 else house_kind)
	var gate_a := rng.randf() * TAU
	var gates: Array = roads if not roads.is_empty() else [gate_a, gate_a + PI]
	var on_road := func(pos: Vector3, r: float) -> bool:
		for ga: float in gates:
			var dir := Vector3(cos(ga), 0, sin(ga))
			var along := pos.dot(dir)
			if along > 0.0 and (pos - dir * along).length() < r + 2.2:
				return true
		return false
	# ---- grid towns: a main avenue and cross avenue, smaller streets between, buildings on lots facing the streets
	var grid_on: bool = opts.get("grid", false)
	var rects: Array = []      # [cu, cv, hu, hv] of grid-placed buildings, in street space
	var gtheta: float = opts.get("grid_angle", 0.0)
	var gu := Vector3(cos(gtheta), 0, sin(gtheta))
	var gv := Vector3(-sin(gtheta), 0, cos(gtheta))
	if grid_on:
		var rmax := 76.0
		var streets := grid_streets(gtheta, plaza_r, rmax)
		# street bands in (u, v): [axis(0=along u), offset, half width, t0, t1]
		var bands: Array = []
		for sg: Array in streets:
			var a: Vector3 = sg[0]
			var b2: Vector3 = sg[1]
			var along_u: bool = absf((b2 - a).dot(gv)) < 0.01
			if along_u:
				bands.append([0, a.dot(gv), float(sg[2]) * 0.5, a.dot(gu), b2.dot(gu)])
			else:
				bands.append([1, a.dot(gu), float(sg[2]) * 0.5, a.dot(gv), b2.dot(gv)])
		# the road ground (kept as thin dirt strips under everything, in case the painted ground is faint)
		var sb := B.new(st, 9)
		var scol := Color(st["ground"]).lightened(0.1)
		for sg: Array in streets:
			var a2: Vector3 = sg[0]
			var b3: Vector3 = sg[1]
			var mid := (a2 + b3) * 0.5
			var dd := b3 - a2
			sb.box(mid + Vector3(0, -0.03, 0), Vector3(float(sg[2]), 0.06, dd.length()), scol, atan2(dd.x, dd.z))
		root.add_child(sb.build("Streets"))
		var circle_ok := func(pos: Vector3, r: float) -> bool:
			if not is_free.call(pos, r):
				return false
			var pu := pos.dot(gu)
			var pv := pos.dot(gv)
			for bd0: Array in bands:
				var lo0 := (pv if int(bd0[0]) == 0 else pu)
				var al0 := (pu if int(bd0[0]) == 0 else pv)
				if absf(lo0 - float(bd0[1])) < float(bd0[2]) + r + (0.5 if r < 0.7 else 0.9) and al0 > float(bd0[3]) - r and al0 < float(bd0[4]) + r:
					if not (r == 0.5):    # lamps stand at the street edge on purpose
						return false
			for rc: Array in rects:
				var dx := maxf(absf(pu - float(rc[0])) - float(rc[2]), 0.0)
				var dz := maxf(absf(pv - float(rc[1])) - float(rc[3]), 0.0)
				if Vector2(dx, dz).length() < r + 0.1:
					return false
			return true
		var rect_ok := func(cu: float, cv: float, hu: float, hv: float, own: Array) -> bool:
			var cs := [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
			for c: Vector2 in cs:
				var wp := gu * (cu + c.x * hu) + gv * (cv + c.y * hv)
				if wp.length() > rmax or wp.length() < plaza_r + 1.2:
					return false
			if on_road.call(gu * cu + gv * cv, 0.0):
				return false
			for bd: Array in bands:
				var lo := (cv if int(bd[0]) == 0 else cu)
				var hh := (hv if int(bd[0]) == 0 else hu)
				var along := (cu if int(bd[0]) == 0 else cv)
				var ha := (hu if int(bd[0]) == 0 else hv)
				if lo + hh > float(bd[1]) - float(bd[2]) - 1.2 and lo - hh < float(bd[1]) + float(bd[2]) + 1.2:
					if along + ha > float(bd[3]) and along - ha < float(bd[4]):
						return false
			for rc2: Array in rects:
				if absf(cu - float(rc2[0])) < hu + float(rc2[2]) + 2.0 and absf(cv - float(rc2[1])) < hv + float(rc2[3]) + 2.0:
					return false
			var cw := gu * cu + gv * cv
			for pc: Array in placed:
				var pu2 := (pc[0] as Vector3).dot(gu)
				var pv2 := (pc[0] as Vector3).dot(gv)
				var dx2 := maxf(absf(pu2 - cu) - hu, 0.0)
				var dz2 := maxf(absf(pv2 - cv) - hv, 0.0)
				if Vector2(dx2, dz2).length() < float(pc[1]) + 0.6:
					return false
			return cw.length() > 0.0
		var pending: Array = []
		for kind2: String in kinds:
			var bs2 := _bsc(kind2, bscale)
			var dm := _dims(kind2) * bs2
			var best_pos := Vector3.ZERO
			var best_yaw := 0.0
			var best_rect: Array = []
			var best_score := 1e9
			var outer := kind2 in ["farm", "windmill", "barn"]
			if kind2 == "keep":
				# the keep closes the cross avenue on the north side
				var kh := footprint("keep") * bs2 * 0.85
				var kc := gv * -(plaza_r + 4.0 + kh)
				var ky := atan2(gv.x, gv.z)
				var kn := add.call("keep", kc, ky) as Node3D
				placed.pop_back()
				rects.append([kc.dot(gu), kc.dot(gv), kh, kh])
				continue
			for bd2: Array in bands:
				for side in [-1.0, 1.0]:
					var t := -rmax
					while t <= rmax:
						var cu := 0.0
						var cv := 0.0
						var hu := 0.0
						var hv := 0.0
						var dir := Vector3.ZERO
						if int(bd2[0]) == 0:
							cu = t
							cv = float(bd2[1]) + side * (float(bd2[2]) + 2.0 + dm.y * 0.5)
							hu = dm.x * 0.5
							hv = dm.y * 0.5
							dir = gv * -side
						else:
							cv = t
							cu = float(bd2[1]) + side * (float(bd2[2]) + 2.0 + dm.y * 0.5)
							hu = dm.y * 0.5
							hv = dm.x * 0.5
							dir = gu * -side
						t += 1.5
						if t < float(bd2[3]) or t > float(bd2[4]):
							continue
						var dist := Vector2(cu, cv).length()
						var score := dist if not outer else -dist
						if outer and dist < rmax * 0.55:
							continue
						if score >= best_score:
							continue
						if not rect_ok.call(cu, cv, hu, hv, bd2):
							continue
						best_score = score
						best_pos = gu * cu + gv * cv
						best_yaw = atan2(dir.x, dir.z)
						best_rect = [cu, cv, hu, hv]
			if best_rect.is_empty():
				continue
			add.call(kind2, best_pos, best_yaw)
			placed.pop_back()
			rects.append(best_rect)
			pending.append([best_pos, best_yaw, dm])
		# once every building is down: a barrel, crates or a bench in the yard, wherever there is room
		for pd: Array in pending:
			var tdir: Vector3 = Vector3(sin(float(pd[1])), 0, cos(float(pd[1])))
			var along_dir := Vector3(tdir.z, 0, -tdir.x)
			var pdm: Vector2 = pd[2]
			var cp: Vector3 = (pd[0] as Vector3) + tdir * (pdm.y * 0.5 + 0.85) + along_dir * (pdm.x * 0.5 - 1.2)
			var clutter2: String = ["barrel", "crates", "bench", "cart", "firewood", "barrel"][rng.randi() % 6]
			if circle_ok.call(cp, 0.6):
				add.call(clutter2, cp, float(pd[1]) + rng.randf_range(-0.3, 0.3))
		# lamps along the avenues
		for sg2: Array in streets:
			if float(sg2[2]) < 4.0:
				continue
			var a4: Vector3 = sg2[0]
			var b4: Vector3 = sg2[1]
			var dd2 := b4 - a4
			var ln := dd2.length()
			var dn := dd2 / ln
			var nrm := Vector3(-dn.z, 0, dn.x)
			var tt := 8.0
			while tt < ln - 6.0:
				for sd in [-1.0, 1.0]:
					var lp2: Vector3 = a4 + dn * tt + nrm * sd * 3.3
					if lp2.length() > plaza_r + 1.5 and circle_ok.call(lp2, 0.5):
						add.call("lamp", lp2, 0.0)
				tt += 14.0
	var ring_now := ring
	for kind: String in (kinds if not grid_on else []):
		var r := footprint(kind) * _bsc(kind, bscale)
		var done := false
		var a0 := rng.randf() * TAU
		# fill the inner rings first, sweeping all the way round before stepping outward
		for lvl in 14:
			if done:
				break
			var rad := ring + lvl * 3.5 + r * 0.5
			var steps := int(TAU * rad / 1.6)
			for k in steps:
				var ang := a0 + TAU * k / steps
				var pos := Vector3(cos(ang), 0, sin(ang)) * rad
				if is_free.call(pos, r) and not on_road.call(pos, r):
					add.call(kind, pos, face_center.call(pos) + rng.randf_range(-0.12, 0.12))
					var side := Vector3(cos(ang + 0.45), 0, sin(ang + 0.45)) * (rad + 0.5)
					var clutter: String = ["barrel", "crates", "haybale", "firewood", "bench", "cart", "trough", "barrel"][rng.randi() % 8]
					if is_free.call(side, 0.9):
						add.call(clutter, side, rng.randf() * TAU)
					done = true
					break
	var far := 0.0
	for p: Array in placed:
		far = maxf(far, Vector2((p[0] as Vector3).x, (p[0] as Vector3).z).length() + float(p[1]))
	for rc3: Array in rects:
		far = maxf(far, (gu * float(rc3[0]) + gv * float(rc3[1])).length() + maxf(float(rc3[2]), float(rc3[3])))
	ring_now = far - 3.0
	# a fence / palisade / wall around it, with two openings
	var edge := ring_now + 7.0
	var fence_kind: String = {"fence": "fence", "palisade": "palisade", "stone": "stone_wall", "castle": "castle_wall"}.get(opts.get("wall", st["fence"]), "")
	var castle: bool = fence_kind == "castle_wall"
	if fence_kind != "":
		var seg := 6.0
		var n_seg := int(TAU * edge / seg)
		if roads.is_empty():
			_paths(root, st, gates, plaza_r, edge + 6.0)
		for k in n_seg:
			var a3 := (k + 0.5) * TAU / n_seg
			var gap := (4.2 if fence_kind != "fence" else 2.5) / edge
			if castle:
				gap = 5.6 / edge
			var in_gap := false
			for ga2: float in gates:
				if absf(angle_difference(a3, ga2)) < gap:
					in_gap = true
			if in_gap:
				continue
			var fp := Vector3(cos(a3), 0, sin(a3)) * edge
			var fn := build(fence_kind, style_name, k, seg + 0.3)
			fn.position = fp
			fn.rotation.y = -a3 + PI * 0.5
			root.add_child(fn)
			if castle and k % 4 == 0:
				var tw := build("castle_tower", style_name, k)
				tw.position = Vector3(cos(a3 + 0.5 * TAU / n_seg), 0, sin(a3 + 0.5 * TAU / n_seg)) * edge
				root.add_child(tw)
		if fence_kind != "fence":
			for ga: float in gates:
				var gp := Vector3(cos(ga), 0, sin(ga)) * edge
				var gh := build("castle_gate" if castle else "gatehouse", style_name, 3)
				gh.position = gp
				gh.rotation.y = -ga + PI * 0.5
				root.add_child(gh)
	_tag_rest(root, site_counts)
	root.set_meta("radius", edge + 3.0)
	root.set_meta("buildings", buildings)
	return root


## Dirt roads from the plaza out through the gates.
static func _paths(root: Node3D, st: Dictionary, angles: Array, from_r: float, to_r: float) -> void:
	var pb := B.new(st, 5)
	var col := Color(st["ground"]).lightened(0.08)
	for a: float in angles:
		var dir := Vector3(cos(a), 0, sin(a))
		var mid := dir * (from_r + to_r) * 0.5
		pb.box(mid + Vector3(0, -0.02, 0), Vector3(3.2, 0.06, to_r - from_r), col, atan2(dir.x, dir.z))
	root.add_child(pb.build("Paths"))


## A small camp: tents around a fire, bedrolls, a banner. kind: "hunters", "bandits", "pilgrims".
static func camp(style_name := "meadow", seed_v := 1, kind := "hunters") -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var root := Node3D.new()
	root.name = "Camp"
	var site_counts := {}
	_mark_site(root, style_name, 1.0)
	var put := func(k: String, pos: Vector3, yaw: float) -> void:
		var n := build(k, style_name, rng.randi() % 1000)
		n.position = pos
		n.rotation.y = yaw
		root.add_child(n)
		_tag_site_prop(n, k, site_counts)
	if kind != "tutorial":    # the tutorial camp's cooking fire is placed by the world
		put.call("spit" if kind == "hunters" else "campfire", Vector3.ZERO, 0.0)
	var tent_angles: Array = [2.4, 3.7, 1.6]    # the tutorial camp keeps its east and north sides open
	var n_tents := 3 + rng.randi() % 3 if kind != "tutorial" else 3
	for i in n_tents:
		var a := i * TAU / n_tents + rng.randf_range(-0.2, 0.2)
		if kind == "tutorial":
			a = tent_angles[i]
		var p := Vector3(cos(a), 0, sin(a)) * 5.2
		put.call("yurt" if (kind == "pilgrims" and i % 2 == 0) else "tent", p, atan2(-p.x, -p.z))
		var bp := Vector3(cos(a + 0.45), 0, sin(a + 0.45)) * 3.4
		put.call("bedroll", bp, atan2(-bp.x, -bp.z))
	for i in 3:
		var a2 := i * TAU / 3.0 + 0.5
		var lp := Vector3(cos(a2), 0, sin(a2)) * 2.0
		put.call("log_seat", lp, -a2 + PI * 0.5)
	put.call("crates", Vector3(-6.5, 0, 2.0), 0.4)
	put.call("banner", Vector3(6.0, 0, -2.5), 0.0)
	if kind == "bandits":
		put.call("weapon_rack", Vector3(2.0, 0, -6.0), 0.2)
		put.call("dummy", Vector3(4.5, 0, -5.5), 0.0)
		for k in 5:
			var a3 := PI * 0.75 + k * 0.32
			var pp := Vector3(cos(a3), 0, sin(a3)) * 9.0
			var pal := build("palisade", style_name, k, 3.2)
			pal.position = pp
			pal.rotation.y = -a3 + PI * 0.5
			root.add_child(pal)
	else:
		put.call("firewood", Vector3(1.0, 0, 6.6), 0.2)
		put.call("cart", Vector3(-4.0, 0, -6.0), 0.8)
	_tag_rest(root, site_counts)
	root.set_meta("radius", 10.0)
	return root
