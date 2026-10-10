class_name CameraRig
extends Node3D
## World-of-Warcraft style third-person camera.
##  - Left-drag orbits the camera around you without turning the character.
##  - Right-drag is mouselook: the character turns with the camera. Both buttons: run forward.
##  - A short click (no drag) is reported through `clicked` so main can target / interact.
##  - While you walk forward the camera slowly drifts back behind the character (optional).
##  - The wheel zooms from first person out to about 36 m. The boom shortens when walls or
##    hills would be in the way and eases back out afterwards.
## On the title screen it slowly circles the shrine.

signal clicked(button: int)

@export var pitch_degrees := 22.0
@export var distance := 12.0
@export var min_distance := 0.0
@export var max_distance := 36.0
@export var fov := 60.0
@export var min_pitch_degrees := -25.0   # below eye level, looking up
@export var max_pitch_degrees := 85.0    # nearly straight down
@export var drag_sensitivity := 0.006
@export var follow_speed := 0.7          # slow swing back behind you, only while moving forward
var follow_enabled := true               # Settings: turn the swing-back off completely
@export var pivot_height := 1.7
@export var turn_follow := 6.0           # how tightly the view swings round when you turn with A / D (lower = looser)
@export var focus_follow := 16.0         # how tightly the view tracks your position (lower = looser)

const DRAG_START_PX := 5.0

var target: Node3D
var world: World
var focus := Vector3.ZERO
var yaw := 0.0
var target_yaw := 0.0
var orbiting := false             # title-screen fly-around
var input_enabled := true         # main turns this off during dialogs, maps and so on
var shake := 0.0
var lmb := false                  # held, and dragging the camera
var rmb := false                  # held, and steering
var dragging := false             # either button is being used for the camera right now

var camera: Camera3D
var _attrs: CameraAttributesPractical
var _indoor := 0.0
var _zoom := 12.0
var _boom := 12.0                 # distance after collision
var _grab_pos := Vector2.ZERO       # where the cursor was when the drag began
var _held := {}                   # button -> press position (not yet dragging)
var _down := {}                   # button -> still held
var _skip_motion := 0             # ignore the jump the first mouse events make when the cursor gets captured
var _settle := 0.0                # keeps easing round for a moment after you stop turning


func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = fov
	camera.far = 400.0
	camera.near = 0.05
	_attrs = CameraAttributesPractical.new()
	_attrs.dof_blur_far_enabled = true
	_attrs.dof_blur_amount = 0.05
	camera.attributes = _attrs
	add_child(camera)
	_zoom = distance
	_boom = distance


func snap() -> void:
	if target:
		focus = target.global_position
	yaw = target_yaw
	_boom = distance
	_place()


func reset_yaw() -> void:
	yaw = 0.0
	target_yaw = 0.0


## Both buttons held = run forward (read by the player).
var _chord := false


func run_forward() -> bool:
	return (lmb and rmb) or (_down.get(MOUSE_BUTTON_LEFT, false) and _down.get(MOUSE_BUTTON_RIGHT, false))


func _unhandled_input(event: InputEvent) -> void:
	if orbiting or not input_enabled:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN) and get_viewport().gui_get_hovered_control() != null:
			return
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom = maxf(min_distance, _zoom - maxf(0.7, _zoom * 0.12))
			if _zoom < 0.9:
				_zoom = min_distance
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom = minf(max_distance, maxf(_zoom, 0.9) + maxf(0.7, _zoom * 0.12))
		elif mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				if get_viewport().gui_get_hovered_control() != null:
					return
				_held[mb.button_index] = mb.position
				_down[mb.button_index] = true
				if _down.size() >= 2:
					_chord = true   # both buttons together is "run forward", never a click
			else:
				var was_drag: bool = (lmb and mb.button_index == MOUSE_BUTTON_LEFT) or (rmb and mb.button_index == MOUSE_BUTTON_RIGHT)
				var had := _held.has(mb.button_index)
				_held.erase(mb.button_index)
				_down.erase(mb.button_index)
				if mb.button_index == MOUSE_BUTTON_LEFT:
					lmb = false
				else:
					rmb = false
				if not was_drag and had and not _chord:
					clicked.emit(mb.button_index)
				if _down.is_empty():
					_chord = false
				_sync_mouse_mode()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _skip_motion > 0 and dragging:
			_skip_motion -= 1
			return
		if mm.relative.length() > 140.0:
			return   # a recentering jump, not a real flick
		# a held button turns into a drag once the mouse has moved a few pixels
		for b: int in _held.keys():
			if (mm.position - (_held[b] as Vector2)).length() > DRAG_START_PX:
				if not dragging:
					_grab_pos = _held[b] as Vector2
				_held.erase(b)
				if b == MOUSE_BUTTON_LEFT:
					lmb = true
				else:
					rmb = true
				_sync_mouse_mode()
		if lmb or rmb:
			yaw -= mm.relative.x * drag_sensitivity
			target_yaw = yaw
			pitch_degrees = clampf(pitch_degrees + mm.relative.y * drag_sensitivity * 57.3, min_pitch_degrees, max_pitch_degrees)


func _sync_mouse_mode() -> void:
	dragging = lmb or rmb
	if DisplayServer.get_name() == "headless":
		return
	var want := Input.MOUSE_MODE_CAPTURED if dragging else Input.MOUSE_MODE_VISIBLE
	if Input.mouse_mode != want:
		Input.mouse_mode = want
		_skip_motion = 2
		if not dragging:
			# captured mode leaves the cursor in the middle of the screen: put it back where the drag began
			get_viewport().warp_mouse(_grab_pos)
			get_viewport().call_deferred("warp_mouse", _grab_pos)


func release_mouse() -> void:
	lmb = false
	rmb = false
	_held.clear()
	_down.clear()
	_sync_mouse_mode()


func _process(delta: float) -> void:
	if (not input_enabled or orbiting) and (dragging or not _held.is_empty()):
		release_mouse()
	if dragging and DisplayServer.get_name() != "headless" and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		release_mouse()   # button let go while we weren't looking (alt-tab and the like)
	var pl := target as Player
	if orbiting:
		yaw += delta * 0.06
		target_yaw = yaw
	elif pl and not rmb and not lmb and (pl.turning or _settle > 0.0):
		# turning with A / D: the view swings round after you with a little give, then settles
		_settle = 0.6 if pl.turning else _settle - delta
		yaw = lerp_angle(yaw, pl.face_yaw, 1.0 - exp(-delta * turn_follow))
		target_yaw = yaw
	elif pl and follow_enabled and not rmb and not lmb and pl.moving_forward:
		# very slowly drift back behind the character, only while walking forward
		yaw = lerp_angle(yaw, pl.face_yaw, 1.0 - exp(-delta * follow_speed))
		target_yaw = yaw
	if target and not orbiting:
		var tp := target.global_position
		focus.x = lerpf(focus.x, tp.x, 1.0 - exp(-delta * focus_follow))   # a little give so it is not bolted to you
		focus.z = lerpf(focus.z, tp.z, 1.0 - exp(-delta * focus_follow))
		focus.y = lerpf(focus.y, tp.y, 1.0 - exp(-delta * 4.0))   # softer vertically so jumps don't bob the view
	# indoors the camera pulls in (and eases back out when you leave)
	_indoor = lerpf(_indoor, 1.0 if Building.inside_any else 0.0, 1.0 - exp(-delta * 7.0))
	var zoom_goal := lerpf(_zoom, minf(_zoom, 9.0), _indoor)
	var rate := 12.0 if (_indoor < 0.002 or _indoor > 0.998) else 9.0
	distance = lerpf(distance, zoom_goal, 1.0 - exp(-delta * rate))
	shake = maxf(0.0, shake - delta * 2.5)
	_place()
	if pl:
		pl.hide_model = _boom < 1.1 and not orbiting


func _place() -> void:
	# indoors the view tips up a little more, so you look down into the room
	var p := deg_to_rad(minf(pitch_degrees + _indoor * 12.0, max_pitch_degrees))
	var pivot := focus + Vector3(0, pivot_height if not orbiting else 1.0, 0)
	var fwd := Vector3(0, -sin(p), -cos(p)).rotated(Vector3.UP, yaw)   # where the camera looks
	var want := distance
	# pull the boom in when something solid is behind us; ease back out slowly
	var clear := _clear_distance(pivot, -fwd, distance)
	if clear < _boom:
		_boom = clear
	else:
		_boom = minf(clear, lerpf(_boom, clear, 0.08))
	var d := minf(_boom, want)
	var pos := pivot - fwd * d
	# never dip under the ground
	if world:
		var g := world.height_at(pos.x, pos.z) + 0.35
		if pos.y < g:
			pos.y = g
	global_position = pivot
	var jitter := Vector3.ZERO
	if shake > 0.0:
		jitter = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * shake * 0.35
	camera.global_position = pos + jitter
	if pos.distance_to(pivot) > 0.5:
		camera.look_at(pivot + jitter, Vector3.UP)
	else:
		camera.global_basis = Basis.from_euler(Vector3(-p, yaw, 0))
	_attrs.dof_blur_far_distance = maxf(distance, 8.0) + 30.0
	_attrs.dof_blur_far_transition = 40.0


## How far back along `dir` the camera can go before it hits terrain or a building.
func _clear_distance(pivot: Vector3, dir: Vector3, max_d: float) -> float:
	if max_d < 0.2 or not is_inside_tree() or orbiting:
		return max_d
	var space := get_world_3d().direct_space_state
	if space == null:
		return max_d
	var q := PhysicsRayQueryParameters3D.create(pivot, pivot + dir * (max_d + 0.3), 1 | 16)
	q.exclude = Building.cam_exclude
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return max_d
	return maxf(0.0, pivot.distance_to(hit["position"] as Vector3) - 0.3)
