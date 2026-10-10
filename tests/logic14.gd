extends Node
var main: Node
var fails := 0
func check(n: String, ok: bool) -> void:
	print(("ok   " if ok else "FAIL ") + n)
	if not ok:
		fails += 1
func frames(k: int) -> void:
	for i in k:
		await get_tree().physics_frame
func finish_dialog() -> void:
	var guard := 0
	while main.ui.dialog_open() and guard < 40:
		main.ui.advance()
		guard += 1
func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await frames(10)
	main.new_game("warrior")
	finish_dialog()
	var w: World = main.world
	var q = main.quests
	var me: Vector3 = main.player.global_position
	print("camp ", w.camp_pos, " spawn ", me, " shrine ", w.shrine_pos)
	check("spawn at camp", Vector2(me.x - w.camp_pos.x, me.z - w.camp_pos.z).length() < 6.0)
	check("camp on land", not w.is_water(w.camp_pos.x, w.camp_pos.z) and w.camp_pos.y > 0.2)
	check("bench on land", not w.is_water(w.camp_bench_pos.x, w.camp_bench_pos.z))
	check("tam stands on land", not w.is_water(w.npc_pos["tam"].x, w.npc_pos["tam"].z))
	check("pond is water", w.is_water(w.camp_pond.x, w.camp_pond.z))
	check("fish spot in water", w.is_water(w.camp_fish_pos.x, w.camp_fish_pos.z))
	var shore_ok := false
	for a in 16:
		var ang := a * TAU / 16.0
		var p: Vector3 = w.camp_fish_pos + Vector3(cos(ang), 0, sin(ang)) * 3.0
		if not w.is_water(p.x, p.z):
			shore_ok = true
	check("dry land within fish range", shore_ok)
	var near_fish := false
	for fs: Dictionary in main.skills.fish_spots:
		if (fs["pos"] as Vector3).distance_to(w.camp_fish_pos) < 0.1:
			near_fish = true
	check("skills has camp fish spot", near_fish)
	var twigs := 0
	var oaks := 0
	for n: Dictionary in main.crafting._nodes:
		if Vector2(n["pos"].x - w.camp_pos.x, n["pos"].z - w.camp_pos.z).length() < 18.0:
			if n["mat"] == "twig":
				twigs += 1
			elif n["mat"] == "oak":
				oaks += 1
	print("twigs ", twigs, " oaks ", oaks)
	check("brush near camp", twigs >= 12)
	check("oaks near camp", oaks >= 2)
	var kp: Vector3 = w.npc_pos["king"]
	check("king in keep", kp.distance_to(w.shrine_pos) < w.town_radius)
	main.combat._try_spawn()
	check("no spawns while safe", main.combat.enemies.size() == 0)
	main.player.teleport(w.camp_pos + Vector3(60, 1.0, 0))
	await frames(4)
	var far := Vector2(main.player.global_position.x - w.camp_pos.x, main.player.global_position.z - w.camp_pos.z).length()
	check("kept inside camp while safe", far < 27.0)
	main.player.teleport(w.camp_pos + Vector3(3.2, 1.0, -3.4))
	check("tam available", q.status("tam") == "available")
	check("tutorial info", q.tutorial_info()["text"].begins_with("Speak with Old Tam"))
	check("guide -> tam", q.guide_target()["label"] == "Old Tam")
	# walk through the chain
	q.talk("tam")
	finish_dialog()
	check("stage0 active", q.status("tam") == "active")
	check("guide -> brush", q.guide_target()["label"] == "Brush")
	main.crafting.add_mat("twig", 12)
	check("stage0 ready", q.status("tam") == "ready")
	q.talk("tam")
	finish_dialog()
	check("twig reward", main.crafting.count("twig") >= 24)
	check("stage1 available", q.status("tam") == "available" and q.current("tam")["title"] == "Wooden Tools")
	q.talk("tam")
	finish_dialog()
	check("guide -> bench", q.guide_target()["label"] == "Workbench")
	for r: Dictionary in Data.RECIPES["crafting"]:
		if r["out"] in ["wooden_axe", "wooden_knife", "rod"]:
			main.crafting.add_mat(r["out"], 1)
	check("stage1 ready", q.status("tam") == "ready")
	q.talk("tam")
	finish_dialog()
	q.talk("tam")
	finish_dialog()
	check("stage2 active", q.current("tam")["title"] == "Chop a Log" and q.status("tam") == "active")
	main.crafting.add_mat("oak", 2)
	q.talk("tam")
	finish_dialog()
	q.talk("tam")
	finish_dialog()
	check("fire stage gives flint", main.crafting.count("flint_steel") >= 1)
	main.skills.light_fire("kindling_oak")
	main.crafting.add_mat("kindling_oak", 1)
	main.skills.light_fire("kindling_oak")
	check("fire lit", main.skills.fires.size() == 1)
	check("stage3 ready", q.status("tam") == "ready")
	q.talk("tam")
	finish_dialog()
	q.talk("tam")
	finish_dialog()
	check("bait given", main.crafting.count("bait_0") >= 8)
	check("guide -> pond", q.guide_target()["label"] == "Fishing spot")
	main.crafting.add_mat("raw_minnow", 2)
	q.talk("tam")
	finish_dialog()
	q.talk("tam")
	finish_dialog()
	check("cook stage", q.current("tam")["title"] == "Cook It" and q.status("tam") == "active")
	main.crafting.add_mat("minnow", 2)
	q.talk("tam")
	finish_dialog()
	q.talk("tam")
	finish_dialog()
	check("ability stage", q.current("tam")["title"] == "Set Your Abilities" and q.status("tam") == "active")
	check("abilities button pulses", q.tutorial_pulse() == "abilities")
	main.toggle_on_bar(0)
	main.toggle_on_bar(1)
	check("bar stage ready", q.status("tam") == "ready")
	q.talk("tam")
	finish_dialog()
	q.talk("tam")
	finish_dialog()
	check("practice stage", q.current("tam")["title"] == "Try Them Out" and q.status("tam") == "active")
	await frames(5)
	check("practice mosslet spawned", q._practice != null and is_instance_valid(q._practice))
	check("still safe", main.state["tut_safe"] == true)
	main.combat.damage_enemy(q._practice, 99999.0, Vector3.ZERO, 0.0)
	await frames(3)
	check("practice ready", q.status("tam") == "ready")
	q.talk("tam")
	finish_dialog()
	check("safe zone ends", main.state["tut_safe"] == false)
	q.talk("tam")
	finish_dialog()
	q.talk("tam")
	finish_dialog()
	check("road stage active", q.current("tam")["title"] == "The Road to Hearthmoor" and q.status("tam") == "active")
	check("guide -> king", q.guide_target()["label"] == "King Aldren")
	var gold0: int = main.state["gold"]
	q.talk("king")
	finish_dialog()
	check("tam done after king", q.status("tam") == "done")
	check("king gave reward gold", int(main.state["gold"]) > gold0)
	check("king quest active", q.status("king") == "active")
	check("guide -> rowan", q.guide_target()["label"] == "Elder Rowan")
	check("tracker shows king charge", q.tutorial_info()["title"] == "The King's Charge")
	q.talk("rowan")
	finish_dialog()
	check("king done after rowan", q.status("king") == "done")
	check("no tutorial left", q.tutorial_info().is_empty() and q.guide_target().is_empty())
	check("rowan chain starts at smith", q.current("rowan")["title"] == "Meet the Smith")
	# already-owned item credit
	q.talk("rowan")
	finish_dialog()
	main.crafting.add_mat("wooden_pickaxe", 1)
	print("fails ", fails)
	get_tree().quit(1 if fails > 0 else 0)
