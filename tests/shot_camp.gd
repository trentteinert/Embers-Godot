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
	main.rig.max_distance = 200.0
	main.rig._zoom = 30.0
	main.rig.pitch_degrees = 55.0
	main.rig.yaw = 0.0
	main.rig.snap()
	await frames(8)
	await snap("camp_aerial")
	main.rig._zoom = 8.0
	main.rig.pitch_degrees = 22.0
	main.rig.yaw = PI * 0.8
	main.rig.snap()
	await frames(8)
	await snap("camp_ground")
	main.player.teleport(w.camp_pos + Vector3(8, 0.5, -40))
	main.rig._zoom = 9.0
	main.rig.yaw = PI
	main.rig.snap()
	await frames(8)
	await snap("camp_far")
	get_tree().quit()
