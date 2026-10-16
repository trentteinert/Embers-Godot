@tool
class_name Models
extends RefCounted
## Low-poly 3D models built from simple shapes: heroes, NPCs, every creature and Warden,
## pickups, and the tree/rock meshes used for scenery. Everything is flat-coloured and chunky
## on purpose. Characters come back as a Rig (see rig.gd) so they can animate.
##
## Tweak a look by editing the colour tables or the builder for that creature.

const HEROES := {
	"warrior": {"skin": "e8b48a", "shirt": "b8342c", "shirt2": "7a2020", "sleeve": "8c96a3", "pants": "4a3a4a", "boots": "3a3446",
		"head": "helm", "metal": "a3adba", "plume": "b8342c", "trim": "d8b04a", "weapon_r": "sword", "weapon_l": "shield", "pauldrons": true},
	"rogue": {"skin": "e8b48a", "shirt": "3d4452", "shirt2": "2a2f3a", "sleeve": "2a2f3a", "pants": "2a2830", "boots": "1f222b",
		"head": "hood", "hood": "2f3340", "mask": "7a1e2c", "trim": "7a1e2c", "weapon_r": "dagger", "weapon_l": "dagger", "cape": "22252e", "metal": "c9ced6"},
	"mage": {"skin": "e8b48a", "shirt": "5b3c9e", "shirt2": "3e2a70", "sleeve": "5b3c9e", "pants": "3e2a70", "boots": "2a2434",
		"head": "wizard", "hat": "5b3c9e", "trim": "e0c060", "beard": "f4f2ea", "robe": "5b3c9e", "weapon_r": "staff", "orb": "b080ff"},
	"hunter": {"skin": "e8b48a", "shirt": "4f7a3a", "shirt2": "3a5a2c", "sleeve": "3a5a2c", "pants": "5a4a30", "boots": "3a3446",
		"head": "hood", "hood": "3f6b3a", "hair": "8a5a30", "feather": "e05a4a", "trim": "c8a050", "weapon_l": "bow", "quiver": true, "cape": "3a5a2c"},
	"merchant": {"skin": "e8b48a", "shirt": "a0603a", "shirt2": "7a4428", "sleeve": "a0603a", "pants": "4a3a3a", "boots": "3a2a2a",
		"head": "wide", "hat": "6b4a2c", "trim": "e0c060", "beard": "5a3a20", "apron": "e8dcc0", "pack": true},
	"farmer": {"skin": "e8b48a", "shirt": "6a8ac0", "shirt2": "4a6a9a", "sleeve": "6a8ac0", "pants": "6a5a40", "boots": "4a3a2a",
		"head": "wide", "hat": "e0c870", "trim": "b8a050", "hair": "8a6a40", "weapon_r": "pitchfork"},
	"ranger": {"skin": "e0a878", "shirt": "3e6a4a", "shirt2": "2c4c34", "sleeve": "2c4c34", "pants": "4a3a2a", "boots": "3a2a20",
		"head": "hood", "hood": "2f5a34", "hair": "c07040", "weapon_l": "bow", "quiver": true},
	"hermit": {"skin": "d8b090", "shirt": "5a5a48", "shirt2": "3e3e32", "sleeve": "5a5a48", "pants": "3a3a30", "boots": "2a2a24",
		"head": "hood", "hood": "4a4a3a", "beard": "f4f2ea", "robe": "5a5a48", "weapon_r": "lantern", "orb": "ffd27a"},
	"pilgrim": {"skin": "e8b48a", "shirt": "c8d0dc", "shirt2": "9aa4b0", "sleeve": "c8d0dc", "pants": "6a6a78", "boots": "4a4a58",
		"head": "bare", "hair": "e0d0b0", "trim": "6a8ac0", "robe": "c8d0dc", "weapon_r": "walking"},
	"smith": {"skin": "e0a070", "shirt": "8a3a2a", "shirt2": "6a2a20", "sleeve": "e0a070", "pants": "3a3030", "boots": "2a2424",
		"head": "bare", "hair": "c8642a", "beard": "c8642a", "apron": "5a4030", "weapon_r": "hammer"},
	"elder": {"skin": "e0b090", "shirt": "6a5a8a", "shirt2": "4a3e66", "sleeve": "6a5a8a", "pants": "4a3e56", "boots": "2a2434",
		"head": "bare", "hair": "f0ece0", "beard": "f0ece0", "trim": "d8b04a", "robe": "6a5a8a", "weapon_r": "walking"},
	"king": {"skin": "e0b090", "shirt": "8a2a3a", "shirt2": "5e1a28", "sleeve": "8a2a3a", "pants": "3a2a3a", "boots": "2a2024",
		"head": "crown", "hair": "d8d0c0", "beard": "d8d0c0", "trim": "e8c048", "robe": "8a2a3a", "weapon_r": "walking"},
	"tam": {"skin": "d8a880", "shirt": "8a5a3a", "shirt2": "6a4228", "sleeve": "8a5a3a", "pants": "4a4030", "boots": "3a2a20",
		"head": "wide", "hat": "7a6a48", "trim": "b8a050", "beard": "c8c0b0", "weapon_r": "walking"},
	"slayer": {"skin": "c8946a", "shirt": "4a2228", "shirt2": "321418", "sleeve": "2a2228", "pants": "2a2228", "boots": "1f1a20",
		"head": "hood", "hood": "3a1a20", "mask": "1f1a20", "trim": "a02a3a", "weapon_r": "sword", "cape": "5a1a22", "metal": "9aa0aa", "pauldrons": true},
}

static var _mesh_cache := {}


# ================================================================ shape helpers
static func _box_mesh(size: Vector3) -> BoxMesh:
	var key := "b%s" % size
	if not _mesh_cache.has(key):
		var b := BoxMesh.new()
		b.size = size
		_mesh_cache[key] = b
	return _mesh_cache[key]


static func _cyl_mesh(top: float, bottom: float, h: float, segs: int) -> CylinderMesh:
	var key := "c%s_%s_%s_%d" % [top, bottom, h, segs]
	if not _mesh_cache.has(key):
		var c := CylinderMesh.new()
		c.top_radius = top
		c.bottom_radius = bottom
		c.height = h
		c.radial_segments = segs
		c.rings = 1
		_mesh_cache[key] = c
	return _mesh_cache[key]


static func _sph_mesh(r: float, segs: int, rings: int) -> SphereMesh:
	var key := "s%s_%d_%d" % [r, segs, rings]
	if not _mesh_cache.has(key):
		var s := SphereMesh.new()
		s.radius = r
		s.height = r * 2.0
		s.radial_segments = segs
		s.rings = rings
		_mesh_cache[key] = s
	return _mesh_cache[key]


## A faceted solid of revolution (oval rings stacked up y), flat-shaded: the chunky old-school look.
## rings: [y, rx, rz] or [y, rx, rz, ox, oz], ordered top to bottom or bottom to top.
static func _lathe_mesh(rings: Array, segs: int) -> ArrayMesh:
	var key := "l%s_%d" % [str(rings), segs]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: Array = []
	for r: Array in rings:
		var row: Array = []
		var ox: float = r[3] if r.size() > 3 else 0.0
		var oz: float = r[4] if r.size() > 4 else 0.0
		for i in segs:
			var a := TAU * float(i) / float(segs) + TAU / float(segs) * 0.5
			row.append(Vector3(ox + cos(a) * float(r[1]), float(r[0]), oz + sin(a) * float(r[2])))
		pts.append(row)
	for k in range(pts.size() - 1):
		for i in segs:
			var j := (i + 1) % segs
			var a: Vector3 = pts[k][i]
			var b: Vector3 = pts[k][j]
			var c: Vector3 = pts[k + 1][j]
			var d: Vector3 = pts[k + 1][i]
			var ctr := (a + b + c + d) * 0.25
			var axis := Vector3(ctr.x - (a.x + b.x + c.x + d.x) * 0.25 + (float(rings[k][3]) if rings[k].size() > 3 else 0.0), ctr.y, (float(rings[k][4]) if rings[k].size() > 4 else 0.0))
			var out := Vector3(ctr.x - axis.x, 0, ctr.z - axis.z)
			_tri_o(st, a, b, c, out)
			_tri_o(st, a, c, d, out)
	for end in [0, pts.size() - 1]:
		var row: Array = pts[end]
		var ctr := Vector3.ZERO
		for p: Vector3 in row:
			ctr += p
		ctr /= float(segs)
		var up := Vector3(0, 1.0 if end == pts.size() - 1 else -1.0, 0)
		if pts.size() > 1 and (pts[0][0] as Vector3).y > (pts[pts.size() - 1][0] as Vector3).y:
			up = -up
		for i in segs:
			_tri_o(st, row[i], row[(i + 1) % segs], ctr, up)
	st.generate_normals()
	var m := st.commit()
	_mesh_cache[key] = m
	return m


static func _tri_o(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, out: Vector3) -> void:
	# Godot front faces wind clockwise seen from outside, so the cross product must point inward
	if (b - a).cross(c - a).dot(out) > 0.0:
		var t := b
		b = c
		c = t
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)


static func lathe(rig: Rig, parent: Node3D, rings: Array, col: Variant, pos := Vector3.ZERO, scl := Vector3.ONE, segs := 8, rot := Vector3.ZERO, emit := 0.0) -> MeshInstance3D:
	return _add(rig, parent, _lathe_mesh(rings, segs), _c(col), pos, rot, emit, scl)


static func _add(rig: Rig, parent: Node3D, mesh: Mesh, col: Color, pos: Vector3, rot := Vector3.ZERO, emit := 0.0, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = rig.mat(col, emit)
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi


static func box(rig: Rig, parent: Node3D, size: Vector3, col: Variant, pos: Vector3, rot := Vector3.ZERO, emit := 0.0) -> MeshInstance3D:
	return _add(rig, parent, _box_mesh(size), _c(col), pos, rot, emit)


static func cyl(rig: Rig, parent: Node3D, top: float, bottom: float, h: float, col: Variant, pos: Vector3, rot := Vector3.ZERO, segs := 6, emit := 0.0) -> MeshInstance3D:
	return _add(rig, parent, _cyl_mesh(top, bottom, h, segs), _c(col), pos, rot, emit)


static func ball(rig: Rig, parent: Node3D, r: float, col: Variant, pos: Vector3, scl := Vector3.ONE, segs := 8, rings := 4, emit := 0.0) -> MeshInstance3D:
	return _add(rig, parent, _sph_mesh(r, segs, rings), _c(col), pos, Vector3.ZERO, emit, scl)


static func pivot(rig: Rig, parent: Node3D, part_name: String, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = part_name
	n.position = pos
	parent.add_child(n)
	rig.add_part(part_name, n)
	return n


static func _c(v: Variant) -> Color:
	return v if v is Color else Color(String(v))


# ================================================================ character creation
const HAIR_STYLES := [["short", "Short"], ["buzz", "Buzzed"], ["bald", "Bald"], ["shaggy", "Shaggy"], ["mohawk", "Mohawk"], ["long", "Long"],
	["ponytail", "Ponytail"], ["bun", "Bun"], ["bob", "Bob"], ["braid", "Braid"], ["spiky", "Spiky"], ["slick", "Slicked back"], ["curly", "Curly"],
	["topknot", "Topknot"], ["pigtails", "Pigtails"], ["sidepart", "Side part"]]
const FACIAL_STYLES := [["none", "Clean"], ["stubble", "Stubble"], ["stache", "Mustache"], ["goatee", "Goatee"], ["beard", "Full beard"]]
const SKIN_TONES := ["f6d3b3", "e8b48a", "d49a6a", "b5774a", "8a5a3a", "5e3b26", "f0c8c0", "c8d8c0"]
const HAIR_COLORS := ["1c1814", "3a2616", "5a3a22", "8a5a30", "c07a3a", "d8b060", "e8e0c8", "9a9aa0", "a02a2a", "3a5aa0", "5a3a8a", "3a8a5a"]
const EYE_COLORS := ["1a1420", "3a5a8a", "3a7a4a", "6a4a2a", "7a7a8a", "8a3a8a", "c0402a"]
const CLOTH_COLORS := ["b8342c", "d8802a", "d8b04a", "6a9a3a", "3a8a5a", "3a8a9a", "3a5aa0", "5b3c9e", "9a4a8a", "e8e0d0", "8a8a90", "3a3a44", "5a4030", "8f8c4c"]
const NAME_START := ["Ash", "Bram", "Cael", "Dun", "Eli", "Fen", "Gar", "Hal", "Isa", "Jor", "Kes", "Lyra", "Mor", "Nyx", "Oda", "Per", "Rhea", "Sef", "Tam", "Ulf", "Vael", "Wren", "Yara", "Zeph"]
const NAME_END := ["a", "ar", "beth", "dric", "en", "grim", "hild", "ia", "ik", "ira", "la", "mond", "na", "orn", "ric", "sa", "thorn", "wyn", "wick", "yn"]


static func random_name() -> String:
	return String(NAME_START[randi() % NAME_START.size()]) + String(NAME_END[randi() % NAME_END.size()])


static func default_look(id: String) -> Dictionary:
	var hair: String = {"warrior": "5a3a22", "rogue": "1c1814", "mage": "e8e0c8", "hunter": "8a5a30"}.get(id, "5a3a22")
	var shirt: String = {"warrior": "b8342c", "rogue": "3a3a44", "mage": "5b3c9e", "hunter": "6a9a3a"}.get(id, "8f8c4c")
	return {"body": "a", "skin": "e8b48a", "hair_style": "short", "hair": hair, "facial": "none", "eye": "1a1420",
		"shirt": shirt, "pants": "5a4030", "boots": "3a3446", "belt": "7a2222"}


static func random_look(id: String) -> Dictionary:
	var l := default_look(id)
	l["body"] = "a" if randf() < 0.5 else "b"
	l["skin"] = SKIN_TONES[randi() % SKIN_TONES.size()]
	l["hair_style"] = HAIR_STYLES[randi() % HAIR_STYLES.size()][0]
	l["hair"] = HAIR_COLORS[randi() % HAIR_COLORS.size()]
	l["facial"] = FACIAL_STYLES[randi() % FACIAL_STYLES.size()][0] if l["body"] == "a" else "none"
	l["eye"] = EYE_COLORS[randi() % EYE_COLORS.size()]
	for k in ["shirt", "pants", "boots", "belt"]:
		l[k] = CLOTH_COLORS[randi() % CLOTH_COLORS.size()]
	return l


# ================================================================ humanoids
static func hero(id: String) -> Rig:
	return humanoid(HEROES[id])


## The hero as dressed: equip is slot -> item. Armor type (plate/mail/leather/cloth) sets the
## cut, the item's material tier the colour, its rarity the trim. Empty slots show plain clothes.
static func hero_geared(id: String, equip: Dictionary, look := {}) -> Rig:
	var cfg: Dictionary = (HEROES[id] as Dictionary).duplicate()
	var skin: String = cfg.get("skin", "e8b48a")
	var hair: String = cfg.get("hair", "6a4a2a")
	# plain clothes first
	cfg["shirt"] = "8f8c4c"
	cfg["shirt2"] = "8f8c4c"
	cfg["sleeve"] = "8f8c4c"
	cfg["pants"] = "3f7d3c"
	cfg["boots"] = "6a4a30"
	cfg["belt"] = "7a2222"
	cfg["cuff"] = "8a9097"
	cfg["head"] = "bare"
	cfg["hair"] = {"warrior": "5a3a22", "rogue": "24202a", "mage": "d8d4cc", "hunter": "8a5a30"}.get(id, hair)
	if id == "warrior":
		cfg["goatee"] = "5a3a22"
	for k in ["robe", "pauldrons", "cape", "hood", "hat", "plume", "mask", "beard", "feather", "quiver"]:
		cfg.erase(k)
	cfg["trim"] = "8a7a60"
	cfg["metal"] = "a3adba"
	var wep: Dictionary = equip.get("weapon", {})
	var off: Dictionary = equip.get("offhand", {})
	if id == "rogue":
		# dual wield: main hand right, off-hand left, whatever one-handers they are
		cfg["weapon_r"] = String(wep.get("type", "")) if not wep.is_empty() else ""
		cfg["weapon_l"] = String(off.get("type", "")) if not off.is_empty() else ""
		cfg["wmetal"] = _tier_col(wep if not wep.is_empty() else off, "plate").to_html(false)
		if not off.is_empty():
			cfg["wmetal_l"] = _tier_col(off, "plate").to_html(false)
	elif wep.is_empty():
		cfg["weapon_r"] = ""
		cfg["weapon_l"] = ""
	else:
		cfg["wmetal"] = _tier_col(wep, "plate").to_html(false)
	if cfg.get("weapon_l", "") == "shield":
		cfg["weapon_l"] = "shield" if String(off.get("type", "")) == "shield" else ""
		# the shield keeps its own look (not the chest's or the helm's colours) until you find one with a different look:
		# plain grey metal with a red face; a better shield takes its tier's metal and its rarity's colour
		cfg["shield_metal"] = "8c96a3"
		cfg["shield_face"] = "b8342c"
		cfg["shield_trim"] = "d8b04a"
		if not off.is_empty() and int(off.get("ilvl", 1)) > 4:
			cfg["shield_metal"] = _tier_col(off, "plate").to_html(false)
			if int(off.get("rarity", 0)) > 0:
				cfg["shield_face"] = Items.RARITY_COLORS[int(off["rarity"])]
	var ch: Dictionary = equip.get("chest", {})
	if not ch.is_empty():
		var a: String = ch.get("armor", Items.ARMOR_FOR[id])
		var c := _tier_col(ch, a)
		var rc := Color(Items.RARITY_COLORS[int(ch["rarity"])])
		cfg["longsleeve"] = true
		cfg["cuff"] = ""
		match a:
			"plate":
				cfg["shirt"] = c.to_html(false)
				cfg["shirt2"] = c.lightened(0.28).to_html(false)
				cfg["sleeve"] = c.darkened(0.12).to_html(false)
				cfg["pauldrons"] = true
				cfg["metal"] = c.to_html(false)
			"mail":
				cfg["shirt"] = c.darkened(0.08).to_html(false)
				cfg["shirt2"] = c.lightened(0.12).to_html(false)
				cfg["sleeve"] = c.darkened(0.08).to_html(false)
			"leather":
				cfg["shirt"] = c.to_html(false)
				cfg["shirt2"] = c.darkened(0.25).to_html(false)
				cfg["sleeve"] = c.darkened(0.12).to_html(false)
				cfg["cape"] = c.darkened(0.35).to_html(false)
			"rags":
				cfg["shirt"] = c.to_html(false)
				cfg["shirt2"] = c.lightened(0.1).to_html(false)
				cfg["sleeve"] = c.darkened(0.06).to_html(false)
			"cloth":
				cfg["robe"] = c.to_html(false)
				cfg["shirt"] = c.to_html(false)
				cfg["shirt2"] = c.lightened(0.2).to_html(false)
				cfg["sleeve"] = c.to_html(false)
		if int(ch["rarity"]) > 0:
			cfg["trim"] = rc.to_html(false)
	if not ch.is_empty():
		cfg["style_chest"] = _style(ch)
	var lg: Dictionary = equip.get("legs", {})
	if not lg.is_empty():
		cfg["style_legs"] = _style(lg)
		cfg["pants"] = _tier_col(lg, lg.get("armor", Items.ARMOR_FOR[id])).to_html(false)
	var ft: Dictionary = equip.get("feet", {})
	if not ft.is_empty():
		cfg["style_feet"] = _style(ft)
		cfg["boots"] = _tier_col(ft, ft.get("armor", Items.ARMOR_FOR[id])).darkened(0.1).to_html(false)
	var hd: Dictionary = equip.get("hands", {})
	if not hd.is_empty():
		cfg["style_hands"] = _style(hd)
		cfg["glove"] = _tier_col(hd, hd.get("armor", Items.ARMOR_FOR[id])).to_html(false)
	var hh: Dictionary = equip.get("head", {})
	if not hh.is_empty():
		cfg["style_head"] = _style(hh)
		var a2: String = hh.get("armor", Items.ARMOR_FOR[id])
		var hc := _tier_col(hh, a2)
		match a2:
			"plate":
				cfg["head"] = "helm"
				cfg["metal"] = hc.to_html(false)
				if int(hh["rarity"]) >= 2:
					cfg["plume"] = Items.RARITY_COLORS[int(hh["rarity"])]
			"mail":
				cfg["head"] = "hood"
				cfg["hood"] = hc.darkened(0.1).to_html(false)
			"leather":
				cfg["head"] = "hood"
				cfg["hood"] = hc.to_html(false)
				cfg["mask"] = hc.darkened(0.4).to_html(false)
			"cloth":
				cfg["head"] = "wizard"
				cfg["hat"] = hc.to_html(false)
				cfg["beard"] = "f4f2ea" if id == "mage" else "d8d0c0"
		if a2 != "plate" and int(hh["rarity"]) > 0:
			cfg["trim"] = Items.RARITY_COLORS[int(hh["rarity"])]
	var am: Dictionary = equip.get("amulet", {})
	if not am.is_empty():
		cfg["amulet"] = Items.RARITY_COLORS[int(am["rarity"])]
	if not look.is_empty():
		_apply_look(cfg, look, equip)
	cfg["bare_top"] = ch.is_empty()
	cfg["bare_legs"] = lg.is_empty()
	cfg["bare_feet"] = ft.is_empty()
	if ch.is_empty():
		cfg["cuff"] = ""
	var skinned: Rig = CharRig.try_build(cfg)   # the skinned character, when its files are in the game
	if skinned != null:
		return skinned
	return humanoid(cfg)


## Character creation choices on top of the dressed config. Clothing colours only show on bare slots; armor wins.
static func _apply_look(cfg: Dictionary, look: Dictionary, equip: Dictionary) -> void:
	cfg["skin"] = look.get("skin", cfg.get("skin", "e8b48a"))
	cfg["hair"] = look.get("hair", cfg.get("hair", "5a3a22"))
	cfg["hair_style"] = look.get("hair_style", "short")
	cfg["eyec"] = look.get("eye", "1a1420")
	if String(look.get("body", "a")) == "b":
		cfg["thin"] = 0.84
		cfg["femme"] = true
	for k in ["goatee", "beard", "stache", "stubble"]:
		cfg.erase(k)
	var hc: String = cfg["hair"]
	match String(look.get("facial", "none")):
		"stubble":
			cfg["stubble"] = _c(cfg["skin"]).lerp(_c(hc), 0.45).to_html(false)
		"stache":
			cfg["stache"] = hc
		"goatee":
			cfg["goatee"] = hc
		"beard":
			cfg["beard"] = hc
	if equip.get("chest", {}).is_empty():
		var sc := _c(look.get("shirt", "8f8c4c"))
		cfg["shirt"] = sc.to_html(false)
		cfg["shirt2"] = sc.lightened(0.15).to_html(false)
		cfg["sleeve"] = sc.darkened(0.08).to_html(false)
	if equip.get("legs", {}).is_empty():
		cfg["pants"] = look.get("pants", "3f7d3c")
	if equip.get("feet", {}).is_empty():
		cfg["boots"] = look.get("boots", "6a4a30")
	if look.has("belt"):
		cfg["belt"] = look["belt"]


## Colour of a piece: material tier tint, shaped by armor type (metal, dull chain, brown leather, dyed cloth).
## Which of the few cuts of a piece of armor this item has (0-3). Standard armor is one shape in different colours with small
## differences like these; an item can name its own with "look" once there are special looks.
static func _style(item: Dictionary) -> int:
	if item.has("look"):
		return int(item["look"]) % 4
	return absi(hash(String(item.get("name", "")))) % 4


static func _tier_col(item: Dictionary, armor: String) -> Color:
	var mat := Color(String(item.get("mat", "b87333")))
	match armor:
		"mail":
			return mat.lerp(Color("7a828c"), 0.55)
		"leather":
			return Color("6b4a2c").lerp(mat, 0.3)
		"cloth":
			var cls_col := Color("5b3c9e")
			return cls_col.lerp(mat, 0.35)
	return mat


static func humanoid(cfg: Dictionary) -> Rig:
	var rig := Rig.new()
	rig.kind = "humanoid"
	var b := rig.body
	var thin: float = cfg.get("thin", 1.0)
	var skin: String = cfg.get("skin", "e8b48a")
	if cfg.get("bare_top", false):
		cfg["shirt"] = skin
		cfg["shirt2"] = _c(skin).lightened(0.05).to_html(false)
		cfg["sleeve"] = skin
		cfg["belt"] = skin
	if cfg.get("bare_legs", false):
		cfg["pants"] = skin
	if cfg.get("bare_feet", false):
		cfg["boots"] = skin
	var robe: String = cfg.get("robe", "")
	var pants: String = cfg.get("pants", "4a3a4a")
	var pants_d := _c(pants).darkened(0.1)
	# legs: square thigh, knee block, shin and boot on their own pivot so the leg really bends
	for side in [-1, 1]:
		var leg := pivot(rig, b, "leg_l" if side < 0 else "leg_r", Vector3(0.12 * side, 0.62, 0))
		box(rig, leg, Vector3(0.17 * thin, 0.28, 0.2 * thin), pants, Vector3(0, -0.13, 0))
		var shin := pivot(rig, leg, "shin_l" if side < 0 else "shin_r", Vector3(0, -0.27, 0))
		box(rig, shin, Vector3(0.176 * thin, 0.1, 0.208 * thin), pants_d, Vector3(0, 0.0, 0))
		box(rig, shin, Vector3(0.16 * thin, 0.24, 0.19 * thin), pants, Vector3(0, -0.12, 0))
		var foot := pivot(rig, shin, "foot_l" if side < 0 else "foot_r", Vector3(0, -0.22, 0))
		box(rig, foot, Vector3(0.19, 0.13, 0.27), cfg.get("boots", "3a3446"), Vector3(0, -0.065, 0.03))
		match int(cfg.get("style_legs", 0)):
			1:   # knee pads
				box(rig, shin, Vector3(0.19 * thin, 0.1, 0.07), _c(pants).lightened(0.15).to_html(false), Vector3(0, 0.02, 0.115 * thin))
			2:   # a stripe down the outside
				box(rig, leg, Vector3(0.025, 0.5, 0.05), cfg.get("trim", "d8b04a"), Vector3(0.09 * side * thin, -0.2, 0.0))
			3:   # turned-up cuffs
				box(rig, shin, Vector3(0.19 * thin, 0.05, 0.215 * thin), _c(pants).lightened(0.2).to_html(false), Vector3(0, -0.22, 0))
		match int(cfg.get("style_feet", 0)):
			1:   # tall boot cuffs
				box(rig, shin, Vector3(0.18 * thin, 0.09, 0.215 * thin), _c(cfg.get("boots", "3a3446")).lightened(0.12).to_html(false), Vector3(0, -0.17, 0))
			2:   # a toe cap
				box(rig, foot, Vector3(0.17, 0.07, 0.09), _c(cfg.get("boots", "3a3446")).lightened(0.18).to_html(false), Vector3(0, -0.09, 0.16))
			3:   # an ankle strap
				box(rig, foot, Vector3(0.2, 0.03, 0.14), cfg.get("trim", "d8b04a"), Vector3(0, -0.01, 0.0))
		leg.visible = robe == ""
	if robe != "":
		cyl(rig, b, 0.24, 0.36, 0.64, robe, Vector3(0, 0.32, 0), Vector3.ZERO, 8)
		if cfg.has("trim"):
			cyl(rig, b, 0.365, 0.37, 0.05, cfg["trim"], Vector3(0, 0.03, 0), Vector3.ZERO, 8)
	else:
		var hip_w := 0.43 * thin if not cfg.get("femme", false) else 0.44
		box(rig, b, Vector3(hip_w, 0.13, 0.27 * thin), "e6e0d4" if cfg.get("bare_legs", false) else pants, Vector3(0, 0.62, 0))   # hips tie the legs to the body
	# torso
	var torso := pivot(rig, b, "torso", Vector3(0, 0.62, 0))
	torso.rotation.x = cfg.get("hunch", 0.0)
	torso.set_meta("hunch", float(cfg.get("hunch", 0.0)))
	if cfg.get("femme", false):
		# narrower waist and shoulders, a little chest, wider hips
		box(rig, torso, Vector3(0.36, 0.26, 0.24), cfg.get("shirt", "888888"), Vector3(0, 0.14, 0))
		box(rig, torso, Vector3(0.4, 0.26, 0.27), cfg.get("shirt", "888888"), Vector3(0, 0.38, 0))
	else:
		box(rig, torso, Vector3(0.46 * thin, 0.5, 0.28 * thin), cfg.get("shirt", "888888"), Vector3(0, 0.27, 0))
	box(rig, torso, Vector3(0.2, 0.42, 0.02), cfg.get("shirt2", "666666"), Vector3(0, 0.27, 0.141 * thin))
	match int(cfg.get("style_chest", 0)):
		1:   # a sash across the chest
			box(rig, torso, Vector3(0.1, 0.62, 0.02), cfg.get("trim", "d8b04a"), Vector3(0.02, 0.27, 0.152 * thin), Vector3(0, 0, 0.55))
		2:   # a breast plate
			box(rig, torso, Vector3(0.34 * thin, 0.27, 0.03), _c(cfg.get("shirt2", "666666")).lightened(0.12).to_html(false), Vector3(0, 0.34, 0.15 * thin))
			box(rig, torso, Vector3(0.36 * thin, 0.04, 0.032), cfg.get("trim", "d8b04a"), Vector3(0, 0.2, 0.15 * thin))
		3:   # a collar and belt pouches
			box(rig, torso, Vector3(0.3, 0.07, 0.3), _c(cfg.get("shirt2", "666666")).lightened(0.08).to_html(false), Vector3(0, 0.5, 0))
			for sd in [-1, 1]:
				box(rig, torso, Vector3(0.1, 0.12, 0.09), cfg.get("belt", "5a3a24"), Vector3(0.27 * sd * thin, -0.02, 0.06))
	box(rig, torso, Vector3(0.48 * thin, 0.07, 0.3 * thin), cfg.get("belt", "5a3a24"), Vector3(0, 0.05, 0))
	if not cfg.get("bare_top", false):
		box(rig, torso, Vector3(0.08, 0.07, 0.02), cfg.get("trim", "d8b04a"), Vector3(0, 0.05, 0.151 * thin))
	box(rig, torso, Vector3(0.14, 0.1, 0.14), skin, Vector3(0, 0.55, 0))   # neck
	box(rig, torso, Vector3(0.58 * thin, 0.12, 0.27 * thin), cfg.get("sleeve", "888888"), Vector3(0, 0.46, 0))   # shoulder line joins the arms to the chest
	if cfg.has("amulet"):
		box(rig, torso, Vector3(0.07, 0.07, 0.03), cfg["amulet"], Vector3(0, 0.42, 0.155 * thin), Vector3.ZERO, 1.6)
	if cfg.has("apron"):
		box(rig, torso, Vector3(0.3, 0.55, 0.03), cfg["apron"], Vector3(0, 0.12, 0.16))
	if cfg.get("pack", false):
		box(rig, torso, Vector3(0.36, 0.42, 0.2), "6b4a2c", Vector3(0, 0.3, -0.24))
		cyl(rig, torso, 0.08, 0.08, 0.38, "b8443a", Vector3(0, 0.56, -0.24), Vector3(0, 0, PI * 0.5))
	if cfg.get("quiver", false):
		var q := box(rig, torso, Vector3(0.14, 0.5, 0.14), "6b4a2c", Vector3(0.1, 0.35, -0.2), Vector3(0, 0, 0.4))
		for k in 3:
			box(rig, q, Vector3(0.04, 0.1, 0.04), "e05a4a", Vector3(-0.03 + k * 0.03, 0.3, 0))
	if cfg.has("cape"):
		var cape := pivot(rig, torso, "cape", Vector3(0, 0.5, -0.15))
		box(rig, cape, Vector3(0.44, 0.62, 0.04), cfg["cape"], Vector3(0, -0.31, 0))
	# arms: shoulder block, upper arm, elbow block, forearm, cuff, hand
	var long_sleeve: bool = cfg.get("longsleeve", false)
	var scol: String = cfg.get("sleeve", "888888")
	for side in [-1, 1]:
		var arm := pivot(rig, torso, "arm_l" if side < 0 else "arm_r", Vector3(0.31 * side * thin, 0.46, 0))
		box(rig, arm, Vector3(0.17 * thin, 0.14, 0.19 * thin), scol, Vector3(0, -0.01, 0))
		box(rig, arm, Vector3(0.14 * thin, 0.25, 0.16 * thin), scol, Vector3(0, -0.13, 0))
		var fore := pivot(rig, arm, "forearm_l" if side < 0 else "forearm_r", Vector3(0, -0.24, 0))
		box(rig, fore, Vector3(0.15 * thin, 0.09, 0.17 * thin), scol if long_sleeve else skin, Vector3(0, 0.0, 0))
		if long_sleeve:
			box(rig, fore, Vector3(0.14 * thin, 0.19, 0.16 * thin), scol, Vector3(0, -0.1, 0))
		else:
			box(rig, fore, Vector3(0.12 * thin, 0.19, 0.14 * thin), skin, Vector3(0, -0.1, 0))
		var cuff: String = cfg.get("cuff", "")
		if cuff != "" and not cfg.has("glove"):
			box(rig, fore, Vector3(0.145, 0.05, 0.165), cuff, Vector3(0, -0.15, 0))
		if cfg.has("glove"):
			box(rig, fore, Vector3(0.16, 0.16, 0.18), cfg["glove"], Vector3(0, -0.2, 0))
			match int(cfg.get("style_hands", 0)):
				1:   # a long bracer
					box(rig, fore, Vector3(0.155, 0.12, 0.175), _c(cfg["glove"]).darkened(0.1).to_html(false), Vector3(0, -0.07, 0))
				2:   # a flared cuff
					box(rig, fore, Vector3(0.2, 0.05, 0.22), _c(cfg["glove"]).lightened(0.12).to_html(false), Vector3(0, -0.12, 0))
				3:   # knuckle plates
					box(rig, fore, Vector3(0.14, 0.04, 0.05), cfg.get("trim", "d8b04a"), Vector3(0, -0.27, 0.09))
		else:
			box(rig, fore, Vector3(0.13, 0.12, 0.14), skin, Vector3(0, -0.21, 0))
		if cfg.get("pauldrons", false):
			box(rig, arm, Vector3(0.23, 0.12, 0.25), cfg.get("metal", "dfe5ec"), Vector3(0.02 * side, 0.03, 0))
		var hand := pivot(rig, fore, "hand_l" if side < 0 else "hand_r", Vector3(0, -0.23, 0.03))
		var w: String = cfg.get("weapon_l" if side < 0 else "weapon_r", "")
		if w != "":
			_weapon(rig, hand, arm, w, cfg, side)
	# head
	var head := pivot(rig, torso, "head", Vector3(0, 0.52, 0))
	var hcol: String = cfg.get("bone", skin)
	box(rig, head, Vector3(0.42, 0.38, 0.36), hcol, Vector3(0, 0.19, 0))
	if cfg.get("femme", false):
		head.scale = Vector3.ONE * 0.95
	var eye_col: String = cfg.get("eye", cfg.get("eyec", "1a1420"))
	var glow: float = 1.5 if cfg.has("eye") else 0.0
	var is_skull: bool = cfg.get("head", "") == "skull"
	var eye_size := Vector3(0.09, 0.09, 0.02) if is_skull else Vector3(0.06, 0.08, 0.02)
	for side in [-1, 1]:
		box(rig, head, eye_size, eye_col, Vector3(0.09 * side, 0.21, 0.181), Vector3.ZERO, glow)
		if not is_skull:
			box(rig, head, Vector3(0.04, 0.1, 0.07), _c(hcol).darkened(0.05), Vector3(0.22 * side, 0.18, 0.0))   # ears
	if not is_skull:
		box(rig, head, Vector3(0.07, 0.09, 0.06), _c(hcol).lightened(0.05), Vector3(0, 0.15, 0.195))   # nose
	_headwear(rig, head, cfg)
	if cfg.get("femme", false):
		rig.set_meta("femme", true)
	rig.height = 1.6
	return rig


static func _headwear(rig: Rig, head: Node3D, cfg: Dictionary) -> void:
	match cfg.get("head", "bare"):
		"helm":
			var m: String = cfg.get("metal", "dfe5ec")
			box(rig, head, Vector3(0.47, 0.22, 0.42), m, Vector3(0, 0.34, 0))
			for side in [-1, 1]:
				box(rig, head, Vector3(0.05, 0.22, 0.4), m, Vector3(0.235 * side, 0.18, 0))
			box(rig, head, Vector3(0.05, 0.17, 0.03), m, Vector3(0, 0.2, 0.2))
			box(rig, head, Vector3(0.47, 0.04, 0.43), "8c96a3", Vector3(0, 0.24, 0))
			if cfg.has("plume"):
				box(rig, head, Vector3(0.06, 0.18, 0.34), cfg["plume"], Vector3(0, 0.53, -0.02))
			match int(cfg.get("style_head", 0)):
				1:   # a ridge along the top
					box(rig, head, Vector3(0.07, 0.07, 0.4), _c(m).lightened(0.15).to_html(false), Vector3(0, 0.47, 0))
				2:   # a nose guard
					box(rig, head, Vector3(0.05, 0.2, 0.03), _c(m).lightened(0.1).to_html(false), Vector3(0, 0.2, 0.23))
				3:   # little horns
					for sd in [-1, 1]:
						box(rig, head, Vector3(0.06, 0.2, 0.06), "e8e0c8", Vector3(0.27 * sd, 0.5, 0), Vector3(0, 0, -0.5 * sd))
		"hood":
			var h: String = cfg.get("hood", "444444")
			box(rig, head, Vector3(0.5, 0.1, 0.44), h, Vector3(0, 0.42, -0.01))
			for side in [-1, 1]:
				box(rig, head, Vector3(0.06, 0.42, 0.42), h, Vector3(0.25 * side, 0.2, -0.02))
			box(rig, head, Vector3(0.5, 0.44, 0.06), h, Vector3(0, 0.2, -0.21))
			box(rig, head, Vector3(0.2, 0.16, 0.16), h, Vector3(0, 0.4, -0.27), Vector3(0.6, 0, 0))
			match int(cfg.get("style_head", 0)):
				1:   # a long pointed tip
					box(rig, head, Vector3(0.12, 0.14, 0.3), h, Vector3(0, 0.34, -0.42), Vector3(0.9, 0, 0))
				2:   # a trim band
					box(rig, head, Vector3(0.51, 0.04, 0.45), _c(h).lightened(0.25).to_html(false), Vector3(0, 0.36, -0.01))
				3:   # a face wrap
					box(rig, head, Vector3(0.43, 0.1, 0.06), _c(h).darkened(0.1).to_html(false), Vector3(0, 0.08, 0.185))
			if cfg.has("hair") and cfg.get("hair_style", "short") != "bald":
				box(rig, head, Vector3(0.38, 0.06, 0.03), cfg["hair"], Vector3(0, 0.34, 0.18))
				_hair(rig, head, String(cfg.get("hair_style", "short")), cfg["hair"], false)
			if cfg.has("feather"):
				box(rig, head, Vector3(0.04, 0.26, 0.08), cfg["feather"], Vector3(0.22, 0.5, -0.05), Vector3(0, 0, -0.4))
		"wizard":
			var hat: String = cfg.get("hat", "5b3c9e")
			cyl(rig, head, 0.42, 0.42, 0.04, hat, Vector3(0, 0.4, 0), Vector3.ZERO, 8)
			cyl(rig, head, 0.27, 0.27, 0.06, cfg.get("trim", "e0c060"), Vector3(0, 0.45, 0), Vector3.ZERO, 8)
			cyl(rig, head, 0.0, 0.26, 0.62, hat, Vector3(0, 0.76, -0.04), Vector3(-0.18, 0, 0), 6)
			match int(cfg.get("style_head", 0)):
				1:   # a bent tip
					cyl(rig, head, 0.0, 0.1, 0.3, hat, Vector3(0, 1.1, -0.17), Vector3(-0.9, 0, 0), 5)
				2:   # a feather
					box(rig, head, Vector3(0.04, 0.3, 0.07), "e8e0c8", Vector3(0.22, 0.6, 0.05), Vector3(0, 0, -0.5))
				3:   # a buckle band
					box(rig, head, Vector3(0.08, 0.06, 0.04), "e8c048", Vector3(0, 0.45, 0.28))
		"wide":
			var hat2: String = cfg.get("hat", "6b4a2c")
			cyl(rig, head, 0.44, 0.44, 0.04, hat2, Vector3(0, 0.4, 0), Vector3.ZERO, 8)
			cyl(rig, head, 0.22, 0.24, 0.2, hat2, Vector3(0, 0.51, 0), Vector3.ZERO, 8)
			cyl(rig, head, 0.245, 0.245, 0.05, cfg.get("trim", "e0c060"), Vector3(0, 0.44, 0), Vector3.ZERO, 8)
		"skull":
			box(rig, head, Vector3(0.36, 0.08, 0.04), "2a2030", Vector3(0, 0.07, 0.17))
		"crown":
			var gold: String = cfg.get("trim", "e8c048")
			if cfg.has("hair"):
				box(rig, head, Vector3(0.44, 0.08, 0.39), cfg["hair"], Vector3(0, 0.37, -0.005))
				box(rig, head, Vector3(0.44, 0.3, 0.07), cfg["hair"], Vector3(0, 0.25, -0.17))
			box(rig, head, Vector3(0.47, 0.1, 0.42), gold, Vector3(0, 0.46, 0))
			for cx in [-0.18, 0.0, 0.18]:
				box(rig, head, Vector3(0.09, 0.12, 0.09), gold, Vector3(cx, 0.56, 0.14))
				box(rig, head, Vector3(0.09, 0.12, 0.09), gold, Vector3(cx, 0.56, -0.14))
			box(rig, head, Vector3(0.05, 0.05, 0.03), "d8304a", Vector3(0, 0.47, 0.215))
		"bare":
			if cfg.has("hair"):
				_hair(rig, head, String(cfg.get("hair_style", "short")), cfg["hair"], true)
	if cfg.has("stubble"):
		box(rig, head, Vector3(0.38, 0.13, 0.02), cfg["stubble"], Vector3(0, 0.05, 0.181))
	if cfg.has("stache"):
		box(rig, head, Vector3(0.18, 0.04, 0.04), cfg["stache"], Vector3(0, 0.12, 0.195))
	if cfg.has("goatee"):
		box(rig, head, Vector3(0.1, 0.1, 0.05), cfg["goatee"], Vector3(0, 0.05, 0.15), Vector3(-0.2, 0, 0))
		box(rig, head, Vector3(0.14, 0.03, 0.03), cfg["goatee"], Vector3(0, 0.1, 0.17))
	if cfg.has("beard"):
		box(rig, head, Vector3(0.32, 0.22, 0.08), cfg["beard"], Vector3(0, 0.04, 0.18))
		box(rig, head, Vector3(0.24, 0.05, 0.03), cfg["beard"], Vector3(0, 0.13, 0.2))
	if cfg.has("mask"):
		box(rig, head, Vector3(0.43, 0.13, 0.03), cfg["mask"], Vector3(0, 0.09, 0.185))


static func _hair(rig: Rig, head: Node3D, style: String, col: Variant, full: bool) -> void:
	# full: the top of the head is bare, so draw the crown and fringe too. Otherwise only what hangs out of headwear.
	if style == "bald":
		return
	var tail := style in ["long", "ponytail", "bob", "braid", "bun", "pigtails"]
	if not full:
		if not tail:
			return
	else:
		match style:
			"buzz":
				box(rig, head, Vector3(0.43, 0.05, 0.38), col, Vector3(0, 0.375, -0.005))
				box(rig, head, Vector3(0.43, 0.14, 0.03), col, Vector3(0, 0.3, -0.18))
				return
			"mohawk":
				box(rig, head, Vector3(0.08, 0.14, 0.38), col, Vector3(0, 0.45, -0.01))
				box(rig, head, Vector3(0.08, 0.22, 0.05), col, Vector3(0, 0.3, -0.19))
				return
			"spiky":
				box(rig, head, Vector3(0.43, 0.06, 0.38), col, Vector3(0, 0.375, -0.005))
				box(rig, head, Vector3(0.43, 0.16, 0.03), col, Vector3(0, 0.3, -0.18))
				for sp: Array in [[-0.15, 0.1, 0.0], [0.0, 0.16, 0.0], [0.15, 0.1, 0.0], [-0.08, 0.12, -0.12], [0.08, 0.12, -0.12], [0.0, 0.1, 0.12]]:
					box(rig, head, Vector3(0.09, 0.1 + float(sp[1]), 0.09), col, Vector3(float(sp[0]), 0.4 + float(sp[1]) * 0.5, float(sp[2])))
				return
			"curly":
				box(rig, head, Vector3(0.5, 0.18, 0.44), col, Vector3(0, 0.42, -0.02))
				box(rig, head, Vector3(0.5, 0.34, 0.1), col, Vector3(0, 0.22, -0.2))
				for side in [-1, 1]:
					box(rig, head, Vector3(0.07, 0.26, 0.34), col, Vector3(0.255 * side, 0.27, -0.02))
				return
			"topknot":
				box(rig, head, Vector3(0.43, 0.05, 0.38), col, Vector3(0, 0.375, -0.005))
				box(rig, head, Vector3(0.43, 0.14, 0.03), col, Vector3(0, 0.3, -0.18))
				box(rig, head, Vector3(0.15, 0.16, 0.15), col, Vector3(0, 0.5, -0.02))
				box(rig, head, Vector3(0.17, 0.04, 0.17), "8a2a2a", Vector3(0, 0.42, -0.02))
				return
			"slick":
				box(rig, head, Vector3(0.44, 0.1, 0.39), col, Vector3(0, 0.385, -0.005))
				box(rig, head, Vector3(0.44, 0.3, 0.07), col, Vector3(0, 0.25, -0.17))
				box(rig, head, Vector3(0.46, 0.06, 0.1), col, Vector3(0, 0.43, 0.14), Vector3(-0.3, 0, 0))
				return
			"sidepart":
				box(rig, head, Vector3(0.44, 0.1, 0.39), col, Vector3(0, 0.385, -0.005))
				box(rig, head, Vector3(0.44, 0.3, 0.07), col, Vector3(0, 0.25, -0.17))
				box(rig, head, Vector3(0.26, 0.12, 0.04), col, Vector3(0.1, 0.33, 0.19))
				box(rig, head, Vector3(0.05, 0.22, 0.2), col, Vector3(0.235, 0.26, 0.06))
				return
			_:
				box(rig, head, Vector3(0.44, 0.1, 0.39), col, Vector3(0, 0.385, -0.005))
				box(rig, head, Vector3(0.44, 0.3, 0.07), col, Vector3(0, 0.25, -0.17))
				box(rig, head, Vector3(0.43, 0.05 if style != "shaggy" else 0.1, 0.03), col, Vector3(0, 0.345 if style != "shaggy" else 0.32, 0.185))
	match style:
		"shaggy":
			if full:
				for side in [-1, 1]:
					box(rig, head, Vector3(0.06, 0.22, 0.3), col, Vector3(0.235 * side, 0.27, 0.0))
		"long":
			box(rig, head, Vector3(0.46, 0.56, 0.07), col, Vector3(0, 0.08, -0.2))
			if full:
				for side in [-1, 1]:
					box(rig, head, Vector3(0.05, 0.34, 0.22), col, Vector3(0.235 * side, 0.2, -0.05))
		"bob":
			box(rig, head, Vector3(0.46, 0.3, 0.07), col, Vector3(0, 0.12, -0.2))
			if full:
				for side in [-1, 1]:
					box(rig, head, Vector3(0.05, 0.26, 0.24), col, Vector3(0.235 * side, 0.2, -0.04))
		"ponytail":
			box(rig, head, Vector3(0.1, 0.1, 0.1), "8a2a2a", Vector3(0, 0.34, -0.22))
			box(rig, head, Vector3(0.12, 0.36, 0.1), col, Vector3(0, 0.12, -0.26), Vector3(0.18, 0, 0))
		"braid":
			box(rig, head, Vector3(0.12, 0.22, 0.09), col, Vector3(0, 0.22, -0.23))
			box(rig, head, Vector3(0.1, 0.22, 0.08), col, Vector3(0, 0.0, -0.25))
			box(rig, head, Vector3(0.08, 0.08, 0.07), "8a2a2a", Vector3(0, -0.14, -0.25))
		"bun":
			box(rig, head, Vector3(0.18, 0.16, 0.16), col, Vector3(0, 0.46, -0.1))
		"pigtails":
			for side in [-1, 1]:
				box(rig, head, Vector3(0.09, 0.09, 0.09), "8a2a2a", Vector3(0.23 * side, 0.3, -0.12))
				box(rig, head, Vector3(0.1, 0.34, 0.1), col, Vector3(0.24 * side, 0.1, -0.13), Vector3(0, 0, 0.12 * side))


## Tools that appear in the hands while skilling: returns [right-hand tool, left-hand tool or null].
static func work_tools(rig: Rig, kind: String, col: String) -> Array:
	var wood := "6b4a2c"
	var r := Node3D.new()
	r.rotation.x = 1.2
	var l: Node3D = null
	match kind:
		"chop":
			cyl(rig, r, 0.03, 0.03, 0.9, wood, Vector3(0, 0.3, 0))
			box(rig, r, Vector3(0.05, 0.22, 0.28), col, Vector3(0, 0.74, 0.11))
			box(rig, r, Vector3(0.07, 0.1, 0.07), "4a4a54", Vector3(0, 0.74, -0.04))
		"mine":
			cyl(rig, r, 0.03, 0.03, 0.9, wood, Vector3(0, 0.3, 0))
			# the head lies in the swing plane (front to back), so the tip is what meets the rock
			box(rig, r, Vector3(0.07, 0.07, 0.6), col, Vector3(0, 0.76, 0))
			box(rig, r, Vector3(0.07, 0.07, 0.18), col, Vector3(0, 0.7, 0.3), Vector3(0.55, 0, 0))
			box(rig, r, Vector3(0.07, 0.07, 0.18), col, Vector3(0, 0.7, -0.3), Vector3(-0.55, 0, 0))
		"smith":
			cyl(rig, r, 0.03, 0.03, 0.55, wood, Vector3(0, 0.2, 0))
			box(rig, r, Vector3(0.26, 0.14, 0.14), "4a4a54", Vector3(0, 0.52, 0))
		"fish":
			r.rotation.x = 0.55
			cyl(rig, r, 0.012, 0.028, 1.6, "8a6a44", Vector3(0, 0.55, 0))
			box(rig, r, Vector3(0.05, 0.07, 0.05), "55555e", Vector3(0.05, 0.0, 0))
			var tip := Node3D.new()
			tip.name = "Tip"
			tip.position = Vector3(0, 1.35, 0)
			r.add_child(tip)
			var line := Node3D.new()
			line.position = Vector3(0, 0, 0)
			tip.add_child(line)
			box(rig, line, Vector3(0.008, 1.1, 0.008), "e8e0c8", Vector3(0, -0.55, 0))
			ball(rig, line, 0.045, "d9483b", Vector3(0, -1.1, 0), Vector3.ONE, 6, 3)
		"cook":
			r.rotation.x = 0.9
			cyl(rig, r, 0.02, 0.02, 0.7, wood, Vector3(0, 0.25, 0))
			cyl(rig, r, 0.09, 0.06, 0.07, "8a9097", Vector3(0, 0.62, 0))
		"brew":
			r.rotation.x = 0.7
			cyl(rig, r, 0.025, 0.04, 0.3, "d8d0c0", Vector3(0, 0.1, 0))
			ball(rig, r, 0.045, "d8d0c0", Vector3(0, 0.27, 0), Vector3.ONE, 6, 3)
			l = Node3D.new()
			l.rotation.x = 0.5
			cyl(rig, l, 0.14, 0.09, 0.12, "8a8a90", Vector3(0, 0.0, 0.07))
			cyl(rig, l, 0.11, 0.11, 0.012, "3a4a3a", Vector3(0, 0.06, 0.07))
		"craft":
			r.rotation.x = 0.9
			cyl(rig, r, 0.025, 0.025, 0.34, wood, Vector3(0, 0.12, 0))
			box(rig, r, Vector3(0.13, 0.09, 0.09), wood, Vector3(0, 0.33, 0))
			l = Node3D.new()
			l.rotation.x = 0.9
			box(rig, l, Vector3(0.03, 0.22, 0.025), "b0b4bc", Vector3(0, 0.12, 0))
			box(rig, l, Vector3(0.05, 0.08, 0.05), wood, Vector3(0, -0.01, 0))
		_:
			r.free()
			r = null
	return [r, l]


static func _weapon(rig: Rig, hand: Node3D, arm: Node3D, w: String, cfg: Dictionary, side: int) -> void:
	var metal: String = cfg.get("wmetal_l" if side < 0 and cfg.has("wmetal_l") else "wmetal", cfg.get("metal", "dfe5ec"))
	var wood := "6b4a2c"
	var n := Node3D.new()
	n.rotation.x = 1.2
	hand.add_child(n)
	match w:
		"sword":
			box(rig, n, Vector3(0.05, 0.2, 0.05), wood, Vector3(0, 0, 0))
			box(rig, n, Vector3(0.24, 0.05, 0.07), cfg.get("trim", "d8b04a"), Vector3(0, 0.11, 0))
			box(rig, n, Vector3(0.07, 0.72, 0.025), metal, Vector3(0, 0.49, 0))
		"shortsword":
			box(rig, n, Vector3(0.045, 0.15, 0.045), wood, Vector3(0, 0, 0))
			box(rig, n, Vector3(0.2, 0.04, 0.06), cfg.get("trim", "a08040"), Vector3(0, 0.09, 0))
			box(rig, n, Vector3(0.06, 0.5, 0.022), metal, Vector3(0, 0.36, 0))
		"dagger":
			box(rig, n, Vector3(0.045, 0.13, 0.045), wood, Vector3(0, 0, 0))
			box(rig, n, Vector3(0.14, 0.04, 0.05), cfg.get("trim", "a08040"), Vector3(0, 0.07, 0))
			box(rig, n, Vector3(0.05, 0.32, 0.02), metal, Vector3(0, 0.25, 0))
		"staff", "lantern", "walking":
			n.rotation.x = 0.25
			cyl(rig, n, 0.035, 0.035, 1.5, wood, Vector3(0, 0.3, 0))
			if w == "staff":
				ball(rig, n, 0.11, cfg.get("orb", "b080ff"), Vector3(0, 1.12, 0), Vector3.ONE, 6, 3, 2.2)
				for k in 3:
					box(rig, n, Vector3(0.03, 0.18, 0.03), wood, Vector3(cos(k * 2.1) * 0.08, 1.02, sin(k * 2.1) * 0.08))
			elif w == "lantern":
				box(rig, n, Vector3(0.14, 0.18, 0.14), cfg.get("orb", "ffd27a"), Vector3(0.1, 1.0, 0), Vector3.ZERO, 2.5)
				box(rig, n, Vector3(0.18, 0.03, 0.18), "3a3a30", Vector3(0.1, 1.1, 0))
		"hammer":
			cyl(rig, n, 0.03, 0.03, 0.7, wood, Vector3(0, 0.2, 0))
			box(rig, n, Vector3(0.3, 0.16, 0.16), "4a4a54", Vector3(0, 0.55, 0))
		"pitchfork":
			n.rotation.x = 0.25
			cyl(rig, n, 0.03, 0.03, 1.4, wood, Vector3(0, 0.35, 0))
			box(rig, n, Vector3(0.26, 0.04, 0.04), "9aa4b0", Vector3(0, 1.06, 0))
			for k in 3:
				box(rig, n, Vector3(0.03, 0.22, 0.03), "9aa4b0", Vector3(-0.11 + k * 0.11, 1.18, 0))
		"bow":
			n.rotation.x = 0.0
			for i in range(-2, 3):
				var t := i / 2.0
				box(rig, n, Vector3(0.04, 0.2, 0.05), wood, Vector3(0, i * 0.17, 0.12 * (1.0 - t * t)), Vector3(-t * 0.6, 0, 0))
			box(rig, n, Vector3(0.012, 0.68, 0.012), "e8e0c8", Vector3(0, 0, 0.0))
		"shield":
			n.queue_free()
			var sh := Node3D.new()
			var fa: Node3D = arm.get_node_or_null("forearm_" + ("l" if side < 0 else "r"))
			var mount: Node3D = fa if fa != null else arm
			sh.position = Vector3(-0.16, -0.12, 0.05) if fa != null else Vector3(-0.1, -0.26, 0.04)
			sh.rotation.z = PI * 0.5
			mount.add_child(sh)
			cyl(rig, sh, 0.3, 0.3, 0.06, cfg.get("shield_metal", cfg.get("metal", "8c96a3")), Vector3.ZERO, Vector3.ZERO, 8)
			cyl(rig, sh, 0.22, 0.22, 0.07, cfg.get("shield_face", cfg.get("plume", "b8342c")), Vector3(0, 0.013, 0), Vector3.ZERO, 8)
			ball(rig, sh, 0.06, cfg.get("shield_trim", cfg.get("trim", "d8b04a")), Vector3(0, 0.05, 0), Vector3.ONE, 6, 3)
			rig.add_weapon(sh, mount, side, "shield")
			return
	rig.add_weapon(n, hand, side, w)


# ================================================================ creatures
## Build any creature by its sprite/kind name. pal can override colours: g (main), G (light), e (eyes), a (cloth).
static func creature(id: String, pal := {}) -> Rig:
	match id:
		"slime":
			return blob(pal.get("g", "7bbf5a"), pal.get("G", "c8f08a"), 0.45)
		"wolf":
			return quad({"col": pal.get("g", "7d7a86"), "col2": pal.get("G", "a9a6b2"), "eye": pal.get("e", "f2c14a")})
		"skel":
			return humanoid({"skin": pal.get("g", "e4dcc4"), "bone": pal.get("g", "e4dcc4"), "shirt": pal.get("a", "4a3b2a"), "shirt2": _dark(pal.get("a", "4a3b2a")),
				"sleeve": pal.get("g", "e4dcc4"), "pants": pal.get("a", "4a3b2a"), "boots": "2a2030", "head": "skull", "eye": "ff4a3a", "thin": 0.7,
				"weapon_l": "bow" if pal.get("kind", "") == "archer" else "", "weapon_r": "" if pal.get("kind", "") == "archer" else "staff",
				"orb": pal.get("orb", "9be05a"), "robe": "" if pal.get("kind", "") == "archer" else pal.get("a", "3d5a3a")})
		"beetle":
			return beetle(pal.get("g", "3a6a5a"), pal.get("G", "5aa08a"))
		"puffcap":
			return puffcap()
		"sapling":
			return treant(1.0, "7a5a3a", "4a8a3a")
		"spider":
			return spider(pal.get("g", "3a3040"))
		"leech":
			return worm(pal.get("g", "5a5a3a"), pal.get("G", "7a7a4a"))
		"crone":
			return humanoid({"skin": "a8b890", "shirt": "4a5a40", "shirt2": "34402c", "sleeve": "4a5a40", "robe": "4a5a40", "head": "hood", "hood": "3a4a3a",
				"eye": "e0ff70", "weapon_r": "staff", "orb": "70ff90", "hunch": 0.35})
		"golem":
			return golem(pal.get("g", "8ab0cc"), pal.get("G", "c8e0f0"), pal.get("e", "2a7fd0"))
		"frostwisp":
			return wisp("9fe0ff")
	return blob("ff00ff", "ffffff", 0.4)


static func boss(i: int) -> Rig:
	var r: Rig
	match i:
		0:
			r = quad({"col": "9a6b3f", "col2": "c99a5e", "eye": "ffe27a", "legs": 0.62, "antlers": "f0e2b0"})
			r.scale = Vector3.ONE * 2.0
		1:
			r = treant(2.4, "5a3e28", "2f5a34", "7ad08a")
		2:
			r = blob("4e6b3a", "8fb060", 0.5, true)
			r.scale = Vector3.ONE * 3.2
		3:
			r = quad({"col": "9cc4dc", "col2": "e8f6ff", "eye": "2a7fd0", "len": 1.7, "w": 0.6, "h": 0.55, "legs": 0.42, "spikes": "e8f6ff", "horns": "e8f6ff"})
			r.scale = Vector3.ONE * 2.4
	r.height *= r.scale.y
	return r


static func _dark(hex: String) -> String:
	return Color(hex).darkened(0.3).to_html(false)


static func quad(cfg: Dictionary) -> Rig:
	var rig := Rig.new()
	rig.kind = "quad"
	rig.walk_speed = 11.0
	var b := rig.body
	var col: String = cfg.get("col", "7d7a86")
	var col2: String = cfg.get("col2", "a9a6b2")
	var ln: float = cfg.get("len", 0.95)
	var w: float = cfg.get("w", 0.42)
	var h: float = cfg.get("h", 0.4)
	var lh: float = cfg.get("legs", 0.45)
	var y := lh + h * 0.5
	box(rig, b, Vector3(w, h, ln), col, Vector3(0, y, 0))
	box(rig, b, Vector3(w * 0.8, h * 0.3, ln * 0.8), col2, Vector3(0, y - h * 0.4, 0))
	for leg in [["leg_fl", -1, 1], ["leg_fr", 1, 1], ["leg_bl", -1, -1], ["leg_br", 1, -1]]:
		var p := pivot(rig, b, leg[0], Vector3(w * 0.35 * leg[1], lh, ln * 0.36 * leg[2]))
		box(rig, p, Vector3(w * 0.26, lh, w * 0.26), col, Vector3(0, -lh * 0.5, 0))
		box(rig, p, Vector3(w * 0.3, 0.06, w * 0.34), _dark(col), Vector3(0, -lh + 0.03, 0.02))
	var head := pivot(rig, b, "head", Vector3(0, y + h * 0.35, ln * 0.5))
	box(rig, head, Vector3(w * 0.8, h * 0.8, 0.36), col, Vector3(0, 0, 0.12))
	box(rig, head, Vector3(w * 0.45, h * 0.35, 0.22), col2, Vector3(0, -h * 0.15, 0.36))
	box(rig, head, Vector3(w * 0.15, w * 0.12, 0.05), "1a1420", Vector3(0, -h * 0.05, 0.48))
	for side in [-1, 1]:
		box(rig, head, Vector3(0.05, 0.05, 0.02), cfg.get("eye", "f2c14a"), Vector3(w * 0.22 * side, h * 0.12, 0.305), Vector3.ZERO, 1.5)
		if not cfg.has("antlers") and not cfg.has("horns"):
			box(rig, head, Vector3(0.08, 0.14, 0.06), col, Vector3(w * 0.25 * side, h * 0.5, 0.05), Vector3(0, 0, -0.2 * side))
	if cfg.has("antlers"):
		for side in [-1, 1]:
			var a := Node3D.new()
			a.position = Vector3(w * 0.25 * side, h * 0.45, 0.02)
			a.rotation.z = -0.35 * side
			head.add_child(a)
			box(rig, a, Vector3(0.05, 0.4, 0.05), cfg["antlers"], Vector3(0, 0.2, 0))
			box(rig, a, Vector3(0.04, 0.22, 0.04), cfg["antlers"], Vector3(0.08 * side, 0.32, 0.04), Vector3(0, 0, -0.7 * side))
			box(rig, a, Vector3(0.04, 0.2, 0.04), cfg["antlers"], Vector3(-0.05 * side, 0.36, -0.05), Vector3(0.5, 0, 0.5 * side))
			box(rig, a, Vector3(0.04, 0.18, 0.04), cfg["antlers"], Vector3(0.1 * side, 0.18, -0.02), Vector3(0, 0, -1.0 * side))
	if cfg.has("horns"):
		for side in [-1, 1]:
			box(rig, head, Vector3(0.06, 0.3, 0.06), cfg["horns"], Vector3(w * 0.25 * side, h * 0.5, -0.05), Vector3(-0.8, 0, 0.3 * side))
	if cfg.has("spikes"):
		for k in 6:
			cyl(rig, b, 0.0, 0.08, 0.22, cfg["spikes"], Vector3(0, y + h * 0.5 + 0.08, ln * 0.4 - k * ln * 0.15), Vector3(-0.3, 0, 0), 4)
	var tail := pivot(rig, b, "tail", Vector3(0, y + h * 0.2, -ln * 0.5))
	box(rig, tail, Vector3(0.09, 0.09, ln * (0.7 if cfg.has("spikes") else 0.42)), col, Vector3(0, 0, -ln * (0.35 if cfg.has("spikes") else 0.2)), Vector3(0.4, 0, 0))
	rig.height = y + h
	return rig


static func blob(col: String, col2: String, r: float, teeth := false) -> Rig:
	var rig := Rig.new()
	rig.kind = "blob"
	rig.walk_speed = 7.0
	var b := rig.body
	ball(rig, b, r, col, Vector3(0, r * 0.8, 0), Vector3(1, 0.8, 1), 8, 4)
	ball(rig, b, r * 0.55, col2, Vector3(-r * 0.25, r * 1.15, r * 0.1), Vector3(1, 0.7, 1), 6, 3)
	for side in [-1, 1]:
		box(rig, b, Vector3(r * 0.16, r * 0.24, 0.03), "1a1420", Vector3(r * 0.3 * side, r * 0.95, r * 0.88))
	if teeth:
		box(rig, b, Vector3(r * 1.1, r * 0.25, 0.04), "2a1a20", Vector3(0, r * 0.55, r * 0.9))
		for k in 6:
			cyl(rig, b, 0.0, r * 0.07, r * 0.2, "e8e0c8", Vector3(-r * 0.45 + k * r * 0.18, r * 0.63, r * 0.92), Vector3(PI, 0, 0), 4)
	else:
		box(rig, b, Vector3(r * 0.4, r * 0.08, 0.03), "1a1420", Vector3(0, r * 0.7, r * 0.9))
	rig.height = r * 1.6
	return rig


static func puffcap() -> Rig:
	var rig := Rig.new()
	rig.kind = "blob"
	rig.walk_speed = 8.0
	var b := rig.body
	cyl(rig, b, 0.18, 0.22, 0.45, "e8d8c0", Vector3(0, 0.22, 0), Vector3.ZERO, 6)
	ball(rig, b, 0.42, "b04060", Vector3(0, 0.55, 0), Vector3(1, 0.6, 1), 8, 4)
	for k in 6:
		var a := k * TAU / 6.0
		box(rig, b, Vector3(0.09, 0.05, 0.09), "f0e0e8", Vector3(cos(a) * 0.25, 0.73, sin(a) * 0.25))
	box(rig, b, Vector3(0.1, 0.05, 0.1), "f0e0e8", Vector3(0, 0.8, 0))
	for side in [-1, 1]:
		box(rig, b, Vector3(0.05, 0.08, 0.02), "1a1420", Vector3(0.07 * side, 0.3, 0.2))
	rig.height = 0.85
	return rig


static func beetle(col: String, col2: String) -> Rig:
	var rig := Rig.new()
	rig.kind = "quad"
	rig.walk_speed = 14.0
	var b := rig.body
	ball(rig, b, 0.4, col, Vector3(0, 0.32, -0.05), Vector3(1.1, 0.7, 1.4), 8, 4)
	ball(rig, b, 0.25, col2, Vector3(-0.12, 0.47, 0.0), Vector3(1, 0.5, 1.4), 6, 3)
	box(rig, b, Vector3(0.02, 0.1, 0.9), "1f2a2a", Vector3(0, 0.55, -0.05))
	var head := pivot(rig, b, "head", Vector3(0, 0.28, 0.5))
	ball(rig, head, 0.18, "1f2a2a", Vector3.ZERO, Vector3.ONE, 6, 3)
	box(rig, head, Vector3(0.06, 0.06, 0.3), "c8c0a0", Vector3(0, 0.1, 0.18), Vector3(-0.6, 0, 0))
	for side in [-1, 1]:
		box(rig, head, Vector3(0.04, 0.04, 0.02), "ffd27a", Vector3(0.09 * side, 0.05, 0.16), Vector3.ZERO, 1.5)
	var names := ["leg_fl", "leg_fr", "leg_bl", "leg_br"]
	var spots := [[-1, 0.25], [1, 0.25], [-1, -0.3], [1, -0.3]]
	for i in 4:
		var p := pivot(rig, b, names[i], Vector3(0.36 * spots[i][0], 0.25, spots[i][1]))
		box(rig, p, Vector3(0.06, 0.25, 0.06), "1f2a2a", Vector3(0.05 * spots[i][0], -0.12, 0), Vector3(0, 0, 0.4 * spots[i][0]))
	for side in [-1, 1]:
		box(rig, b, Vector3(0.06, 0.25, 0.06), "1f2a2a", Vector3(0.4 * side, 0.13, -0.02), Vector3(0, 0, 0.4 * side))
	rig.height = 0.7
	return rig


static func spider(col: String) -> Rig:
	var rig := Rig.new()
	rig.kind = "spider"
	rig.walk_speed = 14.0
	var b := rig.body
	ball(rig, b, 0.28, col, Vector3(0, 0.38, 0.15), Vector3(1, 0.8, 1), 8, 4)
	ball(rig, b, 0.4, _dark(col), Vector3(0, 0.45, -0.38), Vector3(1, 0.85, 1.1), 8, 4)
	box(rig, b, Vector3(0.12, 0.04, 0.3), "b04040", Vector3(0, 0.78, -0.4))
	for k in 4:
		box(rig, b, Vector3(0.05, 0.05, 0.02), "ff4a4a", Vector3(-0.09 + k * 0.06, 0.45, 0.42), Vector3.ZERO, 2.0)
	for side in [-1, 1]:
		box(rig, b, Vector3(0.05, 0.14, 0.05), "e8e0d0", Vector3(0.07 * side, 0.27, 0.42))
	for i in 8:
		var side := 1.0 if i < 4 else -1.0
		var zpos := 0.32 - (i % 4) * 0.17
		var p := pivot(rig, b, "leg%d" % i, Vector3(0.18 * side, 0.42, zpos))
		var upper := box(rig, p, Vector3(0.38, 0.05, 0.05), "2a2230", Vector3(0.17 * side, 0.1, 0), Vector3(0, 0, 0.5 * side))
		box(rig, upper, Vector3(0.05, 0.42, 0.05), "2a2230", Vector3(0.19 * side, -0.2, 0), Vector3(0, 0, -0.5 * side))
	rig.height = 0.9
	return rig


static func worm(col: String, col2: String) -> Rig:
	var rig := Rig.new()
	rig.kind = "worm"
	rig.walk_speed = 8.0
	var b := rig.body
	for i in 6:
		var p := pivot(rig, b, "seg%d" % i, Vector3(0, 0.25, 0.45 - i * 0.22))
		var r := 0.26 - i * 0.025
		ball(rig, p, r, col if i % 2 == 0 else col2, Vector3.ZERO, Vector3(1, 0.85, 1), 8, 4)
	var head: Node3D = rig.parts["seg0"]
	cyl(rig, head, 0.14, 0.18, 0.08, "8a2a2a", Vector3(0, 0, 0.25), Vector3(PI * 0.5, 0, 0), 8)
	for k in 5:
		var a := k * TAU / 5.0
		cyl(rig, head, 0.0, 0.03, 0.08, "e8d8c0", Vector3(cos(a) * 0.1, sin(a) * 0.1, 0.3), Vector3(PI * 0.5, 0, 0), 3)
	rig.height = 0.6
	return rig


static func treant(s: float, bark: String, leaf: String, eye := "c8f070") -> Rig:
	var rig := Rig.new()
	rig.kind = "humanoid"
	rig.walk_speed = 6.0
	var b := rig.body
	for side in [-1, 1]:
		var leg := pivot(rig, b, "leg_l" if side < 0 else "leg_r", Vector3(0.14 * side * s, 0.5 * s, 0))
		box(rig, leg, Vector3(0.2, 0.5, 0.22) * s, _dark(bark), Vector3(0, -0.25 * s, 0))
		box(rig, leg, Vector3(0.32, 0.08, 0.36) * s, _dark(bark), Vector3(0, -0.48 * s, 0.04 * s))
	var torso := pivot(rig, b, "torso", Vector3(0, 0.5 * s, 0))
	box(rig, torso, Vector3(0.5, 0.8, 0.42) * s, bark, Vector3(0, 0.4 * s, 0))
	for k in 3:
		box(rig, torso, Vector3(0.03, 0.6, 0.02) * s, _dark(bark), Vector3((-0.15 + k * 0.15) * s, 0.4 * s, 0.215 * s))
	for side in [-1, 1]:
		box(rig, torso, Vector3(0.08, 0.06, 0.02) * s, eye, Vector3(0.11 * side * s, 0.62 * s, 0.215 * s), Vector3.ZERO, 2.0)
	var head := pivot(rig, torso, "head", Vector3(0, 0.8 * s, 0))
	ball(rig, head, 0.5 * s, leaf, Vector3(0, 0.25 * s, 0), Vector3(1, 0.8, 1), 7, 3)
	ball(rig, head, 0.32 * s, Color(leaf).lightened(0.2), Vector3(-0.2 * s, 0.45 * s, 0.1 * s), Vector3.ONE, 6, 3)
	ball(rig, head, 0.3 * s, Color(leaf).darkened(0.15), Vector3(0.25 * s, 0.35 * s, -0.15 * s), Vector3.ONE, 6, 3)
	for side in [-1, 1]:
		var arm := pivot(rig, torso, "arm_l" if side < 0 else "arm_r", Vector3(0.3 * side * s, 0.7 * s, 0))
		box(rig, arm, Vector3(0.14, 0.6, 0.14) * s, bark, Vector3(0.05 * side * s, -0.28 * s, 0), Vector3(0, 0, 0.25 * side))
		box(rig, arm, Vector3(0.08, 0.25, 0.08) * s, bark, Vector3(0.18 * side * s, -0.5 * s, 0.05 * s), Vector3(0, 0, -0.5 * side))
		ball(rig, arm, 0.12 * s, leaf, Vector3(0.22 * side * s, -0.62 * s, 0.05 * s), Vector3.ONE, 5, 3)
	rig.height = 1.8 * s
	return rig


static func golem(ice := "8ab0cc", hi := "c8e0f0", eye := "2a7fd0") -> Rig:
	var rig := Rig.new()
	rig.kind = "humanoid"
	rig.walk_speed = 5.0
	var b := rig.body
	for side in [-1, 1]:
		var leg := pivot(rig, b, "leg_l" if side < 0 else "leg_r", Vector3(0.24 * side, 0.6, 0))
		box(rig, leg, Vector3(0.34, 0.6, 0.36), ice, Vector3(0, -0.3, 0))
	var torso := pivot(rig, b, "torso", Vector3(0, 0.6, 0))
	box(rig, torso, Vector3(0.95, 0.8, 0.6), ice, Vector3(0, 0.42, 0))
	box(rig, torso, Vector3(0.95, 0.18, 0.62), hi, Vector3(0, 0.78, 0))
	box(rig, torso, Vector3(0.24, 0.24, 0.04), eye, Vector3(0, 0.45, 0.31), Vector3.ZERO, 2.5)
	var head := pivot(rig, torso, "head", Vector3(0, 0.86, 0.05))
	box(rig, head, Vector3(0.42, 0.34, 0.4), ice, Vector3(0, 0.16, 0))
	for side in [-1, 1]:
		box(rig, head, Vector3(0.09, 0.07, 0.02), eye, Vector3(0.1 * side, 0.18, 0.205), Vector3.ZERO, 2.5)
	for side in [-1, 1]:
		var arm := pivot(rig, torso, "arm_l" if side < 0 else "arm_r", Vector3(0.62 * side, 0.7, 0))
		box(rig, arm, Vector3(0.32, 0.7, 0.34), ice, Vector3(0, -0.32, 0))
		box(rig, arm, Vector3(0.4, 0.34, 0.4), hi, Vector3(0, -0.78, 0.02))
		box(rig, arm, Vector3(0.36, 0.2, 0.38), hi, Vector3(0, 0.04, 0))
	rig.height = 2.0
	return rig


static func wisp(col: String) -> Rig:
	var rig := Rig.new()
	rig.kind = "float"
	var b := rig.body
	var core := pivot(rig, b, "core", Vector3(0, 0.0, 0))
	ball(rig, core, 0.3, col, Vector3.ZERO, Vector3(1, 1.3, 1), 4, 2, 2.0)
	ball(rig, core, 0.16, "ffffff", Vector3(0, 0, 0.12), Vector3.ONE, 4, 2, 3.0)
	var ring := pivot(rig, b, "ring", Vector3(0, 0.0, 0))
	for k in 4:
		var a := k * TAU / 4.0
		cyl(rig, ring, 0.0, 0.07, 0.3, "e8f8ff", Vector3(cos(a) * 0.5, 0, sin(a) * 0.5), Vector3(0, 0, PI * 0.5 * (1 if k % 2 == 0 else -1)), 4, 1.5)
	var l := OmniLight3D.new()
	l.light_color = Color(col)
	l.omni_range = 3.0
	l.light_energy = 1.0
	core.add_child(l)
	rig.height = 1.4
	return rig


# ================================================================ props
static func gem(col: Color) -> Rig:
	var rig := Rig.new()
	rig.kind = "float"
	var core := pivot(rig, rig.body, "core", Vector3(0, 0.0, 0))
	ball(rig, core, 0.2, col, Vector3.ZERO, Vector3(1, 1.4, 1), 4, 2, 1.8)
	return rig


static func potion() -> Rig:
	var rig := Rig.new()
	rig.kind = "float"
	var core := pivot(rig, rig.body, "core", Vector3(0, -0.1, 0))
	ball(rig, core, 0.16, "d9483b", Vector3(0, 0, 0), Vector3.ONE, 6, 3, 0.6)
	cyl(rig, core, 0.05, 0.06, 0.12, "e8e0d0", Vector3(0, 0.18, 0), Vector3.ZERO, 6)
	cyl(rig, core, 0.05, 0.05, 0.06, "8a5a30", Vector3(0, 0.27, 0), Vector3.ZERO, 6)
	return rig


static func loot_bag(col: Color) -> Rig:
	var rig := Rig.new()
	rig.kind = "float"
	var core := pivot(rig, rig.body, "core", Vector3(0, -0.3, 0))
	ball(rig, core, 0.26, "c8a878", Vector3(0, 0, 0), Vector3(1, 0.9, 1), 7, 3)
	cyl(rig, core, 0.09, 0.14, 0.12, "c8a878", Vector3(0, 0.25, 0), Vector3.ZERO, 6)
	cyl(rig, core, 0.11, 0.11, 0.04, col, Vector3(0, 0.22, 0), Vector3.ZERO, 6, 1.2)
	box(rig, core, Vector3(0.12, 0.12, 0.02), col, Vector3(0, 0.02, 0.25), Vector3.ZERO, 1.2)
	return rig


static func plant(kind: String) -> Rig:
	var rig := Rig.new()
	rig.kind = "static"
	var b := rig.body
	if kind == "sunpetal":
		cyl(rig, b, 0.03, 0.03, 0.5, "4c8a3c", Vector3(0, 0.25, 0))
		box(rig, b, Vector3(0.2, 0.04, 0.08), "4c8a3c", Vector3(0.08, 0.18, 0), Vector3(0, 0, 0.4))
		for k in 6:
			var a := k * TAU / 6.0
			box(rig, b, Vector3(0.12, 0.03, 0.08), "ffd27a", Vector3(cos(a) * 0.1, 0.52, sin(a) * 0.1), Vector3(0, -a, 0), 1.2)
		ball(rig, b, 0.06, "c47a2a", Vector3(0, 0.54, 0), Vector3.ONE, 6, 3)
	elif kind == "thrift":
		cyl(rig, b, 0.03, 0.03, 0.4, "5a8a4a", Vector3(0, 0.2, 0))
		ball(rig, b, 0.14, "ff9ac8", Vector3(0, 0.46, 0), Vector3.ONE, 6, 3, 1.2)
		box(rig, b, Vector3(0.3, 0.03, 0.06), "5a8a4a", Vector3(0.1, 0.12, 0), Vector3(0, 0, 0.3))
	elif kind == "briarberry":
		cyl(rig, b, 0.04, 0.05, 0.55, "3a2a1e", Vector3(0, 0.27, 0))
		box(rig, b, Vector3(0.3, 0.04, 0.04), "3a2a1e", Vector3(0.12, 0.35, 0), Vector3(0, 0, 0.5))
		for k in 4:
			ball(rig, b, 0.07, "e03a4a", Vector3(0.12 * cos(k * 1.6), 0.3 + 0.08 * k, 0.12 * sin(k * 1.6)), Vector3.ONE, 5, 3, 1.5)
	elif kind == "heather":
		cyl(rig, b, 0.03, 0.03, 0.45, "5a6a3a", Vector3(0, 0.22, 0))
		for k in 5:
			cyl(rig, b, 0.0, 0.05, 0.22, "b88aff", Vector3(0.06 * cos(k * 1.3), 0.5, 0.06 * sin(k * 1.3)), Vector3.ZERO, 5, 1.4)
	else:
		cyl(rig, b, 0.07, 0.09, 0.35, "e8d8c0", Vector3(0, 0.17, 0))
		ball(rig, b, 0.24, "7affd8" if kind == "brinecap" else "9fe0a0", Vector3(0, 0.38, 0), Vector3(1, 0.55, 1), 8, 3, 1.6)
		cyl(rig, b, 0.04, 0.05, 0.2, "e8d8c0", Vector3(0.25, 0.1, 0.1))
		ball(rig, b, 0.12, "9fe0a0", Vector3(0.25, 0.22, 0.1), Vector3(1, 0.55, 1), 6, 3, 1.6)
	return rig


# ================================================================ scenery meshes (trees, rocks, grass)
## Flat-shaded, vertex-coloured meshes for MultiMesh scenery.
static func scenery_mesh(kind: String, seed_v: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	match kind:
		"oak", "dark_oak", "autumn":
			_blk_oak(st, rng, kind, seed_v)
		"birch":
			_blk_birch(st, rng)
		"willow":
			_blk_willow(st, rng)
		"tall_pine":
			_blk_conifer(st, rng, 6 + (seed_v % 2), 2.0, 1.1, false)
		"pine":
			_blk_conifer(st, rng, 4, 1.7, 0.8, true)
		"dead":
			_blk_dead(st, rng)
		"bush":
			_blk_bush(st, rng, seed_v)
		"stump":
			_blk_stump(st)
		"rockmass":
			_m_blob(st, Vector3(0, 0, 0), Vector3(1.0, 1.0, 1.0), Color("6a6a72"), rng, 0.28)
			_m_blob(st, Vector3(0.45, 0.35, 0.2), Vector3(0.6, 0.6, 0.6), Color("7a7a84"), rng, 0.25)
		"stalag":
			_m_cone(st, Vector3(0, 0, 0), 1.0, 3.0, Color("77757c"), 6)
			_m_cone(st, Vector3(0.7, 0, 0.2), 0.55, 1.7, Color("66646b"), 5)
		"fern":
			for k in 7:
				var a3 := k * TAU / 7.0 + rng.randf() * 0.4
				_m_beam(st, Vector3.ZERO, Vector3(cos(a3) * 0.5, 0.45 + rng.randf() * 0.15, sin(a3) * 0.5), 0.03, Color("3f8a4a").lightened(rng.randf() * 0.12))
		"mushroom":
			var big := 1.0 + rng.randf() * 0.5
			_m_cyl(st, Vector3(0, 0, 0), 0.07 * big, 0.05 * big, 0.28 * big, Color("e8dcc0"), 5)
			_m_blob(st, Vector3(0, 0.3 * big, 0), Vector3(0.24, 0.13, 0.24) * big, Color("c83a2e") if seed_v % 3 != 0 else Color("b88a4a"), rng, 0.04)
			_m_cyl(st, Vector3(0.26, 0, 0.1), 0.04, 0.03, 0.14, Color("e8dcc0"), 4)
			_m_blob(st, Vector3(0.26, 0.15, 0.1), Vector3(0.12, 0.07, 0.12), Color("c83a2e") if seed_v % 3 != 0 else Color("b88a4a"), rng, 0.03)
		"reeds":
			for k in 6:
				var a4 := k * 1.1 + rng.randf()
				var o2 := Vector3(cos(a4), 0, sin(a4)) * (0.05 + rng.randf() * 0.2)
				var hgt := 0.8 + rng.randf() * 0.6
				_m_beam(st, o2, o2 + Vector3(cos(a4) * 0.05, hgt, sin(a4) * 0.05), 0.025, Color("a8a050").lightened(rng.randf() * 0.12))
				if k % 2 == 0:
					_m_beam(st, o2 + Vector3(cos(a4) * 0.05, hgt - 0.05, sin(a4) * 0.05), o2 + Vector3(cos(a4) * 0.055, hgt + 0.2, sin(a4) * 0.055), 0.05, Color("5a3d25"))
		"log":
			var ln := 0.8 + rng.randf() * 0.4
			_m_beam(st, Vector3(-ln, 0.2, 0), Vector3(ln, 0.2, 0.1), 0.2, Color("5e4630"))
			_m_beam(st, Vector3(ln, 0.2, 0.1), Vector3(ln + 0.02, 0.2, 0.1), 0.17, Color("c8a878"))
			_m_blob(st, Vector3(-0.2, 0.42, 0.0), Vector3(0.3, 0.08, 0.14), Color("4c8a3c"), rng, 0.05)
		"spire":
			var hh2 := 2.6 + rng.randf() * 1.6
			_m_cone(st, Vector3(0, 0, 0), 0.95, hh2, Color("6a6f7a"), 5)
			_m_cone(st, Vector3(0.7, 0, 0.3), 0.6, hh2 * 0.6, Color("7b808b"), 5)
			_m_cone(st, Vector3(0, hh2 * 0.78, 0), 0.22, hh2 * 0.22, Color("e8f0f6"), 5)
		"boulder":
			_m_blob(st, Vector3(0, 0.45, 0), Vector3(1.0, 0.75, 0.9), Color("6f7480"), rng, 0.18)
			_m_blob(st, Vector3(0.1, 0.85, 0.05), Vector3(0.75, 0.25, 0.65), Color("e8f0f6"), rng, 0.1)
		"tuft":
			for k in 4:
				var a2 := k * 1.6 + rng.randf()
				var o := Vector3(cos(a2), 0, sin(a2)) * 0.12
				_m_beam(st, o, o + Vector3(cos(a2) * 0.12, 0.35 + rng.randf() * 0.15, sin(a2) * 0.12), 0.035, Color("4c8a3c").lightened(rng.randf() * 0.15))
		"pebbles":
			for k in 5:
				var a5 := rng.randf() * TAU
				var o5 := Vector3(cos(a5), 0, sin(a5)) * (0.08 + rng.randf() * 0.4)
				var s5 := 0.08 + rng.randf() * 0.12
				_m_blob(st, o5 + Vector3(0, s5 * 0.4, 0), Vector3(s5, s5 * 0.6, s5 * 0.85), Color("77797f").lightened(rng.randf() * 0.15), rng, 0.15)
		"mossrock":
			_m_blob(st, Vector3(0, 0.22, 0), Vector3(0.5, 0.32, 0.42), Color("5f6670"), rng, 0.16)
			_m_blob(st, Vector3(0.3, 0.14, 0.12), Vector3(0.28, 0.2, 0.26), Color("6d747d"), rng, 0.15)
			_m_blob(st, Vector3(-0.05, 0.4, 0.0), Vector3(0.34, 0.1, 0.3), Color("4a7a3c"), rng, 0.06)
		"bones":
			var bc := Color("d8d2bc")
			for k in 6:
				var ang := -0.9 + k * 0.36
				var rx := -0.1 + k * 0.1
				_m_beam(st, Vector3(rx, 0.02, 0), Vector3(rx, 0.2, sin(ang) * 0.3), 0.025, bc)
				_m_beam(st, Vector3(rx, 0.2, sin(ang) * 0.3), Vector3(rx, 0.03, sin(ang) * 0.5), 0.022, bc)
				_m_beam(st, Vector3(rx, 0.02, 0), Vector3(rx, 0.2, -sin(ang) * 0.3), 0.025, bc)
			_m_beam(st, Vector3(-0.15, 0.03, 0), Vector3(0.6, 0.03, 0.05), 0.035, bc)
			_m_blob(st, Vector3(-0.35, 0.1, 0.2), Vector3(0.13, 0.1, 0.12), bc, rng, 0.06)
			_m_beam(st, Vector3(0.5, 0.02, -0.3), Vector3(0.8, 0.04, -0.4), 0.03, bc)
		"branches":
			for k in 3:
				var a6 := rng.randf() * TAU
				var base := Vector3(rng.randf_range(-0.2, 0.2), 0.05, rng.randf_range(-0.2, 0.2))
				var ln2 := 0.5 + rng.randf() * 0.5
				var tip := base + Vector3(cos(a6) * ln2, 0.03, sin(a6) * ln2)
				_m_beam(st, base, tip, 0.04, Color("5b4630"))
				var mid := base.lerp(tip, 0.55)
				_m_beam(st, mid, mid + Vector3(cos(a6 + 0.8) * 0.25, 0.1, sin(a6 + 0.8) * 0.25), 0.025, Color("5b4630"))
		"tallgrass":
			for k in 9:
				var a7 := k * 0.9 + rng.randf()
				var o7 := Vector3(cos(a7), 0, sin(a7)) * (0.05 + rng.randf() * 0.18)
				_m_beam(st, o7, o7 + Vector3(cos(a7) * 0.2, 0.42 + rng.randf() * 0.25, sin(a7) * 0.2), 0.02, Color("6c9a45").lightened(rng.randf() * 0.15))
		"glowcap":
			var gc := Color("5ee0c8") if seed_v % 2 == 0 else Color("b48cff")
			for k in 3:
				var o8 := Vector3(rng.randf_range(-0.2, 0.2), 0, rng.randf_range(-0.2, 0.2))
				var h8 := 0.18 + rng.randf() * 0.2
				_m_cyl(st, o8, 0.03, 0.025, h8, Color("cfd8d0"), 4)
				_m_blob(st, o8 + Vector3(0, h8, 0), Vector3(0.1, 0.06, 0.1) * (0.8 + rng.randf() * 0.6), gc, rng, 0.03)
		"frostweed":
			for k in 6:
				var a9 := k * 1.1 + rng.randf()
				var o9 := Vector3(cos(a9), 0, sin(a9)) * 0.1
				_m_beam(st, o9, o9 + Vector3(cos(a9) * 0.15, 0.3 + rng.randf() * 0.2, sin(a9) * 0.15), 0.03, Color("a8c4cc").lightened(rng.randf() * 0.2))
		"ruin":
			var rc2 := Color("7d7f86")
			var rc3 := Color("6a6c73")
			_m_box(st, Vector3(0, -0.6, 0), Vector3(10.0, 1.2, 10.0), Color("55575e"), 0.0)
			for sd in 4:
				var rot := sd * PI / 2.0
				var fw := Basis(Vector3.UP, rot)
				var segs2 := [[-3.4, 2.6 + rng.randf() * 1.4], [-0.6, 0.0], [2.6, 1.0 + rng.randf() * 2.2]]
				for sg in segs2:
					if float(sg[1]) <= 0.0:
						continue
					var ctr: Vector3 = fw * Vector3(float(sg[0]) + 0.9, float(sg[1]) * 0.5, 4.5)
					_m_box(st, ctr, Vector3(3.2, float(sg[1]), 0.7), rc2 if (sd + int(sg[1] * 3)) % 2 == 0 else rc3, rot)
				var cp: Vector3 = fw * Vector3(4.5, 0, 4.5)
				var ph := 3.4 + rng.randf() * 1.6 if sd != 2 else 1.2
				_m_cyl(st, cp, 0.55, 0.45, ph, Color("8a8c93"), 6)
				if sd != 2:
					_m_cone(st, cp + Vector3(0, ph, 0), 0.5, 0.25, Color("6e7078"), 6)
			for k in 7:
				var a10 := rng.randf() * TAU
				var r10 := 1.0 + rng.randf() * 4.0
				_m_blob(st, Vector3(cos(a10) * r10, 0.2, sin(a10) * r10), Vector3(0.45, 0.3, 0.4) * (0.6 + rng.randf()), rc3, rng, 0.2)
			_m_blob(st, Vector3(0, 0.05, 0), Vector3(1.1, 0.18, 1.1), Color("4a7a3c"), rng, 0.05)
		"standing_stones":
			_m_box(st, Vector3(0, -0.5, 0), Vector3(1.8, 1.4, 1.2), Color("676a72"), 0.3)
			_m_blob(st, Vector3(0, 0.95, 0), Vector3(0.9, 0.12, 0.6), Color("4a7a3c"), rng, 0.05)
			for k in 7:
				var a11 := k * TAU / 7.0
				var h11 := 2.6 + rng.randf() * 1.8
				var p11 := Vector3(cos(a11) * 4.6, 0, sin(a11) * 4.6)
				_m_box(st, p11 + Vector3(0, h11 * 0.5 - 0.5, 0), Vector3(1.2, h11 + 1.0, 0.65), Color("757880").darkened(rng.randf() * 0.12), -a11 + 0.15 * (rng.randf() - 0.5))
				_m_blob(st, p11 + Vector3(0, h11 - 0.45, 0), Vector3(0.65, 0.12, 0.4), Color("4a7a3c"), rng, 0.05)
			_m_box(st, Vector3(4.6, 4.3, 0), Vector3(1.0, 0.5, 4.0), Color("757880"), 0.0)
		"watchtower":
			_m_cyl(st, Vector3(0, -1.2, 0), 2.4, 2.2, 1.4, Color("55575e"), 7)
			_m_cyl(st, Vector3(0, 0, 0), 2.1, 1.7, 7.5, Color("858890"), 7)
			_m_cyl(st, Vector3(0, 7.5, 0), 2.0, 2.0, 0.5, Color("6e7078"), 7)
			for k in 7:
				if k == 2 or k == 5:
					continue
				var a12 := k * TAU / 7.0
				_m_box(st, Vector3(cos(a12) * 1.85, 8.35 + (k % 3) * 0.12, sin(a12) * 1.85), Vector3(0.9, 0.9, 0.7), Color("7d7f86"), -a12 + PI / 2.0)
			for k in 4:
				_m_box(st, Vector3(sin(k * PI / 2.0) * 1.62, 3.0 + k * 1.1, cos(k * PI / 2.0) * 1.62), Vector3(0.35, 0.7, 0.2), Color("2a2a30"), k * PI / 2.0)
			_m_beam(st, Vector3(-1.6, 5.2, 0.4), Vector3(1.4, 6.3, -0.2), 0.12, Color("5b4630"))
			_m_beam(st, Vector3(0.2, 7.8, -1.2), Vector3(1.0, 6.6, -1.9), 0.1, Color("5b4630"))
		"ancient_tree":
			var bark := Color("4e4236")
			_m_cyl(st, Vector3(0, -0.8, 0), 1.9, 1.3, 1.6, bark, 7)
			_m_cyl(st, Vector3(0, 0.8, 0), 1.3, 0.8, 5.2, bark, 7)
			_m_cyl(st, Vector3(0.1, 6.0, 0), 0.8, 0.45, 5.0, bark.darkened(0.08), 6)
			for k in 7:
				var a13 := k * 0.95 + rng.randf() * 0.4
				var y13 := 3.6 + k * 1.0
				var d13 := Vector3(cos(a13), 0.5 + rng.randf() * 0.4, sin(a13)).normalized()
				var l13 := 2.8 + rng.randf() * 2.2
				var s13 := Vector3(0, y13, 0)
				_m_beam(st, s13, s13 + d13 * l13, 0.25 - k * 0.02, bark)
				var e13 := s13 + d13 * l13
				_m_beam(st, e13, e13 + Vector3(cos(a13 + 0.7), 0.9, sin(a13 + 0.7)).normalized() * 1.6, 0.1, bark.darkened(0.1))
			for k in 5:
				var a14 := k * 1.3
				_m_beam(st, Vector3(cos(a14) * 1.0, 0.2, sin(a14) * 1.0), Vector3(cos(a14) * 2.7, -0.3, sin(a14) * 2.7), 0.38, bark)
		"obelisk":
			var rune := Color("6af0ff")
			_m_box(st, Vector3(0, -0.6, 0), Vector3(3.2, 1.2, 3.2), Color("55575e"), 0.4)
			_m_box(st, Vector3(0, 0.3, 0), Vector3(2.2, 0.6, 2.2), Color("676a72"), 0.4)
			_m_cyl(st, Vector3(0, 0.6, 0), 0.95, 0.55, 6.0, Color("565a68"), 4)
			_m_cone(st, Vector3(0, 6.6, 0), 0.55, 0.9, Color("565a68"), 4)
			for k in 4:
				for r in 4:
					var yy := 1.4 + r * 1.2
					var rr := 0.9 - (yy - 0.6) * 0.058
					var ar := k * PI / 2.0 + PI / 4.0
					_m_box(st, Vector3(cos(ar) * rr, yy, sin(ar) * rr), Vector3(0.12, 0.5 + (r % 2) * 0.25, 0.12), rune, -ar)
		"old_camp":
			var cloth := Color("8a7a58")
			_m_beam(st, Vector3(-1.4, 0.05, 0), Vector3(-0.15, 1.5, 0), 0.07, Color("5b4630"))
			_m_beam(st, Vector3(1.0, 0.05, 0), Vector3(0.15, 1.5, 0), 0.07, Color("5b4630"))
			_m_box(st, Vector3(-0.85, 0.7, 0.0), Vector3(1.9, 0.07, 2.2), cloth, 0.0)
			_tri(st, Vector3(-1.9, 0.05, 1.1), Vector3(-0.15, 1.5, 0), Vector3(-1.9, 0.05, -1.1), cloth.darkened(0.15))
			_m_cyl(st, Vector3(2.8, 0, 0.4), 0.45, 0.45, 0.06, Color("2a2622"), 7)
			for k in 8:
				var a15 := k * TAU / 8.0
				_m_blob(st, Vector3(2.8 + cos(a15) * 0.6, 0.12, 0.4 + sin(a15) * 0.6), Vector3(0.17, 0.13, 0.15), Color("6a6c73"), rng, 0.12)
			_m_beam(st, Vector3(1.6, 0.18, 2.2), Vector3(3.8, 0.18, 2.0), 0.17, Color("5e4630"))
			_m_beam(st, Vector3(1.4, 0.18, -1.7), Vector3(3.6, 0.18, -2.0), 0.17, Color("5e4630"))
			_m_box(st, Vector3(-1.2, 0.3, 1.6), Vector3(0.7, 0.6, 0.6), Color("7a5a36"), 0.4)
		"bridge":
			var bl := float(seed_v)
			var wood := Color("6b5238")
			var wood2 := Color("7d6244")
			var np := int(bl / 0.55)
			for k in np:
				var px := -bl * 0.5 + (k + 0.5) * bl / np
				_m_box(st, Vector3(px, -0.06, 0), Vector3(bl / np - 0.04, 0.12, 2.6), wood if k % 2 == 0 else wood2, 0.0)
			for sd in [-1.0, 1.0]:
				_m_box(st, Vector3(0, -0.28, sd * 1.05), Vector3(bl, 0.2, 0.22), Color("4e3b28"), 0.0)
				_m_box(st, Vector3(0, 0.95, sd * 1.3), Vector3(bl, 0.1, 0.12), wood2, 0.0)
				_m_box(st, Vector3(0, 0.55, sd * 1.3), Vector3(bl, 0.07, 0.1), wood, 0.0)
				var nposts := int(bl / 2.4) + 1
				for k in nposts + 1:
					var ppx := -bl * 0.5 + k * bl / nposts
					_m_box(st, Vector3(ppx, 0.5, sd * 1.3), Vector3(0.2, 1.1, 0.2), Color("4e3b28"), 0.0)
			var nl := int(bl / 5.0)
			for k in nl + 1:
				var lx := -bl * 0.5 + 1.0 + k * (bl - 2.0) / maxf(nl, 1.0)
				for sd in [-1.0, 1.0]:
					_m_box(st, Vector3(lx, -1.2, sd * 1.0), Vector3(0.3, 2.2, 0.3), Color("4e3b28"), 0.0)
		"flower":
			_m_beam(st, Vector3.ZERO, Vector3(0, 0.32, 0), 0.025, Color("4c8a3c"))
			_m_blob(st, Vector3(0, 0.36, 0), Vector3(0.09, 0.06, 0.09), Color("f2d16b") if seed_v % 2 == 0 else Color("e88aa6"), rng, 0.0)
	st.generate_normals()
	return st.commit()



# ---- blocky trees: chunky stacked boxes, flat-shaded (top faces lighter), a stepped foot under every trunk
static func _blk_foot(st: SurfaceTool, w: float, col: Color) -> float:
	## two steps of widening base under a trunk; returns the height the trunk starts at
	_m_box(st, Vector3(0, 0.1, 0), Vector3(w * 1.75, 0.2, w * 1.75), col.darkened(0.1), 0.0)
	_m_box(st, Vector3(0, 0.3, 0), Vector3(w * 1.35, 0.2, w * 1.35), col.darkened(0.04), 0.0)
	return 0.4


static func _blk_oak(st: SurfaceTool, rng: RandomNumberGenerator, kind: String, seed_v: int) -> void:
	var bark := Color("6b4a2c") if kind != "autumn" else Color("5e4228")
	var g1 := Color("3f8a43")
	var g2 := Color("2e6b34")
	var g3 := Color("5fae58")
	if kind == "dark_oak":
		g1 = Color("2d5e33")
		g2 = Color("21472a")
		g3 = Color("3f7a44")
	elif kind == "autumn":
		var pal: Array = [[Color("c8641e"), Color("a8321e"), Color("e0a82e")], [Color("d98a22"), Color("b8481e"), Color("e8c040")], [Color("a8321e"), Color("c8641e"), Color("d8a030")]][seed_v % 3]
		g1 = pal[0]
		g2 = pal[1]
		g3 = pal[2]
	var w := 0.46
	var y0 := _blk_foot(st, w, bark)
	var th := 1.45 + rng.randf() * 0.3
	_m_box(st, Vector3(0, y0 + th * 0.5, 0), Vector3(w, th, w), bark, rng.randf() * 0.4)
	var top := y0 + th
	var r0 := rng.randf() * PI * 0.5
	# the crown: a wide core slab and a skirt, with offset chunks stacked on and around it
	_m_box(st, Vector3(0, top + 0.45, 0), Vector3(1.9, 1.0, 1.9), g1, r0)
	_m_box(st, Vector3(0.12, top + 0.05, -0.1), Vector3(2.3, 0.55, 2.0), g2, r0 + 0.5)
	_m_box(st, Vector3(-0.15, top + 1.25, 0.1), Vector3(1.35, 0.75, 1.35), g3, r0 + 0.9)
	for k in 3:
		var a := r0 + k * 2.1 + rng.randf() * 0.6
		var d := 0.85 + rng.randf() * 0.25
		var sz := 0.9 + rng.randf() * 0.45
		_m_box(st, Vector3(cos(a) * d, top + 0.35 + rng.randf() * 0.7, sin(a) * d), Vector3(sz, sz * 0.85, sz), g3 if k % 2 == 0 else g1, a)


static func _blk_birch(st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	var bark := Color("e6e2d4")
	var w := 0.3
	var y0 := _blk_foot(st, w, bark)
	var th := 2.2 + rng.randf() * 0.6
	_m_box(st, Vector3(0, y0 + th * 0.5, 0), Vector3(w, th, w), bark, 0.0)
	for k in 4:
		_m_box(st, Vector3(0, y0 + 0.5 + k * 0.5, 0), Vector3(w + 0.03, 0.1, w + 0.03), Color("3a3630"), k * 0.5)
	var top := y0 + th
	var r0 := rng.randf() * PI * 0.5
	_m_box(st, Vector3(0, top + 0.15, 0), Vector3(1.3, 1.1, 1.3), Color("8cc063"), r0)
	_m_box(st, Vector3(0.25, top - 0.5, 0.1), Vector3(1.0, 0.7, 1.0), Color("a8d070"), r0 + 0.6)
	_m_box(st, Vector3(-0.15, top + 0.85, -0.1), Vector3(0.8, 0.7, 0.8), Color("77b055"), r0 + 1.1)


static func _blk_willow(st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	var bark := Color("5a4a34")
	var w := 0.55
	var y0 := _blk_foot(st, w, bark)
	_m_box(st, Vector3(0, y0 + 0.65, 0), Vector3(w, 1.3, w), bark, 0.0)
	var top := y0 + 1.3
	var r0 := rng.randf() * PI * 0.5
	_m_box(st, Vector3(0, top + 0.3, 0), Vector3(2.6, 0.8, 2.6), Color("7fa04e"), r0)
	_m_box(st, Vector3(0.1, top + 0.85, 0), Vector3(1.6, 0.5, 1.6), Color("8fb25a"), r0 + 0.6)
	for k in 14:
		var a := k * TAU / 14.0 + rng.randf() * 0.25
		var h := 1.3 + rng.randf() * 0.6
		var rr := 1.15 + rng.randf() * 0.15
		_m_box(st, Vector3(cos(a) * rr, top + 0.1 - h * 0.5, sin(a) * rr), Vector3(0.3, h, 0.3), Color("6e9a46").darkened(rng.randf() * 0.15), a)
	for k in 6:
		var a2 := k * TAU / 6.0 + 0.3
		var h2 := 0.8 + rng.randf() * 0.4
		_m_box(st, Vector3(cos(a2) * 0.55, top + 0.1 - h2 * 0.5, sin(a2) * 0.55), Vector3(0.26, h2, 0.26), Color("7aa850").darkened(rng.randf() * 0.1), a2)


static func _blk_conifer(st: SurfaceTool, rng: RandomNumberGenerator, tiers: int, base_w: float, tier_h: float, snow: bool) -> void:
	## a stepped spruce: boxes that narrow towards the top, each nudged and turned a little
	var bark := Color("4a3524")
	var w := 0.4
	var y0 := _blk_foot(st, w, bark)
	var trunk := 0.9
	_m_box(st, Vector3(0, y0 + trunk * 0.5, 0), Vector3(w, trunk, w), bark, 0.0)
	var y := y0 + trunk - 0.2
	var base := Color("2c4f3c") if snow else Color("1f3d2c")
	for k in tiers:
		var f := float(k) / maxf(tiers - 1, 1)
		var ww := lerpf(base_w, base_w * 0.28, f)
		var hh := tier_h * lerpf(1.0, 0.8, f)
		var ang := rng.randf() * PI * 0.5
		var off := Vector3(rng.randf_range(-0.08, 0.08), 0, rng.randf_range(-0.08, 0.08))
		var col := base.lightened(0.03 * k + (0.04 if k % 2 == 1 else 0.0))
		_m_box(st, Vector3(off.x, y + hh * 0.5, off.z), Vector3(ww, hh, ww), col, ang)
		if snow:
			_m_box(st, Vector3(off.x, y + hh + 0.03, off.z), Vector3(ww * 0.92, 0.1, ww * 0.92), Color("e8f0f6"), ang)
		y += hh * 0.72


static func _blk_dead(st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	var bark := Color("5b4d3d")
	var y0 := _blk_foot(st, 0.38, bark)
	_m_box(st, Vector3(0, y0 + 0.55, 0), Vector3(0.38, 1.1, 0.38), bark, 0.0)
	_m_box(st, Vector3(0.04, y0 + 1.5, 0), Vector3(0.3, 0.9, 0.3), bark.darkened(0.05), 0.3)
	_m_box(st, Vector3(-0.02, y0 + 2.25, 0.02), Vector3(0.22, 0.7, 0.22), bark.darkened(0.1), 0.6)
	for k in 3:
		var a := k * 2.2 + rng.randf() * 0.4
		var y2 := 1.3 + k * 0.5
		var dir := Vector3(cos(a), 0.55, sin(a)).normalized()
		_m_beam(st, Vector3(0, y2, 0), Vector3(0, y2, 0) + dir * 0.9, 0.07, bark)


static func _blk_bush(st: SurfaceTool, rng: RandomNumberGenerator, seed_v: int) -> void:
	var r0 := rng.randf() * PI * 0.5
	_m_box(st, Vector3(0, 0.2, 0), Vector3(0.95, 0.4, 0.8), Color("3f7a3a"), r0)
	_m_box(st, Vector3(0.12, 0.55, -0.05), Vector3(0.65, 0.35, 0.6), Color("4c8a44"), r0 + 0.5)
	_m_box(st, Vector3(-0.3, 0.38, 0.22), Vector3(0.45, 0.3, 0.4), Color("5fae58"), r0 + 1.0)
	if seed_v % 2 == 0:
		_m_box(st, Vector3(-0.18, 0.78, 0.1), Vector3(0.09, 0.09, 0.09), Color("d9483b"), 0.3)
		_m_box(st, Vector3(0.3, 0.72, -0.12), Vector3(0.09, 0.09, 0.09), Color("d9483b"), 0.8)


static func _blk_stump(st: SurfaceTool) -> void:
	var bark := Color("5e4630")
	_m_box(st, Vector3(0, 0.1, 0), Vector3(0.85, 0.2, 0.85), bark.darkened(0.1), 0.0)
	_m_box(st, Vector3(0, 0.38, 0), Vector3(0.62, 0.36, 0.62), bark, 0.3)
	_m_box(st, Vector3(0, 0.575, 0), Vector3(0.56, 0.04, 0.56), Color("c8a878"), 0.3)


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	st.set_color(col)
	st.add_vertex(a)
	st.set_color(col)
	st.add_vertex(b)
	st.set_color(col)
	st.add_vertex(c)


static func _m_box(st: SurfaceTool, c: Vector3, size: Vector3, col: Color, rot_y: float) -> void:
	var b := Basis(Vector3.UP, rot_y)
	var h := size * 0.5
	var v: Array[Vector3] = []
	for i in 8:
		v.append(c + b * Vector3(h.x if i & 1 else -h.x, h.y if i & 2 else -h.y, h.z if i & 4 else -h.z))
	var faces := [[0, 2, 3, 1], [4, 5, 7, 6], [0, 4, 6, 2], [1, 3, 7, 5], [0, 1, 5, 4], [2, 6, 7, 3]]
	for f in faces:
		var shade := col.lightened(0.08) if f == faces[5] else (col.darkened(0.12) if f == faces[4] else col)
		_tri(st, v[f[0]], v[f[1]], v[f[2]], shade)
		_tri(st, v[f[0]], v[f[2]], v[f[3]], shade)


static func _m_cyl(st: SurfaceTool, base: Vector3, rb: float, rt: float, h: float, col: Color, segs: int) -> void:
	for i in segs:
		var a0 := TAU * i / segs
		var a1 := TAU * (i + 1) / segs
		var b0 := base + Vector3(cos(a0) * rb, 0, sin(a0) * rb)
		var b1 := base + Vector3(cos(a1) * rb, 0, sin(a1) * rb)
		var t0 := base + Vector3(cos(a0) * rt, h, sin(a0) * rt)
		var t1 := base + Vector3(cos(a1) * rt, h, sin(a1) * rt)
		var shade := col.darkened(0.12 * ((i % 2)))
		_tri(st, b0, t1, b1, shade)
		_tri(st, b0, t0, t1, shade)


static func _m_cone(st: SurfaceTool, base: Vector3, r: float, h: float, col: Color, segs: int) -> void:
	var tip := base + Vector3(0, h, 0)
	for i in segs:
		var a0 := TAU * i / segs
		var a1 := TAU * (i + 1) / segs
		var b0 := base + Vector3(cos(a0) * r, 0, sin(a0) * r)
		var b1 := base + Vector3(cos(a1) * r, 0, sin(a1) * r)
		_tri(st, b0, tip, b1, col.darkened(0.08 * (i % 2)))
		_tri(st, b0, b1, base, col.darkened(0.3))


static func _m_blob(st: SurfaceTool, c: Vector3, s: Vector3, col: Color, rng: RandomNumberGenerator, jitter := 0.12) -> void:
	## a lumpy low-poly sphere (6 around, 4 rings)
	var segs := 6
	var rings := 4
	var pts := []
	for r in rings + 1:
		var row := []
		var v := float(r) / rings
		var phi := PI * v
		for i in segs:
			var th := TAU * i / segs + (0.5 if r % 2 == 1 else 0.0)
			var p := Vector3(sin(phi) * cos(th), cos(phi), sin(phi) * sin(th))
			if r > 0 and r < rings:
				p *= 1.0 + rng.randf_range(-jitter, jitter)
			row.append(c + p * s)
		pts.append(row)
	for r in rings:
		for i in segs:
			var i2 := (i + 1) % segs
			var a: Vector3 = pts[r][i]
			var b: Vector3 = pts[r][i2]
			var d: Vector3 = pts[r + 1][i]
			var e: Vector3 = pts[r + 1][i2]
			var shade := col.lightened(0.08) if r == 0 else (col.darkened(0.1) if r >= rings - 1 else col)
			if r > 0:
				_tri(st, a, b, d, shade)
			if r < rings - 1:
				_tri(st, b, e, d, shade)


static func _m_beam(st: SurfaceTool, a: Vector3, b: Vector3, w: float, col: Color) -> void:
	var dir := (b - a).normalized()
	var side := dir.cross(Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT).normalized() * w
	var up := dir.cross(side).normalized() * w
	var corners := [side + up, side - up, -side - up, -side + up]
	for i in 4:
		var c0: Vector3 = corners[i]
		var c1: Vector3 = corners[(i + 1) % 4]
		_tri(st, a + c0, b + c0, b + c1, col)
		_tri(st, a + c0, b + c1, a + c1, col)
	_tri(st, b + corners[0], b + corners[2], b + corners[1], col)
	_tri(st, b + corners[0], b + corners[3], b + corners[2], col)
