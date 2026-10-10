class_name Combat
extends Node3D
## Everything that happens in a fight: enemy spawning, basic attacks, the 24 class abilities,
## projectiles, damage, pickups, traps, the spirit wolf, boss summoning, and hit effects.

const SPAWN_MIN := 24.0
const SPAWN_MAX := 34.0
const SPAWN_GAP := 9.0      # new enemies keep at least this far from existing ones
const DESPAWN := 56.0
const PICKUP_RANGE := 2.2   # how close you need to be to pick up loot
const KILL_XP_MULT := 0.6   # slows levelling from kills (quests still pay full XP)
## Gap-closers only fire at a selected target within this many metres.
const DASH_RANGE := {"charge": 12.0, "step": 9.0, "assassinate": 8.0}
const BASIC_MULT := 0.4     # auto attack (F) hits for this fraction of a normal hit; abilities carry the damage
const DEV_DMG_MULT := 1.0   # dev mode no longer boosts damage (the game is meant to be hard)
const BOSS_LEASH := 48.0
const SHOT_HEIGHT := 1.0

## Sound played when each ability is cast.
const ABILITY_SOUND := {
	"cleave": "swing_heavy", "charge": "dash", "whirl": "swing_heavy", "shout": "buff", "slam": "slam", "stand": "shield",
	"backstab": "swing", "step": "dash", "fan": "swing", "poison": "buff", "smoke": "smoke", "flurry": "buff", "stealth": "smoke", "assassinate": "swing", "venomburst": "buff",
	"fireball": "fire_cast", "blink": "blink", "nova": "frost", "barrier": "shield", "chain": "lightning", "meteor": "meteor_fall",
	"power": "bow", "disengage": "dodge", "volley": "bow", "trap": "ui_click", "rain": "bow", "wolf": "howl",
}

var main: Node
var world: World
var player: Player
var enemies: Array[Enemy] = []
var boss: Enemy = null
var cooldowns: Array = Combat.fresh_cooldowns()


static func fresh_cooldowns() -> Array:
	var a: Array = []
	a.resize(32)
	a.fill(0.0)
	return a
var texts: Array = []          # floating numbers, drawn by the HUD overlay

var _projectiles: Array = []
var _pickups: Array = []
var _traps: Array = []
var _pet := {}
var _timers: Array = []
var _spawn_t := 0.0
var _mat_cache := {}
var _particle_mesh: QuadMesh


func setup(m: Node) -> void:
	main = m
	world = m.world
	player = m.player
	_particle_mesh = QuadMesh.new()
	_particle_mesh.size = Vector2(0.16, 0.16)
	var pm := StandardMaterial3D.new()
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.vertex_color_use_as_albedo = true
	pm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_particle_mesh.material = pm


func active() -> bool:
	return main.mode == "play" or main.mode == "dead"


func player_hidden() -> bool:
	return player.has_buff("stealth")


func reset() -> void:
	## clears every enemy, projectile and effect (new game, load, main menu)
	for e: Enemy in enemies:
		e.queue_free()
	enemies.clear()
	boss = null
	for p: Dictionary in _projectiles:
		(p["node"] as Node).queue_free()
	_projectiles.clear()
	for k: Dictionary in _pickups:
		(k["node"] as Node).queue_free()
	_pickups.clear()
	for t: Dictionary in _traps:
		(t["node"] as Node).queue_free()
	_traps.clear()
	if not _pet.is_empty():
		(_pet["node"] as Node).queue_free()
	_pet = {}
	_timers.clear()
	texts.clear()
	cooldowns = fresh_cooldowns()
	if world and world.caves:
		world.caves.reset()


# ================================================================ tick
func _physics_process(delta: float) -> void:
	if not active():
		return
	for i in cooldowns.size():
		cooldowns[i] = maxf(0.0, cooldowns[i] - delta)
	_cloak_cd = maxf(0.0, _cloak_cd - delta)
	if main.mode == "play" and player.can_act and _attack_held():
		_try_attack()
	_dash_hits()
	_update_projectiles(delta)
	_update_pickups(delta)
	_update_traps(delta)
	_update_pet(delta)
	for t: Dictionary in _timers.duplicate():
		t["t"] = float(t["t"]) - delta
		if t["t"] <= 0.0:
			_timers.erase(t)
			(t["fn"] as Callable).call()
	_spawn_t -= delta
	if _spawn_t <= 0.0:
		_spawn_t = 1.6
		_try_spawn()
	for e: Enemy in enemies.duplicate():
		if not e.is_boss and not e.is_elite and _flat(e.global_position, player.global_position) > DESPAWN:
			enemies.erase(e)
			e.queue_free()
	if boss and _flat(player.global_position, world.altar_pos[boss.boss_index]) > BOSS_LEASH:
		despawn_boss("%s returns to its slumber. Your sigils are returned." % Data.BOSSES[boss.boss_index]["name"])


func _process(delta: float) -> void:
	for t: Dictionary in texts:
		t["life"] = float(t["life"]) - delta
		t["pos"] = (t["pos"] as Vector3) + Vector3(0, 1.6 * delta, 0)
	texts = texts.filter(func(t: Dictionary) -> bool: return t["life"] > 0.0)


var _cloak_cd := 0.0
var auto_attack := false   # right-clicked an enemy: keep swinging while it is in reach


func _attack_held() -> bool:
	if Input.is_action_pressed("attack"):
		return true
	if auto_attack:
		if not main.has_target():
			auto_attack = false
			return false
		var cc: Dictionary = Data.CLASS_COMBAT[player.class_id]
		var reach: float = float(cc["range"]) + main.target.radius + 1.4 if cc["attack"] == "melee" else 16.0
		return _flat(main.target.global_position, player.global_position) <= reach
	return false


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _pd(mult: float) -> float:
	return player.dmg * mult * (1.3 if player.has_buff("shout") else 1.0) * (1.25 if player.has_buff("might") else 1.0) * (DEV_DMG_MULT if main.dev_mode else 1.0)


# ================================================================ spawning
func _try_spawn() -> void:
	if bool(main.state.get("tut_safe", false)):
		return    # the starting lessons: nothing wanders in until you know your abilities
	var cap := 5 if boss else 12
	if enemies.size() >= cap or player.dead:
		return
	for k in 6:
		var a := randf() * TAU
		var d := randf_range(SPAWN_MIN, SPAWN_MAX)
		var p := player.global_position + Vector3(cos(a), 0, sin(a)) * d
		if absf(p.x) > World.HALF - 6.0 or absf(p.z) > World.HALF - 6.0:
			continue
		if _flat(p, world.shrine_pos) < world.town_radius + 14.0 or world.is_water(p.x, p.z):
			continue
		var crowded := false
		for o: Enemy in enemies:
			if _flat(o.global_position, p) < SPAWN_GAP:
				crowded = true
				break
		if crowded:
			continue
		var b := world.biome_at(p)
		var list: Array = Data.SPAWN_TABLE[b]
		if world.zone_at(p) == 7:
			list = Data.GREYFOLD_SPAWN
		spawn_enemy(list[randi() % list.size()], p, b)
		return


func spawn_elite(id: String, pos: Vector3) -> Enemy:
	var e := Enemy.new()
	e.setup_elite(self, id, world.biome_at(pos))
	e.level = world.rec_level(pos, true)
	add_child(e)
	e.global_position = Vector3(pos.x, world.height_at(pos.x, pos.z) + 0.3, pos.z)
	e.aggro = false
	enemies.append(e)
	burst(e.center(), Color("ff8a5a"), 30, 6.0, 0.8, 0.25)
	return e


func spawn_enemy(id: String, pos: Vector3, b: int) -> Enemy:
	var e := Enemy.new()
	e.setup_enemy(self, id, b)
	e.level = world.rec_level(pos)
	add_child(e)
	e.global_position = Vector3(pos.x, world.height_at(pos.x, pos.z) + 0.3, pos.z)
	enemies.append(e)
	return e


# ================================================================ damage
func damage_enemy(e: Enemy, amount: float, dir: Vector3, knock: float, o := {}) -> void:
	if e == null or e.dead or e.burrowed:
		return
	var dot: bool = o.get("dot", false)
	var crit := false
	var from_stealth := false
	if not dot:
		if player.has_buff("stealth"):
			crit = true
			from_stealth = true
			player.buffs.erase("stealth")
			if main.talent_rank("sh_dance") > 0:
				player.gain_res(30.0)
		elif randf() < player.crit + 0.04 * main.talent_rank("sh_keen"):
			crit = true
	if from_stealth:
		amount *= 1.0 + 0.3 * main.talent_rank("sh_ambush")
	if crit:
		amount *= 2.0 + 0.2 * main.talent_rank("sh_lethal")
	if not dot and e.poison_t > 0.0:
		amount *= 1.0 + 0.08 * main.talent_rank("ve_fester")
	if e.hp < e.max_hp * 0.3:
		amount *= 1.0 + 0.15 * (main.talent_rank("sh_exec") + main.talent_rank("bw_exec"))
	if e.is_boss or e.is_elite:
		amount *= 1.0 + 0.1 * (main.talent_rank("sh_marked") + main.talent_rank("ve_marked") + main.talent_rank("bw_marked"))
	amount *= main.skills.damage_mult(e)
	amount = maxf(1.0, round(amount))
	e.hp -= amount
	var col := Color("9be05a") if dot else (Color("ffd27a") if crit else Color.WHITE)
	float_text(e.global_position + Vector3(0, e.height + 0.4, 0), str(int(amount)) + ("!" if crit else ""), col)
	if not dot:
		Sfx.play("hit_crit" if crit else "hit", e.global_position, -2.0 if crit else -5.0)
		e.flash = 0.12
		e.aggro = true
		if not main.has_target():
			main.set_target(e)
		if not e.is_boss:
			e.knock += Vector3(dir.x, 0, dir.z) * knock
			if o.has("stun"):
				e.stun = maxf(e.stun, o["stun"])
			if o.has("root"):
				e.root = maxf(e.root, o["root"])
		if player.has_buff("poison") or (from_stealth and main.talent_rank("ve_veil") > 0):
			var pmult: float = 1.0 + 0.2 * main.talent_rank("ve_potent") + 0.25 * main.talent_rank("ve_deadly")
			e.apply_poison(player.dmg * 0.35 * pmult, 4.0 + 2.0 * main.talent_rank("ve_lasting"))
		if e.poison_t > 0.0 and main.talent_rank("ve_cripple") > 0:
			e.slow = maxf(e.slow, 1.5)
		if player.class_id == "hunter":
			player.gain_res(2.0)
		player.combat_t = 0.0
		burst(e.center(), Color(Data.BOSSES[e.boss_index]["color"]) if e.is_boss else Color.WHITE, 5, 3.0, 0.3)
	if o.has("slow"):
		e.slow = maxf(e.slow, o["slow"])
	if e.hp <= 0.0:
		_kill(e)


func kill(e: Enemy) -> void:
	if not e.dead:
		_kill(e)


func _kill(e: Enemy) -> void:
	e.dead = true
	enemies.erase(e)
	if e.is_boss:
		_boss_defeated(e)
		return
	var d: Dictionary = Data.ENEMIES[e.type_id]
	Sfx.play("enemy_die", e.global_position, -3.0)
	var heal: float = 0.03 * (main.talent_rank("sh_drink") + main.talent_rank("ve_feast") + main.talent_rank("bw_second"))
	if heal > 0.0:
		player.hp = minf(player.max_hp, player.hp + player.max_hp * heal)
	if main.talent_rank("bw_blood") > 0:
		player.gain_res(10.0 * main.talent_rank("bw_blood"))
	if e.poison_t > 0.0 and main.talent_rank("ve_contagion") > 0:
		for o: Enemy in enemies:
			if o != e and not o.dead and _flat(o.global_position, e.global_position) < 6.0:
				o.apply_poison(player.dmg * 0.35 * (1.0 + 0.2 * main.talent_rank("ve_potent") + 0.25 * main.talent_rank("ve_deadly")), 4.0 + 2.0 * main.talent_rank("ve_lasting"))
	burst(e.center(), Color((d["pal"] as Dictionary).get("g", "a8a0b0")), 16, 5.0, 0.6, 0.2)
	if randf() < 0.06:
		var lvl: int = mini(world.rec_level(e.global_position), Data.MAX_SKILL)
		_drop_item(e.global_position + Vector3(randf_range(-0.6, 0.6), 0, randf_range(-0.6, 0.6)),
			Items.generate(lvl, player.class_id, Items.roll_rarity([80.0, 15.0, 4.5, 0.5, 0.0])))
	main.gain_xp(maxi(1, roundi(e.xp * KILL_XP_MULT)))
	var loot := {"gold": maxi(1, roundi(e.xp * 0.35 * randf_range(0.7, 1.3))), "mats": {}}
	main.quests.on_kill(e)
	main.skills.on_kill(e)
	for md: Array in Data.ENEMY_MATS.get(e.type_id, []):
		if randf() < float(md[1]):
			_add_loot_mat(loot, md[0], 1)
	# with a knife in your bag you cut fishing bait from the right creatures
	if Data.BAIT_MOBS.has(e.type_id) and main.skills.tool_tier("knife") >= 0 and randf() < 0.85:
		_add_loot_mat(loot, Data.BAIT_MOBS[e.type_id], randi_range(1 + maxi(0, main.skills.tool_tier("knife")), 2 + maxi(0, main.skills.tool_tier("knife"))))
	if e.is_elite:
		var tier: Dictionary = Data.CRAFT_TIERS[clampi(e.biome, 0, 3)]
		_add_loot_mat(loot, "ember", 1)
		_add_loot_mat(loot, tier["primary"], 3)
		_add_loot_mat(loot, tier["secondary"], 3)
		drop_loot(e.global_position, loot)
		Sfx.play("boss_die", e.global_position, -4.0)
		for k in 2:
			var lv: int = mini(world.rec_level(e.global_position, true), Data.MAX_SKILL)
			_drop_item(e.global_position + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)), Items.generate(lv, player.class_id, Items.roll_rarity([0.0, 55.0, 38.0, 7.0, 0.0])))
		e.queue_free()
		return
	var st: Dictionary = main.state
	var bi := int(st["bi"])
	var b: Dictionary = Data.BOSSES[bi]
	if not st["done"] and int(st["step"]) <= 1 and e.biome == int(b["biome"]) and randf() < 0.38:
		loot["sigil"] = 1
	elif randf() < 0.09:
		loot["potion"] = 1
	drop_loot(e.global_position, loot)
	e.queue_free()


func hurt_player(amount: float, _src: Node = null) -> void:
	if player.is_untouchable() or main.mode != "play":
		return
	player.armed_t = maxf(player.armed_t, 6.0)
	if player.has_buff("stand"):
		amount *= 0.3
	if player.has_buff("barrier") and player.shield > 0.0:
		var ab := minf(player.shield, amount)
		player.shield -= ab
		amount -= ab
		if ab > 0.0:
			float_text(player.global_position + Vector3(0, 2.6, 0), "absorbed", Color("c0a0ff"))
		if amount <= 0.0:
			player.inv_t = 0.25
			return
	if randf() < 0.03 * (main.talent_rank("sh_evasion") + main.talent_rank("ve_dodge")):
		float_text(player.global_position + Vector3(0, 2.3, 0), "dodged", Color("c8d8ff"))
		player.inv_t = 0.25
		return
	amount = round(amount * (1.0 - player.armor_red) * (1.0 - 0.03 * main.talent_rank("bw_stalwart")))
	Sfx.play("hurt", Vector3.INF, -3.0)
	player.hp -= amount
	player.inv_t = 0.5
	player.combat_t = 0.0
	player.buffs.erase("stealth")
	if main.talent_rank("sh_cloak") > 0 and _cloak_cd <= 0.0 and player.hp > 0.0 and player.hp < player.max_hp * 0.3:
		_cloak_cd = 45.0
		player.buffs["stealth"] = 4.0
		_lose_track(14.0)
		float_text(player.global_position + Vector3(0, 2.8, 0), "Shadow Cloak", Color("b49af0"))
	if player.class_id == "warrior" and main.talent_rank("bw_rally") > 0:
		player.gain_res(amount * 0.15 * main.talent_rank("bw_rally"))
	main.rig.shake = minf(0.6, main.rig.shake + 0.3)
	float_text(player.global_position + Vector3(0, 2.3, 0), "-%d" % int(amount), Color("ff6a5a"))
	burst(player.global_position + Vector3(0, 1.0, 0), Color("d9483b"), 8, 3.0, 0.35)
	if player.hp <= 0.0:
		player.hp = 0.0
		main.player_died()


func float_text(pos: Vector3, text: String, col: Color) -> void:
	texts.append({"pos": pos + Vector3(randf_range(-0.3, 0.3), 0, 0), "text": text, "color": col, "life": 0.9})


# ================================================================ attacks
func _try_attack() -> void:
	if player.attack_t > 0.0 or player.dead or not player.dash.is_empty():
		return
	var cc: Dictionary = Data.CLASS_COMBAT[player.class_id]
	player.attack_t = float(cc["cd"]) * (0.5 if player.has_buff("flurry") else 1.0) * maxf(0.4, 1.0 - 0.08 * main.talent_rank("sh_quick") - 0.06 * (main.talent_rank("ve_quick") + main.talent_rank("bw_quick")))
	if cc["attack"] == "bolt":
		player.anim_cast(0.25)
	else:
		player.anim_attack(minf(0.3, player.attack_t * 0.9))
	match cc["attack"]:
		"melee":
			Sfx.play("swing_heavy" if player.class_id == "warrior" else "swing", Vector3.INF, -6.0)
			_melee(cc["range"], cc["arc"], BASIC_MULT, cc["knock"], Color("fff4d8"))
		"bolt":
			Sfx.play("bolt", Vector3.INF, -8.0)
			_player_shot(player.aim_dir, cc["speed"], _pd(BASIC_MULT), "bolt", Color("c49bff"), cc["life"])
		"arrow":
			Sfx.play("bow", Vector3.INF, -6.0)
			_player_shot(player.aim_dir, cc["speed"], _pd(BASIC_MULT), "arrow", Color("e8d8b0"), cc["life"])


func _melee(rng: float, arc: float, mult: float, knock: float, col: Color, o := {}) -> int:
	player.swing_t = 0.18
	var origin := player.global_position
	var a := player.aim_dir
	slash(origin, a, rng, arc, col)
	var n := 0
	for e: Enemy in enemies.duplicate():
		var to := e.global_position - origin
		to.y = 0.0
		var d := to.length()
		if d > rng + e.radius + 0.7:
			continue
		var ok := d < 0.4 or acos(clampf(a.dot(to / d), -1.0, 1.0)) < arc * 0.5 + 0.25
		if ok:
			damage_enemy(e, _pd(mult), to / maxf(d, 0.01), knock, o)
			n += 1
	return n


func _aoe(c: Vector3, r: float, mult: float, knock: float, o := {}) -> void:
	for e: Enemy in enemies.duplicate():
		var to := e.global_position - c
		to.y = 0.0
		if to.length() < r + e.radius:
			if o.get("nodmg", false):
				e.slow = maxf(e.slow, float(o.get("slow", 0.0)))
				continue
			damage_enemy(e, _pd(mult), to.normalized(), knock, o)


## Regular enemies within `r` of you stop chasing (stealth, smoke).
func _lose_track(r: float) -> void:
	for e: Enemy in enemies:
		if not e.is_boss and _flat(e.global_position, player.global_position) <= r:
			e.aggro = false


func _player_shot(dir: Vector3, speed: float, dmg: float, kind: String, col: Color, life: float, extra := {}) -> void:
	shoot(player.global_position + dir * 0.6, dir, speed, dmg, "player", kind, col, life, extra)


func _dash_hits() -> void:
	if player.dash.is_empty() or float(player.dash["mult"]) <= 0.0:
		return
	var hit: Dictionary = player.dash["hit"]
	var v: Vector3 = player.dash["vel"]
	for e: Enemy in enemies.duplicate():
		if hit.has(e):
			continue
		if _flat(e.global_position, player.global_position) < 1.0 + e.radius:
			hit[e] = true
			damage_enemy(e, _pd(player.dash["mult"]), v.normalized(), 4.0, player.dash["opts"])
	if randf() < 0.7:
		burst(player.global_position + Vector3(0, 0.8, 0), Color("6a6478"), 1, 0.5, 0.25, 0.25)


# ================================================================ abilities
## Press an action-bar slot (0-5): uses whatever ability you put there.
func cast(slot: int) -> void:
	var idx: int = main.bar_ability(slot)
	if idx < 0:
		if main.mode == "play" and player.can_act and not player.dead:
			main.ui.toast("Empty slot. Press N to add abilities to your bar.")
		return
	cast_ability(idx, slot)


func cast_ability(i: int, slot := -1) -> void:
	if main.mode != "play" or not player.can_act or player.dead:
		return
	var a: Dictionary = main.ability_view(Data.ABILITIES[player.class_id][i])
	var res_name: String = Data.CLASSES[player.class_id]["resource"]
	var lock: String = main.ability_locked(i)
	if lock != "":
		main.ui.toast("%s is learned in your talents (T)" % a["name"] if lock == "TALENT" else "%s unlocks at level %d" % [a["name"], a["lvl"]])
		main.ui.flash_slot(slot)
		return
	# pressing an offensive ability at an enemy starts auto attack, even if it is on cooldown or you lack the resource
	if main.has_target() and not (a["id"] in ["stand", "barrier", "blink", "disengage", "stealth", "smoke", "shout", "poison", "flurry", "wolf", "trap"]):
		auto_attack = true
	if cooldowns[i] > 0.0 or not player.dash.is_empty():
		return
	if player.res < float(a["cost"]):
		main.ui.toast("Not enough %s" % res_name.to_lower())
		main.ui.flash_slot(slot)
		return
	if a["id"] in DASH_RANGE:
		var rng: float = DASH_RANGE[a["id"]]
		if not main.has_target():
			main.ui.toast("%s needs a target" % a["name"])
			main.ui.flash_slot(slot)
			return
		if _flat(main.target.global_position, player.global_position) > rng + main.target.radius:
			main.ui.toast("Out of range (%d m)" % int(rng))
			main.ui.flash_slot(slot)
			return
	if not _do(a["id"]):
		return
	if player.class_id == "mage" or a["id"] in ["shout", "poison", "smoke", "trap", "wolf", "stand", "flurry", "stealth", "venomburst"]:
		player.anim_cast(0.45)
	else:
		player.anim_attack(0.3)
	var snd: String = ABILITY_SOUND.get(a["id"], "")
	if snd != "":
		Sfx.play(snd, Vector3.INF, -3.0, 0.04)
	player.res -= float(a["cost"])
	if a["id"] == "charge":
		player.gain_res(15.0)
	var cdm: float = 1.0
	if a["id"] in ["stealth", "smoke"]:
		cdm = 1.0 - 0.2 * main.talent_rank("sh_prep")
	cooldowns[i] = float(a["cd"]) * cdm
	player.combat_t = 0.0
	# using an offensive ability on an enemy starts auto attacking it
	if main.has_target() and not (a["id"] in ["stand", "barrier", "blink", "disengage", "stealth", "smoke"]):
		auto_attack = true


func _do(id: String) -> bool:
	var p := player.global_position
	var aim := player.aim_dir
	var chest := p + Vector3(0, 1.0, 0)
	match id:
		# ---------------- melee: the base blow
		"strike":
			if main.talent_rank("bw_heroic") > 0:
				_melee(2.5, 1.7, 3.0, 7.0, Color("ffc070"))
				var hh := player.max_hp * 0.06
				player.hp = minf(player.max_hp, player.hp + hh)
				float_text(p + Vector3(0, 2.4, 0), "+%d" % int(hh), Color("7be08a"))
				burst(chest, Color("ffc070"), 12, 4.0, 0.4)
			elif main.talent_rank("sh_sinister") > 0:
				_melee(2.1, 1.5, 1.4, 3.0, Color("ff6a7a"))
				_timers.append({"t": 0.12, "fn": func() -> void: _melee(2.1, 1.5, 1.4, 3.0, Color("ff6a7a"))})
			elif main.talent_rank("sh_backstab") > 0:
				_melee(1.9, 1.4, 2.8, 3.0, Color("ff6a7a"))
			else:
				_melee(2.4, 1.6, 2.2, 5.0, Color("ffd8a0"))
		# ---------------- bulwark
		"cleave":
			_melee(2.9, 3.1, 1.7, 8.0, Color("ffb080"))
			main.rig.shake += 0.15
		"charge":
			var cdir := _dash_dir(1.4)
			player.start_dash(cdir[0] * clampf(cdir[1] / 0.24, 8.0, 60.0), 0.24, 1.2, {"stun": 1.2})
		"whirl":
			player.swing_t = 0.35
			ring(p, 3.0, Color("ffe0a0"), 0.3)
			_aoe(p, 3.0, 2.0, 9.0)
			main.rig.shake += 0.2
		"shout":
			player.buffs["shout"] = 8.0
			var heal := player.max_hp * 0.2
			player.hp = minf(player.max_hp, player.hp + heal)
			float_text(p + Vector3(0, 2.4, 0), "+%d" % int(heal), Color("7be08a"))
			ring(p, 3.6, Color("ff6a4a"), 0.5)
			burst(chest, Color("ff8a5a"), 20, 5.0, 0.6)
		"slam":
			ring(p, 3.9, Color("c8a070"), 0.45)
			ring(p, 2.2, Color.WHITE, 0.3)
			_aoe(p, 3.9, 2.5, 7.0, {"slow": 2.5})
			burst(p + Vector3(0, 0.2, 0), Color("8a6038"), 30, 7.0, 0.6, 0.22)
			main.rig.shake += 0.5
		"stand":
			player.buffs["stand"] = 5.0
			burst(chest, Color("c0c8d4"), 18, 4.0, 0.5)
		# ---------------- shadow and venom
		"backstab":
			_melee(1.9, 1.4, 2.8, 3.0, Color("ff6a7a"))
		"step":
			var sdir := _dash_dir(-2.0)
			player.start_dash(sdir[0] * clampf(sdir[1] / 0.2, 8.0, 60.0), 0.2, 2.2, {})
			burst(chest, Color("7a1e2c"), 10, 3.0, 0.4)
		"fan":
			for k in 12:
				var a := k / 12.0 * TAU
				_player_shot(Vector3(cos(a), 0, sin(a)), 16.0, _pd(1.2), "knife", Color("d8dce6"), 0.45)
		"poison":
			player.buffs["poison"] = 8.0 + 4.0 * main.talent_rank("ve_dose")
			burst(chest, Color("6ab040"), 16, 4.0, 0.5)
		"stealth":
			player.buffs["stealth"] = 15.0 + 5.0 * main.talent_rank("sh_deep")
			_lose_track(14.0)
			burst(chest, Color("3a3458"), 24, 3.0, 0.8, 0.3)
		"smoke":
			player.buffs["stealth"] = 5.0 + 5.0 * main.talent_rank("sh_deep")
			ring(p, 4.0, Color("8a8a9a"), 0.4)
			_aoe(p, 4.0, 0.0, 0.0, {"slow": 3.0, "nodmg": true})
			_lose_track(20.0)
			burst(chest, Color("8a8a9a"), 40, 5.0, 1.1, 0.35)
		"assassinate":
			var tg: Enemy = main.target
			var behind := (tg.global_position - player.global_position).normalized()
			behind.y = 0.0
			burst(chest, Color("7a1e2c"), 16, 4.0, 0.4)
			var dest := tg.global_position + behind * 1.2
			player.teleport(Vector3(dest.x, world.height_at(dest.x, dest.z) + 0.15, dest.z))
			player.aim_dir = -behind
			player.inv_t = maxf(player.inv_t, 0.3)
			damage_enemy(tg, _pd(7.0), behind, 4.0)
			main.rig.shake += 0.35
			burst(tg.center(), Color("ff6a7a"), 24, 6.0, 0.5)
		"venomburst":
			var n := 0
			for e: Enemy in enemies.duplicate():
				if e.poison_t > 0.0 and _flat(e.global_position, p) <= 14.0:
					var rest := e.poison_dps * e.poison_t * 2.0
					e.poison_t = 0.0
					n += 1
					burst(e.center(), Color("6ac040"), 20, 5.0, 0.5)
					damage_enemy(e, maxf(rest, 1.0), Vector3.ZERO, 0.0, {"dot": true})
			if n == 0:
				main.ui.toast("No poisoned enemies nearby")
				return false
			ring(p, 3.0, Color("6ac040"), 0.4)
		"flurry":
			player.buffs["flurry"] = 5.0
			burst(chest, Color("ffd27a"), 14, 4.0, 0.5)
		# ---------------- mage
		"fireball":
			_player_shot(aim, 13.0, _pd(2.0), "fire", Color("ff7a3a"), 1.0, {"aoe": 2.4, "r": 0.32})
		"blink":
			_blink(player.forward_vec())   # straight ahead, wherever your character faces
		"nova":
			ring(p, 4.0, Color("9fe0ff"), 0.35)
			_aoe(p, 4.0, 1.6, 4.0, {"slow": 3.0})
			burst(chest, Color("cfefff"), 24, 8.0, 0.5)
		"barrier":
			player.buffs["barrier"] = 8.0
			player.shield = player.max_hp * 0.4
			ring(p, 1.2, Color("c0a0ff"), 0.4)
		"chain":
			return _chain()
		"meteor":
			var t := player.aim_point
			t.y = world.height_at(t.x, t.z)
			_mark(t, 3.2, Color("ff7a3a"), 0.9)
			_meteor_fall(t)
			var impact := func() -> void:
				_aoe(t, 3.2, 5.0, 10.0)
				Sfx.play("explosion", t)
				ring(t, 3.6, Color("ffb060"), 0.5)
				burst(t + Vector3(0, 0.3, 0), Color("ff7a3a"), 40, 9.0, 0.8, 0.25)
				burst(t + Vector3(0, 0.3, 0), Color("ffd27a"), 20, 6.0, 0.6)
				main.rig.shake += 0.7
			_timers.append({"t": 0.9, "fn": impact})
		# ---------------- hunter
		"power":
			_player_shot(aim, 24.0, _pd(2.6), "arrow", Color("ffd27a"), 0.9, {"pierce": {}, "big": true})
		"disengage":
			player.start_dash(-aim * 22.5, 0.22, 0.0, {})
		"volley":
			for k in range(-2, 3):
				_player_shot(aim.rotated(Vector3.UP, k * 0.17), 18.0, _pd(1.1), "arrow", Color("ffe9a8"), 0.8)
		"trap":
			_place_trap(p)
		"rain":
			var t2 := player.aim_point
			t2.y = world.height_at(t2.x, t2.z)
			_mark(t2, 2.8, Color("e8d8b0"), 2.0)
			var volley_tick := func() -> void:
				_aoe(t2, 2.8, 0.8, 1.5)
				Sfx.play("arrow_hit", t2, -6.0, 0.2)
				for j in 6:
					var off := Vector3(randf_range(-2.4, 2.4), 0, randf_range(-2.4, 2.4))
					burst(t2 + off + Vector3(0, 0.2, 0), Color("e8d8b0"), 2, 1.5, 0.2)
			for k in 6:
				_timers.append({"t": 0.15 + k * 0.33, "fn": volley_tick})
		"wolf":
			_summon_pet()
	return true


## Direction to the target and how far to travel (distance minus `stop`; a negative stop runs past it).
func _dash_dir(stop: float) -> Array:
	var to: Vector3 = main.target.global_position - player.global_position
	to.y = 0.0
	var d := to.length()
	var dir := to / maxf(d, 0.01)
	player.aim_dir = dir
	return [dir, maxf(2.0, d - stop)]


func _blink(aim: Vector3) -> void:
	var p := player.global_position
	var space := get_world_3d().direct_space_state
	var target := p
	var step := 0.4
	var dist := step
	while dist <= 6.5:
		var c := p + aim * dist
		if world.is_water(c.x, c.z):
			break
		var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 1.0, 0), c + Vector3(0, 1.0, 0), 2)
		if not space.intersect_ray(q).is_empty():
			break
		target = c
		dist += step
	burst(p + Vector3(0, 1.0, 0), Color("b080ff"), 18, 4.0, 0.5)
	player.teleport(Vector3(target.x, world.height_at(target.x, target.z) + 0.15, target.z))
	player.inv_t = maxf(player.inv_t, 0.2)
	burst(player.global_position + Vector3(0, 1.0, 0), Color("e0c0ff"), 18, 4.0, 0.5)


func _chain() -> bool:
	var hit := {}
	var from := player.global_position + Vector3(0, 1.0, 0)
	var pts: Array[Vector3] = [from]
	var mult := 1.8
	for k in 5:
		var best: Enemy = null
		var bd := 10.5 if k == 0 else 6.0
		for e: Enemy in enemies:
			if hit.has(e) or e.dead or e.burrowed:
				continue
			var d := from.distance_to(e.center())
			if d < bd:
				bd = d
				best = e
		if best == null:
			break
		hit[best] = true
		pts.append(best.center())
		from = best.center()
		damage_enemy(best, _pd(mult), Vector3.ZERO, 0.0, {"stun": 0.3})
		mult *= 0.85
	if pts.size() < 2:
		main.ui.toast("No target in range")
		return false
	_lightning(pts)
	return true


func _place_trap(p: Vector3) -> void:
	var node := Node3D.new()
	add_child(node)
	node.global_position = Vector3(p.x, world.height_at(p.x, p.z) + 0.05, p.z)
	var base := MeshInstance3D.new()
	base.mesh = _cyl(0.45, 0.06)
	base.material_override = _mat(Color("5a4a30"))
	node.add_child(base)
	for k in 6:
		var tooth := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.06, 0.22, 0.06)
		tooth.mesh = bm
		tooth.material_override = _mat(Color("c0c0c8"))
		var a := k / 6.0 * TAU
		tooth.position = Vector3(cos(a) * 0.38, 0.12, sin(a) * 0.38)
		node.add_child(tooth)
	_traps.append({"node": node, "pos": node.global_position, "t": 30.0})
	if _traps.size() > 3:
		var old: Dictionary = _traps.pop_front()
		(old["node"] as Node).queue_free()


func _update_traps(delta: float) -> void:
	for t: Dictionary in _traps.duplicate():
		t["t"] = float(t["t"]) - delta
		var sprung := false
		for e: Enemy in enemies:
			if _flat(e.global_position, t["pos"]) < 0.8 + e.radius * 0.5:
				damage_enemy(e, _pd(1.5), Vector3.ZERO, 0.0, {"root": 3.0})
				Sfx.play("trap", t["pos"])
				burst(t["pos"] + Vector3(0, 0.3, 0), Color("c0a070"), 12, 4.0, 0.4)
				sprung = true
				break
		if sprung or t["t"] <= 0.0:
			_traps.erase(t)
			(t["node"] as Node).queue_free()


func _summon_pet() -> void:
	if not _pet.is_empty():
		(_pet["node"] as Node).queue_free()
	var node := Node3D.new()
	add_child(node)
	var s := Models.creature("wolf", {"g": "7ac8f0", "G": "d0f0ff", "e": "ffffff"})
	s.scale = Vector3.ONE * 1.2
	node.add_child(s)
	s.set_alpha(0.75)
	s.set_facing(player.aim_dir, true)
	var l := OmniLight3D.new()
	l.light_color = Color("7ac8f0")
	l.omni_range = 3.0
	l.position.y = 0.8
	node.add_child(l)
	var p := player.global_position + Vector3(-1.2, 0, 0.5)
	node.global_position = Vector3(p.x, world.height_at(p.x, p.z), p.z)
	_pet = {"node": node, "sprite": s, "t": 15.0, "cd": 0.0, "anim": 0.0}
	burst(node.global_position + Vector3(0, 0.6, 0), Color("7ac8f0"), 24, 5.0, 0.7)


func _update_pet(delta: float) -> void:
	if _pet.is_empty():
		return
	var node: Node3D = _pet["node"]
	_pet["t"] = float(_pet["t"]) - delta
	_pet["cd"] = float(_pet["cd"]) - delta
	var tgt: Enemy = null
	var bd := 11.0
	for e: Enemy in enemies:
		var d := _flat(e.global_position, player.global_position)
		if d < bd:
			bd = d
			tgt = e
	var goal: Vector3
	var stop: float
	if tgt:
		goal = tgt.global_position
		stop = tgt.radius + 0.6
	else:
		goal = player.global_position - player.aim_dir * 1.5
		stop = 0.8
	var to := goal - node.global_position
	to.y = 0.0
	var d2 := to.length()
	if d2 > stop:
		var sp := minf(d2 - stop, (12.0 if d2 > 6.0 else 7.0) * delta)
		node.global_position += to / d2 * sp
		(_pet["sprite"] as Rig).set_facing(to)
		(_pet["sprite"] as Rig).tick(delta, 1.2)
	else:
		if tgt:
			(_pet["sprite"] as Rig).set_facing(to)
		(_pet["sprite"] as Rig).tick(delta, 0.0)
	node.global_position.y = world.height_at(node.global_position.x, node.global_position.z)
	if tgt and d2 <= stop + 0.3 and float(_pet["cd"]) <= 0.0:
		_pet["cd"] = 0.75
		(_pet["sprite"] as Rig).attack(0.3)
		damage_enemy(tgt, _pd(0.7), to.normalized(), 2.0)
	if float(_pet["t"]) <= 0.0:
		burst(node.global_position + Vector3(0, 0.6, 0), Color("7ac8f0"), 16, 4.0, 0.5)
		node.queue_free()
		_pet = {}


func pet_time() -> float:
	return 0.0 if _pet.is_empty() else float(_pet["t"])


# ================================================================ projectiles
func shoot(from: Vector3, dir: Vector3, speed: float, dmg: float, owner: String, kind: String, col: Color, life: float, extra := {}) -> void:
	var d := Vector3(dir.x, 0, dir.z)
	if d.length() < 0.001:
		d = Vector3.FORWARD
	d = d.normalized()
	var r: float = extra.get("r", 0.12 if kind in ["arrow", "knife"] else 0.2)
	var node := _projectile_node(kind, col, r, extra.get("big", false))
	add_child(node)
	var pos := Vector3(from.x, world.height_at(from.x, from.z) + SHOT_HEIGHT, from.z)
	node.global_position = pos
	if kind in ["arrow", "knife"]:
		node.look_at(pos + d, Vector3.UP)
	if owner == "enemy":
		Sfx.play("enemy_shot" if kind == "arrow" else "orb_shot", pos, -8.0)
	var p := {"node": node, "pos": pos, "vel": d * speed, "dmg": dmg, "from": owner, "kind": kind, "life": life, "r": r}
	p.merge(extra)
	_projectiles.append(p)


func _projectile_node(kind: String, col: Color, r: float, big: bool) -> Node3D:
	var root := Node3D.new()
	var mi := MeshInstance3D.new()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if kind == "arrow" or kind == "knife":
		var bm := BoxMesh.new()
		bm.size = Vector3(0.07, 0.07, (1.0 if big else 0.7) if kind == "arrow" else 0.38)
		mi.mesh = bm
		mi.material_override = _mat(col, true)
	else:
		var sm := SphereMesh.new()
		sm.radius = r
		sm.height = r * 2.0
		sm.radial_segments = 8
		sm.rings = 4
		mi.mesh = sm
		mi.material_override = _mat(col, true)
		var halo := MeshInstance3D.new()
		var hs := SphereMesh.new()
		hs.radius = r * 1.8
		hs.height = r * 3.6
		hs.radial_segments = 8
		hs.rings = 4
		halo.mesh = hs
		halo.material_override = _mat(Color(col, 0.3), true)
		halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(halo)
		if kind == "fire":
			var l := OmniLight3D.new()
			l.light_color = col
			l.omni_range = 4.0
			l.light_energy = 1.5
			root.add_child(l)
	root.add_child(mi)
	return root


func _update_projectiles(delta: float) -> void:
	var done: Array = []
	for p: Dictionary in _projectiles:
		var pos: Vector3 = p["pos"]
		pos += (p["vel"] as Vector3) * delta
		pos.y = world.height_at(pos.x, pos.z) + SHOT_HEIGHT
		p["pos"] = pos
		p["life"] = float(p["life"]) - delta
		(p["node"] as Node3D).global_position = pos
		if p["kind"] == "fire" and randf() < 0.6:
			burst(pos, Color("ffb060") if randf() < 0.5 else Color("ff7a3a"), 1, 0.6, 0.3)
		var ended := false
		if p["from"] == "player":
			for e: Enemy in enemies.duplicate():
				if e.dead or e.burrowed:
					continue
				if p.has("pierce") and (p["pierce"] as Dictionary).has(e):
					continue
				if _flat(pos, e.global_position) < e.radius + float(p["r"]) + 0.15:
					if p.has("aoe"):
						ended = true
						break
					damage_enemy(e, p["dmg"], (p["vel"] as Vector3).normalized(), 7.0 if p.get("big", false) else 4.0)
					if p.has("pierce"):
						(p["pierce"] as Dictionary)[e] = true
					else:
						ended = true
						break
		else:
			if _flat(pos, player.global_position) < 0.45 + float(p["r"]) and not player.is_untouchable():
				hurt_player(p["dmg"])
				ended = true
		if ended or float(p["life"]) <= 0.0:
			if p.has("aoe"):
				_explode(p)
			done.append(p)
	for p: Dictionary in done:
		_projectiles.erase(p)
		(p["node"] as Node).queue_free()


func _explode(p: Dictionary) -> void:
	var pos: Vector3 = p["pos"]
	Sfx.play("explosion", pos, -4.0)
	var r: float = p["aoe"]
	for e: Enemy in enemies.duplicate():
		if _flat(pos, e.global_position) < r + e.radius:
			var dir := e.global_position - pos
			damage_enemy(e, p["dmg"], dir.normalized(), 6.0)
	ring(pos - Vector3(0, SHOT_HEIGHT - 0.1, 0), r, Color("ffb060"), 0.3)
	burst(pos, Color("ff7a3a"), 18, 6.0, 0.5, 0.2)
	burst(pos, Color("ffd27a"), 8, 4.0, 0.4)


func clear_enemy_shots() -> void:
	for p: Dictionary in _projectiles.duplicate():
		if p["from"] != "player":
			_projectiles.erase(p)
			(p["node"] as Node).queue_free()


# ================================================================ pickups
func _add_loot_mat(loot: Dictionary, mat: String, n: int) -> void:
	var m: Dictionary = loot["mats"]
	m[mat] = int(m.get(mat, 0)) + n


## A pile of loot on the ground (gold, materials, a sigil or potion). Click it to pick it up.
func drop_loot(pos: Vector3, loot: Dictionary) -> void:
	var p := Vector3(pos.x, world.height_at(pos.x, pos.z), pos.z)
	var s: Rig
	var sigil := int(loot.get("sigil", 0)) > 0
	if sigil:
		var col := Color(Data.BOSSES[int(main.state["bi"])]["color"])
		s = Models.gem(col)
		s.scale = Vector3.ONE * 1.6
		var l := OmniLight3D.new()
		l.light_color = col
		l.omni_range = 3.0
		l.light_energy = 1.2
		s.add_child(l)
	elif int(loot.get("potion", 0)) > 0 and int(loot.get("gold", 0)) == 0:
		s = Models.potion()
		s.scale = Vector3.ONE * 1.4
	else:
		s = Models.loot_bag(Color("ffd27a"))
		s.scale = Vector3.ONE * 1.1
	add_child(s)
	s.global_position = p
	_pickups.append({"node": s, "sprite": s, "pos": p, "kind": "loot", "loot": loot, "t": 0.0, "name": loot_name(loot)})


static func loot_name(loot: Dictionary) -> String:
	var parts: Array[String] = []
	if int(loot.get("sigil", 0)) > 0:
		parts.append("Sigil")
	if int(loot.get("potion", 0)) > 0:
		parts.append("Potion")
	if int(loot.get("gold", 0)) > 0:
		parts.append("%dg" % int(loot["gold"]))
	for m: String in (loot.get("mats", {}) as Dictionary):
		parts.append("%d %s" % [int(loot["mats"][m]), Data.MATERIALS[m]["name"]])
	return ", ".join(parts)


func _drop_item(pos: Vector3, item: Dictionary) -> void:
	var root := Node3D.new()
	add_child(root)
	var p := Vector3(pos.x, world.height_at(pos.x, pos.z), pos.z)
	root.global_position = p
	var col := Items.color(item)
	var s := Models.loot_bag(col)
	s.scale = Vector3.ONE * 1.5
	root.add_child(s)
	var r: int = item["rarity"]
	if r >= 1:
		# light beam so good drops are easy to spot
		var beam := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.06
		cm.bottom_radius = 0.18
		cm.height = 2.0 + r * 1.5
		cm.radial_segments = 6
		beam.mesh = cm
		beam.material_override = _fade_mat(Color(col, 0.35))
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		beam.position.y = cm.height * 0.5
		root.add_child(beam)
		var l := OmniLight3D.new()
		l.light_color = col
		l.omni_range = 2.5 + r
		l.light_energy = 1.0
		l.position.y = 0.8
		root.add_child(l)
	if r >= 2:
		Sfx.play("loot_rare", p, -2.0)
	_pickups.append({"node": root, "pos": p, "kind": "item", "item": item, "t": 0.0, "sprite": s, "name": item["name"], "color": col})


func _update_pickups(delta: float) -> void:
	for k: Dictionary in _pickups.duplicate():
		k["t"] = float(k["t"]) + delta
		(k["node"] as Node3D).global_position = k["pos"]
		var rig: Rig = k["sprite"]
		rig.tick(delta, 0.0)
		rig.rotation.y = float(k["t"]) * 1.2
		var keep := 300.0 if (k["kind"] == "item" or int((k.get("loot", {}) as Dictionary).get("sigil", 0)) > 0) else 120.0
		if float(k["t"]) > keep:
			_pickups.erase(k)
			(k["node"] as Node).queue_free()


## Loot within reach of the player (for the G key).
func nearest_pickup(max_d := PICKUP_RANGE) -> Dictionary:
	var best := {}
	var bd := max_d
	for k: Dictionary in _pickups:
		var d := _flat(k["pos"], player.global_position)
		if d < bd:
			bd = d
			best = k
	return best


## Pick up a pile or an item. Returns false if it couldn't be taken (bag full).
func take(k: Dictionary) -> bool:
	if not _pickups.has(k):
		return false
	if k["kind"] == "item":
		if not main.can_take_item():
			main.ui.toast("Your bag is full")
			return false
		_pickups.erase(k)
		(k["node"] as Node).queue_free()
		main.collect_item(k["item"])
		return true
	var loot: Dictionary = k["loot"]
	var at := player.global_position
	if int(loot.get("gold", 0)) > 0:
		main.add_gold(int(loot["gold"]), at)
		loot["gold"] = 0
	var pn := int(loot.get("potion", 0))
	var took := 0
	for i in pn:
		if main.mat_room("hpot") < 1:
			main.ui.toast("Your bag is full", Color("e0a080"))
			break
		Sfx.play("pickup_potion")
		main.collect("potion")
		took += 1
	loot["potion"] = pn - took
	for i in int(loot.get("sigil", 0)):
		Sfx.play("pickup_sigil")
		main.collect("sigil")
	loot["sigil"] = 0
	var mats: Dictionary = loot.get("mats", {})
	var off := 0.4
	for m: String in mats.keys():
		var n := int(mats[m])
		var got: int = main.crafting.add_mat(m, n, at + Vector3(0, off, 0))
		off += 0.4
		if got >= n:
			mats.erase(m)
		else:
			mats[m] = n - got
	if not mats.is_empty() or int(loot["potion"]) > 0:
		# bag full: whatever didn't fit stays on the ground
		k["name"] = loot_name(loot)
		return false
	_pickups.erase(k)
	(k["node"] as Node).queue_free()
	Sfx.play("loot", Vector3.INF, -6.0)
	return true


func summon_boss(i: int) -> void:
	if boss:
		return
	var a := world.altar_pos[i]
	boss = Enemy.new()
	boss.setup_boss(self, i)
	add_child(boss)
	var p := a + Vector3(0, 0, -3.2)
	boss.global_position = Vector3(p.x, world.height_at(p.x, p.z) + 0.2, p.z)
	enemies.append(boss)
	var col := Color(Data.BOSSES[i]["color"])
	ring(a, 7.0, col, 0.8)
	burst(a + Vector3(0, 1.0, 0), col, 50, 10.0, 1.0, 0.25)
	main.rig.shake += 0.8
	Sfx.play("boss_summon")
	var roar := func() -> void: Sfx.play("boss_roar")
	_timers.append({"t": 1.2, "fn": roar})
	Sfx.music("boss")
	main.ui.toast("%s awakens!" % Data.BOSSES[i]["name"])


func despawn_boss(msg: String) -> void:
	if boss == null:
		return
	enemies.erase(boss)
	boss.queue_free()
	boss = null
	main.boss_reset()
	if msg != "":
		main.ui.toast(msg)


func _boss_defeated(e: Enemy) -> void:
	var col := Color(Data.BOSSES[e.boss_index]["color"])
	Sfx.play("boss_die")
	# Warden loot: three pieces, rare or better
	var lvl: int = int(Data.BOSSES[e.boss_index]["rec"]) + 2
	for k in 3:
		var rr := Items.roll_rarity([0.0, 0.0, 60.0, 32.0, 8.0 + e.boss_index * 4.0])
		var a := k * TAU / 3.0
		_drop_item(e.global_position + Vector3(cos(a), 0, sin(a)) * 1.6, Items.generate(lvl, player.class_id, rr))
	burst(e.center(), col, 60, 12.0, 1.2, 0.3)
	burst(e.center(), Color.WHITE, 30, 8.0, 0.8, 0.2)
	ring(e.global_position, 8.0, col, 0.9)
	main.rig.shake += 1.0
	boss = null
	clear_enemy_shots()
	var i := e.boss_index
	var bt: Dictionary = Data.CRAFT_TIERS[clampi(i, 0, 3)]
	var bl := {"gold": roundi(60.0 * pow(i + 1, 1.5)), "mats": {}}
	_add_loot_mat(bl, "ember", 2)
	_add_loot_mat(bl, bt["primary"], 5)
	_add_loot_mat(bl, bt["secondary"], 5)
	drop_loot(e.global_position, bl)
	e.queue_free()
	main.on_boss_defeated(i)


# ================================================================ effects
func _mat(col: Color, glow := false) -> StandardMaterial3D:
	var key := col.to_html() + ("g" if glow else "")
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	if col.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_cache[key] = m
	return m


func _fade_mat(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = col
	return m


func _cyl(r: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 16
	c.rings = 1
	return c


func burst(pos: Vector3, col: Color, n: int, speed: float, life: float, size := 0.16) -> void:
	var cp := CPUParticles3D.new()
	cp.one_shot = true
	cp.emitting = false
	cp.amount = maxi(n, 1)
	cp.lifetime = life
	cp.explosiveness = 1.0
	cp.mesh = _particle_mesh
	cp.direction = Vector3(0, 1, 0)
	cp.spread = 180.0
	cp.initial_velocity_min = speed * 0.3
	cp.initial_velocity_max = speed
	cp.gravity = Vector3(0, -9.0, 0)
	cp.scale_amount_min = size / 0.16 * 0.7
	cp.scale_amount_max = size / 0.16
	cp.color = col
	cp.local_coords = false
	add_child(cp)
	cp.global_position = pos
	cp.emitting = true
	cp.finished.connect(cp.queue_free)


func trail(pos: Vector3, col: Color) -> void:
	if randf() < 0.5:
		burst(pos, col, 1, 0.5, 0.35, 0.3)


## red warning shapes on the ground before an enemy's special move lands
func telegraph_circle(pos: Vector3, r: float, life: float, col := Color(1.0, 0.25, 0.25)) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _cyl(r, 0.04)
	var m := _fade_mat(Color(col, 0.18))
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = Vector3(pos.x, world.height_at(pos.x, pos.z) + 0.1, pos.z)
	var tw := create_tween()
	tw.tween_property(m, "albedo_color:a", 0.5, life)
	tw.tween_callback(mi.queue_free)


func telegraph_line(from: Vector3, dir: Vector3, length: float, width: float, life: float, col := Color(1.0, 0.25, 0.25)) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(width, 0.04, length)
	mi.mesh = bm
	var m := _fade_mat(Color(col, 0.18))
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var mid := from + dir * length * 0.5
	mi.global_position = Vector3(mid.x, world.height_at(mid.x, mid.z) + 0.12, mid.z)
	mi.rotation.y = atan2(dir.x, dir.z)
	var tw := create_tween()
	tw.tween_property(m, "albedo_color:a", 0.5, life)
	tw.tween_callback(mi.queue_free)


func heal_beam(a: Vector3, b: Vector3, text: String) -> void:
	_lightning_col([a, b], Color(0.45, 1.0, 0.55, 1.0))
	float_text(b + Vector3(0, 0.8, 0), text, Color("7be08a"))
	burst(b, Color("7be08a"), 10, 3.0, 0.5)
	Sfx.play("heal", b, -8.0)


func ring(pos: Vector3, radius: float, col: Color, life: float) -> void:
	var tm := TorusMesh.new()
	tm.inner_radius = 0.86
	tm.outer_radius = 1.0
	tm.rings = 24
	tm.ring_segments = 4
	var mi := MeshInstance3D.new()
	mi.mesh = tm
	var m := _fade_mat(Color(col, 0.85))
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = Vector3(pos.x, world.height_at(pos.x, pos.z) + 0.15, pos.z)
	mi.scale = Vector3(radius * 0.2, 0.05, radius * 0.2)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(radius, 0.05, radius), life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, life)
	tw.chain().tween_callback(mi.queue_free)


func slash(origin: Vector3, dir: Vector3, rng: float, arc: float, col: Color) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var base := atan2(dir.x, dir.z)
	var segs := 10
	var inner := rng * 0.45
	for s in segs:
		var a0 := base - arc * 0.5 + arc * s / segs
		var a1 := base - arc * 0.5 + arc * (s + 1) / segs
		var o0 := Vector3(sin(a0), 0, cos(a0))
		var o1 := Vector3(sin(a1), 0, cos(a1))
		st.add_vertex(o0 * inner)
		st.add_vertex(o0 * rng)
		st.add_vertex(o1 * rng)
		st.add_vertex(o0 * inner)
		st.add_vertex(o1 * rng)
		st.add_vertex(o1 * inner)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := _fade_mat(Color(col, 0.6))
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = origin + Vector3(0, 0.9, 0)
	var tw := create_tween()
	tw.tween_property(m, "albedo_color:a", 0.0, 0.16)
	tw.tween_callback(mi.queue_free)


func _mark(pos: Vector3, r: float, col: Color, life: float) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _cyl(r, 0.04)
	var m := _fade_mat(Color(col, 0.28))
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = pos + Vector3(0, 0.12, 0)
	var tw := create_tween()
	tw.tween_property(m, "albedo_color:a", 0.45, life)
	tw.tween_callback(mi.queue_free)


func _meteor_fall(t: Vector3) -> void:
	var node := _projectile_node("fire", Color("ff7a3a"), 0.7, false)
	add_child(node)
	node.global_position = t + Vector3(4.0, 16.0, -2.0)
	var tw := create_tween()
	tw.tween_property(node, "global_position", t + Vector3(0, 0.5, 0), 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(node.queue_free)


func _lightning(pts: Array[Vector3]) -> void:
	_lightning_col(pts, Color(1.0, 0.97, 0.6, 1.0))


func _lightning_col(pts: Array[Vector3], col: Color) -> void:
	var root := Node3D.new()
	add_child(root)
	var m := _fade_mat(col)
	for i in range(1, pts.size()):
		var a: Vector3 = pts[i - 1]
		var b: Vector3 = pts[i]
		var prev := a
		for s in range(1, 5):
			var t := s / 4.0
			var nxt := a.lerp(b, t)
			if s < 4:
				nxt += Vector3(randf_range(-0.4, 0.4), randf_range(-0.3, 0.3), randf_range(-0.4, 0.4))
			var seg := MeshInstance3D.new()
			var bm := BoxMesh.new()
			var len := prev.distance_to(nxt)
			bm.size = Vector3(0.08, 0.08, len)
			seg.mesh = bm
			seg.material_override = m
			seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(seg)
			seg.global_position = (prev + nxt) * 0.5
			if len > 0.01:
				seg.look_at(nxt, Vector3.UP if absf((nxt - prev).normalized().y) < 0.99 else Vector3.RIGHT)
			prev = nxt
		burst(b, Color("fff6a0"), 6, 4.0, 0.3)
	var tw := create_tween()
	tw.tween_property(m, "albedo_color:a", 0.0, 0.3)
	tw.tween_callback(root.queue_free)
