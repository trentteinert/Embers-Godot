extends Node
func _ready() -> void:
	var lay := {"v": 1, "props": {}, "deleted": [], "added": [{"id": "add_1", "kind": "chest", "pos": [-0.6, 0.0, 1.0], "yaw": -90.0, "upper": false, "ax": 1.0}, {"id": "add_2", "kind": "chest", "pos": [0.0, 0.0, 0.5], "yaw": 0.0, "upper": false, "az": -1.0}]}
	for sd in 8:
		TownKit.layout_override = lay
		var b: Node3D = TownKit.build("house", "meadow", sd, 6.0, true)
		TownKit.layout_override = null
		var tk: Dictionary = b.get_meta("tk")
		var out := ""
		for n in b.find_children("add_*", "", true, false):
			var nd := n as Node3D
			out += " %s(%.2f,%.2f)" % [n.name, nd.position.x, nd.position.z]
		print("seed ", sd, " hw ", snappedf(tk["hw"], 0.01), " hd ", tk["hd"], out)
		b.free()
	print("DONE")
	get_tree().quit()
