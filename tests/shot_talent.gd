extends Node
var main: Node
var out := "/tmp/claude-0/shots/"
func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(out)
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
	main.new_game("rogue")
	while main.ui.dialog_open():
		main.ui.advance()
	main.dev_mode = false
	main.set_level(20)
	main.learn_talent("ve_poison")
	main.learn_talent("ve_potent")
	main.learn_talent("sh_ambush")
	main.learn_talent("sh_keen")
	main.learn_talent("sh_prep")
	main.learn_talent("ve_lasting")
	main.player.teleport(main.world.shrine_pos + Vector3(0, 0.5, 12))
	main.rig._zoom = 4.5
	main.rig.pitch_degrees = 6.0
	main.rig.yaw = PI
	main.rig.snap()
	main.ui.toggle_side("talents")
	await frames(30)
	await snap("t_talents")
	main.ui.toggle_side("abilities")
	await frames(10)
	await snap("t_abilities")
	main.ui.toggle_side("char")
	await frames(10)
	await snap("t_char")
	get_tree().quit()
