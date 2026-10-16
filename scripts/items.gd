@tool
class_name Items
extends RefCounted
## Gear: random item generation, names, pixel icons, stat totals and tooltip text.
## An item is a plain Dictionary so it saves straight to JSON:
##   {uid, name, slot, type, rarity, ilvl, stats: {str, agi, int, sta, armor, crit, dmg}, mat}

const SLOTS := ["head", "chest", "cloak", "hands", "legs", "feet", "ring", "amulet", "weapon"]
const SLOT_NAMES := {"head": "Head", "chest": "Chest", "hands": "Hands", "legs": "Legs", "feet": "Feet",
	"ring": "Ring", "amulet": "Amulet", "weapon": "Weapon", "offhand": "Off-hand", "cloak": "Cloak"}
const SLOT_WEIGHT := {
	"weapon": 1.0,
	"chest": 1.0,
	"legs": 0.9,
	"head": 0.8,
	"hands": 0.6,
	"feet": 0.6,
	"ring": 0.55,
	"amulet": 0.65,
	"offhand": 0.8,
	"cloak": 0.5
}
const ARMOR_SLOTS := ["head", "chest", "cloak", "hands", "legs", "feet"]

const RARITY_NAMES := ["Common", "Uncommon", "Rare", "Epic", "Legendary"]
const RARITY_COLORS := ["c8c4d0", "6fd05a", "4a9ae8", "b06ae8", "f2994a"]
const RARITY_MULT := [1.0, 1.3, 1.7, 2.2, 3.0]
const STAT_LINES := [1, 2, 2, 3, 4]

const WEAPON_FOR := {"warrior": "sword", "mage": "staff", "hunter": "bow"}
const CLASS_FOR_WEAPON := {"sword": "warrior", "dagger": "warrior", "shortsword": "warrior", "staff": "mage", "bow": "hunter"}
## Weapon types each class finds. Rogues dual wield one-handers: a main hand and an off-hand.
const WEAPON_TYPES_FOR := {"warrior": ["sword", "sword", "dagger", "shortsword"], "mage": ["staff"], "hunter": ["bow"]}
const MAIN_STAT := {
	"warrior": "str",
	"mage": "int",
	"hunter": "agi",
	"rogue": "agi"
}
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
		"Greathelm",
		"Visor",
		"Warhelm",
		"Crownhelm"
	],
	"chest": [
		"Breastplate",
		"Chestplate",
		"Cuirass",
		"Warplate",
		"Kingsplate"
	],
	"hands": [
		"Gauntlets",
		"Plate Gloves",
		"Vambraces",
		"Handguards",
		"Titan Fists"
	],
	"legs": [
		"Greaves",
		"Plate Leggings",
		"Cuisses",
		"Tassets",
		"Legplates"
	],
	"feet": [
		"Sabatons",
		"Plate Boots",
		"Warboots",
		"Ironshod Boots",
		"Titan Treads"
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
	],
	"cloak": [
		"Cape",
		"Mantle Cape",
		"Battle Cloak",
		"Warcloak",
		"Kingsmantle"
	]
}
## Armor types by class. Weapons are class-bound already; armor now is too.
const ARMOR_FOR := {
	"warrior": "plate",
	"hunter": "mail",
	"mage": "cloth",
	"rogue": "leather"
}
const ARMOR_NAMES := {
	"plate": {
		"head": [
			"Helm",
			"Greathelm",
			"Visor",
			"Warhelm",
			"Crownhelm"
		],
		"chest": [
			"Breastplate",
			"Chestplate",
			"Cuirass",
			"Warplate",
			"Kingsplate"
		],
		"hands": [
			"Gauntlets",
			"Plate Gloves",
			"Vambraces",
			"Handguards",
			"Titan Fists"
		],
		"legs": [
			"Greaves",
			"Plate Leggings",
			"Cuisses",
			"Tassets",
			"Legplates"
		],
		"feet": [
			"Sabatons",
			"Plate Boots",
			"Warboots",
			"Ironshod Boots",
			"Titan Treads"
		],
		"cloak": [
			"Cape",
			"Mantle Cape",
			"Battle Cloak",
			"Warcloak",
			"Kingsmantle"
		]
	},
	"mail": {
		"head": [
			"Coif",
			"Mail Hood",
			"Ringed Cap",
			"Chain Helm",
			"Warden Coif"
		],
		"chest": [
			"Hauberk",
			"Mail Shirt",
			"Chain Vest",
			"Byrnie",
			"Warden Hauberk"
		],
		"hands": [
			"Mail Gloves",
			"Chain Mitts",
			"Ringed Grips",
			"Chain Gauntlets",
			"Warden Mitts"
		],
		"legs": [
			"Mail Leggings",
			"Chain Chausses",
			"Ringed Trousers",
			"Mail Skirt",
			"Warden Chausses"
		],
		"feet": [
			"Mail Boots",
			"Chain Treads",
			"Ringed Boots",
			"Chain Sabatons",
			"Warden Treads"
		],
		"cloak": [
			"Wayfarer Cloak",
			"Ranger Cloak",
			"Warden Cloak",
			"Greencloak",
			"Wildmantle"
		]
	},
	"leather": {
		"head": [
			"Hood",
			"Leather Cap",
			"Cowl",
			"Skullcap",
			"Shadow Cowl"
		],
		"chest": [
			"Jerkin",
			"Leather Tunic",
			"Vest",
			"Brigandine",
			"Shadowcoat"
		],
		"hands": [
			"Leather Gloves",
			"Grips",
			"Wraps",
			"Bracers",
			"Nightgrips"
		],
		"legs": [
			"Leather Trousers",
			"Leggings",
			"Breeches",
			"Chaps",
			"Shadow Pants"
		],
		"feet": [
			"Leather Boots",
			"Treads",
			"Soft Boots",
			"Riding Boots",
			"Shadowsteps"
		],
		"cloak": [
			"Cloak",
			"Hooded Cloak",
			"Shadow Cloak",
			"Nightcloak",
			"Wraith Mantle"
		]
	},
	"cloth": {
		"head": [
			"Hat",
			"Pointed Cap",
			"Circlet",
			"Witch Hat",
			"Archmage Hat"
		],
		"chest": [
			"Robe",
			"Vestments",
			"Tunic",
			"Mantle",
			"Archrobe"
		],
		"hands": [
			"Cloth Wraps",
			"Mitts",
			"Gloves",
			"Sleeves",
			"Spellwraps"
		],
		"legs": [
			"Cloth Pants",
			"Skirt",
			"Leggings",
			"Kilt",
			"Spellskirt"
		],
		"feet": [
			"Slippers",
			"Sandals",
			"Cloth Boots",
			"Shoes",
			"Spellslippers"
		],
		"cloak": [
			"Shawl",
			"Wrap",
			"Cape of Silk",
			"Mage Cloak",
			"Arch Mantle"
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
	"cloak": ["............", "...kkkkkk...", "..kmmggmmk..", ".kmmlmmmmmk.", ".kmlmdmmdmk.", "kmmlmdmmdmmk", "kmlmmdmmdmmk", "kmlmmdmmdmmk", "kmmmmdmmdmmk", "kmmdmmmmmdmk", "kdddmmmmdddk", "kkkkkkkkkkkk"],
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
## Distinct icons per armor type: plate = the generic rows above, leather = LEATHER_ROWS on top of them, and full rows for mail
## (c = chain links) and cloth.
const MAIL_ROWS := {
	"head": ["............", "...kkkkkk...", ".kcccccccck.", ".kcccccccck.", ".kcckkkkcck.", ".kckddddkck.", ".kckddddkck.", ".kcccccccck.", ".kcccccccck.", "..kcccccck..", "...kkkkkk...", "............"],
	"chest": ["............", ".kkkk..kkkk.", "kcccccccccck", "kcccccccccck", "kcccc..cccck", "kcckccccckck", "kcc.kccck.ck", ".kc.kcccck.k", "..kkcccccck.", "..kdccccccdk", "..kddddddddk", "...kkkkkkkk."],
	"hands": ["............", "..k.k.k.....", ".kckckck....", ".kckckck.k..", ".kcccccckck.", ".kcdcccccck.", ".kcdccccck..", "..kccccck...", "..kdddddk...", "..kdddddk...", "...kkkkk....", "............"],
	"legs": ["............", "..kkkkkkkk..", ".kcccccccck.", "..kccccccck.", "..kccllcck..", "..kcck.kcck.", "..kcck.kcck.", "..kcck.kcck.", "..kcck.kcck.", "..kdck.kdck.", "..kkkk.kkkk.", "............"],
	"feet": ["............", "...kkkkk....", "...kcccck...", "...kccck....", "...kddck....", "...kcccck...", "...kccckkk..", "..kccccccck.", "..kcccccccck", "..kddddddddk", "...kkkkkkkk.", "............"],
}
const CLOTH_ROWS := {
	"head": [".....kk.....", "....kmmk....", "....kmmk....", "...kmmmmk...", "...kmlmmk...", "..kmmmmmmk..", ".kmmmmmmmmk.", ".kggggggggk.", "kmmmmmmmmmmk", ".kddddddddk.", "..kkkkkkkk..", "............"],
	"chest": ["............", "...kkkkkk...", "..kmmllmmk..", ".kmmmmmmmmk.", "kmmmmggmmmmk", "kmkmmmmmmkmk", "kmkmmmmmmkmk", "kmkmmmmmmkmk", "kkkmmmmmmkkk", "..kmmmmmmk..", "..kddddddk..", "...kkkkkk..."],
	"hands": ["............", "...kkkk.....", "..kmmmmk.kk.", "..kllllkkmk.", "..kmmmmmmmk.", "..kllllmmk..", "..kmmmmmk...", "..kllllmk...", "..kmmmmmk...", "..kddddk....", "...kkkk.....", "............"],
	"legs": ["............", "..kkkkkkkk..", "..kmmmmmmk..", "..kmlmmmmk..", "..kmmkkmmk..", "..kmk..kmk..", "..kmk..kmk..", "..kmk..kmk..", ".kmmk..kmmk.", ".kddk..kddk.", ".kkkk..kkkk.", "............"],
	"feet": ["............", "...kkkk.....", "...kmmk.....", "...kmlk.....", "...kmmk.....", "...kmmk.....", "...kmmkkk...", "..kmmmmmmkk.", ".kmmmmmmmmmk", "kmmddddddmmk", ".kkkkkkkkkk.", "............"],
}

## The extra pieces of a rarity's design (the same ones the 3D armor gets, see Models._style_parts) as pixels per slot: [x, y, char]
const DESIGN_PIXELS := {
	"head": {1: [[5, 1, "g"], [6, 1, "g"], [5, 0, "g"], [6, 0, "g"]], 2: [[4, 1, "s"], [5, 1, "s"], [6, 1, "s"], [7, 1, "s"]], 3: [[1, 2, "e"], [1, 1, "e"], [10, 2, "e"], [10, 1, "e"], [0, 0, "e"], [11, 0, "e"]]},
	"chest": {1: [[3, 2, "g"], [4, 3, "g"], [5, 4, "g"], [6, 5, "g"], [7, 6, "g"], [8, 7, "g"]], 2: [[4, 3, "s"], [5, 3, "s"], [6, 3, "s"], [7, 3, "s"], [4, 4, "s"], [5, 4, "s"], [6, 4, "s"], [7, 4, "s"]], 3: [[4, 2, "s"], [5, 2, "s"], [6, 2, "s"], [7, 2, "s"], [2, 8, "w"], [9, 8, "w"]]},
	"hands": {1: [[2, 6, "g"], [3, 6, "g"], [4, 6, "g"], [5, 6, "g"]], 2: [[2, 8, "s"], [3, 8, "s"], [4, 8, "s"], [5, 8, "s"]], 3: [[3, 4, "g"], [5, 4, "g"], [7, 4, "g"]]},
	"legs": {1: [[3, 5, "s"], [4, 5, "s"], [7, 5, "s"], [8, 5, "s"]], 2: [[2, 3, "g"], [2, 4, "g"], [2, 5, "g"], [2, 6, "g"], [9, 3, "g"], [9, 4, "g"]], 3: [[3, 9, "g"], [4, 9, "g"], [7, 9, "g"], [8, 9, "g"]]},
	"cloak": {1: [[1, 10, "g"], [2, 10, "g"], [3, 10, "g"], [4, 10, "g"], [7, 10, "g"], [8, 10, "g"], [9, 10, "g"], [10, 10, "g"]], 2: [[2, 3, "s"], [3, 3, "s"], [4, 3, "s"], [7, 3, "s"], [8, 3, "s"], [9, 3, "s"]], 3: [[4, 1, "s"], [5, 1, "s"], [6, 1, "s"], [7, 1, "s"], [5, 0, "s"], [6, 0, "s"]]},
	"feet": {1: [[3, 3, "g"], [4, 3, "g"], [5, 3, "g"]], 2: [[6, 8, "s"], [7, 8, "s"], [8, 8, "s"]], 3: [[3, 6, "g"], [4, 6, "g"], [5, 6, "g"]]},
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


## What colour a piece of armor is: its armor type's own base colour, tinted by its rarity (Common is the plain base).
const ARMOR_BASE := {"plate": "9aa4b0", "mail": "7a8a82", "leather": "8a6038", "cloth": "6a5aa0"}
const ARMOR_TINT := [0.0, 0.5, 0.55, 0.6, 0.6]


static func armor_col(item: Dictionary, armor: String) -> Color:
	if not ARMOR_BASE.has(armor):
		return Color(String(item.get("mat", "8a8a8e")))   # rags and anything else keep their own colour
	var r := clampi(int(item.get("rarity", 0)), 0, 4)
	return Color(String(ARMOR_BASE[armor])).lerp(Color(String(RARITY_COLORS[r])), float(ARMOR_TINT[r]))


## The extras a rarity's design has: Uncommon the first, Rare the second, Epic the third, Legendary the second and third.
static func design_parts(rarity: int) -> Array:
	return [[], [1], [2], [3], [2, 3]][clampi(rarity, 0, 4)]


static func icon(item: Dictionary) -> ImageTexture:
	var key := "%s_%s_%d_%s" % [item["type"], item["mat"], int(item["rarity"]), item.get("armor", "")]
	if _icon_cache.has(key):
		return _icon_cache[key]
	var armor := String(item.get("armor", ""))
	var type := String(item["type"])
	var rows: Array = ICONS.get(type, SHORTSWORD_ICON if type == "shortsword" else (SHIELD_ICON if type == "shield" else ICONS["ring"]))
	if armor == "leather" and LEATHER_ROWS.has(type):
		rows = (rows as Array).duplicate()
		var ov: Dictionary = LEATHER_ROWS[type]
		for ri: int in ov:
			rows[ri] = ov[ri]
	elif armor == "mail" and MAIL_ROWS.has(type):
		rows = MAIL_ROWS[type]
	elif armor == "cloth" and CLOTH_ROWS.has(type):
		rows = CLOTH_ROWS[type]
	var is_armor := ARMOR_BASE.has(armor) and ARMOR_SLOTS.has(type)
	var m := armor_col(item, armor) if is_armor else Color(item["mat"])
	if type in ["staff", "bow"]:
		m = Color(item["mat"]).lerp(Color("8a5a30"), 0.4)
	var metal := m
	var rar := int(item["rarity"])
	var pal := {"k": Color("1a1420"), "m": m, "l": m.lightened(0.4), "d": m.darkened(0.35), "s": metal.lightened(0.2),
		"c": m.lightened(0.15), "e": Color("e8e0c8"),
		"w": Color("4a3020") if armor == "leather" else Color("6b4a2c"), "g": color(item) if rar > 0 else Color("8a8a9a")}
	if armor == "mail":
		pal["c"] = m   # chain links: every other pixel a little lighter (set below)
	var img := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in 12:
		var row: String = rows[y]
		for x in mini(12, row.length()):
			var ch := row[x]
			if ch == "c":
				img.set_pixel(x, y, m.lightened(0.28) if (x + y) % 2 == 0 else m.darkened(0.12))
			elif pal.has(ch):
				img.set_pixel(x, y, pal[ch])
	# the rarity's design: the same extras the 3D armor gets (crest, plate, sash, horns, trim)
	if is_armor and DESIGN_PIXELS.has(type):
		for part: int in design_parts(rar):
			for px: Array in DESIGN_PIXELS[type].get(part, []):
				var pc: String = px[2]
				if pc == "g":
					img.set_pixel(px[0], px[1], pal["g"])
				else:
					img.set_pixel(px[0], px[1], pal[pc])
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
