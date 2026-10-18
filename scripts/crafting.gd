class_name Crafting
extends Node3D
## Materials and the Hearth Forge: resource nodes you can mine, chop or harvest,
## Hilde the smith, and the craft / upgrade / salvage actions behind the forge screen.
## Materials are stored in main.state["mats"]: id -> count. Costs and recipes live in data.gd.

const GATHER_RANGE := 2.2
const RESPAWN := 150.0

var main: Node
var world: World
var _nodes: Array = []        # {node, pos, mat, ready_t}
var _smith := {}
var _smith_dir := Vector3(0, 0, 1)
var _t := 0.0


func setup(m: Node) -> void:
	main = m
	world = m.world
	# the opening camp's twigs and logs are fixed; everything else comes and goes with the map chunks
	# (online: the server places every resource, see Online._sync_nodes)
	if Online.requested():
		_build_forge()
		return
	for spot: Dictionary in world.resource_spots:
		var n := _make_node(spot["mat"], spot["pos"])
		_nodes.append({"node": n, "pos": spot["pos"], "mat": spot["mat"], "ready_t": 0.0})
	world.streamer.chunk_loaded.connect(_on_chunk_loaded)
	world.streamer.chunk_unloaded.connect(_on_chunk_unloaded)
	for c: Vector2i in world.streamer.loaded_coords():
		_on_chunk_loaded(c)
	_build_forge()


func _on_chunk_loaded(c: Vector2i) -> void:
	for spot: Dictionary in world.streamer.spots_for(c):
		if spot.has("node"):
			continue
		if spot.has("respawn_at"):
			spot["ready_t"] = maxf(0.0, float(spot["respawn_at"]) - _t)
			spot.erase("respawn_at")
		var n := _make_node(spot["mat"], spot["pos"])
		set_node_live(n, float(spot["ready_t"]) <= 0.0)
		spot["node"] = n
		_nodes.append(spot)


func _on_chunk_unloaded(c: Vector2i) -> void:
	for spot: Dictionary in world.streamer.spots_for(c):
		if not spot.has("node"):
			continue
		if float(spot["ready_t"]) > 0.0:
			spot["respawn_at"] = _t + float(spot["ready_t"])
		if is_instance_valid(spot["node"]):
			(spot["node"] as Node).queue_free()
		spot.erase("node")
		_nodes.erase(spot)


# ================================================================ visuals
func _mat3d(col: Color, glow := 0.0) -> StandardMaterial3D:
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


func _make_node(mat: String, pos: Vector3) -> Node3D:
	var root := Node3D.new()
	add_child(root)
	root.global_position = pos
	root.rotation.y = randf() * TAU
	var col := Color(Data.MATERIALS[mat]["color"])
	match Data.NODES[mat]["look"]:
		"ore":
			var rock := Color("6f7480") if mat == "copper" else Color("4a4a44")
			var sm := SphereMesh.new()
			sm.radius = 0.75
			sm.height = 1.1
			sm.radial_segments = 6
			sm.rings = 3
			_mesh(root, sm, _mat3d(rock), Vector3(0, 0.35, 0))
			var sm2 := sm.duplicate() as SphereMesh
			sm2.radius = 0.45
			sm2.height = 0.7
			_mesh(root, sm2, _mat3d(rock.darkened(0.15)), Vector3(0.6, 0.2, 0.3))
			for k in 6:
				var a := k * 1.1
				_mesh(root, _box(Vector3(0.16, 0.16, 0.16)), _mat3d(col, 0.6), Vector3(cos(a) * 0.55, 0.3 + (k % 3) * 0.18, sin(a) * 0.55), Vector3(k, k * 2, 0))
		"log":
			var cm := CylinderMesh.new()
			cm.top_radius = 0.32
			cm.bottom_radius = 0.36
			cm.height = 2.2
			cm.radial_segments = 7
			_mesh(root, cm, _mat3d(Color("6b4a2c")), Vector3(0, 0.33, 0), Vector3(0, 0, PI * 0.5))
			var ring := CylinderMesh.new()
			ring.top_radius = 0.3
			ring.bottom_radius = 0.3
			ring.height = 0.04
			ring.radial_segments = 7
			_mesh(root, ring, _mat3d(col, 0.3), Vector3(1.11, 0.33, 0), Vector3(0, 0, PI * 0.5))
			_mesh(root, _box(Vector3(0.5, 0.12, 0.3)), _mat3d(Color("4a8a3a")), Vector3(-0.3, 0.7, 0.1))
		"tree":
			var tree := MeshInstance3D.new()
			tree.mesh = Models.scenery_mesh("oak", int(absf(pos.x * 7.0 + pos.z)) % 50)
			var tm := StandardMaterial3D.new()
			tm.vertex_color_use_as_albedo = true
			tm.roughness = 1.0
			tm.cull_mode = BaseMaterial3D.CULL_DISABLED   # the scenery meshes are wound for the flora shader, which draws both sides
			tree.material_override = tm
			tree.scale = Vector3.ONE * 1.25
			root.add_child(tree)
			# a notch of pale wood shows it can be chopped
			_mesh(root, _box(Vector3(0.3, 0.3, 0.12)), _mat3d(col, 0.4), Vector3(0, 0.55, 0.27))
		"brush":
			for k in 7:
				var a3 := k * 0.9
				_mesh(root, _box(Vector3(0.06, 0.7 + (k % 3) * 0.15, 0.06)), _mat3d(Color("8a6a3a")), Vector3(cos(a3) * 0.18, 0.3, sin(a3) * 0.18), Vector3(cos(a3) * 0.5, 0, sin(a3) * 0.5))
			var lf := SphereMesh.new()
			lf.radius = 0.3
			lf.height = 0.4
			lf.radial_segments = 6
			lf.rings = 3
			_mesh(root, lf, _mat3d(Color("5a7a3a")), Vector3(0, 0.12, 0))
		"herb":
			var bush := SphereMesh.new()
			bush.radius = 0.38
			bush.height = 0.5
			bush.radial_segments = 6
			bush.rings = 3
			_mesh(root, bush, _mat3d(Color("3f7a3a")), Vector3(0, 0.2, 0))
			for k in 5:
				var a2 := k * TAU / 5.0
				_mesh(root, _box(Vector3(0.12, 0.12, 0.12)), _mat3d(col, 0.7), Vector3(cos(a2) * 0.26, 0.42 + (k % 2) * 0.08, sin(a2) * 0.26), Vector3(k, k, 0))
		"crystal":
			for k in 5:
				var h := 0.6 + (k % 3) * 0.35
				_mesh(root, _box(Vector3(0.22, h, 0.22)), _mat3d(col, 1.2), Vector3((k - 2) * 0.22, h * 0.5, (k % 2) * 0.2 - 0.1), Vector3(0, k, (k - 2) * 0.2))
			var l := OmniLight3D.new()
			l.light_color = col
			l.omni_range = 3.0
			l.light_energy = 0.8
			l.position.y = 0.8
			root.add_child(l)
	if Data.NODES[mat]["look"] == "tree":
		# chopped dry, a tree leaves its stump behind until it grows back
		var live := Node3D.new()
		live.name = "Live"
		for ch in root.get_children():
			root.remove_child(ch)
			live.add_child(ch)
		root.add_child(live)
		var stump := MeshInstance3D.new()
		stump.name = "Stump"
		stump.mesh = Models.scenery_mesh("stump", 0)
		var sm2 := StandardMaterial3D.new()
		sm2.vertex_color_use_as_albedo = true
		sm2.roughness = 1.0
		sm2.cull_mode = BaseMaterial3D.CULL_DISABLED
		stump.material_override = sm2
		stump.scale = Vector3.ONE * 1.25
		stump.visible = false
		root.add_child(stump)
	return root


## Show a gatherable as ready (live) or spent. Trees swap to a stump; everything else just hides.
func set_node_live(root: Node3D, live: bool) -> void:
	var stump := root.get_node_or_null("Stump")
	if stump == null:
		root.visible = live
		return
	root.visible = true
	root.get_node("Live").visible = live
	stump.visible = not live


func _build_forge() -> void:
	# Hilde works the smithy's own anvil; the furnace and anvil are the building's
	var f := world.forge_pos
	var root := Node3D.new()
	add_child(root)
	root.global_position = f
	_smith_dir = Vector3(world.anvil_pos.x - f.x, 0, world.anvil_pos.z - f.z)
	if _smith_dir.length() < 0.1:
		_smith_dir = Vector3(0, 0, 1)
	# Hilde
	var s := Models.hero("smith")
	s.scale = Vector3.ONE * Player.MODEL_SCALE
	root.add_child(s)
	s.set_facing(_smith_dir, true)
	var l3 := Label3D.new()
	l3.text = Data.SMITH_NAME
	l3.font = load("res://assets/fonts/Jersey10.ttf")
	l3.font_size = 38
	l3.pixel_size = 0.012
	l3.outline_size = 10
	l3.outline_modulate = Color("0a0810")
	l3.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l3.no_depth_test = true
	l3.position = Vector3(0.0, 2.75, 0.0)
	root.add_child(l3)
	_smith = {"sprite": s, "next": 0.0}


func _process(delta: float) -> void:
	if main == null or main.mode == "title":
		return
	_t += delta
	for n: Dictionary in _nodes:
		if float(n["ready_t"]) > 0.0:
			n["ready_t"] = float(n["ready_t"]) - delta
			if float(n["ready_t"]) <= 0.0:
				set_node_live(n["node"] as Node3D, true)
	if not _smith.is_empty():
		var s: Rig = _smith["sprite"]
		# hammering at the anvil, turning to greet you when you come close
		var to: Vector3 = main.player.global_position - s.global_position
		if Vector2(to.x, to.z).length() < 3.2:
			s.set_facing(to)
		else:
			s.set_facing(_smith_dir)
			if _t >= float(_smith["next"]):
				_smith["next"] = _t + 0.85
				s.attack(0.4)
		s.tick(delta, 0.0)


# ================================================================ interaction
func nearest() -> Dictionary:
	var p: Vector3 = main.player.global_position
	if Vector2(p.x - world.forge_pos.x, p.z - world.forge_pos.z).length() < 2.0:
		return {"kind": "forge"}
	var best := {}
	var bd := GATHER_RANGE
	for n: Dictionary in _nodes:
		if float(n["ready_t"]) > 0.0:
			continue
		var d := Vector2(p.x - n["pos"].x, p.z - n["pos"].z).length()
		if d < bd:
			bd = d
			best = {"kind": "node", "node": n}
	return best


func prompt(it: Dictionary) -> String:
	if it["kind"] == "forge":
		return "[G] Hilde: upgrade or salvage"
	var mat: String = it["node"]["mat"]
	var nd: Dictionary = Data.NODES[mat]
	var need := ""
	if main.skills.level(nd["skill"]) < int(nd["lvl"]):
		need = "  (needs %s %d)" % [Data.SKILLS[nd["skill"]]["name"], nd["lvl"]]
	elif nd.get("tool", "") != "" and main.skills.tool_tier(nd["tool"]) < int(nd.get("tt", 0)):
		need = "  (needs %s)" % Data.MATERIALS[Data.TOOL_LINES[nd["tool"]][int(nd.get("tt", 0))]]["name"]
	return "[G] %s %s%s" % [nd["verb"], Data.MATERIALS[mat]["name"], need]


## A node has been gathered dry: hide it until it grows back.
func deplete(n: Dictionary) -> void:
	n["ready_t"] = RESPAWN
	n["charges"] = 0
	set_node_live(n["node"] as Node3D, false)
	main.combat.burst(n["pos"] + Vector3(0, 0.6, 0), Color(Data.MATERIALS[n["mat"]]["color"]), 16, 4.0, 0.5)


var _full_toast_ms := 0


## Puts materials in the bag. Returns how many actually fit (the bag can be full).
func add_mat(mat: String, n: int, at := Vector3.INF) -> int:
	var fit := mini(n, main.mat_room(mat))
	if fit < n:
		var now := Time.get_ticks_msec()
		if now - _full_toast_ms > 1500:
			_full_toast_ms = now
			main.ui.toast("Your bag is full", Color("e0a080"))
	if fit <= 0:
		return 0
	if mat == "hpot":
		main.state["potions"] = int(main.state.get("potions", 0)) + fit
	else:
		var mats: Dictionary = main.state.get("mats", {})
		mats[mat] = int(mats.get(mat, 0)) + fit
		main.state["mats"] = mats
	main.quests.notify("obtain", mat, fit)
	main.ui.refresh_inventory()
	var col := Color(Data.MATERIALS[mat]["color"])
	if at != Vector3.INF:
		main.combat.float_text(at + Vector3(0, 2.0, 0), "+%d %s" % [fit, Data.MATERIALS[mat]["name"]], col)
	else:
		main.ui.toast("+%d %s" % [fit, Data.MATERIALS[mat]["name"]], col)
	return fit


## Gives back what _pay took (used when a recipe can't finish because the bag is full).
func refund(cost: Dictionary) -> void:
	var mats: Dictionary = main.state["mats"]
	for k: String in cost:
		if k == "gold":
			main.state["gold"] = int(main.state.get("gold", 0)) + int(cost[k])
		else:
			mats[k] = int(mats.get(k, 0)) + int(cost[k])


## Dev mode: every material (but tools and potions) reads as plentiful without sitting in your bag.
func dev_free(mat: String) -> bool:
	return main.dev_mode and mat != "hpot" and Data.MATERIALS.has(mat) and Data.MATERIALS[mat].get("kind", "") != "tool"


## What you can spend (unlimited in dev mode).
func count(mat: String) -> int:
	if dev_free(mat):
		return maxi(held(mat), 9999)
	return held(mat)


## What is physically in your bag.
func held(mat: String) -> int:
	if mat == "hpot":
		return int(main.state.get("potions", 0))
	return int((main.state.get("mats", {}) as Dictionary).get(mat, 0))


## Use up materials (free in dev mode).
func take(mat: String, n := 1) -> void:
	if dev_free(mat):
		return
	var mats: Dictionary = main.state["mats"]
	mats[mat] = maxi(0, int(mats.get(mat, 0)) - n)


func can_afford(cost: Dictionary) -> bool:
	for k: String in cost:
		if k == "gold":
			if int(main.state.get("gold", 0)) < int(cost[k]):
				return false
		elif count(k) < int(cost[k]):
			return false
	return true


func _pay(cost: Dictionary) -> void:
	var mats: Dictionary = main.state["mats"]
	for k: String in cost:
		if k == "gold":
			main.state["gold"] = int(main.state["gold"]) - int(cost[k])
		else:
			take(k, int(cost[k]))


# ================================================================ forge actions
## Rings and amulets are Crafting; everything else at the forge is Smithing.
static func skill_for_slot(slot: String) -> String:
	return "crafting" if slot in ["ring", "amulet"] else "smithing"


func tier_unlocked(tier: int, slot := "weapon") -> bool:
	return main.skills.level(skill_for_slot(slot)) >= int(Data.TIER_SKILL_LVL[tier])


func craft(tier: int, slot: String, masterwork: bool) -> void:
	if main.online != null:
		main.online.send({"t": "craft", "id": "gear:%d:%s:%d" % [tier, slot, 1 if masterwork else 0], "qty": 1})
		return
	var cost0 := Data.craft_cost(tier, slot, masterwork)
	var sk0 := skill_for_slot(slot)
	if not tier_unlocked(tier, slot) or not can_afford(cost0) or not main.can_take_item():
		_craft_now(tier, slot, masterwork)   # explains why not
		return
	main.skills.start_job(sk0, int(Data.TIER_SKILL_LVL[tier]), 1, func() -> bool:
		_craft_now(tier, slot, masterwork)
		return false, "Forge")


func _craft_now(tier: int, slot: String, masterwork: bool) -> void:
	var cost := Data.craft_cost(tier, slot, masterwork)
	if not tier_unlocked(tier, slot):
		var sk := skill_for_slot(slot)
		main.ui.toast("You need %s level %d to work %s" % [Data.SKILLS[sk]["name"], Data.TIER_SKILL_LVL[tier], Data.CRAFT_TIERS[tier]["name"]])
		return
	if not can_afford(cost):
		main.ui.toast("You don't have the materials for that")
		Sfx.play("ui_click")
		return
	if not main.can_take_item():
		main.ui.toast("Your bag is full")
		return
	_pay(cost)
	var t: Dictionary = Data.CRAFT_TIERS[tier]
	var cls: String = main.player.class_id
	var it := Items.generate(int(t["ilvl"]), cls, 3 if masterwork else 2, slot, true)
	if slot == "weapon":
		it["type"] = Items.WEAPON_FOR[cls]
	var base: String = Items.base_names(it["type"], it.get("armor", ""))[0]
	it["name"] = "%s %s %s" % ["Masterwork" if masterwork else "Forged", t["name"], base]
	(main.state["bag"] as Array).append(it)
	main.skills.add_xp(skill_for_slot(slot), roundi(55.0 * (tier + 1) * (1.6 if masterwork else 1.0)))
	main.quests.notify("craft", "any")
	Sfx.play("equip")
	Sfx.play("loot_rare", Vector3.INF, -4.0)
	main.ui.toast("Crafted %s" % it["name"], Items.color(it))
	main.ui.refresh_forge()


## One piece of gear for your class, straight into the bag (the anvil recipe already took the cost).
func make_gear(tier: int, slot: String, masterwork: bool) -> void:
	var t: Dictionary = Data.CRAFT_TIERS[tier]
	var cls: String = main.player.class_id
	var it := Items.generate(int(t["ilvl"]), cls, 3 if masterwork else 2, slot, true)
	if slot == "weapon":
		it["type"] = Items.WEAPON_FOR[cls]
	var base: String = Items.base_names(it["type"], it.get("armor", ""))[0]
	it["name"] = "%s %s %s" % ["Masterwork" if masterwork else "Forged", t["name"], base]
	(main.state["bag"] as Array).append(it)
	main.quests.notify("craft", "any")
	Sfx.play("loot_rare", Vector3.INF, -4.0)
	main.ui.toast("Forged %s" % it["name"], Items.color(it))


func brew_potion() -> void:
	if main.online != null:
		main.ui.toast("Use a vial on a herb to brew potions")
		return
	var cost := {"mossgel": 2, "gold": 5}
	if not can_afford(cost):
		main.ui.toast("Brewing needs 2 Mossgel and 5 gold")
		return
	_pay(cost)
	main.state["potions"] = int(main.state["potions"]) + 1
	main.skills.add_xp("herblore", 10)
	Sfx.play("potion")
	main.ui.refresh_forge()


func upgrade(ref: Array) -> void:
	if main.online != null:
		main.online.send({"t": "upgrade", "bag": int(ref[1])} if ref[0] == "bag" else {"t": "upgrade", "slot": str(ref[1])})
		return
	var item: Dictionary = main.item_ref(ref)
	if item.is_empty():
		return
	if int(item.get("upg", 0)) >= Data.UPGRADE_MAX or not can_afford(Data.upgrade_cost(item)):
		_upgrade_now(ref)   # explains why not
		return
	main.skills.start_job("smithing", int(Data.TIER_SKILL_LVL[mini(Data.item_tier(item), 3)]), 1, func() -> bool:
		_upgrade_now(ref)
		return false, "Upgrade")


func _upgrade_now(ref: Array) -> void:
	var item: Dictionary = main.item_ref(ref)
	if item.is_empty():
		return
	if int(item.get("upg", 0)) >= Data.UPGRADE_MAX:
		main.ui.toast("That item is fully upgraded")
		return
	var cost := Data.upgrade_cost(item)
	if not can_afford(cost):
		main.ui.toast("You don't have the materials for that")
		Sfx.play("ui_click")
		return
	_pay(cost)
	item["upg"] = int(item.get("upg", 0)) + 1
	main.skills.add_xp("smithing", 18 * (Data.item_tier(item) + 1) * int(item["upg"]))
	Sfx.play("equip")
	Sfx.play("level_up", Vector3.INF, -8.0)
	main.ui.toast("%s is now +%d" % [item["name"], item["upg"]], Items.color(item))
	if ref[0] == "equip":
		main._apply_gear()
	main.ui.refresh_forge()


func salvage(idx: int) -> void:
	if main.online != null:
		main.online.send({"t": "salvage", "idx": idx})
		return
	var bag: Array = main.state["bag"]
	if idx < 0 or idx >= bag.size():
		return
	var item: Dictionary = bag[idx]
	if not main.can_hold(_salvage_mats(item), 1):
		main.ui.toast("No room in your bag for the materials", Color("e0a080"))
		return
	bag.remove_at(idx)
	_give_salvage(item)
	Sfx.play("slam", Vector3.INF, -10.0)
	main.ui.refresh_forge()


func salvage_commons() -> void:
	if main.online != null:
		var b: Array = main.state["bag"]
		for i in range(b.size() - 1, -1, -1):
			if int((b[i] as Dictionary).get("rarity", 0)) == 0:
				main.online.send({"t": "salvage", "idx": i})
		return
	var bag: Array = main.state["bag"]
	var n := 0
	var skipped := 0
	for i in range(bag.size() - 1, -1, -1):
		if int(bag[i]["rarity"]) == 0:
			if not main.can_hold(_salvage_mats(bag[i]), 1):
				skipped += 1
				continue
			_give_salvage(bag[i], false)
			bag.remove_at(i)
			n += 1
	if n == 0:
		main.ui.toast("No room for the materials" if skipped > 0 else "No Common items to salvage", Color("e0a080") if skipped > 0 else Color.WHITE)
		return
	Sfx.play("slam", Vector3.INF, -10.0)
	main.ui.toast("Salvaged %d Common items" % n + (" (%d left: bag full)" % skipped if skipped > 0 else ""))
	main.ui.refresh_forge()


## Worst case materials a salvage can give (for the bag-room check).
func _salvage_mats(item: Dictionary) -> Dictionary:
	var y := Data.salvage_yield(item)
	var m: Dictionary = (y["mats"] as Dictionary).duplicate()
	if float(y["ember_chance"]) > 0.0:
		m["ember"] = int(m.get("ember", 0)) + int(y["ember"])
	return m


func _give_salvage(item: Dictionary, announce := true) -> void:
	var y := Data.salvage_yield(item)
	main.skills.add_xp("smithing", 8 * (Data.item_tier(item) + 1), announce)
	var mats: Dictionary = main.state.get("mats", {})
	var got: Array[String] = []
	for k: String in y["mats"]:
		mats[k] = int(mats.get(k, 0)) + int(y["mats"][k])
		got.append("%d %s" % [y["mats"][k], Data.MATERIALS[k]["name"]])
	if randf() < float(y["ember_chance"]):
		mats["ember"] = int(mats.get("ember", 0)) + int(y["ember"])
		got.append("%d Ember Shard" % y["ember"])
	main.state["mats"] = mats
	if announce:
		main.ui.toast("Salvaged: " + ", ".join(got))
