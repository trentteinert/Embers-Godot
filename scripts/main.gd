extends Node3D
## Runs the game: title screen, new game / continue, story progression, leveling, death,
## pause menu, biome atmosphere and saving. Fights themselves live in combat.gd.

const SAVE_PATH := "user://save.json"
const BAG_SIZE := 28          # 4 x 7 slots
const BIOME_MUSIC := ["meadow", "thornwood", "mire", "peaks", "meadow"]
## Per-biome mood: fog colour, fog density, sun colour, sun strength.
const ATMOS := [
	[Color("b9cfe0"), 0.0035, Color("fff2dc"), 1.05],   # Greenreach Meadow
	[Color("6f8f74"), 0.009, Color("e8f0c8"), 0.8],     # Thornwood
	[Color("7a8a6a"), 0.014, Color("d8e0b0"), 0.7],     # The Mire
	[Color("c8d8ec"), 0.008, Color("e8f0ff"), 0.85],    # Frostspine Peaks
	[Color("b9cfe0"), 0.003, Color("fff2dc"), 1.05],    # The Shore
]

@onready var world: World = $World
@onready var player: Player = $Player
@onready var rig: CameraRig = $CameraRig
@onready var combat: Combat = $Combat
@onready var quests: Quests = $Quests
@onready var crafting: Crafting = $Crafting
@onready var ui: GameUI = $UI
var dev_panel: DevPanel
var build_editor: BuildEditor
@onready var sun: DirectionalLight3D = $Sun
@onready var env_node: WorldEnvironment = $WorldEnvironment

var mode := "title"      # title, play, dead
var paused := false
var inv_open := false
var shop_open := false
var forge_open := false
var window := ""          # which side-panel tab is open (other than char / bag)
var _station_pos := Vector3.ZERO
var state := {}
var clicker: Clicker
var skills: Skills
var guide: Guide
var target: Enemy           # the enemy you clicked on (shown in the target frame)
var dev_mode := false       # testing: unlimited gold and quest objectives fill themselves
var _env: Environment
var daynight: DayNight
var _act_block := 0.0
var _save_t := 0.0
var _death_t := 0.0
var _last_biome := -1
var online: Online          # set when the game was started with --online (see online.gd)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for n: Node in [world, player, rig, sun, combat, quests, crafting]:
		n.process_mode = Node.PROCESS_MODE_PAUSABLE
	_setup_environment()
	world.generate()
	player.world = world
	dev_panel = DevPanel.new()
	ui.add_child(dev_panel)
	dev_panel.setup(self)
	build_editor = BuildEditor.new()
	add_child(build_editor)
	build_editor.setup(self)
	build_editor.apply_instances()
	build_editor.apply_sites()
	player.combat_ref = combat
	player.camera = rig.camera
	rig.world = world
	rig.clicked.connect(_on_world_click)
	player.notify.connect(func(t: String) -> void: ui.toast(t))
	combat.setup(self)
	world.caves.setup(self)
	quests.setup(self)
	crafting.setup(self)
	skills = Skills.new()
	add_child(skills)
	skills.process_mode = Node.PROCESS_MODE_PAUSABLE
	skills.setup(self)
	clicker = Clicker.new()
	add_child(clicker)
	clicker.setup(self)
	guide = Guide.new()
	add_child(guide)
	guide.process_mode = Node.PROCESS_MODE_PAUSABLE
	guide.setup(self)
	Sfx.inst.listener = player
	ui.setup(self)
	player.setup("warrior", 1)
	player.teleport(world.spawn_point())
	daynight = DayNight.new()
	add_child(daynight)
	daynight.process_mode = Node.PROCESS_MODE_PAUSABLE
	daynight.setup(_env, sun, world, player, ATMOS)
	show_title()
	online = Online.try_start(self)
	if online == null:
		OnlineLogin.attach(self)   # the login screen for online play (launch arguments still work)


# ================================================================ environment
func _setup_environment() -> void:
	_env = Environment.new()
	_env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var psm := ProceduralSkyMaterial.new()
	psm.sky_top_color = Color("4f78b0")
	psm.sky_horizon_color = Color("c9d8e4")
	psm.ground_horizon_color = Color("c9d8e4")
	psm.ground_bottom_color = Color("31445a")
	sky.sky_material = psm
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_env.ambient_light_energy = 0.38
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.tonemap_exposure = 0.92
	_env.glow_enabled = true
	_env.glow_intensity = 0.5
	_env.glow_bloom = 0.04
	_env.ssao_enabled = true
	_env.ssao_intensity = 1.6
	_env.fog_enabled = true
	_env.fog_light_color = ATMOS[0][0]
	_env.fog_density = ATMOS[0][1]
	_env.fog_sky_affect = 0.25
	_env.adjustment_enabled = true
	_env.adjustment_saturation = 1.0
	env_node.environment = _env
	sun.rotation_degrees = Vector3(-52, 32, 0)
	sun.light_color = ATMOS[0][2]
	sun.light_energy = ATMOS[0][3]
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	sun.shadow_blur = 0.6


func _update_atmosphere(_delta: float) -> void:
	var b := world.biome_at(player.global_position)
	daynight.biome = b
	# the tutorial camp stays a bright morning; after that the day starts rolling
	daynight.frozen = bool(state.get("tut_safe", false))
	state["tod"] = daynight.tod
	if b != _last_biome:
		_last_biome = b


# ================================================================ flow
func show_title() -> void:
	mode = "title"
	paused = false
	get_tree().paused = false
	combat.reset()
	player.visible = false
	player.set_physics_process(false)
	rig.target = null
	rig.focus = world.shrine_pos
	rig.orbiting = true
	rig.distance = 28.0
	world.set_lit(0)
	daynight.tod = 0.72
	daynight.snap()
	ui.show_dead(false)
	ui.show_inventory(false)
	ui.show_shop(false)
	ui.show_forge(false)
	inv_open = false
	shop_open = false
	forge_open = false
	window = ""
	ui.close_side()
	ui.show_title(FileAccess.file_exists(SAVE_PATH))
	Sfx.music("title")


func _tier() -> int:
	return int(state["bi"]) + (1 if state["done"] else 0)


func _begin_play() -> void:
	mode = "play"
	paused = false
	get_tree().paused = false
	daynight.tod = float(state.get("tod", 0.3))
	daynight.snap()
	combat.reset()
	ui.hide_title()
	ui.show_pause(false)
	ui.show_hud(true)
	ui.show_dead(false)
	player.dead = false
	player.visible = true
	player.set_physics_process(true)
	rig.orbiting = false
	rig.reset_yaw()
	player.cam_yaw = 0.0
	player.face_yaw = 0.0
	rig.target = player
	rig.snap()
	_last_biome = -1
	ui.build_ability_bar(player.class_id)
	_refresh_world()


func new_game(class_id: String, look := {}, pname := "") -> void:
	state = {"cls": class_id, "look": look, "name": pname.strip_edges(), "lvl": 1, "xp": 0, "potions": 2, "shards": 0, "bi": 0, "step": 0,
		"runes": [false, false, false, false], "done": false, "bag": [], "equip": {}, "gold": 0, "shop": [], "quests": {}, "mats": {},
		"skills": {}, "tools": {}, "bag_lvl": 0, "slayer": {}, "kit": true, "tut_safe": true, "tod": 0.3, "bar": [-1, -1, -1, -1, -1, -1]}
	state["mats"] = {}
	world.reset_fog()
	sync_combat_level(false)
	for it: Dictionary in Items.starter_kit(class_id):
		state["equip"]["offhand" if it.get("offhand", false) else it["slot"]] = it
	_apply_gear(false)
	Sfx.play("menu_start")
	player.look = look
	player.setup(class_id, 1)
	_restock_shop()
	quests.reset()
	player.teleport(world.spawn_point())
	_begin_play()
	var cname: String = Data.CLASSES[class_id]["name"]
	ui.say(Data.intro_lines(cname))
	save_game()


## Apply a new look and name from the appearance screen.
func apply_appearance(look: Dictionary, pname: String) -> void:
	state["look"] = look
	state["name"] = pname
	player.look = look
	player.refresh_look()
	save_game()
	ui.toast("Looking good, %s." % pname)


func continue_game() -> void:
	var d := _read_save()
	if d.is_empty():
		ui.toast("No save found")
		return
	state = d
	if d.has("fog"):
		world.load_fog(Marshalls.base64_to_raw(String(d["fog"])))
	else:
		world.reset_fog()
		world.reveal(Vector3(d["pos"][0], 0, d["pos"][2]), 90.0)
	state.erase("fog")
	_migrate_melee(d)
	for k in ["lvl", "bi", "step", "shards", "potions", "xp"]:
		state[k] = int(d.get(k, 0))
	state["lvl"] = maxi(1, state["lvl"])
	state["done"] = bool(d.get("done", false))
	if not (state.get("skills") is Dictionary):
		# old save from before skills: carry the old level over into this class's combat skill
		state["skills"] = {Data.COMBAT_SKILL[state["cls"]]: Data.xp_for_level(state["lvl"]) + int(state["xp"])}
	for sk: String in state["skills"]:
		state["skills"][sk] = int(state["skills"][sk])
	if not (state.get("tools") is Dictionary):
		state["tools"] = {}
	if not (state.get("slayer") is Dictionary):
		state["slayer"] = {}
	state["bag_lvl"] = int(state.get("bag_lvl", 0))
	state["tod"] = float(state.get("tod", 0.3))
	sync_combat_level(false)
	if not state.has("bag") or not (state["bag"] is Array):
		state["bag"] = []
	if not state.has("equip") or not (state["equip"] is Dictionary) or (state["equip"] as Dictionary).is_empty():
		state["equip"] = {}
		for it: Dictionary in Items.starter_kit(state["cls"]):
			state["equip"]["offhand" if it.get("offhand", false) else it["slot"]] = it
	state["oh_given"] = true
	_apply_gear(false)
	if not (state.get("look") is Dictionary):
		state["look"] = {}
	state["name"] = String(state.get("name", ""))
	player.look = state["look"]
	player.setup(state["cls"], state["lvl"], true, _tier())
	state["gold"] = int(d.get("gold", 0))
	if not (state.get("mats") is Dictionary):
		state["mats"] = {}
	if not bool(d.get("kit", false)):
		# saves from before tools: hand over the basic kit so nobody is stranded
		state["kit"] = true
		for tk: String in ["pickaxe", "axe", "rod", "knife", "flint_steel"]:
			if int(state["mats"].get(tk, 0)) <= 0:
				state["mats"][tk] = 1
		if not (state.get("bar") is Array):
			state["bar"] = [0, 1, 2, 3, 4, 5]   # they were used to a full bar
	if not (state.get("bar") is Array) or (state["bar"] as Array).size() != 6:
		state["bar"] = [-1, -1, -1, -1, -1, -1]
	for bi2 in 6:
		state["bar"][bi2] = int(state["bar"][bi2])
	if not (state.get("quests") is Dictionary):
		state["quests"] = {}
	var tam_q: Dictionary = (state["quests"] as Dictionary).get("tam", {})
	if (int(tam_q.get("stage", 0)) >= 1 or bool(tam_q.get("active", false)) or bool(tam_q.get("done", false)) or state["quests"].has("king")) and skills.tool_tier("knife") < 0:
		state["mats"]["wooden_knife"] = 1   # a knife is how you craft now
	if not (state.get("shop") is Array) or (state["shop"] as Array).is_empty():
		_restock_shop()
	quests.reset()
	var pos: Array = d.get("pos", [])
	if pos.size() == 3:
		player.teleport(Vector3(pos[0], pos[1] + 0.3, pos[2]))
	else:
		player.teleport(world.spawn_point())
	if d.has("hp"):
		player.hp = clampf(float(d["hp"]), 1.0, player.max_hp)
	_begin_play()
	ui.toast("Welcome back, %s" % Data.CLASSES[state["cls"]]["name"])


func to_main_menu() -> void:
	if combat.boss:
		combat.despawn_boss("")
	save_game()
	ui.show_pause(false)
	show_title()


## The old pause menu is now the Settings tab of the side panel (the game keeps running).
func toggle_pause() -> void:
	if mode != "play":
		return
	ui.toggle_side("settings")


## Your weapon decides your fighting style: a sword is Melee with Rage, daggers are Melee with Energy,
## a staff is Magic and a bow is Ranged. Each style keeps its own action bar and levels its own skill.
## Warrior and Rogue became one Melee fighter with three talent leanings. Old bars point at the old ability lists.
const OLD_BAR := {
	"warrior": ["cleave", "charge", "whirl", "shout", "slam", "stand"],
	"rogue": ["backstab", "step", "stealth", "poison", "fan", "smoke", "flurry", "assassinate", "venomburst"],
}


func _migrate_melee(d: Dictionary) -> void:
	var old: String = String(state.get("cls", "warrior"))
	if bool(d.get("melee_merged", false)) or not OLD_BAR.has(old):
		state["cls"] = "warrior" if old == "rogue" else old
		state["melee_merged"] = true
		return
	var ids: Array = OLD_BAR[old]
	var nb: Array = [-1, -1, -1, -1, -1, -1]
	var abil: Array = Data.ABILITIES["warrior"]
	var bar: Variant = state.get("bar")
	if bar is Array:
		for s in mini(6, (bar as Array).size()):
			var oi := int((bar as Array)[s])
			if oi >= 0 and oi < ids.size():
				for ni in abil.size():
					if abil[ni]["id"] == ids[oi]:
						nb[s] = ni
	state["bar"] = nb
	state["bars"] = {}
	state["cls"] = "warrior"
	state["melee_merged"] = true
	if state.has("equip") and old == "rogue":
		var eqd: Dictionary = state["equip"]
		if not (eqd.get("offhand", {}) as Dictionary).is_empty() and not (state.get("talents") is Dictionary and int((state["talents"] as Dictionary).get("sh_dual", 0)) > 0):
			# the off-hand now needs the Dual Wield talent: park the dagger in the bag until then
			if (state["bag"] as Array).size() < 40:
				(state["bag"] as Array).append(eqd["offhand"])
				eqd.erase("offhand")


func _refit_kit() -> void:
	var w: Dictionary = (state.get("equip", {}) as Dictionary).get("weapon", {})
	if w.is_empty():
		return
	var kit: String = Items.CLASS_FOR_WEAPON.get(w["type"], "")
	if kit != "" and kit != String(state["cls"]):
		_set_kit(kit)


func _set_kit(id: String) -> void:
	var bars: Dictionary = state.get("bars", {})
	bars[state["cls"]] = (state.get("bar", [-1, -1, -1, -1, -1, -1]) as Array).duplicate()
	state["bars"] = bars
	state["cls"] = id
	var fresh := not bars.has(id)
	state["bar"] = (bars[id] as Array).duplicate() if not fresh else [-1, -1, -1, -1, -1, -1]
	sync_combat_level(false)
	_apply_gear(false)
	player.setup(id, state["lvl"], false, _tier())
	combat.cooldowns = Combat.fresh_cooldowns()
	if fresh:
		var slot := 0
		var abil: Array = Data.ABILITIES[id]
		for i in abil.size():
			if slot < 6 and ability_locked(i) == "":
				(state["bar"] as Array)[slot] = i
				slot += 1
	_prune_bar()
	ui.build_ability_bar(id)
	save_game()
	ui.refresh_window()
	ui.toast("%s style: %s" % [Data.SKILLS[Data.COMBAT_SKILL[id]]["name"], Data.CLASSES[id]["name"]])


func switch_class(id: String) -> void:
	if online != null:
		ui.toast("You pick a class when you create a character online", Color("e0a080"))
		return
	if id == player.class_id:
		return
	state["cls"] = id
	sync_combat_level(false)
	_swap_weapon_for_class(id)
	_apply_gear(false)
	player.setup(id, state["lvl"], false, _tier())
	combat.cooldowns = Combat.fresh_cooldowns()
	ui.build_ability_bar(id)
	save_game()
	ui.refresh_window()
	ui.toast("You are now a %s" % Data.CLASSES[id]["name"])


func set_level(l: int) -> void:
	if online != null:
		online.send({"t": "dev_level", "level": l})   # the server raises it (development tools)
		return
	skills.set_xp(skills.combat_id(), Data.xp_for_level(l))
	player.setup(state["cls"], state["lvl"], true, _tier())
	save_game()
	ui.toast("Level set to %d" % l)


# ================================================================ progression
## Combat XP (kills, quests) goes into your class's combat skill: Melee, Magic or Ranged.
func gain_xp(n: int) -> void:
	skills.add_xp(skills.combat_id(), n)


## Your "level" is your current combat skill. Called whenever its XP changes.
func sync_combat_level(leveled_up: bool) -> void:
	var cid := skills.combat_id()
	var total := skills.xp(cid)
	var lvl := Data.level_for_xp(total)
	state["lvl"] = lvl
	state["xp"] = total - Data.xp_for_level(lvl)
	state["xp_need"] = Data.xp_needed(lvl) if lvl < Data.MAX_SKILL else 1
	if not leveled_up:
		return
	var res := player.res
	var buffs := player.buffs.duplicate()
	var shield := player.shield
	player.setup(state["cls"], lvl, true, _tier())
	player.res = minf(res, player.res_max) if player.class_id == "warrior" else player.res_max
	player.buffs = buffs
	player.shield = shield
	var unlocked := ""
	for a: Dictionary in Data.ABILITIES[player.class_id]:
		if int(a["lvl"]) == lvl:
			unlocked = a["name"]
	var sk_name: String = Data.SKILLS[cid]["name"]
	ui.chat_levelup(cid, lvl, "New ability: %s" % unlocked if unlocked != "" else "You feel stronger.")
	Sfx.play("level_up")
	_restock_shop()
	combat.ring(player.global_position, 3.0, Color("ffd27a"), 0.6)
	combat.burst(player.global_position + Vector3(0, 1.0, 0), Color("ffd27a"), 26, 6.0, 0.8)


## Testing: every skill to max.
func max_all_skills() -> void:
	if online != null:
		ui.toast("Skill levels are set by the server online", Color("e0a080"))
		return
	for id: String in Data.SKILL_ORDER:
		state["skills"][id] = Data.xp_for_level(Data.MAX_SKILL)
	sync_combat_level(false)
	player.setup(state["cls"], state["lvl"], true, _tier())
	ui.toast("All skills set to %d" % Data.MAX_SKILL)


func collect(kind: String) -> void:
	if kind == "potion":
		state["potions"] = int(state["potions"]) + 1
		ui.toast("+1 Potion")
		return
	var b := _boss()
	state["shards"] = int(state["shards"]) + 1
	ui.toast("+1 %s (%d/3)" % [b["sigil"], mini(int(state["shards"]), 3)])
	if int(state["shards"]) == 3:
		ui.toast("Take them to the altar")
		if not state["runes"][int(state["bi"])]:
			state["runes"][int(state["bi"])] = true
			state["step"] = 1
			_refresh_world()
	_refresh_world()


func drink_potion() -> void:
	if mode != "play" or paused or player.dead:
		return
	if online != null:
		online.send({"t": "use_potion"})
		return
	var greater := crafting.count("greater") > 0
	if int(state.get("potions", 0)) <= 0 and not greater:
		ui.toast("No potions left")
		return
	if player.hp >= player.max_hp:
		ui.toast("Already at full health")
		return
	if greater:
		crafting.take("greater")
	else:
		state["potions"] = int(state["potions"]) - 1
	Sfx.play("potion")
	var heal := player.max_hp * (0.7 if greater else 0.45)
	player.hp = minf(player.max_hp, player.hp + heal)
	combat.float_text(player.global_position + Vector3(0, 2.4, 0), "+%d" % int(heal), Color("7be08a"))
	combat.burst(player.global_position + Vector3(0, 1.0, 0), Color("7be08a"), 14, 3.0, 0.6)


func player_died() -> void:
	combat.auto_attack = false
	mode = "dead"
	player.dead = true
	Sfx.play("death")
	_death_t = 2.4
	ui.show_dead(true)


func _respawn() -> void:
	if online != null:
		online.request_respawn()   # the server revives you; Online switches back to play mode
		_death_t = 1.5
		return
	ui.show_dead(false)
	state["xp"] = int(float(state["xp"]) * 0.75)
	if combat.boss:
		combat.despawn_boss("The Warden returns to its slumber. Your sigils are returned.")
	for e: Enemy in combat.enemies.duplicate():
		if not e.is_boss and combat._flat(e.global_position, world.shrine_pos) < 40.0:
			combat.enemies.erase(e)
			e.queue_free()
	combat.clear_enemy_shots()
	player.dead = false
	player.teleport(world.spawn_point())
	player.hp = player.max_hp
	player.inv_t = 1.5
	player.sta = player.sta_max
	player.buffs.clear()
	player.shield = 0.0
	player.res = player.res_max if Data.CLASSES[player.class_id]["res_start_full"] else 0.0
	rig.snap()
	mode = "play"
	save_game()


func on_boss_defeated(i: int) -> void:
	var b: Dictionary = Data.BOSSES[i]
	state["step"] = 2
	gain_xp(Data.BOSS_COMBAT[i]["xp"])
	state["potions"] = int(state["potions"]) + 2
	ui.set_boss("", 0.0)
	_refresh_world()
	save_game()
	ui.say([["THE WISP", b["win"]]], func() -> void: ui.toast("%s obtained · +2 Potions" % b["trophy"]))


func boss_reset() -> void:
	## the boss went back to sleep: give the sigils back
	state["shards"] = int(state["shards"]) + 3
	ui.set_boss("", 0.0)
	_refresh_world()


func _place_trophy() -> void:
	var placed := _boss()
	state["bi"] = int(state["bi"]) + 1
	state["step"] = 0
	state["shards"] = 0
	Sfx.play("trophy")
	_restock_shop()
	combat.ring(world.shrine_pos, 7.0, Color("ffd27a"), 0.8)
	combat.burst(world.shrine_pos + Vector3(0, 2.5, 0), Color("ffd27a"), 40, 8.0, 1.0, 0.25)
	if int(state["bi"]) >= 4:
		state["done"] = true
		state["bi"] = 3
		player.setup(state["cls"], state["lvl"], true, _tier())
		_refresh_world()
		save_game()
		var lines: Array = []
		for t: String in Data.ENDING:
			lines.append(["THE WISP", t])
		ui.say(lines, func() -> void: ui.toast("Thornvale is at peace"))
		return
	player.setup(state["cls"], state["lvl"], true, _tier())
	if state["runes"][int(state["bi"])]:
		state["step"] = 1
	_refresh_world()
	save_game()
	ui.say([["THE WISP", "The %s settles into its place, and the Ember brightens. You feel sturdier, too." % placed["trophy"]], ["THE WISP", placed["placed"]]])


# ================================================================ save
func save_game() -> void:
	if online != null:
		return
	if (mode != "play" and mode != "dead") or state.is_empty():
		return
	var d := state.duplicate(true)
	d.erase("xp_need")
	var p := player.global_position if mode == "play" else world.spawn_point()
	d["pos"] = [p.x, p.y, p.z]
	d["hp"] = player.hp if mode == "play" else player.max_hp
	d["fog"] = Marshalls.raw_to_base64(world.explored)
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))


func _read_save() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()


# ================================================================ input + tick
func _unhandled_input(event: InputEvent) -> void:
	if mode != "play":
		return
	# Esc closes whatever is open, or opens the menu tab. Nothing pauses the game.
	if event.is_action_pressed("pause"):
		if BankWindow.is_open():
			BankWindow.close()
		elif ui.map_open():
			ui.toggle_map(false)
		elif shop_open:
			toggle_shop()
		elif forge_open:
			toggle_forge()
		elif ui.talents_open():
			ui.toggle_talents(false)
		elif ui.side_tab != "":
			ui.close_side()
		else:
			ui.toggle_side("settings")
		get_viewport().set_input_as_handled()
		return
	if (shop_open or forge_open) and event.is_action_pressed("interact"):
		if shop_open:
			toggle_shop()
		else:
			toggle_forge()
		get_viewport().set_input_as_handled()
		return
	if not ui.dialog_open():
		for pair: Array in [["inventory", "bag"], ["character", "char"], ["skills", "skills"], ["abilities", "abilities"], ["talents", "talents"], ["questbook", "book"], ["settings", "settings"]]:
			if event.is_action_pressed(pair[0]):
				ui.toggle_side(pair[1])
				get_viewport().set_input_as_handled()
				return
	if ui.dialog_open():
		var click: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
		if click or event.is_action_pressed("interact") or event.is_action_pressed("jump") or event.is_action_pressed("ui_accept"):
			ui.advance()
			Sfx.play("dialog")
			_act_block = 0.25
			get_viewport().set_input_as_handled()
		return
	if dev_mode and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1:
			set_flying(not player.flying)
			return
		if event.keycode == KEY_F2:
			dev_panel.toggle()
			return
		if event.keycode == KEY_F3 or event.keycode == KEY_BACKSLASH or (event.keycode == KEY_E and (event.meta_pressed or event.ctrl_pressed)):
			build_editor.toggle()
			get_viewport().set_input_as_handled()
			return
	if ui.map_open() and event is InputEventKey and event.pressed:
		var kc: Key = (event as InputEventKey).keycode
		if kc == KEY_EQUAL or kc == KEY_PLUS or kc == KEY_KP_ADD:
			ui.map_zoom(0.8)
			get_viewport().set_input_as_handled()
			return
		if kc == KEY_MINUS or kc == KEY_KP_SUBTRACT:
			ui.map_zoom(1.25)
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("map"):
		ui.toggle_map(not ui.map_open())
		return
	if ui.map_open():
		return
	if event.is_action_pressed("target_next"):
		cycle_target(-1 if (event as InputEventKey).shift_pressed else 1)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("interact"):
		interact()
	elif event.is_action_pressed("potion"):
		drink_potion()
	elif event.is_action_pressed("food"):
		skills.eat()
	elif event.is_action_pressed("might"):
		skills.drink("might")
	elif event.is_action_pressed("swift"):
		skills.drink("swift")
	else:
		for i in 6:
			if event.is_action_pressed("ability_%d" % (i + 1)):
				combat.cast(i)
				break


func _process(delta: float) -> void:
	if mode != "play":
		rig.input_enabled = false
	if mode == "dead" and not paused:
		ui.update_hud(player, state, quest_info(), combat.cooldowns)
		_death_t -= delta
		if _death_t <= 0.0:
			_respawn()
		return
	if mode != "play":
		return
	world.reveal(player.global_position)
	_auto_close_menus()
	_tutorial_bounds()
	Sfx.music("boss" if combat.boss else BIOME_MUSIC[world.biome_at(player.global_position)])
	_act_block -= delta
	player.can_act = not ui.dialog_open() and not ui.map_open() and _act_block <= 0.0
	player.cam_yaw = rig.yaw
	player.steer = rig.rmb
	player.run_both = rig.run_forward()
	rig.input_enabled = player.can_act and not player.dead
	var it := _nearest_interactable()
	var pk := combat.nearest_pickup()
	var prompt := _prompt_text(it)
	if not pk.is_empty():
		prompt = "[G] Pick up %s" % pk["name"]
	ui.set_prompt(prompt if player.can_act else "")
	_update_atmosphere(delta)
	if dev_mode:
		_dev_tick()
	if target != null and (not has_target() or _flat_dist(target.global_position, player.global_position) > 45.0):
		target = null
	ui.update_hud(player, state, quest_info(), combat.cooldowns)
	if combat.boss:
		ui.set_boss(Data.BOSSES[combat.boss.boss_index]["name"], combat.boss.hp / combat.boss.max_hp)
	_save_t += delta
	if _save_t > 10.0:
		_save_t = 0.0
		save_game()


func cast(i: int) -> void:
	combat.cast(i)


# ================================================================ gear
## Kept for older callers: opens the bag / character tab of the side panel.
func toggle_inventory(part := "both") -> void:
	if mode != "play":
		return
	ui.toggle_side("char" if part == "char" else "bag")


func close_inventory() -> void:
	if ui.side_tab in ["char", "bag"]:
		ui.close_side()


## Called by the UI whenever the side panel opens, closes or changes tab.
func on_side_changed() -> void:
	inv_open = ui.side_tab in ["char", "bag"]
	window = "" if inv_open else ui.side_tab
	if window in ["cooking", "herblore", "crafting", "furnace", "anvil"]:
		_station_pos = player.global_position
	if ui.side_tab != "":
		if shop_open:
			toggle_shop()
		if forge_open:
			toggle_forge()


## The starting lessons are a private "instance": until the player has learned abilities
## (state["tut_safe"], saved per player), they stay inside Wanderer's Rest and nothing spawns.
## With multiplayer this flag decides who shares the camp: nobody else is in it until you're through.
const CAMP_LEASH := 26.0


func _tutorial_bounds() -> void:
	if not bool(state.get("tut_safe", false)) or player.dead:
		return
	var off := Vector3(player.global_position.x - world.camp_pos.x, 0, player.global_position.z - world.camp_pos.z)
	if off.length() > CAMP_LEASH:
		var edge := world.camp_pos + off.normalized() * (CAMP_LEASH - 0.2)
		player.global_position = Vector3(edge.x, player.global_position.y, edge.z)
		player.velocity.x = 0.0
		player.velocity.z = 0.0
		ui.toast("Finish Tam's lessons before you head out.", Color("ffb070"))


## Walk away from the merchant, forge or a crafting station and its panel closes.
func _auto_close_menus() -> void:
	var p := player.global_position
	if shop_open and _flat_dist(p, world.merchant_pos) > 6.5 and _flat_dist(p, world.merchant2_pos) > 6.5 and _flat_dist(p, world.merchant3_pos) > 6.5:
		toggle_shop()
	if forge_open and _flat_dist(p, world.forge_pos) > 6.5:
		toggle_forge()
	if window in ["cooking", "herblore", "crafting", "furnace", "anvil"] and _flat_dist(p, _station_pos) > 5.0:
		ui.close_side()


## Skills, quest book, settings or a crafting station: a tab in the side panel.
func toggle_window(w: String) -> void:
	if mode != "play":
		return
	ui.toggle_side(w)


## A short click in the world (not a drag). Left selects / uses, right also starts attacking.
func _on_world_click(button: int) -> void:
	if mode != "play" or not player.can_act:
		return
	var e := clicker.pick_enemy()
	if e:
		set_target(e)
		if button == MOUSE_BUTTON_RIGHT:
			combat.auto_attack = true
		return
	if clicker.click():
		return
	if button == MOUSE_BUTTON_LEFT:
		target = null
		combat.auto_attack = false


## Tab: next enemy in front of you, nearest first (Shift+Tab goes the other way).
func cycle_target(dir := 1) -> void:
	var fwd := player.forward_vec()
	var cands: Array = []
	for e: Enemy in combat.enemies:
		if e.dead or e.burrowed:
			continue
		var to := e.global_position - player.global_position
		to.y = 0.0
		var d := to.length()
		if d > 28.0:
			continue
		var ang := acos(clampf(fwd.dot(to / maxf(d, 0.01)), -1.0, 1.0))
		if ang > deg_to_rad(110.0):
			continue
		cands.append({"e": e, "score": d + ang * 4.0})
	if cands.is_empty():
		return
	cands.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["score"]) < float(b["score"]))
	var idx := 0
	if has_target():
		for i in cands.size():
			if cands[i]["e"] == target:
				idx = (i + dir + cands.size()) % cands.size()
				break
	elif dir < 0:
		idx = cands.size() - 1
	set_target(cands[idx]["e"])


## Left-clicking a tool says what it is for (the tools work on the world, not in the bag).
const TOOL_HINTS := {
	"wooden_axe": "Stand next to an oak tree and press G to chop it.", "axe": "Stand next to a tree and press G to chop it.",
	"bogiron_axe": "Stand next to a tree and press G to chop it (faster).", "frost_axe": "Stand next to a tree and press G to chop it (fastest).",
	"wooden_pickaxe": "Stand next to a rock and press G to mine it.", "pickaxe": "Stand next to a rock and press G to mine it.",
	"bogiron_pickaxe": "Stand next to a rock and press G to mine it (faster).", "frost_pickaxe": "Stand next to a rock and press G to mine it (fastest).",
	"rod": "Stand at a fishing spot (the ripples in the water) and press G to fish.",
}


## Right-click on a stack in the bag: drink, eat, cut kindling, light a fire.
func use_mat(id: String) -> void:
	if mode != "play" or player.dead:
		return
	if online != null and id not in ["hpot", "greater"]:
		if id in ["minnow", "trout", "eel", "icefin"]:
			online.send({"t": "eat"})
		elif id in ["might", "swift"]:
			online.send({"t": "drink", "potion": id})
		elif id in ["oak", "heartwood"]:
			online.light_fire()
		elif id in TOOL_HINTS:
			ui.toast("%s: %s" % [Data.MATERIALS[id]["name"], TOOL_HINTS[id]])
		else:
			ui.toast("%s: use the Workshop (J) to make things from it" % Data.MATERIALS[id]["name"])
		return
	match id:
		"hpot", "greater":
			drink_potion()
		"might", "swift":
			skills.drink(id)
		"minnow", "trout", "eel", "icefin":
			skills.eat(id)
		"oak", "heartwood":
			skills.make_kindling(id)
		"kindling_oak", "kindling_heart":
			skills.light_fire(id)
		_:
			var d: Dictionary = Data.MATERIALS[id]
			ui.toast("%s: %s" % [d["name"], d.get("desc", "A crafting material.")])
	ui.refresh_inventory()


## At an anvil (the town's, or Hilde's at the forge)?
func near_anvil() -> bool:
	var p := player.global_position
	return _flat_dist(p, world.anvil_pos) < Skills.STATION_RANGE + 0.6


## Recipes at a station. The anvil also makes gear for your class (masterwork pieces need an Ember Shard).
func recipes_for(station: String) -> Array:
	var base: Array = Data.RECIPES.get(station, [])
	if (station == "anvil" or station == "crafting") and player != null:
		var gear: Array = []
		for r: Dictionary in Data.gear_recipes(player.class_id):
			if r["station"] == station:
				gear.append(r)
		return base + gear
	return base


## Which recipe sets does using `a` on `b` open? Returns {"station", "target"} or {}.
func combo_for(a: String, b: String) -> Dictionary:
	for st: String in Data.COMBO_TOOLS:
		var tools: Array = Data.COMBO_TOOLS[st]
		var tgt := ""
		if a in tools and not (b in tools):
			tgt = b
		elif b in tools and not (a in tools):
			tgt = a
		else:
			continue
		for r: Dictionary in recipes_for(st):
			if (r["cost"] as Dictionary).has(tgt) and (tgt == "ember" or not r.get("master", false)):
				return {"station": st, "target": tgt}
	return {}


## Does this material take part in any item-on-item recipe (so it gets a "Use" option)?
func combo_item(id: String) -> bool:
	if id == "flint_steel" or (online != null and id in ["oak", "heartwood"]):
		return true   # a log and Flint and Steel make a fire (use one on the other)
	for st: String in Data.COMBO_TOOLS:
		if id in (Data.COMBO_TOOLS[st] as Array):
			return true
		for r: Dictionary in recipes_for(st):
			if (r["cost"] as Dictionary).has(id):
				return true
	return false


## Use one bag item on another (knife on twigs, vial on a herb, hammer on a bar).
func use_on(a: String, b: String) -> void:
	if mode != "play" or player.dead:
		return
	if a == "flint_steel" or b == "flint_steel":
		var other := b if a == "flint_steel" else a
		if online != null and other in ["oak", "heartwood"]:
			online.light_fire()
		elif other in ["kindling_oak", "kindling_heart"]:
			use_mat(other)
		else:
			ui.chat_say("Nothing interesting happens. Use the Flint and Steel on a log.", Color("a89cb8"))
		return
	var c := combo_for(a, b)
	if c.is_empty():
		ui.chat_say("Nothing interesting happens.", Color("a89cb8"))
		return
	if c["station"] == "anvil" and not near_anvil():
		ui.chat_say("You need to be at an anvil to forge.", Color("e0a080"))
		Sfx.play("ui_click")
		return
	ui.open_combo(c["station"], c["target"])


# ---------------------------------------------------------------- talents
## Talent ranks count everywhere: every tree is open to every character. Points come from each combat skill
## on its own (one per 2 levels of Melee, Magic or Ranged) and are spent in that skill's trees.
func talent_rank(id: String) -> int:
	var t: Variant = state.get("talents")
	if t is Dictionary:
		return int((t as Dictionary).get(id, 0))
	return 0


func has_talents() -> bool:
	return true


## Melee, Magic or Ranged: the skill whose points pay for talent `id` (its tree's owner).
func talent_style(id: String) -> String:
	return String(Data.COMBAT_SKILL.get(Data.talent_owner(id), "melee"))


## The combat style you fight in now (the weapon in your hand, online).
func active_style() -> String:
	return String(Data.COMBAT_SKILL.get(player.class_id, "melee"))


## Your level in each combat skill. Online these come from the server; offline you only train the one you chose.
func combat_levels() -> Dictionary:
	if online != null and online.started:
		return {"melee": online.skill_level("melee"), "magic": online.skill_level("magic"), "ranged": online.skill_level("ranged")}
	var out := {"melee": 1, "magic": 1, "ranged": 1}
	out[active_style()] = int(state.get("lvl", player.level))
	return out


func skill_level_of(style: String) -> int:
	return int(combat_levels().get(style, 1))


## One point every 2 levels of the skill ("" = the style in your hand).
func talent_points_total(style := "") -> int:
	return skill_level_of(style if style != "" else active_style()) / 2


func talent_points_spent(tree := "", style := "") -> int:
	var n := 0
	var t: Variant = state.get("talents")
	if t is Dictionary:
		for cls: String in Data.TALENTS:
			if style != "" and String(Data.COMBAT_SKILL.get(cls, "melee")) != style:
				continue
			for node: Dictionary in Data.TALENTS[cls]:
				if tree == "" or node["tree"] == tree:
					n += int((t as Dictionary).get(node["id"], 0))
	return n


func talent_points_left(style := "") -> int:
	var st := style if style != "" else active_style()
	return talent_points_total(st) - talent_points_spent("", st)


## "" if you can put a point in it, otherwise why not.
func talent_block(id: String) -> String:
	var node: Dictionary = Data.talent_node(id)
	if node.is_empty():
		return "Not available"
	if talent_rank(id) >= int(node["max"]):
		return "Maxed"
	if talent_points_left(talent_style(id)) <= 0:
		return "No %s talent points left" % Data.SKILLS[talent_style(id)]["name"]
	if node.has("req") and talent_rank(String(node["req"])) < 1:
		return "Needs %s first" % Data.talent_node(String(node["req"]))["name"]
	var need: int = int(node["tier"]) * 2
	if talent_points_spent(node["tree"]) < need:
		return "Spend %d points in this tree first" % need
	return ""


func learn_talent(id: String) -> void:
	if online != null:
		online.send({"t": "learn_talent", "id": id})
		return
	var why := talent_block(id)
	if why != "":
		ui.toast(why)
		return
	if not (state.get("talents") is Dictionary):
		state["talents"] = {}
	state["talents"][id] = talent_rank(id) + 1
	player.refresh_stats()
	var node: Dictionary = Data.talent_node(id)
	if node.has("ability"):
		ui.toast("Learned %s. Open Abilities (N) to put it on your bar." % node["name"])
	Sfx.play("level_up" if node.has("ability") else "ui_click", Vector3.INF, -8.0)
	ui.refresh_window()


## Take one point back out of a talent (right-click). Refused if another talent still depends on it.
func unlearn_talent(id: String) -> void:
	if online != null:
		online.send({"t": "unlearn_talent", "id": id})
		return
	var node: Dictionary = Data.talent_node(id)
	var r := talent_rank(id)
	if node.is_empty() or r <= 0:
		return
	var t: Dictionary = state["talents"]
	# would anything left standing lose its footing?
	t[id] = r - 1
	var bad := ""
	for cls: String in Data.TALENTS:
		for n: Dictionary in Data.TALENTS[cls]:
			var nr := talent_rank(String(n["id"]))
			if nr <= 0:
				continue
			if n.has("req") and talent_rank(String(n["req"])) < 1:
				bad = "%s needs it" % n["name"]
				break
			if talent_points_spent(n["tree"]) < int(n["tier"]) * 2:
				bad = "%s needs those points" % n["name"]
				break
		if bad != "":
			break
	if bad != "":
		t[id] = r
		ui.toast("Can't refund: " + bad)
		return
	if r - 1 <= 0:
		t.erase(id)
	player.refresh_stats()
	_prune_bar()
	Sfx.play("ui_click", Vector3.INF, -6.0)
	ui.build_ability_bar(player.class_id)
	ui.refresh_window()


## Refund the points of one skill ("melee", "magic" or "ranged"); the other skills' talents stay as they are.
func reset_talents(style := "") -> void:
	var st := style if style != "" else active_style()
	if online != null:
		online.send({"t": "respec", "style": st})
		return
	var tal: Dictionary = state.get("talents", {})
	for cls: String in Data.TALENTS:
		if String(Data.COMBAT_SKILL.get(cls, "melee")) != st:
			continue
		for node: Dictionary in Data.TALENTS[cls]:
			tal.erase(node["id"])
	state["talents"] = tal
	player.refresh_stats()
	_prune_bar()
	Sfx.play("ui_click", Vector3.INF, -6.0)
	ui.toast("%s talents reset. Points refunded." % Data.SKILLS[st]["name"])
	ui.build_ability_bar(player.class_id)
	ui.refresh_window()


## Take abilities you can no longer use off the bar.
func _prune_bar() -> void:
	var bar: Variant = state.get("bar")
	if bar is Array:
		for s in (bar as Array).size():
			var idx := int((bar as Array)[s])
			if idx >= 0 and ability_locked(idx) != "":
				(bar as Array)[s] = -1


## "" if the ability is usable, otherwise the short reason shown on the bar.
func ability_view(a: Dictionary) -> Dictionary:
	var ms: Variant = Data.MORPHS.get(a["id"])
	if ms is Array:
		for o: Dictionary in ms:
			if talent_rank(String(o["talent"])) > 0:
				var v := a.duplicate()
				v.merge(o["over"], true)
				return v
	return a


func ability_locked(idx: int) -> String:
	var a: Dictionary = Data.ABILITIES[player.class_id][idx]
	if player.level < int(a["lvl"]):
		return "LV %d" % int(a["lvl"])
	if a.has("talent") and talent_rank(a["talent"]) <= 0:
		return "TALENT"
	return ""


# ---------------------------------------------------------------- action bar
func bar_ability(slot: int) -> int:
	var bar: Variant = state.get("bar")
	if not (bar is Array) or slot < 0 or slot >= (bar as Array).size():
		return -1
	return int((bar as Array)[slot])


func ability_slot(idx: int) -> int:
	var bar: Variant = state.get("bar")
	if bar is Array:
		for i in (bar as Array).size():
			if int((bar as Array)[i]) == idx:
				return i
	return -1


## Put an ability in a chosen bar slot (0-5). Choosing the slot it is already in clears it; an ability already
## elsewhere on the bar moves, and whatever was in the slot is replaced.
func set_bar_slot(idx: int, slot: int) -> void:
	if not (state.get("bar") is Array):
		state["bar"] = [-1, -1, -1, -1, -1, -1]
	var bar: Array = state["bar"]
	var a: Dictionary = Data.ABILITIES[player.class_id][idx]
	if ability_locked(idx) != "":
		ui.toast("%s unlocks at level %d" % [a["name"], a["lvl"]])
		return
	if int(bar[slot]) == idx:
		bar[slot] = -1
	else:
		var cur := ability_slot(idx)
		if cur >= 0:
			bar[cur] = -1
		bar[slot] = idx
		quests.notify("bar", "any", 1)
	Sfx.play("ui_click", Vector3.INF, -6.0)
	ui.build_ability_bar(player.class_id)
	ui.refresh_window()
	_bar_edited()


## Online, the server keeps your bars with your character.
func _bar_edited() -> void:
	if online != null:
		online.save_bars()


## Put an ability (index into your class list) on the first free slot, or take it off if it's already there.
func toggle_on_bar(idx: int) -> void:
	if not (state.get("bar") is Array):
		state["bar"] = [-1, -1, -1, -1, -1, -1]
	var bar: Array = state["bar"]
	var cur := ability_slot(idx)
	if cur >= 0:
		bar[cur] = -1
	else:
		var a: Dictionary = Data.ABILITIES[player.class_id][idx]
		if player.level < int(a["lvl"]):
			ui.toast("%s unlocks at level %d" % [a["name"], a["lvl"]])
			return
		var free := bar.find(-1)
		if free < 0:
			ui.toast("Your bar is full. Right-click a slot to clear it.")
			return
		bar[free] = idx
	Sfx.play("ui_click", Vector3.INF, -6.0)
	if ability_slot(idx) >= 0:
		quests.notify("bar", "any", 1)
	ui.build_ability_bar(player.class_id)
	ui.refresh_window()
	_bar_edited()


func clear_bar_slot(slot: int) -> void:
	var bar: Variant = state.get("bar")
	if bar is Array and slot >= 0 and slot < (bar as Array).size() and int((bar as Array)[slot]) >= 0:
		(bar as Array)[slot] = -1
		Sfx.play("ui_click", Vector3.INF, -6.0)
		ui.build_ability_bar(player.class_id)
		ui.refresh_window()
		_bar_edited()


func has_target() -> bool:
	return target != null and is_instance_valid(target) and not target.dead


func set_target(e: Enemy) -> void:
	target = e   # online: Online notices and tells the server


func set_dev_mode(on: bool) -> void:
	dev_mode = on
	if not on:
		set_flying(false)
	ui.toast("Dev mode %s" % ("on" if on else "off"))


func set_flying(on: bool) -> void:
	if on and not dev_mode:
		return
	if online != null:
		if on and not online.server_dev:
			ui.toast("This server has its development tools turned off", Color("e0a080"))
			return
		online.send({"t": "dev_fly", "on": on})
	player.flying = on
	if on:
		player.velocity = Vector3.ZERO
	ui.toast("Flying %s" % ("on" if on else "off"))


## Dev mode: jump to a world position (above the ground when flying).
func dev_teleport(pos: Vector3) -> void:
	if not dev_mode:
		return
	if online != null:
		if not online.server_dev:
			ui.toast("This server has its development tools turned off", Color("e0a080"))
			return
		online.send({"t": "dev_teleport", "x": pos.x, "z": pos.z})   # the server moves us, then we follow it
		ui.toast("Teleported")
		return
	var y := world.height_at(pos.x, pos.z)
	if bool(state.get("tut_safe", false)) and Vector2(pos.x - world.camp_pos.x, pos.z - world.camp_pos.z).length() > CAMP_LEASH:
		state["tut_safe"] = false      # the tutorial leash would drag you straight back to camp
		daynight.frozen = false
	player.teleport(Vector3(pos.x, y + (6.0 if player.flying else 1.5), pos.z))
	ui.toast("Teleported")


## Dev mode: fill in whatever the current objectives need.
func _dev_tick() -> void:
	if state.is_empty():
		return
	if int(state.get("gold", 0)) < 9999999:
		state["gold"] = 9999999   # dev mode: unlimited gold
	if state.get("done", false):
		return
	var step := int(state["step"])
	var bi := int(state["bi"])
	if step == 0:
		state["runes"][bi] = true
		state["step"] = 1
		_refresh_world()
	if int(state["step"]) == 1 and int(state["shards"]) < 3 and combat.boss == null:
		state["shards"] = 3
		_refresh_world()
	for q: Dictionary in Data.SIDE_QUESTS:
		var id: String = q["id"]
		if quests.status(id) == "active":
			var st: Dictionary = quests._qs(id)
			st["progress"] = int(quests.current(id)["count"])


func menu_open() -> bool:
	return ui.dialog_open() or ui.map_open()


func bag_size() -> int:
	return BAG_SIZE


## Materials live in the bag as stacks: [{id, count}] in display order, STACK_MAX per slot.
func mat_stacks() -> Array:
	var out: Array = []
	for k: String in Data.MAT_ORDER:
		var n := crafting.held(k)
		while n > 0:
			var c := mini(n, Data.STACK_MAX)
			out.append({"id": k, "count": c})
			n -= c
	return out


func mat_slots() -> int:
	var n := 0
	for k: String in Data.MAT_ORDER:
		n += ceili(float(crafting.held(k)) / float(Data.STACK_MAX))
	return n


func bag_used() -> int:
	return (state.get("bag", []) as Array).size() + mat_slots()


func can_take_item() -> bool:
	return bag_used() < bag_size()


## How many more of a material fit in the bag right now.
func mat_room(mat: String) -> int:
	var cur := crafting.held(mat)
	var free := maxi(0, bag_size() - bag_used())
	return maxi(0, (ceili(float(cur) / float(Data.STACK_MAX)) + free) * Data.STACK_MAX - cur)


## Would all of these materials fit (extra_free = slots about to be freed)?
func can_hold(add: Dictionary, extra_free := 0) -> bool:
	var free := bag_size() - bag_used() + extra_free
	var need := 0
	for k: String in add:
		var cur := crafting.held(k)
		need += ceili(float(cur + int(add[k])) / float(Data.STACK_MAX)) - ceili(float(cur) / float(Data.STACK_MAX))
	return need <= free


## Drag a bag slot out of the bag: it lands on the ground in front of you.
func drop_from_bag(idx: int, mat: String, n: int) -> void:
	if mode != "play" or player.dead:
		return
	if online != null:
		online.send({"t": "drop_mat", "mat": mat, "n": n} if mat != "" else {"t": "drop_item", "idx": idx})
		return
	var pos := player.global_position + player.forward_vec() * 1.3
	if mat != "":
		var have := crafting.held(mat)
		n = mini(n, have)
		if n <= 0:
			return
		state["mats"][mat] = have - n
		combat.drop_loot(pos, {"gold": 0, "mats": {mat: n}})
		ui.toast("Dropped %d %s" % [n, Data.MATERIALS[mat]["name"]])
	else:
		var bag: Array = state["bag"]
		if idx < 0 or idx >= bag.size():
			return
		var item: Dictionary = bag[idx]
		bag.remove_at(idx)
		combat._drop_item(pos, item)
		ui.toast("Dropped %s" % item["name"])
	Sfx.play("smoke", Vector3.INF, -8.0)
	ui.refresh_inventory()


## "I'm stuck": back to the shrine (not while fighting).
func unstick() -> void:
	if mode != "play" or player.dead:
		return
	if player.combat_t < 6.0:
		ui.toast("You can't do that in a fight")
		return
	player.teleport(world.spawn_point() + Vector3(0, 0.5, 0))
	rig.snap()
	ui.toast("Back at the shrine")


func collect_item(item: Dictionary) -> void:
	(state["bag"] as Array).append(item)
	Sfx.play("loot_rare" if int(item["rarity"]) >= 2 else "loot", Vector3.INF, -3.0)
	ui.toast_item(item)
	ui.refresh_inventory()


func _usable_equipment() -> Dictionary:
	var out := {}
	var eq: Dictionary = state.get("equip", {})
	for slot: String in eq:
		var it: Dictionary = eq[slot]
		if slot == "offhand" and talent_rank("sh_dual") <= 0 and String(it.get("type", "")) != "shield":
			continue
		if not it.is_empty() and Items.can_equip(it, state["cls"]):
			out[slot] = it
	return out


func _apply_gear(refresh := true) -> void:
	var eq := _usable_equipment()
	# online, this runs on every inventory update: only rebuild the character model when what you wear changed, or it flickers
	# and restarts the gathering pose each time you pick something up
	var same: bool = online != null and player.equipped == eq
	player.gear = Items.totals(eq)
	player.equipped = eq
	if refresh:
		player.refresh_stats()
		if not same:
			player.refresh_look()


func equip_from_bag(idx: int) -> void:
	if online != null:
		online.send({"t": "equip", "idx": idx})
		return
	var bag: Array = state["bag"]
	if idx < 0 or idx >= bag.size():
		return
	var item: Dictionary = bag[idx]
	if not Items.can_equip(item, state["cls"]):
		var who: String = Items.CLASS_FOR_WEAPON.get(item["type"], "")
		if who == "":
			for k: String in Items.ARMOR_FOR:
				if Items.ARMOR_FOR[k] == item.get("armor", ""):
					who = k
		ui.toast("Only %ss can use that" % Data.CLASSES[who]["name"])
		Sfx.play("ui_click")
		return
	var slot: String = item["slot"]
	var eq: Dictionary = state["equip"]
	# daggers dual wield: a second one-hander goes to the off-hand when the main hand is taken
	if slot == "weapon" and talent_rank("sh_dual") > 0 and item["type"] in ["sword", "dagger", "shortsword"] and not eq.get("weapon", {}).is_empty() and eq.get("offhand", {}).is_empty():
		slot = "offhand"
	var old: Dictionary = eq.get(slot, {})
	bag.remove_at(idx)
	if not old.is_empty():
		bag.insert(idx, old)
	eq[slot] = item
	Sfx.play("equip")
	_apply_gear()
	if slot == "weapon":
		_refit_kit()
	ui.refresh_inventory()


func unequip(slot: String) -> void:
	if online != null:
		online.send({"t": "unequip", "slot": slot})
		return
	var eq: Dictionary = state["equip"]
	if not eq.has(slot):
		return
	if not can_take_item():
		ui.toast("Your bag is full")
		return
	(state["bag"] as Array).append(eq[slot])
	eq.erase(slot)
	Sfx.play("ui_click")
	_apply_gear()
	ui.refresh_inventory()


func discard(idx: int) -> void:
	if online != null:
		online.send({"t": "discard", "idx": idx})
		return
	var bag: Array = state["bag"]
	if idx < 0 or idx >= bag.size():
		return
	var item: Dictionary = bag[idx]
	bag.remove_at(idx)
	Sfx.play("smoke", Vector3.INF, -8.0)
	ui.toast("Discarded %s" % item["name"])
	ui.refresh_inventory()


func sort_bag() -> void:
	if online != null:
		online.send({"t": "sort_bag"})
		return
	state.erase("bag_pos")
	var bag: Array = state["bag"]
	bag.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var sa := Items.SLOTS.find(a["slot"])
		var sb := Items.SLOTS.find(b["slot"])
		if sa != sb:
			return sa < sb
		if int(a["rarity"]) != int(b["rarity"]):
			return int(a["rarity"]) > int(b["rarity"])
		return int(a["ilvl"]) > int(b["ilvl"]))
	Sfx.play("ui_click")
	ui.refresh_inventory()


func _swap_weapon_for_class(cls: String) -> void:
	## when switching class, trade the equipped weapon for the best usable one in the bag
	var eq: Dictionary = state["equip"]
	var bag: Array = state["bag"]
	var cur: Dictionary = eq.get("weapon", {})
	if not cur.is_empty() and Items.CLASS_FOR_WEAPON.get(cur["type"], "") == cls:
		return
	var best := -1
	for i in bag.size():
		var it: Dictionary = bag[i]
		if it["slot"] == "weapon" and Items.CLASS_FOR_WEAPON.get(it["type"], "") == cls:
			if best == -1 or float(it["stats"].get("dmg", 0)) > float(bag[best]["stats"].get("dmg", 0)):
				best = i
	var fresh: Dictionary
	if best >= 0:
		fresh = bag[best]
		bag.remove_at(best)
	else:
		fresh = Items.starter_kit(cls)[0]
	if not cur.is_empty() and bag.size() < bag_size():
		bag.append(cur)
	eq["weapon"] = fresh


# ================================================================ forge
func toggle_forge() -> void:
	if mode != "play" or paused:
		return
	forge_open = not forge_open
	if forge_open:
		ui.close_side()
	ui.show_forge(forge_open)
	Sfx.play("ui_open" if forge_open else "ui_close", Vector3.INF, -4.0)
	if not forge_open:
		_act_block = 0.2


## ["equip", slot] or ["bag", index] -> the item Dictionary (or {} if gone)
func item_ref(ref: Array) -> Dictionary:
	if ref.size() != 2:
		return {}
	if ref[0] == "equip":
		return (state["equip"] as Dictionary).get(ref[1], {})
	var bag: Array = state["bag"]
	var i: int = ref[1]
	return bag[i] if i >= 0 and i < bag.size() else {}


# ================================================================ gold + shop
func add_gold(n: int, at := Vector3.INF) -> void:
	state["gold"] = int(state.get("gold", 0)) + n
	if at != Vector3.INF:
		combat.float_text(at + Vector3(0, 1.8, 0), "+%dg" % n, Color("ffd27a"))
	Sfx.play("loot", Vector3.INF, -12.0, 0.15)


func _restock_shop() -> void:
	var stock: Array = []
	var lvl := int(state.get("lvl", 1))
	var cls: String = state.get("cls", "warrior")
	for i in Data.SHOP_SLOTS:
		var slot := "weapon" if i == 0 else ""
		var it := Items.generate(mini(lvl + randi() % 3, 20), cls, Items.roll_rarity([0.0, 55.0, 35.0, 9.0, 1.0]), slot)
		if slot == "weapon":
			it["type"] = Items.WEAPON_FOR[cls]
		stock.append(it)
	state["shop"] = stock


func toggle_shop() -> void:
	if mode != "play" or paused:
		return
	if online != null and not shop_open:
		online.send({"t": "open_shop"})   # the shop window opens when the server sends the stock
		return
	shop_open = not shop_open
	if shop_open:
		ui.close_side()
	ui.show_shop(shop_open)
	Sfx.play("ui_open" if shop_open else "ui_close", Vector3.INF, -4.0)
	if shop_open:
		ui.toast(Data.MERCHANT_LINES[randi() % Data.MERCHANT_LINES.size()], Color("f1e8d4"))
	else:
		_act_block = 0.2


func _spend(cost: int) -> bool:
	if int(state["gold"]) < cost:
		ui.toast("You need %d more gold" % (cost - int(state["gold"])))
		Sfx.play("ui_click")
		return false
	state["gold"] = int(state["gold"]) - cost
	return true


func buy_item(idx: int) -> void:
	if online != null:
		online.send({"t": "buy_item", "idx": idx})
		return
	var stock: Array = state["shop"]
	if idx < 0 or idx >= stock.size():
		return
	if not can_take_item():
		ui.toast("Your bag is full")
		return
	var item: Dictionary = stock[idx]
	if not _spend(Data.sell_price(item) * 4):
		return
	stock.remove_at(idx)
	(state["bag"] as Array).append(item)
	Sfx.play("loot_rare" if int(item["rarity"]) >= 2 else "loot")
	ui.refresh_shop()


func buy_potion() -> void:
	if online != null:
		online.send({"t": "buy_potion"})
		return
	if mat_room("hpot") < 1:
		ui.toast("Your bag is full", Color("e0a080"))
		return
	if not _spend(Data.potion_price(int(state["lvl"]))):
		return
	state["potions"] = int(state["potions"]) + 1
	Sfx.play("pickup_potion")
	ui.refresh_shop()


func sell_item(idx: int) -> void:
	if online != null:
		online.send({"t": "sell", "idx": idx})
		return
	var bag: Array = state["bag"]
	if idx < 0 or idx >= bag.size():
		return
	var item: Dictionary = bag[idx]
	bag.remove_at(idx)
	state["gold"] = int(state["gold"]) + Data.sell_price(item)
	Sfx.play("loot", Vector3.INF, -4.0)
	ui.refresh_shop()


func sell_commons() -> void:
	if online != null:
		online.send({"t": "sell_commons"})
		return
	var bag: Array = state["bag"]
	var total := 0
	for i in range(bag.size() - 1, -1, -1):
		if int(bag[i]["rarity"]) == 0:
			total += Data.sell_price(bag[i])
			bag.remove_at(i)
	if total == 0:
		ui.toast("No Common items to sell")
		return
	state["gold"] = int(state["gold"]) + total
	Sfx.play("loot")
	ui.toast("Sold Common items for %d gold" % total)
	ui.refresh_shop()


func paid_restock() -> void:
	if online != null:
		online.send({"t": "restock"})
		return
	if not _spend(Data.restock_price(int(state["lvl"]))):
		return
	_restock_shop()
	Sfx.play("equip")
	ui.refresh_shop()


# ================================================================ story
func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _nearest_interactable() -> Dictionary:
	var p := player.global_position
	var cv := world.caves.nearest(p)
	if not cv.is_empty():
		return cv
	var npc := quests.nearest()
	if npc != "":
		return {"kind": "npc", "id": npc}
	var cr := crafting.nearest()
	if not cr.is_empty():
		return cr
	if online != null:
		var sn: Dictionary = online.nearest_node()
		if not sn.is_empty():
			return sn
		var bk: Dictionary = online.nearest_bank()
		if not bk.is_empty():
			return bk
	if _flat_dist(p, world.slayer_pos) < 3.2:
		return {"kind": "varka"}
	if _flat_dist(p, world.rack_pos) < 3.0:
		return {"kind": "rack"}
	var d_fu := _flat_dist(p, world.furnace_pos)
	var d_an := _flat_dist(p, world.anvil_pos)
	if d_fu < Skills.STATION_RANGE + 0.6 and d_fu <= d_an:
		return {"kind": "furnace"}
	if d_an < Skills.STATION_RANGE:
		return {"kind": "anvil"}
	for fp: Vector3 in skills.all_fires():
		if _flat_dist(p, fp) < Skills.STATION_RANGE:
			return {"kind": "fire"}
	for fs: Dictionary in skills.fish_spots:
		if _flat_dist(p, fs["pos"]) < Skills.FISH_RANGE:
			return {"kind": "fish", "spot": fs}
	if _flat_dist(p, world.shrine_pos) < 7.5:
		return {"kind": "shrine"}
	for i in 4:
		if _flat_dist(p, world.rune_pos[i]) < 3.2:
			return {"kind": "rune", "i": i}
		if _flat_dist(p, world.altar_pos[i]) < 5.0:
			return {"kind": "altar", "i": i}
	return {}


func _boss() -> Dictionary:
	return Data.BOSSES[int(state["bi"])]


func _prompt_text(it: Dictionary) -> String:
	if it.is_empty():
		return ""
	var b := _boss()
	var bi := int(state["bi"])
	var step := int(state["step"])
	match it["kind"]:
		"cave":
			return "[G] Enter %s" % world.caves.name_of(it["i"])
		"cave_exit":
			return "[G] Leave the cave"
		"npc":
			return quests.prompt(it["id"])
		"snode", "sfire":
			return "[G] " + online.node_prompt(it)
		"bank":
			return "[G] Open the bank"
		"forge", "node":
			return crafting.prompt(it)
		"varka":
			var t := skills.task()
			if t.is_empty():
				return "[G] Ask %s for a Slayer task" % Data.SLAYER_NAME
			return "[G] Talk to %s" % Data.SLAYER_NAME
		"rack":
			return "[G] Take the bow and staff" if not bool(state.get("rack", false)) else "The rack is empty"
		"furnace":
			return "[G] Smelt ore (Furnace)"
		"anvil":
			return "[G] Anvil (use a hammer on a bar)"
		"fire":
			return "[G] Cook (Cooking)"
		"fish":
			var f: Dictionary = (it["spot"] as Dictionary)["fish"]
			var need := "" if skills.level("fishing") >= int(f["lvl"]) else "  (needs Fishing %d)" % f["lvl"]
			return "[G] Fish for %s%s" % [String(Data.MATERIALS[f["raw"]]["name"]).trim_prefix("Raw "), need]
		"shrine":
			return "[G] Place the %s" % b["trophy"] if (not state["done"] and step == 2) else "[G] Speak with the Wisp"
		"rune":
			return "[G] Read the runestone"
		"altar":
			var i: int = it["i"]
			if combat.boss:
				return ""
			if i < bi or state["done"]:
				return "This altar is quiet now"
			if i > bi:
				return "The altar is cold. Another Warden comes first"
			if step == 2:
				return "The Warden is gone"
			return "[G] Offer 3 %ss" % b["sigil"] if int(state["shards"]) >= 3 else "Needs 3 %ss (%d/3)" % [b["sigil"], state["shards"]]
	return ""


## The camp's weapon rack: a worn bow and staff, so every fighting style is within reach of the first lessons.
func _take_rack() -> void:
	if bool(state.get("rack", false)):
		ui.toast("The rack is empty")
		return
	if (state["bag"] as Array).size() > 36:
		ui.toast("Your bag is full")
		return
	for cid: String in ["hunter", "mage"]:
		var wp: Dictionary = Items.starter_kit(cid)[0]
		collect_item(wp)
	state["rack"] = true
	save_game()
	ui.say([["TAM", "Take them. Equip one from your bag (I) and you fight that way: the bow shoots, the staff casts. Your sword is still there when you want it."]])


func interact() -> void:
	if not player.can_act or player.dead:
		return
	var pk := combat.nearest_pickup()
	if not pk.is_empty():
		combat.take(pk)
		return
	interact_with(_nearest_interactable())


## What the hover label says for something under the mouse ("" = nothing to do).
func click_label(it: Dictionary) -> String:
	if it.is_empty():
		return ""
	if it["kind"] == "pickup":
		return "Pick up %s" % (it["pickup"] as Dictionary)["name"]
	return _prompt_text(it).trim_prefix("[G] ")


func interact_with(it: Dictionary) -> void:
	if it.is_empty() or not player.can_act or player.dead:
		return
	if online != null and it["kind"] in ["snode", "sfire"]:
		online.use_node(it)
		return
	if online != null and it["kind"] in ["furnace", "anvil", "fire"]:
		# the game's own windows, in the chat box (the server does the making)
		if it["kind"] == "anvil":
			ui.chat_say("Use a hammer on a bar from your bag to forge here.", Color("e8c070"))
		else:
			toggle_window("furnace" if it["kind"] == "furnace" else "cooking")
		return
	if online != null and it["kind"] == "bank":
		if BankWindow.is_open():
			BankWindow.close()
		else:
			online.send({"t": "open_bank"})   # the window opens when the server sends the bank
		return
	if online != null and it["kind"] == "varka":
		online.talk("varka")
		return
	if online != null and it["kind"] in ["node", "fish", "rack", "cave", "cave_exit"]:
		ui.toast("That isn't available in the online version yet", Color("e0a080"))
		return
	var b := _boss()
	var step := int(state["step"])
	match it["kind"]:
		"cave":
			world.caves.enter(it["i"])
		"cave_exit":
			world.caves.leave()
		"npc":
			if it["id"] == "merchant" or it["id"] == "merchant2" or it["id"] == "merchant3":
				quests.notify("talk", "merchant")
				ui.set_shop_keeper(Data.APOTHECARY_NAME if it["id"] == "merchant3" else Data.MERCHANT_NAME, "hermit" if it["id"] == "merchant3" else "merchant")
				toggle_shop()
			else:
				quests.talk(it["id"])
		"forge":
			quests.notify("talk", "smith")
			toggle_forge()
		"node":
			skills.start_node(it["node"])
		"fish":
			skills.start_fish(it["spot"])
		"varka":
			skills.talk_varka()
		"rack":
			_take_rack()
		"furnace":
			toggle_window("furnace")
		"anvil":
			ui.chat_say("Use a hammer on a bar from your bag to forge here.", Color("e8c070"))
		"fire":
			toggle_window("cooking")
		"shrine":
			quests.notify("talk", "wisp")
			if not state["done"] and step == 2:
				_place_trophy()
				return
			if state["done"]:
				ui.say([["THE WISP", "The Ember is whole. Rest as long as you like, keeper."]])
				return
			var hint := ""
			if step == 0:
				hint = "Follow the old road %s and find the runestone. %s waits beyond it." % [world.boss_dir(Data.BOSSES.find(b)), b["name"]]
			elif int(state["shards"]) >= 3:
				hint = "You have the sigils. Take them to the altar %s of here." % world.boss_dir(Data.BOSSES.find(b))
			else:
				hint = "Hunt the creatures of %s for %ss. You have %d of 3." % [Data.BIOME_NAMES[b["biome"]], b["sigil"], state["shards"]]
			if player.level < int(b["rec"]):
				hint += " You may want to be level %d first." % b["rec"]
			ui.say([["THE WISP", hint]])
		"rune":
			var i: int = it["i"]
			var r: Dictionary = Data.BOSSES[i]
			ui.say([["RUNESTONE", r["rune"]]], func() -> void: _read_rune(i))
		"altar":
			var ai: int = it["i"]
			if combat.boss or state["done"] or ai != int(state["bi"]) or step == 2:
				return
			if int(state["shards"]) < 3:
				ui.toast("You need 3 %ss" % b["sigil"])
				return
			state["runes"][ai] = true
			state["step"] = 1
			state["shards"] = int(state["shards"]) - 3
			combat.summon_boss(ai)
			_refresh_world()


func _read_rune(i: int) -> void:
	var runes: Array = state["runes"]
	if runes[i]:
		return
	runes[i] = true
	Sfx.play("rune")
	if i == int(state["bi"]) and int(state["step"]) == 0 and not state["done"]:
		state["step"] = 1
		ui.toast("Altar marked on your map")
	_refresh_world()
	save_game()


func _refresh_world() -> void:
	var runes: Array = state.get("runes", [false, false, false, false])
	var bi := int(state.get("bi", 0))
	var done: bool = state.get("done", false)
	for i in 4:
		if runes[i]:
			world.set_rune_state(i, "read")
		elif i == bi and int(state.get("step", 0)) == 0 and not done:
			world.set_rune_state(i, "glow")
		else:
			world.set_rune_state(i, "dim")
		var active := i == bi and not done and int(state.get("step", 0)) == 1 and combat.boss == null
		world.set_altar(i, active, int(state.get("shards", 0)))
	world.set_lit(4 if done else bi)


func quest_info(with_tutorial := true) -> Dictionary:
	var tut: Dictionary = quests.tutorial_info() if with_tutorial else {}
	if not tut.is_empty():
		return tut
	if state.get("done", false):
		return {"title": "Thornvale is free", "text": "The Ember burns whole. Wander wherever you like.", "rec": ""}
	var b := _boss()
	var step := int(state["step"])
	var text := ""
	if combat.boss:
		text = "Defeat %s. Leaving the altar's clearing lets it sleep again." % b["name"]
	elif step == 0:
		text = "Follow the old road %s from the Hearth Shrine and read the runestone." % world.boss_dir(Data.BOSSES.find(b))
	elif step == 1:
		if int(state["shards"]) >= 3:
			text = "Offer the %ss at the altar to summon %s." % [b["sigil"], b["name"]]
		else:
			text = "Hunt in %s for %ss (%d/3)." % [Data.BIOME_NAMES[b["biome"]], b["sigil"], state["shards"]]
	else:
		text = "Bring the %s back to the Hearth Shrine." % b["trophy"]
	return {"title": b["name"], "text": text, "rec": "Recommended level %d" % b["rec"]}


var _poi_cache: Array = []


func map_markers() -> Array:
	if _poi_cache.is_empty():
		_poi_cache = world.poi_list()
	var m: Array = []
	m.append({"cell": world.world_to_cell(world.shrine_pos), "color": Color("f2994a"), "size": 4.0})
	if state.is_empty():
		return m
	var runes: Array = state["runes"]
	var bi := int(state["bi"])
	var step := int(state["step"])
	for i in 4:
		var cur: bool = i == bi and not state["done"]
		if runes[i] or (cur and step == 0):
			m.append({"cell": world.world_to_cell(world.rune_pos[i]), "color": Color("ffd27a"), "size": 3.5 if cur else 2.5, "pulse": cur and step == 0})
		if runes[i] and (i < bi or state["done"]):
			m.append({"cell": world.world_to_cell(world.altar_pos[i]), "color": Color("6a5a70"), "size": 3.0})
		elif runes[i] and i == bi:
			m.append({"cell": world.world_to_cell(world.altar_pos[i]), "color": Color("e0566e"), "size": 4.0, "pulse": true})
	if combat.boss:
		m.append({"cell": world.world_to_cell(combat.boss.global_position), "color": Color("e0566e"), "size": 3.0})
	m.append_array(quests.map_markers())
	for poi: Dictionary in _poi_cache:
		m.append({"cell": poi["cell"], "color": poi["color"], "size": 5.0, "glyph": poi["glyph"], "poi": true})
	m.append_array(world.caves.map_markers())
	var g: Dictionary = quests.guide_target()
	if not g.is_empty() and g["pos"] != Vector3.INF:
		m.append({"cell": world.world_to_cell(g["pos"]), "color": Color("fff0a0"), "size": 5.0, "pulse": true})
	return m
