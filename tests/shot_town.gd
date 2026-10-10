extends Node
var main: Node
var out := "/tmp/claude-0/shots/"
func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	run()
func snap(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + n + ".png")
func frames(k: int) -> void:
	for i in k:
		await get_tree().process_frame
func run() -> void:
	await frames(20)
	main.new_game("warrior")
	while main.ui.dialog_open():
		main.ui.advance()
	var w: World = main.world
	print("buildings: ", w.town_buildings.size(), " radius ", w.town_radius)
	main.player.teleport(w.shrine_pos + Vector3(0, 0.5, 8))
	main.rig._zoom = 70.0
	main.rig.max_distance = 200.0
	main.rig.pitch_degrees = 62.0
	main.rig.yaw = 0.0
	main.rig.snap()
	await frames(5)
	await snap("tw_aerial")
	# npc movement
	var q = main.quests
	var p0: Vector3 = (q._ambient[0] as Dictionary)["pos"]
	await frames(2)
	var p1: Vector3 = (q._ambient[0] as Dictionary)["pos"]
	print("villager moved ", p0.distance_to(p1))
	# a house door
	var cot: Dictionary = {}
	for tb in w.town_buildings:
		if tb["kind"] == "tavern":
			cot = tb
	var fwd := Vector3(sin(cot["yaw"]), 0, cos(cot["yaw"]))
	main.rig._zoom = 7.0
	main.rig.pitch_degrees = 20.0
	main.player.teleport(cot["pos"] + fwd * 8.5)
	main.rig.yaw = cot["yaw"] + PI
	main.rig.snap()
	await frames(5)
	await snap("tw_tavern_front")
	main.player.teleport(cot["pos"] + fwd * 1.5 + Vector3(0, 0.3, 0))
	main.rig._zoom = 6.0
	main.rig.pitch_degrees = 35.0
	main.rig.snap()
	await frames(5)
	await snap("tw_tavern_in")
	var keep: Dictionary = {}
	for tb in w.town_buildings:
		if tb["kind"] == "keep":
			keep = tb
	if not keep.is_empty():
		var kf := Vector3(sin(keep["yaw"]), 0, cos(keep["yaw"]))
		main.player.teleport(keep["pos"] + kf * 12.0)
		main.rig._zoom = 12.0
		main.rig.pitch_degrees = 15.0
		main.rig.yaw = keep["yaw"] + PI
		main.rig.snap()
		await frames(5)
		await snap("tw_keep_front")
		main.player.teleport(keep["pos"] + kf * 2.0 + Vector3(0, 0.3, 0))
		main.rig._zoom = 7.0
		main.rig.pitch_degrees = 35.0
		main.rig.snap()
		await frames(5)
		await snap("tw_keep_in")
	get_tree().quit()
