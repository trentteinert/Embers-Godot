# Embers of Thornvale

A small open-world RPG with chunky low-poly 3D characters, built in Godot 4.5.

## Open it
1. Open Godot 4.5 (the standard version, not .NET).
2. In the Project Manager, click **Import** and pick `project.godot` in this folder.
3. Press **F5** (or the ▶ button) to play.

## Controls
W / S move · A / D turn · Q / E strafe · R autorun · Shift sprint · Space jump
1-6 action bar (starts empty; N opens Abilities to fill it) · Tab / Shift+Tab target · G interact / pick up · M map · Esc menu
Right-click potions, food and draughts in your bag to use them (hotkeys H · X · Y · V still work) · B / I bags · K character · U skills · L quest book · O settings (also on the buttons, bottom right)
Click people, the forge, ore nodes, runestones and loot to use them; if they're far you walk over first (WASD cancels)
Camera (World of Warcraft style): left-drag orbits the camera, right-drag steers (the character turns with the view; A / D strafe while it is held), both buttons run forward. The view swings back behind you as you walk. Wheel zooms from first person out to 36 m; the camera pulls in at walls and never goes under the ground.
Combat is target-based (using any offensive ability on an enemy starts auto attacking it; there is no attack key): left-click or Tab selects an enemy, right-click an enemy to select it and start auto-attacking. Abilities and attacks aim at your target, or straight ahead with none.

## Interface
Everything opens in a panel docked at the bottom right (Character, Skills, Bag, Quests, Settings, and the cooking / herblore / crafting stations), RuneScape style. The game never pauses; Esc closes the panel or opens the Settings & menu tab (save, main menu, class switch, testing). The shop and forge dock on the right and close when you walk away.

## The world
About 800 m across now (2.5x wider than before, ~6x the area); `World.N` / `World.S` in `scripts/world.gd` scale it.
You wake up at **Wanderer's Rest**, a little camp south of town with a pond, brush and oaks. **Old Tam** walks you
through a 7-step tutorial (twigs, wooden tools at the camp bench, chopping, firemaking, fishing, cooking), with a golden
beam and diamond over the next target, a sparkle pointing the way above your head, a marker on the map and the step
shown in the HUD tracker. The last step sends you up the road to **Hearthmoor**, the walled castle town around the Hearth
Shrine, to meet **King Aldren** in the keep, who sends you to **Elder Rowan** for the town chain (forge, mining, combat,
Slayer, then the Wisp and the main story). Old saves skip the tutorial. Camp code: `World._carve_camp`, `Quests`
(`tam` / `king` in `Data.SIDE_QUESTS`), `scripts/guide.gd`.

## Towns & camps kit
`scripts/town_kit.gd` builds low-poly buildings and props in four region styles (meadow, thornwood, mire, peaks):
cottages, two-storey houses, longhouse, tavern, shop, smithy, chapel, watchtower, windmill, barn, stilt hut, stone lodge;
palisade, stone wall, fence, gatehouse, wall tower; and ~25 props (well, market stall, lamp posts, barrels, crates, carts, tents,
yurts, bedrolls, campfire and spit, weapon rack, banners, pier, bridge...). `TownKit.village(style, seed)` lays out a whole
village and `TownKit.camp(style, seed, "hunters" | "bandits" | "pilgrims")` a camp.
**To look around:** open `scenes/asset_gallery.tscn` and press **F6**. WASD to fly, hold right mouse to look, Q/E down/up, wheel = speed.

## Skills (RuneScape-style, levels 1-30)
Press **U** (or the bars button, bottom right) for the skill guide: every skill, its level, XP, and what each level unlocks.
- **Combat:** Melee (Warrior, Rogue), Magic (Mage), Ranged (Hunter). Your class's combat skill *is* your level: health, damage, abilities.
- **Gathering:** Mining (ore rocks), Woodcutting (oak trees, heartwood logs), Herblore herbs (flowering bushes), Fishing (ripples on the water). Click one and your character keeps working it until it runs dry; moving or attacking stops.
- **Making:** Cooking at campfires (shrine + every quest giver), Herblore at the Alchemy Table, Crafting at the Workbench (tools, bigger bags) and rings/amulets at the forge, Smithing for everything else at Hilde's forge.
- **Agility:** obstacle courses (Meadow Run, Thornwood Gauntlet, Frostspine Climb): run the glowing gates in order and jump the hurdles. Sprinting and jumping trickle XP. Faster movement and stamina; double jump at 15.
- **Slayer:** Varka by the shrine hands out kill tasks. Bonus damage against your task.
- **Action bar:** starts empty. Press **N** (Abilities) and add class abilities to slots 1-6; right-click a bar slot to clear it. Potions and food are not on the bar: right-click them in your bag.

## Talents (T) and the Rogue
One talent point per level after the first (free respec). Rogues have two trees:
- **Shadowblade** (stealth and burst): Ambush, Keen Edge, Smoke Bomb, Preparation, Blade Flurry, Deep Cover, Lethality, and the capstone **Assassinate**.
- **Venomcraft** (poison and damage over time): Poison Blade, Potent Toxins, Lingering Venom, Toxic Veil, Fan of Knives, Festering Wounds, Crippling Toxin, Deadly Dose, and the capstone **Venom Burst**.
Both share **Stealth**, learned at level 2. Rogues dual wield: a main hand and an off-hand (daggers or shortswords; the off-hand hits for half). Armor is by class: plate (warrior), mail (hunter), leather (rogue), cloth (mage).

## Tools and the making chain
Everything starts from nothing: you make your own tools. Gather **twigs** from brush by hand, make wooden tools, then work up.
- **Workbench:** Wooden Pickaxe, Axe, Knife (twigs) and the Fishing Rod (twigs). Wooden tools do the first tier (copper, oak).
- **Tiers:** wooden → copper → bog iron → frost pickaxes and axes. Heartwood and bog iron need a copper tool, frost crystal needs a bog iron pick. Better tools work faster. A copper knife gives extra bait.
- **Furnace** (in the square): smelt ore into bars (Smithing), and melt Mossgel + a log into Glass Vials.
- **Anvil:** bars into copper, bog iron and frost tools, plus Flint and Steel. Each is made once and lives in your bag.
- **Workbench (also):** bags and faster Sturdy tools.
- **Mining** needs a pickaxe, **Woodcutting** an axe, **Fishing** a rod and bait. Bait is cut from fresh kills with a Knife (Mosslets and Beetles give Grub Bait, wolves and spiders Spider Bait, and so on).
- **Herblore:** every potion uses a Glass Vial, a herb from a plant and a secondary from a monster.
- **Firemaking:** right-click a log to cut kindling (needs a Knife), then right-click kindling to light it (needs Flint and Steel and another log). Higher levels burn better logs. Cook on your fire.
- A full bag blocks everything: drag an item out of the bag to drop it.

## Dev mode
Off by default. Settings (O) → Testing: unlimited gold and materials (a full stack of everything but tools, in a 64-slot bag), and quest objectives (runestones, sigils, side-quest counts) fill themselves. It no longer boosts damage.

## Build Editor (F3, dev mode)
Turn on dev mode, press **F3**. The game pauses and you become a free camera (hold right mouse + WASD, Q/E down/up, Shift fast, wheel dollies, F focus, T top view). Click a building to open it, click a piece of furniture to select it.
- **M** move tool (arrows, XZ square, or just drag the piece), **R** rotate ring. Snap 0.25 m / 15°, hold Alt for fine.
- Arrow keys nudge (Shift ×4, Alt fine), PageUp/Down height, [ ] rotate. Ctrl+D duplicate, Delete, Ctrl+Z / Ctrl+Y.
- Right panel: exact X/Y/Z/Rot numbers, Add-a-piece palette, piece list, Restore deleted, Reset building, floor toggle. A check lists props inside walls, overlapping, or blocking doors.
- Edits autosave to `res://layouts/<building kind>.json` and apply to every copy of that kind. Keep that folder (and include *.json in exports). Pieces are named `kind_N` in build order.

## Difficulty knobs
`HP_MULT` / `DMG_MULT` / `BOSS_*` at the top of `scripts/enemy.gd`, and `KILL_XP_MULT` at the top of `scripts/combat.gd`.

## Where things live
- `scripts/data.gd`: classes, abilities, story text, side quests, shop prices, key bindings. Most tuning happens here.
- `scripts/world.gd`: builds the map (terrain, water, trees, shrine, runestones, altars).
- `scripts/player.gd`: movement, sprint, jumping, stamina, class resources and buffs.
- `scripts/combat.gd`: spawning, attacks, all 24 abilities, projectiles, pickups, bosses, hit effects.
- `scripts/enemy.gd`: enemy and boss behaviour (aggro range and leash at the top, chasing, shooting, special moves like charges, pounces and burrowing, boss attack patterns).
- `scripts/camera_rig.gd`: the tilted camera and tilt-shift blur.
- `scripts/ui.gd`: title screen, HUD, ability bar, map, dialog, pause menu, quest book and settings.
- `scripts/skills.gd`: all the skills: XP and levels, gathering, recipes, food and potions, Slayer tasks, agility courses.
- `scripts/camera_rig.gd`: the WoW-style camera (orbit / steer / zoom / collision) and click-vs-drag detection.
- `scripts/clicker.gd`: point-and-click: what's under the mouse, the hover label and ring, walking over to things.
- `scripts/main.gd`: game flow, story interactions, inventory actions and saving.
- `scripts/quests.gd`: side quests, quest givers, gatherable plants, named elites, and Bramble's figure.
- `scripts/models.gd`: every character, creature, boss, tree, rock and pickup, built from simple shapes. Colours for each hero/NPC are in `HEROES` at the top.
- `scripts/rig.gd`: animates those models in code (walk cycles, swings, casts, jumps, hit flashes, tints).
- `scripts/sprite_art.gd` and `tools/make_sprites.py`: the old 2D sprites. No longer used; safe to delete.
- `scripts/crafting.gd`: materials, resource nodes (ore, logs, crystals), Hilde's forge, and craft / upgrade / salvage.
- `scripts/items.gd`: gear generation (names, rarities, stats, icons) and tooltips.
- `scripts/audio.gd`: sound effects and music (`Sfx.play("hit")`, `Sfx.music("meadow")`).
- `assets/audio/`: the sounds and music. `tools/make_audio.py` regenerates them (Python + numpy + scipy + ffmpeg); swap any file for your own with the same name.

## Sky, light & atmosphere
- `scripts/daynight.gd`: 12-minute day/night cycle (starts at a bright morning, frozen while you're in the tutorial camp, saved as `tod`).
  Custom sky shader (sun, moon, stars, drifting clouds), time-of-day ambient/fog/exposure blended with each biome's mood, slow overcast/mist weather.
- Town lamps and windows light up at night, fires flicker, and you carry a small lantern after dark.
- Ambient particles: pollen (meadow), leaves (Thornwood), spores (Mire), snow (Frostspine), fireflies at night.
- Water shader: shallows vs deep, shore foam, glittering wave normals, sky fresnel.

## UI
- Compact HUD: player frame top-left, target frame top-center (hidden for bosses, whose bar replaces it), minimap with biome + time of day top-right.
- The quest tracker is fixed under the minimap and never moves; it only fades if a panel is drawn over it.
- Bag/character panels are small and dock above the menu buttons; windows are compact.
- UI size: Settings > Display (-, +, Reset) or Ctrl/Cmd +/-; saved between sessions (70%-150%).

## Build Editor: how saving works (keep in mind when editing)
- **Save for all** replaces every building of that kind, including any single-building copies (those go to `layouts/backup/`). It then test-builds the narrowest and widest version and warns if a piece clips there.
- Pieces you add next to a wall are saved relative to that wall (`ax`/`az` in the JSON), so they stay flush when houses are wider or narrower. Moved default pieces are offsets from where the code puts them, which already follows the walls.
- Every save keeps the last 15 versions of that layout file in `layouts/backup/`. Single-building copies match a building within 1.5 m if a village shifts slightly.
