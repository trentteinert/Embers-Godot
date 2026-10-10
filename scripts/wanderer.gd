class_name Wanderer
extends RefCounted
## Makes a villager stroll around a home point: walk to a random spot nearby, stand for a bit,
## repeat. Spots are only picked when the straight path is clear of walls, furniture and water.
## They stop and face you when you walk up, so talking to them is easy.

var home := Vector3.ZERO
var radius := 4.0
var speed := 1.4
var pos := Vector3.ZERO
var _target := Vector3.INF
var _wait := 0.0
var _rng := RandomNumberGenerator.new()
var moving := false


func _init(home_pos: Vector3, r: float, seed_v := 0) -> void:
	home = home_pos
	pos = home_pos
	radius = r
	_rng.seed = seed_v
	_wait = _rng.randf_range(0.5, 4.0)


## Advances one frame. world: the World, space: a node in the scene (for ray queries).
## stop: true while the player is near / talking. Returns the movement direction (zero if standing).
func step(delta: float, world: World, space_node: Node3D, stop: bool) -> Vector3:
	moving = false
	if stop:
		return Vector3.ZERO
	if _target == Vector3.INF:
		_wait -= delta
		if _wait <= 0.0:
			_pick(world, space_node)
		return Vector3.ZERO
	var to := _target - pos
	to.y = 0.0
	var dist := to.length()
	if dist < 0.15:
		_target = Vector3.INF
		_wait = _rng.randf_range(2.0, 7.0)
		return Vector3.ZERO
	var dir := to / dist
	# a quick look ahead, so a door that is shut or someone in the way makes us pick again
	if _blocked(space_node, pos, pos + dir * minf(dist, 0.8)):
		_target = Vector3.INF
		_wait = 0.6
		return Vector3.ZERO
	pos += dir * minf(dist, speed * delta)
	pos.y = world.height_at(pos.x, pos.z)
	moving = true
	return dir


func _pick(world: World, space_node: Node3D) -> void:
	for i in 10:
		var a := _rng.randf() * TAU
		var d := sqrt(_rng.randf()) * radius
		var p := home + Vector3(cos(a) * d, 0, sin(a) * d)
		p.y = world.height_at(p.x, p.z)
		if world.is_water(p.x, p.z) or absf(p.y - home.y) > 1.2:
			continue
		if _blocked(space_node, pos, p):
			continue
		_target = p
		return
	_wait = 1.5


func _blocked(space_node: Node3D, a: Vector3, b: Vector3) -> bool:
	var space := space_node.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(a + Vector3(0, 0.9, 0), b + Vector3(0, 0.9, 0), 2 | 16)
	return not space.intersect_ray(q).is_empty()
