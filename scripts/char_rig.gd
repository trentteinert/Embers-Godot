@tool
class_name CharRig
extends Rig
## A player character made from a skinned model (characters/*.fbx, a Mixamo skeleton) instead of the game's block parts. It is a Rig, so
## everything that drives a Rig (walking, attacking, casting, jumping, tints, flashes, work poses, online players) works unchanged; the
## animations are Mixamo clips played by an AnimationPlayer instead of the procedural ones.
## characters/idle.fbx holds the model; walk, run, jump, attack and cast hold one clip each (their model is ignored).

const DIR := "res://characters/"
const MODEL_FILE := "idle.fbx"
const CLIP_FILES := {"idle": "idle.fbx", "walk": "walk.fbx", "run": "run.fbx", "jump": "jump.fbx", "attack": "attack.fbx", "cast": "cast.fbx",
	"walk_back": "walk_back.fbx",
	# the sword-and-shield set, used while a weapon is drawn (all optional: a missing one falls back to the plain clip)
	"idle_armed": "idle_armed.fbx", "walk_armed": "walk_armed.fbx", "walk_back_armed": "walk_back_armed.fbx", "run_armed": "run_armed.fbx",
	"run_back_armed": "run_back_armed.fbx", "strafe_l_armed": "strafe_l_armed.fbx", "strafe_r_armed": "strafe_r_armed.fbx", "jump_armed": "jump_armed.fbx",
	"attack_armed": "attack_armed.fbx", "attack_armed_2": "attack_armed_2.fbx", "attack_armed_3": "attack_armed_3.fbx", "attack_armed_4": "attack_armed_4.fbx",
	"cast_armed": "cast_armed.fbx"}
const LOOPING := ["idle", "walk", "run", "walk_back", "idle_armed", "walk_armed", "walk_back_armed", "run_armed", "run_back_armed", "strafe_l_armed", "strafe_r_armed"]
const ATTACKS_ARMED := ["attack_armed", "attack_armed_2", "attack_armed_3", "attack_armed_4"]
# how fast each travelling clip moves (m/s, model size), from its root motion; the travel is taken out and the speed matched to the character
const CLIP_SPEED := {"walk": 1.96, "run": 3.45, "walk_back": 0.61, "walk_armed": 1.65, "walk_back_armed": 1.24, "run_armed": 4.54, "run_back_armed": 4.85, "strafe_l_armed": 1.15, "strafe_r_armed": 1.35}
const MODEL_HEIGHT := 1.88            # the model, in metres, as exported
const BODY_HEIGHT := 1.84             # how tall the character stands (the block characters are 1.6 but chunkier; the player scales every Rig by 1.25 on top)
const WEAPON_SCALE := 1.1             # weapons and tools, relative to the block characters'
const WEAPON_PITCH := -0.35           # tip a held weapon up from pointing straight ahead (radians)
const ROLL_R := -0.47                 # turn the right hand's grip so a held weapon points forward, not across the body
const ROLL_L := 0.47
const FULL_SPEED := 4.6               # world speed that tick(move = 1.0) stands for

static var _said := false
static var _anims := {}               # clip name -> Animation, prepared once

var _model: Node3D
var _skel: Skeleton3D
var _ap: AnimationPlayer
var _cur := ""
var _one_shot := 0.0                  # seconds left of an attack or cast clip
var _last_pos := Vector3.ZERO
var _have_last := false
var _move_fwd := 1.0
var _move_side := 0.0


const SETTINGS := "user://character.cfg"


## Which characters to show: the block characters (default) or the new skinned one. F8 in the game switches and remembers.
static func enabled() -> bool:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS) != OK:
		return false
	return bool(cf.get_value("character", "use_new", false))


static func set_enabled(on: bool) -> void:
	var cf := ConfigFile.new()
	cf.load(SETTINGS)
	cf.set_value("character", "use_new", on)
	cf.save(SETTINGS)
	_said = false


static func available() -> bool:
	return enabled() and ResourceLoader.exists(DIR + MODEL_FILE)


## Builds the character for a hero config (see Models.hero_geared), or null when the model files are not in the game.
static func try_build(cfg: Dictionary) -> Rig:
	if not available():
		if not _said:
			_said = true
			if not enabled():
				print("CharRig: off (block characters). Press F8 in the game to try the new character.")
			else:
				print("CharRig: res://characters/idle.fbx is not imported, using the block character. Open the project in the Godot editor once so it imports the files.")
		return null
	_prepare()
	if _anims.is_empty():
		if not _said:
			_said = true
			print("CharRig: no animation clips could be read from res://characters/, using the block character.")
		return null
	if not _said:
		_said = true
		print("CharRig: using the new character (clips: ", ", ".join(PackedStringArray(_anims.keys())), ")")
	var r := CharRig.new()
	r.kind = "skinned"
	r.height = BODY_HEIGHT
	r._setup(cfg)
	return r


static func _prepare() -> void:
	if not _anims.is_empty():
		return
	for clip: String in CLIP_FILES:
		var path: String = DIR + String(CLIP_FILES[clip])
		if not ResourceLoader.exists(path):
			continue
		var inst: Node = (load(path) as PackedScene).instantiate()
		var ap: AnimationPlayer = inst.find_child("AnimationPlayer", true, false)
		if ap != null:
			var names := ap.get_animation_list()
			if names.size() > 0:
				var a: Animation = ap.get_animation(names[0]).duplicate()
				a.loop_mode = Animation.LOOP_LINEAR if clip in LOOPING else Animation.LOOP_NONE
				if CLIP_SPEED.has(clip):
					_in_place(a, 0 if clip.begins_with("strafe") else 2)
				_anims[clip] = a
		inst.free()


## The walk and run clips travel forward; the game moves the character itself, so take that travel out of the hips.
static func _in_place(a: Animation, axis: int) -> void:
	var t := a.find_track(NodePath("Skeleton3D:mixamorig_Hips"), Animation.TYPE_POSITION_3D)
	if t < 0:
		return
	var first: Vector3 = a.track_get_key_value(t, 0)
	for k in a.track_get_key_count(t):
		var v: Vector3 = a.track_get_key_value(t, k)
		v[axis] = first[axis]
		a.track_set_key_value(t, k, v)


func _setup(cfg: Dictionary) -> void:
	_model = (load(DIR + MODEL_FILE) as PackedScene).instantiate() as Node3D
	_model.scale = Vector3.ONE * (BODY_HEIGHT / MODEL_HEIGHT)
	body.add_child(_model)
	_skel = _model.find_child("Skeleton3D", true, false) as Skeleton3D
	_ap = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _ap != null:
		for lib: StringName in _ap.get_animation_library_list():
			_ap.remove_animation_library(lib)
		var lib := AnimationLibrary.new()
		for clip: String in _anims:
			lib.add_animation(clip, _anims[clip])
		_ap.add_animation_library("", lib)
		_ap.playback_default_blend_time = 0.18
		_ap.play("idle")
		_cur = "idle"
	if _skel != null:
		for mi: Node in _skel.get_children():
			if mi is MeshInstance3D:
				_paint(mi as MeshInstance3D, cfg)
		# the hand and body spots the rest of the game attaches things to (weapons, tools), in the block characters' orientation
		var hand_r := Basis(Vector3(0, 0, 1), Vector3(0, -1, 0), Vector3(1, 0, 0)) * Basis(Vector3.UP, ROLL_R)
		var hand_l := Basis(Vector3(0, 0, -1), Vector3(0, -1, 0), Vector3(-1, 0, 0)) * Basis(Vector3.UP, ROLL_L)
		var unscale := Vector3.ONE * (MODEL_HEIGHT / BODY_HEIGHT) * WEAPON_SCALE   # things built for the block characters keep their size
		_attach("hand_r", "mixamorig_RightHand", Transform3D(hand_r.scaled(unscale), Vector3.ZERO))
		_attach("hand_l", "mixamorig_LeftHand", Transform3D(hand_l.scaled(unscale), Vector3.ZERO))
		_attach("arm_l", "mixamorig_LeftArm", Transform3D(Basis(Vector3(0, 0, -1), Vector3(0, -1, 0), Vector3(-1, 0, 0)).scaled(unscale), Vector3.ZERO))
		_attach("arm_r", "mixamorig_RightArm", Transform3D(Basis(Vector3(0, 0, 1), Vector3(0, -1, 0), Vector3(1, 0, 0)).scaled(unscale), Vector3.ZERO))
		_attach("torso", "mixamorig_Spine2", Transform3D(Basis.IDENTITY.scaled(unscale), Vector3.ZERO))
		_attach("head", "mixamorig_Head", Transform3D(Basis.IDENTITY.scaled(unscale), Vector3.ZERO))
	for side in [-1, 1]:
		var w: String = cfg.get("weapon_l" if side < 0 else "weapon_r", "")
		if w != "" and parts.has("hand_l" if side < 0 else "hand_r"):
			Models._weapon(self, parts["hand_l" if side < 0 else "hand_r"], parts["arm_l" if side < 0 else "arm_r"], w, cfg, side)
	# a weapon in the fist is tipped up a little, not held straight out
	for wd: Dictionary in _weapons:
		if wd["home"] == parts.get("hand_r") or wd["home"] == parts.get("hand_l"):
			var xf: Transform3D = wd["home_xf"]
			xf.basis = Basis(Vector3.RIGHT, WEAPON_PITCH) * xf.basis
			wd["home_xf"] = xf
			(wd["node"] as Node3D).transform = xf


func _attach(part: String, bone: String, xf: Transform3D) -> void:
	if _skel.find_bone(bone) < 0:
		return
	var ba := BoneAttachment3D.new()
	ba.bone_name = bone
	_skel.add_child(ba)
	var holder := Node3D.new()
	holder.transform = xf
	ba.add_child(holder)
	add_part(part, holder)


## Colours: the model's materials are named skin, underwear, eyes and mouth; each gets this character's colour.
func _paint(mi: MeshInstance3D, cfg: Dictionary) -> void:
	if mi.mesh == null:
		return
	mi.custom_aabb = AABB(Vector3(-100, -100, -100), Vector3(200, 200, 200))   # a skinned mesh's own bounds are tiny: never cull it
	var skin := Color(String(cfg.get("skin", "e8b48a")))
	for s in mi.mesh.get_surface_count():
		var src := mi.mesh.surface_get_material(s)
		var nm := String(src.resource_name) if src != null else ""
		var col := skin
		match nm:
			"underwear":
				col = Color(String(cfg.get("pants", "5a4030")))
			"eyes":
				col = Color(String(cfg.get("eyec", "1a1420")))
			"mouth":
				col = skin.darkened(0.35)
			"hair":
				col = Color(String(cfg.get("hair", "5a3a22")))
		mi.set_surface_override_material(s, mat(col))


# ================================================================ weapons: drawn or put away
func _apply_armed(on: bool) -> void:
	for w: Dictionary in _weapons:
		var n: Node3D = w["node"]
		if is_instance_valid(n):
			n.visible = on
			if n.get_parent() != w["home"]:
				n.get_parent().remove_child(n)
				(w["home"] as Node).add_child(n)
			n.transform = w["home_xf"]


# ================================================================ animation
var _attack_n := 0


func _is_armed() -> bool:
	return _armed and not _weapons.is_empty()


## The clip to use for a plain name: its sword-and-shield version while a weapon is drawn, when there is one.
func _clip(base: String) -> String:
	if _is_armed() and _anims.has(base + "_armed"):
		return base + "_armed"
	return base


func attack(dur := 0.25, left := false, fast := false) -> void:
	super.attack(dur, left, fast)
	if _is_armed():
		var n := 0
		for c: String in ATTACKS_ARMED:
			if _anims.has(c):
				n += 1
		if n > 0:
			_attack_n = (_attack_n + 1) % n
			_play_once(ATTACKS_ARMED[_attack_n], 1.5)
			return
	_play_once("attack", 2.2)


func cast(dur := 0.4) -> void:
	super.cast(dur)
	_play_once(_clip("cast"), 1.4)


func _play_once(clip: String, speed: float) -> void:
	if _ap == null or not _anims.has(clip):
		return
	_ap.speed_scale = speed
	_ap.play(clip)
	_ap.seek(0.0, true)
	_cur = clip
	_one_shot = (_anims[clip] as Animation).length / speed


## Speed scale that makes a travelling clip keep pace with the character (no foot sliding).
func _pace(clip: String, v: float, lo := 0.4, hi := 2.2) -> float:
	var clip_v: float = float(CLIP_SPEED.get(clip, 1.0)) * BODY_HEIGHT / MODEL_HEIGHT * 1.25   # world metres per second at speed 1
	return clampf(v / clip_v, lo, hi)


func tick(delta: float, move: float) -> void:
	super.tick(delta, move)
	if _ap == null:
		return
	_one_shot = maxf(0.0, _one_shot - delta)
	if _one_shot > 0.0:
		return
	var v := _move * FULL_SPEED
	# which way we are going compared with which way we face (we keep facing forward when backing up)
	var dir_fwd := 1.0
	var dir_side := 0.0
	if is_inside_tree():
		var pos := global_position
		if _have_last and delta > 0.0:
			var m := Vector3(pos.x - _last_pos.x, 0.0, pos.z - _last_pos.z) / delta
			if m.length() > 0.6:
				var mn := m.normalized()
				var fwd := Vector3(global_transform.basis.z.x, 0.0, global_transform.basis.z.z).normalized()
				var left := Vector3(global_transform.basis.x.x, 0.0, global_transform.basis.x.z).normalized()
				_move_fwd = mn.dot(fwd)
				_move_side = mn.dot(left)
			elif m.length() < 0.3:
				_move_fwd = 1.0
				_move_side = 0.0
		_last_pos = pos
		_have_last = true
		dir_fwd = _move_fwd
		dir_side = _move_side
	var want := _clip("idle")
	var speed := 1.0
	if air > 0.35:
		want = _clip("jump")
		speed = 1.4
	elif work_kind in ["chop", "mine", "smith", "craft"]:
		want = _clip("attack") if not _is_armed() else "attack"   # until there are work clips, these swing
		speed = 1.0
	elif v > 0.4:
		var run := v >= 2.6
		var base := "run" if run else "walk"
		if dir_fwd < -0.45:
			base += "_back"
		elif absf(dir_side) > 0.7 and absf(dir_fwd) < 0.6 and _is_armed():
			base = "strafe_l" if dir_side > 0.0 else "strafe_r"
		var c := _clip(base)
		if not _anims.has(c) and base.ends_with("_back"):
			c = _clip("walk_back")
		if not _anims.has(c):
			c = _clip("run" if run else "walk")
			if not _anims.has(c):
				c = "walk"
		want = c
		speed = _pace(c, v)
	if want != _cur or (want == "attack" and not _ap.is_playing()):
		_cur = want
		_ap.play(want)
	_ap.speed_scale = speed
	if _cur.begins_with("jump") and _ap.current_animation_position > (_anims[_cur] as Animation).length * 0.9:
		_ap.pause()
	elif not _cur.begins_with("jump") and not _ap.is_playing():
		_ap.play(_cur)
