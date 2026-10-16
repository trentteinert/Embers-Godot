@tool
class_name Items
extends RefCounted
## Gear: random item generation, names, pixel icons, stat totals and tooltip text.
## An item is a plain Dictionary so it saves straight to JSON:
##   {uid, name, slot, type, rarity, ilvl, stats: {str, agi, int, sta, armor, crit, dmg}, mat}

const SLOTS := ["head", "chest", "hands", "legs", "feet", "ring", "amulet", "weapon"]
const SLOT_NAMES := {"head": "Head", "chest": "Chest", "hands": "Hands", "legs": "Legs", "feet": "Feet",
	"ring": "Ring", "amulet": "Amulet", "weapon": "Weapon", "offhand": "Off-hand"}
const SLOT_WEIGHT := {
	"weapon": 1.0,
	"chest": 1.0,
	"legs": 0.9,
	"head": 0.8,
	"hands": 0.6,
	"feet": 0.6,
	"ring": 0.55,
	"amulet": 0.65,
	"offhand": 0.8
}
const ARMOR_SLOTS := ["head", "chest", "hands", "legs", "feet"]

const RARITY_NAMES := ["Common", "Uncommon", "Rare", "Epic", "Legendary"]
const RARITY_COLORS := ["c8c4d0", "6fd05a", "4a9ae8", "b06ae8", "f2994a"]
const RARITY_MULT := [1.0, 1.3, 1.7, 2.2, 3.0]
const STAT_LINES := [1, 2, 2, 3, 4]

const WEAPON_FOR := {"warrior": "sword", "mage": "staff", "hunter": "bow"}
const CLASS_FOR_WEAPON := {"sword": "warrior", "dagger": "warrior", "shortsword": "warrior", "staff": "mage", "bow": "hunter"}
## Weapon types each class finds. Rogues dual wield one-handers: a main hand and an off-hand.
const WEAPON_TYPES_FOR := {"warrior": ["sword", "sword", "dagger", "shortsword"], "mage": ["staff"], "hunter": ["bow"]}
const MAIN_STAT := {"warrior": "str", "mage": "int", "hunter": "agi"}
const STAT_NAMES := {"str": "Strength", "agi": "Agility", "int": "Intellect", "sta": "Stamina", "armor": "Armor", "crit": "Critical Strike", "dmg": "Weapon Damage"}
const STAT_ORDER := ["dmg", "armor", "str", "agi", "int", "sta", "crit"]

const TIER_MATERIAL := [["Copper", "b87333"], ["Iron", "9aa4b0"], ["Steel", "c8d0dc"], ["Frostforged", "9fe0ff"]]
const PREFIX := [["Worn", "Plain", "Sturdy"], ["Fine", "Tempered", "Keen"], ["Gleaming", "Runed", "Valiant"],
	["Ember-touched", "Wardenbound", "Starforged"], ["Hearthfire", "Ancient", "Kingsworn"]]
const BASE_NAMES := {
	"sword": [
		"Sword",
		"Blade",
		"Longsword"
	],
	"shortsword": [
		"Shortsword",
		"Gladius",
		"Cutlass"
	],
	"dagger": [
		"Dagger",
		"Dirk",
		"Stiletto"
	],
	"staff": [
		"Staff",
		"Rod",
		"Stave"
	],
	"bow": [
		"Bow",
		"Longbow",
		"Recurve"
	],
	"head": [
		"Helm",
		"Hood",
		"Cap",
		"Coif"
	],
	"chest": [
		"Chestguard",
		"Tunic",
		"Hauberk",
		"Vest"
	],
	"hands": [
		"Gloves",
		"Gauntlets",
		"Grips",
		"Mitts"
	],
	"legs": [
		"Leggings",
		"Greaves",
		"Trousers",
		"Breeches"
	],
	"feet": [
		"Boots",
		"Treads",
		"Sabatons",
		"Shoes"
	],
	"ring": [
		"Ring",
		"Band",
		"Signet"
	],
	"amulet": [
		"Amulet",
		"Pendant",
		"Talisman"
	],
	"shield": [
		"Shield",
		"Buckler",
		"Aegis"
	]
}
## Armor types by class. Weapons are class-bound already; armor now is too.
const ARMOR_FOR := {"warrior": "plate", "hunter": "mail", "mage": "cloth"}
const ARMOR_NAMES := {
	"plate": {
		"head": [
			"Helm",
			"Greathelm",
			"Visor",
			"Warhelm"
		],
		"chest": [
			"Breastplate",
			"Chestplate",
			"Cuirass",
			"Warplate"
		],
		"hands": [
			"Gauntlets",
			"Plate Gloves",
			"Vambraces",
			"Handguards"
		],
		"legs": [
			"Greaves",
			"Plate Leggings",
			"Cuisses",
			"Tassets"
		],
		"feet": [
			"Sabatons",
			"Plate Boots",
			"Warboots",
			"Ironshod Boots"
		]
	},
	"mail": {
		"head": [
			"Coif",
			"Mail Hood",
			"Ringed Cap",
			"Chain Helm"
		],
		"chest": [
			"Hauberk",
			"Mail Shirt",
			"Chain Vest",
			"Byrnie"
		],
		"hands": [
			"Mail Gloves",
			"Chain Mitts",
			"Ringed Grips",
			"Chain Gauntlets"
		],
		"legs": [
			"Mail Leggings",
			"Chain Chausses",
			"Ringed Trousers",
			"Mail Skirt"
		],
		"feet": [
			"Mail Boots",
			"Chain Treads",
			"Ringed Boots",
			"Chain Sabatons"
		]
	},
	"leather": {
		"head": [
			"Hood",
			"Leather Cap",
			"Cowl",
			"Skullcap"
		],
		"chest": [
			"Jerkin",
			"Leather Tunic",
			"Vest",
			"Brigandine"
		],
		"hands": [
			"Leather Gloves",
			"Grips",
			"Wraps",
			"Bracers"
		],
		"legs": [
			"Leather Trousers",
			"Leggings",
			"Breeches",
			"Chaps"
		],
		"feet": [
			"Leather Boots",
			"Treads",
			"Soft Boots",
			"Riding Boots"
		]
	},
	"cloth": {
		"head": [
			"Hat",
			"Cap",
			"Circlet",
			"Witch Hat"
		],
		"chest": [
			"Robe",
			"Vestments",
			"Tunic",
			"Mantle"
		],
		"hands": [
			"Cloth Wraps",
			"Mitts",
			"Gloves",
			"Sleeves"
		],
		"legs": [
			"Cloth Pants",
			"Skirt",
			"Leggings",
			"Kilt"
		],
		"feet": [
			"Slippers",
			"Sandals",
			"Cloth Boots",
			"Shoes"
		]
	}
}
const SUFFIX := {"str": "of the Bear", "agi": "of the Fox", "int": "of the Owl", "sta": "of the Ox", "crit": "of Precision"}

## 12x12 icons. k=outline, m=material, l=light, d=dark, w=wood/leather, g=gem (rarity colour)
const ICONS := {
	"sword": ["..........kk", ".........klk", "........klmk", ".......klmk.", "......klmk..", ".....klmk...",
		"..k.klmk....", "..kkkmk.....", "...kwkk.....", "..kwk.kk....", ".kgk........", "..k........."],
	"dagger": ["............", "............", "........kkk.", ".......klmk.", "......klmk..", ".....klmk...",
		"..k.klmk....", "..kkkmk.....", "...kwkk.....", "..kwk.kk....", ".kgk........", "..k........."],
	"staff": ["........kkk.", ".......kgggk", ".......kglgk", "........kgk.", ".......kwk..", "......kwk...",
		".....kwk....", "....kwk.....", "...kwk......", "..kwk.......", ".kwk........", "..k........."],
	"bow": ["......kkk...", ".....kwwk...", "....kwk.l...", "...kwk..l...", "...kwk...l..", "..kmk....l..",
		"..kmk....l..", "...kwk...l..", "...kwk..l...", "....kwk.l...", ".....kwwk...", "......kkk..."],
	"head": ["............", "....kkkk....", "...kmmmmk...", "..kmllmmmk..", "..kmlmmmmk..", "..kmmmmmmk..",
		"..kddddddk..", "..kmk..kmk..", "..kmk..kmk..", "..kk....kk..", "............", "............"],
	"chest": ["............", "..kkk..kkk..", ".kmmmkkmmmk.", ".kmlmmmmmmk.", ".kmlmmmmmmk.", "..kmmgmmmk..",
		"..kmmmmmmk..", "..kddddddk..", "..kmmmmmmk..", "..kmmmmmmk..", "...kkkkkk...", "............"],
	"hands": ["............", "..k.k.k.....", ".kmkmkmk....", ".kmkmkmk.k..", ".kmmmmmkkmk.", ".kmlmmmmmk..",
		".kmlmmmmk...", "..kmmmmk....", "..kddddk....", "..kddddk....", "...kkkk.....", "............"],
	"legs": ["............", "..kkkkkkkk..", "..kddddddk..", "..kmlmmmmk..", "..kmlkkmmk..", "..kmk..kmk..",
		"..kmk..kmk..", "..kmk..kmk..", "..kmk..kmk..", "..kdk..kdk..", "..kkk..kkk..", "............"],
	"feet": ["............", "...kkkk.....", "...kmmk.....", "...kmlk.....", "...kmlk.....", "...kmmk.....",
		"...kmmkkk...", "..kmmmmmmk..", "..kmmmmmmmk.", "..kddddddddk", "...kkkkkkkk.", "............"],
	"ring": ["............", ".....kk.....", "....kggk....", "...kkggkk...", "..kmmkkmmk..", "..kmk..kmk..",
		".kmk....kmk.", ".kmk....kmk.", "..kmk..kmk..", "..kmmkkmmk..", "...kkmmkk...", ".....kk....."],
	"amulet": ["..k......k..", "...k....k...", "....k..k....", ".....kk.....", "....kmmk....", "...kmggmk...",
		"..kmgllgmk..", "..kmggggmk..", "...kmggmk...", "....kmmk....", ".....kk.....", "............"],
}

## Rows swapped into the generic armor icons for leather (rogue) pieces: straps, laces, buckles.
const LEATHER_ROWS := {
	"head": {1: "...kkkkkk...", 2: "..kmmmmmmk..", 3: ".kmmllmmmmk.", 4: ".kmlmmmmmmk.", 5: ".kmmkkkkmmk.", 6: ".kmk....kmk.", 7: ".kdk.ss.kdk.", 8: ".kdk....kdk.", 9: ".kk......kk."},
	"chest": {3: ".kmlmwwmmmk.", 4: ".kmlmkwkmmk.", 5: "..kmmwkmmk..", 6: "..kmmkwmmk..", 7: "..kwwwssww..", 8: "..kmmwkmmk.."},
	"hands": {5: ".kwwwwwwwk..", 6: ".kmlmmmmk...", 7: "..kmmmmk....", 8: "..kwwwwk...."},
	"legs": {1: "..kwwwsswwk.", 2: "..kddddddk..", 5: "..kwk..kwk..", 6: "..kmk..kmk..", 8: "..kwk..kwk.."},
	"feet": {3: "...kmlk.....", 4: "...kwwk.....", 5: "...kmmk.....", 6: "...kmmkkk...", 7: "..kmmwwwwk..", 8: "..kmmmmmmmk."},
}
const SHORTSWORD_ICON := ["............", "..........kk", ".........kmk", "........kmlk", ".......kmlk.", "......kmlk..",
	"..k..kmlk...", "..kkkmlk....", "...kwkk.....", "..kwk.......", ".kgk........", "..k........."]

static var _icon_cache := {}
static var _uid := 0


## Names to pick from for an item type (armor depends on its armor type).
static func base_names(type: String, armor := "") -> Array:
	if armor != "" and ARMOR_NAMES.has(armor) and ARMOR_NAMES[armor].has(type):
		return ARMOR_NAMES[armor][type]
	return BASE_NAMES[type]


static func _rand_pick(arr: Array) -> Variant:
	return arr[randi() % arr.size()]


static func roll_rarity(weights: Array) -> int:
	var total := 0.0
	for w: float in weights:
		total += w
	var r := randf() * total
	for i in weights.size():
		r -= weights[i]
		if r <= 0.0:
			return i
	return 0


## Makes a random item. class_id biases weapon type and the main stat; slot "" picks one at random.
static func generate(ilvl: int, class_id: String, rarity: int, slot := "", force_class := false) -> Dictionary:
	if slot == "":
		slot = _rand_pick(SLOTS)
	var type := slot
	if slot == "weapon":
		type = _rand_pick(WEAPON_TYPES_FOR[class_id]) if randf() < 0.7 else _rand_pick(CLASS_FOR_WEAPON.keys())
	var tier := clampi(int((ilvl - 1) / 4.0), 0, 3)
	var budget: float = (2.0 + ilvl * 0.6) * RARITY_MULT[rarity] * float(SLOT_WEIGHT[slot])
	var stats := {}
	if slot == "weapon":
		stats["dmg"] = maxi(1, roundi((1.5 + ilvl * 0.5) * (1.0 + 0.15 * rarity)))
		budget *= 0.6
	elif slot in ARMOR_SLOTS:
		stats["armor"] = roundi((2.0 + ilvl * 1.2) * float(SLOT_WEIGHT[slot]) * (1.0 + 0.15 * rarity))
	# pick stats: main stat (biased to the weapon's class or the player's), stamina, then extras
	var owner: String = CLASS_FOR_WEAPON.get(type, class_id) if slot == "weapon" else (class_id if (force_class or randf() < 0.6) else _rand_pick(MAIN_STAT.keys()))
	var picks: Array = [MAIN_STAT[owner]]
	var pool := ["sta", "str", "agi", "int", "sta"]
	while picks.size() < STAT_LINES[rarity]:
		var s: String = _rand_pick(pool)
		if not s in picks:
			picks.append(s)
	var weights: Array = []
	var wsum := 0.0
	for i in picks.size():
		var w := 1.0 if i == 0 else randf_range(0.4, 0.8)
		weights.append(w)
		wsum += w
	for i in picks.size():
		stats[picks[i]] = maxi(1, roundi(budget * weights[i] / wsum))
	if rarity >= 3 or (rarity == 2 and randf() < 0.4):
		stats["crit"] = snappedf(0.4 + ilvl * 0.05 * (1 + rarity * 0.25), 0.1)
	_uid += 1
	var item := {
		"armor": ARMOR_FOR[owner] if slot in ARMOR_SLOTS else "",
		"uid": int(Time.get_unix_time_from_system()) * 1000 + _uid, "slot": slot, "type": type, "rarity": rarity,
		"ilvl": ilvl, "stats": stats, "mat": TIER_MATERIAL[tier][1],
	}
	item["name"] = _make_name(item, tier, picks)
	return item


static func _make_name(item: Dictionary, tier: int, picks: Array) -> String:
	var r: int = item["rarity"]
	var base: String = _rand_pick(base_names(item["type"], item.get("armor", "")))
	var mat: String = TIER_MATERIAL[tier][0]
	var name: String = "%s %s %s" % [_rand_pick(PREFIX[r]), mat, base]
	if item["slot"] in ["ring", "amulet"]:
		name = "%s %s" % [_rand_pick(PREFIX[r]), base]
	if r >= 1:
		var top: String = "crit" if (item["stats"].has("crit") and r >= 3) else picks[0]
		name += " " + SUFFIX.get(top, "")
	return name.strip_edges()


static func starter_kit(class_id: String) -> Array:
	var w := generate(1, class_id, 0, "weapon")
	w["type"] = WEAPON_FOR[class_id]
	w["name"] = "Worn Copper " + String(BASE_NAMES[w["type"]][0])
	var c := generate(1, class_id, 0, "chest", true)
	c["name"] = "Worn %s" % String(base_names("chest", c["armor"])[0])
	var kit := [w, c]
	if class_id == "rogue":
		var oh := generate(1, class_id, 0, "weapon")
		oh["type"] = "dagger"
		oh["name"] = "Worn Copper Dagger"
		oh["offhand"] = true   # starts in the off-hand
		kit.append(oh)
	return kit


## Anyone can wear anything. Your weapon decides your fighting style (see Main._refit_kit).
static func can_equip(_item: Dictionary, _class_id: String) -> bool:
	return true


static func color(item: Dictionary) -> Color:
	return Color(RARITY_COLORS[int(item["rarity"])])


## Sums the stats of everything equipped (equipment: slot -> item).
static func totals(equipment: Dictionary) -> Dictionary:
	var t := {"str": 0.0, "agi": 0.0, "int": 0.0, "sta": 0.0, "armor": 0.0, "crit": 0.0, "dmg": 0.0}
	for slot: String in equipment:
		var it: Dictionary = equipment[slot]
		if it.is_empty():
			continue
		var mult := upg_mult(it)
		for k: String in it["stats"]:
			var part := 0.5 if (slot == "offhand" and k == "dmg") else 1.0   # the off-hand hits for half
			t[k] = float(t.get(k, 0.0)) + float(it["stats"][k]) * mult * part
	return t


## Each forge upgrade (+1 to +5) raises all of an item's stats by 10%.
static func upg_mult(item: Dictionary) -> float:
	return 1.0 + 0.1 * int(item.get("upg", 0))


static func display_name(item: Dictionary) -> String:
	var u := int(item.get("upg", 0))
	return "%s +%d" % [item["name"], u] if u > 0 else String(item["name"])


const SHIELD_ICON := ["............", "..kkkkkkkk..", ".kmmmmmmmmk.", ".kmllllllmk.", ".kmlmmmmlmk.", ".kmlmssmlmk.", ".kmlmssmlmk.", "..kmlmmlmk..", "..kmmllmmk..", "...kmmmmk...", "....kmmk....", ".....kk....."]


static func icon(item: Dictionary) -> ImageTexture:
	var key := "%s_%s_%d_%s" % [item["type"], item["mat"], int(item["rarity"]), item.get("armor", "")]
	if _icon_cache.has(key):
		return _icon_cache[key]
	var rows: Array = ICONS.get(item["type"], SHORTSWORD_ICON if item["type"] == "shortsword" else (SHIELD_ICON if item["type"] == "shield" else ICONS["ring"]))
	if String(item.get("armor", "")) == "leather" and LEATHER_ROWS.has(item["type"]):
		rows = (rows as Array).duplicate()
		var ov: Dictionary = LEATHER_ROWS[item["type"]]
		for ri: int in ov:
			rows[ri] = ov[ri]
	var m := Color(item["mat"])
	if item["type"] in ["staff", "bow"]:
		m = Color(item["mat"]).lerp(Color("8a5a30"), 0.4)
	var metal := m
	if String(item.get("armor", "")) == "leather":
		m = Color("8a5a34").lerp(m, 0.18)
	var pal := {"k": Color("1a1420"), "m": m, "l": m.lightened(0.4), "d": m.darkened(0.35), "s": metal.lightened(0.2),
		"w": Color("4a3020") if String(item.get("armor", "")) == "leather" else Color("6b4a2c"), "g": color(item) if int(item["rarity"]) > 0 else Color("8a8a9a")}
	var img := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in 12:
		var row: String = rows[y]
		for x in mini(12, row.length()):
			var ch := row[x]
			if pal.has(ch):
				img.set_pixel(x, y, pal[ch])
	var tex := ImageTexture.create_from_image(img)
	_icon_cache[key] = tex
	return tex


## BBCode tooltip, with green/red differences against the equipped item when given.
static func tooltip(item: Dictionary, class_id: String, equipped: Dictionary = {}) -> String:
	var c := color(item).to_html(false)
	var lines: Array[String] = []
	lines.append("[font_size=25][color=#%s]%s[/color][/font_size]" % [c, display_name(item)])
	lines.append("[color=#a89dba]%s %s%s · Item level %d[/color]" % [RARITY_NAMES[int(item["rarity"])], String(item.get("armor", "")).capitalize() + " " if item.get("armor", "") != "" else "", SLOT_NAMES[item["slot"]], int(item["ilvl"])])
	var st: Dictionary = item["stats"]
	var mult := upg_mult(item)
	for k: String in STAT_ORDER:
		if not st.has(k):
			continue
		var v: float = float(st[k]) * mult
		if k == "dmg":
			lines.append("[color=#f1e8d4]+%d Weapon Damage[/color]" % roundi(v))
		elif k == "armor":
			lines.append("[color=#f1e8d4]%d Armor[/color]" % roundi(v))
		elif k == "crit":
			lines.append("[color=#6fd05a]+%.1f%% Critical Strike[/color]" % v)
		else:
			lines.append("[color=#6fd05a]+%d %s[/color]" % [roundi(v), STAT_NAMES[k]])
	if item["slot"] == "weapon":
		var who: String = CLASS_FOR_WEAPON.get(item["type"], "")
		if who != "":
			lines.append("[color=#a89dba]%s weapon[/color]" % Data.SKILLS[Data.COMBAT_SKILL[who]]["name"])
	if not equipped.is_empty() and equipped.get("uid", -1) != item.get("uid", -2):
		lines.append("")
		lines.append("[color=#a89dba]Compared to equipped:[/color]")
		var any := false
		for k: String in STAT_ORDER:
			var a := float(item["stats"].get(k, 0.0)) * upg_mult(item)
			var b := float(equipped["stats"].get(k, 0.0)) * upg_mult(equipped)
			var d := a - b
			if absf(d) < 0.05:
				continue
			any = true
			var col := "6fd05a" if d > 0.0 else "e05a4a"
			if k == "crit":
				lines.append("[color=#%s]%+.1f%% Critical Strike[/color]" % [col, d])
			else:
				lines.append("[color=#%s]%+d %s[/color]" % [col, roundi(d), STAT_NAMES[k]])
		if not any:
			lines.append("[color=#a89dba]No change[/color]")
	return "\n".join(lines)
