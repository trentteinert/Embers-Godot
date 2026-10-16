class_name RemotePlayer
extends Node3D
## Another player in the online world: a geared hero model with a name tag, smoothed between server updates.

var rig: Rig
var tag: Label3D
var class_id := "warrior"
var target_pos := Vector3.ZERO
var face := Vector3(0, 0, 1)
var player_name := ""
var dead := false
var air := false
var buffs: Array = []
var _last := Vector3.ZERO
var _attack_t := 0.0
var work := ""   # the skilling pose (chop, mine, fish, cook ...) the server says they are in


func setup(id: String, pname: String, equip: Dictionary) -> void:
	class_id = id
	player_name = pname
	tag = Label3D.new()
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	tag.pixel_size = 0.012
	tag.font_size = 40
	tag.outline_size = 8
	tag.position.y = 2.9
	tag.modulate = Color("f1e8d4")
	add_child(tag)
	set_gear(equip)
	set_text(1, 1.0, 1.0)


var _equip := {}


## Rebuild the model from the last gear (used when the character style is switched).
func rebuild() -> void:
	set_gear(_equip)


func set_gear(equip: Dictionary) -> void:
	_equip = equip
	if rig != null:
		rig.queue_free()
	rig = Models.hero_geared(class_id, equip)
	rig.scale = Vector3.ONE * Player.MODEL_SCALE
	add_child(rig)
	rig.set_facing(face, true)


func set_text(level: int, hp: float, max_hp: float) -> void:
	tag.text = "%s  L%d\n%d/%d" % [player_name, level, int(hp), int(max_hp)]


func apply(v: Dictionary, world: World) -> void:
	var x: float = float(v["pos"][0])
	var z: float = float(v["pos"][1])
	target_pos = Vector3(x, float(v["y"]) + (world.height_at(x, z) - world.grid_height_at(x, z)) + 0.02, z)
	var aim := Vector3(float(v["aim"][0]), 0, float(v["aim"][1]))
	if aim.length() > 0.1:
		face = aim.normalized()
	dead = bool(v["dead"])
	air = bool(v.get("air", false))
	work = str(v.get("work", ""))
	buffs = v["buffs"]
	set_text(int(v["level"]), float(v["hp"]), float(v["max_hp"]))
	if global_position.distance_to(target_pos) > 8.0:
		global_position = target_pos
		_last = target_pos


func play_attack(cast: bool) -> void:
	if rig == null:
		return
	rig.set_armed(true, true)
	_attack_t = 4.0
	if cast:
		rig.cast(0.4)
	else:
		rig.attack(0.3)


func _process(delta: float) -> void:
	if rig == null:
		return
	global_position = global_position.lerp(target_pos, clampf(delta * 12.0, 0.0, 1.0))
	var step: Vector3 = global_position - _last
	step.y = 0.0
	_last = global_position
	var speed: float = step.length() / maxf(delta, 0.001)
	rig.set_facing(face)
	_attack_t -= delta
	rig.set_armed(_attack_t > 0.0)
	rig.set_work(work)
	rig.set_alpha(0.35 if "stealth" in buffs else 1.0)
	rig.visible = not dead
	rig.air = move_toward(rig.air, 1.0 if air else 0.0, delta * 9.0)
	rig.tick(delta, clampf(speed / 4.6, 0.0, 1.6))
