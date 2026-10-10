extends Node
func _ready() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	for i in 20:
		await get_tree().process_frame
	main.new_game("warrior")
	var w: World = main.world
	var i := 0
	for b: Dictionary in w.bridges:
		var p: Vector3 = b["pos"]
		var d: Vector3 = b["dir"]
		var ln: float = b["len"]
		var wet := 0
		var n := 0
		var t := -ln * 0.5
		var lo := 99.0
		var hi := -99.0
		while t <= ln * 0.5:
			var h := w.height_at(p.x + d.x * t, p.z + d.z * t)
			lo = minf(lo, h); hi = maxf(hi, h)
			if h < 0.0:
				wet += 1
			n += 1
			t += 1.0
		print("BR%d pos(%d,%d) len %.0f wet %d/%d h %.1f..%.1f" % [i, p.x, p.z, ln, wet, n, lo, hi])
		i += 1
	print("DONE")
	get_tree().quit()
