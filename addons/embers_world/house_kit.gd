@tool
class_name EmbersHouseKit
extends RefCounted
## More houses, built from the game's own TownKit pieces (walls with a doorway, floors, stairs, furniture, windows,
## roofs), so they feel exactly like the game's houses: you can walk in, climb the stairs, and they take each region's
## colours (the EmbersProp "style"). Use them from an EmbersProp with Category = House. Things face +Z (the door side)
## and stand on y = 0. "variation" changes the size a little, the doors, the chimney and the furniture.

const KINDS := ["cottage_porch", "cottage_stone", "cottage_hip", "cottage_lean", "cottage_dormer", "house_loft", "house_balcony",
	"townhouse_tall", "manor", "cabin_log", "hunter_lodge", "workshop_house"]


static func build(kind: String, style_name := "meadow", seed_v := 0, _length := 6.0) -> Node3D:
	var b: TownKit.B = TownKit.B.new(TownKit.style(style_name), seed_v * 7919 + kind.hash())
	b.layout = {}
	match kind:
		"cottage_porch": _cottage_porch(b)
		"cottage_stone": _cottage_stone(b)
		"cottage_hip": _cottage_hip(b)
		"cottage_lean": _cottage_lean(b)
		"cottage_dormer": _cottage_dormer(b)
		"house_loft": _house_loft(b)
		"house_balcony": _house_balcony(b)
		"townhouse_tall": _townhouse_tall(b)
		"manor": _manor(b)
		"cabin_log": _cabin_log(b, false)
		"hunter_lodge": _cabin_log(b, true)
		"workshop_house": _workshop_house(b)
		_: b.box(Vector3(0, 0.5, 0), Vector3.ONE, Color.MAGENTA)
	var root: Node3D = b.build(kind)
	root.set_meta("tk", {"kind": kind, "style": style_name, "seed": seed_v, "length": _length, "hw": b.hw, "hd": b.hd, "zc": b.zc})
	return root


# ================================================================ pieces
static func _shutters(b: TownKit.B, c: Vector3, w: float, h: float) -> void:
	for sx in [-1, 1]:
		b.box(c + Vector3(sx * (w * 0.5 + 0.2), 0, 0.06), Vector3(0.3, h + 0.1, 0.05), b.c("trim"))


## A roofed porch on two posts in front of the door.
static func _porch(b: TownKit.B, x: float, zf: float, w: float, h: float) -> void:
	var tc := b.c("timber")
	b.box(Vector3(x, 0.1, zf + 0.9), Vector3(w, 0.2, 1.8), tc.lightened(0.15))
	for sx in [-1, 1]:
		b.box(Vector3(x + sx * (w * 0.5 - 0.15), h * 0.5, zf + 1.65), Vector3(0.2, h, 0.2), tc)
		b.solid(Vector3(x + sx * (w * 0.5 - 0.15), h * 0.5, zf + 1.65), Vector3(0.24, h, 0.24))
	b.in_roof = true
	b.quad(Vector3(x - w * 0.5 - 0.2, h + 0.1, zf + 1.9), Vector3(x + w * 0.5 + 0.2, h + 0.1, zf + 1.9), Vector3(x + w * 0.5 + 0.2, h + 0.45, zf - 0.1), Vector3(x - w * 0.5 - 0.2, h + 0.45, zf - 0.1), b.c("roof"))
	b.quad(Vector3(x - w * 0.5 - 0.2, h + 0.06, zf + 1.9), Vector3(x - w * 0.5 - 0.2, h + 0.41, zf - 0.1), Vector3(x + w * 0.5 + 0.2, h + 0.41, zf - 0.1), Vector3(x + w * 0.5 + 0.2, h + 0.06, zf + 1.9), b.c("roof").darkened(0.3))
	b.in_roof = false
	b.box(Vector3(x, 0.45, zf + 1.65), Vector3(0.9, 0.1, 0.4), tc.lightened(0.1))   # a bench on the porch
	b.box(Vector3(x - 0.35, 0.22, zf + 1.65), Vector3(0.1, 0.44, 0.35), tc)
	b.box(Vector3(x + 0.35, 0.22, zf + 1.65), Vector3(0.1, 0.44, 0.35), tc)


static func _bed_room(b: TownKit.B, w: float, d: float) -> void:
	TownKit._bed(b, Vector3(-w * 0.5 + 0.95, 0, -d * 0.5 + 1.3))
	TownKit._chest(b, Vector3(-w * 0.5 + 2.2, 0, -d * 0.5 + 0.55))


static func _kitchen(b: TownKit.B, w: float, d: float) -> void:
	TownKit._hearth(b, Vector3(w * 0.22, 0, -d * 0.5 + 0.65))
	TownKit._table(b, Vector3(w * 0.2, 0, 0.5), 1.2, 0.8)
	TownKit._stool(b, Vector3(w * 0.2 - 0.9, 0, 0.5))
	TownKit._stool(b, Vector3(w * 0.2 + 0.9, 0, 0.5))
	TownKit._carpet(b, Vector3(-0.2, 0, 0.1), 1.6, 1.2, b.c("cloth"))


# ================================================================ cottages
static func _cottage_porch(b: TownKit.B) -> void:
	var w := 5.6 + b.rng.randf_range(-0.3, 0.5)
	var d := 4.2
	var h := 2.6
	var dx := -w * 0.15
	TownKit._hall(b, w, d, h, dx, 1.0, 1.9, TownKit._door_mode(b))
	TownKit._braces(b, w, 0.4, h, -d * 0.5)
	TownKit._roof(b, Vector3(0, h, 0), w + 0.8, d + 1.0, 1.9)
	_porch(b, dx, d * 0.5, 2.4, 2.1)
	var wc := Vector3(w * 0.28, 1.5, d * 0.5)
	b.window(wc, 0.7, 0.6, Vector3.BACK)
	_shutters(b, wc, 0.7, 0.6)
	b.window(Vector3(w * 0.5, 1.5, 0), 0.6, 0.6, Vector3.RIGHT)
	b.window(Vector3(-w * 0.5, 1.5, 0), 0.6, 0.6, Vector3.LEFT)
	TownKit._chimney(b, Vector3(w * 0.3, h, -0.6), 2.5)
	_kitchen(b, w, d)
	_bed_room(b, w, d)


static func _cottage_stone(b: TownKit.B) -> void:
	var w := 5.8
	var d := 4.4
	var h := 2.7
	TownKit._hall(b, w, d, h, w * 0.18, 1.0, 1.9, TownKit._door_mode(b, 0.5, 0.35), 0.0, -1.0, "stone")
	TownKit._roof(b, Vector3(0, h, 0), w + 0.8, d + 1.0, 2.0)
	for sx in [-1, 1]:
		TownKit._chimney(b, Vector3(sx * (w * 0.5 - 0.2), h, 0.0), 2.4)
		var wc := Vector3(sx * w * 0.28, 1.5, d * 0.5)
		b.window(wc, 0.6, 0.7, Vector3.BACK)
		_shutters(b, wc, 0.6, 0.7)
	TownKit._hearth(b, Vector3(-w * 0.2, 0, -d * 0.5 + 0.65))
	TownKit._table(b, Vector3(-w * 0.15, 0, 0.5), 1.3, 0.9)
	TownKit._stool(b, Vector3(-w * 0.15 - 1.0, 0, 0.5))
	TownKit._bed(b, Vector3(w * 0.5 - 0.95, 0, -d * 0.5 + 1.3))
	TownKit._barrel(b, Vector3(w * 0.5 - 0.7, 0, 0.8))
	TownKit._flowerbox(b, Vector3(-w * 0.28, 1.05, d * 0.5 + 0.2), 0.0)


static func _cottage_hip(b: TownKit.B) -> void:
	var w := 5.0
	var d := 5.0
	var h := 2.7
	TownKit._hall(b, w, d, h, -0.5, 1.0, 1.9, TownKit._door_mode(b))
	b.in_roof = true
	b.pyramid(Vector3(0, h, 0), w + 1.2, d + 1.2, 2.2, b.c("roof"))
	b.in_roof = false
	TownKit._chimney(b, Vector3(0.9, h + 0.6, -0.6), 2.0)
	for sx in [-1, 1]:
		b.window(Vector3(sx * w * 0.5, 1.5, 0), 0.6, 0.6, Vector3.RIGHT * sx)
	b.window(Vector3(w * 0.28, 1.5, d * 0.5), 0.7, 0.6, Vector3.BACK)
	TownKit._flowerbox(b, Vector3(w * 0.28, 1.05, d * 0.5 + 0.2), 0.0)
	_kitchen(b, w, d)
	TownKit._bed(b, Vector3(-w * 0.5 + 0.95, 0, -d * 0.5 + 1.3))


static func _cottage_lean(b: TownKit.B) -> void:
	var w := 5.4
	var d := 4.0
	var h := 2.5
	TownKit._hall(b, w, d, h, w * 0.12, 0.95, 1.85, TownKit._door_mode(b), 0.0, h)
	# a single slope, high at the back, with the gable ends filled in
	var rise := 1.3
	b.in_roof = true
	b.quad(Vector3(-w * 0.5 - 0.4, h, d * 0.5 + 0.6), Vector3(w * 0.5 + 0.4, h, d * 0.5 + 0.6), Vector3(w * 0.5 + 0.4, h + rise, -d * 0.5 - 0.5), Vector3(-w * 0.5 - 0.4, h + rise, -d * 0.5 - 0.5), b.c("roof"))
	b.quad(Vector3(-w * 0.5 - 0.4, h - 0.1, d * 0.5 + 0.6), Vector3(-w * 0.5 - 0.4, h + rise - 0.1, -d * 0.5 - 0.5), Vector3(w * 0.5 + 0.4, h + rise - 0.1, -d * 0.5 - 0.5), Vector3(w * 0.5 + 0.4, h - 0.1, d * 0.5 + 0.6), b.c("roof").darkened(0.3))
	b.in_roof = false
	for sx in [-1, 1]:
		b.tri(Vector3(sx * w * 0.5, h, d * 0.5), Vector3(sx * w * 0.5, h, -d * 0.5), Vector3(sx * w * 0.5, h + rise - 0.1, -d * 0.5), b.c("wall2"))
		b.tri(Vector3(sx * w * 0.5, h, d * 0.5), Vector3(sx * w * 0.5, h + rise - 0.1, -d * 0.5), Vector3(sx * w * 0.5, h, -d * 0.5), b.c("wall2"))
	b.box(Vector3(0, h + rise * 0.5, -d * 0.5), Vector3(w, rise, 0.3), b.c("wall"))
	b.window(Vector3(-w * 0.28, 1.5, d * 0.5), 0.8, 0.6, Vector3.BACK)
	TownKit._hearth(b, Vector3(-w * 0.2, 0, -d * 0.5 + 0.65))
	TownKit._bed(b, Vector3(w * 0.5 - 0.95, 0, -d * 0.5 + 1.3))
	TownKit._table(b, Vector3(-w * 0.15, 0, 0.5), 1.1, 0.8)
	TownKit._stool(b, Vector3(-w * 0.15 + 0.9, 0, 0.5))
	b.box(Vector3(w * 0.5 + 0.7, 0.5, -0.5), Vector3(0.8, 1.0, 2.0), Color("8a6a40"))   # a woodpile against the wall
	b.solid(Vector3(w * 0.5 + 0.7, 0.5, -0.5), Vector3(0.8, 1.0, 2.0))


static func _cottage_dormer(b: TownKit.B) -> void:
	var w := 6.0
	var d := 4.6
	var h := 2.6
	TownKit._hall(b, w, d, h, 0.0, 1.0, 1.9, TownKit._door_mode(b, 0.7, 0.2))
	var rh := 2.4
	TownKit._roof(b, Vector3(0, h, 0), w + 0.8, d + 1.0, rh)
	# two dormers on the front slope
	var rz := (d + 1.0) * 0.5
	for sx in [-1, 1]:
		var cx: float = sx * w * 0.27
		var zd := 1.2
		var base_y := h + rh * (1.0 - zd / rz) - 0.2
		b.in_roof = true
		b.box(Vector3(cx, base_y + 0.45, zd + 0.1), Vector3(1.3, 0.9, 0.9), b.c("wall"))
		var save := b.xf
		b.xf = Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(cx, base_y + 0.9, zd + 0.1))
		b.gable(Vector3.ZERO, 1.7, 1.2, 0.7, b.c("roof"), b.c("wall2"))
		b.xf = save
		b.in_roof = false
		b.window(Vector3(cx, base_y + 0.5, zd + 0.58), 0.6, 0.5, Vector3.BACK)
	for sx in [-1, 1]:
		var wc := Vector3(sx * w * 0.3, 1.5, d * 0.5)
		b.window(wc, 0.7, 0.7, Vector3.BACK)
		_shutters(b, wc, 0.7, 0.7)
	TownKit._chimney(b, Vector3(0.0, h + 0.6, -1.0), 2.2)
	_kitchen(b, w, d)
	TownKit._bed(b, Vector3(-w * 0.5 + 0.95, 0, -d * 0.5 + 1.3))
	TownKit._bed(b, Vector3(-w * 0.5 + 2.1, 0, -d * 0.5 + 1.3))


# ================================================================ bigger houses
static func _house_loft(b: TownKit.B) -> void:
	var w := 7.0
	var d := 6.0
	var fy := 3.0
	var h2 := 2.6
	TownKit._hall(b, w, d, fy, 0.6, 1.2, 2.0, TownKit._door_mode(b, 0.7, 0.2))
	TownKit._storey(b, w, d, 0.0, fy, h2, -1.0, 4.4)
	TownKit._roof(b, Vector3(0, fy + h2, 0), w + 1.1, d + 1.3, 2.2)
	for x in [-w * 0.3, w * 0.35]:
		b.window(Vector3(x, 1.6, d * 0.5), 0.8, 0.7, Vector3.BACK)
	TownKit._up_on(b)
	for x in [-w * 0.3, 0.0, w * 0.3]:
		var wc := Vector3(x, 1.5, d * 0.5)
		b.window(wc, 0.8, 0.8, Vector3.BACK)
		_shutters(b, wc, 0.8, 0.8)
	TownKit._bed(b, Vector3(w * 0.5 - 1.0, 0, -d * 0.5 + 1.45))
	TownKit._bed(b, Vector3(w * 0.5 - 2.3, 0, -d * 0.5 + 1.45))
	TownKit._chest(b, Vector3(0.0, 0, -d * 0.5 + 0.6))
	TownKit._shelf_side(b, w, 1.0, 1.2, 1.6)
	TownKit._up_off(b)
	TownKit._chimney(b, Vector3(w * 0.3, fy + h2, -1.2), 2.4)
	_kitchen(b, w, d)
	TownKit._barrel(b, Vector3(w * 0.5 - 0.8, 0, 2.2))


static func _house_balcony(b: TownKit.B) -> void:
	var w := 7.6
	var d := 6.4
	var fy := 3.0
	var h2 := 2.7
	TownKit._hall(b, w, d, fy, 0.9, 1.2, 2.0, TownKit._door_mode(b, 0.8, 0.15), 0.0, -1.0, "wall")
	TownKit._storey(b, w, d, 0.0, fy, h2, -1.0, 4.4)
	TownKit._roof(b, Vector3(0, fy + h2, 0), w + 1.1, d + 1.3, 2.3)
	# a balcony over the door: floor, rail, and two posts down to the ground
	var tc := b.c("timber")
	b.box(Vector3(0.9, fy + 0.05, d * 0.5 + 0.7), Vector3(2.8, 0.14, 1.4), tc.lightened(0.15))
	b.box(Vector3(0.9, fy + 0.85, d * 0.5 + 1.38), Vector3(2.8, 0.08, 0.06), tc)
	for sx in [-1, 1]:
		b.box(Vector3(0.9 + sx * 1.3, fy + 0.45, d * 0.5 + 1.38), Vector3(0.08, 0.9, 0.08), tc)
		b.box(Vector3(0.9 + sx * 1.3, fy * 0.5, d * 0.5 + 1.38), Vector3(0.2, fy, 0.2), tc)
		b.solid(Vector3(0.9 + sx * 1.3, fy * 0.5, d * 0.5 + 1.38), Vector3(0.24, fy, 0.24))
		b.box(Vector3(0.9 + sx * 0.6, fy + 0.45, d * 0.5 + 1.38), Vector3(0.06, 0.8, 0.06), tc.lightened(0.1))
	for x in [-w * 0.3]:
		b.window(Vector3(x, 1.6, d * 0.5), 0.8, 0.8, Vector3.BACK)
	TownKit._up_on(b)
	b.window(Vector3(-w * 0.3, 1.5, d * 0.5), 0.8, 0.8, Vector3.BACK)
	b.window(Vector3(0.9, 1.45, d * 0.5), 1.0, 1.4, Vector3.BACK)
	TownKit._bed(b, Vector3(w * 0.5 - 1.0, 0, -d * 0.5 + 1.45))
	TownKit._bed(b, Vector3(w * 0.5 - 2.3, 0, -d * 0.5 + 1.45))
	TownKit._table(b, Vector3(0.6, 0, -0.6), 1.4, 0.9)
	TownKit._up_off(b)
	TownKit._chimney(b, Vector3(-w * 0.3, fy + h2, -1.2), 2.4)
	TownKit._hearth(b, Vector3(-w * 0.22, 0, -d * 0.5 + 0.65))
	TownKit._table(b, Vector3(1.4, 0, -0.5), 1.8, 1.0)
	for x in [0.4, 1.4, 2.4]:
		TownKit._stool(b, Vector3(x, 0, 0.6))
	TownKit._shelf_side(b, w, 1.0, 1.0, 1.8)


static func _townhouse_tall(b: TownKit.B) -> void:
	var w := 5.6
	var d := 5.4
	var fy := 3.0
	var h2 := 2.6
	TownKit._hall(b, w, d, fy, 0.4, 1.1, 2.0, TownKit._door_mode(b, 0.7, 0.2), 0.0, -1.0, "stone")
	TownKit._storey(b, w, d, 0.0, fy, h2, -1.0, 3.6, "wall")
	TownKit._roof(b, Vector3(0, fy + h2, 0), w + 1.0, d + 1.2, 2.6)
	b.window(Vector3(-w * 0.25, 1.6, d * 0.5), 0.8, 0.7, Vector3.BACK)
	TownKit._up_on(b)
	b.window(Vector3(-w * 0.25, 1.5, d * 0.5), 0.8, 0.8, Vector3.BACK)
	b.window(Vector3(w * 0.25, 1.5, d * 0.5), 0.8, 0.8, Vector3.BACK)
	TownKit._flowerbox(b, Vector3(w * 0.25, 1.05, d * 0.5 + 0.2), 0.0)
	TownKit._bed(b, Vector3(w * 0.5 - 1.0, 0, -d * 0.5 + 1.45))
	TownKit._chest(b, Vector3(0.6, 0, -d * 0.5 + 0.6))
	TownKit._up_off(b)
	# an attic window in the gable
	b.window(Vector3(0, fy + h2 + 0.9, d * 0.5 + 0.5), 0.5, 0.5, Vector3.BACK)
	TownKit._chimney(b, Vector3(w * 0.3, fy + h2, -1.0), 2.6)
	_kitchen(b, w, d)


static func _manor(b: TownKit.B) -> void:
	var w := 9.4
	var d := 7.2
	var fy := 3.4
	var h2 := 2.9
	TownKit._hall(b, w, d, fy, 0.0, 1.4, 2.3, TownKit._door_mode(b, 0.6, 0.35), 0.0, -1.0, "stone")
	TownKit._storey(b, w, d, 0.0, fy, h2, -1.0, 5.0, "wall")
	TownKit._roof(b, Vector3(0, fy + h2, 0), w + 1.3, d + 1.4, 2.8)
	# two side wings you can't enter, set a little back, each with its own roof and chimney
	for sx in [-1, 1]:
		var wx: float = sx * (w * 0.5 + 2.1)
		b.box(Vector3(wx, 1.6, -0.8), Vector3(4.2, 3.2, 5.0), b.c("stone"))
		b.solid(Vector3(wx, 1.6, -0.8), Vector3(4.2, 3.2, 5.0))
		b.in_roof = true
		b.gable(Vector3(wx, 3.2, -0.8), 4.8, 5.8, 1.6, b.c("roof"), b.c("wall2"))
		b.in_roof = false
		b.window(Vector3(wx, 1.8, 1.72), 0.8, 1.0, Vector3.BACK)
		TownKit._chimney(b, Vector3(wx + sx * 1.2, 3.2, -1.6), 2.0)
	# front steps and a columned porch
	var tc := b.c("timber")
	for i in 3:
		b.box(Vector3(0, 0.1 + i * 0.1, d * 0.5 + 0.9 - i * 0.3), Vector3(3.4, 0.2 + i * 0.2, 0.6), b.c("stone"))
	for sx in [-1, 1]:
		b.cyl(Vector3(sx * 1.4, 0.0, d * 0.5 + 1.6), 0.2, 0.2, 3.2, b.c("stone").lightened(0.1), 8)
		b.solid(Vector3(sx * 1.4, 1.6, d * 0.5 + 1.6), Vector3(0.4, 3.2, 0.4))
	b.in_roof = true
	b.box(Vector3(0, 3.3, d * 0.5 + 0.9), Vector3(3.8, 0.2, 2.2), tc)
	b.in_roof = false
	for x in [-w * 0.32, w * 0.32]:
		b.window(Vector3(x, 1.7, d * 0.5), 0.9, 1.0, Vector3.BACK)
	TownKit._up_on(b)
	for x in [-w * 0.32, 0.0, w * 0.32]:
		b.window(Vector3(x, 1.6, d * 0.5), 0.9, 1.0, Vector3.BACK)
	for i in 3:
		TownKit._bed(b, Vector3(w * 0.5 - 1.0 - i * 1.3, 0, -d * 0.5 + 1.5))
	TownKit._chest(b, Vector3(-2.0, 0, -d * 0.5 + 0.6))
	TownKit._shelf_side(b, w, 1.0, 1.2, 2.2)
	TownKit._up_off(b)
	# the great hall: a long table with benches, a big hearth, shelves
	TownKit._hearth(b, Vector3(-w * 0.2, 0, -d * 0.5 + 0.65))
	TownKit._table(b, Vector3(1.2, 0, -0.4), 3.4, 1.1)
	for x in [-0.6, 1.2, 3.0]:
		TownKit._stool(b, Vector3(x, 0, 0.75))
		TownKit._stool(b, Vector3(x, 0, -1.55))
	TownKit._shelf_side(b, w, 1.0, 1.4, 2.4)
	TownKit._carpet(b, Vector3(1.2, 0, 1.6), 3.0, 1.6, b.c("cloth"))


# ================================================================ log buildings
## A log cabin: round log ends at the corners, a steep roof. With hunter = true it has antlers, a skinning rack and furs.
static func _cabin_log(b: TownKit.B, hunter: bool) -> void:
	var w := 5.8 if not hunter else 6.4
	var d := 4.6
	var h := 2.6
	var logc := b.c("timber").lightened(0.1)
	TownKit._hall(b, w, d, h, -w * 0.12, 1.0, 1.9, TownKit._door_mode(b, 0.5, 0.4), 0.0, -1.0, "timber")
	# stacked log ends at the corners and horizontal log lines across the walls
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			for k in 6:
				b.cyl(Vector3(sx * w * 0.5, 0.2 + k * 0.42, sz * d * 0.5) + Vector3(0, 0, 0), 0.21, 0.21, 0.04, logc.lightened(0.12 * (k % 2)), 7, false, true)
	for k in 5:
		b.box(Vector3(0, 0.55 + k * 0.45, d * 0.5 + 0.03), Vector3(w + 0.3, 0.05, 0.05), logc.darkened(0.25))
	TownKit._roof(b, Vector3(0, h, 0), w + 1.0, d + 1.2, 2.3)
	TownKit._chimney(b, Vector3(w * 0.32, h, -0.8), 2.6)
	b.window(Vector3(w * 0.28, 1.5, d * 0.5), 0.6, 0.6, Vector3.BACK)
	b.window(Vector3(-w * 0.5, 1.5, 0), 0.6, 0.6, Vector3.LEFT)
	TownKit._hearth(b, Vector3(w * 0.2, 0, -d * 0.5 + 0.65))
	TownKit._bed(b, Vector3(-w * 0.5 + 0.95, 0, -d * 0.5 + 1.3))
	TownKit._table(b, Vector3(0.4, 0, 0.5), 1.2, 0.8)
	TownKit._stool(b, Vector3(-0.5, 0, 0.5))
	TownKit._stool(b, Vector3(1.3, 0, 0.5))
	TownKit._carpet(b, Vector3(0.4, 0, 0.1), 1.8, 1.4, Color("6a4a3a"))
	# woodpile under a lean-to on the side
	b.box(Vector3(w * 0.5 + 0.7, 0.55, 0.0), Vector3(1.0, 1.1, 2.4), Color("8a6a40"))
	b.solid(Vector3(w * 0.5 + 0.7, 0.55, 0.0), Vector3(1.0, 1.1, 2.4))
	if hunter:
		# antlers over the door, a drying rack with hides, a trophy skull stump
		var tc := b.c("timber")
		for sx in [-1, 1]:
			b.beam(Vector3(-w * 0.12 + sx * 0.15, 2.45, d * 0.5 + 0.12), Vector3(-w * 0.12 + sx * 0.7, 3.0, d * 0.5 + 0.12), 0.06, Color("e8dcc0"))
			b.beam(Vector3(-w * 0.12 + sx * 0.45, 2.75, d * 0.5 + 0.12), Vector3(-w * 0.12 + sx * 0.55, 3.1, d * 0.5 + 0.12), 0.05, Color("e8dcc0"))
		for sx in [-1, 1]:
			b.box(Vector3(-w * 0.5 - 1.9 + sx * 0.9, 0.95, 0.9), Vector3(0.12, 1.9, 0.12), tc)
			b.solid(Vector3(-w * 0.5 - 1.9 + sx * 0.9, 0.95, 0.9), Vector3(0.16, 1.9, 0.16))
		b.box(Vector3(-w * 0.5 - 1.9, 1.85, 0.9), Vector3(2.0, 0.1, 0.1), tc)
		for k in 3:
			b.box(Vector3(-w * 0.5 - 2.4 + k * 0.5, 1.3, 0.9), Vector3(0.4, 0.9, 0.05), [Color("8a6a4a"), Color("a08868"), Color("6a4a30")][k])
		TownKit._weapon_rack_at(b, Vector3(w * 0.5 - 0.5, 0, 0.9))


static func _workshop_house(b: TownKit.B) -> void:
	var w := 6.6
	var d := 5.2
	var h := 2.8
	TownKit._hall(b, w, d, h, -w * 0.2, 1.1, 1.95, TownKit._door_mode(b, 0.6, 0.3), 0.0, -1.0, "wall")
	TownKit._roof(b, Vector3(0, h, 0), w + 0.9, d + 1.1, 2.1)
	TownKit._chimney(b, Vector3(-w * 0.3, h, -1.0), 2.6)
	var tc := b.c("timber")
	# an open workshop bay on the right: a roofed lean-to over a bench and a barrel
	var lx := w * 0.5 + 1.6
	for sz in [-1, 1]:
		b.box(Vector3(lx + 1.4, 1.2, sz * 1.8), Vector3(0.2, 2.4, 0.2), tc)
		b.solid(Vector3(lx + 1.4, 1.2, sz * 1.8), Vector3(0.24, 2.4, 0.24))
	b.in_roof = true
	b.quad(Vector3(w * 0.5, 2.7, 2.2), Vector3(lx + 1.7, 2.3, 2.2), Vector3(lx + 1.7, 2.3, -2.2), Vector3(w * 0.5, 2.7, -2.2), b.c("roof2"))
	b.in_roof = false
	b.box(Vector3(lx + 0.5, 0.45, -1.2), Vector3(1.2, 0.9, 0.7), tc.lightened(0.1))   # workbench
	b.box(Vector3(lx + 0.5, 0.95, -1.2), Vector3(1.3, 0.08, 0.8), tc.lightened(0.2))
	b.solid(Vector3(lx + 0.5, 0.5, -1.2), Vector3(1.3, 1.0, 0.8))
	b.box(Vector3(lx + 0.6, 0.5, 1.1), Vector3(0.7, 0.9, 0.7), tc)
	b.solid(Vector3(lx + 0.6, 0.5, 1.1), Vector3(0.7, 1.0, 0.7))
	b.box(Vector3(lx + 0.5, 1.4, -1.55), Vector3(0.7, 0.4, 0.05), Color("9a9a9a"))   # tools on the wall
	b.window(Vector3(w * 0.25, 1.5, d * 0.5), 0.9, 0.8, Vector3.BACK)
	# a hanging sign
	b.beam(Vector3(-w * 0.2 + 1.0, 2.6, d * 0.5 + 0.2), Vector3(-w * 0.2 + 2.0, 2.6, d * 0.5 + 0.2), 0.07, tc)
	b.box(Vector3(-w * 0.2 + 1.8, 2.2, d * 0.5 + 0.2), Vector3(0.6, 0.5, 0.05), b.c("trim"))
	TownKit._hearth(b, Vector3(-w * 0.28, 0, -d * 0.5 + 0.65))
	TownKit._table(b, Vector3(0.4, 0, 0.2), 1.8, 1.0)
	TownKit._stool(b, Vector3(0.4, 0, 1.1))
	TownKit._bed(b, Vector3(w * 0.5 - 0.95, 0, -d * 0.5 + 1.3))
	TownKit._shelf_side(b, w, 1.0, 0.6, 1.6)
