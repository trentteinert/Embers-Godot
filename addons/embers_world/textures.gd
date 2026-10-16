@tool
class_name EmbersTextures
extends RefCounted
## Makes the ground textures of the original game for Terrain3D: the same colours, the same 2 m checkered cells with
## a little light and dark variation, the same speckles (flowers in the grass, needles in the forest, pebbles on the
## rock...). One tile covers 32 m (16 x 16 cells) and repeats seamlessly. Plus rock variants for hills and mountains.
## Used by Project > Tools > Embers: Set up ground textures (like the original game).

const CELLS := 16        # cells per tile side (a cell is 2 m, the game's grid)
const TEX := 8           # pixels per cell, as in the game
const TILE_M := 32.0     # metres one tile covers

## id, name, the two checker colours, speckle table [chance, colour] (the first matching roll wins, rolls are 0..1)
const SET := [
	[0, "Water", ["3b6470", "3e6874"], [[1.0, "4a7a88"]]],
	[1, "Sand", ["c9b27a", "cfb880"], [[1.0, "b39b62"]]],
	[2, "Grass", ["5f9a46", "649f4a"], [[0.025, "f2d16b"], [0.05, "e88aa6"], [0.3, "4c8a3c"], [1.0, "82c25e"]]],
	[3, "Forest", ["2f5a34", "325e37"], [[0.2, "6b5a2a"], [1.0, "24452a"]]],
	[4, "Mud", ["4b4a33", "4f4e36"], [[1.0, "3a3a28"]]],
	[5, "Bog", ["2e3d34", "304036"], [[1.0, "46604f"]]],
	[6, "Snow", ["c4d0dc", "bdc9d6"], [[0.3, "e4ecf2"], [1.0, "a6b4c4"]]],
	[7, "Rock", ["6f7480", "767b86"], [[0.4, "9aa0aa"], [1.0, "50545e"]]],
	# for hills and mountains (the painter picks these by name for steep slopes)
	[8, "Cliff Rock", ["5f6068", "666870"], [[0.35, "8a8c94"], [1.0, "3e3f46"]]],
	[9, "Mossy Rock", ["5f6a60", "667064"], [[0.45, "4c8a3c"], [0.7, "2f5a34"], [1.0, "50545e"]]],
	[10, "Snow Rock", ["6f7480", "767b86"], [[0.2, "e4ecf2"], [0.35, "c4d0dc"], [1.0, "50545e"]]],
	[11, "Dark Rock", ["4a4c55", "50525a"], [[0.3, "6a6c76"], [1.0, "2e3036"]]],
	[12, "Sand Rock", ["a89878", "b0a080"], [[0.3, "c9b27a"], [0.6, "6f7480"], [1.0, "8a7a58"]]],
	# roads and paths, one per biome, in the game's path colours (Embers: Paint path on terrain uses these by name)
	[13, "Path Meadow", ["8a7350", "8a7350"], [[0.6, "756244"], [1.0, "968162"]]],
	[14, "Path Thornwood", ["6e5a3c", "6e5a3c"], [[0.6, "5e4c33"], [1.0, "7d6a50"]]],
	[15, "Path Mire", ["5e553c", "5e553c"], [[0.6, "504833"], [1.0, "6e6650"]]],
	[16, "Path Frostspine", ["b4c0ca", "b4c0ca"], [[0.6, "99a3ac"], [1.0, "bcc6cf"]]],
	[17, "Path Coast", ["bfa874", "bfa874"], [[0.6, "a28f63"], [1.0, "c5b182"]]],
]


## One albedo image: RGB colour, alpha = a height for blending between textures.
static func albedo(entry: Array, rock_light := 0.0) -> Image:
	var size := CELLS * TEX
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(entry[1])
	var cols: Array = entry[2]
	var lift: float = rock_light if int(entry[0]) >= 7 and int(entry[0]) <= 12 else 0.0   # the rock textures can be made lighter or darker
	# smooth light/dark variation across the tile (wraps, so it tiles)
	var rnd := []
	for i in CELLS * CELLS:
		rnd.append(rng.randf_range(-1.0, 1.0))
	var strata: bool = str(entry[1]) == "Cliff Rock"
	for cy in CELLS:
		for cx in CELLS:
			var base := _tone(Color(str(cols[(cx + cy) % 2])), lift)
			var s := 0.0
			for oy in range(-1, 2):
				for ox in range(-1, 2):
					s += float(rnd[((cy + oy + CELLS) % CELLS) * CELLS + (cx + ox + CELLS) % CELLS])
			s = clampf(s / 9.0 * 2.2, -1.0, 1.0)
			base = base.lightened(s * 0.08) if s > 0.0 else base.darkened(-s * 0.12)
			if strata and cy % 4 == 0:
				base = base.lightened(0.08)
			var h := clampf(0.5 + s * 0.35, 0.0, 1.0)
			var c := Color(base.r, base.g, base.b, h)
			img.fill_rect(Rect2i(cx * TEX, cy * TEX, TEX, TEX), c)
			for k in 6:
				var px := cx * TEX + rng.randi_range(0, TEX - 1)
				var py := cy * TEX + rng.randi_range(0, TEX - 1)
				var r := rng.randf()
				for sp: Array in entry[3]:
					if r < float(sp[0]):
						var sc := _tone(Color(str(sp[1])), lift)
						img.set_pixel(px, py, Color(sc.r, sc.g, sc.b, clampf(h + 0.15, 0.0, 1.0)))
						break
	return img


static func _tone(c: Color, lift: float) -> Color:
	return c.lightened(lift) if lift >= 0.0 else c.darkened(-lift)


## A matching normal map (DirectX style, roughness in alpha) from the albedo's height, gentle bumps.
static func normal_map(alb: Image, bumpy := false) -> Image:
	var size := alb.get_width()
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	if not bumpy:
		# the game's ground is flat colour with no bumps: a flat normal and fully rough, so the sun lights it the way the game does
		img.fill(Color(0.5, 0.5, 1.0, 1.0))
		return img
	for y in size:
		for x in size:
			var hl := alb.get_pixel((x - 1 + size) % size, y).a
			var hr := alb.get_pixel((x + 1) % size, y).a
			var hu := alb.get_pixel(x, (y - 1 + size) % size).a
			var hd := alb.get_pixel(x, (y + 1) % size).a
			var n := Vector3((hl - hr) * 1.2, (hd - hu) * -1.2, 1.0).normalized()   # green flipped: DirectX
			img.set_pixel(x, y, Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5, 0.95))
	return img


## Put all the game's ground textures into a Terrain3D node (slots 0..17). Returns a message for the person.
static func install(terrain: Node, rock_light := 0.0, bumpy := false) -> String:
	if not ClassDB.class_exists("Terrain3DTextureAsset"):
		return "This needs Terrain3D 1.0 or newer (no Terrain3DTextureAsset found)."
	var assets: Object = terrain.get("assets")
	if assets == null or not assets.has_method("set_texture"):
		return "This Terrain3D has no assets list to put textures in. Update Terrain3D to 1.0 or newer."
	var names: Array[String] = []
	for entry: Array in SET:
		var alb := albedo(entry, rock_light)
		var nrm := normal_map(alb, bumpy)
		alb.generate_mipmaps()
		nrm.generate_mipmaps()
		var ta: Object = ClassDB.instantiate("Terrain3DTextureAsset")
		ta.set("name", entry[1])
		ta.set("albedo_texture", ImageTexture.create_from_image(alb))
		ta.set("normal_texture", ImageTexture.create_from_image(nrm))
		ta.set("uv_scale", 1.0 / TILE_M)
		ta.set("detiling_rotation", 0.12)
		if ta.has_method("set_id"):
			ta.call("set_id", int(entry[0]))
		assets.call("set_texture", int(entry[0]), ta)
		names.append(str(entry[1]))
	return "Added %d ground textures to Terrain3D (slots 0 to %d): %s.\nThey look like the original game: 2 m checkered cells with speckles. Save the scene and the Terrain3D assets to keep them. Then use the brush or Project > Tools > Embers: Paint ground textures from regions." % [names.size(), SET.size() - 1, ", ".join(names)]
