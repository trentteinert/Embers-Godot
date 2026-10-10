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
var _cast_t := 0.0
var _cast_dur := 0.4
var _flash_t := 0.0
var _flashing := false
var _tint := Color.WHITE
var _alpha := 1.0
var _yaw := 0.0
var _target_yaw := 0.0
var _rest := {}              # part name -> resting position
var _t := 0.0
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
		"shield":
			mount = Transform3D(Basis.from_euler(Vector3(PI * 0.5, 0, 0)), Vector3(0, 0.3, -0.24))
		_:
			mount = Transform3D(Basis.from_euler(Vector3(-0.08, 0, 0.85 * side)), Vector3(-0.05 * side, 0.1, -0.2))
	_weapons.append({"node": n, "home": home, "home_xf": n.transform, "mount_xf": mount})


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


func attack(dur := 0.25) -> void:
	_attack_t = dur
	_attack_dur = dur


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


func _anim_humanoid() -> void:
	var s := sin(_phase)
	var c := cos(_phase)
	var amt := minf(_move, 1.0)
	var run := clampf(_move - 1.0, 0.0, 0.5) * 2.0     # 0 walking .. 1 sprinting
	var fem := 1.0 if get_meta("femme", false) else 0.0
	var swing := (0.7 + 0.25 * run) * (1.0 - 0.1 * fem)
	var leg_l := s * swing * amt
	var leg_r := -s * swing * amt
	# knees fold while the leg swings forward, and the foot lifts
	var knee_l := maxf(0.0, -c) * (0.9 + 0.5 * run) * amt
	var knee_r := maxf(0.0, c) * (0.9 + 0.5 * run) * amt
	var arm_l := -s * (0.55 + 0.25 * run) * amt
	var arm_r := s * (0.55 + 0.25 * run) * amt
	# elbows stay a little bent, and bend more as the arm comes forward
	var elb_l := -(0.12 + (0.25 + 0.5 * run) * maxf(0.0, s)) * (0.4 + 0.6 * amt)
	var elb_r := -(0.12 + (0.25 + 0.5 * run) * maxf(0.0, -s)) * (0.4 + 0.6 * amt)
	var arm_lz := 0.04
	var arm_rz := -0.04
	if air > 0.0:
		# jump pose: one knee forward, one leg tucked back, arms out
		leg_l = lerpf(leg_l, -0.9, air)
		leg_r = lerpf(leg_r, 0.5, air)
		knee_l = lerpf(knee_l, 0.9, air)
		knee_r = lerpf(knee_r, 1.1, air)
		arm_l = lerpf(arm_l, -0.5, air)
		arm_r = lerpf(arm_r, -0.5, air)
		elb_l = lerpf(elb_l, -0.5, air)
		elb_r = lerpf(elb_r, -0.5, air)
		arm_lz = lerpf(arm_lz, -0.6, air)
		arm_rz = lerpf(arm_rz, 0.6, air)
	var torso_y := -s * 0.14 * amt * (1.0 - air)      # shoulders counter-twist against the hips
	var torso_x := 0.07 * amt + 0.08 * run - 0.05 * air
	var head_x := -torso_x * 0.8
	if _attack_t > 0.0:
		var k := 1.0 - _attack_t / _attack_dur
		var e := 1.0 - pow(1.0 - k, 3.0)
		# wind up, then strike: the arm snaps from raised and bent to straight
		arm_r = lerpf(-2.7, -0.4, e)
		elb_r = lerpf(-1.3, -0.1, e)
		torso_y = lerpf(0.4, -0.35, e)
		torso_x += sin(k * PI) * 0.12
		elb_l = -0.7
		arm_l = lerpf(arm_l, -0.5, 0.6)
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
		match work_kind:
			"chop", "mine", "smith":
				var amp := 0.85 if work_kind == "smith" else 1.0
				if u < 0.5:
					var k := u / 0.5
					var e := 1.0 - pow(1.0 - k, 2.0)
					a_r = lerpf(-0.9, -2.8 * amp, e)
					e_r = lerpf(-0.5, -1.3, e)
					tx = -0.12 * e
					ty = 0.1 * e
				elif u < 0.62:
					var k := (u - 0.5) / 0.12
					a_r = lerpf(-2.8 * amp, -0.45, k * k)
					e_r = lerpf(-1.3, -0.15, k)
					tx = lerpf(-0.12, 0.38, k)
					ty = lerpf(0.1, -0.2, k)
				else:
					var k := (u - 0.62) / 0.38
					a_r = lerpf(-0.45, -0.9, k)
					e_r = lerpf(-0.15, -0.5, k)
					tx = lerpf(0.38, 0.0, k)
					ty = lerpf(-0.2, 0.0, k)
				a_l = a_r * 0.92
				e_l = e_r
			"gather":
				tx = 0.75 + sin(_work_t * 4.0) * 0.06
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
				tx = -0.04
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
		head_x -= tx * wt * 0.6
	if _cast_t > 0.0:
		var k2 := 1.0 - _cast_t / _cast_dur
		var up := sin(k2 * PI)
		arm_l = -2.3 * up
		arm_r = -2.3 * up
		elb_l = -0.5 * up
		elb_r = -0.5 * up
		arm_lz = -0.3 * up
		arm_rz = 0.3 * up
		torso_x -= 0.1 * up
	_rot("leg_l", leg_l)
	_rot("leg_r", leg_r)
	_rot("shin_l", knee_l)
	_rot("shin_r", knee_r)
	_rot("arm_l", arm_l, 0, arm_lz)
	_rot("arm_r", arm_r, 0, arm_rz)
	_rot("forearm_l", elb_l)
	_rot("forearm_r", elb_r)
	if parts.has("torso"):
		var t: Node3D = parts["torso"]
		var hunch: float = float(t.get_meta("hunch", 0.0))
		t.rotation = Vector3(hunch + torso_x + sin(_t * 1.8) * 0.012, torso_y, sin(_phase) * 0.03 * amt * (1.0 + fem * 1.0))
	if parts.has("head"):
		var h: Node3D = parts["head"]
		h.rotation = Vector3(head_x + sin(_t * 1.3) * 0.015, -torso_y * 0.6, 0)
	if parts.has("cape"):
		(parts["cape"] as Node3D).rotation.x = 0.15 + amt * 0.35 + run * 0.3 + absf(s) * 0.1 * amt
	body.position.y = -0.8 + absf(s) * 0.06 * amt * (1.0 - air) + sin(_t * 2.0) * 0.008
	body.rotation.z = s * 0.025 * amt * (1.0 - air) * (1.0 + fem * 1.2)


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
