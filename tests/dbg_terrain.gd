extends Node
func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("relief="):
			World.relief_scale = float(a.get_slice("=", 1))
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	for i in 20:
		await get_tree().process_frame
	var w: World = main.world
	var n := World.N
	var ww := n + 1
	var img := Image.create(600, 600, false, Image.FORMAT_RGB8)
	var mn := 1e9
	var mx := -1e9
	var land := 0
	var hist := {}
	for y in 600:
		for x in 600:
			var h := w.heights[(y * 2) * ww + x * 2]
			mn = minf(mn, h)
			mx = maxf(mx, h)
			var c: Color
			if h < -0.05:
				c = Color(0.1, 0.25, 0.5).lerp(Color(0.25, 0.5, 0.7), clampf((h + 2.6) / 2.6, 0, 1))
			elif h < 3.0:
				c = Color(0.35, 0.6, 0.3).lerp(Color(0.5, 0.7, 0.35), h / 3.0)
			elif h < 12.0:
				c = Color(0.5, 0.7, 0.35).lerp(Color(0.55, 0.45, 0.3), (h - 3.0) / 9.0)
			else:
				c = Color(0.55, 0.45, 0.3).lerp(Color.WHITE, clampf((h - 12.0) / 14.0, 0, 1))
			img.set_pixel(x, y, c)
			if h > -0.05:
				land += 1
				var b := int(clampf(h, -1, 30) / 3.0)
				hist[b] = int(hist.get(b, 0)) + 1
	img.save_png("/tmp/claude-0/shots/heights_%d.png" % int(World.relief_scale * 10))
	print("HEIGHT min ", snapped(mn, 0.1), " max ", snapped(mx, 0.1), " land ", land)
	var keys := hist.keys()
	keys.sort()
	for k in keys:
		print("  ", int(k) * 3, "-", int(k) * 3 + 3, " m: ", snapped(100.0 * int(hist[k]) / land, 0.1), "%")
	# road steepness (rise per 2 m cell along road cells)
	var steep := 0
	var cliffs: Array[Vector2i] = []
	var tot := 0
	var worst := 0.0
	var worst_c := Vector2i.ZERO
	for y in range(1, n - 1):
		for x in range(1, n - 1):
			if w.path[y * n + x]:
				tot += 1
				var sl := maxf(absf(w.heights[y * ww + x + 1] - w.heights[y * ww + x - 1]), absf(w.heights[(y + 1) * ww + x] - w.heights[(y - 1) * ww + x])) / 4.0
				if sl > worst:
					worst = sl
					worst_c = Vector2i(x, y)
				if sl > 0.45:
					steep += 1
				if sl > 0.9:
					cliffs.append(Vector2i(x, y))
	print("WORST at ", w.cell_center(worst_c.x, worst_c.y), " ", w.heights[worst_c.y * ww + worst_c.x - 1], " ", w.heights[worst_c.y * ww + worst_c.x + 1], " ", w.heights[(worst_c.y - 1) * ww + worst_c.x], " ", w.heights[(worst_c.y + 1) * ww + worst_c.x])
	print("ROADS cells ", tot, " steeper than 24deg: ", steep, " worst grade ", snapped(worst, 0.01))
	print("ROAD CLIFF cells: ", cliffs.size())
	for ci in range(0, cliffs.size(), maxi(1, cliffs.size() / 12)):
		var cc := cliffs[ci]
		var wp := w.cell_center(cc.x, cc.y)
		var nearest := ""
		var nd := 1e9
		for st: Dictionary in w.settlements:
			var dd := Vector2(wp.x - st["pos"].x, wp.z - st["pos"].z).length()
			if dd < nd:
				nd = dd
				nearest = String(st["name"])
		print("  cliff at ", Vector2(wp.x, wp.z).snapped(Vector2.ONE), " h ", snapped(wp.y, 0.1), " nearest ", nearest, " ", snapped(nd, 1.0), "m")
	for st: Dictionary in w.settlements:
		var p: Vector3 = st["pos"]
		var lo := 1e9
		var hi := -1e9
		for a in 12:
			for r in [6.0, 14.0]:
				var q: Vector3 = p + Vector3(cos(a * TAU / 12.0), 0, sin(a * TAU / 12.0)) * r
				var hh := w.height_at(q.x, q.z)
				lo = minf(lo, hh)
				hi = maxf(hi, hh)
		print("SITE ", st["name"], " y ", snapped(p.y, 0.1), " range within 14m ", snapped(lo, 0.1), "..", snapped(hi, 0.1))
	var wet := 0
	for k in w.npc_pos:
		var q: Vector3 = w.npc_pos[k]
		if w.is_water(q.x, q.z):
			wet += 1
			print("NPC IN WATER ", k)
	for i in 4:
		for q: Vector3 in [w.rune_pos[i] as Vector3, w.altar_pos[i] as Vector3]:
			if w.is_water(q.x, q.z):
				print("RUNE/ALTAR IN WATER ", i)
	for i in w.cave_sites.size():
		var q: Vector3 = w.cave_sites[i]["pos"]
		print("CAVE ", i, " y ", snapped(q.y, 0.1), " water ", w.is_water(q.x, q.z))
	print("bridges ", w.bridges.size())
	print("DONE")
	get_tree().quit()
