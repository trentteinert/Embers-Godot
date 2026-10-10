class_name Quests
extends Node3D
## Side quests: the four quest givers, Bramble the merchant's figure, glowing plants to gather,
## and the named elites that guard their lairs. Quest text and rewards live in data.gd (SIDE_QUESTS).
## Progress is stored in main.state["quests"]: id -> {stage, active, progress}.

const TALK_RANGE := 3.2

var main: Node
var world: World
var _npcs := {}                # id -> {node, sprite, mark, frames}
var _merchant := {}
var _merchant2 := {}
var _merchant3 := {}
var _gather: Array = []        # {node, pos, type, quest}
var _elites := {}              # elite id -> Enemy
var _t := 0.0
var _practice: Enemy
var _font: Font


func setup(m: Node) -> void:
	main = m
	world = m.world
	_font = load("res://assets/fonts/Jersey10.ttf")
	var si := 0
	for q: Dictionary in Data.SIDE_QUESTS:
		var npc := _make_npc(q["sprite"], world.npc_pos[q["id"]], q["name"])
		# the ones standing in town stroll about their spot
		if q.has("town") and not q.get("still", false):
			npc["wander"] = Wanderer.new(world.npc_pos[q["id"]], 3.2, 100 + si)
		_npcs[q["id"]] = npc
		si += 1
	_merchant = _make_npc("merchant", world.merchant_pos, Data.MERCHANT_NAME)
	(_merchant["mark"] as Label3D).text = "$"
	(_merchant["mark"] as Label3D).modulate = Color("ffd27a")
	_merchant2 = _make_npc("merchant", world.merchant2_pos, Data.MERCHANT_NAME)
	(_merchant2["mark"] as Label3D).text = "$"
	(_merchant2["mark"] as Label3D).modulate = Color("ffd27a")
	_merchant3 = _make_npc("hermit", world.merchant3_pos, Data.APOTHECARY_NAME)
	(_merchant3["mark"] as Label3D).text = "$"
	(_merchant3["mark"] as Label3D).modulate = Color("9fe0a0")
	_spawn_villagers()


func _make_npc(sprite: String, pos: Vector3, label: String) -> Dictionary:
	var root := Node3D.new()
	add_child(root)
	root.global_position = pos
	var s := Models.hero(sprite)
	s.scale = Vector3.ONE * Player.MODEL_SCALE
	root.add_child(s)
	var face := world.shrine_pos - pos
	s.set_facing(face if Vector2(face.x, face.z).length() > 1.0 else Vector3.BACK, true)
	var body := StaticBody3D.new()
	body.collision_layer = 2
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.6
	cs.shape = cap
	cs.position.y = 0.8
	body.add_child(cs)
	root.add_child(body)
	var name_l := _label3d(label, 30, Color("f1e8d4"))
	name_l.position.y = 2.75
	root.add_child(name_l)
	var mark := _label3d("", 64, Color("ffd27a"))
	mark.position.y = 3.35
	root.add_child(mark)
	return {"node": root, "sprite": s, "mark": mark, "pos": pos}


## Townsfolk who are not quest givers: they stroll around their spot and say a line when you pass.
const VILLAGERS := [
	{"sprite": "farmer", "name": "Farmer Hob", "kind": "barn", "r": 5.0, "lines": ["Good soil this year.", "Mind the hay.", "The wolves took a sheep again."]},
	{"sprite": "pilgrim", "name": "Pilgrim", "kind": "chapel", "r": 4.0, "lines": ["The shrine hums at night.", "I walked here from the peaks.", "Peace to you, traveller."]},
	{"sprite": "elder", "name": "Innkeeper", "kind": "tavern", "r": 1.0, "local": Vector3(2.4, 0, -2.4), "lines": ["Warm fire, cold ale.", "Sit anywhere.", "Rowan drinks too much tea."]},
	{"sprite": "farmer", "name": "Goodwife Mara", "kind": "farm", "r": 3.5, "local": Vector3(0, 0, 0.5), "lines": ["Cabbages again. Always cabbages.", "Keep off the rows, dear.", "The crows know no fear."]},
	{"sprite": "farmer", "name": "Old Pell", "kind": "farm", "nth": 1, "r": 3.5, "local": Vector3(0, 0, 0.5), "lines": ["My knees say rain.", "Wheat's late this year.", "Scarecrow's got more sense than my son."]},
	{"sprite": "pilgrim", "name": "Wandering Minstrel", "kind": "tavern", "r": 2.0, "local": Vector3(-3.0, 0, 6.2), "lines": ["Care for a song about the Wardens?", "I only know sad ones.", "Gold for a tune? Kind of you."]},
	{"sprite": "merchant", "name": "Peddler", "kind": "plaza", "r": 6.0, "lines": ["Needles, nails, a charm for luck.", "Best prices south of the keep.", "Don't tell Bramble I'm here."]},
	{"sprite": "warrior", "name": "Town Watch", "kind": "plaza", "r": 8.0, "lines": ["Move along, citizen. Kindly.", "All quiet.", "Heard something howling past the wall."]},
	{"sprite": "hermit", "name": "Smith's Helper", "kind": "smithy", "r": 2.0, "local": Vector3(2.4, 0, 1.6), "lines": ["Mind the sparks!", "Hilde works me to the bone.", "Fetch more coal? Sure."]},
	{"sprite": "warrior", "name": "Castle Guard", "kind": "gate", "r": 4.5, "lines": ["Roads are dangerous. Stay sharp.", "Nothing to report.", "Keep your blade handy out there."]},
	{"sprite": "warrior", "name": "Castle Guard", "kind": "gate", "r": 4.5, "lines": ["Halt. Ah, it is you.", "Quiet watch tonight.", "Beasts gather beyond the walls."]},
	{"sprite": "hermit", "name": "Old Wren", "kind": "windmill", "r": 4.0, "lines": ["The old stones remember.", "I knew the Wardens.", "Feed the shrine, it feeds you."]},
]
var _ambient: Array = []


func _spawn_villagers() -> void:
	var gate_n := 0
	var idx := 0
	for v: Dictionary in VILLAGERS:
		var home := world.shrine_pos + Vector3(0, 0, 6.0)
		var found := false
		match String(v["kind"]):
			"gate":
				var ang: float = float(world.gate_angles[gate_n % world.gate_angles.size()])
				home = world.shrine_pos + Vector3(cos(ang), 0, sin(ang)) * (world.town_radius - 9.0)
				gate_n += 1
				found = true
			"plaza":
				var pa := float(idx) * 2.4
				home = world.shrine_pos + Vector3(-3.0, 0, -3.0) + Vector3(cos(pa), 0, sin(pa)) * 5.0
				found = true
			_:
				var nth_left: int = int(v.get("nth", 0))
				for tb: Dictionary in world.town_buildings:
					if tb["kind"] == v["kind"]:
						if nth_left > 0:
							nth_left -= 1
							continue
						var tp: Vector3 = tb["pos"]
						var fwd := Vector3(sin(tb["yaw"]), 0, cos(tb["yaw"]))
						if v.has("local"):
							# a spot in the building's own space (behind the bar, on the farm plot...)
							home = tp + Basis(Vector3.UP, float(tb["yaw"])) * (v["local"] as Vector3) * float(tb.get("scale", 1.0))
						else:
							# inside: a little in from the door; otherwise out in front of it
							home = tp + fwd * (0.0 if v.get("inside", false) else TownKit.footprint(v["kind"]) * float(tb.get("scale", 1.0)) + 2.0)
						found = true
						break
		if not found:
			continue
		home.y = world.height_at(home.x, home.z)
		var n := _make_npc(v["sprite"], home, v["name"])
		n["wander"] = Wanderer.new(home, float(v["r"]), 500 + idx)
		n["lines"] = v["lines"]
		n["say_t"] = randf_range(2.0, 6.0)
		_ambient.append(n)
		idx += 1


func _label3d(text: String, size: int, col: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = _font
	l.font_size = roundi(size * 1.25)
	l.pixel_size = 0.012
	l.outline_size = 10
	l.outline_modulate = Color("0a0810")
	l.modulate = col
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return l


# ================================================================ state helpers
func _qs(id: String) -> Dictionary:
	var all: Dictionary = main.state.get("quests", {})
	if not all.has(id):
		all[id] = {"stage": 0, "active": false, "progress": 0}
		main.state["quests"] = all
	return all[id]


func _def(id: String) -> Dictionary:
	for q: Dictionary in Data.SIDE_QUESTS:
		if q["id"] == id:
			return q
	return {}


func current(id: String) -> Dictionary:
	var q := _def(id)
	var st := _qs(id)
	var quests: Array = q["quests"]
	return quests[int(st["stage"])] if int(st["stage"]) < quests.size() else {}


func status(id: String) -> String:
	var cur := current(id)
	if cur.is_empty():
		return "done"
	var st := _qs(id)
	if not st["active"]:
		return "available"
	return "ready" if int(st["progress"]) >= int(cur["count"]) else "active"


## Called on new game / load: clears plants and elites, rebuilds from saved progress.
func reset() -> void:
	for g: Dictionary in _gather:
		(g["node"] as Node).queue_free()
	_gather.clear()
	_elites.clear()
	for q: Dictionary in Data.SIDE_QUESTS:
		_ensure_gather(q["id"])


# ================================================================ talking
func nearest() -> String:
	var p: Vector3 = main.player.global_position
	if _flat(p, world.merchant_pos) < TALK_RANGE + 0.4:
		return "merchant"
	if _flat(p, world.merchant2_pos) < TALK_RANGE + 0.4:
		return "merchant2"
	if _flat(p, world.merchant3_pos) < TALK_RANGE + 0.4:
		return "merchant3"
	for id: String in _npcs:
		if _flat(p, (_npcs[id] as Dictionary)["pos"]) < TALK_RANGE:
			return id
	return ""


func prompt(id: String) -> String:
	if id == "merchant3":
		return "[G] Trade with %s" % Data.APOTHECARY_NAME
	if id == "merchant" or id == "merchant2":
		return "[G] Trade with %s" % Data.MERCHANT_NAME
	return "[G] Talk to %s" % _def(id)["name"]


const OPEN_ACTIVE := ["", "", "Still at it? ", "Keep going. ", "Not done yet. "]
const OPEN_READY := ["", "Well done. ", "Back already! ", "That's it. "]
const OPEN_NEXT := ["", "Next up. ", "Ready for more? ", "Good. Now this. "]
const THANKS_EXTRA := ["Good to see you.", "Stay safe out there.", "Anything else, just ask."]


func _pick_line(options: Array) -> String:
	return String(options[randi() % options.size()])


func talk(id: String) -> void:
	var q := _def(id)
	var who: String = String(q["name"]).to_upper()
	notify("talk", id)
	if status(id) == "active":
		_sync_obtain(id)
	var cur := current(id)
	var st := _qs(id)
	match status(id):
		"available":
			var accept := func() -> void:
				st["active"] = true
				st["progress"] = 0
				st["met"] = true
				Sfx.play("ui_open")
				main.ui.toast("New quest: %s" % cur["title"])
				if cur.has("give"):
					var gv: Dictionary = cur["give"]
					for gk: String in gv:
						main.crafting.add_mat(gk, int(gv[gk]))
				_ensure_gather(id)
				_sync_obtain(id)
				main.save_game()
			if bool(st.get("met", false)) or int(st["stage"]) > 0:
				main.ui.say([[who, _pick_line(OPEN_NEXT) + String(cur["intro"])]], accept)
			else:
				main.ui.say([[who, q["greet"]], [who, cur["intro"]]], accept)
		"active":
			var tail := "" if int(cur["count"]) <= 1 else " (%d/%d)" % [st["progress"], cur["count"]]
			main.ui.say([[who, _pick_line(OPEN_ACTIVE) + String(cur["nag"]) + tail]])
		"ready":
			var line := String(cur["done"])
			main.ui.say([[who, _pick_line(OPEN_READY) + line]], func() -> void: _complete(id))
		"done":
			main.ui.say([[who, _pick_line([q["thanks"], q["thanks"], _pick_line(THANKS_EXTRA)])]])


## Credit for things already in your bag (a tool you made before taking the quest, say).
func _sync_obtain(id: String) -> void:
	var cur := current(id)
	if cur.is_empty() or status(id) != "active":
		return
	if cur["goal"] == "bar":
		var on_bar := 0
		for b in (main.state.get("bar", []) as Array):
			if int(b) >= 0:
				on_bar += 1
		var stb := _qs(id)
		if on_bar > int(stb["progress"]):
			stb["progress"] = mini(on_bar, int(cur["count"]))
		return
	if cur["goal"] != "obtain":
		return
	var parts: PackedStringArray = String(cur["target"]).split("|")
	var have := 0
	if parts.size() > 1:
		for t: String in parts:
			have += 1 if main.crafting.count(t) > 0 else 0
	else:
		have = main.crafting.count(parts[0])
	var st := _qs(id)
	if have > int(st["progress"]):
		st["progress"] = mini(have, int(cur["count"]))
		if int(st["progress"]) >= int(cur["count"]):
			Sfx.play("pickup_sigil")
			main.ui.toast("Done! Return to %s" % _def(id)["name"])


## The skill a quest trains: what you actually did (kill = combat, twigs and logs = woodcutting...).
func _reward_skill(cur: Dictionary) -> String:
	if cur.has("skill"):
		return cur["skill"]
	var tg := String(cur["target"])
	match String(cur["goal"]):
		"kill", "elite":
			return "combat"
		"gather":
			return "herblore"
		"craft":
			return "smithing"
		"fire":
			return "firemaking"
		"obtain":
			if tg in ["twig", "oak", "heartwood"]:
				return "woodcutting"
			if tg in ["copper", "bogiron", "frost"]:
				return "mining"
			if tg.ends_with("_bar"):
				return "smithing"
			if tg.begins_with("raw_"):
				return "fishing"
			if tg in ["minnow", "trout", "eel", "icefin"]:
				return "cooking"
			return "crafting"
	return ""    # talking and exploring pay gold, not XP


func _complete(id: String) -> void:
	var cur := current(id)
	var st := _qs(id)
	st["stage"] = int(st["stage"]) + 1
	st["active"] = false
	st["progress"] = 0
	Sfx.play("trophy", Vector3.INF, -4.0)
	main.ui.toast("Quest complete: %s" % cur["title"])
	var sk := _reward_skill(cur)
	if sk == "combat":
		main.gain_xp(int(cur["xp"]))
	elif sk != "":
		main.skills.add_xp(sk, int(cur["xp"]))
	main.add_gold(int(cur["gold"]))
	if cur.get("end_safe", false):
		main.state["tut_safe"] = false
		main.ui.toast("The wilds are open. Stay sharp.", Color("ffb070"))
	if cur.has("reward_mats"):
		var rm: Dictionary = cur["reward_mats"]
		for rk: String in rm:
			main.crafting.add_mat(rk, int(rm[rk]))
	if cur.has("reward_rarity"):
		var it := Items.generate(mini(main.player.level + 1, 20), main.player.class_id, int(cur["reward_rarity"]))
		if main.can_take_item():
			main.collect_item(it)
		else:
			main.combat._drop_item(main.player.global_position, it)
			main.ui.toast("Your bag is full. The reward is on the ground.")
	main.save_game()


# ================================================================ progress
func on_kill(e: Enemy) -> void:
	for q: Dictionary in Data.SIDE_QUESTS:
		var id: String = q["id"]
		if status(id) != "active":
			continue
		var cur := current(id)
		var hit := false
		if cur["goal"] == "kill" and not e.is_elite and e.type_id == cur["target"]:
			hit = true
		elif cur["goal"] == "elite" and e.is_elite and e.elite_id == cur["target"]:
			hit = true
		if hit:
			_advance(id, cur)


## Progress for the newer goal types: talk (target = smith / merchant / varka / wisp / giver id),
## obtain (target = material id), craft (any forge craft).
func notify(goal: String, target: String, n := 1) -> void:
	for q: Dictionary in Data.SIDE_QUESTS:
		var id: String = q["id"]
		if status(id) != "active":
			continue
		var cur := current(id)
		var tg: String = cur["target"]
		if cur["goal"] == goal and (tg == target or tg == "any" or target in tg.split("|")):
			_advance(id, cur, n)


func _advance(id: String, cur: Dictionary, n := 1) -> void:
	var st := _qs(id)
	st["progress"] = mini(int(st["progress"]) + n, int(cur["count"]))
	if int(st["progress"]) >= int(cur["count"]):
		if cur.get("auto", false):
			_complete(id)
			return
		Sfx.play("pickup_sigil")
		main.ui.toast("Done! Return to %s" % _def(id)["name"])
	# partial progress shows in the HUD tracker only, no pop-ups


func _ensure_gather(id: String) -> void:
	if status(id) != "active":
		return
	var cur := current(id)
	if cur["goal"] != "gather":
		return
	var have := 0
	for g: Dictionary in _gather:
		if g["quest"] == id:
			have += 1
	var need := int(cur["count"]) - int(_qs(id)["progress"]) + 2 - have
	var q := _def(id)
	var center: Vector3 = world.npc_pos[id]
	var tries := 0
	while need > 0 and tries < 200:
		tries += 1
		var a := randf() * TAU
		var d := randf_range(8.0, 28.0)
		var p := center + Vector3(cos(a), 0, sin(a)) * d
		if world.is_water(p.x, p.z) or world.biome_at(p) != int(q["biome"]):
			continue
		p.y = world.height_at(p.x, p.z)
		_spawn_plant(cur["target"], p, id)
		need -= 1


func _spawn_plant(kind: String, pos: Vector3, quest: String) -> void:
	var g: Dictionary = Data.GATHER[kind]
	var root := Node3D.new()
	add_child(root)
	root.global_position = pos
	var col := Color(g["color"])
	var s := Models.plant(kind)
	s.scale = Vector3.ONE * 1.6
	root.add_child(s)
	var l := OmniLight3D.new()
	l.light_color = col
	l.omni_range = 3.0
	l.light_energy = 1.2
	l.position.y = 0.7
	root.add_child(l)
	_gather.append({"node": root, "pos": pos, "type": kind, "quest": quest, "sprite": s})


func _process(delta: float) -> void:
	if main == null or main.mode == "title":
		return
	_t += delta
	var p: Vector3 = main.player.global_position
	var cam_right := Vector3.RIGHT.rotated(Vector3.UP, main.player.cam_yaw)
	# NPCs idle, face the player, show ! / ?
	for id: String in _npcs:
		var n: Dictionary = _npcs[id]
		_idle(n, p, cam_right)
		var mark: Label3D = n["mark"]
		match status(id):
			"available":
				mark.text = "!"
				mark.modulate = Color("ffd27a")
			"ready":
				mark.text = "?"
				mark.modulate = Color("ffd27a")
			"active":
				mark.text = "?"
				mark.modulate = Color("8a8496")
			_:
				mark.text = ""
		mark.position.y = 3.35 + sin(_t * 3.0) * 0.08
	_idle(_merchant, p, cam_right)
	_idle(_merchant2, p, cam_right)
	_idle(_merchant3, p, cam_right)
	for a: Dictionary in _ambient:
		_idle(a, p, cam_right)
		_chatter(a, p, delta)
	# the practice Mosslet for the abilities lesson
	if main.mode == "play" and status("tam") == "active" and current("tam").get("spawn", false):
		if _practice == null or not is_instance_valid(_practice) or _practice.dead:
			if int(_qs("tam")["progress"]) < int(current("tam")["count"]):
				var pp: Vector3 = world.camp_pos + Vector3(3.0, 0, -7.5)
				_practice = main.combat.spawn_enemy("mosslet", pp, 0)
	# plants
	for g: Dictionary in _gather.duplicate():
		(g["sprite"] as Node3D).rotation.y = sin(_t * 1.2 + float(g["pos"].x)) * 0.4
		if main.mode == "play" and _flat(p, g["pos"]) < 1.1:
			var id: String = g["quest"]
			_gather.erase(g)
			(g["node"] as Node).queue_free()
			if status(id) == "active":
				Sfx.play("pickup_sigil", Vector3.INF, -4.0)
				_advance(id, current(id))
	# elites appear when you approach their lair during the quest
	for q: Dictionary in Data.SIDE_QUESTS:
		var id: String = q["id"]
		if status(id) != "active":
			continue
		var cur := current(id)
		if cur["goal"] != "elite":
			continue
		var eid: String = cur["target"]
		var lair: Vector3 = world.npc_pos[eid]
		var alive: bool = _elites.has(eid) and is_instance_valid(_elites[eid]) and not (_elites[eid] as Enemy).dead
		if not alive and _flat(p, lair) < 40.0:
			_elites[eid] = main.combat.spawn_elite(eid, lair)
			main.ui.toast("%s is near!" % Data.ELITES[eid]["name"], Color("ff8a5a"))


func _idle(n: Dictionary, p: Vector3, _cam_right: Vector3) -> void:
	var s: Rig = n["sprite"]
	var to: Vector3 = p - (n["pos"] as Vector3)
	var near := Vector2(to.x, to.z).length()
	var w: Wanderer = n.get("wander")
	var walking := 0.0
	if w != null:
		# they pause and turn to you when you come close, or while their dialogue is open
		var stop: bool = near < TALK_RANGE + 1.6 or main.ui.dialog_open()
		var dir := w.step(get_process_delta_time(), world, self, stop)
		if dir != Vector3.ZERO:
			s.set_facing(dir)
			walking = 0.5
			n["pos"] = w.pos
			(n["node"] as Node3D).global_position = w.pos
	if walking == 0.0 and near < 12.0:
		s.set_facing(to)
	s.tick(get_process_delta_time(), walking)


## A short line in a speech bubble when you stroll past an ambient villager.
func _chatter(a: Dictionary, p: Vector3, delta: float) -> void:
	var node: Node3D = a["node"]
	var mark: Label3D = a["mark"]
	var near := _flat(p, a["pos"]) < 5.0
	a["say_t"] = float(a["say_t"]) - delta
	if float(a.get("show_t", 0.0)) > 0.0:
		a["show_t"] = float(a["show_t"]) - delta
		if float(a["show_t"]) <= 0.0:
			mark.text = ""
	elif near and float(a["say_t"]) <= 0.0:
		var lines: Array = a["lines"]
		mark.text = lines[randi() % lines.size()]
		mark.modulate = Color("f1e8d4")
		mark.font_size = 45
		a["show_t"] = 3.5
		a["say_t"] = randf_range(9.0, 16.0)
	if mark.text != "":
		mark.position.y = 3.35
	node.visible = true


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# ================================================================ HUD + map
func tracker() -> Array:
	var out: Array = []
	for q: Dictionary in Data.SIDE_QUESTS:
		var id: String = q["id"]
		if id == "tam":
			continue    # shown at the top of the HUD instead
		var stt := status(id)
		if stt == "active":
			var cur := current(id)
			out.append([cur["title"], "%s %d/%d" % [cur["label"], _qs(id)["progress"], cur["count"]]])
		elif stt == "ready":
			out.append([current(id)["title"], "Return to %s" % q["name"]])
	return out


## The Wanderer's Rest tutorial, shown at the top of the HUD tracker instead of the main quest.
func tutorial_info() -> Dictionary:
	if main.state.is_empty():
		return {}
	for id: String in ["tam", "king"]:
		var stt := status(id)
		if stt == "done":
			continue
		var def := _def(id)
		var cur := current(id)
		var title: String = String(cur["title"]) if id == "tam" else "The King's Charge"
		var text := ""
		match stt:
			"available":
				text = "Speak with %s%s." % [def["name"], " by the campfire" if id == "tam" else " in the keep"]
			"ready":
				text = "Return to %s." % def["name"]
			_:
				text = String(cur.get("tip", cur["label"]))
				if int(cur["count"]) > 1:
					text = "%s %d/%d" % [cur["label"], _qs(id)["progress"], cur["count"]]
		var info := {"title": title, "text": text, "rec": ""}
		if stt == "active" and cur.has("checks"):
			info["title"] = "%s:" % cur.get("head", "Craft")
			info["text"] = ""
			var rows: Array = []
			for c: Dictionary in cur["checks"]:
				rows.append([c["label"], main.crafting.count(c["item"]) > 0])
			info["checks"] = rows
		return info
	return {}


## Which HUD button should pulse for the current tutorial step ("" = none).
func tutorial_pulse() -> String:
	if main.state.is_empty() or status("tam") != "active":
		return ""
	return String(current("tam").get("pulse", ""))


func _nearest_node(mat: String, from: Vector3) -> Vector3:
	var best := Vector3.INF
	var bd := INF
	for n: Dictionary in main.crafting._nodes:
		if n["mat"] != mat or float(n["ready_t"]) > 0.0:
			continue
		var d := _flat(from, n["pos"])
		if d < bd:
			bd = d
			best = n["pos"]
	return best


## Where the guide sparkle points: the next thing to do in the opening tutorial.
func guide_target() -> Dictionary:
	if main.state.is_empty():
		return {}
	var me: Vector3 = main.player.global_position
	var tam := status("tam")
	if tam != "done":
		var tp: Vector3 = world.npc_pos["tam"]
		if tam == "available" or tam == "ready":
			return {"pos": tp, "label": "Old Tam", "h": 4.3}
		match int(_qs("tam")["stage"]):
			0:
				var b := _nearest_node("twig", me)
				return {"pos": b, "label": "Brush", "h": 2.2} if b != Vector3.INF else {"pos": tp, "label": "Old Tam", "h": 4.3}
			1:
				return {}
			2:
				var o := _nearest_node("oak", me)
				return {"pos": o, "label": "Oak tree", "h": 4.5} if o != Vector3.INF else {}
			4:
				return {"pos": world.camp_fish_pos, "label": "Fishing spot", "h": 2.0}
			5:
				var best := world.camp_pos
				var bd := INF
				for fp: Vector3 in main.skills.all_fires():
					if _flat(me, fp) < bd:
						bd = _flat(me, fp)
						best = fp
				return {"pos": best, "label": "Fire", "h": 2.4}
			7:
				if _practice != null and is_instance_valid(_practice) and not _practice.dead:
					return {"pos": _practice.global_position, "label": "Mosslet", "h": 2.4}
				return {}
			8:
				return {"pos": world.npc_pos["king"], "label": "King Aldren", "h": 4.3}
		return {}
	var ks := status("king")
	if ks == "available":
		return {"pos": world.npc_pos["king"], "label": "King Aldren", "h": 4.3}
	if ks == "active":
		return {"pos": world.npc_pos["rowan"], "label": "Elder Rowan", "h": 4.3}
	return {}


func map_markers() -> Array:
	var m: Array = []
	m.append({"cell": world.world_to_cell(world.camp_pos), "color": Color("e8a050"), "size": 3.0})
	for q: Dictionary in Data.SIDE_QUESTS:
		var id: String = q["id"]
		var stt := status(id)
		var cell := world.world_to_cell(world.npc_pos[id])
		if stt == "available" or stt == "ready":
			m.append({"cell": cell, "color": Color("ffd27a"), "size": 3.0, "pulse": stt == "ready", "glyph": "?" if stt == "ready" else "!"})
		elif stt == "active":
			m.append({"cell": cell, "color": Color("a89dba"), "size": 2.5})
			var cur := current(id)
			if cur["goal"] == "elite":
				m.append({"cell": world.world_to_cell(world.npc_pos[cur["target"]]), "color": Color("ff8a5a"), "size": 3.5, "pulse": true})
	return m
