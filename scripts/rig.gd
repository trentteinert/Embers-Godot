@tool
class_name Rig
extends Node3D
## A low-poly character or creature made of simple shapes (see models.gd), with procedural animation:
## walk cycles, attack swings, spell casts, jumps, hit flashes and colour tints.
## The model faces +Z. Call tick() every frame with how fast it is moving (0..1+).

var kind := "humanoid"       # humanoid, quad, blob, spider, worm, float
var parts := {}              # name -> Node3D pivot (legs, arms, head, body...)
var height := 1.6
var walk_speed := 9.0        # walk cycle rate

var pivot: Node3D            # sits at chest height
var body: Node3D             # everything visible hangs off this

var _mats: Array[StandardMaterial3D] = []
var _mat_cache := {}
var _base_albedo: Array[Color] = []
var _base_emit: Array[float] = []
var _phase := 0.0
var _move := 0.0
var _attack_t := 0.0
var _attack_dur := 0.25
var _attack_left := false
var _cast_t := 0.0
var _ranged_t := 0.0     # drawing a bow or waving a staff for a basic shot
var _ranged_dur := 1.0
var _ranged_staff := false
var _cast_dur := 0.4
var _flash_t := 0.0
var _flashing := false
var _tint := Color.WHITE
var _alpha := 1.0
var _yaw := 0.0
var _target_yaw := 0.0
var _rest := {}              # part name -> resting position
var _t := 0.0
var look_target := Vector3.INF   # a world position the head turns toward (Vector3.INF = none)
var _ba := {}                # block animation state (anim_humanoid.txt)
var air := 0.0               # 0..1 how airborne (jump pose)
var hold_flash := false      # keep the white flash on (wind-up warnings)

# weapons: drawn (in the hands) or sheathed (hip / back); work: a skilling pose with a tool in hand
const DRAW_DUR := 0.3
var _weapons: Array = []     # {node, home, home_xf, mount_xf}
var _armed := true
var _armed_set := false
var _draw_t := 0.0
var _draw_swapped := true
var work_kind := ""          # chop, mine, gather, fish, cook, brew, smith, craft ("" = not working)
var _work_t := 0.0
var _work_u := 0.0
var _tool_r: Node3D
var _tool_l: Node3D
var _fish_line: Node3D
var on_work_hit := Callable()  # called at the moment a swing lands


func _init() -> void:
	pivot = Node3D.new()
	pivot.name = "Pivot"
	pivot.position.y = 0.8
	add_child(pivot)
	body = Node3D.new()
	body.name = "Body"
	body.position.y = -0.8
	pivot.add_child(body)


## A material owned by this rig (so flashes and tints don't affect other models).
func mat(col: Color, emit := 0.0) -> StandardMaterial3D:
	var key := col.to_html() + str(emit)
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.95
	m.metallic_specular = 0.2
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emit
	_mats.append(m)
	_base_albedo.append(col)
	_base_emit.append(emit)
	_mat_cache[key] = m
	return m


func add_part(part_name: String, node: Node3D) -> void:
	parts[part_name] = node
	_rest[part_name] = node.position


func set_facing(dir: Vector3, instant := false) -> void:
	if Vector2(dir.x, dir.z).length() < 0.01:
		return
	_target_yaw = atan2(dir.x, dir.z)
	if instant:
		_yaw = _target_yaw
		rotation.y = _yaw


## Registers a weapon so it can be sheathed: `home` is where it sits when drawn.
func add_weapon(n: Node3D, home: Node3D, side: int, w: String) -> void:
	var mount := Transform3D()
	match w:
		"dagger", "shortsword":
			mount = Transform3D(Basis.from_euler(Vector3(0, 0, PI - 0.3 * side)), Vector3(0.3 * side, 0.03, 0.0))
		"sword":
			# hangs from the belt on the left hip, blade angled back and down; shrunk so the tip clears the ground
			var d := Vector3(0.1 * side, -0.78, -0.62).normalized()
			var zax := (Vector3(side, 0, 0) - d * d.x * side).normalized()
			var xax := d.cross(zax).normalized()
			mount = Transform3D(Basis(xax, d, zax).scaled(Vector3.ONE * 0.62), Vector3(-0.3 * side, 0.0, -0.02))
		"shield":
			mount = Transform3D(Basis.from_euler(Vector3(-PI * 0.5, 0, 0)), Vector3(0, 0.3, -0.24))
		"staff":
			# slung across the back, the head over the right shoulder
			mount = Transform3D(Basis.from_euler(Vector3(0.0, 0.0, 0.42)), Vector3(-0.05, -0.05, -0.3))
		"bow":
			# hung on the back, limbs up and down, the grip on the middle of the spine
			mount = Transform3D(Basis.from_euler(Vector3(0.0, PI * 0.5, 0.2)), Vector3(0.0, 0.1, -0.27))
		_:
			mount = Transform3D(Basis.from_euler(Vector3(-0.08, 0, 0.85 * side)), Vector3(-0.05 * side, 0.1, -0.2))
	_weapons.append({"node": n, "home": home, "home_xf": n.transform, "mount_xf": mount, "type": w})


func is_armed() -> bool:
	return _armed


## Draws or sheathes every weapon (with a quick reach-and-stow animation unless `instant`).
func set_armed(on: bool, instant := false) -> void:
	if work_kind != "":
		return
	if _armed_set and on == _armed:
		return
	var first := not _armed_set
	_armed_set = true
	_armed = on
	if instant or first or _weapons.is_empty():
		_apply_armed(on)
		_draw_t = 0.0
		_draw_swapped = true
	else:
		_draw_t = DRAW_DUR
		_draw_swapped = false


func _apply_armed(on: bool) -> void:
	if not parts.has("torso"):
		return
	for w: Dictionary in _weapons:
		var n: Node3D = w["node"]
		if not is_instance_valid(n):
			continue
		var tgt: Node3D = w["home"] if on else parts["torso"]
		if n.get_parent() != tgt:
			n.get_parent().remove_child(n)
			tgt.add_child(n)
		n.transform = w["home_xf"] if on else w["mount_xf"]


## Starts (or stops, with "") a skilling pose. The weapon is sheathed and the right tool comes out.
func set_work(kind: String, col := "a3adba") -> void:
	if kind == work_kind:
		return
	_clear_tools()
	if kind != "":
		_armed_set = true
		_armed = false
		_apply_armed(false)
		_draw_t = 0.0
		var t: Array = Models.work_tools(self, kind, col)
		_tool_r = t[0]
		_tool_l = t[1]
		if parts.has("hand_r") and _tool_r:
			(parts["hand_r"] as Node3D).add_child(_tool_r)
			_tool_r.scale = Vector3.ZERO
		if parts.has("hand_l") and _tool_l:
			(parts["hand_l"] as Node3D).add_child(_tool_l)
			_tool_l.scale = Vector3.ZERO
		if kind == "fish" and _tool_r:
			_fish_line = _tool_r.get_node_or_null("Tip")
	work_kind = kind
	_work_t = 0.0
	_work_u = 0.0


func _clear_tools() -> void:
	for t in [_tool_r, _tool_l]:
		if is_instance_valid(t):
			(t as Node3D).queue_free()
	_tool_r = null
	_tool_l = null
	_fish_line = null


func _work_period() -> float:
	match work_kind:
		"craft":
			return 0.5
		"fish":
			return 3.2
		_:
			return 0.85


## `left`: swing with the left hand (dual wielding alternates). `fast`: a quick flurry swing, not the full-length one.
func attack(dur := 0.25, left := false, fast := false) -> void:
	var least := 0.26 if fast else 0.5
	_attack_t = maxf(dur, least)
	_attack_dur = maxf(dur, least)
	_attack_left = left


## Basic ranged attack: a two-handed bow draw and release, or a wave of the staff. The shot leaves near the end.
func shoot(dur := 1.0) -> void:
	_ranged_t = dur
	_ranged_dur = dur
	_ranged_staff = false


func wave(dur := 0.9) -> void:
	_ranged_t = dur
	_ranged_dur = dur
	_ranged_staff = true


func cast(dur := 0.4) -> void:
	_cast_t = dur
	_cast_dur = dur


func hit_flash() -> void:
	_flash_t = 0.12


func set_tint(c: Color) -> void:
	if c == _tint:
		return
	_tint = c
	_apply_colors()


func set_alpha(a: float) -> void:
	if is_equal_approx(a, _alpha):
		return
	_alpha = a
	for m in _mats:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if a < 0.99 else BaseMaterial3D.TRANSPARENCY_DISABLED
	_apply_colors()


func _apply_colors() -> void:
	for i in _mats.size():
		var c := _base_albedo[i] * _tint
		c.a = _alpha
		_mats[i].albedo_color = c


func _set_flash(on: bool) -> void:
	if on == _flashing:
		return
	_flashing = on
	for i in _mats.size():
		var m := _mats[i]
		if on:
			m.emission_enabled = true
			m.emission = Color(1, 1, 1)
			m.emission_energy_multiplier = 1.6
		else:
			m.emission_enabled = _base_emit[i] > 0.0
			m.emission = _base_albedo[i]
			m.emission_energy_multiplier = _base_emit[i]


func flash_pulse(on: bool) -> void:
	## for wind-up warnings: blink white while true
	hold_flash = on and int(Time.get_ticks_msec() / 70) % 2 == 0


func tick(delta: float, move: float) -> void:
	_t += delta
	_move = lerpf(_move, clampf(move, 0.0, 1.5), 1.0 - exp(-delta * 12.0))
	_phase += delta * walk_speed * maxf(_move, 0.0)
	_yaw = lerp_angle(_yaw, _target_yaw, 1.0 - exp(-delta * 14.0))
	rotation.y = _yaw
	_attack_t = maxf(0.0, _attack_t - delta)
	_cast_t = maxf(0.0, _cast_t - delta)
	_ranged_t = maxf(0.0, _ranged_t - delta)
	if _draw_t > 0.0:
		_draw_t = maxf(0.0, _draw_t - delta)
		if not _draw_swapped and _draw_t <= DRAW_DUR * 0.5:
			_draw_swapped = true
			_apply_armed(_armed)
	if work_kind != "":
		_work_t += delta
		var per := _work_period()
		var nu := fmod(_work_t, per) / per
		if work_kind in ["chop", "mine", "smith", "craft"] and _work_u < 0.62 and nu >= 0.62 and _work_t > 0.4 and on_work_hit.is_valid():
			on_work_hit.call()
		_work_u = nu
		var grow := clampf((_work_t - 0.08) / 0.3, 0.0, 1.0)
		var sc := Vector3.ONE * (1.0 - pow(1.0 - grow, 3.0))
		if is_instance_valid(_tool_r):
			_tool_r.scale = sc
		if is_instance_valid(_tool_l):
			_tool_l.scale = sc
		if is_instance_valid(_fish_line):
			(_fish_line as Node3D).global_rotation = Vector3.ZERO
	_flash_t -= delta
	_set_flash(_flash_t > 0.0 or hold_flash)
	match kind:
		"humanoid":
			_anim_humanoid()
		"quad":
			_anim_quad()
		"blob":
			_anim_blob()
		"spider":
			_anim_spider()
		"worm":
			_anim_worm()
		"float":
			_anim_float()


func _rot(part_name: String, x := 0.0, y := 0.0, z := 0.0) -> void:
	if parts.has(part_name):
		(parts[part_name] as Node3D).rotation = Vector3(x, y, z)


func _anim_humanoid() -> void:   # block animation v2 (godot_character/anim_humanoid.txt): bigger range, weight and follow-through
	var dt := get_process_delta_time()
	var s := sin(_phase)
	var c := cos(_phase)
	var amt := minf(_move, 1.0)
	var run := clampf(_move - 1.0, 0.0, 0.5) * 2.0     # 0 walking .. 1 sprinting
	var fem := 1.0 if get_meta("femme", false) else 0.0
	var idle_k := 1.0 - smoothstep(0.0, 0.35, _move)    # 1 standing .. 0 moving
	# which way we move compared with which way we face (we keep facing forward when backing up, and lean when sidestepping)
	var df: float = _ba.get("df", 1.0)
	var ds: float = _ba.get("ds", 0.0)
	if is_inside_tree() and dt > 0.0:
		# the body moves in physics steps, so measure over a short stretch of time, not frame to frame
		var p := global_position
		var t_acc: float = float(_ba.get("tacc", 0.0)) + dt
		if not _ba.has("p0"):
			_ba["p0"] = p
		if t_acc >= 0.06:
			var p0: Vector3 = _ba["p0"]
			var mv := Vector3(p.x - p0.x, 0.0, p.z - p0.z) / t_acc
			if mv.length() > 0.6 and _move > 0.1:
				var mn := mv.normalized()
				var fw := Vector3(global_transform.basis.z.x, 0.0, global_transform.basis.z.z).normalized()
				var lf := Vector3(global_transform.basis.x.x, 0.0, global_transform.basis.x.z).normalized()
				_ba["tf"] = mn.dot(fw)
				_ba["ts"] = mn.dot(lf)
			elif _move < 0.08:
				_ba["tf"] = 1.0
				_ba["ts"] = 0.0
			_ba["p0"] = p
			t_acc = 0.0
		_ba["tacc"] = t_acc
		df = lerpf(df, float(_ba.get("tf", 1.0)), 1.0 - exp(-dt * 8.0))
		ds = lerpf(ds, float(_ba.get("ts", 0.0)), 1.0 - exp(-dt * 8.0))
		_ba["df"] = df
		_ba["ds"] = ds
	var fdir := clampf(df * 2.0, -1.0, 1.0)             # legs and arms swing the other way when backing up
	var back_k := clampf(-df, 0.0, 1.0) * minf(_move, 1.0)
	var side_k := smoothstep(0.35, 0.85, absf(ds)) * (1.0 - smoothstep(0.3, 0.7, absf(df))) * minf(_move, 1.0)
	var sgn := signf(ds)
	# start and stop: lean into a start, rock back on a stop
	var acc: float = _ba.get("acc", 0.0)
	if dt > 0.0:
		acc = lerpf(acc, (_move - float(_ba.get("mv", _move))) / dt, 1.0 - exp(-dt * 8.0))
		_ba["mv"] = _move
		_ba["acc"] = acc
	var lean_acc := clampf(acc * 0.025, -0.08, 0.1)
	# landing: a short crouch when the jump ends
	var air_prev: float = _ba.get("air", 0.0)
	var land: float = _ba.get("land", 0.0)
	if air_prev > 0.6 and air < 0.4:
		land = 1.0
	land = maxf(0.0, land - dt * 4.5)
	_ba["air"] = air
	_ba["land"] = land
	var lk := sin(land * PI) if land > 0.0 else 0.0

	var swing := (0.85 + 0.35 * run) * (1.0 - 0.1 * fem) * (1.0 - 0.55 * back_k - 0.55 * side_k)
	var leg_l := s * swing * amt * fdir
	var leg_r := -s * swing * amt * fdir
	# knees fold while the leg swings forward, and the foot lifts
	var knee_l := maxf(0.0, -c) * (1.15 + 0.75 * run) * amt * (1.0 - 0.4 * back_k)
	var knee_r := maxf(0.0, c) * (1.15 + 0.75 * run) * amt * (1.0 - 0.4 * back_k)
	var leg_lz := 0.02 + 0.03 * amt
	var leg_rz := -0.02 - 0.03 * amt
	# backing up: each foot swings out and round as it lifts (not straight back and forth); sidestepping: the feet step across
	leg_lz += s * 0.4 * side_k * sgn
	leg_rz -= s * 0.4 * side_k * sgn
	var arm_l := -s * (0.75 + 0.35 * run) * amt * fdir * (1.0 - 0.35 * back_k - 0.6 * side_k)
	var arm_r := s * (0.75 + 0.35 * run) * amt * fdir * (1.0 - 0.35 * back_k - 0.6 * side_k)
	# elbows stay bent, and bend more as the arm comes forward (a pumping run)
	var elb_l := -(0.18 + (0.3 + 0.9 * run) * maxf(0.0, s * fdir)) * (0.4 + 0.6 * amt)
	var elb_r := -(0.18 + (0.3 + 0.9 * run) * maxf(0.0, -s * fdir)) * (0.4 + 0.6 * amt)
	var arm_lz := 0.05 + 0.04 * amt
	var arm_rz := -0.05 - 0.04 * amt
	# standing: breathing, weight shifting from foot to foot, arms hanging loose
	var sway := sin(_t * 0.5)
	var breath := sin(_t * 2.0)
	arm_l += sin(_t * 1.1) * 0.06 * idle_k
	arm_r += sin(_t * 1.1 + 1.7) * 0.06 * idle_k
	elb_l -= 0.14 * idle_k
	elb_r -= 0.14 * idle_k
	arm_lz += breath * 0.02 * idle_k
	arm_rz -= breath * 0.02 * idle_k
	knee_l += maxf(0.0, sway) * 0.16 * idle_k
	knee_r += maxf(0.0, -sway) * 0.16 * idle_k
	leg_l -= maxf(0.0, sway) * 0.07 * idle_k
	leg_r -= maxf(0.0, -sway) * 0.07 * idle_k
	if air > 0.0:
		# jump pose: one knee forward, one leg tucked back, arms out
		leg_l = lerpf(leg_l, -1.05, air)
		leg_r = lerpf(leg_r, 0.6, air)
		knee_l = lerpf(knee_l, 1.0, air)
		knee_r = lerpf(knee_r, 1.2, air)
		arm_l = lerpf(arm_l, -0.7, air)
		arm_r = lerpf(arm_r, -0.7, air)
		elb_l = lerpf(elb_l, -0.6, air)
		elb_r = lerpf(elb_r, -0.6, air)
		arm_lz = lerpf(arm_lz, -0.8, air)
		arm_rz = lerpf(arm_rz, 0.8, air)
	var body_y := 0.0
	var body_z := 0.0
	var torso_y := -s * 0.13 * amt * fdir * (1.0 - air)      # shoulders counter-twist against the hips
	var torso_x := 0.05 * amt + 0.09 * run - 0.05 * air + lean_acc + breath * 0.015 * idle_k
	var torso_z := s * 0.015 * amt * (1.0 + fem) + sway * 0.02 * idle_k - ds * 0.05 * amt
	var body_x := 0.02 * amt + 0.06 * run + lean_acc * 0.5
	body_y = s * 0.08 * amt * fdir * (1.0 - air)                  # hips twist
	body_z = s * (0.012 + 0.05 * back_k) * amt * (1.0 - air) * (1.0 + fem * 1.2) - ds * 0.05 * amt + sway * 0.015 * idle_k
	var hop := (1.0 - absf(s)) * (0.05 + 0.04 * run) * amt * (1.0 - air) * (1.0 - 0.5 * back_k)   # up between steps, down on each footfall
	var body_off := 0.0
	# backing up (after a reference clip): the hips stay turned to one side, the upper body keeps facing the way you look, knees stay bent in a low
	# guarded stance, the arms are held up in front, and the lifted foot crosses behind
	if back_k > 0.0:
		var turn := 0.2 + 0.55 * clampf(ds * 1.6, -1.0, 1.0)   # backing up and to the left/right: turn the hips more that way
		body_y += turn * back_k
		torso_y -= turn * 0.55 * back_k
		torso_x += 0.1 * back_k
		body_off -= 0.06 * back_k
		knee_l += 0.22 * back_k
		knee_r += 0.22 * back_k
		leg_l -= 0.08 * back_k
		leg_r -= 0.08 * back_k
		arm_l = lerpf(arm_l, -0.85, 0.75 * back_k)
		elb_l = lerpf(elb_l, -1.3, 0.75 * back_k)
		arm_r = lerpf(arm_r, -0.6, 0.75 * back_k)
		elb_r = lerpf(elb_r, -1.0, 0.75 * back_k)
		leg_lz += knee_l * 0.1 * back_k
		leg_rz -= knee_r * 0.1 * back_k
	if lk > 0.0:
		leg_l -= 0.55 * lk
		leg_r -= 0.45 * lk
		knee_l += 0.95 * lk
		knee_r += 0.85 * lk
		torso_x += 0.28 * lk
		arm_l -= 0.4 * lk
		arm_r -= 0.4 * lk
		body_off -= 0.16 * lk
	# the head: glances about while standing, and turns (neck first, then the eyes of the player follow) toward look_target when there is one
	var lw: float = _ba.get("lw", 0.0)
	var has_look := look_target != Vector3.INF and is_inside_tree()
	lw = lerpf(lw, 1.0 if has_look else 0.0, 1.0 - exp(-dt * 7.0))
	_ba["lw"] = lw
	var head_look := (sin(_t * 0.37) * 0.28 + sin(_t * 0.93) * 0.08) * idle_k * (1.0 - lw) - 0.0
	var head_nod := sin(_t * 0.61) * 0.05 * idle_k * (1.0 - lw)
	var look_yaw := 0.0
	var look_pitch := 0.0
	if has_look:
		var lp := to_local(look_target)
		var flat := Vector2(lp.x, lp.z).length()
		look_yaw = clampf(atan2(lp.x, lp.z), -1.15, 1.15)
		look_pitch = clampf(-atan2(lp.y - 1.45, maxf(flat, 0.3)), -0.5, 0.45)
	_ba["hy"] = lerpf(float(_ba.get("hy", 0.0)), look_yaw, 1.0 - exp(-dt * 9.0))
	_ba["hp"] = lerpf(float(_ba.get("hp", 0.0)), look_pitch, 1.0 - exp(-dt * 9.0))
	var push := 0.0      # the whole body pushed forward (lunges, thrusts)
	var head_x_extra := 0.0

	var base_pose := {"arm_r": arm_r, "arm_l": arm_l, "elb_r": elb_r, "elb_l": elb_l, "arm_lz": arm_lz, "arm_rz": arm_rz, "torso_y": torso_y, "torso_x": torso_x,
		"leg_l": leg_l, "leg_r": leg_r, "knee_l": knee_l, "knee_r": knee_r, "body_y": body_y, "push": push}
	var aw := 0.0
	if _attack_t > 0.0:
		var k := 1.0 - _attack_t / _attack_dur
		aw = smoothstep(0.0, 0.14, k) * (1.0 - smoothstep(0.84, 1.0, k))   # ease into the swing and back out of it
		var prev_t: float = _ba.get("atk", 0.0)
		if _attack_t > prev_t + 0.001:
			_ba["var"] = (int(_ba.get("var", 0)) + 1) % 3   # a new swing: next move of the combo
		var move_n: int = int(_ba.get("var", 0))
		var e := 1.0 - pow(1.0 - k, 3.0)
		var wind := smoothstep(0.0, 0.32, k)                  # anticipation: pull back before the strike
		var hit := smoothstep(0.3, 0.62, k)                   # the strike
		var rec := smoothstep(0.7, 1.0, k)                    # follow-through, easing back
		var strike := hit * (1.0 - rec)
		match move_n:
			0:   # overhead chop
				arm_r = lerpf(-0.9, -2.95, wind) * (1.0 - hit) + lerpf(-2.95, -0.35, hit) * hit
				elb_r = lerpf(-0.6, -1.5, wind) * (1.0 - hit) + lerpf(-1.5, -0.1, hit) * hit
				torso_y = lerpf(0.0, 0.55, wind) * (1.0 - hit) + lerpf(0.55, -0.45, hit) * hit
				torso_x += -0.18 * wind * (1.0 - hit) + 0.34 * strike
				leg_l = -0.75 * strike - 0.1 * wind
				leg_r = 0.5 * strike
				knee_l = 0.45 * strike
				knee_r = 0.3 * strike
				push = 0.14 * strike
			1:   # sideways slash
				arm_r = lerpf(-0.9, -1.55, wind)
				arm_rz = lerpf(-0.05, 1.7, wind) * (1.0 - hit) + lerpf(1.7, -1.0, hit) * hit
				elb_r = lerpf(-0.6, -0.9, wind) * (1.0 - hit) + lerpf(-0.9, -0.12, hit) * hit
				torso_y = lerpf(0.0, 0.8, wind) * (1.0 - hit) + lerpf(0.8, -0.75, hit) * hit
				body_y = torso_y * 0.4
				torso_x += 0.15 * strike
				leg_l = -0.5 * strike
				leg_r = 0.6 * strike
				knee_r = 0.4 * strike
				push = 0.08 * strike
			_:   # thrust
				arm_r = lerpf(-0.9, -1.2, wind) * (1.0 - hit) + lerpf(-1.2, -1.58, hit) * hit
				elb_r = lerpf(-0.6, -1.9, wind) * (1.0 - hit) + lerpf(-1.9, -0.04, hit) * hit
				torso_y = lerpf(0.0, 0.35, wind) * (1.0 - hit) + lerpf(0.35, -0.3, hit) * hit
				torso_x += -0.1 * wind * (1.0 - hit) + 0.38 * strike
				leg_l = -0.95 * strike
				leg_r = 0.55 * strike
				knee_l = 0.55 * strike
				knee_r = 0.2 * strike
				push = 0.2 * strike
		if _attack_left:
			# off-hand swing: the same move mirrored onto the left arm, the right arm guards
			arm_l = arm_r
			elb_l = elb_r
			arm_lz = -arm_rz
			torso_y = -torso_y
			var t_leg := leg_l
			leg_l = leg_r
			leg_r = t_leg
			var t_knee := knee_l
			knee_l = knee_r
			knee_r = t_knee
			arm_r = lerpf(arm_r, -1.05, 0.7)
			elb_r = -1.1
			arm_rz = -0.1
		else:
			arm_l = lerpf(arm_l, -1.05, 0.7)         # the other arm guards
			elb_l = -1.1
			arm_lz = 0.1
		_ba["atk"] = _attack_t
		arm_r = lerpf(float(base_pose["arm_r"]), arm_r, aw)
		arm_l = lerpf(float(base_pose["arm_l"]), arm_l, aw)
		elb_r = lerpf(float(base_pose["elb_r"]), elb_r, aw)
		elb_l = lerpf(float(base_pose["elb_l"]), elb_l, aw)
		arm_lz = lerpf(float(base_pose["arm_lz"]), arm_lz, aw)
		arm_rz = lerpf(float(base_pose["arm_rz"]), arm_rz, aw)
		torso_y = lerpf(float(base_pose["torso_y"]), torso_y, aw)
		torso_x = lerpf(float(base_pose["torso_x"]), torso_x, aw)
		leg_l = lerpf(float(base_pose["leg_l"]), leg_l, aw)
		leg_r = lerpf(float(base_pose["leg_r"]), leg_r, aw)
		knee_l = lerpf(float(base_pose["knee_l"]), knee_l, aw)
		knee_r = lerpf(float(base_pose["knee_r"]), knee_r, aw)
		body_y = lerpf(float(base_pose["body_y"]), body_y, aw)
		push = lerpf(float(base_pose["push"]), push, aw)
	else:
		_ba["atk"] = 0.0
	if _draw_t > 0.0:
		var kd := 1.0 - _draw_t / DRAW_DUR
		var up_d := sin(kd * PI)
		arm_r = lerpf(arm_r, -2.5, up_d)
		elb_r = lerpf(elb_r, -0.9, up_d)
		arm_l = lerpf(arm_l, -2.3, up_d * 0.8)
		elb_l = lerpf(elb_l, -0.8, up_d * 0.8)
		torso_y += 0.15 * up_d
	if work_kind != "":
		var wt := smoothstep(0.0, 0.3, _work_t)
		var u := _work_u
		var a_r := arm_r
		var e_r := elb_r
		var a_l := arm_l
		var e_l := elb_l
		var tx := 0.0
		var ty := 0.0
		var azr := arm_rz
		var stance := 0.0
		match work_kind:
			"chop", "mine", "smith":
				var amp := 0.85 if work_kind == "smith" else 1.0
				stance = 1.0
				if u < 0.5:
					var k := u / 0.5
					var e := 1.0 - pow(1.0 - k, 2.0)
					a_r = lerpf(-0.9, -2.9 * amp, e)
					e_r = lerpf(-0.5, -1.4, e)
					tx = -0.16 * e
					ty = 0.14 * e
				elif u < 0.62:
					var k := (u - 0.5) / 0.12
					a_r = lerpf(-2.9 * amp, -0.45, k * k)
					e_r = lerpf(-1.4, -0.15, k)
					tx = lerpf(-0.16, 0.45, k)
					ty = lerpf(0.14, -0.24, k)
				else:
					var k := (u - 0.62) / 0.38
					a_r = lerpf(-0.45, -0.9, k)
					e_r = lerpf(-0.15, -0.5, k)
					tx = lerpf(0.45, 0.0, k)
					ty = lerpf(-0.24, 0.0, k)
				a_l = a_r * 0.92
				e_l = e_r
			"gather":
				stance = 0.8
				tx = 0.8 + sin(_work_t * 4.0) * 0.06
				a_r = -1.35 + sin(_work_t * 5.0) * 0.25
				e_r = -0.4
				a_l = -0.5
				e_l = -0.4
			"fish":
				var cast := clampf(1.0 - _work_t / 0.7, 0.0, 1.0)
				a_r = lerpf(-1.05, -2.5, cast * cast) + sin(_work_t * 1.7) * 0.03
				e_r = lerpf(-0.55, -0.2, cast)
				a_l = -0.75
				e_l = -0.7
				tx = -0.04 - 0.1 * cast
				if u > 0.88:
					a_r += sin((u - 0.88) / 0.12 * PI) * -0.45     # a little flick to jig the bait
			"cook":
				a_r = -1.0
				e_r = -0.95 + sin(_work_t * 6.0) * 0.28
				azr = -0.06 + cos(_work_t * 6.0) * 0.1
				a_l = -0.45
				e_l = -0.5
				tx = 0.22
			"brew":
				a_r = -1.05
				e_r = -1.25 + sin(_work_t * 7.0) * 0.22
				azr = -0.05 + cos(_work_t * 7.0) * 0.18
				a_l = -1.05
				e_l = -1.3
				tx = 0.2
			"craft":
				a_r = -1.0
				e_r = -0.9 + maxf(0.0, sin(u * TAU)) * 0.45
				a_l = -1.0
				e_l = -1.2
				tx = 0.25
		arm_r = lerpf(arm_r, a_r, wt)
		elb_r = lerpf(elb_r, e_r, wt)
		arm_l = lerpf(arm_l, a_l, wt)
		elb_l = lerpf(elb_l, e_l, wt)
		arm_rz = lerpf(arm_rz, azr, wt)
		torso_x += tx * wt
		torso_y += ty * wt
		head_x_extra = -tx * wt * 0.6
		# feet planted, knees bent: a working stance
		leg_l = lerpf(leg_l, -0.3 * stance, wt)
		leg_r = lerpf(leg_r, 0.25 * stance, wt)
		knee_l = lerpf(knee_l, 0.3 * stance + maxf(0.0, tx) * 0.2, wt)
		knee_r = lerpf(knee_r, 0.25 * stance, wt)
		body_off -= 0.05 * stance * wt
	if _cast_t > 0.0:
		var k2 := 1.0 - _cast_t / _cast_dur
		var up := sin(k2 * PI)
		var pulse := 1.0 + sin(k2 * PI * 5.0) * 0.08
		arm_l = -2.3 * up * pulse
		arm_r = -2.3 * up * pulse
		elb_l = -0.45 * up
		elb_r = -0.45 * up
		arm_lz = -0.55 * up
		arm_rz = 0.55 * up
		torso_x -= 0.2 * up
		torso_x += 0.15 * smoothstep(0.75, 1.0, k2)   # snaps forward as the spell leaves
		leg_l = lerpf(leg_l, -0.25, up)
		leg_r = lerpf(leg_r, 0.3, up)
		knee_l = lerpf(knee_l, 0.3, up)
		knee_r = lerpf(knee_r, 0.3, up)
		body_off -= 0.04 * up

	# a bow in the hand turns upright while it is drawn (arm out front, limbs up and down), and hangs normally otherwise
	var bow_up := 0.0
	if _ranged_t > 0.0 and not _ranged_staff:
		var kb := 1.0 - _ranged_t / _ranged_dur
		bow_up = smoothstep(0.0, 0.15, kb) * (1.0 - smoothstep(0.78, 1.0, kb))
	for wp: Dictionary in _weapons:
		if String(wp.get("type", "")) == "bow":
			var bn: Node3D = wp["node"]
			if is_instance_valid(bn) and bn.get_parent() == wp["home"]:
				bn.rotation.x = (wp["home_xf"] as Transform3D).basis.get_euler().x + lerpf(0.0, PI * 0.5, bow_up)
	if _ranged_t > 0.0:
		var kr := 1.0 - _ranged_t / _ranged_dur
		var back := 1.0 - smoothstep(0.78, 1.0, kr)   # the pose eases away at the end
		if not _ranged_staff:
			# bow: left arm out holding the bow, right hand draws the string back to the cheek, then lets go
			var pull := smoothstep(0.0, 0.6, kr) * (1.0 - smoothstep(0.62, 0.7, kr))
			# the bow arm reaches across the body towards the drawing hand, the bow itself held upright
			arm_l = lerpf(arm_l, -1.5, back)
			elb_l = lerpf(elb_l, -0.05, back)
			arm_lz = lerpf(arm_lz, 0.3, back)
			arm_r = lerpf(arm_r, -1.5, back)
			elb_r = lerpf(elb_r, -0.15 - 1.95 * pull, back)
			arm_rz = lerpf(arm_rz, 0.1 * pull, back)
			torso_y = lerpf(torso_y, -0.3, back)
			torso_x += 0.04 * smoothstep(0.62, 0.7, kr) * back
			leg_l = lerpf(leg_l, -0.3, back)
			leg_r = lerpf(leg_r, 0.3, back)
			knee_l = lerpf(knee_l, 0.15, back)
			knee_r = lerpf(knee_r, 0.15, back)
		else:
			# staff: raised overhead, waved in a circle, then swept forward as the bolt leaves
			var wind := smoothstep(0.0, 0.35, kr)
			var sweep := smoothstep(0.35, 0.55, kr)
			arm_r = lerpf(arm_r, lerpf(-2.7, -1.15, sweep) * wind + arm_r * (1.0 - wind), back)
			elb_r = lerpf(elb_r, lerpf(-0.6, -0.15, sweep) * wind, back)
			arm_rz = lerpf(arm_rz, sin(kr * TAU * 1.5) * 0.45 * (1.0 - sweep) * wind, back)
			arm_l = lerpf(arm_l, -1.0 * wind, back)
			elb_l = lerpf(elb_l, -1.1 * wind, back)
			torso_x += (-0.2 * wind * (1.0 - sweep) + 0.3 * sweep) * back
			torso_y += sin(kr * TAU * 1.5) * 0.3 * (1.0 - sweep) * wind * back
			leg_l = lerpf(leg_l, -0.25, back)
			leg_r = lerpf(leg_r, 0.25, back)
	_rot("leg_l", leg_l, 0, leg_lz)
	_rot("leg_r", leg_r, 0, leg_rz)
	_rot("shin_l", knee_l)
	_rot("shin_r", knee_r)
	# feet roll: toes lift as the leg swings forward, push off at the back
	# backing up the foot reaches back and lands on its toes
	_rot("foot_l", clampf(leg_l * 0.3, -0.25, 0.4) - knee_l * 0.35 + back_k * clampf(leg_l * 1.1, 0.0, 0.5))
	_rot("foot_r", clampf(leg_r * 0.3, -0.25, 0.4) - knee_r * 0.35 + back_k * clampf(leg_r * 1.1, 0.0, 0.5))
	_rot("arm_l", arm_l, 0, arm_lz)
	_rot("arm_r", arm_r, 0, arm_rz)
	_rot("forearm_l", elb_l)
	_rot("forearm_r", elb_r)
	var head_x := -(torso_x + body_x) * 0.85 + head_x_extra + head_nod + float(_ba.get("hp", 0.0)) * lw
	if parts.has("torso"):
		var t: Node3D = parts["torso"]
		var hunch: float = float(t.get_meta("hunch", 0.0))
		t.rotation = Vector3(hunch + torso_x, torso_y - body_y * 0.3, torso_z)
	if parts.has("head"):
		var h: Node3D = parts["head"]
		h.rotation = Vector3(head_x, -(torso_y - body_y * 0.3) * 0.7 - body_y * 0.45 * back_k + head_look + (float(_ba.get("hy", 0.0)) - (torso_y - body_y * 0.3)) * lw, -torso_z * 0.5)
	if parts.has("cape"):
		(parts["cape"] as Node3D).rotation.x = 0.15 + amt * 0.4 + run * 0.35 + absf(s) * 0.12 * amt - lean_acc
	body.position = Vector3(sway * 0.012 * idle_k, -0.8 + hop + body_off + sin(_t * 2.0) * 0.008, push)
	body.rotation = Vector3(body_x, body_y, body_z)



func _anim_quad() -> void:
	var s := sin(_phase)
	var amt := minf(_move, 1.0)
	_rot("leg_fl", s * 0.6 * amt)
	_rot("leg_br", s * 0.6 * amt)
	_rot("leg_fr", -s * 0.6 * amt)
	_rot("leg_bl", -s * 0.6 * amt)
	if parts.has("tail"):
		(parts["tail"] as Node3D).rotation.y = sin(_t * 6.0) * 0.4
	if parts.has("head"):
		var h: Node3D = parts["head"]
		var lunge := 0.0
		if _attack_t > 0.0:
			lunge = sin((1.0 - _attack_t / _attack_dur) * PI) * 0.35
		h.position = (_rest["head"] as Vector3) + Vector3(0, 0, lunge)
		h.rotation.x = sin(_phase * 2.0) * 0.06 * amt + lunge * 0.6
	body.position.y = -0.8 + absf(s) * 0.04 * amt


func _anim_blob() -> void:
	var pulse := sin(_t * 3.0) * 0.05 + absf(sin(_phase)) * 0.18 * minf(_move, 1.0)
	var stretch := 0.0
	if _attack_t > 0.0:
		stretch = sin((1.0 - _attack_t / _attack_dur) * PI) * 0.3
	body.scale = Vector3(1.0 + pulse * 0.5 - stretch * 0.3, 1.0 - pulse + stretch, 1.0 + pulse * 0.5 - stretch * 0.3)
	body.position.y = -0.8


func _anim_spider() -> void:
	var amt := minf(_move, 1.0)
	for i in 8:
		var n := "leg%d" % i
		if parts.has(n):
			var side := 1.0 if i < 4 else -1.0
			var ph := _phase + i * 1.3
			(parts[n] as Node3D).rotation = Vector3(0, sin(ph) * 0.35 * amt, side * (0.2 + absf(cos(ph)) * 0.25 * amt))
	body.position.y = -0.8 + absf(sin(_phase * 2.0)) * 0.03 * amt


func _anim_worm() -> void:
	for i in 6:
		var n := "seg%d" % i
		if parts.has(n):
			var p: Node3D = parts[n]
			p.position = (_rest[n] as Vector3) + Vector3(sin(_phase * 0.8 + i * 0.9) * 0.08, absf(sin(_phase * 0.8 + i * 0.9)) * 0.1 * minf(_move, 1.0), 0)


func _anim_float() -> void:
	body.position.y = -0.8 + 0.7 + sin(_t * 2.5) * 0.15
	if parts.has("ring"):
		(parts["ring"] as Node3D).rotation.y = _t * 2.0
	if parts.has("core"):
		(parts["core"] as Node3D).rotation.y = -_t * 1.2
