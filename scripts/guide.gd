class_name Guide
extends Node3D
## The tutorial guide: a tall golden beam and a bobbing diamond over the thing to do next, plus a
## little sparkle that floats above your head and points the way when it's far off.

var main: Node
var _beacon: Node3D
var _beam: MeshInstance3D
var _diamond: MeshInstance3D
var _label: Label3D
var _arrow: Node3D
var _arrow_mesh: MeshInstance3D
var _trail: Array[MeshInstance3D] = []
var _t := 0.0
var _target := {}


func setup(m: Node) -> void:
	main = m
	var gold := StandardMaterial3D.new()
	gold.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gold.albedo_color = Color("ffe08a")
	gold.no_depth_test = true
	var beam_mat := StandardMaterial3D.new()
	beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mat.albedo_color = Color(1.0, 0.88, 0.5, 0.2)
	beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_beacon = Node3D.new()
	add_child(_beacon)
	_beam = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.1
	cm.bottom_radius = 0.35
	cm.height = 16.0
	cm.radial_segments = 8
	_beam.mesh = cm
	_beam.material_override = beam_mat
	_beam.position.y = 8.0
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beacon.add_child(_beam)
	_diamond = MeshInstance3D.new()
	var dm := SphereMesh.new()
	dm.radius = 0.5
	dm.height = 1.0
	dm.radial_segments = 4
	dm.rings = 2
	_diamond.mesh = dm
	_diamond.material_override = gold
	_diamond.scale = Vector3(0.45, 0.75, 0.45)
	_diamond.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beacon.add_child(_diamond)
	_beacon.add_child(_sparkles(0.9, 14, 2.2))
	_label = Label3D.new()
	_label.font = load("res://assets/fonts/Jersey10.ttf")
	_label.font_size = 38
	_label.pixel_size = 0.012
	_label.outline_size = 10
	_label.outline_modulate = Color("0a0810")
	_label.modulate = Color("ffe6a0")
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_beacon.add_child(_label)
	_beacon.visible = false
	# the pointer above the player's head
	_arrow = Node3D.new()
	add_child(_arrow)
	_arrow_mesh = MeshInstance3D.new()
	var am := CylinderMesh.new()
	am.top_radius = 0.0
	am.bottom_radius = 0.17
	am.height = 0.5
	am.radial_segments = 4
	_arrow_mesh.mesh = am
	_arrow_mesh.material_override = gold
	_arrow_mesh.rotation.x = -PI * 0.5
	_arrow_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_arrow.add_child(_arrow_mesh)
	for k in 3:
		var dot := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.09 - k * 0.02
		sm.height = sm.radius * 2.0
		sm.radial_segments = 6
		sm.rings = 3
		dot.mesh = sm
		dot.material_override = gold
		dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(dot)
		_trail.append(dot)
	_arrow.add_child(_sparkles(0.2, 6, 1.0))
	_arrow.visible = false


func _sparkles(radius: float, amount: int, life: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.1, 0.1)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_color = Color("fff0a8")
	mat.no_depth_test = true
	q.material = mat
	p.mesh = q
	p.amount = amount
	p.lifetime = life
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius
	p.direction = Vector3.UP
	p.spread = 30.0
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 0.8
	p.gravity = Vector3(0, 0.2, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


func _process(delta: float) -> void:
	_t += delta
	if main == null or main.mode != "play":
		_beacon.visible = false
		_arrow.visible = false
		for d in _trail:
			d.visible = false
		return
	if Engine.get_process_frames() % 10 == 0 or _target.is_empty():
		_target = main.quests.guide_target()
	var show: bool = not _target.is_empty() and _target["pos"] != Vector3.INF
	_beacon.visible = show
	var show_arrow := false
	if show:
		var tp: Vector3 = _target["pos"]
		var gy: float = main.world.height_at(tp.x, tp.z)
		_beacon.global_position = Vector3(tp.x, gy, tp.z)
		var h: float = _target.get("h", 3.0)
		_diamond.position.y = h + sin(_t * 2.4) * 0.18
		_diamond.rotation.y = _t * 1.6
		_label.text = String(_target.get("label", "")) if h < 4.0 else ""
		_label.position.y = h + 0.95
		var me: Vector3 = main.player.global_position
		var flat := Vector3(tp.x - me.x, 0, tp.z - me.z)
		var dist := flat.length()
		_beam.visible = dist > 9.0
		if dist > 7.0 and not main.ui.dialog_open():
			show_arrow = true
			var dir := flat.normalized()
			var base := me + Vector3(0, 3.1 + sin(_t * 3.0) * 0.07, 0)
			_arrow.global_position = base + dir * (1.2 + sin(_t * 4.0) * 0.08)
			_arrow.look_at(_arrow.global_position + dir, Vector3.UP)
			for k in _trail.size():
				var d := _trail[k]
				d.visible = true
				d.global_position = base + dir * (0.75 - k * 0.2 + sin(_t * 4.0 - k * 0.6) * 0.04)
	_arrow.visible = show_arrow
	if not show_arrow:
		for d in _trail:
			d.visible = false
