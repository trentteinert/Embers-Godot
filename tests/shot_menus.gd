extends Node
var main: Node
func snap(n: String) -> void:
	for i in 4: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/claude-0/shots/m_" + n + ".png")
func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	for i in 20: await get_tree().process_frame
	main.new_game("warrior")
	while main.ui.dialog_open(): main.ui.advance()
	for k in ["twig", "oak", "copper", "raw_minnow", "minnow", "kindling_oak", "hpot"]:
		main.crafting.add_mat(k, 12)
	for t in ["settings", "abilities", "skills"]:
		main.ui.open_side(t)
		await snap(t)
	get_tree().quit()
