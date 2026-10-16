@tool
class_name Door
extends Node3D
## A hinged door. "auto" doors swing open when anyone (the player or a villager) walks up and
## close again once they leave; "open" doors stay propped open. The solid part switches off while
## the door is swinging so nobody gets pushed around. Doors open away from whoever opens them.

var door_w := 1.0
var door_h := 2.0
var mode := "auto"
var mirror := false          # hinged on the right instead of the left
var hinge: Node3D
var shape: CollisionShape3D
var openness := 0.0
var _side := 1.0             # +1 swings outwards (towards +Z), -1 inwards
var _want := false


func _ready() -> void:
	add_to_group("doors")
	if mode == "open":
		openness = 1.0
		_apply()
		set_process(false)


func _process(delta: float) -> void:
	var near := false
	var thr := 3.0 if _want else 2.1
	var first_z := 0.0
	for u: Node in get_tree().get_nodes_in_group("door_users"):
		var l := to_local((u as Node3D).global_position)
		if Vector2(l.x, l.z).length() < thr and absf(l.y) < 2.5:
			if not near:
				first_z = l.z
			near = true
	if near and not _want:
		_side = 1.0 if first_z > 0.0 else -1.0
		Sfx.play("ui_open", global_position, -14.0, 0.15)
	elif _want and not near:
		Sfx.play("ui_close", global_position, -16.0, 0.15)
	_want = near
	var target := 1.0 if _want else 0.0
	if not is_equal_approx(openness, target):
		openness = move_toward(openness, target, delta * 3.0)
		_apply()


func _apply() -> void:
	var s := 1.0 if mirror else -1.0
	hinge.rotation.y = s * _side * openness * 1.75
	if shape:
		shape.set_deferred("disabled", openness > 0.15)
