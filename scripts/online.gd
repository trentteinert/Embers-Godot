class_name Online
extends Node
## Online mode: the real game as a client of the Embers server (see server/PROTOCOL.md).
##
## The server owns the rules: movement, combat, loot, quests, saving. This node sends your intentions
## (input, casts, clicks) and mirrors what comes back into the game's own structures (`main.state`,
## the player, proxy enemies, pickups), so the existing HUD, inventory, shop and quest screens just work.
##
## Start the game with:  --online ws://host:port --account NAME --password PW [--register] [--class warrior|mage|hunter]
## (guest, nothing saved, if the server allows it: --online ws://host:port --class mage --name Bob)

static var active := false          # true once online mode was requested; cheap to test from hooks

var main: Node
var url := ""
var account := ""
var password := ""
var register := false
var guest_class := "warrior"
var guest_name := "Guest"
var self_test := false              # scripted headless bot, see _bot()
var skill_test := false             # scripted skilling bot, see _skill_bot()
var quest_test := false             # scripted tutorial bot, see _quest_bot()

var my_id := -1
var started := false
var chr: Dictionary = {}
var inv: Dictionary = {}
var journal: Array = []
var npcs: Dictionary = {}
var remote: Dictionary = {}         # player id -> RemotePlayer
var mobs: Dictionary = {}           # mob id -> Enemy (proxy)
var drops: Dictionary = {}          # drop id -> pickup dict in combat._pickups
var plants: Dictionary = {}         # plant id -> Node3D
var gear_cache: Dictionary = {}     # player id -> equipment dict
var snap: Dictionary = {}
var nodes: Dictionary = {}          # server node id -> {data, root, pos}
var recipes: Array = []             # the Workshop's recipe book (server sends what is missing)
var skill_levels: Dictionary = {}   # skill id -> {level, xp_into, xp_next, next}
var task: Dictionary = {}           # Slayer task
var ui2: OnlineUI
var _known_ok: Dictionary = {}      # recipe id -> could make it last time (for the "you can make X" nudge)
var _nudged: Dictionary = {}
var _nudge_t := 0.0
var _chat_ready := false

var _ws: WebSocketPeer = WebSocketPeer.new()
var _ws_state := -1
var _my_target := Vector3.ZERO
var _srv_air := false
var server_speed := 0.0   # walking pace the server uses for us; the game's own movement is scaled to match
var _in_t := 0.0
var _idle_t := 0.0
const SNAP_DIST := 5.0    # farther than this from the server and we jump to it
const DRIFT_OK := 2.5     # while moving, this much lead over the server's (older) position is normal
var _have_pos := false
var _last_dir := Vector2(9, 9)
var _last_aim := Vector2.ZERO
var _last_sprint := false
var _aim_t := 0.0
var _want_attack := false
var _sent_target := -2
var _sent_bar := -1
var _bar_t := 0.0
var _shot_nodes: Array[MeshInstance3D] = []
var _disconnected := false
var _was_dead := false
var _kind_color := {"fire": Color("ff7a3a"), "arrow": Color("ffe9a8"), "knife": Color("d8dce6"), "bolt": Color("c49bff"), "orb": Color("ff5a4a")}

# self-test bookkeeping
var _t := 0.0
var _netlog: PackedStringArray = PackedStringArray()
var _netlog_on := false
## The server feature level this game expects (see protocol::BUILD): 2 = work poses and the stop position.
const SERVER_BUILD_NEEDED := 3
var work_pose := ""   # the skilling pose the server says we are in ("" = none); skills.gd leaves it alone while this is set
var _work_sfx := 0.0
var _seen := {}


## Set by the login screen (online_login.gd): url, account, password, register, class, world, auto. It stays
## across a restart of the scene, which is how a different world gets loaded.
static var cfg: Dictionary = {}


static func requested() -> bool:
	return OS.get_cmdline_user_args().has("--online") or bool(cfg.get("auto", false))


static func arg(name: String, default := "") -> String:
	if bool(cfg.get("auto", false)):
		var keys := {"--online": "url", "--account": "account", "--password": "password", "--class": "class", "--name": "account"}
		if keys.has(name):
			return str(cfg.get(keys[name], default))
	var a: PackedStringArray = OS.get_cmdline_user_args()
	var i: int = a.find(name)
	return a[i + 1] if i >= 0 and i + 1 < a.size() else default


## Called from Main._ready (after everything else is set up). Returns null unless --online was given.
static func try_start(m: Node) -> Online:
	if not requested():
		return null
	var o: Online = Online.new()
	o.name = "Online"
	m.add_child(o)
	o.setup(m)
	return o


func setup(m: Node) -> void:
	main = m
	active = true
	url = arg("--online", "ws://127.0.0.1:7777")
	account = arg("--account")
	password = arg("--password")
	register = OS.get_cmdline_user_args().has("--register") or bool(cfg.get("register", false))
	guest_class = arg("--class", "warrior")
	guest_name = arg("--name", "Guest")
	self_test = OS.get_cmdline_user_args().has("--online-bot")
	skill_test = OS.get_cmdline_user_args().has("--online-skill-bot")
	quest_test = OS.get_cmdline_user_args().has("--online-quest-bot")
	main.ui.hide_title()
	main.ui.toast("Connecting to %s ..." % url)
	var err: Error = _ws.connect_to_url(url)
	if err != OK:
		main.ui.toast("Cannot connect: %s" % error_string(err), Color("ff8a6a"))


func send(d: Dictionary) -> void:
	if _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_ws.send_text(JSON.stringify(d))


# ================================================================ network
func _process(delta: float) -> void:
	_t += delta
	_ws.poll()
	var st: int = _ws.get_ready_state()
	if st != _ws_state:
		_ws_state = st
		if st == WebSocketPeer.STATE_OPEN:
			_login()
		elif st == WebSocketPeer.STATE_CLOSED and not started and bool(cfg.get("auto", false)):
			_fail("Cannot reach the server at %s. Is it running?" % url)
			return
		elif st == WebSocketPeer.STATE_CLOSED and not _disconnected:
			_disconnected = true
			main.ui.toast("Disconnected from the server", Color("ff8a6a"))
			if self_test:
				print("ONLINE-BOT FAIL disconnected")
				get_tree().quit(1)
	while st == WebSocketPeer.STATE_OPEN and _ws.get_available_packet_count() > 0:
		var parsed: Variant = JSON.parse_string(_ws.get_packet().get_string_from_utf8())
		if parsed is Dictionary:
			_on_message(parsed)
	if not started and bool(cfg.get("auto", false)) and _t > 20.0:
		_fail("The server did not answer. Check the address.")
		return
	if started:
		_sync_intent(delta)
	if self_test:
		_bot(delta)
	if skill_test:
		_skill_bot(delta)
	if quest_test:
		_quest_bot(delta)
	if OS.get_cmdline_user_args().has("--online-stairs-bot"):
		_stairs_bot(delta)
	if OS.get_cmdline_user_args().has("--online-soak"):
		_soak(delta)
	var shot: String = arg("--online-shot")
	if shot != "" and started and _t > float(arg("--online-shot-after", "20")):
		get_viewport().get_texture().get_image().save_png(shot)
		print("saved ", shot)
		get_tree().quit(0)


## Login failed (wrong password, name taken, server down): back to the login screen with the reason.
func _fail(msg: String) -> void:
	var keep := cfg.duplicate()
	keep["auto"] = false
	keep["error"] = msg
	keep.erase("password")
	cfg = keep
	active = false
	get_tree().reload_current_scene()


func _login() -> void:
	if account != "":
		send({"t": "register" if register else "login", "name": account, "password": password, "class": guest_class})
	else:
		send({"t": "join", "name": guest_name, "class": guest_class})


func _on_message(m: Dictionary) -> void:
	match str(m.get("t", "")):
		"welcome":
			my_id = int(m["you"])
			var sb: int = int(m.get("build", 0))
			if sb < SERVER_BUILD_NEEDED:
				main.ui.toast("This server is out of date (build %d, the game needs %d): no work animations or smooth stops. Stop it and run ./start_server.command again." % [sb, SERVER_BUILD_NEEDED], Color("ff8a6a"))
			else:
				print("server build ", sb)
		"npcs":
			for n: Dictionary in m["list"]:
				npcs[str(n["id"])] = n
		"character":
			chr = m
			if started:
				_apply_character()
		"inventory":
			inv = m
			if started:
				_apply_inventory()
		"journal":
			journal = m["entries"]
			if started:
				_apply_journal()
		"shop":
			_on_shop(m)
		"dialogue":
			var lines: Array = []
			for ln: Array in m["lines"]:
				lines.append([str(ln[0]), str(ln[1])])
			main.ui.say(lines)
		"notice":
			main.ui.toast(str(m["text"]))
		"gear":
			gear_cache[int(m["player"])] = m["equip"]
			if remote.has(int(m["player"])):
				(remote[int(m["player"])] as RemotePlayer).set_gear(m["equip"])
		"snapshot":
			snap = m
			_on_snapshot(m)
		"events":
			for e: Variant in m["events"]:
				_on_event(e)
		"skills":
			_apply_skills(m)
		"recipes":
			_apply_recipes(m["list"])
		"nodes":
			_sync_nodes(m["upsert"], m["gone"])
		"chat":
			_seen["chat"] = true
			_on_chat(m)
		"rejected":
			var why: String = str(m["why"])
			if quest_test:
				print("QB reject: ", m)
			main.ui.toast(why.substr(0, 1).to_upper() + why.substr(1), Color("e0a080"))
		"error":
			if not started and bool(cfg.get("auto", false)):
				_fail(str(m["msg"]).substr(0, 1).to_upper() + str(m["msg"]).substr(1))
				return
			main.ui.toast("Server: %s" % m["msg"], Color("ff8a6a"))
			if self_test and not started:
				print("ONLINE-BOT FAIL server error: %s" % m["msg"])
				get_tree().quit(1)


# ================================================================ entering the world
## People are not solid online (the server does not collide you with them either): walk through, don't get shoved.
func _npcs_passable(n: Node) -> void:
	for c in n.get_children():
		if c is StaticBody3D:
			(c as StaticBody3D).collision_layer = 0
		else:
			_npcs_passable(c)


func _ready_to_start() -> bool:
	return my_id >= 0 and not chr.is_empty() and not inv.is_empty() and _have_pos and not started


func _begin_play() -> void:
	started = true
	_npcs_passable(main.quests)
	var cls: String = str(chr["class"])
	main.state = {"cls": cls, "look": {}, "name": account if account != "" else guest_name, "lvl": int(chr["level"]), "xp": 0, "potions": 0, "shards": 0,
		"bi": 0, "step": 0, "runes": [false, false, false, false], "done": false, "bag": [], "equip": {}, "gold": 0, "shop": [], "quests": {}, "mats": {},
		"skills": {}, "tools": {}, "bag_lvl": 0, "slayer": {}, "kit": true, "tut_safe": false, "tod": 0.3, "bar": [-1, -1, -1, -1, -1, -1]}
	main.world.reset_fog()
	_apply_character(false)
	_apply_inventory(false)
	_apply_journal()
	main.player.look = {}
	main.player.setup(cls, int(chr["level"]), true, 0)
	main.player.teleport(_my_target)
	main._begin_play()
	ui2 = OnlineUI.new()
	ui2.name = "OnlineUI"
	main.add_child(ui2)
	ui2.setup(self)
	_setup_chat()
	_apply_recipes(recipes)
	main.ui.toast("Welcome, %s" % main.state["name"])
	main.ui.chat_say("J = Workshop (recipes) · U = skills · Enter = chat · click trees, rocks, plants and ripples to gather", Color("9a8fa8"))
	if OS.get_cmdline_user_args().has("--online-fill-bar"):
		var bar: Array = [-1, -1, -1, -1, -1, -1]
		var n: int = 0
		for i in (Data.ABILITIES[cls] as Array).size():
			if n < 6 and main.ability_locked(i) == "":
				bar[n] = i
				n += 1
		main.state["bar"] = bar
		main.ui.build_ability_bar(cls)
	var talk_to: String = arg("--online-talk")
	if talk_to != "":
		get_tree().create_timer(1.5).timeout.connect(func() -> void: main.quests.talk(talk_to))
	var open_tab: String = arg("--online-open")
	if open_tab != "":
		get_tree().create_timer(1.0).timeout.connect(func() -> void: main.ui.toggle_side(open_tab))


func _apply_character(refresh := true) -> void:
	var s: Dictionary = main.state
	var lvl: int = int(chr["level"])
	var changed: bool = int(s.get("lvl", 0)) != lvl or str(s.get("cls", "")) != str(chr["class"])
	s["cls"] = str(chr["class"])
	s["lvl"] = lvl
	s["xp"] = int(chr["xp_into_level"])
	s["xp_need"] = int(chr["xp_next"]) if int(chr["xp_next"]) > 0 else 1
	s["gold"] = int(chr["gold"])
	var sk: Dictionary = s.get("skills", {})
	sk[Data.COMBAT_SKILL[s["cls"]]] = int(chr["xp"])
	s["skills"] = sk
	var talents: Dictionary = {}
	for pair: Array in chr["talents"]:
		talents[str(pair[0])] = int(pair[1])
	s["talents"] = talents
	if refresh:
		if changed:
			main.player.setup(s["cls"], lvl, false, 0)
			main.ui.build_ability_bar(main.player.class_id)
		main.player.refresh_stats()
		main.ui.refresh_window()


func _apply_inventory(refresh := true) -> void:
	var s: Dictionary = main.state
	s["bag"] = inv["bag"]
	s["equip"] = inv["equip"]
	var mats: Dictionary = (inv["mats"] as Dictionary).duplicate()
	s["potions"] = int(mats.get("hpot", 0))
	mats.erase("hpot")
	var tools: Dictionary = {}
	for k: String in mats.keys():
		if k.begins_with("sturdy_"):
			tools[k.trim_prefix("sturdy_")] = true
			mats.erase(k)
	s["tools"] = tools
	for k: String in mats.keys():
		mats[k] = int(mats[k])
	s["mats"] = mats
	main._apply_gear(refresh)
	if refresh:
		main.ui.refresh_inventory()


func _apply_journal() -> void:
	var q: Dictionary = {}
	for g: Dictionary in Data.SIDE_QUESTS:
		q[g["id"]] = {"stage": (g["quests"] as Array).size(), "active": false, "progress": 0, "met": true}
	for e: Dictionary in journal:
		q[str(e["npc"])] = {"stage": int(e["stage"]), "active": bool(e["active"]), "progress": int(e["progress"]), "met": bool(e["met"])}
	main.state["quests"] = q


func _on_shop(m: Dictionary) -> void:
	var stock: Array = []
	for entry: Dictionary in m["stock"]:
		stock.append(entry["item"])
	main.state["shop"] = stock
	if not main.shop_open:
		main.shop_open = true
		main.ui.close_side()
		main.ui.show_shop(true)
	else:
		main.ui.refresh_shop()


# ================================================================ the world each tick
func _w3(a: Variant, y: float) -> Vector3:
	var arr: Array = a
	return Vector3(float(arr[0]), y, float(arr[1]))


func _on_snapshot(s: Dictionary) -> void:
	if not started:
		# until play begins (combat.reset() clears everything) we only need our own position
		for v0: Dictionary in s["players"]:
			if int(v0["id"]) == my_id:
				_apply_me(v0)
		if _ready_to_start():
			_begin_play()
		return
	var seen_p: Dictionary = {}
	for v: Dictionary in s["players"]:
		var id: int = int(v["id"])
		seen_p[id] = true
		if id == my_id:
			_apply_me(v)
			continue
		if not remote.has(id):
			var rp: RemotePlayer = RemotePlayer.new()
			rp.setup(str(v["class"]), str(v["name"]), gear_cache.get(id, {}))
			main.add_child(rp)
			remote[id] = rp
			rp.global_position = _w3(v["pos"], float(v["y"]))
		(remote[id] as RemotePlayer).apply(v, main.world)
	for id: int in remote.keys():
		if not seen_p.has(id):
			(remote[id] as RemotePlayer).queue_free()
			remote.erase(id)
	_sync_mobs(s["mobs"])
	_sync_drops(s["drops"])
	_sync_plants(s["plants"])
	_sync_shots(s["shots"])


func _apply_me(v: Dictionary) -> void:
	var p: Player = main.player
	# the server knows about floors, stairs and jumps; follow the terrain you can see where it differs from the server's grid
	var dh: float = main.world.height_at(float(v["pos"][0]), float(v["pos"][1])) - main.world.grid_height_at(float(v["pos"][0]), float(v["pos"][1]))
	_my_target = _w3(v["pos"], float(v["y"]) + dh + 0.02)
	_srv_air = bool(v.get("air", false))
	server_speed = float(v.get("spd", 0.0))
	if not _have_pos:
		_have_pos = true
	if not started:
		return
	p.hp = float(v["hp"])
	p.max_hp = float(v["max_hp"])
	p.res = float(v["res"])
	p.res_max = float(v["res_max"])
	p.sta = float(v["sta"])
	p.sta_max = float(v["sta_max"])
	var b: Dictionary = {}
	for name: String in v["buffs"]:
		b[name] = 2.0
	p.buffs = b
	p.shield = 1.0 if b.has("barrier") else 0.0
	# cooldowns: the server sends (ability id, seconds left)
	var cd: Dictionary = {}
	for pair: Array in v["cooldowns"]:
		cd[str(pair[0])] = float(pair[1])
	var abil: Array = Data.ABILITIES[p.class_id]
	for i in abil.size():
		main.combat.cooldowns[i] = float(cd.get(str(abil[i]["id"]), 0.0))
	var dead: bool = bool(v["dead"])
	if dead and main.mode == "play":
		main.player_died()
	elif not dead and main.mode == "dead":
		main.mode = "play"
		main.ui.show_dead(false)
		p.dead = false
		p.teleport(_my_target)
		main.rig.snap()
	main.state["gold"] = int(chr.get("gold", 0))
	_show_action(v)
	_sync_work(v)


## The skilling poses of the original game (chop, mine, gather, fish, cook ...) while the server says we are working: the
## right tool comes out, we face the work, and each swing that lands plays its sound and a puff of chips.
func _sync_work(v: Dictionary) -> void:
	var p: Player = main.player
	if p == null or p.model == null:
		return
	var wk := str(v.get("work", ""))
	work_pose = wk
	if wk == "":
		if p.model.work_kind != "":
			p.model.set_work("")
		return
	var at := _work_target(wk, p.global_position)
	if at != Vector3.INF:
		p.model.set_facing(at - p.global_position)
	p.model.set_work(wk, _tool_col(wk))
	p.model.on_work_hit = _work_hit.bind(wk, at)
	if wk in ["cook", "brew"] and _t >= _work_sfx:
		_work_sfx = _t + 0.85
		Sfx.play({"cook": "fire_cast", "brew": "potion"}[wk], Vector3.INF, -12.0, 0.15)


## The nearest thing we are working on (a tree, rock, ripple or fire), or INF.
func _work_target(wk: String, from: Vector3) -> Vector3:
	var best := Vector3.INF
	var bd := 5.0
	for id: Variant in nodes.keys():
		var d: Dictionary = nodes[id]["data"]
		var kind := str(d.get("kind", ""))
		var ok := false
		match wk:
			"fish":
				ok = kind == "fish"
			"cook":
				ok = kind == "fire"
			"chop", "mine", "gather":
				ok = kind != "fish" and kind != "fire"
		if not ok:
			continue
		var pos: Vector3 = nodes[id]["pos"]
		var dist := Vector2(pos.x - from.x, pos.z - from.z).length()
		if dist < bd:
			bd = dist
			best = pos
	return best


## Metal colour of the tool in hand, by tier (pickaxe and axe lines), as the game does it.
func _tool_col(wk: String) -> String:
	var line: String = {"mine": "pickaxe", "chop": "axe"}.get(wk, "")
	if line == "" or not Data.TOOL_LINES.has(line):
		return "a3adba"
	var best := -1
	var ids: Array = Data.TOOL_LINES[line]
	for i in ids.size():
		if inv_count(str(ids[i])) > 0:
			best = i
	return (["8a6a44", "a3adba", "6a8a5a", "9fe0ff"] as Array)[clampi(best, 0, 3)]


func _work_hit(wk: String, at: Vector3) -> void:
	var p: Player = main.player
	if p == null or p.model == null:
		return
	var snd := "equip"
	var col := Color("a07a4a")
	match wk:
		"chop":
			snd = "hit"
		"mine":
			col = Color("b0b4bc")
		"smith":
			col = Color("ffb050")
		"craft":
			col = Color("c8a878")
	Sfx.play(snd, Vector3.INF, -10.0, 0.15)
	var on_node: bool = at != Vector3.INF and wk in ["chop", "mine", "gather"]
	var where: Vector3 = at if on_node else p.global_position + p.model.global_basis.z.normalized() * 0.8
	main.combat.burst(where + Vector3(0, 1.0 if on_node else 0.9, 0), col, 6, 2.5, 0.5, 0.1)


func _sync_mobs(list: Array) -> void:
	var seen: Dictionary = {}
	for v: Dictionary in list:
		var id: int = int(v["id"])
		seen[id] = true
		var e: Enemy = mobs.get(id)
		if e == null or not is_instance_valid(e):
			e = _make_mob(v)
			mobs[id] = e
		var pos: Vector3 = _w3(v["pos"], main.world.height_at(float(v["pos"][0]), float(v["pos"][1])))
		e.net_pos = pos
		e.hp = float(v["hp"])
		e.max_hp = float(v["max_hp"])
	for id: int in mobs.keys():
		if not seen.has(id):
			_remove_mob(id, false)


func _make_mob(v: Dictionary) -> Enemy:
	var e: Enemy = Enemy.new()
	var pos: Vector3 = _w3(v["pos"], main.world.height_at(float(v["pos"][0]), float(v["pos"][1])))
	var biome: int = main.world.biome_at(pos)
	if v.has("elite"):
		e.setup_elite(main.combat, str(v["elite"]), biome)
	else:
		e.setup_enemy(main.combat, str(v["kind"]), biome)
	e.proxy = true
	e.server_id = int(v["id"])
	e.collision_layer = 0
	e.collision_mask = 0
	e.max_hp = float(v["max_hp"])
	e.hp = float(v["hp"])
	e.level = main.world.rec_level(pos)
	main.combat.add_child(e)
	e.global_position = pos
	e.net_pos = pos
	main.combat.enemies.append(e)
	return e


func _remove_mob(id: int, died: bool) -> void:
	var e: Enemy = mobs.get(id)
	mobs.erase(id)
	if e == null or not is_instance_valid(e):
		return
	if died:
		main.combat.burst(e.center(), Color("a8a0b0"), 16, 5.0, 0.6, 0.2)
		Sfx.play("enemy_die", e.global_position, -3.0)
	e.dead = true
	main.combat.enemies.erase(e)
	if main.target == e:
		main.target = null
	e.queue_free()


func _sync_drops(list: Array) -> void:
	var seen: Dictionary = {}
	for v: Dictionary in list:
		var id: int = int(v["id"])
		seen[id] = true
		if drops.has(id):
			(drops[id] as Dictionary)["name"] = str(v["name"])
			continue
		var pos: Vector3 = _w3(v["pos"], main.world.height_at(float(v["pos"][0]), float(v["pos"][1])))
		var rig: Rig
		var col: Color = Color("ffd27a")
		var kind: String = "loot"
		if v["kind"] == "item":
			col = Color(Items.RARITY_COLORS[clampi(int(v["rarity"]), 0, 4)])
			kind = "item"
		rig = Models.loot_bag(col)
		rig.scale = Vector3.ONE * (1.5 if kind == "item" else 1.1)
		var root: Node3D = Node3D.new()
		main.combat.add_child(root)
		root.add_child(rig)
		root.global_position = pos
		var entry: Dictionary = {"node": root, "sprite": rig, "pos": pos, "kind": kind, "t": 0.0, "name": str(v["name"]), "color": col, "server_id": id, "loot": {}, "item": {}}
		main.combat._pickups.append(entry)
		drops[id] = entry
	for id: int in drops.keys():
		if not seen.has(id):
			var d: Dictionary = drops[id]
			drops.erase(id)
			main.combat._pickups.erase(d)
			if is_instance_valid(d["node"]):
				(d["node"] as Node).queue_free()


func _sync_plants(list: Array) -> void:
	var seen: Dictionary = {}
	for v: Dictionary in list:
		var id: int = int(v["id"])
		seen[id] = true
		if plants.has(id):
			continue
		var root: Node3D = Node3D.new()
		main.add_child(root)
		root.global_position = _w3(v["pos"], main.world.height_at(float(v["pos"][0]), float(v["pos"][1])))
		var rig: Rig = Models.plant(str(v["kind"]))
		rig.scale = Vector3.ONE * 1.6
		root.add_child(rig)
		var l: OmniLight3D = OmniLight3D.new()
		l.light_color = Color(Data.GATHER[str(v["kind"])]["color"])
		l.omni_range = 3.0
		l.light_energy = 1.2
		l.position.y = 0.7
		root.add_child(l)
		plants[id] = root
	for id: int in plants.keys():
		if not seen.has(id):
			(plants[id] as Node).queue_free()
			plants.erase(id)


func _sync_shots(list: Array) -> void:
	while _shot_nodes.size() < list.size():
		var mi: MeshInstance3D = MeshInstance3D.new()
		var sm: SphereMesh = SphereMesh.new()
		sm.radius = 0.18
		sm.height = 0.36
		mi.mesh = sm
		main.add_child(mi)
		_shot_nodes.append(mi)
	for i in _shot_nodes.size():
		_shot_nodes[i].visible = i < list.size()
		if i < list.size():
			var sh: Dictionary = list[i]
			_shot_nodes[i].global_position = _w3(sh["pos"], float(sh["y"]))
			var m: StandardMaterial3D = StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = Color("ff5a4a") if sh["hostile"] else _kind_color.get(str(sh["kind"]), Color("ffd27a"))
			_shot_nodes[i].material_override = m


# ================================================================ events -> effects
const ABILITY_SOUND := {
	"cleave": "swing_heavy", "charge": "dash", "whirl": "swing_heavy", "shout": "buff", "slam": "slam", "stand": "shield",
	"backstab": "swing", "step": "dash", "fan": "swing", "poison": "buff", "smoke": "smoke", "flurry": "buff", "stealth": "smoke", "assassinate": "swing", "venomburst": "buff",
	"fireball": "fire_cast", "blink": "blink", "nova": "frost", "barrier": "shield", "chain": "lightning", "meteor": "meteor_fall",
	"power": "bow", "disengage": "dodge", "volley": "bow", "trap": "ui_click", "rain": "bow", "wolf": "howl", "strike": "swing_heavy",
}
## ability -> [kind, size, colour]; "ring" = area burst around the caster, "melee" = a swing arc, "burst" = self effect
const ABILITY_FX := {
	"strike": ["melee", 2.4, "ffd8a0"], "cleave": ["melee", 2.9, "ffb080"], "backstab": ["melee", 1.9, "ff6a7a"],
	"whirl": ["ring", 3.0, "ffe0a0"], "slam": ["ring", 3.9, "c8a070"], "nova": ["ring", 4.0, "9fe0ff"], "smoke": ["ring", 4.0, "8a8a9a"],
	"shout": ["burst", 3.6, "ff8a5a"], "stand": ["burst", 1.5, "c0c8d4"], "poison": ["burst", 1.5, "6ab040"], "flurry": ["burst", 1.5, "ffd27a"],
	"stealth": ["burst", 1.5, "3a3458"], "barrier": ["burst", 1.2, "c0a0ff"], "wolf": ["burst", 2.0, "7ac8f0"], "blink": ["burst", 1.5, "b080ff"],
	"charge": ["burst", 1.5, "c0802e"], "step": ["burst", 1.5, "7a1e2c"], "assassinate": ["burst", 1.5, "7a1e2c"], "disengage": ["burst", 1.2, "507a44"],
	"venomburst": ["ring", 3.0, "6ac040"],
}


func _player_node(id: int) -> Node3D:
	return main.player if id == my_id else remote.get(id)


func _on_event(e: Variant) -> void:
	if e is String:
		return
	var d: Dictionary = e
	if d.has("Cast"):
		var c: Dictionary = d["Cast"]
		_on_cast_event(int(c["player"]), c["event"])
	elif d.has("PlayerHurt"):
		var h: Dictionary = d["PlayerHurt"]
		var n: Node3D = _player_node(int(h["player"]))
		if n != null and int(h["amount"]) > 0:
			main.combat.float_text(n.global_position + Vector3(0, 2.3, 0), "-%d" % int(h["amount"]), Color("ff6a5a"))
			main.combat.burst(n.global_position + Vector3(0, 1.0, 0), Color("d9483b"), 8, 3.0, 0.35)
			if int(h["player"]) == my_id:
				main.rig.shake = minf(0.6, main.rig.shake + 0.3)
				Sfx.play("hurt", Vector3.INF, -3.0)
	elif d.has("MobDied"):
		var md: Dictionary = d["MobDied"]
		_remove_mob(int(md["mob"]), true)
		if int(md["killer"]) == my_id:
			_seen["killed"] = true
	elif d.has("LevelUp"):
		var lv: Dictionary = d["LevelUp"]
		var n2: Node3D = _player_node(int(lv["player"]))
		if n2 != null:
			main.combat.ring(n2.global_position, 3.0, Color("ffd27a"), 0.6)
			main.combat.burst(n2.global_position + Vector3(0, 1.0, 0), Color("ffd27a"), 26, 6.0, 0.8)
		if int(lv["player"]) == my_id:
			Sfx.play("level_up")
			main.ui.toast("Level %d!" % int(lv["level"]), Color("ffd27a"))
	elif d.has("Looted"):
		var lt: Dictionary = d["Looted"]
		if int(lt["player"]) == my_id:
			Sfx.play("loot", Vector3.INF, -6.0)
			var what: String = str(lt["what"])
			var hauled: bool = what.contains(" x") and what.substr(what.rfind(" x") + 2).is_valid_int()
			main.ui.toast(("+ %s" % what) if hauled else ("Got %s" % what), Color("ffd27a"))
			_seen["looted"] = true
	elif d.has("SkillUp"):
		var su: Dictionary = d["SkillUp"]
		if int(su["player"]) == my_id:
			Sfx.play("level_up", Vector3.INF, -4.0)
			main.combat.ring(main.player.global_position, 2.2, Color(Data.SKILLS[str(su["skill"])]["color"]), 0.6)
	elif d.has("QuestNotice"):
		var qn: Dictionary = d["QuestNotice"]
		if int(qn["player"]) == my_id:
			main.ui.toast(str(qn["text"]), Color("ffe8a8"))
			_seen["quest"] = true


## An auto attack (the class basic attack) by player `pid`: swing, shoot or cast, with the game's own sound and white slash.
func _on_basic_attack(pid: int, n: Node3D, ab: String) -> void:
	var cls: String = main.player.class_id if pid == my_id else (n as RemotePlayer).class_id
	var bolt: bool = ab == "basic_bolt"
	if pid == my_id:
		if bolt:
			main.player.anim_cast(0.25, false)   # false: do not turn the character toward the enemy
		else:
			main.player.anim_attack(0.3, false)
	else:
		(n as RemotePlayer).play_attack(bolt)
	match ab:
		"basic_melee":
			Sfx.play("swing_heavy" if cls == "warrior" else "swing", n.global_position, -6.0)
			var cc: Dictionary = Data.CLASS_COMBAT.get(cls, Data.CLASS_COMBAT["warrior"])
			var fwd: Vector3 = main.player.aim_dir if pid == my_id else (n as RemotePlayer).face
			main.combat.slash(n.global_position, fwd, float(cc.get("range", 2.3)), float(cc.get("arc", 2.2)), Color("fff4d8"))
		"basic_bolt":
			Sfx.play("bolt", n.global_position, -8.0)
		"basic_arrow":
			Sfx.play("bow", n.global_position, -6.0)


func _on_cast_event(pid: int, ev: Variant) -> void:
	if ev is String:
		return
	var d: Dictionary = ev
	var n: Node3D = _player_node(pid)
	if d.has("Cast"):
		var ab: String = str(d["Cast"]["ability"])
		if n == null:
			return
		if ab.begins_with("basic_"):
			_on_basic_attack(pid, n, ab)   # the auto attack: the swing animation and the white slash
			return
		var snd: String = ABILITY_SOUND.get(ab, "")
		if snd != "":
			Sfx.play(snd, n.global_position, -3.0)
		var spell: bool = main.player.class_id == "mage" if pid == my_id else (n as RemotePlayer).class_id == "mage"
		if pid == my_id:
			if spell or ab in ["shout", "poison", "smoke", "trap", "wolf", "stand", "flurry", "stealth", "venomburst"]:
				main.player.anim_cast(0.45)
			else:
				main.player.anim_attack(0.3)
		else:
			(n as RemotePlayer).play_attack(spell)
		var fx: Array = ABILITY_FX.get(ab, [])
		if fx.is_empty():
			return
		var col: Color = Color(str(fx[2]))
		var fwd: Vector3 = main.player.aim_dir if pid == my_id else (n as RemotePlayer).face
		match str(fx[0]):
			"melee":
				main.combat.slash(n.global_position, fwd, float(fx[1]), 1.6, col)
			"ring":
				main.combat.ring(n.global_position, float(fx[1]), col, 0.4)
				main.combat.burst(n.global_position + Vector3(0, 1.0, 0), col, 20, 5.0, 0.5)
			"burst":
				main.combat.ring(n.global_position, float(fx[1]), col, 0.4)
				main.combat.burst(n.global_position + Vector3(0, 1.0, 0), col, 16, 4.0, 0.5)
	elif d.has("MobHit"):
		var mh: Dictionary = d["MobHit"]
		var inner: Variant = mh["event"]
		var e: Enemy = mobs.get(int(mh["mob"]))
		if inner is Dictionary and (inner as Dictionary).has("Damage") and e != null and is_instance_valid(e):
			var dm: Dictionary = inner["Damage"]
			var crit: bool = bool(dm["crit"])
			var dot: bool = bool(dm["dot"])
			var col2: Color = Color("9be05a") if dot else (Color("ffd27a") if crit else Color.WHITE)
			main.combat.float_text(e.global_position + Vector3(0, e.height + 0.4, 0), str(int(dm["amount"])) + ("!" if crit else ""), col2)
			if not dot:
				Sfx.play("hit_crit" if crit else "hit", e.global_position, -2.0 if crit else -5.0)
				e.flash = 0.12
				main.combat.burst(e.center(), Color.WHITE, 5, 3.0, 0.3)
			if pid == my_id:
				_seen["hit"] = true
	elif d.has("Heal"):
		if n != null:
			main.combat.float_text(n.global_position + Vector3(0, 2.4, 0), "+%d" % int(d["Heal"]["amount"]), Color("7be08a"))
	elif d.has("MeteorImpact"):
		var at: Array = d["MeteorImpact"]["at"]
		var p: Vector3 = _w3(at, main.world.height_at(float(at[0]), float(at[1])))
		main.combat.ring(p, 3.6, Color("ffb060"), 0.5)
		main.combat.burst(p + Vector3(0, 0.3, 0), Color("ff7a3a"), 40, 9.0, 0.8, 0.25)
		Sfx.play("explosion", p)
		main.rig.shake += 0.5
	elif d.has("TrapSprung"):
		if n != null:
			Sfx.play("trap", n.global_position)


# ================================================================ sending intent
## Called from Player._physics_process after the game's own movement ran (so walking, turning, the camera and the
## animations feel exactly like single player: you move at once, you never wait for the network). We tell the server
## what we are doing; it decides where we really are, and we only ease back to it when we drifted.
func sync_player(p: Player, delta: float, move: Vector3, sprinting: bool, wanted_h: Vector2) -> void:
	var pre: Vector3 = p.global_position
	_sync_player_inner(p, delta, move, sprinting, wanted_h)
	if _netlog_on:
		_log_net(p, pre, move)


func _sync_player_inner(p: Player, delta: float, move: Vector3, sprinting: bool, wanted_h: Vector2) -> void:
	var dir: Vector2 = Vector2(move.x, move.z)
	if dir.length() > 1.0:
		dir = dir.normalized()
	# tell the server how we actually moved: when we are blocked or sliding along a wall, the server does the same
	if wanted_h.length() > 0.1 and dir.length() > 0.01:
		var real := Vector2(p.get_real_velocity().x, p.get_real_velocity().z)
		var ratio: float = real.length() / wanted_h.length()
		if ratio < 0.97:   # uphill, against a wall, along a wall: the server moves as little as we did
			dir = real.normalized() * dir.length() * ratio if ratio > 0.05 else Vector2.ZERO
	var aim: Vector2 = Vector2(p.forward_vec().x, p.forward_vec().z)
	_aim_t -= delta
	_in_t -= delta
	var edge: bool = (dir.length() < 0.01) != (_last_dir.length() < 0.01)
	if (dir.distance_to(_last_dir) > 0.01 and (_in_t <= 0.0 or edge)) or sprinting != _last_sprint or (aim.distance_to(_last_aim) > 0.05 and _aim_t <= 0.0):
		_in_t = 0.05
		_last_dir = dir
		_last_sprint = sprinting
		_last_aim = aim
		_aim_t = 0.1
		var msg := {"t": "input", "dir": [dir.x, dir.y], "aim": [aim.x, aim.y], "sprint": sprinting}
		if dir.length() < 0.01 and p.is_on_floor():
			# we have stopped: say where, so the server ends up here too instead of running on and pulling us forward
			msg["at"] = [p.global_position.x, p.global_position.z]
		send(msg)
	var ground_y: float = main.world.height_at(p.global_position.x, p.global_position.z)
	if p.global_position.y < ground_y - 3.0:
		# fell through: no collider here (a world without ground colliders); stand on the ground we can see
		p.global_position.y = ground_y + 0.3
		p.velocity.y = 0.0
	var off := Vector2(_my_target.x - p.global_position.x, _my_target.z - p.global_position.z)
	var err: float = off.length()
	if err > SNAP_DIST or absf(_my_target.y - p.global_position.y) > 4.0:
		# blink, charge, respawn, or far out of step: go where the server says
		p.global_position = _my_target
		p.velocity = Vector3.ZERO
	elif move.length() > 0.1:
		_idle_t = 0.0
		# the server's picture is a few tenths of a second old while we run; only correct real drift
		if err > DRIFT_OK:
			var pull: Vector2 = off.normalized() * (err - DRIFT_OK) * clampf(delta * 6.0, 0.0, 1.0)
			p.global_position += Vector3(pull.x, 0.0, pull.y)
	else:
		# standing still: the server's last position is a little old (or it ran on a moment before it heard us
		# stop), so wait for it to settle before easing to it, and never for a small difference
		_idle_t += delta
		if _idle_t > 0.6 and err > 0.25:
			var back: Vector2 = off * clampf(delta * 4.0, 0.0, 1.0)
			p.global_position += Vector3(back.x, 0.0, back.y)


## F10 starts and stops a recording of how our character and the server's picture of it differ, frame by frame, to
## user://netlog.csv (columns: time, our x z y, server x z y, error, how far we were pulled this frame, input, speed, on floor, idle time).
func toggle_netlog() -> void:
	_netlog_on = not _netlog_on
	if _netlog_on:
		_netlog = PackedStringArray(["t,px,pz,py,sx,sz,sy,err,pulled,input,vel,floor,idle"])
		main.ui.toast("Recording movement... press F10 again to save", Color("ffd27a"))
		ui2.set_recording(true, 0)
		return
	ui2.set_recording(false)
	var f := FileAccess.open("user://netlog.csv", FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(_netlog))
	var path := ProjectSettings.globalize_path("user://netlog.csv")
	main.ui.toast("Saved %d frames to %s" % [_netlog.size() - 1, path], Color("ffd27a"))
	print("netlog saved: ", path)
	_netlog = PackedStringArray()


func _log_net(p: Player, pre: Vector3, move: Vector3) -> void:
	if _netlog.size() > 20000:
		ui2.set_recording(true, _netlog.size() - 1)
		return
	if _netlog.size() % 15 == 0:
		ui2.set_recording(true, _netlog.size() - 1)
	var pos: Vector3 = p.global_position
	var err: float = Vector2(_my_target.x - pos.x, _my_target.z - pos.z).length()
	var pulled: float = Vector2(pos.x - pre.x, pos.z - pre.z).length()
	_netlog.append("%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.4f,%.2f,%.2f,%d,%.2f" % [_t, pos.x, pos.z, pos.y, _my_target.x, _my_target.z, _my_target.y, err, pulled, move.length(), Vector2(p.velocity.x, p.velocity.z).length(), 1 if p.is_on_floor() else 0, _idle_t])


func _sync_intent(delta: float) -> void:
	# target and auto attack follow what the game's own click handling decided
	var tid: int = -1
	var t: Enemy = main.target
	if t != null and is_instance_valid(t) and not t.dead and t.proxy:
		tid = t.server_id
	if tid != _sent_target:
		_sent_target = tid
		send({"t": "target", "mob": tid if tid >= 0 else null})
	var want: bool = main.combat.auto_attack and tid >= 0 and not main.player.dead
	if want != _want_attack:
		_want_attack = want
		send({"t": "attack", "on": want})
	# the tutorial's "put abilities on your bar" step
	_bar_t -= delta
	if _bar_t <= 0.0:
		_bar_t = 0.5
		var n: int = 0
		for b: Variant in (main.state.get("bar", []) as Array):
			if int(b) >= 0:
				n += 1
		if n != _sent_bar:
			_sent_bar = n
			send({"t": "bar_set", "count": n})


func cast(ability: String) -> void:
	if ability in ["meteor", "rain"]:
		var ap: Vector3 = main.player.aim_point
		send({"t": "aim_point", "pos": [ap.x, ap.z]})
	send({"t": "cast", "ability": ability})


func talk(npc: String) -> void:
	send({"t": "talk", "npc": npc})


func pickup(id: int) -> void:
	send({"t": "pickup", "id": id})


func request_respawn() -> void:
	send({"t": "respawn"})


# ================================================================ skilling
func inv_count(mat: String) -> int:
	if mat == "hpot":
		return int(main.state.get("potions", 0))
	return int((main.state.get("mats", {}) as Dictionary).get(mat, 0)) + (1 if bool((main.state.get("tools", {}) as Dictionary).get(mat.trim_prefix("sturdy_"), false)) and mat.begins_with("sturdy_") else 0)


func gold() -> int:
	return int(chr.get("gold", 0))


func skill_level(skill: String) -> int:
	if skill_levels.has(skill):
		return int((skill_levels[skill] as Dictionary)["level"])
	return 1


## The game's own crafting window (bag: click the knife, then the twigs; furnace, anvil, fire) asks to make `r` at
## `station`. Everything is crafted by the server: the id is "station:index" (same tables as the Workshop) or
## "gear:tier:slot:master".
func craft_local(station: String, r: Dictionary, times: int) -> void:
	var id := ""
	if r.has("gear"):
		var g: Dictionary = r["gear"]
		id = "gear:%d:%s:%d" % [int(g["tier"]), str(g["slot"]), 1 if bool(g["master"]) else 0]
	else:
		var list: Array = Data.RECIPES.get(station, [])
		for i in list.size():
			if str((list[i] as Dictionary)["out"]) == str(r["out"]) and str((list[i] as Dictionary)["name"]) == str(r["name"]):
				id = "%s:%d" % [station, i]
				break
	if id == "":
		main.ui.toast("That can't be made online yet", Color("e0a080"))
		return
	send({"t": "craft", "id": id, "qty": maxi(times, 1)})


## Plain-words "where do I get this?" for a material.
func source_of(mat: String) -> String:
	if Data.NODES.has(mat):
		var nd: Dictionary = Data.NODES[mat]
		var region: String = ["the meadows", "Thornwood", "the Mire", "the Frostspine"][clampi(int(nd["biome"]), 0, 3)]
		return "%s it in %s (%s %d)" % [nd["verb"], region, Data.SKILLS[nd["skill"]]["name"], nd["lvl"]]
	for f: Dictionary in Data.FISH:
		if f["raw"] == mat:
			return "Fish at rippling water (Fishing %d), needs a Fishing Rod" % int(f["lvl"])
	if mat == "flint":
		return "Mine any rock: now and then you chip some flint"
	if mat == "ember":
		return "A rare find when mining, or salvage a rare item at the forge"
	for table: String in Data.RECIPES:
		for r: Dictionary in Data.RECIPES[table]:
			if str(r["out"]) == mat:
				return "Make it in the Workshop (J): %s" % r["name"]
	return "Dropped by creatures"


func _apply_skills(m: Dictionary) -> void:
	var s: Dictionary = main.state
	var sk: Dictionary = s.get("skills", {})
	for e: Dictionary in m["list"]:
		var id: String = str(e["id"])
		var prev: Dictionary = skill_levels.get(id, {})
		skill_levels[id] = e
		if Data.COMBAT_SKILL.values().has(id):
			continue
		var xp: int = Data.xp_for_level(int(e["level"])) + int(e["xp_into"])
		if started and not prev.is_empty():
			var before: int = Data.xp_for_level(int(prev["level"])) + int(prev["xp_into"])
			if xp > before:
				main.combat.float_text(main.player.global_position + Vector3(0, 2.8, 0), "+%d %s" % [xp - before, Data.SKILLS[id]["name"]], Color(Data.SKILLS[id]["color"]).lightened(0.25))
		sk[id] = xp
	s["skills"] = sk
	var t: Variant = m.get("task")
	task = t if t is Dictionary else {}
	s["slayer"] = {"enemy": task["enemy"], "left": int(task["left"]), "total": int(task["total"])} if not task.is_empty() else {}
	if started:
		main.ui.refresh_window()


func _apply_recipes(list: Array) -> void:
	recipes = list
	# nudge: the first time something new becomes makeable, say so (once per recipe)
	var ready: Array = []
	for r: Dictionary in list:
		var ok: bool = str(r["state"]) == "ok"
		if ok and not bool(_known_ok.get(str(r["id"]), false)) and not _nudged.has(str(r["id"])) and not bool(r["gear"]) and not _known_ok.is_empty():
			ready.append(r)
		_known_ok[str(r["id"])] = ok
	if started and not ready.is_empty() and _t - _nudge_t > 3.0:
		_nudge_t = _t
		var r2: Dictionary = ready[0]
		_nudged[str(r2["id"])] = true
		main.ui.chat_say("You can make %s now. Press J." % r2["name"], Color("8ad07a"))
	if ui2 != null and ui2.win.visible:
		ui2._rebuild()


func _make_node_visual(kind: String, pos: Vector3) -> Node3D:
	if kind == "fire":
		return main.skills._make_fire(pos, true)
	if kind == "fish":
		var root := Node3D.new()
		main.add_child(root)
		root.global_position = pos + Vector3(0, 0.04, 0)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("dff4ff")
		mat.emission_enabled = true
		mat.emission = Color("9fd8ff")
		mat.emission_energy_multiplier = 0.5
		for r: Array in [[0.55, 0.66, 16], [0.95, 1.03, 20]]:
			var tm := TorusMesh.new()
			tm.inner_radius = r[0]
			tm.outer_radius = r[1]
			tm.rings = r[2]
			tm.ring_segments = 3
			var mi := MeshInstance3D.new()
			mi.mesh = tm
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(mi)
		return root
	return main.crafting._make_node(kind, pos)


func _sync_nodes(upsert: Array, gone: Array) -> void:
	for v: Dictionary in upsert:
		var id: int = int(v["id"])
		var pos: Vector3 = _w3(v["pos"], float(v["y"]))
		var ent: Dictionary = nodes.get(id, {})
		var was_live: bool = bool(ent.get("data", {}).get("live", true)) if not ent.is_empty() else true
		if ent.is_empty():
			ent = {"root": _make_node_visual(str(v["kind"]), pos)}
		ent["data"] = v
		ent["pos"] = pos
		var root: Node3D = ent["root"]
		main.crafting.set_node_live(root, bool(v["live"]))
		if was_live and not bool(v["live"]) and Data.MATERIALS.has(str(v["kind"])):
			main.combat.burst(pos + Vector3(0, 0.6, 0), Color(Data.MATERIALS[str(v["kind"])]["color"]), 16, 4.0, 0.5)
		nodes[id] = ent
	for gid: Variant in gone:
		var id2: int = int(gid)
		if nodes.has(id2):
			if is_instance_valid(nodes[id2]["root"]):
				(nodes[id2]["root"] as Node).queue_free()
			nodes.erase(id2)


## What the mouse can click on: live resources and fires near you.
func click_candidates() -> Array:
	var out: Array = []
	var me: Vector3 = main.player.global_position
	for id: int in nodes:
		var d: Dictionary = nodes[id]["data"]
		if not bool(d["live"]):
			continue
		var pos: Vector3 = nodes[id]["pos"]
		if Vector2(pos.x - me.x, pos.z - me.z).length() > 32.0:
			continue
		var kind: String = str(d["kind"])
		if kind == "fire":
			out.append({"kind": "sfire", "id": id, "pos": pos, "h": 1.0, "r": 0.9, "range": 4.5})
		elif kind == "fish":
			out.append({"kind": "snode", "id": id, "pos": pos, "h": 0.6, "r": 1.1, "range": 3.2})
		else:
			out.append({"kind": "snode", "id": id, "pos": pos, "h": 1.5, "r": 0.9, "range": 3.0})
	return out


## The hover text for a clickable node, with the reason in plain words if you cannot use it yet.
func node_prompt(it: Dictionary) -> String:
	if not nodes.has(int(it["id"])):
		return ""
	var d: Dictionary = nodes[int(it["id"])]["data"]
	var kind: String = str(d["kind"])
	if kind == "fire":
		return "Cook at the fire"
	if kind == "fish":
		return str(d["label"]) + ("" if inv_count("rod") > 0 else "  (you need a Fishing Rod: Workshop, J)")
	var nd: Dictionary = Data.NODES[kind]
	var need := ""
	if skill_level(str(nd["skill"])) < int(nd["lvl"]):
		need = "  (needs %s %d, you are %d)" % [Data.SKILLS[nd["skill"]]["name"], nd["lvl"], skill_level(str(nd["skill"]))]
	elif str(nd.get("tool", "")) != "":
		var line: Array = Data.TOOL_LINES[nd["tool"]]
		var best := -1
		for i in line.size():
			if inv_count(str(line[i])) > 0:
				best = i
		if best < int(nd.get("tt", 0)):
			need = "  (needs a %s: Workshop, J)" % Data.MATERIALS[line[int(nd.get("tt", 0))]]["name"]
	return "%s %s%s" % [nd["verb"], Data.MATERIALS[kind]["name"], need]


## The closest resource or fire you are standing at (the G key).
func nearest_node() -> Dictionary:
	var me: Vector3 = main.player.global_position
	var best := {}
	var bd := INF
	for it: Dictionary in click_candidates():
		var d: float = Vector2(me.x - it["pos"].x, me.z - it["pos"].z).length()
		if d < float(it["range"]) and d < bd:
			bd = d
			best = it
	return best


func use_node(it: Dictionary) -> void:
	if it["kind"] == "sfire":
		main.toggle_window("cooking")   # the game's own cooking window, in the chat box
		return
	send({"t": "gather", "node": int(it["id"])})


func _show_action(v: Dictionary) -> void:
	if ui2 == null:
		return
	var kind: String = str(v.get("act", ""))
	var label := ""
	match kind:
		"gather":
			label = "Gathering..."
		"fish":
			label = "Fishing..."
		"craft":
			label = "Making..."
	ui2.show_action(kind, float(v.get("act_p", 0.0)), label + "  (move to stop)")


## Placing fires with F is switched off: cook at a campfire (or a town). The server still knows how, in case it is wanted again.
func light_fire() -> void:
	main.ui.toast("Cook at a campfire", Color("e0a080"))


# ================================================================ chat
func _setup_chat() -> void:
	var box: LineEdit = main.ui._chat_input
	box.editable = true
	box.focus_mode = Control.FOCUS_CLICK
	box.placeholder_text = "Enter to chat · /g everyone · /w name · /help"
	box.max_length = 200
	box.text_submitted.connect(_on_chat_submit)
	box.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE:
			box.release_focus()
			box.accept_event())
	_chat_ready = true


func typing() -> bool:
	return _chat_ready and (main.ui._chat_input.has_focus() or (ui2 != null and ui2._search.has_focus()))


func _on_chat_submit(text: String) -> void:
	main.ui._chat_input.text = ""
	main.ui._chat_input.release_focus()
	if text.strip_edges() == "":
		return
	send({"t": "chat", "text": text})


func _on_chat(m: Dictionary) -> void:
	var from: String = str(m["from"])
	var text: String = str(m["text"])
	match str(m["channel"]):
		"say":
			main.ui.chat_say("%s: %s" % [from, text], Color("f0e6d0"))
			var n: Node3D = _player_by_name(from)
			if n != null:
				main.combat.float_text(n.global_position + Vector3(0, 2.6, 0), text.substr(0, 40), Color("f0e6d0"))
		"emote":
			main.ui.chat_say("%s %s" % [from, text], Color("c8a8e8"))
		"global":
			main.ui.chat_say("[World] %s: %s" % [from, text], Color("f2c27a"))
		"whisper":
			main.ui.chat_say("%s whispers: %s" % [from, text], Color("e89ae8"))
		"whisper_to":
			main.ui.chat_say("To %s: %s" % [from, text], Color("e89ae8"))
		_:
			main.ui.chat_say(text, Color("9ad0e8"))


func _player_by_name(nm: String) -> Node3D:
	if nm == str(main.state.get("name", "")):
		return main.player
	for id: int in remote:
		var rp: RemotePlayer = remote[id]
		if rp.player_name == nm:
			return rp
	return null


## F8: block characters or the new skinned one (remembered). Rebuilds you and everyone you can see.
func _switch_character() -> void:
	if not ResourceLoader.exists("res://scripts/char_rig.gd"):
		main.ui.chat_say("The new character is not installed in this game (run update.command).", Color("e0a080"))
		return
	var cr: Object = load("res://scripts/char_rig.gd")
	var on: bool = not bool(cr.call("enabled"))
	cr.call("set_enabled", on)
	main.player.refresh_look()
	for id: int in remote:
		(remote[id] as RemotePlayer).rebuild()
	main.ui.chat_say("Characters: %s (F8 switches)" % ("new skinned character" if on else "block characters"), Color("9ad0ff"))


func _unhandled_input(event: InputEvent) -> void:
	if not started or main.mode != "play" or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if typing():
		return
	match (event as InputEventKey).keycode:
		KEY_J:
			ui2.toggle()
			get_viewport().set_input_as_handled()
		KEY_F8:
			_switch_character()
			get_viewport().set_input_as_handled()
		KEY_F9:
			var q: Vector3 = main.player.global_position
			main.ui.chat_say("HEIGHT: me y %.2f | server y %.2f | game ground %.2f | grid %.2f | water %.2f | on floor %s | x %.1f z %.1f" % [q.y, _my_target.y, main.world.height_at(q.x, q.z), main.world.grid_height_at(q.x, q.z), World.WATER_Y, str(main.player.is_on_floor()), q.x, q.z], Color("9ad0ff"))
			get_viewport().set_input_as_handled()
		KEY_F10:
			toggle_netlog()
			get_viewport().set_input_as_handled()
		KEY_ENTER, KEY_KP_ENTER, KEY_SLASH:
			if not main.ui.dialog_open():
				main.ui._chat_input.grab_focus()
				if (event as InputEventKey).keycode == KEY_SLASH:
					main.ui._chat_input.text = "/"
					main.ui._chat_input.caret_column = 1
				get_viewport().set_input_as_handled()


# ================================================================ scripted check (headless)
var _bot_step := 0
var _bot_wait := 0.0
var _bot_cast_t := 0.0


## `--online-bot`: log in, fight the nearest monster with everything on the bar, loot it, report.
func _bot(delta: float) -> void:
	if _t > float(arg("--bot-seconds", "90")):
		print("ONLINE-BOT FAIL timeout step=%d seen=%s" % [_bot_step, _seen])
		get_tree().quit(1)
		return
	if not started:
		return
	var p: Player = main.player
	if _bot_step == 0:
		_bot_step = 1
		print("ONLINE-BOT in the world as %s L%d at %s, %d monsters in view" % [main.state["name"], int(chr["level"]), p.global_position, mobs.size()])
	if main.target == null or not is_instance_valid(main.target):
		var best: Enemy = null
		var bd: float = 1e9
		for e: Enemy in main.combat.enemies:
			var d: float = e.global_position.distance_to(p.global_position)
			if d < bd and not e.dead:
				bd = d
				best = e
		if best != null:
			main.set_target(best)
		return
	var t: Enemy = main.target
	var to: Vector3 = t.global_position - p.global_position
	var dist: float = Vector2(to.x, to.z).length()
	var dir: Vector2 = Vector2(to.x, to.z) / maxf(dist, 0.01)
	# walk using the same path real input takes: set walk_to like a click would
	p.walk_to = t.global_position if dist > 2.2 else Vector3.INF
	if dist < 4.0:
		main.combat.auto_attack = true
		_bot_cast_t -= delta
		if _bot_cast_t <= 0.0:
			_bot_cast_t = 0.4
			for i in (Data.ABILITIES[p.class_id] as Array).size():
				if main.ability_locked(i) == "":
					main.combat.cast_ability(i)
	if _seen.has("killed") and not _seen.has("looted"):
		var pk: Dictionary = main.combat.nearest_pickup(3.0)
		if not pk.is_empty():
			main.combat.take(pk)
	if _seen.has("hit") and _seen.has("killed") and _seen.has("looted"):
		var others: PackedStringArray = []
		for k: int in remote.keys():
			others.append("%s (%s) at %s" % [(remote[k] as RemotePlayer).player_name, (remote[k] as RemotePlayer).class_id, (remote[k] as RemotePlayer).global_position])
		print("ONLINE-BOT PASS killed a monster and looted it: gold=%d bag=%d xp=%d/%d, other players in view: %s" % [int(chr["gold"]), (main.state["bag"] as Array).size(), int(chr["xp_into_level"]), int(chr["xp_next"]), ", ".join(others)])
		get_tree().quit(0)


var _sb_step := 0
var _sb_t := 0.0
var _sb_sent := -99.0


func _nearest_live(kind: String) -> int:
	var me: Vector3 = main.player.global_position
	var best := -1
	var bd := 1e9
	for id: int in nodes:
		var d: Dictionary = nodes[id]["data"]
		if str(d["kind"]) != kind or not bool(d["live"]):
			continue
		var dist: float = (nodes[id]["pos"] as Vector3).distance_to(me)
		if dist < bd:
			bd = dist
			best = id
	return best


func _recipe_id(nm: String) -> String:
	for r: Dictionary in recipes:
		if str(r["name"]) == nm:
			return str(r["id"])
	return ""


## `--online-skill-bot`: gather twigs, make a Wooden Axe and a Fishing Rod, chop oak, chat, report.
func _skill_bot(delta: float) -> void:
	_sb_t += delta
	if _sb_t > float(arg("--bot-seconds", "120")):
		print("ONLINE-SKILL-BOT FAIL timeout step=%d mats=%s nodes=%d recipes=%d" % [_sb_step, main.state.get("mats", {}), nodes.size(), recipes.size()])
		get_tree().quit(1)
		return
	if not started or nodes.is_empty() or recipes.is_empty():
		return
	var p: Player = main.player
	var mats: Dictionary = main.state["mats"]
	var kind := ""
	var want := 0
	match _sb_step:
		0:
			kind = "twig"
			want = 14
			if int(mats.get("twig", 0)) >= want:
				_sb_step = 1
		1:
			if int(mats.get("wooden_axe", 0)) == 0:
				if _sb_t - _sb_sent > 4.0:
					_sb_sent = _sb_t
					send({"t": "craft", "id": _recipe_id("Wooden Axe"), "qty": 1})
			elif int(mats.get("rod", 0)) == 0:
				if _sb_t - _sb_sent > 4.0:
					_sb_sent = _sb_t
					send({"t": "craft", "id": _recipe_id("Fishing Rod"), "qty": 1})
			else:
				_sb_step = 2
				ui2.open("all")
			return
		2:
			kind = "oak"
			want = 3
			if int(mats.get("oak", 0)) >= want:
				_sb_step = 3
		3:
			send({"t": "chat", "text": "hello from the skill bot"})
			_sb_step = 4
			return
		4:
			if _seen.has("chat"):
				print("ONLINE-SKILL-BOT PASS twigs=%d axe=%d rod=%d oak=%d woodcutting=%s crafting=%s recipes=%d nodes=%d" % [int(mats.get("twig", 0)), int(mats.get("wooden_axe", 0)), int(mats.get("rod", 0)), int(mats.get("oak", 0)), skill_levels.get("woodcutting", {}), skill_levels.get("crafting", {}), recipes.size(), nodes.size()])
				if arg("--online-shot") != "":
					await get_tree().create_timer(1.0).timeout
				get_tree().quit(0)
			return
	if kind == "":
		return
	var id := _nearest_live(kind)
	if id < 0:
		return
	var pos: Vector3 = nodes[id]["pos"]
	var dist: float = Vector2(pos.x - p.global_position.x, pos.z - p.global_position.z).length()
	if dist > 2.6:
		p.walk_to = pos
		return
	p.walk_to = Vector3.INF
	if _sb_t - _sb_sent > 3.0:
		_sb_sent = _sb_t
		send({"t": "gather", "node": id})


var _qb := 0
var _qb_t := 0.0
var _qb_sent := -99.0
var _qb_log: Array = []


func _tam_entry() -> Dictionary:
	for e: Dictionary in journal:
		if str(e["npc"]) == "tam":
			return e
	return {}


## `--online-quest-bot`: the tutorial as a player plays it: talk to Tam, gather 12 twigs, craft the axe and rod,
## go back and turn in, then gather another twig. Prints what the server and the bag say at each step.
func _quest_bot(delta: float) -> void:
	if started:
		_qb_t += minf(delta, 0.1)   # the clock starts when the world is up
	if _qb_t > float(arg("--bot-seconds", "150")):
		print("QUEST-BOT FAIL timeout step=%d nodes=%d recipes=%d mats=%s tam=%s" % [_qb, nodes.size(), recipes.size(), main.state.get("mats", {}), _tam_entry()])
		get_tree().quit(1)
		return
	if not started or nodes.is_empty() or recipes.is_empty():
		if int(_qb_t) % 10 == 0 and _qb_t - _qb_sent > 1.0:
			_qb_sent = _qb_t
			print("QB waiting: started=%s nodes=%d recipes=%d ws=%d(live %d) id=%d chr=%s inv=%s pos=%s" % [started, nodes.size(), recipes.size(), _ws_state, _ws.get_ready_state(), my_id, not chr.is_empty(), not inv.is_empty(), _have_pos])
		return
	if main.ui.dialog_open():
		main.ui.advance()   # read through Tam's talk like a player clicking on
		return
	var p: Player = main.player
	var mats: Dictionary = main.state["mats"]
	var tam: Dictionary = npcs.get("tam", {})
	var tam_pos: Vector3 = _w3(tam["pos"], float(tam["y"]))
	match _qb:
		0:
			var far: float = Vector2(p.global_position.x - tam_pos.x, p.global_position.z - tam_pos.z).length()
			if far > 2.5:
				p.walk_to = tam_pos
			elif _qb_t - _qb_sent > 2.0:
				p.walk_to = Vector3.INF
				_qb_sent = _qb_t
				send({"t": "talk", "npc": "tam"})
			var e := _tam_entry()
			if not e.is_empty() and bool(e["active"]):
				print("QB accepted: ", e["title"], " ", e["progress"], "/", e["count"])
				_qb = 1
		1:
			if int(mats.get("twig", 0)) >= 14:
				print("QB twigs=", mats.get("twig", 0), " tam=", _tam_entry()["status"], " ", _tam_entry()["progress"], "/", _tam_entry()["count"])
				_qb = 2
			else:
				_qb_goto_node("twig")
		2:
			# through the game's own crafting window, as a player does
			if int(mats.get("wooden_axe", 0)) == 0 and _qb_t - _qb_sent > 4.0:
				_qb_sent = _qb_t
				for r: Dictionary in Data.RECIPES["crafting"]:
					if r["name"] == "Wooden Axe":
						main.skills.make("crafting", r, 1)
			elif int(mats.get("wooden_axe", 0)) > 0 and int(mats.get("rod", 0)) == 0 and _qb_t - _qb_sent > 4.0:
				_qb_sent = _qb_t
				for r: Dictionary in Data.RECIPES["crafting"]:
					if r["name"] == "Fishing Rod":
						main.skills.make("crafting", r, 1)
			elif int(mats.get("rod", 0)) > 0:
				print("QB crafted: mats=", mats, " tam=", _tam_entry()["status"], " ", _tam_entry()["progress"], "/", _tam_entry()["count"])
				_qb = 3
		3:
			p.walk_to = tam_pos
			if Vector2(p.global_position.x - tam_pos.x, p.global_position.z - tam_pos.z).length() < 2.5:
				p.walk_to = Vector3.INF
				send({"t": "talk", "npc": "tam"})
				_qb = 4
				_qb_sent = _qb_t
		4:
			if _qb_t - _qb_sent > 2.5:
				var e2 := _tam_entry()
				print("QB after turn-in: tam title=", e2.get("title"), " status=", e2.get("status"), " ", e2.get("progress"), "/", e2.get("count"), " mats=", mats)
				_qb = 5
		5:
			if int(mats.get("twig", 0)) < 30 and _qb_t - _qb_sent > 40.0:
				_qb = 6
			else:
				_qb_goto_node("twig")
				if _qb_t - _qb_sent > 12.0:
					_qb = 6
		6:
			var e3 := _tam_entry()
			print("QUEST-BOT DONE tam=", e3.get("title"), " ", e3.get("status"), " ", e3.get("progress"), "/", e3.get("count"), " mats=", mats)
			get_tree().quit(0)


func _qb_goto_node(kind: String) -> void:
	var p: Player = main.player
	var id := _nearest_live(kind)
	if id < 0:
		return
	var pos: Vector3 = nodes[id]["pos"]
	if int(_qb_t * 10) % 100 == 0:
		print("QB goto ", kind, " node ", id, " at ", pos, " me ", p.global_position, " server ", _my_target, " twigs ", main.state["mats"].get("twig", 0))
	if Vector2(pos.x - p.global_position.x, pos.z - p.global_position.z).length() > 2.6:
		p.walk_to = pos
	else:
		p.walk_to = Vector3.INF
		if _qb_t - _qb_sent > 3.0:
			_qb_sent = _qb_t
			send({"t": "gather", "node": id})


# scripted check of the stairs at (18, 22): walk up the ramp (it rises toward -x), then back down, twice
var _st_t := 0.0
var _st_i := 0
var _st_log := 0.0


func _stairs_bot(delta: float) -> void:
	if not started:
		return
	_st_t += minf(delta, 0.1)
	_st_log -= delta
	var p: Player = main.player
	var goals: Array = [Vector3(24.0, 0, 22.7), Vector3(12.5, 0, 22.4), Vector3(24.0, 0, 22.7), Vector3(12.5, 0, 22.4), Vector3(24.0, 0, 22.7)]
	if _st_i >= goals.size():
		print("STAIRS-BOT done")
		get_tree().quit(0)
		return
	var g: Vector3 = goals[_st_i]
	p.walk_to = g
	if Vector2(p.global_position.x - g.x, p.global_position.z - g.z).length() < 0.8:
		_st_i += 1
		_st_log = 0.0
		print("STAIRS-BOT reached goal ", _st_i, " y=", p.global_position.y, " server=", _my_target)
	if _st_log <= 0.0:
		_st_log = 0.25
		print("SB t=%.1f goal=%d me=(%.2f,%.2f,%.2f) srv=(%.2f,%.2f,%.2f) air=%s floor=%s" % [_st_t, _st_i, p.global_position.x, p.global_position.y, p.global_position.z, _my_target.x, _my_target.y, _my_target.z, _srv_air, p.is_on_floor()])
	if _st_t > 120.0:
		print("STAIRS-BOT FAIL timeout goal=", _st_i)
		get_tree().quit(1)


# soak test: wander around and print how the game grows (nodes, objects, memory, orphans, frame rate)
var _sk_t := 0.0
var _sk_next := 0.0
var _sk_dir_t := 0.0


func _soak(delta: float) -> void:
	if not started:
		return
	_sk_t += delta
	_sk_dir_t -= delta
	var p: Player = main.player
	if _sk_dir_t <= 0.0:
		_sk_dir_t = 6.0
		var a: float = randf() * TAU
		p.walk_to = p.global_position + Vector3(cos(a), 0, sin(a)) * 10.0
	if _sk_t >= _sk_next:
		_sk_next += 20.0
		print("SOAK t=%d nodes=%d objects=%d orphans=%d mem=%dMB fps=%d remote=%d mobs=%d drops=%d" % [int(_sk_t), Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.OBJECT_COUNT), Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), int(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0), int(Performance.get_monitor(Performance.TIME_FPS)), remote.size(), mobs.size(), drops.size() if "drops" in self else -1])
