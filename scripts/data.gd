@tool
extends Node
## Shared game data (autoloaded as "Data"): classes, abilities, story text, sprites and key bindings.
## Most tuning lives here, so you can tweak numbers and text without touching game logic.

const BIOME_NAMES := ["Greenreach Meadow", "Thornwood", "The Mire", "Frostspine Peaks", "The Shore"]
const BIOME_REC_LEVEL := [4, 12, 22, 30, 1]


# ---------------------------------------------------------------- zones
## The island's named regions, as painted on the world plan. `biome` picks the creatures, trees and ground
## (0 meadow, 1 thornwood, 2 mire, 3 peaks); `lo`..`hi` is the level range the zone runs through.
const ZONES := [
	{"id": "campwater", "name": "Campwater Vale", "biome": 0, "lo": 3, "hi": 10},
	{"id": "tallowfields", "name": "Tallowfields", "biome": 0, "lo": 1, "hi": 8},
	{"id": "hearthmoor", "name": "Hearthmoor Basin", "biome": 0, "lo": 6, "hi": 15},
	{"id": "brackenwood", "name": "Brackenwood Fringe", "biome": 1, "lo": 9, "hi": 18},
	{"id": "blackbriar", "name": "Blackbriar Wilds", "biome": 1, "lo": 12, "hi": 21},
	{"id": "saltfen", "name": "Saltfen Reach", "biome": 2, "lo": 19, "hi": 28},
	{"id": "bellwater", "name": "Bellwater Delta", "biome": 2, "lo": 10, "hi": 18},
	{"id": "greyfold", "name": "Greyfold Downs", "biome": 3, "lo": 22, "hi": 34},
	{"id": "frostspine", "name": "Frostspine Crown", "biome": 3, "lo": 29, "hi": 38},
]

# ---------------------------------------------------------------- classes
const CLASS_ORDER := ["warrior", "mage", "hunter"]
const CLASSES := {
	"warrior": {
		"name": "Fighter", "hp": 140, "speed": 4.6, "resource": "Energy", "res_color": "e8c23a", "res_start_full": true,
		"desc": "Close-quarters fighter. Fast-regenerating Energy. Lean tank, stealth or poison through talents.",
		"pal": {"H": "8c96a3", "a": "9c2f2f", "b": "d8b04a", "d": "5a2626"},
	},
	"rogue": {
		"name": "Rogue", "hp": 95, "speed": 5.6, "resource": "Energy", "res_color": "e8c23a", "res_start_full": true,
		"desc": "Fast daggers and dirty tricks. Energy refills quickly.",
		"pal": {"H": "2f3340", "a": "3d4452", "b": "7a1e2c", "d": "22252e"},
	},
	"mage": {
		"name": "Mage", "hp": 80, "speed": 4.4, "resource": "Mana", "res_color": "4a8ae0", "res_start_full": true,
		"desc": "Fragile, but bends fire, frost and lightning.",
		"pal": {"H": "5b3c9e", "a": "6e4bc0", "b": "e0c060", "d": "3e2a70"},
	},
	"hunter": {
		"name": "Hunter", "hp": 100, "speed": 5.0, "resource": "Focus", "res_color": "e08a3a", "res_start_full": true,
		"desc": "Steady bow, long reach, traps and a spirit wolf.",
		"pal": {"H": "3f6b3a", "a": "6b5032", "b": "a8c070", "d": "3e2e1e"},
	},
}

## Six abilities per class, bound to Q E R T F C. "lvl" is the unlock level.
const ABILITIES := {
	"warrior": [
		{"id": "strike", "name": "Strike", "ab": "ST", "cost": 20, "cd": 2.0, "lvl": 1, "hue": "c8603a", "desc": "A hard, focused blow to one enemy. Everyone fights with it. The deep talents change it."},
		# ---- Bulwark: the fighter in the thick of it
		{"id": "charge", "name": "Charge", "ab": "CH", "cost": 15, "cd": 8.0, "lvl": 1, "hue": "c0802e", "talent": "bw_charge", "desc": "Needs a target within 12 m. Rush it, stunning what you hit. Costs 15 Energy."},
		{"id": "cleave", "name": "Cleave", "ab": "CL", "cost": 25, "cd": 3.0, "lvl": 1, "hue": "b8503a", "talent": "bw_cleave", "desc": "Sweep a wide arc in front of you for heavy damage."},
		{"id": "whirl", "name": "Whirlwind", "ab": "WW", "cost": 40, "cd": 5.0, "lvl": 1, "hue": "c09a3a", "talent": "bw_whirl", "desc": "Spin and strike everything around you."},
		{"id": "shout", "name": "Battle Shout", "ab": "BS", "cost": 30, "cd": 18.0, "lvl": 1, "hue": "c84a3e", "talent": "bw_shout", "desc": "Heal 20% of your health and deal 30% more damage for 8s."},
		{"id": "slam", "name": "Ground Slam", "ab": "GS", "cost": 55, "cd": 10.0, "lvl": 1, "hue": "8a6038", "talent": "bw_slam", "desc": "Smash the ground. Big damage, and slows foes nearby."},
		{"id": "stand", "name": "Last Stand", "ab": "LS", "cost": 35, "cd": 30.0, "lvl": 1, "hue": "6c7684", "talent": "bw_stand", "desc": "Take 70% less damage for 5s."},
		# ---- Shadow: the stealthy blade
		{"id": "step", "name": "Shadow Step", "ab": "SS", "cost": 30, "cd": 1.5, "lvl": 1, "hue": "4e4280", "talent": "sh_step", "desc": "Needs a target within 9 m. Dash through it, cutting each enemy on the way. You cannot be hit mid-dash."},
		{"id": "stealth", "name": "Stealth", "ab": "ST", "cost": 20, "cd": 14.0, "lvl": 1, "hue": "3a3458", "talent": "sh_stealth", "desc": "Slip out of sight for up to 15s. Enemies lose track of you. Your first hit from stealth always crits, then you are seen."},
		{"id": "backstab", "name": "Backstab", "ab": "BK", "cost": 40, "cd": 0.5, "lvl": 1, "hue": "a02a3a", "talent": "sh_backstab_old", "desc": "A precise strike for huge damage at close range."},
		{"id": "smoke", "name": "Smoke Bomb", "ab": "SB", "cost": 45, "cd": 8.0, "lvl": 1, "hue": "555566", "talent": "sh_smoke", "desc": "Burst a cloud of smoke: nearby foes are slowed, and you vanish for 5s."},
		{"id": "flurry", "name": "Blade Flurry", "ab": "BF", "cost": 55, "cd": 8.0, "lvl": 1, "hue": "b8963a", "talent": "sh_flurry", "desc": "Attack twice as fast for 5s."},
		{"id": "assassinate", "name": "Assassinate", "ab": "AS", "cost": 60, "cd": 15.0, "lvl": 1, "hue": "7a1e2c", "talent": "sh_assassinate", "desc": "Needs a target within 8 m. Vanish and reappear behind it for a devastating strike."},
		# ---- Venom: poison and attrition
		{"id": "poison", "name": "Poison Blade", "ab": "PB", "cost": 30, "cd": 4.0, "lvl": 1, "hue": "4e8a32", "talent": "ve_poison", "desc": "For 8s, every hit poisons the enemy."},
		{"id": "fan", "name": "Phantom Knives", "ab": "PK", "cost": 40, "cd": 1.0, "lvl": 1, "hue": "6c7684", "talent": "ve_fan", "desc": "Throw spectral knives in every direction. With Poison Blade up, every knife poisons."},
		{"id": "venomburst", "name": "Venom Burst", "ab": "VB", "cost": 50, "cd": 12.0, "lvl": 1, "hue": "6ac040", "talent": "ve_burst", "desc": "Detonate the poison on every poisoned enemy within 14 m, dealing all of its remaining damage at once."},
	],
	"mage": [
		{"id": "fireball", "name": "Fireball", "ab": "FB", "cost": 25, "cd": 0.6, "lvl": 1, "hue": "c8502a", "desc": "Hurl a fireball that explodes on impact."},
		{"id": "blink", "name": "Blink", "ab": "BL", "cost": 30, "cd": 2.0, "lvl": 1, "hue": "8a5ad0", "desc": "Teleport a short distance straight ahead, the way your character faces."},
		{"id": "nova", "name": "Frost Nova", "ab": "FN", "cost": 40, "cd": 2.0, "lvl": 3, "hue": "3a8ab8", "desc": "Blast nearby foes with frost and slow them."},
		{"id": "barrier", "name": "Arcane Barrier", "ab": "AB", "cost": 60, "cd": 6.0, "lvl": 5, "hue": "7a52b8", "desc": "A shield that absorbs damage equal to 40% of your health for 8s."},
		{"id": "chain", "name": "Chain Lightning", "ab": "LI", "cost": 45, "cd": 1.5, "lvl": 8, "hue": "b8a030", "desc": "Lightning jumps between up to 5 enemies."},
		{"id": "meteor", "name": "Meteor", "ab": "MT", "cost": 80, "cd": 4.0, "lvl": 12, "hue": "d0602a", "desc": "Call down a meteor where you aim. Huge damage after a short delay."},
	],
	"hunter": [
		{"id": "power", "name": "Power Shot", "ab": "PS", "cost": 40, "cd": 3.0, "lvl": 1, "hue": "b08a40", "desc": "A heavy arrow that pierces every enemy in its path."},
		{"id": "disengage", "name": "Disengage", "ab": "DG", "cost": 25, "cd": 5.0, "lvl": 1, "hue": "507a44", "desc": "Leap backward, away from where you aim."},
		{"id": "volley", "name": "Volley", "ab": "VO", "cost": 50, "cd": 4.0, "lvl": 3, "hue": "a8903a", "desc": "Loose five arrows in a fan."},
		{"id": "trap", "name": "Snare Trap", "ab": "ST", "cost": 30, "cd": 10.0, "lvl": 5, "hue": "7a6040", "desc": "Set a trap that roots and hurts the first enemy to step on it."},
		{"id": "rain", "name": "Rain of Arrows", "ab": "RA", "cost": 70, "cd": 12.0, "lvl": 8, "hue": "8aa040", "desc": "Arrows fall on the area you aim at for 2s."},
		{"id": "wolf", "name": "Spirit Wolf", "ab": "SW", "cost": 80, "cd": 30.0, "lvl": 12, "hue": "3a8ab0", "desc": "Summon a spirit wolf to fight beside you for 15s."},
	],
}

# ---------------------------------------------------------------- talents
## One talent point every 2 levels (15 at level 30). A node needs "tier * 2" points already spent in its tree.
## "ability": the ability id it teaches (see ABILITIES); other nodes are passives read by combat.gd and player.gd.
## Melee has three leanings you can mix freely: Bulwark (tank), Shadow (stealth burst) and Venom (poison).
const TALENT_TREES := {
	"warrior": [
		{"id": "bulwark", "name": "Bulwark", "color": "d9783a", "desc": "Stand in the thick of it. Armor, health and heavy blows, and Energy back from every hit you take."},
		{"id": "shadow", "name": "Shadowblade", "color": "9a7ae0", "desc": "Stealth, ambush and burst. Open from the shadows and end the fight in a handful of strikes."},
		{"id": "venom", "name": "Venomcraft", "color": "6ac040", "desc": "Poisons and attrition. Pile on damage over time, then walk away or detonate it."},
	],
}
const TALENTS := {
	"warrior": [
		# ---------------- Bulwark
		{"id": "bw_charge", "col": 0, "tree": "bulwark", "tier": 0, "max": 1, "name": "Charge", "desc": "Learn Charge: rush a target within 12 m and stun it.", "ability": "charge"},
		{"id": "bw_cleave", "col": 1, "tree": "bulwark", "tier": 0, "max": 1, "name": "Cleave", "desc": "Learn Cleave: sweep a wide arc for heavy damage.", "ability": "cleave"},
		{"id": "bw_thick", "col": 2, "tree": "bulwark", "tier": 0, "max": 3, "name": "Thick Skin", "desc": "+10% armor per rank."},
		{"id": "bw_vital", "col": 3, "tree": "bulwark", "tier": 0, "max": 3, "name": "Vitality", "desc": "+5% maximum health per rank."},
		{"id": "bw_shout", "col": 0, "tree": "bulwark", "tier": 1, "max": 1, "name": "Battle Shout", "desc": "Learn Battle Shout: heal and hit harder for 8s.", "ability": "shout"},
		{"id": "bw_stalwart", "col": 1, "tree": "bulwark", "tier": 1, "max": 3, "name": "Stalwart", "desc": "Take 3% less damage per rank."},
		{"id": "bw_heavy", "col": 2, "tree": "bulwark", "tier": 1, "max": 3, "name": "Heavy Hands", "desc": "+5% damage per rank."},
		{"id": "bw_rally", "col": 3, "tree": "bulwark", "tier": 1, "max": 3, "name": "Rally", "desc": "Hits you take restore Energy: 15% of the damage per rank."},
		{"id": "bw_whirl", "col": 0, "req": "bw_cleave", "tree": "bulwark", "tier": 2, "max": 1, "name": "Whirlwind", "desc": "Learn Whirlwind: spin and strike everything around you.", "ability": "whirl"},
		{"id": "bw_second", "col": 1, "tree": "bulwark", "tier": 2, "max": 2, "name": "Second Wind", "desc": "Heal 3% of your health per rank on a kill."},
		{"id": "bw_quick", "col": 2, "tree": "bulwark", "tier": 2, "max": 2, "name": "Battle Rhythm", "desc": "Attack 6% faster per rank."},
		{"id": "bw_blood", "col": 3, "tree": "bulwark", "tier": 2, "max": 2, "name": "Bloodlust", "desc": "Restore 10 Energy per rank on a kill."},
		{"id": "bw_slam", "col": 0, "req": "bw_shout", "tree": "bulwark", "tier": 3, "max": 1, "name": "Ground Slam", "desc": "Learn Ground Slam: big damage and slows foes nearby.", "ability": "slam"},
		{"id": "bw_crit", "col": 1, "tree": "bulwark", "tier": 3, "max": 3, "name": "Crushing Blows", "desc": "+3% critical strike chance per rank."},
		{"id": "bw_exec", "col": 2, "tree": "bulwark", "tier": 3, "max": 2, "name": "Finisher", "desc": "+15% damage per rank to enemies below 30% health."},
		{"id": "bw_unbreak", "col": 3, "tree": "bulwark", "tier": 3, "max": 2, "name": "Unbreakable", "desc": "+10% armor per rank."},
		{"id": "bw_stand", "col": 0, "req": "bw_stalwart", "tree": "bulwark", "tier": 4, "max": 1, "name": "Last Stand", "desc": "Learn Last Stand: take 70% less damage for 5s.", "ability": "stand"},
		{"id": "bw_titan", "col": 1, "tree": "bulwark", "tier": 4, "max": 2, "name": "Titan", "desc": "+5% maximum health and +5% damage per rank."},
		{"id": "bw_marked", "col": 2, "tree": "bulwark", "tier": 4, "max": 2, "name": "Giant Slayer", "desc": "+10% damage per rank to elites and bosses."},
		{"id": "bw_vigor", "col": 3, "tree": "bulwark", "tier": 4, "max": 2, "name": "Bloodrush", "desc": "+10% Energy regeneration per rank."},
		{"id": "bw_heroic", "col": 1, "tree": "bulwark", "tier": 5, "max": 1, "name": "Heroic Strike", "desc": "Strike becomes Heroic Strike: it hits much harder and heals you for 6% of your health."},
		# ---------------- Shadow
		{"id": "sh_ambush", "col": 0, "tree": "shadow", "tier": 0, "max": 3, "name": "Ambush", "desc": "+30% damage per rank on your first hit from stealth."},
		{"id": "sh_keen", "col": 1, "tree": "shadow", "tier": 0, "max": 3, "name": "Keen Edge", "desc": "+4% critical strike chance per rank."},
		{"id": "sh_step", "col": 2, "tree": "shadow", "tier": 0, "max": 1, "name": "Shadow Step", "desc": "Learn Shadow Step: dash through a target within 9 m, untouchable mid-dash.", "ability": "step"},
		{"id": "sh_stealth", "col": 3, "tree": "shadow", "tier": 0, "max": 1, "name": "Stealth", "desc": "Learn Stealth: slip out of sight. Your first hit from stealth always crits.", "ability": "stealth"},
		{"id": "sh_backstab", "col": 0, "tree": "shadow", "tier": 1, "max": 1, "name": "Backstab", "desc": "Strike becomes Backstab: a precise blow at close range for huge damage."},
		{"id": "sh_prep", "col": 1, "req": "sh_keen", "tree": "shadow", "tier": 1, "max": 2, "name": "Preparation", "desc": "Stealth and Smoke Bomb cool down 20% faster per rank."},
		{"id": "sh_evasion", "col": 2, "tree": "shadow", "tier": 1, "max": 3, "name": "Evasion", "desc": "+3% chance to dodge an attack per rank."},
		{"id": "sh_edge", "col": 3, "tree": "shadow", "tier": 1, "max": 3, "name": "Sharpened Blades", "desc": "+5% damage per rank."},
		{"id": "sh_smoke", "col": 0, "req": "sh_stealth", "tree": "shadow", "tier": 2, "max": 1, "name": "Smoke Bomb", "desc": "Learn Smoke Bomb: slow nearby foes and vanish.", "ability": "smoke"},
		{"id": "sh_deep", "col": 1, "req": "sh_prep", "tree": "shadow", "tier": 2, "max": 2, "name": "Deep Cover", "desc": "Stealth lasts 5s longer per rank."},
		{"id": "sh_nimble", "col": 2, "tree": "shadow", "tier": 2, "max": 3, "name": "Fleet Footed", "desc": "+4% movement speed per rank."},
		{"id": "sh_quick", "col": 3, "tree": "shadow", "tier": 2, "max": 2, "name": "Quick Hands", "desc": "Attack 8% faster per rank."},
		{"id": "sh_flurry", "col": 0, "req": "sh_smoke", "tree": "shadow", "tier": 3, "max": 1, "name": "Blade Flurry", "desc": "Learn Blade Flurry: attack twice as fast for 5s.", "ability": "flurry"},
		{"id": "sh_lethal", "col": 1, "tree": "shadow", "tier": 3, "max": 3, "name": "Lethality", "desc": "Critical strikes deal 20% more damage per rank."},
		{"id": "sh_exec", "col": 2, "tree": "shadow", "tier": 3, "max": 2, "name": "Executioner", "desc": "+15% damage per rank to enemies below 30% health."},
		{"id": "sh_dual", "col": 3, "tree": "shadow", "tier": 3, "max": 1, "name": "Dual Wield", "desc": "Unlocks your off-hand: wield a second one-handed weapon."},
		{"id": "sh_opp", "col": 0, "tree": "shadow", "tier": 4, "max": 2, "name": "Opportunist", "desc": "+5% critical strike chance per rank."},
		{"id": "sh_dance", "col": 1, "tree": "shadow", "tier": 4, "max": 1, "name": "Shadow Dance", "desc": "Leaving stealth with an attack refunds 30 Energy."},
		{"id": "sh_cloak", "col": 2, "tree": "shadow", "tier": 4, "max": 1, "name": "Shadow Cloak", "desc": "Dropping below 30% health cloaks you in stealth for 4s. 45s cooldown."},
		{"id": "sh_marked", "col": 3, "tree": "shadow", "tier": 4, "max": 2, "name": "Marked for Death", "desc": "+10% damage per rank to elites and bosses."},
		{"id": "sh_assassinate", "col": 1, "tree": "shadow", "tier": 5, "max": 1, "name": "Assassinate", "desc": "Learn Assassinate: reappear behind your target for a devastating strike.", "ability": "assassinate"},
		{"id": "sh_sinister", "col": 2, "tree": "shadow", "tier": 5, "max": 1, "name": "Sinister Strike", "desc": "Strike becomes Sinister Strike: two quick cuts, and it recovers faster."},
		# ---------------- Venom
		{"id": "ve_poison", "col": 0, "tree": "venom", "tier": 0, "max": 1, "name": "Poison Blade", "desc": "Learn Poison Blade: for 8s every hit poisons.", "ability": "poison"},
		{"id": "ve_potent", "col": 1, "tree": "venom", "tier": 0, "max": 3, "name": "Potent Toxins", "desc": "+20% poison damage per rank."},
		{"id": "ve_agile", "col": 2, "tree": "venom", "tier": 0, "max": 3, "name": "Light Step", "desc": "+3% movement speed per rank."},
		{"id": "ve_resil", "col": 3, "tree": "venom", "tier": 0, "max": 2, "name": "Resilience", "desc": "+4% maximum health per rank."},
		{"id": "ve_lasting", "col": 0, "tree": "venom", "tier": 1, "max": 2, "name": "Lingering Venom", "desc": "Poison lasts 2s longer per rank."},
		{"id": "ve_veil", "col": 1, "tree": "venom", "tier": 1, "max": 1, "name": "Toxic Veil", "desc": "Hits from stealth poison the target, no Poison Blade needed."},
		{"id": "ve_keen", "col": 2, "tree": "venom", "tier": 1, "max": 3, "name": "Vital Strikes", "desc": "+3% critical strike chance per rank."},
		{"id": "ve_quick", "col": 3, "tree": "venom", "tier": 1, "max": 2, "name": "Fast Hands", "desc": "Attack 6% faster per rank."},
		{"id": "ve_fan", "col": 0, "req": "ve_poison", "tree": "venom", "tier": 2, "max": 1, "name": "Phantom Knives", "desc": "Learn Phantom Knives. With Poison Blade up, every knife poisons.", "ability": "fan"},
		{"id": "ve_fester", "col": 1, "req": "ve_veil", "tree": "venom", "tier": 2, "max": 2, "name": "Festering Wounds", "desc": "Poisoned enemies take 8% more damage from you per rank."},
		{"id": "ve_flow", "col": 2, "tree": "venom", "tier": 2, "max": 3, "name": "Steady Hands", "desc": "+10% Energy regeneration per rank."},
		{"id": "ve_dodge", "col": 3, "tree": "venom", "tier": 2, "max": 3, "name": "Slippery", "desc": "+3% chance to dodge an attack per rank."},
		{"id": "ve_cripple", "col": 0, "req": "ve_lasting", "tree": "venom", "tier": 3, "max": 1, "name": "Crippling Toxin", "desc": "Poisoned enemies are slowed."},
		{"id": "ve_deadly", "col": 1, "req": "ve_fester", "tree": "venom", "tier": 3, "max": 2, "name": "Deadly Dose", "desc": "+25% poison damage per rank."},
		{"id": "ve_feast", "col": 2, "tree": "venom", "tier": 3, "max": 2, "name": "Feast", "desc": "Heal 3% of your health per rank on a kill."},
		{"id": "ve_thick", "col": 3, "tree": "venom", "tier": 3, "max": 2, "name": "Toughened Hide", "desc": "+10% armor per rank."},
		{"id": "ve_contagion", "col": 0, "tree": "venom", "tier": 4, "max": 1, "name": "Contagion", "desc": "When a poisoned enemy dies, its poison spreads to nearby foes."},
		{"id": "ve_dose", "col": 1, "tree": "venom", "tier": 4, "max": 2, "name": "Double Dose", "desc": "Poison Blade lasts 4s longer per rank."},
		{"id": "ve_sharp", "col": 2, "tree": "venom", "tier": 4, "max": 2, "name": "Honed Edge", "desc": "+5% damage per rank."},
		{"id": "ve_marked", "col": 3, "tree": "venom", "tier": 4, "max": 2, "name": "Pestilence", "desc": "+10% damage per rank to elites and bosses."},
		{"id": "ve_burst", "col": 1, "tree": "venom", "tier": 5, "max": 1, "name": "Venom Burst", "desc": "Learn Venom Burst: detonate every poison nearby.", "ability": "venomburst"},
	],
}


## Some abilities change shape when a deep talent is learned: {talent, over: fields to replace}.
const MORPHS := {
	"strike": [
		{"talent": "bw_heroic", "over": {"name": "Heroic Strike", "ab": "HS", "hue": "d8803a", "desc": "A mighty overhead blow that hits much harder and heals you for 6% of your health."}},
		{"talent": "sh_sinister", "over": {"name": "Sinister Strike", "ab": "SK", "hue": "a02a3a", "cd": 1.2, "desc": "Two quick cuts in a row. Recovers faster than Strike."}},
		{"talent": "sh_backstab", "over": {"name": "Backstab", "ab": "BK", "hue": "a02a3a", "cost": 35, "cd": 1.0, "desc": "A precise blow at close range for huge damage."}},
	],
}


static func talent_owner(id: String) -> String:
	for cls: String in TALENTS:
		for n: Dictionary in TALENTS[cls]:
			if n["id"] == id:
				return cls
	return ""


static func talent_node(id: String) -> Dictionary:
	for cls: String in TALENTS:
		for n: Dictionary in TALENTS[cls]:
			if n["id"] == id:
				return n
	return {}

const ABILITY_KEYS := ["1", "2", "3", "4", "5", "6"]

# ---------------------------------------------------------------- story
const BOSSES := [
	{"name": "The Hornstag", "biome": 0, "dir": "east", "sigil": "Verdant Sigil", "trophy": "Hornstag Antler", "color": "e0d070", "rec": 3,
	 "rune": "The stone reads: 'The Hornstag keeps the meadow's edge. Lay three Verdant Sigils on the antler altar and it will come to you.' The Mosslets carry the sigils.",
	 "win": "The Hornstag kneels and goes still. Its antler hums with a little of the old warmth. Carry it home to the shrine.",
	 "placed": "One light rekindled. Somewhere the Thornwood grows thick, and the Rootfather sleeps at its heart. The wolves there are hungrier than the Mosslets."},
	{"name": "The Rootfather", "biome": 1, "dir": "south", "sigil": "Rootbound Sigil", "trophy": "Heartwood Knot", "color": "7ad08a", "rec": 7,
	 "rune": "Bark has grown over the runes: 'The Rootfather drank the forest's light until he could not stop. Three Rootbound Sigils wake him.' Wolves and Bone Archers carry them.",
	 "win": "The Rootfather crumbles into loam. A knot of heartwood, still warm, is left in the soil.",
	 "placed": "Two lights burn. The Mire is out there. Bogmaw guarded its dead, then grew hungry for the living. Bring potions. Lots of them."},
	{"name": "Bogmaw", "biome": 2, "dir": "west", "sigil": "Mire Sigil", "trophy": "Bogmaw Fang", "color": "b08ae0", "rec": 11,
	 "rune": "Slime coats the stone: 'Bogmaw swallows what the Mire buries. Three Mire Sigils will bring it up from the deep.' Lurkers and Shamans hoard them.",
	 "win": "Bogmaw sinks back into the black water. One fang, long as your arm, washes up on the bank.",
	 "placed": "Three lights. Only the peaks remain. The Frost Wyrm was the first Warden and the proudest. It will not go quietly."},
	{"name": "The Frost Wyrm", "biome": 3, "dir": "north", "sigil": "Rime Sigil", "trophy": "Wyrm Heart", "color": "9fe0ff", "rec": 15,
	 "rune": "Frost has etched the runes deeper: 'The Wyrm watched over all of Thornvale from the peaks. Three Rime Sigils call it down.' The Cultists keep them close.",
	 "win": "The Frost Wyrm falls, and the ice on the peaks begins to drip. Its heart is still beating, slowly. Take it home.",
	 "placed": ""},
]

func intro_lines(class_name_text: String) -> Array:
	return [
		["THE WISP", "You stir at last, %s. Good. The Hearth Shrine has not had a keeper in a hundred winters." % class_name_text],
		["THE WISP", "Thornvale was kept by four Wardens. When the Ember in this shrine went dim, they forgot their oaths and turned on the land they guarded."],
		["THE WISP", "Put them to rest. Bring back what they leave behind, and the Ember will burn again."],
		["THE WISP", "But first, find your feet. This is Hearthmoor, the last village that still keeps the old ways. Elder Rowan waits in the square. Look for the gold \"!\""],
	]


# ---------------------------------------------------------------- combat tuning
## Basic attack per class. range/arc for melee (metres / radians); speed for shots (m/s).
const CLASS_COMBAT := {
	"warrior": {"dmg": 16.0, "cd": 0.45, "attack": "melee", "range": 2.3, "arc": 2.2, "crit": 0.0, "knock": 6.0},
		"mage": {"dmg": 15.0, "cd": 0.5, "attack": "bolt", "speed": 13.0, "life": 0.9, "crit": 0.0},
	"hunter": {"dmg": 13.0, "cd": 0.4, "attack": "arrow", "speed": 18.0, "life": 0.8, "crit": 0.0},
}

## Base armor per class: [at level 1, gained per level]
const BASE_ARMOR := {"warrior": [6.0, 2.0], "rogue": [3.0, 1.0], "mage": [2.0, 0.5], "hunter": [4.0, 1.5]}

const ENEMIES := {
	"mosslet": {"name": "Mosslet", "sprite": "slime", "pal": {"g": "7bbf5a", "G": "c8f08a"}, "hp": 18, "dmg": 5, "speed": 2.3, "xp": 8, "radius": 0.55},
	"wolf": {"name": "Grey Wolf", "sprite": "wolf", "pal": {"g": "7d7a86", "G": "a9a6b2", "e": "f2c14a"}, "hp": 40, "dmg": 9, "speed": 4.6, "xp": 28, "radius": 0.6},
	"archer": {"name": "Bone Archer", "sprite": "skel", "pal": {"g": "e4dcc4", "a": "4a3b2a"}, "hp": 30, "dmg": 8, "speed": 2.4, "xp": 30, "radius": 0.5,
		"ranged": {"speed": 9.0, "cd": 1.9, "color": "e4dcc4", "kind": "arrow"}},
	"lurker": {"name": "Bog Lurker", "sprite": "slime", "pal": {"g": "6a4f86", "G": "9b7cc0"}, "hp": 95, "dmg": 15, "speed": 2.3, "xp": 70, "radius": 0.6},
	"shaman": {"name": "Mire Shaman", "sprite": "skel", "pal": {"g": "a7c08a", "a": "3d5a3a"}, "hp": 65, "dmg": 14, "speed": 2.3, "xp": 75, "radius": 0.5,
		"ranged": {"speed": 7.5, "cd": 1.7, "color": "9be05a", "kind": "orb"}},
	"snowwolf": {"name": "Snow Wolf", "sprite": "wolf", "pal": {"g": "c8d4de", "G": "ffffff", "e": "2a7fd0"}, "hp": 130, "dmg": 20, "speed": 5.8, "xp": 150, "radius": 0.6},
	"cultist": {"name": "Rime Cultist", "sprite": "skel", "pal": {"g": "c9e3f2", "a": "2f4f7a"}, "hp": 105, "dmg": 20, "speed": 2.4, "xp": 160, "radius": 0.5,
		"ranged": {"speed": 9.0, "cd": 1.6, "color": "9fe0ff", "kind": "orb"}},
	# --- second wave of creatures, each with a special move (see "ai" in enemy.gd)
	"beetle": {"name": "Thornbeetle", "sprite": "beetle", "pal": {}, "hp": 26, "dmg": 7, "speed": 2.6, "xp": 12, "radius": 0.6, "ai": "charger"},
	"puffcap": {"name": "Puffcap", "sprite": "puffcap", "pal": {}, "hp": 14, "dmg": 16, "speed": 2.1, "xp": 10, "radius": 0.5, "ai": "bomber"},
	"sapling": {"name": "Treant Sapling", "sprite": "sapling", "pal": {}, "hp": 75, "dmg": 14, "speed": 1.9, "xp": 36, "radius": 0.65, "ai": "slammer"},
	"spider": {"name": "Thicket Spider", "sprite": "spider", "pal": {}, "hp": 34, "dmg": 11, "speed": 4.2, "xp": 30, "radius": 0.6, "ai": "pouncer"},
	"leech": {"name": "Bog Leech", "sprite": "leech", "pal": {}, "hp": 72, "dmg": 16, "speed": 3.6, "xp": 66, "radius": 0.6, "ai": "burrower"},
	"crone": {"name": "Bog Crone", "sprite": "crone", "pal": {}, "hp": 62, "dmg": 12, "speed": 2.2, "xp": 82, "radius": 0.5, "ai": "healer",
		"ranged": {"speed": 7.5, "cd": 2.0, "color": "70ff90", "kind": "orb"}},
	"golem": {"name": "Ice Golem", "sprite": "golem", "pal": {}, "hp": 260, "dmg": 30, "speed": 1.9, "xp": 220, "radius": 0.95, "ai": "slammer"},
	# --- Greyfold Downs
	"downhound": {"name": "Downs Hound", "sprite": "wolf", "pal": {"g": "a89c78", "G": "d8cfa8", "e": "e8ff8a"}, "hp": 150, "dmg": 22, "speed": 5.4, "xp": 140, "radius": 0.6, "ai": "pouncer"},
	"ridgecrawler": {"name": "Ridge Crawler", "sprite": "beetle", "pal": {"g": "8a7a58", "G": "b8a878"}, "hp": 120, "dmg": 20, "speed": 2.9, "xp": 120, "radius": 0.65, "ai": "charger"},
	"barrowwight": {"name": "Barrow Wight", "sprite": "skel", "pal": {"g": "c8c4a8", "a": "5a5a3a", "orb": "d8e070"}, "hp": 115, "dmg": 22, "speed": 2.4, "xp": 150, "radius": 0.5,
		"ranged": {"speed": 8.5, "cd": 1.7, "color": "d8e070", "kind": "orb"}},
	"cairnguard": {"name": "Cairn Guardian", "sprite": "golem", "pal": {"g": "8a9078", "G": "b8c0a0", "e": "e8e070"}, "hp": 240, "dmg": 28, "speed": 1.9, "xp": 210, "radius": 0.95, "ai": "slammer"},
	"frostwisp": {"name": "Frost Wisp", "sprite": "frostwisp", "pal": {}, "hp": 80, "dmg": 15, "speed": 3.2, "xp": 150, "radius": 0.5, "ai": "blinker",
		"ranged": {"speed": 10.0, "cd": 2.2, "color": "c8f0ff", "kind": "orb", "burst": 3}},
}

## Materials each enemy can drop: [material, chance]
const ENEMY_MATS := {
	"mosslet": [["mossgel", 0.5]], "beetle": [["mossgel", 0.3], ["copper", 0.25]], "puffcap": [["mossgel", 0.6]],
	"wolf": [["pelt", 0.5]], "archer": [["heartwood", 0.2], ["pelt", 0.15]], "sapling": [["heartwood", 0.6]], "spider": [["pelt", 0.4]],
	"lurker": [["witchroot", 0.4]], "shaman": [["witchroot", 0.4]], "leech": [["witchroot", 0.5], ["bogiron", 0.15]], "crone": [["witchroot", 0.6]],
	"snowwolf": [["rime", 0.3], ["pelt", 0.3]], "cultist": [["rime", 0.5]], "golem": [["frost", 0.6]], "frostwisp": [["rime", 0.5]],
	"downhound": [["pelt", 0.5], ["rime", 0.15]], "ridgecrawler": [["copper", 0.3], ["bogiron", 0.2]], "barrowwight": [["rime", 0.4]], "cairnguard": [["frost", 0.5], ["bogiron", 0.3]],
}
## What roams Greyfold Downs (the zone uses these instead of the peaks list).
const GREYFOLD_SPAWN := ["downhound", "downhound", "ridgecrawler", "barrowwight", "cairnguard"]
## Which enemies appear in each biome (index matches BIOME_NAMES).
const SPAWN_TABLE := [
	["mosslet", "mosslet", "mosslet", "beetle", "beetle", "puffcap"],
	["wolf", "wolf", "archer", "sapling", "spider", "spider"],
	["lurker", "shaman", "leech", "leech", "crone"],
	["snowwolf", "cultist", "golem", "frostwisp", "frostwisp"],
	["mosslet"],
]

## Boss combat stats, same order as BOSSES.
const BOSS_COMBAT := [
	{"sprite": "hornstag", "scale": 2.4, "pal": {"g": "9a6b3f", "G": "c99a5e", "e": "ffe27a", "w": "f0e2b0"}, "hp": 280, "dmg": 12, "speed": 3.6, "xp": 200, "radius": 1.2,
	 "minion": "mosslet", "patterns": ["charge", "ring", "charge", "spray"]},
	{"sprite": "rootfather", "scale": 3.0, "pal": {"g": "8a6a40", "a": "2f5a34", "l": "4a8a3a"}, "hp": 700, "dmg": 18, "speed": 2.6, "xp": 800, "radius": 1.2,
	 "minion": "wolf", "patterns": ["ring", "summon", "spray", "ring", "spray"]},
	{"sprite": "bogmaw", "scale": 3.6, "pal": {"g": "4e6b3a", "G": "8fb060", "w": "d8d0b0"}, "hp": 1400, "dmg": 24, "speed": 2.3, "xp": 2000, "radius": 1.5,
	 "minion": "lurker", "patterns": ["spray", "ring", "summon", "spiral"]},
	{"sprite": "wyrm", "scale": 3.6, "pal": {"g": "9cc4dc", "G": "e8f6ff", "e": "2a7fd0", "w": "e8f6ff"}, "hp": 2600, "dmg": 30, "speed": 3.9, "xp": 4000, "radius": 1.5,
	 "minion": "snowwolf", "patterns": ["spiral", "charge", "ring", "spray", "charge"]},
]

const ENDING := [
	"The four lights join. The Ember roars up out of the shrine, and for the first time in a hundred winters, Thornvale is warm.",
	"You did what the Wardens could not. The land is yours to wander now, keeper.",
	"That's the end of this first chapter. Thanks for playing!",
]

## Creature sprite maps: k=outline, g=body, G=highlight, e=eyes, a=cloth, w=horn/teeth, l=leaves.
const SPRITES := {
	"slime": [
		["............", "....kkkk....", "...kggggk...", "..kgGggggk..", ".kggggggggk.", ".kgkggggkgk.", ".kggggggggk.", "..kkkkkkkk.."],
		["............", "............", "....kkkk....", "..kkGgggkk..", ".kggggggggk.", ".kgkggggkgk.", ".kggggggggk.", "kkkkkkkkkkkk"],
	],
	"wolf": [
		["..........k.k.", ".........kgkgk", ".kkkkkkkkggegk", "kggggggggggggk", "kgGGGGGGggggkk", ".kggggggggggk.", ".kgk..kgk.kgk.", ".kk...kk..kk.."],
		["..........k.k.", ".........kgkgk", ".kkkkkkkkggegk", "kggggggggggggk", "kgGGGGGGggggkk", ".kggggggggggk.", "..kgk.kgk..kgk", "..kk..kk...kk."],
	],
	"skel": [
		["...kkkk...", "..kggggk..", "..kgkkgk..", "..kggggk..", "...kggk...", ".kkaaaakk.", "kg.kaak.gk", "kg.kaak.gk", "...kaak...", "..kg..gk..", "..kg..gk..", "..kk..kk.."],
		["...kkkk...", "..kggggk..", "..kgkkgk..", "..kggggk..", "...kggk...", ".kkaaaakk.", "kg.kaak.gk", "kg.kaak.gk", "...kaak...", ".kg....gk.", ".kg....gk.", ".kk....kk."],
	],
	"hornstag": [
		["........w...w.", "........w.w.w.", ".........ww.w.", "..........ww..", "..........k.k.", ".........kgkgk", ".kkkkkkkkggegk", "kggggggggggggk", "kgGGGGGGggggkk", ".kggggggggggk.", ".kgk..kgk.kgk.", ".kk...kk..kk.."],
		["........w...w.", "........w.w.w.", ".........ww.w.", "..........ww..", "..........k.k.", ".........kgkgk", ".kkkkkkkkggegk", "kggggggggggggk", "kgGGGGGGggggkk", ".kggggggggggk.", "..kgk.kgk..kgk", "..kk..kk...kk."],
	],
	"rootfather": [
		["..l.l..l..", ".llllllll.", "...kkkk...", "..kggggk..", "..kgkkgk..", "..kggggk..", "...kggk...", ".kkaaaakk.", "kg.kaak.gk", "kg.kaak.gk", "...kaak...", "..kg..gk..", "..kg..gk..", "..kk..kk.."],
		["l..l.l..l.", ".llllllll.", "...kkkk...", "..kggggk..", "..kgkkgk..", "..kggggk..", "...kggk...", ".kkaaaakk.", "kg.kaak.gk", "kg.kaak.gk", "...kaak...", ".kg....gk.", ".kg....gk.", ".kk....kk."],
	],
	"bogmaw": [
		["............", "....kkkk....", "...kggggk...", "..kgGggggk..", ".kggggggggk.", ".kgkggggkgk.", ".kgwgwgwgwk.", "..kkkkkkkk.."],
		["............", "............", "....kkkk....", "..kkGgggkk..", ".kggggggggk.", ".kgkggggkgk.", ".kgwgwgwgwk.", "kkkkkkkkkkkk"],
	],
	"wyrm": [
		["..w.w.w.w.k.k.", ".kwkwkwkwkgkgk", ".kkkkkkkkggegk", "kggggggggggggk", "kgGGGGGGggggkk", ".kggggggggggk.", ".kgk..kgk.kgk.", ".kk...kk..kk.."],
		["..w.w.w.w.k.k.", ".kwkwkwkwkgkgk", ".kkkkkkkkggegk", "kggggggggggggk", "kgGGGGGGggggkk", ".kggggggggggk.", "..kgk.kgk..kgk", "..kk..kk...kk."],
	],
}


func creature_frames(sprite: String, pal: Dictionary) -> Array[ImageTexture]:
	if SPRITES.has(sprite):
		var maps: Array = SPRITES[sprite]
		return [make_sprite(maps[0], pal), make_sprite(maps[1], pal)]
	# newer creatures are drawn in tools/make_sprites.py
	var d: Dictionary = SpriteArt.SPRITES[sprite]
	var full: Dictionary = (d["pal"] as Dictionary).duplicate()
	full.merge(pal, true)
	return [make_sprite(d["a"], full), make_sprite(d["b"], full)]


# ---------------------------------------------------------------- merchant
const SHOP_SLOTS := 6
const MERCHANT_NAME := "Bramble"
const APOTHECARY_NAME := "Sorrel"
const MERCHANT_LINES := [
	"Bramble's the name. Steel, cloth, and potions that mostly work. Have a look.",
	"Back again? I keep the good stuff for keepers who come back.",
	"Gold's gold, friend. Even the Wardens can't argue with that.",
]

## Gold an item sells for. Buying from Bramble costs four times this.
static func sell_price(item: Dictionary) -> int:
	return roundi((5.0 + float(item["ilvl"]) * 2.0) * [1, 2, 4, 8, 16][int(item["rarity"])] * (1.0 + 0.25 * int(item.get("upg", 0))))


static func potion_price(lvl: int) -> int:
	return 20 + lvl * 4


static func restock_price(lvl: int) -> int:
	return 25 + lvl * 10


# ---------------------------------------------------------------- crafting
const MATERIALS := {
	"copper": {"name": "Copper Ore", "color": "c87a3a", "tier": 0},
	"mossgel": {"name": "Mossgel", "color": "7bbf5a", "tier": 0},
	"heartwood": {"name": "Heartwood", "color": "9a6a3a", "tier": 1},
	"pelt": {"name": "Wolf Pelt", "color": "8a8492", "tier": 1},
	"bogiron": {"name": "Bog Iron", "color": "6a7a68", "tier": 2},
	"witchroot": {"name": "Witchroot", "color": "8a6ab0", "tier": 2},
	"frost": {"name": "Frost Crystal", "color": "9fe0ff", "tier": 3},
	"rime": {"name": "Rime Essence", "color": "e8f6ff", "tier": 3},
	"ember": {"name": "Ember Shard", "color": "f2994a", "tier": -1},
	# --- skilling
	"oak": {"name": "Oak Logs", "color": "b08850", "tier": 0},
	"greenleaf": {"name": "Greenleaf", "color": "6ad050", "tier": 0},
	"thornbud": {"name": "Thornbud", "color": "d05a7a", "tier": 1},
	"marshroot": {"name": "Marshroot", "color": "a08ad0", "tier": 2},
	"frostbloom": {"name": "Frostbloom", "color": "a8e8ff", "tier": 3},
	"raw_minnow": {"name": "Raw Minnow", "color": "a8b8c8", "tier": 0},
	"raw_trout": {"name": "Raw Trout", "color": "c89a8a", "tier": 1},
	"raw_eel": {"name": "Raw Mud Eel", "color": "7a6a50", "tier": 2},
	"raw_icefin": {"name": "Raw Icefin", "color": "a8d8f0", "tier": 3},
	"minnow": {"name": "Cooked Minnow", "color": "d8a868", "tier": 0, "heal": 35},
	"trout": {"name": "Cooked Trout", "color": "e08a5a", "tier": 1, "heal": 80},
	"eel": {"name": "Cooked Eel", "color": "b8784a", "tier": 2, "heal": 140},
	"icefin": {"name": "Cooked Icefin", "color": "f0c890", "tier": 3, "heal": 230},
	"might": {"name": "Might Draught", "color": "e0503c", "tier": 1},
	"swift": {"name": "Swift Tonic", "color": "60d0a0", "tier": 2},
	"greater": {"name": "Greater Potion", "color": "ff6a8a", "tier": 3},
	# --- tools, bait and the things you make them from. kind: tool (never used up), bait, item
	"twig": {"name": "Twigs", "color": "9a7a4a", "tier": 0, "kind": "item", "desc": "Gathered from brush. Use a knife on them to whittle wooden tools and rods."},
	"wooden_pickaxe": {"name": "Wooden Pickaxe", "color": "a88a58", "tier": -2, "kind": "tool", "desc": "Mines copper. Upgrade to copper, bog iron and frost picks for harder ore."},
	"wooden_axe": {"name": "Wooden Axe", "color": "b89a68", "tier": -2, "kind": "tool", "desc": "Chops oak. Upgrade for tougher wood."},
	"wooden_knife": {"name": "Wooden Knife", "color": "c0a470", "tier": -2, "kind": "tool", "desc": "Cuts bait from creatures you kill and kindling from logs."},
	"pickaxe": {"name": "Copper Pickaxe", "color": "aab0ba", "tier": -2, "kind": "tool", "desc": "Mines copper and bog iron."},
	"axe": {"name": "Copper Axe", "color": "c8ccd4", "tier": -2, "kind": "tool", "desc": "Chops oak and heartwood."},
	"bogiron_pickaxe": {"name": "Bog Iron Pickaxe", "color": "7a7a70", "tier": -2, "kind": "tool", "desc": "Mines frost crystal and everything below."},
	"bogiron_axe": {"name": "Bog Iron Axe", "color": "8a8a80", "tier": -2, "kind": "tool", "desc": "A heavier axe for faster chopping."},
	"frost_pickaxe": {"name": "Frost Pickaxe", "color": "9fe0ff", "tier": -2, "kind": "tool", "desc": "The best pick. Mines fastest."},
	"frost_axe": {"name": "Frost Axe", "color": "b8e8ff", "tier": -2, "kind": "tool", "desc": "The best axe. Chops fastest."},
	"rod": {"name": "Fishing Rod", "color": "d0b070", "tier": -2, "kind": "tool", "desc": "Needed to fish. You also need bait."},
	"knife": {"name": "Copper Knife", "color": "d8dce4", "tier": -2, "kind": "tool", "desc": "Cuts bait and kindling. Yields extra bait."},
	"hammer": {"name": "Wooden Hammer", "color": "a88a58", "tier": -2, "kind": "tool", "desc": "Use it on a bar at an anvil to shape metal."},
	"flint_steel": {"name": "Flint and Steel", "color": "e8a050", "tier": -2, "kind": "tool", "desc": "Lights kindling to make a fire."},
	"vial": {"name": "Glass Vial", "color": "bfe8f0", "tier": 0, "kind": "item", "desc": "Every potion you brew uses one. Made at the furnace from Mossgel and logs."},
	"flint": {"name": "Flint", "color": "8a8a92", "tier": 0, "kind": "item", "desc": "Sparks. Chipped from rocks while mining. Used to make Flint and Steel."},
	"bait_0": {"name": "Grub Bait", "color": "b8d070", "tier": 0, "kind": "bait", "desc": "Fishing bait for meadow fish. Cut from Mosslets and Beetles with a knife."},
	"bait_1": {"name": "Spider Bait", "color": "9a7a5a", "tier": 1, "kind": "bait", "desc": "Fishing bait for Thornwood fish. Cut from Spiders and Wolves with a knife."},
	"bait_2": {"name": "Leech Bait", "color": "6a8a5a", "tier": 2, "kind": "bait", "desc": "Fishing bait for Mire fish. Cut from Leeches and Lurkers with a knife."},
	"bait_3": {"name": "Rime Bait", "color": "a8d0e8", "tier": 3, "kind": "bait", "desc": "Fishing bait for icy water. Cut from Snow Wolves with a knife."},
	"copper_bar": {"name": "Copper Bar", "color": "d8884a", "tier": 0, "kind": "item", "desc": "Smelted from Copper Ore at the furnace. Forged into tools at the anvil."},
	"bogiron_bar": {"name": "Bog Iron Bar", "color": "7a8a78", "tier": 2, "kind": "item", "desc": "Smelted from Bog Iron at the furnace."},
	"frost_bar": {"name": "Frost Bar", "color": "b0e8ff", "tier": 3, "kind": "item", "desc": "Smelted from Frost Crystal at the furnace."},
	"kindling_oak": {"name": "Oak Kindling", "color": "d8b070", "tier": 0, "kind": "item", "desc": "Right-click to light it (needs Flint and Steel and an Oak Log)."},
	"kindling_heart": {"name": "Heartwood Kindling", "color": "b88a4a", "tier": 1, "kind": "item", "desc": "Right-click to light it (needs Flint and Steel and a Heartwood log)."},
	"hpot": {"name": "Health Potion", "color": "e05a5a", "tier": 0, "kind": "potion", "desc": "Right-click to drink: heals 45%."},
}
const MAT_ORDER := ["wooden_pickaxe", "pickaxe", "bogiron_pickaxe", "frost_pickaxe", "wooden_axe", "axe", "bogiron_axe", "frost_axe", "rod", "wooden_knife", "knife", "hammer", "flint_steel", "twig", "hpot", "greater", "might", "swift",
	"minnow", "trout", "eel", "icefin", "vial", "bait_0", "bait_1", "bait_2", "bait_3",
	"copper_bar", "bogiron_bar", "frost_bar", "kindling_oak", "kindling_heart",
	"copper", "bogiron", "frost", "flint", "oak", "heartwood", "mossgel", "pelt", "witchroot", "rime", "ember",
	"greenleaf", "thornbud", "marshroot", "frostbloom", "raw_minnow", "raw_trout", "raw_eel", "raw_icefin"]
## Creatures that give fishing bait when you kill them with a knife in your bag, and which bait.
## Tool lines, weakest to best. Index = tool tier. Nodes name the tier they need.
const TOOL_LINES := {"pickaxe": ["wooden_pickaxe", "pickaxe", "bogiron_pickaxe", "frost_pickaxe"],
	"axe": ["wooden_axe", "axe", "bogiron_axe", "frost_axe"], "knife": ["wooden_knife", "knife"]}
const BAIT_MOBS := {"mosslet": "bait_0", "beetle": "bait_0", "spider": "bait_1", "wolf": "bait_1",
	"leech": "bait_2", "lurker": "bait_2", "snowwolf": "bait_3"}
## Firemaking: log -> kindling -> fire. lvl: Firemaking level; burn: seconds the fire lasts.
const FIRE_LOGS := {
	"oak": {"kindling": "kindling_oak", "lvl": 1, "kxp": 6, "xp": 24, "burn": 150.0},
	"heartwood": {"kindling": "kindling_heart", "lvl": 10, "kxp": 14, "xp": 55, "burn": 300.0},
}
## Crafting stations -> which skill they train and their window title.
const STATIONS := {
	"cooking": {"skill": "cooking", "title": "Campfire · Cooking"},
	"herblore": {"skill": "herblore", "title": "Herblore"},
	"crafting": {"skill": "crafting", "title": "Crafting"},
	"furnace": {"skill": "smithing", "title": "Furnace · Smelting"},
	"anvil": {"skill": "smithing", "title": "Anvil · Smithing"},
}
## Use one bag item on another: the tool here, on a target that appears in a recipe's cost. Anvil work needs the anvil.
const COMBO_TOOLS := {"crafting": ["wooden_knife", "knife"], "herblore": ["vial"], "anvil": ["hammer"]}
const STACK_MAX := 99   # materials stack this high in one bag slot
const FOOD_ORDER := ["icefin", "eel", "trout", "minnow"]   # eat the best first
## One crafting tier per region. primary comes from resource nodes, secondary from creatures.
const CRAFT_TIERS := [
	{"name": "Copper", "region": 0, "primary": "copper", "secondary": "mossgel", "ilvl": 4, "unlock": 1},
	{"name": "Heartwood", "region": 1, "primary": "heartwood", "secondary": "pelt", "ilvl": 7, "unlock": 4},
	{"name": "Bog Iron", "region": 2, "primary": "bogiron", "secondary": "witchroot", "ilvl": 11, "unlock": 8},
	{"name": "Frostforged", "region": 3, "primary": "frost", "secondary": "rime", "ilvl": 15, "unlock": 12},
]
## Resource nodes in the world: which region, what they give, how they look.
## skill/lvl: what you need to gather it; xp per haul; chance: how often a map cell gets one.
const NODES := {
	"twig": {"verb": "Gather", "biome": 0, "look": "brush", "skill": "woodcutting", "lvl": 1, "xp": 4, "chance": 0.05, "tool": ""},
	"copper": {"verb": "Mine", "biome": 0, "look": "ore", "skill": "mining", "lvl": 1, "xp": 22, "chance": 0.03, "tool": "pickaxe", "tt": 0},
	"oak": {"verb": "Chop", "biome": 0, "look": "tree", "skill": "woodcutting", "lvl": 1, "xp": 22, "chance": 0.022, "tool": "axe", "tt": 0},
	"greenleaf": {"verb": "Pick", "biome": 0, "look": "herb", "skill": "herblore", "lvl": 1, "xp": 14, "chance": 0.02},
	"heartwood": {"verb": "Chop", "biome": 1, "look": "log", "skill": "woodcutting", "lvl": 8, "xp": 42, "chance": 0.012, "tool": "axe", "tt": 1},
	"thornbud": {"verb": "Pick", "biome": 1, "look": "herb", "skill": "herblore", "lvl": 8, "xp": 28, "chance": 0.006},
	"bogiron": {"verb": "Mine", "biome": 2, "look": "ore", "skill": "mining", "lvl": 12, "xp": 60, "chance": 0.0045, "tool": "pickaxe", "tt": 1},
	"marshroot": {"verb": "Pick", "biome": 2, "look": "herb", "skill": "herblore", "lvl": 16, "xp": 45, "chance": 0.004},
	"frost": {"verb": "Mine", "biome": 3, "look": "crystal", "skill": "mining", "lvl": 22, "xp": 85, "chance": 0.004, "tool": "pickaxe", "tt": 2},
	"frostbloom": {"verb": "Pick", "biome": 3, "look": "herb", "skill": "herblore", "lvl": 24, "xp": 65, "chance": 0.003},
}
const SMITH_NAME := "Hilde"
## Smithing (or Crafting, for rings and amulets) level needed to work each forge tier.
const TIER_SKILL_LVL := [1, 8, 16, 24]
const UPGRADE_MAX := 5


static func craft_cost(tier: int, slot: String, masterwork: bool) -> Dictionary:
	var t: Dictionary = CRAFT_TIERS[tier]
	var w := slot == "weapon"
	var cost := {t["primary"]: 3 + tier + (2 if w else 0), t["secondary"]: 2 + tier + (1 if w else 0)}
	if masterwork:
		cost["ember"] = 1
	cost["gold"] = roundi(30.0 * pow(tier + 1, 1.5))
	return cost


## The rule: METAL is hammered from bars at an anvil (plate, mail, swords, daggers, rings, amulets, metal tools).
## Everything else is cut with a knife in the bag: leather and cloth armor, staves and bows, wooden tools.
static func gear_station(cls: String, slot: String) -> String:
	if slot in ["ring", "amulet"]:
		return "anvil"
	if slot == "weapon":
		return "crafting" if Items.WEAPON_FOR[cls] in ["staff", "bow"] else "anvil"
	return "anvil" if Items.ARMOR_FOR[cls] in ["plate", "mail"] else "crafting"


const HERB_TIER := ["greenleaf", "thornbud", "marshroot", "frostbloom"]


static func gear_cost(tier: int, slot: String, masterwork: bool, cls := "warrior") -> Dictionary:
	var c := craft_cost(tier, slot, masterwork)
	var t: Dictionary = CRAFT_TIERS[tier]
	if gear_station(cls, slot) == "anvil":
		var prim: String = t["primary"]
		var bars := {"copper": "copper_bar", "bogiron": "bogiron_bar", "frost": "frost_bar"}
		if bars.has(prim):
			c[bars[prim]] = c[prim]
			c.erase(prim)
		else:
			c["copper_bar"] = 2 + (1 if slot == "weapon" else 0)   # heartwood gear: copper fittings on heartwood
		return c
	# soft gear: parts from animals and plants
	var out := {}
	var sec: String = t["secondary"]
	var herb: String = HERB_TIER[tier]
	if slot == "weapon":
		out[("oak" if tier == 0 else "heartwood")] = 3 + tier
		out[sec] = 2 + tier
	elif Items.ARMOR_FOR[cls] == "leather":
		out[sec] = 3 + tier
		out[herb] = 2
	else:
		out[herb] = 3 + tier
		out[sec] = 2
	if masterwork:
		out["ember"] = 1
	out["gold"] = c["gold"]
	return out


static var _gear_cache := {}


## Every piece of gear you can make for a class, as recipes for the anvil or the knife (masterwork needs an Ember Shard).
static func gear_recipes(cls: String) -> Array:
	if _gear_cache.has(cls):
		return _gear_cache[cls]
	var out: Array = []
	for master in [false, true]:
		for ti in CRAFT_TIERS.size():
			for slot: String in Items.SLOTS:
				if slot == "cloak":
					continue   # cloaks are found, not forged (yet)
				var t: Dictionary = CRAFT_TIERS[ti]
				var ty: String = Items.WEAPON_FOR[cls] if slot == "weapon" else slot
				var armor: String = Items.ARMOR_FOR[cls] if ty in Items.ARMOR_SLOTS else ""
				var base: String = Items.base_names(ty, armor)[0]
				var st := gear_station(cls, slot)
				out.append({"out": "gear", "gear": {"tier": ti, "slot": slot, "master": master}, "station": st,
					"name": "%s %s %s" % ["Masterwork" if master else "Forged", t["name"], base],
					"lvl": TIER_SKILL_LVL[ti], "skill": ("crafting" if (st == "crafting" or slot in ["ring", "amulet"]) else "smithing"),
					"xp": roundi(55.0 * (ti + 1) * (1.6 if master else 1.0)),
					"cost": gear_cost(ti, slot, master, cls), "master": master,
					"desc": "%s · Item level %d · stats favor your class" % ["Epic" if master else "Rare", t["ilvl"]],
					"icon_item": {"type": ty, "mat": Items.TIER_MATERIAL[ti][1], "rarity": 3 if master else 2, "armor": armor}})
	_gear_cache[cls] = out
	return out


static func item_tier(item: Dictionary) -> int:
	return clampi(int((int(item["ilvl"]) - 1) / 4.0), 0, 3)


static func upgrade_cost(item: Dictionary) -> Dictionary:
	var t: Dictionary = CRAFT_TIERS[item_tier(item)]
	var nxt := int(item.get("upg", 0)) + 1
	var cost := {t["primary"]: 1 + nxt, t["secondary"]: nxt, "gold": 15 * nxt * (item_tier(item) + 1)}
	if nxt >= UPGRADE_MAX:
		cost["ember"] = 1
	return cost


## What salvaging gives back: [material, amount] pairs plus an Ember Shard chance.
static func salvage_yield(item: Dictionary) -> Dictionary:
	var t: Dictionary = CRAFT_TIERS[item_tier(item)]
	var r := int(item["rarity"])
	var y := {t["primary"]: 1 + r / 2}
	if r >= 1:
		y[t["secondary"]] = 1 + (1 if r >= 3 else 0)
	var ember_chance: float = [0.0, 0.0, 0.3, 1.0, 1.0][r]
	var ember := 2 if r == 4 else 1
	return {"mats": y, "ember_chance": ember_chance, "ember": ember}


# ---------------------------------------------------------------- side quests
## One quest giver per region, each with two quests in a row.
## goal: "kill" (enemy type), "gather" (glowing plants spawned near the giver), "elite" (a named enemy at a lair).
## goal: "kill" (enemy type), "gather" (glowing plants), "elite" (a named enemy), "talk" (target: smith, merchant,
## varka, wisp, or a quest giver id), "obtain" (pick up / gather / make a material), "craft" (anything at the forge).
## "town": [x, z] puts the giver in Hearthmoor's square (metres from the shrine) instead of out in the wilds.
const SIDE_QUESTS := [
	{
		"id": "tam",
		"name": "Old Tam",
		"sprite": "tam",
		"biome": 0,
		"ang": 0.0,
		"dist": 0,
		"town": [
			0.0,
			0.0
		],
		"still": true,
		"tutorial": true,
		"greet": "Hello, wanderer! I'm Tam. Stick around and I'll teach you the basics.",
		"thanks": "Safe travels. My fire's always lit.",
		"quests": [
			{
				"title": "Gather Twigs",
				"goal": "obtain",
				"target": "twig",
				"label": "Twigs",
				"count": 12,
				"xp": 30,
				"gold": 5,
				"reward_mats": {
					"twig": 12
				},
				"give": {
					"wooden_knife": 1
				},
				"tip": "Click the small bushes (brush) around camp to pick twigs. You need 12. A hand icon shows over things you can click.",
				"intro": "Take my old knife. I need a Wooden Axe and a Fishing Rod made. First, click the brush around camp to gather 12 twigs, then open your bag (I) and use the knife on them.",
				"nag": "Brush is all around camp.",
				"done": "Good. Here are 12 more from my stash.",
				"quest": "Make a Fishing Rod and an Axe",
				"auto": true
			},
			{
				"title": "Wooden Tools",
				"goal": "obtain",
				"target": "wooden_axe|rod",
				"label": "Tools made",
				"count": 2,
				"xp": 45,
				"gold": 5,
				"head": "Craft",
				"checks": [
					{
						"label": "Wooden Axe",
						"item": "wooden_axe"
					},
					{
						"label": "Fishing Rod",
						"item": "rod"
					}
				],
				"tip": "Open your bag (I). Click the knife, then click your twigs, and choose Wooden Axe. Do it again and choose Fishing Rod.",
				"intro": "Open your bag (I), click the knife, then click your twigs. Make a Wooden Axe and a Fishing Rod.",
				"nag": "Bag (I): click the knife, then the twigs. Make an axe and a rod.",
				"done": "Good tools. Take these rags, they'll keep the wind off. Next, wood.",
				"quest": "Make a Fishing Rod and an Axe",
				"reward_items": [
					{
						"name": "Ragged Tunic",
						"slot": "chest"
					},
					{
						"name": "Ragged Trousers",
						"slot": "legs"
					}
				]
			},
			{
				"title": "Chop a Log",
				"goal": "obtain",
				"target": "oak",
				"label": "Oak Logs",
				"count": 2,
				"xp": 45,
				"gold": 5,
				"tip": "Click an oak tree and stand still while you chop (you need the axe you made). Gather 2 oak logs.",
				"intro": "Click an oak and stand still. Bring me 2 logs.",
				"nag": "Oaks are past the brush.",
				"done": "Nice logs.",
				"quest": "Cook a Meal",
				"auto": true
			},
			{
				"title": "Light a Fire",
				"goal": "fire",
				"target": "lit",
				"label": "Fires lit",
				"count": 1,
				"xp": 60,
				"gold": 5,
				"give": {
					"flint_steel": 1
				},
				"tip": "Open your bag (I). Left-click your Flint and Steel, then click a log. A fire lights where you stand. (Right-click a log and choose Light fire works too.)",
				"intro": "Take my flint and steel. Open your bag (I), left-click the flint and steel, then click a log.",
				"nag": "Click the flint and steel, then a log.",
				"done": "Warm already.",
				"quest": "Cook a Meal",
				"auto": true
			},
			{
				"title": "Catch Supper",
				"goal": "obtain",
				"target": "raw_minnow",
				"label": "Raw Minnows",
				"count": 2,
				"xp": 60,
				"gold": 5,
				"give": {
					"bait_0": 8
				},
				"tip": "Walk to the pond and click the ripples in the water, then stand still. Catch 2 raw minnows (your rod and the bait you were given do the work).",
				"intro": "Click the ripples in the pond to fish. Here's bait. Catch 2 minnows.",
				"nag": "Stand still by the pond.",
				"done": "Fine minnows.",
				"quest": "Cook a Meal",
				"auto": true
			},
			{
				"title": "Cook It",
				"goal": "obtain",
				"target": "minnow",
				"label": "Cooked Minnows",
				"count": 2,
				"xp": 70,
				"gold": 10,
				"tip": "Click your fire and choose Cooked Minnow. Some may burn, keep trying. Bring 2 cooked minnows to Tam.",
				"intro": "Click a fire and cook 2 minnows. Some may burn, keep trying.",
				"nag": "Click a fire, pick Cooked Minnow.",
				"done": "Smells great.",
				"quest": "Cook a Meal"
			},
			{
				"title": "Set Your Abilities",
				"goal": "bar",
				"target": "any",
				"label": "Abilities on bar",
				"count": 1,
				"xp": 0,
				"gold": 5,
				"pulse": "abilities",
				"tip": "Press N and click an ability to put it on your bar.",
				"intro": "Press N to open Abilities. Click an ability to put it on your bar.",
				"nag": "Press N, then click abilities.",
				"done": "Now they're one key press away (1-6).",
				"quest": "Ready for a Fight",
				"auto": true
			},
			{
				"title": "Try Them Out",
				"goal": "kill",
				"target": "mosslet",
				"label": "Mosslets",
				"count": 1,
				"xp": 40,
				"gold": 5,
				"spawn": true,
				"end_safe": true,
				"tip": "Hit the Mosslet with your abilities (keys 1-6). Right-click it to auto-attack.",
				"intro": "A Mosslet wandered into camp. Use your abilities on it with keys 1-6. Right-click it to auto-attack.",
				"nag": "The Mosslet's near camp. Use keys 1-6.",
				"done": "Nice. There is a rack by my tent with a bow and a staff, take them if you like. The wilds are open, so stay sharp.",
				"quest": "Ready for a Fight"
			},
			{
				"title": "The Road to Hearthmoor",
				"goal": "talk",
				"target": "king",
				"label": "Meet the King",
				"count": 1,
				"xp": 0,
				"gold": 60,
				"auto": true,
				"reward_rarity": 1,
				"tip": "Follow the road north. Speak to the King.",
				"intro": "Follow the road north to Hearthmoor and speak to the King. Tell him Tam sent you.",
				"nag": "North along the road.",
				"done": ""
			}
		]
	},
	{
		"id": "king",
		"name": "King Aldren",
		"sprite": "king",
		"biome": 0,
		"ang": 0.0,
		"dist": 0,
		"town": [
			0.0,
			0.0
		],
		"still": true,
		"greet": "So Tam sent another wanderer. Welcome to Hearthmoor.",
		"thanks": "Rowan will see you right. Go well, keeper of the Ember.",
		"quests": [
			{
				"title": "The King's Charge",
				"goal": "talk",
				"target": "rowan",
				"label": "Find Elder Rowan",
				"count": 1,
				"xp": 80,
				"gold": 30,
				"auto": true,
				"tip": "Find Elder Rowan in the square.",
				"intro": "The Ember is dying and the four Wardens have turned. Find Elder Rowan in the square. He'll prepare you.",
				"nag": "Elder Rowan is in the square.",
				"done": ""
			}
		]
	},
	{
		"id": "rowan",
		"name": "Elder Rowan",
		"sprite": "elder",
		"biome": 0,
		"ang": 0.0,
		"dist": 0,
		"town": [
			-3.0,
			-10.5
		],
		"greet": "Ah, the new keeper. Welcome to Hearthmoor.",
		"thanks": "You've grown into the work, keeper. Hearthmoor is proud of you.",
		"quests": [
			{
				"title": "Meet the Smith",
				"goal": "talk",
				"target": "smith",
				"label": "Visit Hilde's forge",
				"count": 1,
				"xp": 25,
				"gold": 10,
				"intro": "Visit Hilde at her smithy, the open-sided shed with the stone forge.",
				"nag": "Look for the smithy with the glowing forge.",
				"done": "Hilde doesn't like anyone. You're doing well.",
				"quest": "Learn the Forge",
				"auto": true,
				"tip": "Walk to the smithy (the open shed with the glowing forge) and speak to Hilde."
			},
			{
				"title": "A Wooden Pick",
				"goal": "obtain",
				"target": "wooden_pickaxe",
				"label": "Make a Wooden Pickaxe",
				"count": 1,
				"xp": 50,
				"gold": 10,
				"intro": "Use your knife on 6 twigs to make a Wooden Pickaxe.",
				"nag": "Click the knife, then the twigs.",
				"done": "Crude, but it'll crack copper.",
				"quest": "Learn the Forge",
				"auto": true,
				"tip": "Bag (I): click the knife, then 6 twigs, and choose Wooden Pickaxe."
			},
			{
				"title": "Ore for the Furnace",
				"goal": "obtain",
				"target": "copper",
				"label": "Copper Ore",
				"count": 5,
				"xp": 60,
				"gold": 15,
				"intro": "Mine 5 copper ore from the rocks past the gate.",
				"nag": "Orange-flecked rocks, past the gate.",
				"done": "Honest ore.",
				"quest": "Learn the Forge",
				"auto": true,
				"tip": "Click the orange-flecked rocks past the gate to mine copper (needs the pickaxe)."
			},
			{
				"title": "Smelt and Strike",
				"goal": "obtain",
				"target": "copper_bar",
				"label": "Smelt Copper Bars",
				"count": 3,
				"xp": 80,
				"gold": 20,
				"intro": "Smelt 3 copper bars at the furnace in the square.",
				"nag": "Furnace in the square.",
				"done": "Bars. Now you're getting somewhere.",
				"quest": "Learn the Forge",
				"tip": "Click the furnace in the square and smelt copper ore into bars. 3 bars."
			},
			{
				"title": "Pests at the Gate",
				"goal": "kill",
				"target": "mosslet",
				"label": "Mosslets",
				"count": 5,
				"xp": 80,
				"gold": 20,
				"intro": "Kill 5 Mosslets outside the gate. Press N to set up your abilities.",
				"nag": "Just past the gates.",
				"done": "The gardens are safe again.",
				"tip": "Fight the Mosslets just outside the gate. Use keys 1-6, or right-click to auto-attack."
			},
			{
				"title": "Forged in Hearthmoor",
				"goal": "craft",
				"target": "any",
				"label": "Forge a piece of gear",
				"count": 1,
				"xp": 100,
				"gold": 25,
				"intro": "Make a piece of gear. Metal: click the hammer, then a bar, at an anvil. Leather and cloth: click the knife, then herbs or creature parts.",
				"nag": "Metal at the anvil, soft gear with the knife.",
				"done": "Look at you, all kitted out.",
				"quest": "Hearthmoor's Ways",
				"auto": true,
				"tip": "Metal gear: click the hammer, then a bar, at an anvil. Soft gear: click the knife, then herbs or creature parts."
			},
			{
				"title": "The Slayer's Mark",
				"goal": "talk",
				"target": "varka",
				"label": "Speak with Varka",
				"count": 1,
				"xp": 60,
				"gold": 20,
				"intro": "Meet Varka. She keeps to her own house in town.",
				"nag": "Look for her name over a doorstep in town.",
				"done": "She'll keep you busy.",
				"quest": "Hearthmoor's Ways",
				"auto": true,
				"tip": "Varka lives in her own house in town. Look for her name over the door."
			},
			{
				"title": "The Ember's Keeper",
				"goal": "talk",
				"target": "wisp",
				"label": "Speak with the Wisp",
				"count": 1,
				"xp": 120,
				"gold": 50,
				"reward_rarity": 2,
				"intro": "Speak with the Wisp at the shrine. Take this, my hunting days are done.",
				"nag": "The Wisp floats above the shrine.",
				"done": "Go well, keeper. Hearthmoor will be here.",
				"quest": "Hearthmoor's Ways",
				"tip": "The Wisp floats above the shrine. Speak with it, then come back to Rowan."
			}
		]
	},
	{
		"id": "hollis",
		"name": "Farmer Hollis",
		"sprite": "farmer",
		"biome": 0,
		"ang": 2.6,
		"dist": 13,
		"greet": "Morning, keeper. Mind the turnips.",
		"thanks": "Wren's up and about again. You're always welcome at our table.",
		"quests": [
			{
				"title": "Pests in the Pasture",
				"goal": "kill",
				"target": "mosslet",
				"label": "Mosslets",
				"count": 8,
				"xp": 60,
				"gold": 40,
				"intro": "Those Mosslets have eaten half my turnips. Squash eight of them and I'll pay you what I can.",
				"nag": "Still hearing them squelch in the rows.",
				"done": "Quiet at last! Here, for your trouble."
			},
			{
				"title": "Sunpetals for Wren",
				"goal": "gather",
				"target": "sunpetal",
				"label": "Sunpetals",
				"count": 5,
				"xp": 90,
				"gold": 60,
				"reward_rarity": 2,
				"intro": "My girl Wren's been poorly since the Ember dimmed. Sunpetals grow wild around my fields. They glow a little. Bring me five?",
				"nag": "They glow gold. You can't miss them once the sun's low.",
				"done": "She'll be smiling by supper. Take this. It was my father's."
			}
		]
	},
	{
		"id": "maren",
		"name": "Ranger Maren",
		"sprite": "ranger",
		"biome": 1,
		"ang": 0.9,
		"dist": 30,
		"greet": "Keep your voice down. The trees listen.",
		"thanks": "The Thornwood breathes easier. So do I.",
		"quests": [
			{
				"title": "Thinning the Pack",
				"goal": "kill",
				"target": "wolf",
				"label": "Grey Wolves",
				"count": 6,
				"xp": 250,
				"gold": 120,
				"intro": "The wolves have gone bold since the Rootfather turned. Cull six and the trails will be safer.",
				"nag": "The pack's still out there. I can hear them.",
				"done": "Good work. The trails are quieter already."
			},
			{
				"title": "Old Greymaw",
				"goal": "elite",
				"target": "alpha",
				"label": "Old Greymaw",
				"count": 1,
				"xp": 400,
				"gold": 200,
				"reward_rarity": 2,
				"intro": "Their leader, Old Greymaw, dens east of here. Bigger than any wolf has a right to be. End it.",
				"nag": "Greymaw's den is marked on your map. Go carefully.",
				"done": "Greymaw's gone. You've earned more than thanks. Take this."
			}
		]
	},
	{
		"id": "oswin",
		"name": "Hermit Oswin",
		"sprite": "hermit",
		"biome": 2,
		"ang": 2.2,
		"dist": 50,
		"greet": "Eh? Oh. A visitor. How rare.",
		"thanks": "My lanterns burn and the chanting's stopped. I may even sleep tonight.",
		"quests": [
			{
				"title": "Lights in the Bog",
				"goal": "gather",
				"target": "lantern",
				"label": "Lantern-caps",
				"count": 4,
				"xp": 600,
				"gold": 260,
				"intro": "Lantern-caps grow on the drowned logs round my hut. I need four to see by. Mind the Lurkers.",
				"nag": "Glowing mushrooms, keeper. Big ones.",
				"done": "Ah, light! Wonderful. Here, take some coin."
			},
			{
				"title": "The Shamans' Chant",
				"goal": "kill",
				"target": "shaman",
				"label": "Mire Shamans",
				"count": 6,
				"xp": 900,
				"gold": 380,
				"reward_rarity": 3,
				"intro": "Hear that chanting at night? The Mire Shamans are calling something up. Silence six of them.",
				"nag": "Still chanting. Still not sleeping.",
				"done": "Silence. Blessed silence. This trinket's yours. I never liked it."
			}
		]
	},
	{
		"id": "aldric",
		"name": "Brother Aldric",
		"sprite": "pilgrim",
		"biome": 3,
		"ang": 5.6,
		"dist": 63,
		"greet": "Peace on the road, traveler.",
		"thanks": "The pilgrim road is open once more. The Ember's light be with you.",
		"quests": [
			{
				"title": "Rime and Ruin",
				"goal": "kill",
				"target": "cultist",
				"label": "Rime Cultists",
				"count": 6,
				"xp": 1300,
				"gold": 500,
				"intro": "The Rime Cultists defile the old pilgrim road. Drive them off, six at the least.",
				"nag": "They still walk the road in their frost-masks.",
				"done": "The road is quieter. Bless you."
			},
			{
				"title": "The Frostbound Champion",
				"goal": "elite",
				"target": "champion",
				"label": "Frostbound Champion",
				"count": 1,
				"xp": 2000,
				"gold": 800,
				"reward_rarity": 3,
				"intro": "Their champion guards the high pass north of here. Bring him down and the road is ours again.",
				"nag": "The high pass is marked on your map.",
				"done": "You've done what an army couldn't. Take this, with the Order's thanks."
			}
		]
	},
	{
		"id": "peg",
		"name": "Net-mender Peg",
		"sprite": "farmer",
		"biome": 0,
		"ang": 0.0,
		"dist": 0,
		"greet": "Mind the nets, love. The tide leaves all sorts behind.",
		"thanks": "The boats go out easier now. Come back for a cuppa any time.",
		"quests": [
			{
				"title": "Beetles in the Nets",
				"goal": "kill",
				"target": "beetle",
				"label": "Thornbeetles",
				"count": 6,
				"xp": 70,
				"gold": 45,
				"intro": "Thornbeetles chew through my nets faster than I can mend them. Six of them gone and I'll sleep easy.",
				"nag": "I can hear them clicking along the dunes.",
				"done": "Quiet nets. Bless you."
			},
			{
				"title": "Thrift for the Boats",
				"goal": "gather",
				"target": "thrift",
				"label": "Sea Thrift",
				"count": 5,
				"xp": 100,
				"gold": 65,
				"reward_rarity": 1,
				"intro": "The old sailors tie sea thrift to the bows for luck. Pink flowers, they glow a little at dusk. Five, please.",
				"nag": "Along the dunes by the water. Pink and glowing.",
				"done": "Luck for the whole fleet. Take this, it was my husband's."
			}
		]
	},
	{
		"id": "corwin",
		"name": "Huntsman Corwin",
		"sprite": "ranger",
		"biome": 1,
		"ang": 0.0,
		"dist": 0,
		"greet": "Quiet now. The briars have ears.",
		"thanks": "The lodge sleeps safe tonight. You've a place by the fire.",
		"quests": [
			{
				"title": "Brood in the Briars",
				"goal": "kill",
				"target": "spider",
				"label": "Thicket Spiders",
				"count": 8,
				"xp": 300,
				"gold": 130,
				"intro": "Something's driven the spiders out of their den. They're in the briars, in the rafters. Kill eight.",
				"nag": "Listen for the clicking in the thorns.",
				"done": "Fewer eyes in the dark. Good."
			},
			{
				"title": "Berries for the Salve",
				"goal": "gather",
				"target": "briarberry",
				"label": "Briarberries",
				"count": 5,
				"xp": 380,
				"gold": 160,
				"reward_rarity": 2,
				"intro": "My salve needs briarberries, the dark red ones. They grow where the thorns are thickest. Five.",
				"nag": "Dark red, deep in the thorns. Watch your step.",
				"done": "That'll mend a hunter's hide. Here, take my spare."
			}
		]
	},
	{
		"id": "dunn",
		"name": "Wharfmaster Dunn",
		"sprite": "slayer",
		"biome": 2,
		"ang": 0.0,
		"dist": 0,
		"greet": "Tide's out and the leeches are in. Welcome to Bellwharf.",
		"thanks": "The wharf's working again. The bell rings true.",
		"quests": [
			{
				"title": "Leeches on the Pilings",
				"goal": "kill",
				"target": "leech",
				"label": "Bog Leeches",
				"count": 6,
				"xp": 500,
				"gold": 220,
				"intro": "Bog Leeches have burrowed into the mudflats and rotted my pilings. Dig six of them out for good.",
				"nag": "They burrow, so watch the mud ripple.",
				"done": "The pilings hold. I owe you."
			},
			{
				"title": "Brinecaps for the Cure",
				"goal": "gather",
				"target": "brinecap",
				"label": "Brinecaps",
				"count": 5,
				"xp": 600,
				"gold": 260,
				"intro": "The sick need brinecap broth. Teal mushrooms, they grow on the wrecks. Five should do.",
				"nag": "Teal mushrooms on the wrecks and posts.",
				"done": "That will save a few lives. Take this for the road."
			},
			{
				"title": "The Crones of the Delta",
				"goal": "kill",
				"target": "crone",
				"label": "Bog Crones",
				"count": 3,
				"xp": 800,
				"gold": 340,
				"reward_rarity": 2,
				"intro": "Bog Crones are brewing something out in the reeds. It drifts in at night and the wharf folk dream wrong. Three of them.",
				"nag": "Out in the reeds past the wrecks.",
				"done": "No more bad dreams. This was my father's."
			}
		]
	},
	{
		"id": "ysolt",
		"name": "Shepherd Ysolt",
		"sprite": "elder",
		"biome": 3,
		"ang": 0.0,
		"dist": 0,
		"greet": "Wind's up. Keep your hood close, traveller.",
		"thanks": "The flock is safe and the cairns are quiet. The Downs remember kindness.",
		"quests": [
			{
				"title": "Hounds on the Ridge",
				"goal": "kill",
				"target": "downhound",
				"label": "Downs Hounds",
				"count": 6,
				"xp": 1000,
				"gold": 420,
				"intro": "Downs Hounds took three of my flock last night. Pale things, fast. Put six of them down.",
				"nag": "They hunt along the ridge, near the stones.",
				"done": "My sheep thank you. So do I."
			},
			{
				"title": "Heather for the Dead",
				"goal": "gather",
				"target": "heather",
				"label": "Downs Heather",
				"count": 5,
				"xp": 1100,
				"gold": 460,
				"intro": "We lay heather on the old cairns so the dead rest. Purple, faintly glowing. Bring me five.",
				"nag": "Purple, on the high ground near the stones.",
				"done": "Rest easy, old ones. Thank you."
			},
			{
				"title": "The Barrow-King",
				"goal": "elite",
				"target": "barrowking",
				"label": "The Barrow-King",
				"count": 1,
				"xp": 1800,
				"gold": 700,
				"reward_rarity": 3,
				"intro": "Something has woken in the ruined keep. The shepherds call him the Barrow-King. Lay him down.",
				"nag": "The ruined keep is marked on your map.",
				"done": "He walks no more. Take this, with the Downs' thanks."
			}
		]
	}
]
## Named elites for "elite" quests: base enemy, multipliers, and where their lair is (angle/distance from the shrine, in cells).
const ELITES := {
	"alpha": {"name": "Old Greymaw", "base": "wolf", "hp": 7.0, "dmg": 1.8, "scale": 1.7, "xp": 6, "ang": 0.62, "dist": 35,
		"pal": {"g": "5a5662", "G": "8a8692", "e": "ff5a3a"}},
	"barrowking": {"name": "The Barrow-King", "base": "barrowwight", "hp": 7.0, "dmg": 1.7, "scale": 1.7, "xp": 6, "ang": 0.0, "dist": 0,
		"pal": {"g": "e8e0a0", "a": "3a3a22", "orb": "ffe86a"}},
	"champion": {"name": "Frostbound Champion", "base": "cultist", "hp": 6.0, "dmg": 1.6, "scale": 1.6, "xp": 6, "ang": 5.85, "dist": 66,
		"pal": {"g": "e8f6ff", "a": "1a3a6a"}},
}
const GATHER := {
	"sunpetal": {"name": "Sunpetal", "color": "ffd27a", "stem": "4c8a3c"},
	"lantern": {"name": "Lantern-cap", "color": "9fe0a0", "stem": "6a5a48"},
	"thrift": {"name": "Sea Thrift", "color": "ff9ac8", "stem": "5a8a4a"},
	"briarberry": {"name": "Briarberry", "color": "e03a4a", "stem": "3a2a1e"},
	"brinecap": {"name": "Brinecap", "color": "7affd8", "stem": "b8c8c0"},
	"heather": {"name": "Downs Heather", "color": "b88aff", "stem": "5a6a3a"},
}

# ---------------------------------------------------------------- sprites
## 12x13 hero sprite. k=outline, H=hood/helmet, s=skin, a=main, b=trim, d=legs.
const HERO_A := [
	"....kkkk....", "...kHHHHk...", "..kHHHHHHk..", "..kssssssk..", "..kskssksk..", "..kssssssk..", "...kaaaak...",
	"..kaabbaak..", ".ksaabbaask.", "..kaaaaaak..", "..kddddddk..", "...kd..dk...", "...kk..kk...",
]
const HERO_B := [
	"....kkkk....", "...kHHHHk...", "..kHHHHHHk..", "..kssssssk..", "..kskssksk..", "..kssssssk..", "...kaaaak...",
	"..kaabbaak..", ".ksaabbaask.", "..kaaaaaak..", "..kddddddk..", "..kd....dk..", "..kk....kk..",
]

# ---------------------------------------------------------------- input
## Key bindings. Ints are physical key codes; "mouse_left"/"mouse_right" are mouse buttons.
const BINDINGS := {
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
	"turn_left": [KEY_A, KEY_LEFT],
	"turn_right": [KEY_D, KEY_RIGHT],
	"strafe_left": [KEY_Q],
	"strafe_right": [KEY_E],
	"autorun": [KEY_R],
	"target_next": [KEY_TAB],
	"attack": [],   # no key: attacks are right-click or any ability on an enemy (auto attack)
	"ability_1": [KEY_1],
	"ability_2": [KEY_2],
	"ability_3": [KEY_3],
	"ability_4": [KEY_4],
	"ability_5": [KEY_5],
	"ability_6": [KEY_6],
	"jump": [KEY_SPACE],
	"sprint": [KEY_SHIFT],
	"interact": [KEY_G],
	"potion": [KEY_H],
	"map": [KEY_M],
	"inventory": [KEY_I, KEY_B],
	"character": [KEY_K],
	"skills": [KEY_U],
	"abilities": [KEY_N],
	"talents": [KEY_T],
	"food": [KEY_X],
	"might": [KEY_Y],
	"swift": [KEY_V],
	"questbook": [KEY_L],
	"settings": [KEY_O],
	"pause": [KEY_ESCAPE, KEY_P],
}


func _ready() -> void:
	if Engine.is_editor_hint():
		return   # embers world builder: only the tables are needed in the editor
	var audio := Sfx.new()
	audio.name = "Audio"
	add_child(audio)
	for action: String in BINDINGS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		for b: Variant in BINDINGS[action]:
			var ev: InputEvent
			if b is String:
				var m := InputEventMouseButton.new()
				m.button_index = MOUSE_BUTTON_LEFT if b == "mouse_left" else MOUSE_BUTTON_RIGHT
				ev = m
			else:
				var k := InputEventKey.new()
				k.physical_keycode = b
				ev = k
			InputMap.action_add_event(action, ev)


## Builds a nearest-filtered texture from a list of pixel rows and a palette of hex colours.
func make_sprite(rows: Array, pal: Dictionary) -> ImageTexture:
	var h := rows.size()
	var w: int = (rows[0] as String).length()
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var full := {"k": "1a1420", "s": "e8b48a"}
	full.merge(pal, true)
	for y in h:
		var row: String = rows[y]
		for x in w:
			var ch := row[x]
			if ch != "." and full.has(ch):
				img.set_pixel(x, y, Color(full[ch]))
	return ImageTexture.create_from_image(img)


var _art_cache := {}


## Hero and NPC art (16x22, drawn in tools/make_sprites.py). Works for class ids and NPC names.
func art_frames(id: String) -> Array[ImageTexture]:
	if _art_cache.has(id):
		return _art_cache[id]
	var d: Dictionary = SpriteArt.SPRITES[id]
	var frames: Array[ImageTexture] = [make_sprite(d["a"], d["pal"]), make_sprite(d["b"], d["pal"])]
	_art_cache[id] = frames
	return frames


func hero_frames(class_id: String) -> Array[ImageTexture]:
	return art_frames(class_id)


# ================================================================ skills (RuneScape-style)
const MAX_SKILL := 30
const SKILL_ORDER := ["melee", "magic", "ranged", "slayer", "mining", "woodcutting", "fishing", "herblore", "smithing", "crafting", "cooking", "firemaking", "agility"]
const COMBAT_SKILL := {"warrior": "melee", "rogue": "melee", "mage": "magic", "hunter": "ranged"}
const SKILLS := {
	"melee": {"name": "Melee", "color": "d05a3a", "desc": "Close-quarters fighting. Raises health, damage and armor. Your Melee talents (T) teach the abilities.",
		"unlocks": [[1, "Strike"], [2, "A talent point every 2 levels: Bulwark, Shadow and Venom abilities"], [12, "Deep talents change Strike"], [30, "Master of arms"]]},
	"magic": {"name": "Magic", "color": "8a6ae0", "desc": "Mages. Raises health, spell power and mana regeneration, and unlocks spells.",
		"unlocks": [[1, "Fireball, Blink"], [3, "Frost Nova"], [5, "Arcane Barrier"], [8, "Chain Lightning"], [12, "Meteor"], [30, "Archmage"]]},
	"ranged": {"name": "Ranged", "color": "6ab050", "desc": "Hunters. Raises health and bow damage, and unlocks shots and tricks.",
		"unlocks": [[1, "Power Shot, Disengage"], [3, "Volley"], [5, "Snare Trap"], [8, "Rain of Arrows"], [12, "Spirit Wolf"], [30, "Deadeye"]]},
	"slayer": {"name": "Slayer", "color": "a02a3a", "desc": "Take tasks from Varka at the shrine. Kill what she asks for XP and gold. +1% damage per level against your task.",
		"unlocks": [[1, "Meadow tasks"], [8, "Thornwood tasks"], [16, "Mire tasks"], [24, "Frostspine tasks"], [30, "+30% damage on task"]]},
	"mining": {"name": "Mining", "color": "9aa0aa", "desc": "Mine ore rocks with a pickaxe. Smelt the ore at the furnace. You can chip Flint from rocks too.",
		"unlocks": [[1, "Copper Ore"], [8, "Sturdy Pickaxe (Crafting 8): mine faster"], [12, "Bog Iron"], [22, "Frost Crystal"]]},
	"woodcutting": {"name": "Woodcutting", "color": "8a6a3a", "desc": "Chop trees with an axe. Logs make tool handles, rods, vials, kindling and fires.",
		"unlocks": [[1, "Oak Logs"], [8, "Heartwood"], [8, "Sturdy Hatchet (Crafting 8): chop faster"]]},
	"fishing": {"name": "Fishing", "color": "5a9ad0", "desc": "Fish at rippling spots with a fishing rod and bait. Cut bait from creatures with a knife. Cook what you catch.",
		"unlocks": [[1, "Minnows (meadow ponds, the shore)"], [8, "Trout (Thornwood streams)"], [10, "Supple Rod (Crafting 10): fish faster"], [16, "Mud Eels (the Mire, the shore)"], [24, "Icefin (the far shore)"]]},
	"herblore": {"name": "Herblore", "color": "4ab060", "desc": "Pick herbs in the wild and brew them by using a glass vial on a herb. Each potion needs a herb, a creature ingredient and a vial.",
		"unlocks": [[1, "Greenleaf · Health Potion"], [8, "Thornbud · Might Draught (+25% damage)"], [16, "Marshroot · Swift Tonic (+20% speed)"], [24, "Frostbloom · Greater Potion (heals 70%)"]]},
	"smithing": {"name": "Smithing", "color": "c87a3a", "desc": "Smelt ore into bars at the furnace, then forge tools at the anvil. Hilde's forge makes and upgrades weapons and armor.",
		"unlocks": [[1, "Copper Bars · Copper Knife, Axe, Pickaxe · Glass Vials · copper gear"], [3, "Flint and Steel"], [8, "Heartwood gear"], [12, "Bog Iron Bars · Bog Iron Axe and Pickaxe"], [16, "Bog Iron gear"], [22, "Frost Bars · Frost Axe and Pickaxe"], [24, "Frostforged gear"]]},
	"crafting": {"name": "Crafting", "color": "d0a050", "desc": "Rings, amulets, tools and bags. Rings and amulets at the forge; tools by using a knife on twigs, logs or bars.",
		"unlocks": [[1, "Wooden Pickaxe, Axe, Knife · Fishing Rod · Copper rings and amulets"], [5, "Leather Satchel (+5 bag slots)"], [8, "Sturdy Pickaxe, Sturdy Hatchet · Heartwood jewelry"], [10, "Supple Rod"], [16, "Bog Iron jewelry"], [18, "Traveler's Pack (+5 bag slots)"], [24, "Frostforged jewelry"]]},
	"cooking": {"name": "Cooking", "color": "e08a3a", "desc": "Cook fish at any campfire or the shrine. Food heals (key X). Higher levels burn less.",
		"unlocks": [[1, "Minnow (heals 35)"], [8, "Trout (heals 80)"], [16, "Mud Eel (heals 140)"], [24, "Icefin (heals 230)"]]},
	"firemaking": {"name": "Firemaking", "color": "e0703a", "desc": "Right-click a log in your bag to cut kindling (needs a knife), then right-click the kindling to light it (needs Flint and Steel and another log). Fires last a while and work for cooking.",
		"unlocks": [[1, "Oak fires"], [10, "Heartwood fires (last twice as long)"]]},
	"agility": {"name": "Agility", "color": "4a8ac0", "desc": "Run obstacle courses (and sprint and jump around) to move faster and recover stamina quicker.",
		"unlocks": [[1, "Meadow course · +0.6% speed per level"], [10, "Thornwood course"], [15, "Double jump"], [20, "Frostspine course"], [30, "+18% speed"]]},
}

## XP needed to go from level l to l+1 (all skills use the same curve).
static func xp_needed(lvl: int) -> int:
	return roundi(25.0 * pow(lvl, 1.6))


## Total XP needed to reach a level.
static func xp_for_level(lvl: int) -> int:
	var t := 0
	for i in range(1, lvl):
		t += xp_needed(i)
	return t


static func level_for_xp(xp: int) -> int:
	var l := 1
	while l < MAX_SKILL and xp >= xp_for_level(l + 1):
		l += 1
	return l


## Fishing spots: which fish swims where, and what you need.
const FISH := [
	{
		"raw": "raw_minnow",
		"bait": "bait_0",
		"biomes": [
			0,
			4
		],
		"lvl": 1,
		"xp": 20
	},
	{
		"raw": "raw_trout",
		"bait": "bait_1",
		"biomes": [
			1
		],
		"lvl": 8,
		"xp": 40
	},
	{
		"raw": "raw_eel",
		"bait": "bait_2",
		"biomes": [
			2,
			4
		],
		"lvl": 16,
		"xp": 62
	},
	{
		"raw": "raw_icefin",
		"bait": "bait_3",
		"biomes": [
			3,
			4
		],
		"lvl": 24,
		"xp": 90
	}
]
## Recipes at the cooking fire, furnace and anvil, and by using items (knife, vial, hammer) on materials.
## out: material made (or "potion" / "bag:N" / "tool:<skill>"), cost: materials, burn: can fail at low level, once: one-time upgrade.
const RECIPES := {
	"cooking": [
		{"out": "minnow", "name": "Cooked Minnow", "lvl": 1, "xp": 18, "cost": {"raw_minnow": 1}, "burn": true, "desc": "Heals 35 "},
		{"out": "trout", "name": "Cooked Trout", "lvl": 8, "xp": 38, "cost": {"raw_trout": 1}, "burn": true, "desc": "Heals 80 "},
		{"out": "eel", "name": "Cooked Eel", "lvl": 16, "xp": 60, "cost": {"raw_eel": 1}, "burn": true, "desc": "Heals 140 "},
		{"out": "icefin", "name": "Cooked Icefin", "lvl": 24, "xp": 88, "cost": {"raw_icefin": 1}, "burn": true, "desc": "Heals 230 "},
	],
	"herblore": [
		{"out": "potion", "name": "Health Potion", "lvl": 1, "xp": 30, "cost": {"greenleaf": 2, "mossgel": 1, "vial": 1}, "desc": "Heals 45%"},
		{"out": "might", "name": "Might Draught", "lvl": 8, "xp": 55, "cost": {"thornbud": 2, "pelt": 1, "vial": 1}, "desc": "+25% damage for 2 min"},
		{"out": "swift", "name": "Swift Tonic", "lvl": 16, "xp": 80, "cost": {"marshroot": 2, "witchroot": 1, "vial": 1}, "desc": "+20% speed and faster stamina for 2 min"},
		{"out": "greater", "name": "Greater Potion", "lvl": 24, "xp": 110, "cost": {"frostbloom": 2, "rime": 1, "vial": 1}, "desc": "Heals 70%, used before Health Potions"},
	],
	"furnace": [
		{"out": "copper_bar", "name": "Copper Bar", "lvl": 1, "xp": 14, "cost": {"copper": 1}, "desc": "Smelt a Copper Ore"},
		{"out": "vial", "qty": 3, "name": "Glass Vials (x3)", "lvl": 1, "xp": 10, "cost": {"mossgel": 1, "oak": 1}, "desc": "Melt Mossgel into glass, fired with a log"},
		{"out": "bogiron_bar", "name": "Bog Iron Bar", "lvl": 12, "xp": 36, "cost": {"bogiron": 1}, "desc": "Smelt Bog Iron"},
		{"out": "frost_bar", "name": "Frost Bar", "lvl": 22, "xp": 60, "cost": {"frost": 1}, "desc": "Smelt a Frost Crystal"},
	],
	"anvil": [
		{"out": "knife", "name": "Copper Knife", "lvl": 1, "xp": 20, "cost": {"copper_bar": 1, "twig": 2}, "desc": "Cuts bait and kindling, extra bait", "once": true},
		{"out": "axe", "name": "Copper Axe", "lvl": 1, "xp": 30, "cost": {"copper_bar": 2, "oak": 1}, "desc": "Chops oak and heartwood", "once": true},
		{"out": "pickaxe", "name": "Copper Pickaxe", "lvl": 1, "xp": 30, "cost": {"copper_bar": 2, "oak": 1}, "desc": "Mines bog iron too", "once": true},
		{"out": "bogiron_axe", "name": "Bog Iron Axe", "lvl": 12, "xp": 70, "cost": {"bogiron_bar": 3, "heartwood": 1}, "desc": "Chop faster", "once": true},
		{"out": "bogiron_pickaxe", "name": "Bog Iron Pickaxe", "lvl": 12, "xp": 70, "cost": {"bogiron_bar": 2, "heartwood": 1}, "desc": "Mines frost crystal", "once": true},
		{"out": "frost_axe", "name": "Frost Axe", "lvl": 22, "xp": 120, "cost": {"frost_bar": 3, "heartwood": 2}, "desc": "Chop fastest", "once": true},
		{"out": "frost_pickaxe", "name": "Frost Pickaxe", "lvl": 22, "xp": 120, "cost": {"frost_bar": 2, "heartwood": 2}, "desc": "Mine fastest", "once": true},
		{"out": "tool:mining", "name": "Sturdy Pickaxe", "lvl": 8, "xp": 80, "cost": {"copper_bar": 3, "oak": 4}, "desc": "Mine 30% faster", "once": true},
		{"out": "tool:woodcutting", "name": "Sturdy Hatchet", "lvl": 8, "xp": 80, "cost": {"copper_bar": 3, "oak": 4}, "desc": "Chop 30% faster", "once": true},
		{"out": "flint_steel", "name": "Flint and Steel", "lvl": 3, "xp": 28, "cost": {"copper_bar": 1, "flint": 1}, "desc": "Light fires", "once": true},
	],
	"crafting": [
		{"out": "wooden_pickaxe", "name": "Wooden Pickaxe", "lvl": 1, "xp": 12, "cost": {"twig": 6}, "desc": "Mines copper", "once": true},
		{"out": "wooden_axe", "name": "Wooden Axe", "lvl": 1, "xp": 12, "cost": {"twig": 6}, "desc": "Chops oak", "once": true},
		{"out": "kindling_oak", "qty": 2, "name": "Oak Kindling", "skill": "firemaking", "lvl": 1, "xp": 6, "cost": {"oak": 1}, "desc": "Cut a log into 2 kindling to light a fire"},
		{"out": "kindling_heart", "qty": 2, "name": "Heartwood Kindling", "skill": "firemaking", "lvl": 10, "xp": 14, "cost": {"heartwood": 1}, "desc": "Cut a log into 2 kindling to light a fire"},
		{"out": "hammer", "name": "Wooden Hammer", "lvl": 1, "xp": 12, "cost": {"twig": 6}, "desc": "Shapes metal at an anvil", "once": true},
		{"out": "rod", "name": "Fishing Rod", "lvl": 1, "xp": 25, "cost": {"twig": 8}, "desc": "Needed to fish (and bait)"},
		{"out": "tool:fishing", "name": "Supple Rod", "lvl": 10, "xp": 100, "cost": {"heartwood": 4, "pelt": 2, "copper_bar": 2}, "desc": "Fish 30% faster", "once": true},
	],
}
## Slayer tasks: which enemies Varka hands out at which Slayer level.
const SLAYER_TASKS := [
	{"enemy": "mosslet", "lvl": 1}, {"enemy": "beetle", "lvl": 1}, {"enemy": "puffcap", "lvl": 1},
	{"enemy": "wolf", "lvl": 8}, {"enemy": "archer", "lvl": 8}, {"enemy": "spider", "lvl": 8}, {"enemy": "sapling", "lvl": 8},
	{"enemy": "lurker", "lvl": 16}, {"enemy": "shaman", "lvl": 16}, {"enemy": "leech", "lvl": 16}, {"enemy": "crone", "lvl": 16},
	{"enemy": "snowwolf", "lvl": 24}, {"enemy": "cultist", "lvl": 24}, {"enemy": "golem", "lvl": 24}, {"enemy": "frostwisp", "lvl": 24},
]
const SLAYER_NAME := "Varka"
## Agility courses: biome, level, and XP per obstacle / full lap.
const AGILITY := [
	{"name": "Meadow Run", "biome": 0, "lvl": 1, "xp": 12, "lap": 80},
	{"name": "Thornwood Gauntlet", "biome": 1, "lvl": 10, "xp": 28, "lap": 200},
	{"name": "Frostspine Climb", "biome": 3, "lvl": 20, "xp": 50, "lap": 380},
]
