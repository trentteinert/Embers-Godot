class_name Skills
extends Node3D
## RuneScape-style skills. Every skill levels 1-30 on the same XP curve (Data.xp_for_level).
## Your class's combat skill (Melee / Magic / Ranged) is your "level": it drives health, damage
## and ability unlocks. Also here: gathering (mining, woodcutting, herbs, fishing) as repeating
## actions, cooking / herblore / crafting recipes, food and potions, agility courses and
## Varka's slayer tasks.
## Saved in main.state: "skills" {id: xp}, "tools" {skill: true}, "bag_lvl", "slayer" {enemy, left, total}.

const FISH_RANGE := 3.6
const STATION_RANGE := 2.8
const GATE_RADIUS := 2.0
const LAP_TIME := 75.0          # seconds to finish a lap before the course resets
const EAT_DELAY := 1.2

var main: Node
var world: World
var action := {}                 # gathering in progress: {kind, skill, t, dur, pos, node|spot}
var fish_spots: Array = []       # {pos, biome, fish, node}
var courses: Array = []          # {def, center, gates, next, lap_t, active, flags: Array[Node3D]}
var instant_jobs := false        # tests: finish crafts at once
var _eat_cd := 0.0
var _sprint_t := 0.0
var _swing_t := 0.0
var _t := 0.0
var _varka: Rig
var _course_warned := {}


func setup(m: Node) -> void:
	main = m
	world = m.world
	_build_fish_spots()
	_build_stations()
	_build_courses()
	_build_varka()


# ================================================================ levels and xp
func _skills() -> Dictionary:
	if not (main.state.get("skills") is Dictionary):
		main.state["skills"] = {}
	return main.state["skills"]


func xp(id: String) -> int:
	return int(_skills().get(id, 0))


func level(id: String) -> int:
	return Data.level_for_xp(xp(id))


func total_level() -> int:
	var t := 0
	for id: String in Data.SKILL_ORDER:
		t += level(id)
	return t


func combat_id() -> String:
	return Data.COMBAT_SKILL[main.state.get("cls", "warrior")]


## Give XP to a skill. Shows a little "+22 Mining" over your head, and handles level-ups.
func add_xp(id: String, n: int, show := true) -> void:
	if n <= 0 or main.state.is_empty():
		return
	var before := level(id)
	var cap := Data.xp_for_level(Data.MAX_SKILL) + Data.xp_needed(Data.MAX_SKILL) * 4
	_skills()[id] = mini(xp(id) + n, cap)
	if show:
		var col := Color(Data.SKILLS[id]["color"]).lightened(0.25)
		main.combat.float_text(main.player.global_position + Vector3(0, 2.6, 0), "+%d %s" % [n, Data.SKILLS[id]["name"]], col)
	var after := level(id)
	if id == combat_id():
		main.sync_combat_level(after > before)
	elif after > before:
		_level_up(id, after)


func set_xp(id: String, total: int) -> void:
	_skills()[id] = total
	if id == combat_id():
		main.sync_combat_level(false)


func _level_up(id: String, lvl: int) -> void:
	var sk: Dictionary = Data.SKILLS[id]
	var col := Color(sk["color"]).lightened(0.3)
	var msg := "%s level %d!" % [sk["name"], lvl]
	for u: Array in sk["unlocks"]:
		if int(u[0]) == lvl:
			msg += "  Unlocked: %s" % u[1]
	var extra := ""
	for u2: Array in sk["unlocks"]:
		if int(u2[0]) == lvl:
			extra = "Unlocked: %s" % u2[1]
	main.ui.chat_levelup(id, lvl, extra)
	Sfx.play("level_up")
	main.combat.ring(main.player.global_position, 2.6, col, 0.6)
	main.combat.burst(main.player.global_position + Vector3(0, 1.0, 0), col, 20, 5.0, 0.7)


func has_tool(skill: String) -> bool:
	return bool((main.state.get("tools", {}) as Dictionary).get(skill, false))


# ================================================================ gathering (repeating actions)
func busy() -> bool:
	return not action.is_empty()


func progress() -> float:
	return clampf(float(action.get("t", 0.0)) / maxf(float(action.get("dur", 1.0)), 0.01), 0.0, 1.0)


## Best tier you own in a tool line ("pickaxe", "axe", "knife"), or -1.
func tool_tier(line: String) -> int:
	var best := -1
	var ids: Array = Data.TOOL_LINES[line]
	for i in ids.size():
		if main.crafting.count(ids[i]) > 0:
			best = i
	return best


func _cycle_time(skill: String, req: int, tier := 0) -> float:
	var t := 2.6 * (1.0 - 0.08 * maxi(tier, 0))
	if has_tool(skill):
		t *= 0.7
	return t * clampf(1.0 - (level(skill) - req) * 0.015, 0.6, 1.0)


func start_node(n: Dictionary) -> void:
	var nd: Dictionary = Data.NODES[n["mat"]]
	var sk: String = nd["skill"]
	if level(sk) < int(nd["lvl"]):
		main.ui.toast("You need %s level %d to %s %s" % [Data.SKILLS[sk]["name"], nd["lvl"], String(nd["verb"]).to_lower(), Data.MATERIALS[n["mat"]]["name"]])
		Sfx.play("ui_click")
		return
	var line: String = nd.get("tool", {"mining": "pickaxe", "woodcutting": "axe"}.get(sk, ""))
	if line != "":
		var tt := tool_tier(line)
		var need_t := int(nd.get("tt", 0))
		if tt < need_t:
			var nm: String = String(Data.MATERIALS[Data.TOOL_LINES[line][need_t]]["name"]).to_lower()
			var msg := "You need a %s or better. Make one at the %s." % [nm, "knife on twigs" if need_t == 0 else "hammer on a bar at the anvil"] if tt < 0 else "You need a %s or better to work this." % nm
			main.ui.toast(msg, Color("e0a080"))
			Sfx.play("ui_click")
			return
	if int(n.get("charges", 0)) <= 0:
		n["charges"] = randi_range(3, 5)
	action = {"kind": "node", "node": n, "skill": sk, "t": 0.0, "dur": _cycle_time(sk, nd["lvl"], tool_tier(line) if line != "" else 0), "pos": n["pos"]}


func fish_for(spot: Dictionary) -> Dictionary:
	return spot["fish"]


func start_fish(spot: Dictionary) -> void:
	var f: Dictionary = spot["fish"]
	if level("fishing") < int(f["lvl"]):
		main.ui.toast("You need Fishing level %d to catch %s here" % [f["lvl"], String(Data.MATERIALS[f["raw"]]["name"]).trim_prefix("Raw ")])
		Sfx.play("ui_click")
		return
	if main.crafting.count("rod") <= 0:
		main.ui.toast("You need a fishing rod. Use a knife on 8 twigs to make one.", Color("e0a080"))
		Sfx.play("ui_click")
		return
	if main.crafting.count(f["bait"]) <= 0:
		main.ui.toast("You need %s. Kill creatures nearby with a knife in your bag." % Data.MATERIALS[f["bait"]]["name"], Color("e0a080"))
		Sfx.play("ui_click")
		return
	action = {"kind": "fish", "spot": spot, "skill": "fishing", "t": 0.0, "dur": _cycle_time("fishing", f["lvl"]) * 1.15, "pos": spot["pos"]}


func stop(msg := "") -> void:
	if action.is_empty():
		return
	action = {}
	if msg != "":
		main.ui.toast(msg)


func _tick_action(delta: float) -> void:
	var p: Player = main.player
	var flat := Vector2(p.velocity.x, p.velocity.z).length()
	if p.dead or flat > 0.5 or not p.dash.is_empty() or Input.is_action_pressed("attack"):
		stop()
		return
	var pos: Vector3 = action["pos"]
	if p.model and action["kind"] != "job":
		p.model.set_facing(pos - p.global_position)
	var wk := _work_kind()
	if p.model:
		p.model.set_work(wk, _work_col())
		p.model.on_work_hit = _work_hit
	_swing_t -= delta
	if _swing_t <= 0.0:
		_swing_t = 0.85
		if action["kind"] == "job":
			if wk in ["cook", "brew"]:
				Sfx.play({"cook": "fire_cast", "brew": "potion"}[wk], Vector3.INF, -12.0, 0.15)
		elif action["kind"] != "fish" and wk == "gather":
			Sfx.play("ui_click", Vector3.INF, -10.0, 0.15)
	action["t"] = float(action["t"]) + delta
	if float(action["t"]) < float(action["dur"]):
		return
	action["t"] = 0.0
	if action["kind"] == "job":
		var keep: bool = (action["step"] as Callable).call()
		action["left"] = int(action["left"]) - 1
		if not keep or int(action["left"]) <= 0:
			action = {}
		else:
			action["dur"] = craft_time(level(action["skill"]), int(action["req"]))
		return
	if action["kind"] == "fish":
		var f: Dictionary = (action["spot"] as Dictionary)["fish"]
		if main.crafting.count(f["bait"]) <= 0:
			stop("You're out of bait")
			return
		if main.mat_room(f["raw"]) < 1:
			stop("Your bag is full")
			return
		main.crafting.take(f["bait"])
		main.crafting.add_mat(f["raw"], 1, p.global_position)
		add_xp("fishing", int(f["xp"]))
		main.combat.burst(pos + Vector3(0, 0.2, 0), Color("bfe6ff"), 10, 3.0, 0.4)
		Sfx.play("pickup_potion", Vector3.INF, -8.0)
		return
	var n: Dictionary = action["node"]
	var nd: Dictionary = Data.NODES[n["mat"]]
	if main.mat_room(n["mat"]) < 1:
		stop("Your bag is full")
		return
	main.crafting.add_mat(n["mat"], 1, p.global_position)
	add_xp(action["skill"], int(nd["xp"]))
	if action["skill"] == "mining" and randf() < 0.12 and main.mat_room("flint") >= 1:
		main.crafting.add_mat("flint", 1, p.global_position + Vector3(0, 0.2, 0))
	if randf() < 0.02 and action["skill"] == "mining":
		main.crafting.add_mat("ember", 1, p.global_position + Vector3(0, 0.4, 0))
	n["charges"] = int(n.get("charges", 1)) - 1
	main.combat.burst(n["pos"] + Vector3(0, 0.5, 0), Color(Data.MATERIALS[n["mat"]]["color"]), 6, 2.5, 0.3)
	if int(n["charges"]) <= 0:
		main.crafting.deplete(n)
		stop("The %s is spent." % {"mining": "rock", "woodcutting": "tree", "herblore": "plant"}.get(action["skill"], "node"))


# ================================================================ recipes (cooking, herblore, crafting)
static func station_skill(station: String) -> String:
	return Data.STATIONS[station]["skill"] if Data.STATIONS.has(station) else station


func _is_tool(out: String) -> bool:
	return Data.MATERIALS.has(out) and Data.MATERIALS[out].get("kind", "") == "tool"


## The skill a recipe trains: gear says so itself (rings and amulets are Crafting), the rest follow the station.
func _rskill(station: String, r: Dictionary) -> String:
	return String(r.get("skill", station_skill(station)))


func recipe_done(r: Dictionary) -> bool:
	var out: String = r["out"]
	if _is_tool(out):
		return main.crafting.count(out) > 0
	if out.begins_with("tool:"):
		return has_tool(out.get_slice(":", 1))
	if out.begins_with("bag:"):
		return int(main.state.get("bag_lvl", 0)) >= int(out.get_slice(":", 1))
	return false


func can_make(station: String, r: Dictionary) -> String:
	## "" if you can make it, otherwise the reason
	var sk := _rskill(station, r)
	if level(sk) < int(r["lvl"]):
		return "Needs %s %d" % [Data.SKILLS[sk]["name"], r["lvl"]]
	if (r.get("once", false) or _is_tool(r["out"])) and recipe_done(r):
		return "Already made" if not _is_tool(r["out"]) else "You already have one"
	if station == "anvil" and not main.near_anvil():
		return "Go to an anvil"
	if r.has("gear") and not main.can_take_item():
		return "Your bag is full"
	var out: String = r["out"]
	if out.begins_with("bag:") and int(main.state.get("bag_lvl", 0)) < int(out.get_slice(":", 1)) - 1:
		return "Make the Satchel first"
	if not main.crafting.can_afford(r["cost"]):
		return "Missing materials"
	return ""


## How many times you could make it right now.
func max_make(station: String, r: Dictionary) -> int:
	if can_make(station, r) != "":
		return 0
	if r.get("once", false) or _is_tool(r["out"]):
		return 1
	var n := 999
	for k: String in r["cost"]:
		var have: int = int(main.state.get("gold", 0)) if k == "gold" else main.crafting.count(k)
		n = mini(n, have / int(r["cost"][k]))
	if r.has("gear"):
		n = mini(n, maxi(0, main.bag_size() - main.bag_used()))
	return n


## Seconds one craft takes: slowest at the level the recipe unlocks, quicker the further above it you are.
static func craft_time(skill_level: int, req: int) -> float:
	var base := 3.0 + minf(float(req), 40.0) * 0.04
	return base * clampf(1.0 - float(skill_level - req) * 0.05, 0.25, 1.0)


## Start a timed job (cooking, smelting, brewing, forging...). `step` runs once per finished cycle and returns
## false to stop early. Moving or attacking cancels it, like gathering.
func start_job(skill: String, req: int, times: int, step: Callable, label := "", icon := "") -> void:
	if times <= 0:
		return
	if instant_jobs:
		for i in times:
			if not step.call():
				break
		return
	var p: Player = main.player
	action = {"kind": "job", "skill": skill, "req": req, "left": times, "step": step, "label": label, "icon": icon, "t": 0.0,
		"dur": craft_time(level(skill), req), "pos": p.global_position}
	Sfx.play("ui_click", Vector3.INF, -8.0)


func make(station: String, r: Dictionary, times := 1) -> void:
	if main.online != null:
		main.online.craft_local(station, r, times)   # online: the server makes things
		return
	var why := can_make(station, r)
	if why != "":
		main.ui.toast(why)
		Sfx.play("ui_click")
		return
	var n := maxi(times, 1)
	if r.get("once", false) or _is_tool(r["out"]):
		n = 1
	var sk := _rskill(station, r)
	start_job(sk, int(r["lvl"]), n, func() -> bool:
		_make_now(station, r, 1)
		return can_make(station, r) == "", String(r["name"]), "hammer" if r.has("gear") else String(r["out"]))


func _make_now(station: String, r: Dictionary, times := 1) -> void:
	var made := 0
	var burnt := 0
	var full := false
	for i in times:
		if can_make(station, r) != "":
			break
		main.crafting._pay(r["cost"])
		var out: String = r["out"]
		if r.get("burn", false) and randf() < burn_chance(r):
			burnt += 1
			add_xp(_rskill(station, r), 1, false)
			continue
		if out == "potion":
			if main.mat_room("hpot") < 1:
				main.crafting.refund(r["cost"])
				main.ui.toast("Your bag is full", Color("e0a080"))
				full = true
				break
			main.state["potions"] = int(main.state.get("potions", 0)) + 1
		elif r.has("gear"):
			var g: Dictionary = r["gear"]
			main.crafting.make_gear(int(g["tier"]), String(g["slot"]), bool(g["master"]))
		elif out.begins_with("tool:"):
			if not (main.state.get("tools") is Dictionary):
				main.state["tools"] = {}
			main.state["tools"][out.get_slice(":", 1)] = true
		elif out.begins_with("bag:"):
			main.state["bag_lvl"] = int(out.get_slice(":", 1))
		else:
			var qty := int(r.get("qty", 1))
			if main.mat_room(out) < qty:
				main.crafting.refund(r["cost"])
				main.ui.toast("Your bag is full", Color("e0a080"))
				full = true
				break
			var mats: Dictionary = main.state["mats"]
			mats[out] = int(mats.get(out, 0)) + qty
			main.quests.notify("obtain", out, qty)
		add_xp(_rskill(station, r), int(r["xp"]), false)
		made += 1
	if made + burnt == 0:
		if not full:
			main.ui.toast(can_make(station, r))
		Sfx.play("ui_click")
		return
	var col := Color(Data.SKILLS[_rskill(station, r)]["color"]).lightened(0.3)
	var msg := "Made %s (+%d %s xp)" % [r["name"], made * int(r["xp"]), Data.SKILLS[_rskill(station, r)]["name"]] if made > 0 else ""
	if burnt > 0:
		msg += ("  ·  " if msg != "" else "") + "Burnt %d" % burnt
	main.ui.toast(msg, col)
	Sfx.play({"cooking": "fire_cast", "herblore": "potion", "crafting": "equip", "furnace": "fire_cast", "anvil": "slam"}.get(station, "equip"), Vector3.INF, -4.0)
	main.ui.refresh_window()
	main.ui.refresh_inventory()


func burn_chance(r: Dictionary) -> float:
	return clampf(0.45 - (level("cooking") - int(r["lvl"])) * 0.05, 0.0, 0.45)


# ================================================================ food and potions
func food_count() -> int:
	var n := 0
	for f: String in Data.FOOD_ORDER:
		n += main.crafting.count(f)
	return n


func eat(only := "") -> void:
	if main.online != null:
		main.online.send({"t": "eat"})
		return
	var p: Player = main.player
	if p.dead or _eat_cd > 0.0:
		return
	for f: String in Data.FOOD_ORDER:
		if only != "" and f != only:
			continue
		if main.crafting.count(f) > 0:
			main.crafting.take(f)
			var heal := float(Data.MATERIALS[f]["heal"])
			p.hp = minf(p.max_hp, p.hp + heal)
			_eat_cd = EAT_DELAY
			Sfx.play("pickup_potion", Vector3.INF, -4.0)
			main.combat.float_text(p.global_position + Vector3(0, 2.2, 0), "+%d" % int(heal), Color("8ad07a"))
			return
	main.ui.toast("No food. Fish, then cook at a campfire.")


func drink(id: String) -> void:
	if main.online != null:
		main.online.send({"t": "drink", "potion": id})
		return
	var p: Player = main.player
	if p.dead:
		return
	if main.crafting.count(id) <= 0:
		main.ui.toast("No %s. Smelt some at the furnace." % Data.MATERIALS[id]["name"])
		return
	main.crafting.take(id)
	p.buffs[id] = 120.0
	Sfx.play("potion")
	main.ui.toast("%s: %s" % [Data.MATERIALS[id]["name"], "+25% damage" if id == "might" else "+20% speed"], Color(Data.MATERIALS[id]["color"]))


# ================================================================ slayer
func task() -> Dictionary:
	var t: Variant = main.state.get("slayer", {})
	return t if t is Dictionary else {}


func talk_varka() -> void:
	if main.online != null:
		main.online.talk("varka")
		return
	main.quests.notify("talk", "varka")
	var t := task()
	var who := Data.SLAYER_NAME.to_upper()
	if not t.is_empty() and int(t["left"]) > 0:
		main.ui.say([[who, "You've still got %d %s to kill. Off you go." % [t["left"], _plural(t["enemy"])]]])
		return
	if not t.is_empty():
		# turn in
		var total := int(t["total"])
		var hp := float(Data.ENEMIES[t["enemy"]]["hp"])
		var bonus := roundi(hp * 0.6 * total)
		add_xp("slayer", bonus)
		main.add_gold(12 * total, main.player.global_position)
		main.state["slayer"] = {}
		main.ui.say([[who, "Clean work. Here's your pay. Come back when you want another."]])
		return
	var lvl := level("slayer")
	var choices: Array = []
	for st: Dictionary in Data.SLAYER_TASKS:
		if int(st["lvl"]) <= lvl and int(st["lvl"]) >= lvl - 12:
			choices.append(st["enemy"])
	var e: String = choices[randi() % choices.size()]
	var n := 10 + randi() % 11
	main.state["slayer"] = {"enemy": e, "left": n, "total": n}
	main.ui.say([[who, "Slayer work, then. Kill %d %s and come back to me. You'll hit them harder the more Slayer you know." % [n, _plural(e)]]])


func _plural(e: String) -> String:
	var nm: String = Data.ENEMIES[e]["name"]
	return nm + ("es" if nm.ends_with("s") else "s")


func on_kill(e: Enemy) -> void:
	var t := task()
	if t.is_empty() or int(t["left"]) <= 0 or e.type_id != t["enemy"] or e.is_boss:
		return
	t["left"] = int(t["left"]) - 1
	add_xp("slayer", maxi(4, roundi(float(Data.ENEMIES[e.type_id]["hp"]) * 0.4)))
	if int(t["left"]) == 0:
		main.ui.toast("Slayer task done! Return to %s." % Data.SLAYER_NAME, Color(Data.SKILLS["slayer"]["color"]).lightened(0.3))


func damage_mult(e: Enemy) -> float:
	var t := task()
	if t.is_empty() or e.type_id != t["enemy"]:
		return 1.0
	return 1.0 + 0.01 * level("slayer")


# ================================================================ agility
func speed_mult() -> float:
	return 1.0 + 0.006 * level("agility")


func stamina_mult() -> float:
	return 1.0 + 0.02 * level("agility")


func can_double_jump() -> bool:
	return level("agility") >= 15


func on_jump() -> void:
	add_xp("agility", 1, false)


func _tick_agility(delta: float) -> void:
	var p: Player = main.player
	# a trickle of XP for getting around on foot
	if Input.is_action_pressed("sprint") and Vector2(p.velocity.x, p.velocity.z).length() > 3.0:
		_sprint_t += delta
		if _sprint_t >= 4.0:
			_sprint_t = 0.0
			add_xp("agility", 2, false)
	for c: Dictionary in courses:
		var def: Dictionary = c["def"]
		var gates: Array = c["gates"]
		var next := int(c["next"])
		if bool(c["active"]):
			c["lap_t"] = float(c["lap_t"]) + delta
			if float(c["lap_t"]) > LAP_TIME:
				c["active"] = false
				c["next"] = 0
				_mark_gates(c)
				main.ui.toast("%s: too slow, lap reset" % def["name"])
				continue
		var gp: Vector3 = gates[next % gates.size()]
		if Vector2(p.global_position.x - gp.x, p.global_position.z - gp.z).length() > GATE_RADIUS:
			continue
		if level("agility") < int(def["lvl"]):
			if not _course_warned.get(def["name"], false):
				_course_warned[def["name"]] = true
				main.ui.toast("You need Agility level %d for the %s" % [def["lvl"], def["name"]])
			continue
		if not bool(c["active"]):
			c["active"] = true
			c["lap_t"] = 0.0
			c["next"] = 1
			main.ui.toast("%s: run through the glowing gates in order!" % def["name"], Color(Data.SKILLS["agility"]["color"]).lightened(0.3))
		elif next == gates.size():
			add_xp("agility", int(def["lap"]))
			main.ui.toast("Lap complete in %ds!" % roundi(float(c["lap_t"])), Color(Data.SKILLS["agility"]["color"]).lightened(0.3))
			Sfx.play("level_up", Vector3.INF, -8.0)
			c["next"] = 1
			c["lap_t"] = 0.0
		else:
			add_xp("agility", int(def["xp"]))
			Sfx.play("ui_click", Vector3.INF, -4.0)
			c["next"] = next + 1
		_mark_gates(c)


func _mark_gates(c: Dictionary) -> void:
	var flags: Array = c["flags"]
	var target := int(c["next"]) % flags.size() if bool(c["active"]) else 0
	for i in flags.size():
		var fm: StandardMaterial3D = (flags[i] as Dictionary)["mat"]
		var on := i == target
		fm.albedo_color = Color("ffd27a") if on else Color("5a7a9a")
		fm.emission_energy_multiplier = 1.6 if on else 0.2


## Which skilling pose (see Rig.set_work) the current action calls for.
func _work_kind() -> String:
	if action.is_empty():
		return ""
	match action["kind"]:
		"fish":
			return "fish"
		"job":
			return {"cooking": "cook", "herblore": "brew", "smithing": "smith", "crafting": "craft"}.get(action["skill"], "craft")
		_:
			var nd: Dictionary = Data.NODES[(action["node"] as Dictionary)["mat"]]
			if action["skill"] == "mining":
				return "mine"
			if action["skill"] == "woodcutting" and String(nd.get("tool", "x")) != "":
				return "chop"
			return "gather"


## Metal colour of the tool in hand, by tier.
func _work_col() -> String:
	if action.is_empty() or action["kind"] != "node":
		return "a3adba"
	var nd: Dictionary = Data.NODES[(action["node"] as Dictionary)["mat"]]
	var line: String = nd.get("tool", {"mining": "pickaxe", "woodcutting": "axe"}.get(action["skill"], ""))
	if line == "" or not Data.TOOL_LINES.has(line):
		return "a3adba"
	return (["8a6a44", "a3adba", "6a8a5a", "9fe0ff"] as Array)[clampi(tool_tier(line), 0, 3)]


## A swing lands: sound and a puff of chips where the tool meets the work.
func _work_hit() -> void:
	if action.is_empty():
		return
	var p: Player = main.player
	var wk := _work_kind()
	var snd := "equip"
	var col := Color("a07a4a")
	match wk:
		"chop":
			snd = "hit"
		"mine":
			snd = "equip"
			col = Color("b0b4bc")
			if action["kind"] == "node" and Data.NODES[(action["node"] as Dictionary)["mat"]]["look"] == "crystal":
				snd = "frost"
				col = Color("9fe0ff")
		"smith":
			col = Color("ffb050")
		"craft":
			col = Color("c8a878")
	Sfx.play(snd, Vector3.INF, -10.0, 0.15)
	var at: Vector3 = (action["pos"] as Vector3) if action["kind"] == "node" else p.global_position + p.model.global_basis.z.normalized() * 0.8
	main.combat.burst(at + Vector3(0, 1.0 if action["kind"] == "node" else 0.9, 0), col, 6, 2.5, 0.5, 0.1)


# ================================================================ per frame
func _process(delta: float) -> void:
	_t += delta
	if action.is_empty() and main and main.player and main.player.model and main.player.model.work_kind != "" and (main.online == null or main.online.work_pose == ""):
		main.player.model.set_work("")
	for s: Dictionary in fish_spots:
		var n: Node3D = s["node"]
		n.rotation.y = _t * 0.6
		n.scale = Vector3.ONE * (1.0 + sin(_t * 2.4 + n.position.x) * 0.08)
	if _varka:
		var to: Vector3 = main.player.global_position - world.slayer_pos
		if Vector2(to.x, to.z).length() < 12.0:
			_varka.set_facing(to)
		_varka.tick(delta, 0.0)
	if main.mode != "play" or get_tree().paused:
		return
	_eat_cd -= delta
	_tick_fires(delta)
	if not action.is_empty():
		_tick_action(delta)
	_tick_agility(delta)


# ================================================================ world bits
func _mat(col: Color, glow := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 1.0
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = glow
	return m


func _mesh(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


func _solid(parent: Node3D, size: Vector3, pos: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 2
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.position = pos
	body.add_child(cs)
	parent.add_child(body)


func _label(parent: Node3D, text: String, y: float, col := Color("f1e8d4")) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = load("res://assets/fonts/Jersey10.ttf")
	l.font_size = 32
	l.pixel_size = 0.012
	l.outline_size = 9
	l.outline_modulate = Color("0a0810")
	l.modulate = col
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position.y = y
	parent.add_child(l)


func _build_fish_spots() -> void:
	if Online.requested():
		return   # online: the server places fishing spots
	var ripple := TorusMesh.new()
	ripple.inner_radius = 0.55
	ripple.outer_radius = 0.66
	ripple.rings = 16
	ripple.ring_segments = 3
	var ripple2 := TorusMesh.new()
	ripple2.inner_radius = 0.95
	ripple2.outer_radius = 1.03
	ripple2.rings = 20
	ripple2.ring_segments = 3
	var rm := _mat(Color("dff4ff"), 0.4)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for spot: Dictionary in world.fish_spots:
		var b: int = spot["biome"]
		var options: Array = []
		for f: Dictionary in Data.FISH:
			if b in (f["biomes"] as Array):
				options.append(f)
		var fish: Dictionary = options[rng.randi() % options.size()] if not options.is_empty() else Data.FISH[0]
		var n := Node3D.new()
		add_child(n)
		n.global_position = spot["pos"] + Vector3(0, 0.04, 0)
		_mesh(n, ripple, rm, Vector3.ZERO)
		_mesh(n, ripple2, rm, Vector3.ZERO)
		_mesh(n, _box(Vector3(0.12, 0.05, 0.4)), _mat(Color("2a4a5a")), Vector3(0.3, -0.02, 0), Vector3(0, 0.6, 0))
		fish_spots.append({"pos": spot["pos"], "biome": b, "fish": fish, "node": n})


## A campfire: ring of stones, logs and a flame. Returns the root so lit fires can be removed later.
func _make_fire(fp: Vector3, permanent := false) -> Node3D:
	var r := Node3D.new()
	add_child(r)
	r.global_position = fp
	for k in 6:
		var a := k * TAU / 6.0
		_mesh(r, _box(Vector3(0.28, 0.2, 0.22)), _mat(Color("6f7480")), Vector3(cos(a) * 0.6, 0.1, sin(a) * 0.6), Vector3(0, -a, 0))
	for k in 3:
		_mesh(r, _box(Vector3(0.9, 0.14, 0.14)), _mat(Color("5a3d25")), Vector3(0, 0.15, 0), Vector3(0, k * 1.05, 0.15))
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.28
	cone.height = 0.7
	cone.radial_segments = 5
	var fm := _mat(Color("f2994a"), 2.0)
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mesh(r, cone, fm, Vector3(0, 0.5, 0))
	var l := OmniLight3D.new()
	l.light_color = Color("ff9a4a")
	l.omni_range = 5.0
	l.light_energy = 1.2
	l.position.y = 0.8
	l.set_meta("base", 1.2)
	l.add_to_group("flicker")
	r.add_child(l)
	if not permanent:
		_label(r, "Fire", 1.3, Color("ffb070"))
	return r


# ================================================================ firemaking
var fires: Array = []     # lit fires: {pos, t (seconds left), node}


## Every fire you can cook at: the permanent campfires and the ones you lit.
func all_fires() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for fp: Vector3 in world.campfires:
		out.append(fp)
	for f: Dictionary in fires:
		out.append(f["pos"])
	return out


func make_kindling(log_id: String) -> void:
	if main.online != null:
		main.online.light_fire()   # online: a log and Flint and Steel make a fire
		return
	if not Data.FIRE_LOGS.has(log_id) or main.player.dead:
		return
	var d: Dictionary = Data.FIRE_LOGS[log_id]
	if tool_tier("knife") < 0:
		main.ui.toast("You need a knife to cut kindling.", Color("e0a080"))
		return
	if level("firemaking") < int(d["lvl"]):
		main.ui.toast("You need Firemaking level %d for %s" % [d["lvl"], Data.MATERIALS[log_id]["name"]], Color("e0a080"))
		return
	if main.crafting.count(log_id) <= 0:
		return
	main.crafting.take(log_id)
	if main.mat_room(d["kindling"]) < 2:
		main.crafting.refund({log_id: 1})
		main.ui.toast("Your bag is full", Color("e0a080"))
		return
	main.crafting.add_mat(d["kindling"], 2)
	add_xp("firemaking", int(d["kxp"]))
	Sfx.play("equip", Vector3.INF, -8.0)
	main.ui.refresh_inventory()


func light_fire(kindling_id: String) -> void:
	if main.online != null:
		main.online.light_fire()
		return
	var log_id := ""
	for k: String in Data.FIRE_LOGS:
		if Data.FIRE_LOGS[k]["kindling"] == kindling_id:
			log_id = k
	if log_id == "" or main.player.dead:
		return
	var d: Dictionary = Data.FIRE_LOGS[log_id]
	if main.crafting.count("flint_steel") <= 0:
		main.ui.toast("You need Flint and Steel to light it.", Color("e0a080"))
		return
	if level("firemaking") < int(d["lvl"]):
		main.ui.toast("You need Firemaking level %d for %s" % [d["lvl"], Data.MATERIALS[log_id]["name"]], Color("e0a080"))
		return
	if main.crafting.count(kindling_id) <= 0 or main.crafting.count(log_id) <= 0:
		main.ui.toast("Lighting a fire takes kindling and a %s." % Data.MATERIALS[log_id]["name"], Color("e0a080"))
		return
	main.crafting.take(kindling_id)
	main.crafting.take(log_id)
	var p: Player = main.player
	var pos := p.global_position + p.forward_vec() * 1.6
	pos.y = world.height_at(pos.x, pos.z)
	var node := _make_fire(pos)
	fires.append({"pos": pos, "t": float(d["burn"]), "node": node})
	while fires.size() > 5:
		_put_out(fires[0])
	add_xp("firemaking", int(d["xp"]))
	Sfx.play("fire_cast", Vector3.INF, -4.0)
	main.combat.burst(pos + Vector3(0, 0.4, 0), Color("ffb060"), 12, 3.0, 0.5)
	main.ui.toast("You light a fire. Cook on it (click it).", Color(Data.SKILLS["firemaking"]["color"]).lightened(0.3))
	main.quests.notify("fire", "lit")
	main.ui.refresh_inventory()


func _put_out(f: Dictionary) -> void:
	fires.erase(f)
	if is_instance_valid(f["node"]):
		(f["node"] as Node).queue_free()


func _tick_fires(delta: float) -> void:
	for f: Dictionary in fires.duplicate():
		f["t"] = float(f["t"]) - delta
		if float(f["t"]) <= 0.0:
			_put_out(f)


func _build_stations() -> void:
	# campfires (Cooking)
	for fp: Vector3 in world.campfires:
		_make_fire(fp, true)
	# in the original world the furnace and anvil are the smithy's own; in a custom world (placed with Embers points) they are built here
	var custom: bool = str(world.get_meta("custom_world", "")) != ""
	var fu := Node3D.new()
	add_child(fu)
	fu.global_position = world.furnace_pos
	if custom:
		_build_furnace(fu)
	_label(fu, "Furnace", 2.3, Color("ffb070"))
	var an := Node3D.new()
	add_child(an)
	an.global_position = world.anvil_pos
	if custom:
		_build_anvil(an)
		_build_rack()
	_label(an, "Anvil", 1.7, Color("c8ccd4"))


## A solid block of the given size standing on the ground at `pos` (a corner of its base is at `pos - size/2`).
func _block(parent: Node3D, size: Vector3, pos: Vector3, col: Color, glow := 0.0, solid := false) -> void:
	var bm := BoxMesh.new()
	bm.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = bm
	mi.material_override = _mat(col, glow)
	mi.position = pos + Vector3(0, size.y * 0.5, 0)
	parent.add_child(mi)
	if solid:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		sb.position = mi.position
		sb.add_child(cs)
		parent.add_child(sb)


## The camp's weapon rack in a custom world: a wooden frame holding a bow and a staff (taken once, from Tam's rack).
func _build_rack() -> void:
	var root := Node3D.new()
	add_child(root)
	root.global_position = world.rack_pos
	var wood := Color("6b4a2c")
	_block(root, Vector3(0.18, 1.5, 0.18), Vector3(-0.8, 0, 0), wood, 0.0, true)
	_block(root, Vector3(0.18, 1.5, 0.18), Vector3(0.8, 0, 0), wood, 0.0, true)
	_block(root, Vector3(1.8, 0.14, 0.16), Vector3(0, 1.3, 0), wood)
	_block(root, Vector3(1.8, 0.14, 0.16), Vector3(0, 0.6, 0), wood)
	_block(root, Vector3(0.09, 1.5, 0.09), Vector3(-0.3, 0.2, 0.12), Color("a47a4a"))       # the staff
	_block(root, Vector3(0.22, 0.22, 0.22), Vector3(-0.3, 1.68, 0.12), Color("b080ff"), 1.0)
	_block(root, Vector3(0.07, 1.4, 0.07), Vector3(0.35, 0.2, 0.12), Color("8a5a30"))        # the bow
	_block(root, Vector3(0.07, 0.3, 0.07), Vector3(0.45, 1.5, 0.12), Color("8a5a30"))
	_block(root, Vector3(0.02, 1.4, 0.02), Vector3(0.5, 0.2, 0.12), Color("e8e0d0"))         # the string
	_label(root, "Weapon rack", 2.2, Color("e8c070"))


## A stone furnace: a squat kiln with a glowing mouth, a chimney and a few embers.
func _build_furnace(root: Node3D) -> void:
	var stone := Color("8a8c94")
	var dark := Color("5c5e66")
	_block(root, Vector3(1.8, 0.3, 1.5), Vector3(0, 0, 0), dark, 0.0, true)
	_block(root, Vector3(1.6, 1.3, 1.3), Vector3(0, 0.3, 0), stone, 0.0, true)
	_block(root, Vector3(1.2, 0.35, 1.0), Vector3(0, 1.6, 0), dark)
	_block(root, Vector3(0.55, 1.1, 0.55), Vector3(-0.35, 1.95, -0.2), stone)     # chimney
	_block(root, Vector3(0.7, 0.55, 0.12), Vector3(0, 0.55, 0.69), Color("1a1210"))   # the mouth
	_block(root, Vector3(0.5, 0.3, 0.1), Vector3(0, 0.6, 0.72), Color("ff8a30"), 2.2)   # glowing coals
	_block(root, Vector3(0.25, 0.14, 0.1), Vector3(0.05, 0.9, 0.73), Color("ffd060"), 2.6)
	var light := OmniLight3D.new()
	light.position = Vector3(0, 0.9, 1.2)
	light.light_color = Color("ff9a40")
	light.light_energy = 0.8
	light.omni_range = 5.0
	root.add_child(light)


## An iron anvil on a log: a flat top, a horn, a waist and a foot.
func _build_anvil(root: Node3D) -> void:
	var iron := Color("52555e")
	var top := Color("767a84")
	_block(root, Vector3(0.9, 0.6, 0.9), Vector3(0, 0, 0), Color("6b4a2c"), 0.0, true)   # the log
	_block(root, Vector3(0.9, 0.12, 0.5), Vector3(0, 0.6, 0), iron)                       # foot
	_block(root, Vector3(0.4, 0.28, 0.32), Vector3(0, 0.72, 0), iron)                     # waist
	_block(root, Vector3(1.0, 0.2, 0.46), Vector3(0, 1.0, 0), top)                        # face
	_block(root, Vector3(0.32, 0.14, 0.3), Vector3(0.62, 1.04, 0), top)                   # horn
	_block(root, Vector3(0.18, 0.1, 0.22), Vector3(0.82, 1.06, 0), top)
	_block(root, Vector3(0.7, 0.04, 0.3), Vector3(-0.1, 1.2, 0), Color("9aa0aa"))         # polished top


func _build_courses() -> void:
	for c: Dictionary in world.courses:
		var def: Dictionary = Data.AGILITY[int(c["i"])]
		var gates: Array = c["gates"]
		var flags: Array = []
		var root := Node3D.new()
		add_child(root)
		var post := _mat(Color("6b4a2c"))
		for i in gates.size():
			var g: Vector3 = gates[i]
			var nxt: Vector3 = gates[(i + 1) % gates.size()]
			var dir := (nxt - g)
			dir.y = 0.0
			var side := Vector3(-dir.z, 0, dir.x).normalized()
			var arch := Node3D.new()
			root.add_child(arch)
			arch.global_position = g
			arch.look_at(g + side, Vector3.UP)
			_mesh(arch, _box(Vector3(0.18, 2.6, 0.18)), post, Vector3(0, 1.3, -1.4))
			_mesh(arch, _box(Vector3(0.18, 2.6, 0.18)), post, Vector3(0, 1.3, 1.4))
			var fm := _mat(Color("5a7a9a"), 0.2)
			_mesh(arch, _box(Vector3(0.12, 0.45, 2.9)), fm, Vector3(0, 2.5, 0))
			flags.append({"mat": fm})
			# a hurdle halfway to the next gate: jump it
			var mid := g.lerp(nxt, 0.5)
			mid.y = world.height_at(mid.x, mid.z)
			var h := Node3D.new()
			root.add_child(h)
			h.global_position = mid
			h.look_at(mid + side, Vector3.UP)
			var hh := 0.5 + int(c["i"]) * 0.15
			_mesh(h, _box(Vector3(0.35, hh, 2.6)), _mat(Color("8a6a40")), Vector3(0, hh * 0.5, 0))
			_mesh(h, _box(Vector3(0.4, 0.08, 2.7)), _mat(Color("d8b04a"), 0.3), Vector3(0, hh, 0))
			_solid(h, Vector3(0.35, hh, 2.6), Vector3(0, hh * 0.5, 0))
		var board := Node3D.new()
		root.add_child(board)
		board.global_position = gates[0]
		_label(board, "%s · Agility %d" % [def["name"], def["lvl"]], 3.4, Color("9fd0ff"))
		var cd := {"def": def, "center": c["center"], "gates": gates, "next": 0, "lap_t": 0.0, "active": false, "flags": flags}
		courses.append(cd)
		_mark_gates(cd)


func _build_varka() -> void:
	var root := Node3D.new()
	add_child(root)
	root.global_position = world.slayer_pos
	_varka = Models.hero("slayer")
	_varka.scale = Vector3.ONE * Player.MODEL_SCALE
	root.add_child(_varka)
	_varka.set_facing(world.shrine_pos - world.slayer_pos, true)
	_solid(root, Vector3(0.7, 1.6, 0.7), Vector3(0, 0.8, 0))
	_label(root, "%s · Slayer" % Data.SLAYER_NAME, 2.75, Color("ff8a7a"))
