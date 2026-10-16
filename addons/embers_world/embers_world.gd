@tool
class_name EmbersWorld
extends Node3D
## One of these at the top of your world scene. It says how big the world is, where the sea is and what the
## default ground is. Everything else (EmbersPoint, EmbersRegion, EmbersRoad, groups) is read relative to it.

## Width and depth of the playable square, in metres. The middle of the square is (0, 0).
@export var size_m := 2400.0
## The game's own world is 2400 m wide. Leave this on and a smaller world is padded with open sea to that size, so
## it works in the real game. Turn it off only for server-only tests.
@export var pad_to_game_size := true
## Grid the server walks on (metres). 2 is what the game uses.
@export var cell_m := 2.0
## Anything lower than this is water.
@export var water_y := 0.0
@export_enum("Meadow", "Thornwood", "Mire", "Frostspine", "Coast") var default_biome := 0
@export_enum("Water", "Sand", "Grass", "Forest", "Mud", "Bog", "Snow", "Rock") var default_ground := 2
## Radius around the village where the town rules apply (metres).
@export var town_radius := 85.0
## Which Terrain3D texture each ground type uses when you paint the ground from your regions: Water, Sand, Grass,
## Forest, Mud, Bog, Snow, Rock. -1 (the default) finds it by the texture's name ("grass", "sand", "rock" ...).
@export var texture_ids := PackedInt32Array([-1, -1, -1, -1, -1, -1, -1, -1])
## Size of the flat triangles of the low-poly terrain, in metres (2 = the game's grid). Bigger = chunkier, more faceted. Used by
## Embers: Make terrain low poly and by the texture painting. The server's ground is always the 2 m grid, so keep 2 for exact
## gameplay, or use 4 for a bolder look.
@export_range(2.0, 8.0, 2.0) var facet_size_m := 2.0
## Which way each square of the low-poly terrain is cut into two triangles. If the faces look rounded or bumpy along one
## direction, switch this and run Embers: Make terrain low poly again (Terrain3D cuts its own mesh squares one way and the
## faces look cleanest when both agree).
@export var flip_facet_diagonal := false
## Rock or grass is decided per triangle face (every face is one texture, no blending inside a face), so the edges between
## rock and grass follow the faces of the low-poly terrain.
@export var faceted_textures := true
## When you paint the ground from your regions/paint (Project > Tools > Embers: Paint ground textures ...), steep hill
## and mountain sides become rock, more or less depending on the biome (Frostspine hills turn rocky early, meadow
## only on the steep sides).
## Height above the sea (metres) where snow starts on hills in Thornwood and Mire (the original game uses 7). Lower = snow reaches
## down further, higher = only the tallest peaks are snowy. Used when you press Send.
@export_range(1.0, 60.0, 0.5) var snow_line_m := 7.0
## How quickly it all turns to snow above the snow line, in metres of height. 0 = a hard line (below it none, above it all snow);
## a bigger number = a patchy, gradual change that takes that many metres to become fully snow.
@export_range(0.0, 40.0, 0.5) var snow_fade_m := 4.0
## Scatter the original game's ground clutter (pebbles, mossy rocks, bones, branches, tall grass, glowcaps, frostweed) in the game, by
## ground and biome as the original does. It keeps clear of buildings, walls, trees, rocks, paths and your marker points.
## 0 = none, 1 = like the original, 2 = twice as much. Used when you press Send.
@export_range(0.0, 3.0, 0.1) var ground_clutter := 1.0
## Show the flat-colour ground (one colour per triangle, the original game's look) in the game, built from the exported world. Off: the game shows your
## Terrain3D as you see it in the editor. Used when you press Send.
@export var flat_ground_in_game := true
## How wide the border between two biomes is, in metres (Meadow to Thornwood, Mire, Frostspine; the Coast keeps a clean edge).
## 0 = a hard line. Used when you press Send.
@export_range(0.0, 20.0, 0.5) var biome_blend_m := 6.0
## How far the edge of a path or a dirt/sand/rock patch is scattered into the ground around it, in metres (0 = a clean edge).
## Used when you press Send.
@export_range(0.0, 12.0, 0.5) var path_blend_m := 3.0
## Off: the border is patchy, some faces take the neighbour biome's ground (every face stays one flat colour).
## On: the colours blend smoothly across the border instead (the game and the preview show a gradient, one colour per 2 m cell).
@export var smooth_biome_blend := false
## Place fishing spots by itself along the water's edge (the original game's rule: shallow water next to land, spaced apart, a limited
## number per biome, one near the spawn). Your own Fishing Spot points are kept and counted. Used when you press Send.
@export var auto_fishing_spots := true
## Fishing spots are at least this far apart, in metres (the original uses 22; Mire is denser).
@export_range(6.0, 80.0, 1.0) var fishing_spacing_m := 22.0
## Most fishing spots per biome (the original uses 21; the Coast gets 70% more).
@export_range(1, 200, 1) var fishing_max_per_biome := 21
## Snow on or off for each biome. Meadow, Thornwood and Mire get snow only above the snow line (the original game has it in
## Thornwood and Mire only). Frostspine is snowy all the way down; untick it and Frostspine becomes plain grass (rock on steep slopes).
@export var snow_in_meadow := false
@export var snow_in_thornwood := true
@export var snow_in_mire := true
@export var snow_in_frostspine := true
@export var rocky_slopes := true
## Off (the default) = flat colour textures with no bump shading, like the game. On = small bumps from the speckles (can look
## darker and noisier on slopes). Applies the next time you run Embers: Set up ground textures.
@export var bumpy_ground := false
## Makes the rock textures (Rock, Cliff Rock ...) lighter (+) or darker (-) when you run Project > Tools > Embers: Set up ground
## textures. The game's own rock is 0. Terrain3D often looks a little darker than the game, so a bit lighter is usual.
@export_range(-0.5, 0.8, 0.05) var rock_lightness := 0.2
## Off = every steep slope uses the plain "Rock" texture instead of the biome's rock (Cliff, Mossy, Snow, Dark, Sand Rock).
@export var use_biome_rocks := false
## Force one Terrain3D texture slot (0, 1, 2 ... the number in Terrain3D > Assets > Textures) for ALL steep slopes, whatever the
## biome. -1 = choose automatically. The paint tool's result window says which texture each biome used.
@export var rock_texture_slot := -1
## How sharp the edge between grass and rock is. 0 = a soft fade (a wide band that is part grass, part rock), 1 = a hard
## edge: a slope is grass or it is rock.
@export_range(0.0, 1.0, 0.05) var rock_sharpness := 0.6
## 1 = normal. Higher = rock shows up on gentler slopes, lower = only on cliffs.
@export_range(0.5, 3.0, 0.05) var rockiness := 1.3
## Where "Export world" writes the files. Run the server with: embers-server --world <this folder>
@export_global_dir var export_dir := ""


## When a scene is opened, the flat-colour preview is gone (it is never saved), so a Terrain3D that was hidden for it is shown again.
func _ready() -> void:
	if not Engine.is_editor_hint():
		return
	var root := get_tree().edited_scene_root
	if root == null or root.find_child(EmbersFacetGround.NODE_NAME, true, false) != null:
		return
	for t3: Node in root.find_children("*", "Terrain3D", true, false):
		if t3.has_meta("embers_hidden"):
			(t3 as Node3D).visible = true
			t3.remove_meta("embers_hidden")
