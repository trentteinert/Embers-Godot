extends Node
func _ready() -> void:
	var m = load("res://scenes/main.tscn").instantiate()
	add_child(m)
	for i in 20:
		await get_tree().process_frame
	for s in get_tree().get_nodes_in_group("tk_sites"):
		var tagged := 0
		var un := {}
		for ch in s.get_children():
			if ch.has_meta("pid"):
				tagged += 1
			else:
				var k: String = String(ch.get_meta("tk")["kind"]) if ch.has_meta("tk") else "?" + ch.get_class() + ":" + String(ch.name).rstrip("0123456789@")
				un[k] = int(un.get(k, 0)) + 1
		print(s.name, " tagged ", tagged, " untagged ", un)
	get_tree().quit()
