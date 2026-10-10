extends Node3D
## Open scenes/asset_gallery.tscn and press F6 to walk around every town asset in every region style.
## WASD / arrows fly, hold right or middle mouse and drag to look, wheel = speed, Q/E down/up.
## Rows: one per region style. Further back: a village and a camp for each style.

var cam: Camera3D
var _speed := 14.0
var _yaw := 0.0
var _pitch := -0.45
var _spin: Array[Node] = []


func _ready() -> void:
	RenderingServer.global_shader_parameter_set("player_pos", Vector3(0, -999, 0))
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("9ec4dc")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.62, 0.62, 0.68)
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.85, 0.55, 0)
	sun.shadow_enabled = true
	sun.light_energy = 1.1
	add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(900, 900)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("6a9a4c")
	ground.material_override = gm
	add_child(ground)
	var styles := TownKit.STYLES.keys()
	var all: Array = TownKit.BUILDINGS + TownKit.DEFENSES + TownKit.PROPS
	for si in styles.size():
		var st: String = styles[si]
		var z := -si * 22.0
		_label("%s" % st.to_upper(), Vector3(-16, 3, z), 64, Color("ffd27a"))
		var x := 0.0
		for kind: String in all:
			var r := TownKit.footprint(kind)
			x += r + 1.5
			var n := TownKit.build(kind, st, si)
			n.position = Vector3(x, 0, z)
			add_child(n)
			_label(kind, Vector3(x, 0.2, z + r + 1.2), 26, Color.WHITE)
			x += r + 1.5
	for si in styles.size():
		var st2: String = styles[si]
		var v := TownKit.village(st2, 10 + si)
		v.position = Vector3(si * 110.0, 0, 120.0)
		add_child(v)
		_label("%s village" % st2, v.position + Vector3(0, 14, 0), 90, Color("ffd27a"))
		var c := TownKit.camp(st2, 5 + si, ["hunters", "bandits", "pilgrims", "hunters"][si])
		c.position = Vector3(si * 110.0, 0, 210.0)
		add_child(c)
		_label("%s camp" % st2, c.position + Vector3(0, 8, 0), 70, Color("ffd27a"))
	cam = Camera3D.new()
	cam.far = 600.0
	cam.position = Vector3(30, 22, 36)
	add_child(cam)
	_spin = get_tree().get_nodes_in_group("spin")


func _label(t: String, p: Vector3, size: int, col: Color) -> void:
	var l := Label3D.new()
	l.text = t
	l.font_size = size
	l.pixel_size = 0.01
	l.outline_size = 10
	l.modulate = col
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = p
	add_child(l)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and (event.button_mask & (MOUSE_BUTTON_MASK_RIGHT | MOUSE_BUTTON_MASK_MIDDLE)):
		_yaw -= event.relative.x * 0.005
		_pitch = clampf(_pitch - event.relative.y * 0.005, -1.4, 1.2)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_speed = minf(_speed * 1.2, 120.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_speed = maxf(_speed / 1.2, 3.0)


func _process(delta: float) -> void:
	for n in _spin:
		(n as Node3D).rotation.z += delta * 0.6
	if cam == null:
		return
	cam.rotation = Vector3(_pitch, _yaw, 0)
	var mv := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		mv.z -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		mv.z += 1
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		mv.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		mv.x += 1
	if Input.is_physical_key_pressed(KEY_E):
		mv.y += 1
	if Input.is_physical_key_pressed(KEY_Q):
		mv.y -= 1
	cam.position += cam.global_basis * mv * _speed * delta
