extends Node
## Rogue talents, stealth, poison, assassinate and dual wield.
var main: Node
var fails := 0
func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	run()
func frames(k: int) -> void:
	for i in k:
		await get_tree().physics_frame
func check(n: String, ok: bool, extra := "") -> void:
	print(("ok   " if ok else "FAIL ") + n + " " + extra)
	if not ok:
		fails += 1
func run() -> void:
	await frames(3)
	main.new_game("rogue")
	while main.ui.dialog_open():
		main.ui.advance()
	await frames(5)
	main.dev_mode = false
	var cb = main.combat
	var pl: Player = main.player
	check("starts with main hand + off-hand", not main.state["equip"].get("weapon", {}).is_empty() and not main.state["equip"].get("offhand", {}).is_empty())
	check("off-hand counted", pl.equipped.has("offhand"))
	check("no talent points at level 1", main.talent_points_total() == 0)
	check("stealth locked at level 1", main.ability_locked(2) != "")
	main.set_level(2)
	await frames(2)
	check("1 point at level 2", main.talent_points_left() == 1)
	check("stealth unlocked at level 2", main.ability_locked(2) == "")
	check("poison needs talent", main.ability_locked(3) == "TALENT")
	main.learn_talent("ve_poison")
	check("learned poison blade", main.talent_rank("ve_poison") == 1 and main.ability_locked(3) == "")
	main.learn_talent("sh_ambush")
	check("no points left", main.talent_rank("sh_ambush") == 0)
	main.set_level(12)
	await frames(2)
	main.learn_talent("sh_smoke")
	check("tier 2 blocked by points", main.talent_rank("sh_smoke") == 0)
	for id in ["ve_potent", "ve_potent", "ve_potent"]:
		main.learn_talent(id)
	main.learn_talent("ve_lasting")
	check("tier gating opens after spending", main.talent_rank("ve_lasting") == 1)
	main.set_level(16)
	await frames(2)
	check("points every 2 levels", main.talent_points_total() == 8)
	# stealth + ambush
	main.learn_talent("sh_ambush")
	main.learn_talent("sh_ambush")
	pl.res = 100.0
	main.state["bar"] = [-1, -1, -1, -1, -1, -1]
	main.toggle_on_bar(2)
	check("stealth on bar", main.bar_ability(0) == 2)
	var e: Enemy = cb.spawn_enemy("wolf", pl.global_position + Vector3(4, 0, 0), 0)
	e.global_position = pl.global_position + Vector3(4, 0, 0)
	main.set_target(e)
	cb.cast(0)
	check("stealth buff", pl.has_buff("stealth"))
	check("auto attack not started by stealth", not cb.auto_attack)
	var hp0: float = e.hp
	pl.res = 100.0
	# poison blade and a hit
	main.toggle_on_bar(3)
	cb.cooldowns[3] = 0.0
	pl.res = 100.0
	cb.cast(1)
	check("poison buff", pl.has_buff("poison"), str(pl.buffs) + " bar " + str(main.state["bar"]))
	check("offensive ability starts auto attack", cb.auto_attack)
	e.global_position = pl.global_position + Vector3(1.0, 0, 0)
	cb.damage_enemy(e, 10.0, Vector3.ZERO, 0.0)
	check("hit from stealth consumed stealth", not pl.has_buff("stealth"))
	check("poisoned", e.poison_t > 4.0, str(e.poison_t))
	check("ambush boosted the hit", hp0 - e.hp >= 10.0 * 2.0 * 1.6 - 1.0, str(hp0 - e.hp))
	# venom burst needs the capstone
	check("venom burst locked", main.ability_locked(8) == "TALENT")
	# dual wield equip
	var d := Items.generate(5, "rogue", 2, "weapon")
	d["type"] = "shortsword"
	main.state["bag"].append(d)
	main.state["equip"].erase("offhand")
	main.equip_from_bag(main.state["bag"].size() - 1)
	check("second weapon lands in off-hand", not main.state["equip"].get("offhand", {}).is_empty() and main.state["equip"]["offhand"]["type"] == "shortsword")
	var g0: float = Items.totals({"offhand": d})["dmg"]
	check("off-hand dmg halved", is_equal_approx(g0, float(d["stats"]["dmg"]) * 0.5))
	# armor type restriction
	var plate := Items.generate(5, "warrior", 1, "chest", true)
	check("rogue cannot wear plate", not Items.can_equip(plate, "rogue"))
	# reset
	main.reset_talents()
	check("reset refunds", main.talent_points_spent() == 0 and main.ability_locked(3) == "TALENT")
	check("bar pruned", main.bar_ability(1) == -1)
	main.ui.toggle_side("talents")
	await frames(2)
	check("talents overlay opens", main.ui.talents_open())
	check("req enforced", main.talent_block("sh_prep") != "")
	main.set_level(12)
	main.learn_talent("sh_keen")
	main.learn_talent("sh_ambush")
	main.learn_talent("sh_keen")
	main.learn_talent("sh_prep")
	check("req chain works", main.talent_rank("sh_prep") == 1)
	main.combat.cooldowns[8] = 5.0
	main.combat._physics_process(1.0)
	check("high cooldowns tick", main.combat.cooldowns[8] < 4.5)
	main.reset_talents()
	main.set_level(30)
	check("15 points at 30", main.talent_points_total() == 15)
	for i in 3: main.learn_talent("ve_potent")
	for i in 3: main.learn_talent("ve_agile")
	for i in 2: main.learn_talent("ve_resil")
	check("hp talent applies", pl.max_hp > 0 and main.talent_rank("ve_resil") == 2)
	main.learn_talent("ve_burst")
	check("capstone needs 10 in tree", main.talent_rank("ve_burst") == 0)
	main.learn_talent("ve_poison")
	main.learn_talent("ve_veil")
	main.learn_talent("ve_burst")
	check("capstone at 10 points", main.talent_rank("ve_burst") == 1)
	main.reset_talents()
	for i in 3: main.learn_talent("sh_keen")
	for i in 3: main.learn_talent("sh_ambush")
	for i in 3: main.learn_talent("sh_nimble")
	for i in 3: main.learn_talent("ve_potent")
	for i in 3: main.learn_talent("ve_agile")
	main.learn_talent("sh_assassinate")
	check("hybrid cannot reach capstone", main.talent_rank("sh_assassinate") == 0 and main.talent_points_left() == 0)
	main.ui.toggle_talents(false)
	check("overlay closes", not main.ui.talents_open())
	print("fails=", fails)
	get_tree().quit()
