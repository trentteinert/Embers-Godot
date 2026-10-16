class_name Clicker
extends Node3D
## Point-and-click interaction: hover over a person, the forge, a resource node, the shrine,
## a runestone, an altar or loot on the ground and the cursor turns into a hand with a label.
## Click it to use it; if it's too far away you walk there first. WASD cancels the walk.

const MAX_CLICK_DIST := 30.0

var main: Node
var hovered := {}          # the interactable under the mouse, or {}
var hovered_enemy: Enemy   # enemy under the mouse (click to target it)
var hover_text := ""
var _pending := {}         # clicked but still walking to it
var _block := false        # mouse is still held from an interaction click (don't attack)
var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _target_ring: MeshInstance3D
var _t := 0.0


func setup(m: Node) -> void:
	main = m
	_ring = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.9
	tm.outer_radius = 1.0
	tm.rings = 24
	tm.ring_segments = 4
	_ring.mesh = tm
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.albedo_color = Color("ffd27a")
	_ring.material_override = _ring_mat
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.visible = false
	add_child(_ring)
	_target_ring = MeshInstance3D.new()
	_target_ring.mesh = tm
	var trm := StandardMaterial3D.new()
	trm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	trm.albedo_color = Color("e0503c")
	_target_ring.material_override = trm
	_target_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_target_ring.visible = false
	add_child(_target_ring)


func blocks_attack() -> bool:
	return _block or not hovered.is_empty()


## Every interactable thing in the world right now: {kind, pos, h (height), r (radius), range, ...}
func candidates() -> Array:
	var out: Array = []
	var q = main.quests
	var w: World = main.world
	out.append({"kind": "npc", "id": "merchant", "pos": w.merchant_pos, "h": 2.2, "r": 0.7, "range": q.TALK_RANGE + 0.4})
	out.append({"kind": "npc", "id": "merchant2", "pos": w.merchant2_pos, "h": 2.2, "r": 0.7, "range": q.TALK_RANGE + 0.4})
	out.append({"kind": "npc", "id": "merchant3", "pos": w.merchant3_pos, "h": 2.2, "r": 0.7, "range": q.TALK_RANGE + 0.4})
	for id: String in q._npcs:
		out.append({"kind": "npc", "id": id, "pos": (q._npcs[id] as Dictionary)["pos"], "h": 2.2, "r": 0.7, "range": q.TALK_RANGE})
	out.append({"kind": "forge", "pos": w.forge_pos, "h": 2.2, "r": 1.4, "range": 3.6})
	if main.online != null:
		out.append_array(main.online.click_candidates())   # resources and fires come from the server
	for n: Dictionary in main.crafting._nodes:
		if float(n["ready_t"]) <= 0.0:
			out.append({"kind": "node", "node": n, "pos": n["pos"], "h": 1.4, "r": 0.8, "range": main.crafting.GATHER_RANGE})
	out.append({"kind": "shrine", "pos": w.shrine_pos, "h": 3.2, "r": 2.0, "range": 7.5})
	for i in 4:
		out.append({"kind": "rune", "i": i, "pos": w.rune_pos[i], "h": 2.2, "r": 0.8, "range": 3.2})
		out.append({"kind": "altar", "i": i, "pos": w.altar_pos[i], "h": 1.6, "r": 1.6, "range": 5.0})
	out.append({"kind": "varka", "pos": w.slayer_pos, "h": 2.2, "r": 0.7, "range": 3.2})
	out.append({"kind": "rack", "pos": w.rack_pos, "h": 1.6, "r": 1.2, "range": 3.0})
	out.append({"kind": "furnace", "pos": w.furnace_pos, "h": 1.8, "r": 1.2, "range": Skills.STATION_RANGE + 0.6})
	out.append({"kind": "anvil", "pos": w.anvil_pos, "h": 1.3, "r": 0.9, "range": Skills.STATION_RANGE})
	for fp: Vector3 in main.skills.all_fires():
		out.append({"kind": "fire", "pos": fp, "h": 1.0, "r": 0.8, "range": Skills.STATION_RANGE})
	for fs: Dictionary in main.skills.fish_spots:
		out.append({"kind": "fish", "spot": fs, "pos": fs["pos"], "h": 0.6, "r": 1.0, "range": Skills.FISH_RANGE})
	for k: Dictionary in main.combat._pickups:
		out.append({"kind": "pickup", "pickup": k, "pos": k["pos"], "h": 1.0, "r": 0.6, "range": main.combat.PICKUP_RANGE})
	return out


func _process(delta: float) -> void:
	_t += delta
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_block = false
	var active: bool = main.mode == "play" and main.player.can_act and not main.player.dead and not main.menu_open()
	var free_mouse: bool = active and not main.rig.dragging and main.get_viewport().gui_get_hovered_control() == null
	hovered_enemy = _pick_enemy() if free_mouse else null
	hovered = _pick() if free_mouse and hovered_enemy == null else {}
	hover_text = main.click_label(hovered) if not hovered.is_empty() else ""
	if hover_text == "":
		hovered = {}
	var cursor := Input.CURSOR_ARROW
	if hovered_enemy:
		cursor = Input.CURSOR_CROSS
	elif not hovered.is_empty():
		cursor = Input.CURSOR_POINTING_HAND
	Input.set_default_cursor_shape(cursor)
	_target_ring.visible = main.has_target() and main.mode == "play"
	if _target_ring.visible:
		var te: Enemy = main.target
		var tp := te.global_position
		_target_ring.global_position = Vector3(tp.x, main.world.height_at(tp.x, tp.z) + 0.1, tp.z)
		_target_ring.scale = Vector3.ONE * (te.radius + 0.35)
	var show: Dictionary = hovered if not hovered.is_empty() else _pending
	_ring.visible = not show.is_empty()
	if _ring.visible:
		var p: Vector3 = show["pos"]
		var r: float = show["r"]
		_ring.global_position = Vector3(p.x, main.world.height_at(p.x, p.z) + 0.08, p.z)
		_ring.scale = Vector3.ONE * (r + 0.25 + sin(_t * 6.0) * 0.05)
		_ring_mat.albedo_color = Color("ffd27a") if hovered.is_empty() or _in_range(hovered) else Color("c9b48a")
	# walking toward something we clicked
	if not _pending.is_empty():
		if main.player.walk_to == Vector3.INF and not _in_range(_pending):
			_pending = {}
		elif _in_range(_pending):
			main.player.walk_to = Vector3.INF
			var it := _pending
			_pending = {}
			_use(it)


func _in_range(it: Dictionary) -> bool:
	var p: Vector3 = main.player.global_position
	var q: Vector3 = it["pos"]
	return Vector2(p.x - q.x, p.z - q.z).length() < float(it["range"])


## Called by main on a left click in the world. Returns true if the click was used.
func click() -> bool:
	if hovered.is_empty():
		return false
	_block = true
	var it := hovered
	if _in_range(it):
		_pending = {}
		_use(it)
	else:
		_pending = it
		var p: Vector3 = it["pos"]
		var me: Vector3 = main.player.global_position
		var to := Vector3(p.x - me.x, 0, p.z - me.z)
		# stop a little short of it
		var stop := maxf(float(it["range"]) * 0.6, 0.4)
		main.player.walk_to = me + to.normalized() * maxf(to.length() - stop, 0.0)
	return true


func cancel() -> void:
	_pending = {}


func _use(it: Dictionary) -> void:
	if it["kind"] == "pickup":
		main.combat.take(it["pickup"])
	else:
		main.interact_with(it)


func pick_enemy() -> Enemy:
	return hovered_enemy if hovered_enemy and is_instance_valid(hovered_enemy) and not hovered_enemy.dead else null


func _pick_enemy() -> Enemy:
	var cam: Camera3D = main.rig.camera
	var mouse := main.get_viewport().get_mouse_position()
	var best: Enemy = null
	var best_score := INF
	for e: Enemy in main.combat.enemies:
		if e.dead or e.burrowed:
			continue
		var base := e.global_position
		var top := base + Vector3(0, maxf(e.height, 0.6), 0)
		if cam.is_position_behind(base) or cam.is_position_behind(top):
			continue
		var a := cam.unproject_position(base)
		var b := cam.unproject_position(top)
		var side := cam.unproject_position(base + cam.global_basis.x * maxf(e.radius, 0.4))
		var half_w := maxf(absf(side.x - a.x), 12.0)
		var ab := b - a
		var tt := clampf((mouse - a).dot(ab) / maxf(ab.length_squared(), 1.0), 0.0, 1.0)
		var d := (mouse - (a + ab * tt)).length()
		if d > half_w:
			continue
		var score := d / half_w
		if score < best_score:
			best_score = score
			best = e
	return best


func _pick() -> Dictionary:
	var cam: Camera3D = main.rig.camera
	var mouse := main.get_viewport().get_mouse_position()
	var me: Vector3 = main.player.global_position
	var best := {}
	var best_score := INF
	# mid-fight, only things you can reach right now, so a stray click still attacks
	var fighting: bool = main.player.combat_t < 4.0
	for it: Dictionary in candidates():
		var p: Vector3 = it["pos"]
		if Vector2(p.x - me.x, p.z - me.z).length() > MAX_CLICK_DIST:
			continue
		if fighting and not _in_range(it):
			continue
		var base := Vector3(p.x, main.world.height_at(p.x, p.z), p.z)
		var top := base + Vector3(0, float(it["h"]), 0)
		if cam.is_position_behind(base) or cam.is_position_behind(top):
			continue
		var a := cam.unproject_position(base)
		var b := cam.unproject_position(top)
		# how wide is the thing on screen?
		var side := cam.unproject_position(base + cam.global_basis.x * float(it["r"]))
		var half_w := maxf(absf(side.x - a.x), 14.0)
		# distance from the mouse to the vertical segment between its feet and head
		var ab := b - a
		var tt := clampf((mouse - a).dot(ab) / maxf(ab.length_squared(), 1.0), 0.0, 1.0)
		var closest := a + ab * tt
		var d := (mouse - closest).length()
		if d > half_w:
			continue
		var score := d / half_w + cam.global_position.distance_to(p) * 0.01
		if it["kind"] == "pickup":
			score -= 0.3   # loot wins over whatever is behind it
		if score < best_score:
			best_score = score
			best = it
	return best
