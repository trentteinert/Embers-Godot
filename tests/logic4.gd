extends Node
var main: Node

func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	run()

func frames(k: int) -> void:
	for i in k:
		await get_tree().physics_frame

func run() -> void:
	await frames(3)
	main.new_game("rogue")
	while main.ui.dialog_open():
		main.ui.advance()
	main.state["tut_safe"] = false
	main.set_level(14)
	var c: Vector3 = main.world.cell_center(80, 100)
	main.combat.reset()
	main.player.teleport(c + Vector3(0, 0.5, 0))
	var far: Enemy = main.combat.spawn_enemy("wolf", c + Vector3(9, 0, 0), 0)
	var near: Enemy = main.combat.spawn_enemy("wolf", c + Vector3(0, 0, 5.5), 0)
	await frames(10)
	print("aggro at 9m: ", far.aggro, "  at 5.5m: ", near.aggro)
	# leash: drag the player away quickly and keep them in range of the chaser
	main.combat.reset()
	main.player.teleport(c + Vector3(0, 0.5, 0))
	var ch: Enemy = main.combat.spawn_enemy("wolf", c + Vector3(4, 0, 0), 0)
	var gave_up := false
	for f in 600:
		main.player.inv_t = 9.0
		var pp: Vector3 = ch.global_position + (main.player.global_position - ch.global_position).normalized() * 4.0
		main.player.teleport(Vector3(pp.x, main.world.height_at(pp.x, pp.z) + 0.5, pp.z) + Vector3(-0.1, 0, 0))
		await frames(1)
		if ch._leash_t > 0.0:
			gave_up = true
			break
	print("leashed: ", gave_up, " dist from home ", Vector2(ch.global_position.x - ch.home.x, ch.global_position.z - ch.home.z).length())
	# spawning spread
	main.combat.reset()
	main.player.teleport(c + Vector3(0, 0.5, 0))
	for f in 60 * 30:
		main.player.inv_t = 9.0
		await frames(1)
	var min_gap := 999.0
	for a: Enemy in main.combat.enemies:
		for b: Enemy in main.combat.enemies:
			if a != b:
				min_gap = minf(min_gap, a.global_position.distance_to(b.global_position))
	print("after 30s: enemies ", main.combat.enemies.size(), " min gap ", snappedf(min_gap, 0.1))
	# rogue: energy limits spam, not cooldowns
	main.combat.reset()
	main.player.res = 100.0
	var casts := 0
	for f in 60 * 4:
		main.combat.cooldowns[0] = maxf(0.0, main.combat.cooldowns[0])
		var before: float = main.player.res
		main.combat.cast_ability(0)
		if main.player.res < before:
			casts += 1
		await frames(1)
	print("rogue backstabs in 4s: ", casts, " energy left ", int(main.player.res))
	# jump
	main.combat.reset()
	main.player.teleport(c + Vector3(0, 0.5, 0))
	await frames(20)
	var y0: float = main.player.global_position.y
	var ev := InputEventAction.new()
	ev.action = "jump"
	ev.pressed = true
	Input.parse_input_event(ev)
	var top := y0
	for f in 90:
		await frames(1)
		top = maxf(top, main.player.global_position.y)
	var ev2 := InputEventAction.new()
	ev2.action = "jump"
	ev2.pressed = false
	Input.parse_input_event(ev2)
	await frames(30)
	print("jump height ", snappedf(top - y0, 0.01), " landed ", main.player.is_on_floor(), " back at ", snappedf(main.player.global_position.y - y0, 0.01))
	get_tree().quit()
