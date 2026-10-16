@tool
class_name EmbersRegion
extends Node3D
## A rectangle on the ground that says what is there: which area (biome, so which monsters and plants),
## what the ground is made of, and which named zone it belongs to. Later (higher priority) regions win.

@export var size := Vector2(200, 200): set = _set_size
@export_enum("Meadow", "Thornwood", "Mire", "Frostspine", "Coast") var biome := 0: set = _set_biome
## "Keep" leaves the ground to the default (and to water/beach rules).
@export_enum("Keep", "Water", "Sand", "Grass", "Forest", "Mud", "Bog", "Snow", "Rock") var ground := 0
## Named area (shows in the zone banner and sets monster levels). None = just the biome.
@export_enum("None", "campwater", "tallowfields", "hearthmoor", "brackenwood", "blackbriar", "saltfen", "bellwater", "greyfold", "frostspine") var zone := 0
@export var priority := 0

const COLORS := [Color("6ab050"), Color("2f7a4a"), Color("7a6a9a"), Color("9fd0e8"), Color("e0d08a")]
var _vis: MeshInstance3D


func _set_size(v: Vector2) -> void:
	size = v
	_refresh()


func _set_biome(v: int) -> void:
	biome = v
	_refresh()


func _ready() -> void:
	_refresh()


func _refresh() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	if _vis == null:
		_vis = MeshInstance3D.new()
		_vis.name = "_preview"
		add_child(_vis)   # no owner, so it is never saved
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_vis.material_override = m
	var q := PlaneMesh.new()
	q.size = size
	_vis.mesh = q
	_vis.position.y = 0.3
	var c: Color = COLORS[clampi(biome, 0, 4)]
	c.a = 0.25
	(_vis.material_override as StandardMaterial3D).albedo_color = c


## Is the ground point (x, z) inside this rectangle?
func covers(x: float, z: float) -> bool:
	var d := Vector3(x, 0, z) - Vector3(global_position.x, 0, global_position.z)
	var yaw := global_rotation.y
	var lx := d.x * cos(yaw) - d.z * sin(yaw)
	var lz := d.x * sin(yaw) + d.z * cos(yaw)
	return absf(lx) <= size.x * 0.5 * global_transform.basis.x.length() and absf(lz) <= size.y * 0.5 * global_transform.basis.z.length()
