class_name Caves
extends Node3D
## Cave mouths dug into the hillsides, and the chambers behind them. Each chamber is built far off
## the east edge of the map (so it never touches the overworld) and is entered through a teleport.
## Inside: a guardian, a pack of that region's creatures and no daylight.

const X0 := 2600.0          # centre of chamber 0; the rest follow along +X
const DX := 140.0
const FLOOR_Y := 0.0
const R := 24.0             # chamber radius (m)
const CEIL := 13.0

const DEFS := [
	{"name": "The Old Burrow", "biome": 0, "pool": ["mosslet", "beetle", "puffcap", "spider"], "guard": "beetle", "gname": "Burrow King", "rock": "7a6a52", "glow": "ffcf70"},
	{"name": "Hollow of Roots", "biome": 1, "pool": ["wolf", "spider", "archer", "sapling"], "guard": "sapling", "gname": "Rootmother", "rock": "5a5040", "glow": "9be05a"},
	{"name": "Weeping Grotto", "biome": 2, "pool": ["lurker", "leech", "shaman", "crone"], "guard": "leech", "gname": "Grotto Maw", "rock": "46524c", "glow": "7affc0"},
	{"name": "Rimecrypt", "biome": 3, "pool": ["snowwolf", "cultist", "frostwisp", "golem"], "guard": "golem", "gname": "Frozen Warden", "rock": "7c8896", "glow": "9fe0ff"},
	{"name": "Spider Den", "biome": 1, "pool": ["spider", "spider", "archer", "wolf"], "guard": "spider", "gname": "Brood Queen", "rock": "4a4540", "glow": "e07aff"},
	{"name": "The Barrow", "biome": 3, "pool": ["downhound", "barrowwight", "ridgecrawler", "cairnguard"], "guard": "cairnguard", "gname": "Barrow Warden", "rock": "6a6a58", "glow": "d8e070"},
]

var world: World
var main: Node
var sites: Array = []            # {pos, face, biome, idx}
var _chambers: Array[Node3D] = []
var _inside := -1
var _mine: Array[Enemy] = []
var _flick: Array = []
var _t := 0.0


static func centre(i: int) -> Vector3:
	return Vector3(X0 + i * DX, FLOOR_Y, 0.0)


func idx_for_x(x: float) -> int:
	return clampi(roundi((x - X0) / DX), 0, DEFS.size() - 1)


func biome_here(p: Vector3) -> int:
	return int(DEFS[idx_for_x(p.x)]["biome"])


func map_cell(p: Vector3) -> Vector2:
	var s: Dictionary = sites[idx_for_x(p.x)]
	return world.world_to_cell(s["pos"])


func setup(m: Node) -> void:
	main = m


func reset() -> void:
	_cleanup()


# ================================================================ building
func build(w: World) -> void:
	world = w
	for i in sites.size():
		_build_mouth(sites[i])
	for i in DEFS.size():
		_chambers.append(_build_chamber(i))


func _rock_mat(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.albedo_color = col
	m.roughness = 1.0
	return m


func _glow_mat(col: Color, e: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = e
	return m


func _mm(mesh: Mesh, mat: Material, xf: Array, shadow := true) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xf.size()
	for j in xf.size():
		mm.set_instance_transform(j, xf[j])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _build_mouth(s: Dictionary) -> void:
	var def: Dictionary = DEFS[int(s["idx"])]
	var root := Node3D.new()
	root.name = "CaveMouth%d" % int(s["idx"])
	add_child(root)
	var pos: Vector3 = s["pos"]
	var face: Vector3 = s["face"]
	root.position = pos
	root.rotation.y = atan2(face.x, face.z)   # local +Z points out of the hill
	var rock := _rock_mat(Color(def["rock"]).lightened(0.25))
	var rm := Models.scenery_mesh("rockmass", 5 + int(s["idx"]))
	var sm := Models.scenery_mesh("stalag", 9)
	var body := StaticBody3D.new()
	root.add_child(body)
	# pillars, lintel and the heaped hill behind
	var xf: Array = []
	var parts := [
		[Vector3(-2.5, 1.6, 0.2), Vector3(1.6, 2.6, 1.6)], [Vector3(2.5, 1.6, 0.2), Vector3(1.6, 2.6, 1.6)],
		[Vector3(0, 4.0, 0.0), Vector3(3.6, 1.3, 1.7)], [Vector3(-4.2, 2.6, -2.2), Vector3(3.0, 3.0, 3.0)],
		[Vector3(4.2, 2.6, -2.2), Vector3(3.0, 3.0, 3.0)], [Vector3(0, 4.2, -3.2), Vector3(5.5, 4.2, 4.0)],
		[Vector3(-6.5, 1.2, 0.5), Vector3(1.8, 1.4, 1.8)], [Vector3(6.2, 1.0, 1.0), Vector3(1.4, 1.1, 1.4)],
	]
	for p: Array in parts:
		xf.append(Transform3D(Basis.from_scale(p[1]), p[0]))
	root.add_child(_mm(rm, rock, xf))
	for p: Array in [[Vector3(-2.5, 1.6, 0.2), 1.8], [Vector3(2.5, 1.6, 0.2), 1.8], [Vector3(0, 4.4, -0.5), 2.4], [Vector3(-4.2, 2.6, -2.2), 3.0], [Vector3(4.2, 2.6, -2.2), 3.0], [Vector3(0, 3.5, -3.6), 4.2]]:
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = p[1]
		sh.height = 7.0
		cs.shape = sh
		cs.position = p[0]
		body.add_child(cs)
	# stalactite teeth over the dark opening
	var teeth: Array = []
	for k in 5:
		var tx := -1.6 + k * 0.8
		teeth.append(Transform3D(Basis(Vector3.RIGHT, PI).scaled(Vector3(0.22, 0.28 + (k % 2) * 0.12, 0.22)), Vector3(tx, 3.55, 0.35)))
	root.add_child(_mm(sm, rock, teeth, false))
	var dark := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(4.0, 3.4, 0.3)
	dark.mesh = bm
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(0.01, 0.01, 0.02)
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dark.material_override = dm
	dark.position = Vector3(0, 1.7, -0.6)
	root.add_child(dark)
	var l := OmniLight3D.new()
	l.light_color = Color(def["glow"])
	l.light_energy = 0.7
	l.omni_range = 7.0
	l.position = Vector3(0, 1.8, 1.2)
	l.shadow_enabled = false
	root.add_child(l)


func _build_chamber(i: int) -> Node3D:
	var def: Dictionary = DEFS[i]
	var c := centre(i)
	var root := Node3D.new()
	root.name = "Cave%d" % i
	root.position = c
	root.visible = false
	add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242 + i * 17
	var rockc := Color(def["rock"])
	var rock := _rock_mat(rockc.lightened(0.3))
	var body := StaticBody3D.new()
	root.add_child(body)
	# floor
	var fm := MeshInstance3D.new()
	var fc := CylinderMesh.new()
	fc.top_radius = R + 6.0
	fc.bottom_radius = R + 6.0
	fc.height = 1.0
	fc.radial_segments = 24
	fm.mesh = fc
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = rockc.lightened(0.05)
	fmat.roughness = 1.0
	fm.material_override = fmat
	fm.position.y = -0.5
	root.add_child(fm)
	var fcs := CollisionShape3D.new()
	var fsh := CylinderShape3D.new()
	fsh.radius = R + 6.0
	fsh.height = 1.0
	fcs.shape = fsh
	fcs.position.y = -0.5
	body.add_child(fcs)
	# ceiling
	var cm := MeshInstance3D.new()
	var cc := CylinderMesh.new()
	cc.top_radius = R + 8.0
	cc.bottom_radius = R + 8.0
	cc.height = 1.0
	cc.radial_segments = 24
	cm.mesh = cc
	var cmat := StandardMaterial3D.new()
	cmat.albedo_color = rockc.darkened(0.3)
	cmat.roughness = 1.0
	cm.material_override = cmat
	cm.position.y = CEIL + 0.5
	root.add_child(cm)
	# irregular wall: two rings of heaped rock plus collision boxes
	var rm := Models.scenery_mesh("rockmass", 100 + i)
	var xf: Array = []
	var n := 36
	for k in n:
		var a := TAU * k / n
		var rr := R + 4.4 + rng.randf_range(-1.0, 1.0)
		for layer in 3:
			var sc := rng.randf_range(4.2, 5.6)
			var p := Vector3(cos(a) * (rr + layer * 0.5), 1.2 + layer * 4.6, sin(a) * (rr + layer * 0.5))
			xf.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc * rng.randf_range(0.8, 1.1), sc)), p))
		var wb := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(TAU * R / n + 2.0, CEIL + 2.0, 4.0)
		wb.shape = bs
		wb.position = Vector3(cos(a) * (R + 1.0), CEIL * 0.5, sin(a) * (R + 1.0))
		wb.rotation.y = -a + PI * 0.5
		body.add_child(wb)
	root.add_child(_mm(rm, rock, xf))
	# stalactites on the ceiling
	var sm := Models.scenery_mesh("stalag", 200 + i)
	var tx: Array = []
	for k in 40:
		var a2 := rng.randf() * TAU
		var d2 := sqrt(rng.randf()) * (R - 1.0)
		var s2 := rng.randf_range(0.5, 1.2)
		tx.append(Transform3D(Basis(Vector3.RIGHT, PI).scaled(Vector3(s2, s2 * rng.randf_range(0.8, 1.6), s2)), Vector3(cos(a2) * d2, CEIL, sin(a2) * d2)))
	root.add_child(_mm(sm, rock, tx, false))
	# standing pillars for cover
	var keep_out := [Vector3(0, 0, R - 8.0), Vector3(0, 0, -R + 7.0)]
	var px: Array = []
	var placed: Array[Vector3] = []
	var tries := 0
	while placed.size() < 7 and tries < 80:
		tries += 1
		var a3 := rng.randf() * TAU
		var d3 := rng.randf_range(6.0, R - 6.0)
		var pp := Vector3(cos(a3) * d3, 0, sin(a3) * d3)
		var ok := true
		for k: Vector3 in keep_out + placed:
			if pp.distance_to(k) < 7.0:
				ok = false
		if not ok:
			continue
		placed.append(pp)
		var s3 := rng.randf_range(1.3, 2.0)
		px.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s3, 4.4, s3)), pp))
		var pcs := CollisionShape3D.new()
		var psh := CylinderShape3D.new()
		psh.radius = s3 * 0.85
		psh.height = 8.0
		pcs.shape = psh
		pcs.position = pp + Vector3(0, 3.0, 0)
		body.add_child(pcs)
	root.add_child(_mm(sm, rock, px))
	# glowing crystals near the back, torches around the rim
	var glow := Color(def["glow"])
	var gx: Array = []
	for k in 6:
		var a4 := rng.randf_range(-0.8, 0.8)
		var s4 := rng.randf_range(0.25, 0.5)
		gx.append(Transform3D(Basis(Vector3(0, 0, 1), rng.randf_range(-0.3, 0.3)).scaled(Vector3(s4, s4 * 1.6, s4)), Vector3(sin(a4) * 3.0 + rng.randf_range(-1, 1), 0, -R + 5.0 + cos(a4) * 1.5 + rng.randf_range(-1, 1))))
	root.add_child(_mm(sm, _glow_mat(glow, 2.0), gx, false))
	var cl := OmniLight3D.new()
	cl.light_color = glow
	cl.light_energy = 2.8
	cl.omni_range = 18.0
	cl.position = Vector3(0, 2.0, -R + 6.0)
	cl.set_meta("base", 2.8)
	root.add_child(cl)
	_flick.append(cl)
	for k in 7:
		var a5 := TAU * (k + 0.5) / 7.0
		var tp := Vector3(cos(a5) * (R - 1.2), 2.4, sin(a5) * (R - 1.2))
		var stick := MeshInstance3D.new()
		var sc2 := CylinderMesh.new()
		sc2.top_radius = 0.07
		sc2.bottom_radius = 0.09
		sc2.height = 1.2
		stick.mesh = sc2
		var smat := StandardMaterial3D.new()
		smat.albedo_color = Color("4a3524")
		stick.material_override = smat
		stick.position = tp - Vector3(0, 0.6, 0)
		root.add_child(stick)
		var fl := MeshInstance3D.new()
		var fs := SphereMesh.new()
		fs.radius = 0.2
		fs.height = 0.4
		fl.mesh = fs
		fl.material_override = _glow_mat(Color("ffb050"), 3.0)
		fl.position = tp + Vector3(0, 0.1, 0)
		root.add_child(fl)
		var tl := OmniLight3D.new()
		tl.light_color = Color("ffa860")
		tl.light_energy = 3.2
		tl.omni_range = 18.0
		tl.position = tp + Vector3(0, 0.5, 0)
		tl.set_meta("base", 3.2)
		root.add_child(tl)
		_flick.append(tl)
	# the way out: a pale glowing doorway in the south wall
	var door := MeshInstance3D.new()
	var dq := QuadMesh.new()
	dq.size = Vector2(3.2, 4.2)
	door.mesh = dq
	var dmat := _glow_mat(Color("dfeaf5"), 1.6)
	dmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	door.material_override = dmat
	door.position = Vector3(0, 2.1, R - 0.4)
	root.add_child(door)
	var el := OmniLight3D.new()
	el.light_color = Color("dfeaf5")
	el.light_energy = 1.2
	el.omni_range = 9.0
	el.position = Vector3(0, 2.4, R - 3.0)
	root.add_child(el)
	var mid := OmniLight3D.new()
	mid.light_color = Color(def["glow"]).lerp(Color.WHITE, 0.5)
	mid.light_energy = 1.6
	mid.omni_range = 24.0
	mid.position = Vector3(0, 9.0, 0)
	root.add_child(mid)
	return root


# ================================================================ use
func nearest(p: Vector3) -> Dictionary:
	if _inside >= 0:
		var c := centre(_inside)
		if Vector2(p.x - c.x, p.z - (c.z + R - 2.5)).length() < 4.0:
			return {"kind": "cave_exit", "i": _inside}
		return {}
	for s: Dictionary in sites:
		var pos: Vector3 = s["pos"]
		var mouth: Vector3 = pos + (s["face"] as Vector3) * 1.5
		if Vector2(p.x - mouth.x, p.z - mouth.z).length() < 3.6:
			return {"kind": "cave", "i": int(s["idx"])}
	return {}


func name_of(i: int) -> String:
	return DEFS[i]["name"]


func discovered() -> Array:
	var st: Dictionary = main.state
	if not st.has("caves") or not (st["caves"] is Array):
		st["caves"] = []
	return st["caves"]


func map_markers() -> Array:
	var out: Array = []
	if main == null or main.state.is_empty():
		return out
	for i: Variant in discovered():
		var s: Dictionary = sites[int(i)]
		out.append({"cell": world.world_to_cell(s["pos"]), "color": Color("8a8f9a"), "size": 3.0})
	return out


func enter(i: int) -> void:
	if bool(main.state.get("tut_safe", false)):
		main.ui.toast("Finish your lessons first.")
		return
	_cleanup()
	_inside = i
	for k in _chambers.size():
		_chambers[k].visible = k == i
	var c := centre(i)
	main.player.teleport(c + Vector3(0, 0.3, R - 8.0))
	main.rig.snap()
	if main.daynight:
		main.daynight.cave = true
		main.daynight.snap()
	var def: Dictionary = DEFS[i]
	main.ui.toast(def["name"])
	Sfx.play("ui_open", main.player.global_position, -6.0)
	# the pack
	var pool: Array = def["pool"]
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var made := 0
	var tries := 0
	while made < 7 and tries < 60:
		tries += 1
		var a := rng.randf() * TAU
		var d := rng.randf_range(7.0, R - 4.0)
		var p := c + Vector3(cos(a) * d, 0, sin(a) * d)
		if Vector2(p.x - main.player.global_position.x, p.z - main.player.global_position.z).length() < 11.0:
			continue
		var e: Enemy = main.combat.spawn_enemy(pool[rng.randi() % pool.size()], p, int(def["biome"]))
		_mine.append(e)
		made += 1
	var g: Enemy = main.combat.spawn_enemy(def["guard"], c + Vector3(0, 0, -R + 9.0), int(def["biome"]))
	g.is_elite = true
	g.display_name = def["gname"]
	g.max_hp *= 4.0
	g.hp = g.max_hp
	g.dmg *= 1.35
	g.xp *= 5
	g.model.scale *= 1.6
	g.height *= 1.6
	g.radius *= 1.5
	_mine.append(g)


func leave() -> void:
	if _inside < 0:
		return
	var s: Dictionary = sites[_inside]
	var out: Vector3 = s["pos"] + (s["face"] as Vector3) * 3.8
	_cleanup()
	main.player.teleport(Vector3(out.x, world.height_at(out.x, out.z) + 0.3, out.z))
	main.rig.snap()
	if main.daynight:
		main.daynight.snap()


func _cleanup() -> void:
	for e: Enemy in _mine:
		if is_instance_valid(e):
			if main and main.combat:
				main.combat.enemies.erase(e)
			e.queue_free()
	_mine.clear()
	_inside = -1
	for ch in _chambers:
		ch.visible = false
	if main and main.daynight:
		main.daynight.cave = false


func _process(delta: float) -> void:
	if main == null or main.player == null:
		return
	_t += delta
	var p: Vector3 = main.player.global_position
	var in_zone := p.x > X0 - 150.0
	if in_zone and _inside < 0:
		# loaded a save that was made underground, or fell through: back to the mouth
		var s: Dictionary = sites[idx_for_x(p.x)]
		var out: Vector3 = s["pos"] + (s["face"] as Vector3) * 3.8
		main.player.teleport(Vector3(out.x, world.height_at(out.x, out.z) + 0.3, out.z))
	elif not in_zone and _inside >= 0:
		_cleanup()
	if _inside >= 0:
		for l in _flick:
			(l as OmniLight3D).light_energy = float((l as OmniLight3D).get_meta("base", 1.5)) * (1.0 + 0.12 * sin(_t * 9.0 + l.position.x * 3.0) + 0.07 * sin(_t * 17.0 + l.position.z * 5.0))
	else:
		var disc := discovered()
		for s: Dictionary in sites:
			var i := int(s["idx"])
			if disc.has(i):
				continue
			var pos: Vector3 = s["pos"]
			if Vector2(p.x - pos.x, p.z - pos.z).length() < 38.0:
				disc.append(i)
				main.ui.toast("A cave: %s" % DEFS[i]["name"])
