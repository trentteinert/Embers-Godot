class_name StubStreamer
extends ChunkStreamer
## Stands in for the game's chunk streamer in custom worlds: no ground tiles, trees or ore spots are generated (your scene supplies
## them). It does scatter the original game's ground clutter (pebbles, mossy rocks, bones, branches, tall grass, glowcaps, frostweed)
## around the player, by ground and biome exactly as the original does, but never where World.clear says a structure is (the export
## marks the places around buildings, walls, trees, rocks and your marker points). Everything else that asks gets an empty answer.

var density := 0.0   # 0 = no clutter; 1 = as in the original
var _noise := FastNoiseLite.new()


func setup(w: World) -> void:
	world = w
	name = "Chunks"
	view_chunks = 6
	_noise.seed = 53
	_noise.frequency = 0.16
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_noise.fractal_octaves = 3
	var sh := Shader.new()
	sh.code = SHADER
	for k: String in ["see", "opq", "glow"]:
		var m := ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter("see_through", k == "see")
		m.set_shader_parameter("glow", 1.6 if k == "glow" else 0.0)
		_flora_mat[k] = m


func _process(delta: float) -> void:
	if density > 0.0:
		super._process(delta)


func flush(_p: Vector3, _r := 3) -> void:
	pass


func loaded_coords() -> Array:
	return []


func spots_for(_c: Vector2i) -> Array:
	return []


func is_loaded(_c: Vector2i) -> bool:
	return true


func set_view(chunks: int) -> void:
	super.set_view(mini(chunks, 8))


func _build_chunk(c: Vector2i) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = (c.x * 73856093) ^ (c.y * 19349663) ^ 20261004
	var root := Node3D.new()
	root.name = "Clutter_%d_%d" % [c.x, c.y]
	add_child(root)
	_loaded[c] = root
	var x0 := c.x * CS
	var y0 := c.y * CS
	var inst: Array = []
	_scatter(x0, y0, mini(x0 + CS, World.N), mini(y0 + CS, World.N), rng, inst)
	_merge(root, inst)


## The original's ground clutter rules (chunks.gd), with the chance scaled by `density` and its own noise (the world's is not set up here).
func _scatter(x0: int, y0: int, x1: int, y1: int, rng: RandomNumberGenerator, inst: Array) -> void:
	var N := World.N
	for y in range(y0, y1):
		for x in range(x0, x1):
			var i := y * N + x
			if world.clear[i] or world.path[i]:
				continue
			var g: int = world.ground[i]
			if g == G.WATER:
				continue
			var b: int = world.biome[i]
			var roll := rng.randf() / density
			var pv: float = _noise.get_noise_2d(x * 0.55, y * 0.55)
			var k := -1
			if g == G.SAND:
				if roll < 0.04:
					k = 0
			elif g == G.ROCK:
				if roll < 0.12:
					k = 0
				elif roll < 0.135:
					k = 2
			elif g == G.SNOW:
				if roll < 0.06:
					k = 6
				elif roll < 0.075:
					k = 0
				elif roll < 0.082:
					k = 2
			else:
				match b:
					0:
						if g == G.GRASS:
							if roll < 0.07 and pv > -0.1:
								k = 4
							elif roll < 0.095:
								k = 0
							elif roll < 0.11:
								k = 3
					1:
						if roll < 0.06:
							k = 3
						elif roll < 0.09:
							k = 1
						elif roll < 0.1:
							k = 5
						elif roll < 0.105:
							k = 2
					2:
						if roll < 0.05:
							k = 5
						elif roll < 0.07:
							k = 2
						elif roll < 0.09:
							k = 3
						elif roll < 0.12:
							k = 1
			if k == -1:
				continue
			var p := world.cell_center(x, y)
			p.x += rng.randf_range(-0.7, 0.7)
			p.z += rng.randf_range(-0.7, 0.7)
			p.y = world.height_at(p.x, p.z) - 0.03
			var sc: float = float(CLUTTER_SCALE[k]) * rng.randf_range(0.8, 1.2)
			var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * sc)
			var variant := rng.randi() % CLUTTER_VARIANTS
			var grp := "glow" if k == 5 else ("see" if k in [0, 1, 3, 4] else "opq")
			inst.append([CLUTTER_KINDS[k], (k * 10 + variant) * 5 + 1, Transform3D(basis, p), 0.1 if k in [4, 6] else 0.0, grp, false])
