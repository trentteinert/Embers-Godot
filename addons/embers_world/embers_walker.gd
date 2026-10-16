@tool
class_name EmbersWalker
extends CharacterBody3D
## Drop one of these in your world scene, press F6 (Run Current Scene) and run around it: WASD to move, Shift to
## sprint, Space to jump, hold the right mouse button and drag to look, mouse wheel to zoom. It starts at your
## Spawn point. Use it to check the ground, buildings, stairs and upper floors feel right before the server
## ever sees them. (It uses Godot's physics, not the server's: the server's rules are checked by the export.)

@export var speed := 7.0
@export var sprint_mult := 1.6
@export var jump_speed := 6.5
@export var show_model := true

var move_input := Vector2.ZERO   # for tests; the keyboard sets it every frame otherwise
var _yaw := 0.0
var _pitch := -0.35
var _dist := 7.0
var _cam: Camera3D
var _t := 0.0
var _model: Node3D
var _spawn := Vector3(0, 10, 0)
var _terrain: Node
var _grounded_t := 0.0


func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray()   # the collision shape is added when the scene runs


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if OS.get_cmdline_user_args().has("--world"):
		queue_free()   # playing the real game on this world: the game has its own player and camera
		return
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	add_child(cs)
	floor_snap_length = 0.5
	collision_mask = 3   # layer 1 (ground) and layer 2 (the game puts building walls, floors and stairs there)
	_cam = Camera3D.new()
	_cam.current = true
	get_parent().add_child.call_deferred(_cam)
	_find_spawn(get_tree().current_scene if get_tree().current_scene else get_parent())
	_terrain = _find_terrain(get_tree().current_scene if get_tree().current_scene else get_parent())
	var gh := _ground(_spawn.x, _spawn.z)
	if is_nan(gh):
		if _terrain != null:
			push_warning("EmbersWalker: there is no terrain under the Spawn point. Click the Terrain3D node with the Region tool and add a region there, or move the Spawn point onto the terrain.")
		gh = _spawn.y
	global_position = Vector3(_spawn.x, gh + 0.5, _spawn.z)
	if show_model:
		_model = EmbersProp.make(EmbersProp.Category.NPC, "warrior")
		if _model != null:
			add_child(_model)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	if get_tree().get_nodes_in_group("embers_sun").is_empty() and not _has_light(get_parent()):
		get_parent().add_child.call_deferred(sun)


func _find_terrain(n: Node) -> Node:
	if n.get_class() == "Terrain3D" or n.is_class("Terrain3D"):
		return n
	for c in n.get_children():
		var f := _find_terrain(c)
		if f != null:
			return f
	return null


## Height of Terrain3D's ground at (x, z), or NAN if there is none. Read from the terrain data, so you
## stand on it even before (or without) its physics collision.
func _ground(x: float, z: float) -> float:
	if _terrain == null or not ("data" in _terrain) or _terrain.data == null:
		return NAN
	return _terrain.data.get_height(Vector3(x, 0, z))


func _has_light(n: Node) -> bool:
	if n is DirectionalLight3D:
		return true
	for c in n.get_children():
		if _has_light(c):
			return true
	return false


func _find_spawn(n: Node) -> void:
	if n is EmbersPoint and (n as EmbersPoint).kind == EmbersPoint.Kind.SPAWN:
		_spawn = (n as EmbersPoint).global_position
		return
	for c in n.get_children():
		_find_spawn(c)


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_yaw -= e.relative.x * 0.005
		_pitch = clampf(_pitch - e.relative.y * 0.005, -1.3, 0.4)
	elif e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP:
			_dist = maxf(2.0, _dist - 0.7)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_dist = minf(25.0, _dist + 0.7)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_t += delta
	var dir := move_input
	if dir == Vector2.ZERO:
		dir = Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	var sprint := Input.is_physical_key_pressed(KEY_SHIFT)
	var basis_y := Basis(Vector3.UP, _yaw)
	var wish := (basis_y * Vector3(dir.x, 0, dir.y)).normalized() * (speed * (sprint_mult if sprint else 1.0)) if dir.length() > 0.01 else Vector3.ZERO
	velocity.x = wish.x
	velocity.z = wish.z
	if _t < 0.6:
		velocity.y = 0.0   # wait for the terrain's collision to appear under us
	elif is_on_floor() or _grounded_t < 0.1:
		velocity.y = jump_speed if Input.is_physical_key_pressed(KEY_SPACE) else -1.0
	else:
		velocity.y -= 22.0 * delta
	move_and_slide()
	var gh := _ground(global_position.x, global_position.z)
	var on_ground := is_on_floor()
	if not is_nan(gh) and global_position.y <= gh + 0.05 and velocity.y <= 0.0:
		global_position.y = gh
		velocity.y = 0.0
		on_ground = true
	if on_ground:
		_grounded_t = 0.0
	else:
		_grounded_t += delta
	if global_position.y < -80.0:
		global_position = _spawn + Vector3(0, 3, 0)
		velocity = Vector3.ZERO
	if wish.length() > 0.1 and _model != null:
		_model.rotation.y = lerp_angle(_model.rotation.y, atan2(wish.x, wish.z), clampf(delta * 12.0, 0.0, 1.0))
	if _cam != null and _cam.is_inside_tree():
		var focus := global_position + Vector3(0, 1.5, 0)
		var offset := Basis(Vector3.UP, _yaw) * Basis(Vector3.RIGHT, _pitch) * Vector3(0, 0, _dist)
		_cam.global_position = focus + offset
		_cam.look_at(focus)
