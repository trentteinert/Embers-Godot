class_name Player
extends CharacterBody3D
## The keeper: a low-poly 3D model (see models.gd / rig.gd) driven by this controller.
## Handles movement, sprint, jumping, dashes, aiming, stamina, the class resource and buffs.
## Combat (damage dealt and taken) is resolved in combat.gd.

signal notify(text: String)

const GRAVITY := 24.0
const JUMP_SPEED := 8.5       # about a 1.5m hop
const JUMP_COST := 8.0        # stamina
const COYOTE := 0.12          # you can still jump this long after walking off a ledge
const SPRINT_MULT := 1.55
const SPRINT_DRAIN := 20.0
const STA_REGEN := 30.0
const TURN_SPEED := 3.4        # radians per second with A / D

var class_id := "warrior"
var level := 1
var max_hp := 100.0
var hp := 100.0
var dmg := 10.0
var res := 0.0
var res_max := 100.0
var sta := 100.0
var sta_max := 100.0
var combat_t := 99.0         # seconds since last fight; drives rage decay and mana regen
var aim_dir := Vector3(1, 0, 0)
var aim_point := Vector3.ZERO
var can_act := true          # Main turns this off during dialog and menus
var cam_yaw := 0.0
var face_yaw := 0.0          # which way the keeper faces (0 = -Z); A/D turn it, right-drag steers it
var steer := false           # right mouse held: face the camera and strafe with A/D
var run_both := false        # both mouse buttons held: run forward
var hide_model := false      # camera is in first person
var autorun := false
var back_input := false      # holding S (backpedal keeps facing forward)
var strafing := false
var turning := false         # turning with A / D this frame
var moving_forward := false  # walking or running forward (the camera may drift behind)
var _input_active := false   # moving or turning this frame (the camera follows)
var dead := false
var inv_t := 0.0             # brief invulnerability after a hit
var attack_t := 0.0          # basic attack cooldown
var swing_t := 0.0
var armed_t := 0.0           # weapons stay drawn while this is above zero (fighting)
var _threat_t := 0.0
var combat_ref: Node
var buffs := {}              # name -> seconds left (shout, stand, poison, stealth, flurry, barrier)
var shield := 0.0            # Arcane Barrier absorb
var dash := {}               # active dash: vel, t, mult, opts, hit (Dictionary of enemies)
var gear := {}               # summed stats of equipped items (see items.gd)
var attrs := {}              # Strength / Agility / Intellect / Stamina totals
var crit := 0.0
var armor := 0.0
var armor_red := 0.0         # fraction of damage armor blocks
var tier := 0                # Warden lights rekindled
var _step_t := 0.0

var world: World
var camera: Camera3D

var _sta_delay := 0.0
var walk_to := Vector3.INF   # click-to-walk destination (cleared by WASD)
var _walk_t := 0.0
var _air_t := 0.0           # time since last on the ground
var _jump_buffer := 0.0     # a jump pressed just before landing still counts
var _jumping := false
var _double_used := false
var _anim := 0.0
var _mouse_seen := false
var _last_safe := Vector3.ZERO
var model: Rig
var equipped := {}            # slot -> item, drives how the model is dressed
var look := {}                # character creation choices (body, hair, colours); empty = class default
var _face_aim_t := 0.0     # after attacking, briefly face the aim instead of the walk direction
const MODEL_SCALE := 1.25
var _shield_mesh: MeshInstance3D
var _aura: MeshInstance3D
var _aura_mat: StandardMaterial3D


func _ready() -> void:
	add_to_group("player")
	add_to_group("door_users")
	collision_layer = 4
	collision_mask = 1 | 2
	var shape := CapsuleShape3D.new()
	shape.radius = 0.35
	shape.height = 1.5
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position.y = 0.75
	add_child(cs)
	_build_indicators()
	floor_snap_length = 0.6
	floor_max_angle = deg_to_rad(50)


func _build_indicators() -> void:
	# Arcane Barrier bubble
	var sm := SphereMesh.new()
	sm.radius = 0.9
	sm.height = 2.0
	sm.radial_segments = 12
	sm.rings = 6
	var shm := StandardMaterial3D.new()
	shm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shm.albedo_color = Color(0.75, 0.62, 1.0, 0.22)
	shm.cull_mode = BaseMaterial3D.CULL_DISABLED
	_shield_mesh = MeshInstance3D.new()
	_shield_mesh.mesh = sm
	_shield_mesh.material_override = shm
	_shield_mesh.position.y = 1.0
	_shield_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shield_mesh.visible = false
	add_child(_shield_mesh)
	# buff aura ring on the ground
	var tm := TorusMesh.new()
	tm.inner_radius = 0.75
	tm.outer_radius = 0.95
	tm.rings = 16
	tm.ring_segments = 4
	_aura_mat = StandardMaterial3D.new()
	_aura_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_aura_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_aura = MeshInstance3D.new()
	_aura.mesh = tm
	_aura.material_override = _aura_mat
	_aura.scale = Vector3(1, 0.1, 1)
	_aura.position.y = 0.1
	_aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_aura.visible = false
	add_child(_aura)


func setup(id: String, lvl: int, refill := true, t := 0) -> void:
	var ratio := hp / max_hp if max_hp > 0 else 1.0
	class_id = id
	level = lvl
	tier = t
	_compute()
	var c: Dictionary = Data.CLASSES[id]
	if refill:
		hp = max_hp
		res = res_max if c["res_start_full"] else 0.0
		sta = sta_max
	else:
		hp = maxf(1.0, round(max_hp * ratio))
		res = res_max if c["res_start_full"] else 0.0
	buffs.clear()
	shield = 0.0
	dash.clear()
	if model:
		model.queue_free()
	model = Models.hero_geared(id, equipped, look)
	model.scale = Vector3.ONE * MODEL_SCALE
	add_child(model)
	model.set_facing(forward_vec(), true)


## Rebuild the model so it shows what you're wearing.
func refresh_look() -> void:
	if model == null or class_id == "":
		return
	var yaw_dir := forward_vec()
	model.queue_free()
	model = Models.hero_geared(class_id, equipped, look)
	model.scale = Vector3.ONE * MODEL_SCALE
	add_child(model)
	model.set_facing(yaw_dir, true)


## Re-reads gear without healing or clearing buffs (used when you equip something).
func refresh_stats() -> void:
	var ratio := hp / max_hp if max_hp > 0 else 1.0
	_compute()
	hp = maxf(1.0, round(max_hp * ratio))
	res = minf(res, res_max)


## Level, Warden lights (tier) and gear -> health, damage, crit, armor, resource.
## Sum of a passive-talent effect ("dmg", "crit", "hp", "armor", "res", "move", "cd") over the ranks you hold.
func tfx(kind: String) -> float:
	var total := 0.0
	for n: Dictionary in Data.TALENTS.get(class_id, []):
		if not n.has("effects"):
			continue
		var r := tal(String(n["id"]))
		if r == 0:
			continue
		for e: Dictionary in n["effects"]:
			if e["kind"] == kind:
				total += float(e["per"]) * r
	return total


func tal(id: String) -> int:
	var m := get_parent()
	if m and m.has_method("talent_rank"):
		return int(m.talent_rank(id))
	return 0


func _compute() -> void:
	var c: Dictionary = Data.CLASSES[class_id]
	var cc: Dictionary = Data.CLASS_COMBAT[class_id]
	var main_stat: String = Items.MAIN_STAT[class_id]
	attrs = {}
	for k in ["str", "agi", "int", "sta"]:
		var growth := 4.0 if k == main_stat else (2.0 if k == "sta" else 0.5)
		attrs[k] = 10.0 + growth * (level - 1) + float(gear.get(k, 0.0))
	var base_hp := float(c["hp"])
	max_hp = round((base_hp * (1.0 + 0.1 * tier) + (float(attrs["sta"]) - 10.0) * base_hp * 0.06) * (1.0 + 0.04 * (tal("sh_hard") + tal("ve_resil")) + 0.05 * (tal("bw_vital") + tal("bw_titan")) + tfx("hp") / 100.0))
	dmg = (float(cc["dmg"]) + float(gear.get("dmg", 0.0))) * (1.0 + 0.06 * tier) * (1.0 + (float(attrs[main_stat]) - 10.0) * 0.025)
	dmg *= 1.0 + 0.05 * (tal("sh_edge") + tal("ve_sharp") + tal("bw_heavy") + tal("bw_titan")) + tfx("dmg") / 100.0
	crit = 0.05 * tal("sh_opp") + 0.03 * (tal("ve_keen") + tal("bw_crit")) + float(cc["crit"]) + tfx("crit") / 100.0 + float(gear.get("crit", 0.0)) / 100.0 + (float(attrs["agi"]) - 10.0) * 0.001
	var ba: Array = Data.BASE_ARMOR[class_id]
	armor = float(ba[0]) + float(ba[1]) * (level - 1) + float(gear.get("armor", 0.0))
	armor *= 1.0 + 0.1 * (tal("sh_thick") + tal("ve_thick") + tal("bw_thick") + tal("bw_unbreak")) + tfx("armor") / 100.0
	armor_red = minf(0.6, armor / (armor + 60.0 + 15.0 * level))
	res_max = 100.0 + ((float(attrs["int"]) - 10.0) * 2.0 if class_id == "mage" else 0.0) + tfx("res")
	res = minf(res, res_max)


var flying := false   # dev mode
var _stuck_t := 0.0
var _stuck_ref := Vector3.INF


func teleport(p: Vector3) -> void:
	global_position = p
	var wn := get_tree().get_first_node_in_group("world") as World if is_inside_tree() else null
	if wn and wn.streamer:
		wn.streamer.flush(p, 2)
	_last_safe = p
	velocity = Vector3.ZERO
	dash.clear()
	_air_t = 0.0
	_jumping = false


func has_buff(n: String) -> bool:
	return buffs.get(n, 0.0) > 0.0


func is_untouchable() -> bool:
	return dead or inv_t > 0.0 or not dash.is_empty()


func start_dash(vel: Vector3, t: float, mult := 0.0, opts := {}) -> void:
	dash = {"vel": vel, "t": t, "mult": mult, "opts": opts, "hit": {}}


func gain_res(n: float) -> void:
	res = clampf(res + n, 0.0, res_max)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_seen = true


## True while the keeper is walking or turning, so the camera can swing back behind.
func wants_camera_behind() -> bool:
	return _input_active


func forward_vec() -> Vector3:
	return Vector3(-sin(face_yaw), 0, -cos(face_yaw))


func _physics_process(delta: float) -> void:
	var fwd := 0.0
	var side := 0.0
	var turn := 0.0
	if can_act and not dead:
		fwd = Input.get_axis("move_down", "move_up")
		side = Input.get_axis("strafe_left", "strafe_right")
		turn = Input.get_axis("turn_left", "turn_right")
		if run_both:
			fwd = 1.0
		if fwd != 0.0 and (Input.is_action_pressed("move_up") or Input.is_action_pressed("move_down")):
			autorun = false
		if Input.is_action_just_pressed("autorun"):
			autorun = not autorun
		if autorun and fwd == 0.0:
			fwd = 1.0
	else:
		autorun = false
	if steer:
		# mouse-steering: turn to face the camera quickly, never a hard snap
		var dy := angle_difference(face_yaw, cam_yaw)
		face_yaw = cam_yaw if absf(dy) < 0.03 else face_yaw + dy * (1.0 - exp(-delta * 22.0))
		side += turn          # A / D strafe while steering
		side = clampf(side, -1.0, 1.0)
	elif turn != 0.0:
		face_yaw -= turn * TURN_SPEED * delta
	turning = turn != 0.0 and not steer
	back_input = fwd < 0.0 and not run_both
	strafing = side != 0.0
	_input_active = fwd != 0.0 or side != 0.0 or turning
	moving_forward = fwd > 0.0
	var local := Vector3(side, 0, -fwd)
	if local.length() > 1.0:
		local = local.normalized()
	if fwd < 0.0:
		local *= 0.65         # backpedalling is slower
	var move := local.rotated(Vector3.UP, face_yaw)
	if move.length() > 0.1 or dead or not can_act:
		walk_to = Vector3.INF
	elif walk_to != Vector3.INF:
		var to := walk_to - global_position
		to.y = 0.0
		_walk_t += delta
		if to.length() < 0.3 or _walk_t > 8.0:
			walk_to = Vector3.INF
		else:
			move = to.normalized()
	if walk_to == Vector3.INF:
		_walk_t = 0.0
	var net: Node = get_parent().get("online") if Online.active else null
	if net != null and not net.started:
		net = null
	if net != null and net.typing():
		move = Vector3.ZERO   # online chat: typing must not walk you around
	var moving := move.length() > 0.1
	_input_active = _input_active or walk_to != Vector3.INF
	moving_forward = moving_forward or walk_to != Vector3.INF
	var speed: float = Data.CLASSES[class_id]["speed"]
	var sk = get_parent().get("skills")
	if sk:
		speed *= sk.speed_mult()
	if has_buff("swift"):
		speed *= 1.2
	speed *= 1.0 + 0.04 * tal("sh_nimble") + 0.03 * tal("ve_agile") + tfx("move") / 100.0
	if net != null and net.server_speed > 0.0:
		speed = net.server_speed   # online: walk at the pace the server uses, so we agree on where we are

	for k: String in buffs.keys():
		buffs[k] = buffs[k] - delta
		if buffs[k] <= 0.0:
			buffs.erase(k)
			if k == "barrier":
				shield = 0.0
	inv_t -= delta
	attack_t -= delta
	swing_t -= delta

	_jump_buffer -= delta
	if can_act and not dead and Input.is_action_just_pressed("jump"):
		_jump_buffer = 0.12

	var sprinting := can_act and Input.is_action_pressed("sprint") and moving and sta > 1.0
	if sprinting:
		sta -= SPRINT_DRAIN * delta
		_sta_delay = 0.6
	else:
		_sta_delay -= delta
		if _sta_delay <= 0.0:
			sta = minf(sta_max, sta + STA_REGEN * delta * (sk.stamina_mult() if sk else 1.0) * (1.5 if has_buff("swift") else 1.0))
	sta = maxf(sta, 0.0)

	var hv: Vector3
	if not dash.is_empty():
		dash["t"] = float(dash["t"]) - delta
		hv = dash["vel"]
		if dash["t"] <= 0.0:
			dash.clear()
			inv_t = maxf(inv_t, 0.15)
	elif dead:
		hv = Vector3.ZERO
	else:
		var slow := 0.6 if world.ground_at(global_position) == World.G.BOG else 1.0
		if world.is_water(global_position.x, global_position.z):
			slow = minf(slow, 0.5)   # wading
		hv = move * speed * (SPRINT_MULT if sprinting else 1.0) * slow
	hv = _avoid_water(hv)
	velocity.x = hv.x
	velocity.z = hv.z
	if flying:
		collision_mask = 0
		var fs := 22.0 * (2.6 if Input.is_action_pressed("sprint") else 1.0)
		var up := (1.0 if Input.is_action_pressed("jump") else 0.0) - (1.0 if Input.is_key_pressed(KEY_C) else 0.0)
		velocity = Vector3(move.x * fs, up * fs * 0.7, move.z * fs)
		move_and_slide()
		_last_safe = global_position
		RenderingServer.global_shader_parameter_set("player_pos", global_position)
		_tick_resource(delta)
		_update_aim(move, moving)
		_animate(delta, moving, false)
		if net != null:
			net.fly_sync(self, delta)   # online: the server follows where we fly (development)
		return
	elif collision_mask == 0:
		collision_mask = 1 | 2
	var grounded := is_on_floor()
	if grounded:
		if _jumping and _air_t > 0.15:
			Sfx.play("step", Vector3.INF, -8.0, 0.1)
		_air_t = 0.0
		_jumping = false
	else:
		_air_t += delta
	var double_jump: bool = _jump_buffer > 0.0 and _jumping and not _double_used and sk != null and sk.can_double_jump() and dash.is_empty() and not dead
	if double_jump:
		_jump_buffer = 0.0
		if sta >= JUMP_COST:
			sta -= JUMP_COST
			_sta_delay = 0.5
			velocity.y = JUMP_SPEED * 0.9
			if net != null:
				net.send({"t": "jump"})
			_double_used = true
			Sfx.play("dodge", Vector3.INF, -8.0, 0.2)
			sk.on_jump()
	elif _jump_buffer > 0.0 and not _jumping and _air_t < COYOTE and dash.is_empty() and not dead:
		_jump_buffer = 0.0
		if sta < JUMP_COST:
			notify.emit("Too tired to jump")
		else:
			sta -= JUMP_COST
			_sta_delay = 0.5
			velocity.y = JUMP_SPEED
			if net != null:
				net.send({"t": "jump"})
			_jumping = true
			_double_used = false
			if sk:
				sk.on_jump()
			_air_t = COYOTE
			Sfx.play("dodge", Vector3.INF, -10.0, 0.1)
	elif grounded:
		velocity.y = -1.0
	else:
		velocity.y -= GRAVITY * delta
		# let go of jump early for a shorter hop
		if _jumping and velocity.y > 0.0 and not Input.is_action_pressed("jump"):
			velocity.y -= GRAVITY * delta * 1.5
	var wanted_h := Vector2(velocity.x, velocity.z)
	move_and_slide()
	_unstick(delta, move)
	if net != null:
		net.sync_player(self, delta, move, sprinting, wanted_h)   # online: tell the server, ease back to its position if we drifted

	if global_position.y < -8.0:
		teleport(_last_safe + Vector3(0, 1, 0))
	elif is_on_floor():
		_last_safe = global_position

	RenderingServer.global_shader_parameter_set("player_pos", global_position)
	_tick_resource(delta)
	_update_aim(move, moving)
	_animate(delta, moving, sprinting)


## Wedged between meshes: pushing to move for over a second without getting anywhere hops you up and out.
func _unstick(delta: float, move: Vector3) -> void:
	if move.length() < 0.3 or not dash.is_empty() or dead:
		_stuck_t = 0.0
		_stuck_ref = Vector3.INF
		return
	if _stuck_ref == Vector3.INF or global_position.distance_to(_stuck_ref) > 0.35:
		_stuck_ref = global_position
		_stuck_t = 0.0
		return
	_stuck_t += delta
	if _stuck_t < 1.0:
		return
	_stuck_t = 0.0
	var dir := move.normalized()
	for step in [1.2, 2.2, 3.4]:
		var dest: Vector3 = global_position + dir * float(step)
		var gy := world.height_at(dest.x, dest.z)
		var ok := not world.is_water(dest.x, dest.z)
		if ok:
			var q := PhysicsPointQueryParameters3D.new()
			q.position = Vector3(dest.x, maxf(gy, global_position.y) + 1.0, dest.z)
			q.collision_mask = 3
			if get_world_3d().direct_space_state.intersect_point(q, 1).is_empty():
				global_position = Vector3(dest.x, maxf(gy, global_position.y) + 0.8, dest.z)
				velocity = Vector3.ZERO
				_stuck_ref = Vector3.INF
				return
	global_position += Vector3(0, 1.5, 0)   # last resort: pop up
	_stuck_ref = Vector3.INF


## Shallows can be waded (slowly). Only deep water stops you, and only if you are not already in it,
## so you can always walk back out of a hole.
func _avoid_water(hv: Vector3) -> Vector3:
	var p := global_position
	if world.height_at(p.x, p.z) < World.WATER_Y - 1.0:
		return hv
	var look := 0.55
	if hv.x != 0.0 and world.height_at(p.x + signf(hv.x) * look, p.z) < World.WATER_Y - 1.0:
		hv.x = 0.0
	if hv.z != 0.0 and world.height_at(p.x, p.z + signf(hv.z) * look) < World.WATER_Y - 1.0:
		hv.z = 0.0
	return hv


func _tick_resource(delta: float) -> void:
	combat_t += delta
	match class_id:
		"mage":
			res += (5.0 + 0.4 * level) * (3.0 if combat_t > 4.0 else 1.0) * delta
		"hunter":
			res += 9.0 * delta
		"warrior":
			res += 16.0 * (1.0 + 0.1 * (tal("bw_vigor") + tal("ve_flow"))) * delta
	res = clampf(res, 0.0, res_max)
	if not dead and combat_t > 6.0 and hp < max_hp:
		hp = minf(max_hp, hp + max_hp * 0.008 * delta)   # slow regen out of combat
	if world and not dead and global_position.distance_to(world.shrine_pos) < 8.0 and hp < max_hp:
		hp = minf(max_hp, hp + max_hp * 0.25 * delta)


## Target-based: aim at the selected enemy, otherwise straight ahead.
func _update_aim(_move: Vector3, _moving: bool) -> void:
	var m := get_parent()
	if m and m.has_method("has_target") and m.has_target():
		var t: Node3D = m.get("target")
		var d := Vector3(t.global_position.x - global_position.x, 0, t.global_position.z - global_position.z)
		if d.length() > 0.05:
			aim_dir = d.normalized()
			aim_point = global_position + aim_dir * minf(d.length(), 11.0)
			return
	aim_dir = forward_vec()
	aim_point = global_position + aim_dir * 7.0


func anim_attack(dur := 0.25, face := true) -> void:
	if face:
		_face_aim_t = 0.45
	armed_t = 6.0
	if model:
		model.set_armed(true, true)
		if face:
			model.set_facing(aim_dir)
		model.attack(dur)


func anim_cast(dur := 0.4, face := true) -> void:
	if face:
		_face_aim_t = 0.5
	armed_t = 6.0
	if model:
		model.set_armed(true, true)
		if face:
			model.set_facing(aim_dir)
		model.cast(dur)


func _animate(delta: float, moving: bool, sprinting: bool) -> void:
	if model == null:
		return
	var move_amt := 0.0
	model.air = 0.0 if is_on_floor() else clampf(_air_t * 6.0, 0.0, 1.0)
	if not dash.is_empty():
		model.set_facing(dash["vel"])
		move_amt = 1.4
	else:
		_face_aim_t -= delta
		if _face_aim_t > 0.0:
			model.set_facing(aim_dir)
		else:
			# face the way you're actually going (strafing right = looking right); stand facing forward
			# strafing sideways looks where you're heading; walking, backpedalling and standing face
			# forward, snapped so the body never lags behind the camera
			var walk := Vector3(velocity.x, 0, velocity.z)
			if moving and strafing and not back_input and walk.length() > 0.3:
				model.set_facing(walk)
			else:
				model.set_facing(forward_vec(), true)
		if moving:
			move_amt = 1.3 if sprinting else 1.0
			_step_t -= delta
			if _step_t <= 0.0 and is_on_floor():
				_step_t = 0.24 if sprinting else 0.34
				Sfx.play("step", Vector3.INF, -16.0, 0.15)
	# weapons: drawn while fighting (or when something hostile is close), sheathed otherwise
	armed_t -= delta
	_threat_t -= delta
	if _threat_t <= 0.0:
		_threat_t = 0.3
		if combat_ref and not dead:
			for e: Enemy in (combat_ref as Combat).enemies:
				if is_instance_valid(e) and e.aggro and not e.dead and global_position.distance_to(e.global_position) < 14.0:
					armed_t = maxf(armed_t, 4.0)
					break
	model.set_armed(armed_t > 0.0)
	model.walk_speed = 12.0 if sprinting else 9.0
	var main_node := get_parent()
	model.look_target = (main_node.target.global_position + Vector3(0, 1.2, 0)) if (main_node != null and main_node.has_method("has_target") and main_node.has_target()) else Vector3.INF
	model.tick(delta, move_amt)
	# visibility effects
	var stealth := has_buff("stealth")
	var blink := inv_t > 0.0 and dash.is_empty() and int(Time.get_ticks_msec() / 50) % 2 == 0
	model.set_alpha(0.35 if stealth else 1.0)
	model.set_tint(Color(0.8, 0.9, 1.3) if has_buff("stand") else Color.WHITE)
	model.visible = not blink and not dead and not hide_model
	_shield_mesh.visible = has_buff("barrier") and shield > 0.0
	if has_buff("shout"):
		_aura.visible = true
		_aura_mat.albedo_color = Color(1.0, 0.35, 0.2, 0.55)
	elif has_buff("poison"):
		_aura.visible = true
		_aura_mat.albedo_color = Color(0.45, 0.85, 0.3, 0.5)
	elif has_buff("flurry"):
		_aura.visible = true
		_aura_mat.albedo_color = Color(1.0, 0.82, 0.4, 0.5)
	else:
		_aura.visible = false
