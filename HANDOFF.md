# Embers of Thornvale: handoff notes for a new Claude chat

Paste this file (or just say "read HANDOFF.md first") at the start of any new session. It is written so you can work on the game exactly the way the previous session did.

## 1. What this is
A low-poly 3D open-world RPG in **Godot** (Trenton's Mac runs 4.7; the Linux container used 4.5.1, both work). Everything is built in code (GDScript, explicit static typing); there are almost no hand-made scenes or models. Heroes, enemies, buildings, trees and props are assembled from boxes and simple meshes at runtime. Eerie, Valheim-like mood. The game is meant to be HARD (mobs hit hard, gear is slow). Possible Steam release and multiplayer later.

Owner: Trenton. Style: casual, wants quick replies and results, not essays. Intuitive UI matters a lot to him.

Open the project: Godot, Import `project.godot`, press F5. Main scene `res://scenes/main.tscn`. The viewport is 1280x720, canvas_items stretch.

## 2. Read these first
- `README.md`: controls, systems, file map, Build Editor docs.
- `WORLD_ZONE_STORY_ATLAS.md` and `WORLD_EXPANSION_PLAN.md`: zone/story/level plan (cap 45, regions, Wardens, routes). The atlas is a TARGET, not what is currently generated.
- `SKILLS_AND_TALENTS_DESIGN.md`: skills, talents, classless combat design.
- Keep these .md files current when direction changes (Trenton asked for this).

## 3. Code map (scripts/)
- `main.gd` game flow, saving, dev mode hooks. `data.gd` classes/abilities/quests/prices/keys (most tuning). `world.gd` terrain, water, roads, bridges, biomes, flora, sites. `town_kit.gd` buildings, props, villages, camps. `build_editor.gd` + `prop_layouts.gd` in-game editor and saved layouts. `player.gd`, `combat.gd`, `enemy.gd`, `skills.gd`, `crafting.gd`, `items.gd`, `quests.gd`, `ui.gd`, `models.gd`, `rig.gd`, `camera_rig.gd`, `clicker.gd`, `daynight.gd`, `door.gd`, `building.gd`, `caves.gd`, `chunks.gd`, `dev_panel.gd`, `audio.gd`.
- `layout_map.gd` / `layout_data.gd` are GENERATED from the painted map by `tools/layout/` (edit the pins in `tools/layout/export.py` and rerun it; do not hand-edit layout_data.gd).
- `sprite_art.gd` and `tools/make_sprites.py` are old 2D leftovers, unused.
- `layouts/*.json` hold Trenton's hand edits made in the Build Editor (apothecary, chapel, hall_house, house, shop, tavern, townhouse, site_Hearthmoor). **Never overwrite or delete this folder.** `export_presets.cfg` includes `layouts/*.json`.

## 4. World terrain (world.gd)
- N=1200 cells, CELL=2 m (2.4 km), WATER_Y=0, Hearthmoor at the centre (CX=CY=600). Player starts at Wanderer's Rest (south-west).
- Heights come from coarse fields (`_hb` base, `_ha` roughness, `_hm` mountain weight, `_hw` water weight) plus a relief layer (hills/ridges, `World.relief_scale`, 1.0 default, 0 = flat). `SAFE_R=190` cells of gentle ground around Hearthmoor. Biome multiplies relief. A water-distance field keeps river banks gentle.
- `_flatten(c, rad)` levels settlement sites with an adaptive skirt. Roads (path cells) are lifted to at least 0.3 m except at bridges.
- Bridges: `_find_bridges` fits the road direction near each wet crossing, picks the shortest span within a small angle fan, skips spans that hit sites and spans with under 5 m of real water (those stay fords); `_build_bridges` places them. Check bridges with `tests/shot_bridges` (renders) and `tests/dbg_br` (water under each deck).
- Verify terrain changes with `tests/dbg_terrain` (height histogram, road grade, site flatness, cliffs; arg `-- relief=0` or `1`).

## 5. TownKit prop system (important)
Props are created through `B.prop(kind, at, yaw, draw)` (relative) or `B.piece(kind, at, yaw, draw)` (absolute-coordinate code), with stable ids `kind_N` in build order. Layout JSON per building kind: `props {id:{d:[dx,dy,dz], r:deg}}`, `deleted`, `added`, and `instances {"x_z": layout}` for single buildings. Outdoor objects in villages/camps use `site_<VillageName>.json` (`TownKit.OUTDOOR`, `SITE_EXTRA`, `site_apply`). Changing building code can shift ids, which can move saved edits.

## 6. Build Editor (dev mode)
Dev mode: Settings (O) -> Testing, or the dev flag. Open the editor with backslash, Cmd/Ctrl+E, F3, or the button in the F2 dev panel. Move (M), rotate (R), Delete, Ctrl+D, undo/redo, exact numbers, palette to add pieces. Nothing saves automatically: Ctrl/Cmd+S or "Save for all" (every building of the kind), "Save this one only" (that instance), Revert. Real deletion, not hiding. Quest-linked objects are editable on purpose; a quest pass later will re-sync them.

## 7. Conventions to keep
- GDScript with explicit types everywhere (avoid `:=` where the type can't be inferred; this has caused parse errors).
- Compile check (no output = OK): `godot --headless --path . res://tests/compile.tscn 2>&1 | grep -a "false\|parse\|SCRIPT ERROR"`
- After adding a new `class_name` script: `godot --headless --path . --import`.
- Test scenes live in `tests/`. Copy an existing scene: `sed 's/dbg_edit_game/NAME/g' tests/dbg_edit_game.tscn > tests/NAME.tscn` and write `NAME.gd`. Full-game headless tests need about 90-105 s to build the world, so run them in the background and wait. Extra args go after `--` and are read with `OS.get_cmdline_user_args()`.
- Screenshot tests need a display (xvfb) with `--rendering-driver opengl3`.
- Never use unbounded `while` loops with computed limits (one hung a whole test).
- Don't overwrite the Mac `project.godot`. Keep Godot closed when replacing script files, or the editor may overwrite them.
- Cloud sessions can't see the Mac unless it is linked; check files by md5 after any copy.

## 8. Design decisions Trenton has stated (keep honouring)
- Blocky/square characters (no bubble shapes); gear shows on the model.
- WoW-style camera and controls: left-drag orbit, right-drag steer, target-based combat, loose organic camera.
- RuneScape-style skills (levels 1-30 now, cap 45 planned); you make your own tools from twigs up; action bar starts empty; potions/food by right-click; 28-slot bag; crafting by using items on items.
- UI: side-docked compact panels, nothing pauses the game, only Settings/Talents/Map centered. Minimal quest text, rewards match the activity.
- Classless combat: Melee, Ranged, Magic skills, each with talents; weapon decides style; Melee uses a Fury bar. Doing Melee first.
- Towns on a rough grid with a main road, roomy buildings, some two-storey, lively props. Hearthmoor first.
- Eerie lighting, daytime not too bright. Hard game.

## 9. Open items / waiting on Trenton
- Ranged/Magic talent rework (needs his ideas, Battle Mage / Demon Hunter hybrids).
- Rage hybrid rule (only when bulwark and venom/shadow points are equal).
- Next-order list: Ashford street-grid two-storey pass, hamlets and camps, hamlet villagers, delta roads, minimap crop, tutorial pacing, level-45 Deep Runs.
- A later quest pass (quest positions and objects that were moved in the editor).
- Latest work: terrain relief and the bridge algorithm (just shipped). If bridges look wrong, ask him roughly where (minimap area) and render that bridge.

## 10. How to work with Trenton
Start with one sentence on what you're doing, then do it. Test before claiming it works (compile, headless test, or render). Report briefly: what changed, anything he must do (like restarting Godot). Ask only when a wrong guess would be costly.

## Build Editor: how saving works (keep in mind when editing)
- **Save for all** replaces every building of that kind, including any single-building copies (those go to `layouts/backup/`). It then test-builds the narrowest and widest version and warns if a piece clips there.
- Pieces you add next to a wall are saved relative to that wall (`ax`/`az` in the JSON), so they stay flush when houses are wider or narrower. Moved default pieces are offsets from where the code puts them, which already follows the walls.
- Every save keeps the last 15 versions of that layout file in `layouts/backup/`. Single-building copies match a building within 1.5 m if a village shifts slightly.
