class_name Enemy
extends CharacterBody3D
## A creature or Warden. Regular enemies wander, chase and (for ranged types) keep their distance
## and shoot. Bosses cycle through attack patterns: charge, ring, spray, summon and spiral.

const GRAVITY := 24.0
const AGGRO_RANGE := 6.5     # notices you this close
const DEAGGRO_RANGE := 14.0  # loses interest this far away
const LEASH := 20.0          # gives up and walks home this far from where it spawned
const HP_MULT := 6.4         # difficulty: all regular enemies and elites
const DMG_MULT := 4.4
const BOSS_HP_MULT := 3.0
const BOSS_DMG_MULT := 2.4

var combat: Combat
var type_id := ""
var is_boss := false
var is_elite := false
var elite_id := ""
var display_name := ""
var boss_index := -1
var max_hp := 10.0
var hp := 10.0
var dmg := 5.0
var speed := 2.0
var radius := 0.5
var height := 1.0
var biome := 0
var xp := 0
var ranged := {}
var dead := false
var level := 1

var aggro := false
var flash := 0.0
var slow := 0.0
var stun := 0.0
var root := 0.0
var poison_t := 0.0
var poison_dps := 0.0
var poison_acc := 0.0
var poison_tick := 0.0
var knock := Vector3.ZERO
var hit_cd := 0.0
var shoot_cd := 0.0

# boss state
var mode := "chase"
var mode_t := 0.0
var pattern_t := 1.5
var pattern_i := 0
var spiral_t := 0.0
var spiral_ang := 0.0
var charge_dir := Vector3.ZERO

# special moves (newer creatures): charger, bomber, slammer, pouncer, burrower, healer, blinker
var ai := ""
var act := ""            # "", "wind", "dash", "air"
var act_kind := ""
var act_t := 0.0
var act_dir := Vector3.ZERO
var act_from := Vector3.ZERO
var act_target := Vector3.ZERO
var act_hit := false
var special_cd := 0.0
var burrowed := false
var _override := false
var _hop := 0.0
var _trail_t := 0.0

var home := Vector3.INF     # where it spawned; it won't chase you far from here
var _leash_t := 0.0
var _wander := Vector3.ZERO
var _wander_t := 0.0
var model: Rig
var _telegraph: MeshInstance3D
var _glow: MeshInstance3D


func setup_enemy(c: Combat, id: String, b: int) -> void:
	combat = c
	type_id = id
	biome = b
	var d: Dictionary = Data.ENEMIES[id]
	max_hp = float(d["hp"]) * HP_MULT
	hp = max_hp
	dmg = float(d["dmg"]) * DMG_MULT
	speed = d["speed"]
	radius = d["radius"]
	xp = d["xp"]
	level = int(Data.BIOME_REC_LEVEL[b]) + randi() % 3
	ranged = d.get("ranged", {})
	ai = d.get("ai", "")
	special_cd = randf_range(0.3, 1.2)
	shoot_cd = randf() * 1.5
	_build(_creature(d, d["pal"]), 1.0)


func setup_elite(c: Combat, id: String, b: int) -> void:
	## a named, oversized version of a normal enemy (side quest target)
	combat = c
	is_elite = true
	elite_id = id
	var el: Dictionary = Data.ELITES[id]
	type_id = el["base"]
	biome = b
	display_name = el["name"]
	var d: Dictionary = Data.ENEMIES[type_id]
	max_hp = float(d["hp"]) * float(el["hp"]) * HP_MULT
	hp = max_hp
	dmg = float(d["dmg"]) * float(el["dmg"]) * DMG_MULT
	level = int(Data.BIOME_REC_LEVEL[b]) + 3
	speed = float(d["speed"]) * 1.1
	radius = float(d["radius"]) * float(el["scale"])
	xp = int(d["xp"]) * int(el["xp"])
	ranged = d.get("ranged", {})
	var pal: Dictionary = (d["pal"] as Dictionary).duplicate()
	pal.merge(el["pal"], true)
	_build(_creature(d, pal), el["scale"])


func setup_boss(c: Combat, i: int) -> void:
	combat = c
	is_boss = true
	boss_index = i
	var d: Dictionary = Data.BOSS_COMBAT[i]
	max_hp = float(d["hp"]) * BOSS_HP_MULT
	hp = max_hp
	dmg = float(d["dmg"]) * BOSS_DMG_MULT
	speed = d["speed"]
	radius = d["radius"]
	xp = d["xp"]
	biome = Data.BOSSES[i]["biome"]
	level = int(Data.BOSSES[i]["rec"]) + 2
	display_name = Data.BOSSES[i]["name"]
	mode = "rise"
	mode_t = 1.4
	_build(Models.boss(i), 1.0)
	# telegraph strip for charges
	var bm := BoxMesh.new()
	bm.size = Vector3(radius * 1.6, 0.05, 13.0)
	var tm := StandardMaterial3D.new()
	tm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tm.albedo_color = Color(1.0, 0.2, 0.25, 0.4)
	_telegraph = MeshInstance3D.new()
	_telegraph.mesh = bm
	_telegraph.material_override = tm
	_telegraph.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_telegraph.top_level = true
	_telegraph.visible = false
	add_child(_telegraph)
	# coloured glow disc underfoot
	var cm := CylinderMesh.new()
	cm.top_radius = radius + 0.8
	cm.bottom_radius = radius + 0.8
	cm.height = 0.04
	cm.radial_segments = 20
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.albedo_color = Color(Data.BOSSES[i]["color"], 0.3)
	_glow = MeshInstance3D.new()
	_glow.mesh = cm
	_glow.material_override = gm
	_glow.position.y = 0.06
	_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_glow)


func _creature(d: Dictionary, pal: Dictionary) -> Rig:
	var full := pal.duplicate()
	var r: Dictionary = d.get("ranged", {})
	if r.get("kind", "") == "arrow":
		full["kind"] = "archer"
	elif r.has("color"):
		full["orb"] = r["color"]
	return Models.creature(d["sprite"], full)


func _build(rig: Rig, scale_mult: float) -> void:
	collision_layer = 8
	collision_mask = 1 if is_boss else (1 | 2)
	var shape := CapsuleShape3D.new()
	shape.radius = minf(radius * 0.7, 0.9)
	shape.height = maxf(shape.radius * 2.0, 1.0)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position.y = shape.height * 0.5
	add_child(cs)
	model = rig
	model.scale *= scale_mult
	model.walk_speed = 7.0 + speed * 1.2
	add_child(model)
	height = model.height * scale_mult
	model.set_facing(Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)), true)
	floor_snap_length = 0.6
	floor_max_angle = deg_to_rad(55)


func title() -> String:
	if display_name != "":
		return display_name
	return Data.ENEMIES[type_id]["name"]


func center() -> Vector3:
	return global_position + Vector3(0, height * 0.45, 0)


func apply_poison(dps: float, dur := 4.0) -> void:
	var was := poison_t > 0.0
	poison_t = maxf(poison_t, dur)
	poison_dps = maxf(poison_dps, dps) if was else dps


func _physics_process(delta: float) -> void:
	if dead or combat == null:
		return
	flash -= delta
	hit_cd -= delta
	slow -= delta
	if poison_t > 0.0:
		poison_t -= delta
		var dd := poison_dps * delta
		poison_acc += dd
		poison_tick -= delta
		if poison_tick <= 0.0:
			poison_tick = 0.5
			if poison_acc >= 1.0:
				combat.damage_enemy(self, poison_acc, Vector3.ZERO, 0.0, {"dot": true})
				poison_acc = 0.0
				if dead:
					return
	var hv: Vector3
	if is_boss:
		hv = _boss_tick(delta)
	else:
		hv = _tick(delta)
	hv += knock
	knock = knock * exp(-delta * 8.0)
	hv = _avoid_water(hv)
	velocity.x = hv.x
	velocity.z = hv.z
	if is_on_floor():
		velocity.y = -1.0
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	_contact_damage()
	_visuals(delta, hv)


func _avoid_water(hv: Vector3) -> Vector3:
	var p := global_position
	var w := combat.world
	if hv.x != 0.0 and w.is_water(p.x + signf(hv.x) * 0.6, p.z):
		hv.x = 0.0
	if hv.z != 0.0 and w.is_water(p.x, p.z + signf(hv.z) * 0.6):
		hv.z = 0.0
	return hv


func _flat_to_player() -> Vector3:
	var to := combat.player.global_position - global_position
	to.y = 0.0
	return to


func _tick(delta: float) -> Vector3:
	if stun > 0.0:
		stun -= delta
		return Vector3.ZERO
	var to := _flat_to_player()
	var d := to.length()
	var dir := to / maxf(d, 0.001)
	if home == Vector3.INF:
		home = global_position
	var from_home := Vector2(global_position.x - home.x, global_position.z - home.z)
	if _leash_t > 0.0:
		# gave up the chase: walk home, healing on the way
		_leash_t -= delta
		aggro = false
		hp = minf(max_hp, hp + max_hp * 0.25 * delta)
		if from_home.length() < 1.5 or burrowed:
			_leash_t = 0.0
			return Vector3.ZERO
		var back := Vector3(-from_home.x, 0, -from_home.y).normalized()
		return back * speed * 1.2
	if combat.player_hidden() or combat.player.dead:
		aggro = false
	elif d < AGGRO_RANGE:
		aggro = true
	elif d > DEAGGRO_RANGE:
		aggro = false
	if aggro and not is_elite and from_home.length() > LEASH and act == "":
		aggro = false
		_leash_t = 5.0
	if ai != "":
		var sv := _special(delta, d, dir)
		if _override:
			return sv
	var mv := Vector3.ZERO
	if burrowed:
		mv = dir * 1.5 if aggro else Vector3.ZERO
	elif aggro:
		if not ranged.is_empty():
			if d > 7.0:
				mv = dir
			elif d < 4.5:
				mv = -dir
			shoot_cd -= delta
			if shoot_cd <= 0.0 and d < 12.75:
				shoot_cd = ranged["cd"]
				if ranged["kind"] == "arrow":
					model.attack(0.35)
				else:
					model.cast(0.45)
				var n := int(ranged.get("burst", 1))
				for k in n:
					var aim := dir.rotated(Vector3.UP, (k - (n - 1) * 0.5) * 0.22)
					combat.shoot(center(), aim, ranged["speed"], dmg, "enemy", ranged["kind"], Color(ranged["color"]), 2.6)
		else:
			mv = dir
	else:
		_wander_t -= delta
		if _wander_t <= 0.0:
			_wander_t = randf_range(1.0, 3.0)
			_wander = Vector3.ZERO if randf() < 0.4 else Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU) * 0.4
			if from_home.length() > 6.0:
				_wander = Vector3(-from_home.x, 0, -from_home.y).normalized() * 0.4
		mv = _wander
	# keep a little space between enemies
	for o: Enemy in combat.enemies:
		if o == self or o.is_boss:
			continue
		var off := global_position - o.global_position
		off.y = 0.0
		var dl := off.length()
		if dl < 0.9 and dl > 0.01:
			mv += off / dl * (0.9 - dl) / 0.9
	if root > 0.0:
		root -= delta
		mv = Vector3.ZERO
	var bog := 0.6 if (combat.world.ground_at(global_position) == World.G.BOG and biome != 2) else 1.0
	return mv * speed * (0.45 if slow > 0.0 else 1.0) * bog


func _special(delta: float, d: float, dir: Vector3) -> Vector3:
	_override = false
	special_cd -= delta
	match act:
		"wind":
			_override = true
			act_t -= delta
			if act_t <= 0.0:
				_release()
			return Vector3.ZERO
		"dash":
			_override = true
			act_t -= delta
			if not act_hit and _flat_to_player().length() < radius + 0.7:
				act_hit = true
				combat.hurt_player(dmg * 1.3, self)
			if act_t <= 0.0:
				act = ""
				special_cd = 3.5
			combat.trail(global_position + Vector3(0, 0.3, 0), Color("c8c0a0"))
			return act_dir * 14.0
		"air":
			_override = true
			act_t -= delta
			var k := clampf(1.0 - act_t / 0.5, 0.0, 1.0)
			var pos := act_from.lerp(act_target, k)
			global_position.x = pos.x
			global_position.z = pos.z
			_hop = sin(k * PI) * 2.2
			if act_t <= 0.0:
				_hop = 0.0
				act = ""
				special_cd = 4.0
				_area_hit(act_target, 1.5, 1.0)
				combat.burst(act_target + Vector3(0, 0.2, 0), Color("6a5a48"), 10, 3.0, 0.4)
			return Vector3.ZERO
	if not aggro:
		if burrowed and special_cd <= -6.0:
			_set_burrowed(false)
		return Vector3.ZERO
	var p := combat.player.global_position
	match ai:
		"charger":
			if d > 2.2 and d < 9.0 and special_cd <= 0.0:
				_wind("charge", 0.55)
				act_dir = dir
				combat.telegraph_line(global_position, dir, 9.0, radius * 1.8, 0.55)
		"bomber":
			if d < 2.0:
				_wind("explode", 0.7)
				combat.telegraph_circle(global_position, 2.6, 0.7)
				Sfx.play("fire_cast", global_position, -6.0)
		"slammer":
			var r := 3.4 if type_id == "golem" else 2.6
			if d < r - 0.6 and special_cd <= 0.0:
				_wind("slam", 1.0 if type_id == "golem" else 0.8)
				combat.telegraph_circle(global_position, r, act_t)
		"pouncer":
			if d > 1.5 and d < 9.0 and special_cd <= 0.0:
				_wind("pounce", 0.35)
				act_target = Vector3(p.x, combat.world.height_at(p.x, p.z), p.z)
				combat.telegraph_circle(act_target, 1.5, 0.85)
		"burrower":
			if not burrowed and d > 2.0 and special_cd <= 0.0:
				_set_burrowed(true)
			elif burrowed and d < 1.6:
				_wind("pop", 0.35)
				combat.telegraph_circle(global_position, 1.8, 0.35)
		"healer":
			if special_cd <= 0.0:
				special_cd = 3.0
				var best: Enemy = null
				for o: Enemy in combat.enemies:
					if o == self or o.dead or o.hp >= o.max_hp:
						continue
					if o.global_position.distance_to(global_position) < 9.0 and (best == null or o.hp / o.max_hp < best.hp / best.max_hp):
						best = o
				if best:
					var amt := best.max_hp * 0.25
					best.hp = minf(best.max_hp, best.hp + amt)
					combat.heal_beam(center(), best.center(), "+%d" % int(amt))
		"blinker":
			if d < 4.0 and special_cd <= 0.0:
				special_cd = 3.5
				for t in 8:
					var a := randf() * TAU
					var np := global_position + Vector3(cos(a), 0, sin(a)) * 6.5
					if not combat.world.is_water(np.x, np.z):
						combat.burst(center(), Color("c8f0ff"), 12, 4.0, 0.4)
						global_position = Vector3(np.x, combat.world.height_at(np.x, np.z) + 0.2, np.z)
						combat.burst(center(), Color("c8f0ff"), 12, 4.0, 0.4)
						Sfx.play("blink", global_position, -6.0)
						break
	return Vector3.ZERO


func _wind(kind: String, t: float) -> void:
	act = "wind"
	act_kind = kind
	act_t = t
	_override = true


func _release() -> void:
	act = ""
	model.attack(0.35)
	match act_kind:
		"charge":
			act = "dash"
			act_t = 0.45
			act_hit = false
			Sfx.play("dash", global_position, -4.0)
		"explode":
			_area_hit(global_position, 2.6, 1.0)
			combat.ring(global_position, 2.6, Color("e070a0"), 0.35)
			combat.burst(center(), Color("e070a0"), 30, 7.0, 0.6, 0.22)
			Sfx.play("explosion", global_position, -4.0)
			combat.kill(self)
		"slam":
			var r := 3.4 if type_id == "golem" else 2.6
			_area_hit(global_position, r, 1.2)
			combat.ring(global_position, r, Color("c8e0f0") if type_id == "golem" else Color("8a6a40"), 0.4)
			combat.burst(global_position + Vector3(0, 0.2, 0), Color("8a7a68"), 20, 5.0, 0.5, 0.2)
			Sfx.play("slam", global_position, -3.0)
			combat.main.rig.shake += 0.3
			special_cd = 3.0
		"pounce":
			act = "air"
			act_t = 0.5
			act_from = global_position
			Sfx.play("dodge", global_position, -4.0)
		"pop":
			_set_burrowed(false)
			_area_hit(global_position, 1.8, 1.0)
			combat.burst(global_position + Vector3(0, 0.3, 0), Color("5a4a30"), 20, 5.0, 0.5, 0.22)
			Sfx.play("slam", global_position, -6.0)
			special_cd = 4.0


func _area_hit(at: Vector3, r: float, mult: float) -> void:
	var pp := combat.player.global_position
	if Vector2(pp.x - at.x, pp.z - at.z).length() < r + 0.3:
		combat.hurt_player(dmg * mult, self)


func _set_burrowed(on: bool) -> void:
	burrowed = on
	model.visible = not on
	if on:
		combat.burst(global_position + Vector3(0, 0.2, 0), Color("5a4a30"), 12, 3.0, 0.4)
		special_cd = 0.0


func _contact_damage() -> void:
	if hit_cd > 0.0 or combat.player.dead or burrowed or act == "wind" or act == "air":
		return
	if not is_boss and combat.player_hidden():
		return
	if is_boss and (mode == "rise" or mode == "wind"):
		return
	var d := _flat_to_player().length()
	if d < radius + 0.55:
		hit_cd = 0.9
		model.attack(0.3)
		combat.hurt_player(dmg * (1.5 if (is_boss and mode == "charge") else 1.0), self)


# ---------------------------------------------------------------- boss
func _boss_tick(delta: float) -> Vector3:
	var to := _flat_to_player()
	var d := to.length()
	var dir := to / maxf(d, 0.001)
	var enrage := 0.7 if hp < max_hp * 0.5 else 1.0
	var col := Color(Data.BOSSES[boss_index]["color"])
	var bd: Dictionary = Data.BOSS_COMBAT[boss_index]
	_telegraph.visible = mode == "wind"
	match mode:
		"rise":
			mode_t -= delta
			if mode_t <= 0.0:
				mode = "chase"
			return Vector3.ZERO
		"wind":
			mode_t -= delta
			var mid := global_position + charge_dir * 6.5
			_telegraph.global_position = Vector3(mid.x, combat.world.height_at(mid.x, mid.z) + 0.12, mid.z)
			_telegraph.rotation = Vector3(0, atan2(charge_dir.x, charge_dir.z), 0)
			if mode_t <= 0.0:
				mode = "charge"
				mode_t = 0.6
			return Vector3.ZERO
		"charge":
			mode_t -= delta
			if mode_t <= 0.0:
				mode = "chase"
				pattern_t = 1.4 * enrage
			combat.trail(global_position + Vector3(0, 0.3, 0), col)
			return charge_dir * 21.0
		"spiral":
			mode_t -= delta
			spiral_t -= delta
			if spiral_t <= 0.0:
				spiral_t = 0.08 * enrage
				for k in 3:
					var a := spiral_ang + k * TAU / 3.0
					combat.shoot(center(), Vector3(cos(a), 0, sin(a)), 7.1, dmg * 0.7, "enemy", "orb", col, 3.5)
				spiral_ang += 0.3
			if mode_t <= 0.0:
				mode = "chase"
				pattern_t = 1.4 * enrage
			return Vector3.ZERO
	# chase
	pattern_t -= delta
	if pattern_t <= 0.0:
		_pattern(bd, dir, enrage, col)
	if d > radius + 0.6:
		return dir * speed * (0.6 if slow > 0.0 else 1.0)
	return Vector3.ZERO


func _pattern(bd: Dictionary, dir: Vector3, enrage: float, col: Color) -> void:
	var pats: Array = bd["patterns"]
	var pat: String = pats[pattern_i % pats.size()]
	pattern_i += 1
	model.attack(0.4)
	model.cast(0.5)
	var bi := boss_index
	match pat:
		"charge":
			Sfx.play("boss_roar", global_position, -8.0, 0.1)
			mode = "wind"
			mode_t = 0.7 * enrage + 0.15
			charge_dir = dir
		"ring":
			var n := 10 + bi * 3
			var off := randf() * TAU
			for i in n:
				var a := off + i * TAU / n
				combat.shoot(center(), Vector3(cos(a), 0, sin(a)), 6.0 + bi * 0.75, dmg * 0.8, "enemy", "orb", col, 4.0)
			pattern_t = 1.9 * enrage
		"spray":
			var n2 := 5 + bi
			var base := atan2(dir.z, dir.x)
			for i in n2:
				var a2 := base + (i - (n2 - 1) * 0.5) * 0.16
				combat.shoot(center(), Vector3(cos(a2), 0, sin(a2)), 9.4 + bi * 0.6, dmg * 0.8, "enemy", "orb", col, 3.0)
			pattern_t = 1.5 * enrage
		"summon":
			for i in 2 + bi:
				var a3 := randf() * TAU
				combat.spawn_enemy(bd["minion"], global_position + Vector3(cos(a3), 0, sin(a3)) * 3.0, biome)
			combat.burst(center(), col, 20, 6.0, 0.6)
			pattern_t = 2.2 * enrage
		"spiral":
			mode = "spiral"
			mode_t = 1.8
			spiral_t = 0.0
			spiral_ang = randf() * TAU


# ---------------------------------------------------------------- visuals
func _visuals(delta: float, hv: Vector3) -> void:
	var flat := Vector3(hv.x, 0, hv.z)
	var to_player := _flat_to_player()
	if (aggro or is_boss) and act != "dash" and act != "air" and mode != "charge":
		model.set_facing(to_player)
	elif flat.length() > 0.3:
		model.set_facing(flat)
	model.tick(delta, flat.length() / maxf(speed, 0.5) if stun <= 0.0 else 0.0)
	var wind := (is_boss and mode == "wind") or act == "wind"
	model.flash_pulse(wind)
	if flash > 0.0:
		model.hit_flash()
		flash = 0.0
	if slow > 0.0:
		model.set_tint(Color(0.7, 0.9, 1.4))
	elif poison_t > 0.0:
		model.set_tint(Color(0.75, 1.25, 0.7))
	elif stun > 0.0:
		model.set_tint(Color(1.3, 1.25, 0.7))
	else:
		model.set_tint(Color.WHITE)
	if is_boss and mode == "rise":
		var k := clampf(1.0 - mode_t / 1.4, 0.0, 1.0)
		model.position.y = (k - 1.0) * height
	else:
		model.position.y = _hop
	if burrowed:
		_trail_t -= delta
		if _trail_t <= 0.0 and Vector3(hv.x, 0, hv.z).length() > 0.3:
			_trail_t = 0.12
			combat.burst(global_position + Vector3(0, 0.1, 0), Color("5a4a30"), 3, 1.5, 0.35, 0.18)
