@tool
class_name EmbersFarmKit
extends RefCounted
## More farm and countryside pieces in the same low-poly style as the game's own buildings (they are built with the
## game's TownKit pieces, so they pick up each region's colours and have the same kind of collision). Use them from an
## EmbersProp with Category = Farm. Things face +Z and stand on y = 0. "length" sizes the fields, pens, fences,
## gates and hedges; "variation" changes the crop, the fruit, the animal colours and small details.

const KINDS := ["crop_field", "garden_plot", "pumpkin_patch", "orchard_tree", "hay_stack", "hay_wagon", "silo", "stable", "cowshed",
	"chicken_coop", "tool_shed", "dovecote", "beehives", "compost_heap", "feed_sacks", "pig_pen", "sheep_pen", "paddock", "farm_gate", "hedge",
	"cow", "sheep", "pig", "chicken", "horse", "goat"]
## Which of these take a length (metres).
const SIZED := ["crop_field", "garden_plot", "pumpkin_patch", "pig_pen", "sheep_pen", "paddock", "farm_gate", "hedge"]


static func build(kind: String, style_name := "meadow", seed_v := 0, length := 6.0) -> Node3D:
	var b: TownKit.B = TownKit.B.new(TownKit.style(style_name), seed_v * 7919 + kind.hash())
	b.layout = {}
	match kind:
		"crop_field": _crop_field(b, length, seed_v)
		"garden_plot": _garden_plot(b, length)
		"pumpkin_patch": _pumpkin_patch(b, length)
		"orchard_tree": _orchard_tree(b, seed_v)
		"hay_stack": _hay_stack(b)
		"hay_wagon": _hay_wagon(b)
		"silo": _silo(b)
		"stable": _stable(b)
		"cowshed": _cowshed(b)
		"chicken_coop": _chicken_coop(b)
		"tool_shed": _tool_shed(b)
		"dovecote": _dovecote(b)
		"beehives": _beehives(b)
		"compost_heap": _compost_heap(b)
		"feed_sacks": _feed_sacks(b)
		"pig_pen": _pen(b, length, "pig")
		"sheep_pen": _pen(b, length, "sheep")
		"paddock": _pen(b, length, "horse")
		"farm_gate": _farm_gate(b, length)
		"hedge": _hedge(b, length)
		"cow", "sheep", "pig", "chicken", "horse", "goat": _animal(b, kind, seed_v)
		_: b.box(Vector3(0, 0.5, 0), Vector3.ONE, Color.MAGENTA)
	var root: Node3D = b.build(kind)
	root.set_meta("tk", {"kind": kind, "style": style_name, "seed": seed_v, "length": length, "hw": b.hw, "hd": b.hd, "zc": b.zc})
	return root


# ================================================================ fields and gardens
## Rows of crops on tilled earth. variation: 0 wheat, 1 cabbages, 2 corn, 3 carrots/leeks (then repeats). Walk-through.
static func _crop_field(b: TownKit.B, length: float, seed_v: int) -> void:
	var w := maxf(length, 3.0)
	var d := maxf(length * 0.7, 3.0)
	var crop := seed_v % 4
	b.box(Vector3(0, 0.03, 0), Vector3(w, 0.06, d), Color("5a4030"))
	var rows := int((d - 0.6) / 1.1)
	for i in rows:
		var z := -d * 0.5 + 0.8 + i * 1.1
		b.box(Vector3(0, 0.12, z), Vector3(w - 0.6, 0.2, 0.5), Color("4a3426"))
		var n := int((w - 1.0) / (0.55 if crop != 2 else 0.8))
		for k in n:
			var x := -w * 0.5 + 0.6 + k * ((w - 1.2) / maxf(n - 1, 1))
			var jit := b.rng.randf_range(-0.05, 0.05)
			match crop:
				0:   # wheat: golden stalks with heavy heads
					b.box(Vector3(x, 0.5, z + jit), Vector3(0.1, 0.8, 0.1), Color("cdb050"))
					b.box(Vector3(x, 0.95, z + jit), Vector3(0.16, 0.3, 0.16), Color("e8cc70").darkened(0.05 * (k % 3)))
				1:   # cabbages
					b.cyl(Vector3(x, 0.2, z), 0.3, 0.26, 0.32, Color("6aa84f").darkened(0.07 * (k % 3)), 6)
				2:   # corn: tall green with yellow cobs
					b.box(Vector3(x, 0.8, z + jit), Vector3(0.12, 1.5, 0.12), Color("5a9a40"))
					b.box(Vector3(x + 0.1, 1.0, z + jit), Vector3(0.1, 0.3, 0.1), Color("e8d060"))
					b.box(Vector3(x, 1.5, z + jit), Vector3(0.5, 0.06, 0.12), Color("4a8a3a"), 0.4)
				_:   # carrots: feathery tops, orange tips
					b.cone(Vector3(x, 0.2, z), 0.2, 0.45, Color("4a9a3a"), 5)
					b.box(Vector3(x, 0.26, z), Vector3(0.1, 0.1, 0.1), Color("e8883a"))


## Raised beds with a low fence around them.
static func _garden_plot(b: TownKit.B, length: float) -> void:
	var w := maxf(length, 3.0)
	var d := maxf(length * 0.6, 2.5)
	var tc := b.c("timber").lightened(0.15)
	b.box(Vector3(0, 0.02, 0), Vector3(w + 0.4, 0.04, d + 0.4), Color("6a5236"))
	var beds := maxi(int(w / 1.6), 1)
	for i in beds:
		var x := -w * 0.5 + (i + 0.5) * w / beds
		b.box(Vector3(x, 0.18, 0), Vector3(w / beds - 0.4, 0.36, d - 0.4), tc)
		b.box(Vector3(x, 0.34, 0), Vector3(w / beds - 0.6, 0.06, d - 0.6), Color("4a3426"))
		var flower: bool = (i + b.rng.randi()) % 3 == 0
		for k in int((d - 0.8) / 0.5):
			var z := -d * 0.5 + 0.6 + k * 0.5
			if flower:
				b.cone(Vector3(x, 0.36, z), 0.12, 0.4, Color("4a9a3a"), 4)
				b.box(Vector3(x, 0.78, z), Vector3(0.16, 0.12, 0.16), [Color("e86a8a"), Color("f0d060"), Color("a080e0")][k % 3])
			else:
				b.cyl(Vector3(x, 0.38, z), 0.2, 0.16, 0.22, Color("6aa84f").darkened(0.07 * (k % 2)), 5)
	# low picket fence: posts at the corners and a rail, with a gap on the +Z side
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			b.box(Vector3(sx * (w * 0.5 + 0.2), 0.4, sz * (d * 0.5 + 0.2)), Vector3(0.1, 0.8, 0.1), tc)
	b.box(Vector3(0, 0.55, -d * 0.5 - 0.2), Vector3(w + 0.4, 0.08, 0.05), tc.darkened(0.1))
	for sx in [-1, 1]:
		b.box(Vector3(sx * (w * 0.5 + 0.2), 0.55, 0), Vector3(0.05, 0.08, d + 0.4), tc.darkened(0.1))


static func _pumpkin_patch(b: TownKit.B, length: float) -> void:
	var w := maxf(length, 3.0)
	var d := maxf(length * 0.8, 3.0)
	b.box(Vector3(0, 0.03, 0), Vector3(w, 0.06, d), Color("574634"))
	for i in int(w * d / 2.2):
		var x: float = b.rng.randf_range(-w * 0.5 + 0.5, w * 0.5 - 0.5)
		var z: float = b.rng.randf_range(-d * 0.5 + 0.5, d * 0.5 - 0.5)
		var s: float = b.rng.randf_range(0.7, 1.25)
		b.cyl(Vector3(x, 0.05, z), 0.36 * s, 0.3 * s, 0.4 * s, Color("e8883a").darkened(b.rng.randf_range(0.0, 0.12)), 7)
		b.box(Vector3(x, 0.5 * s, z), Vector3(0.08, 0.14, 0.08), Color("5a8a3a"))
		b.box(Vector3(x + 0.5, 0.08, z), Vector3(0.9, 0.04, 0.06), Color("4a8a3a"), b.rng.randf_range(-0.6, 0.6))


# ================================================================ trees and hay
static func _orchard_tree(b: TownKit.B, seed_v: int) -> void:
	var fruit: Color = [Color("d8403a"), Color("e8c040"), Color("8ac040"), Color("c05a8a")][seed_v % 4]
	var leaf := Color("4f8f3c")
	b.cyl(Vector3.ZERO, 0.24, 0.17, 1.6, Color("6a4a30"), 6)
	b.beam(Vector3(0, 1.4, 0), Vector3(0.7, 2.3, 0.2), 0.14, Color("6a4a30"))
	b.beam(Vector3(0, 1.4, 0), Vector3(-0.6, 2.2, -0.3), 0.14, Color("6a4a30"))
	for k in 6:
		var a := TAU * k / 6.0 + 0.4
		var p := Vector3(cos(a) * 0.9, 2.3 + (k % 2) * 0.4, sin(a) * 0.9)
		b.cyl(p - Vector3(0, 0.4, 0), 0.8, 0.5, 0.9, leaf.darkened(0.06 * (k % 3)), 6)
	b.cyl(Vector3(0, 2.6, 0), 1.0, 0.4, 1.0, leaf.lightened(0.05), 7)
	for k in 9:
		var a2: float = b.rng.randf() * TAU
		var r: float = b.rng.randf_range(0.6, 1.5)
		b.box(Vector3(cos(a2) * r, b.rng.randf_range(1.9, 3.0), sin(a2) * r), Vector3(0.14, 0.14, 0.14), fruit)
	b.solid(Vector3(0, 0.8, 0), Vector3(0.5, 1.6, 0.5))


static func _hay_stack(b: TownKit.B) -> void:
	var hay := Color("d8b860")
	b.cyl(Vector3.ZERO, 1.5, 1.4, 1.5, hay, 9)
	b.cyl(Vector3(0, 1.5, 0), 1.45, 0.0, 1.5, hay.darkened(0.06), 9, false, false)
	b.box(Vector3(0, 3.1, 0), Vector3(0.08, 0.4, 0.08), b.c("timber"))   # the pole through the middle
	b.solid(Vector3(0, 1.1, 0), Vector3(2.6, 2.2, 2.6))


static func _hay_wagon(b: TownKit.B) -> void:
	var tc := b.c("timber").lightened(0.05)
	b.box(Vector3(0, 0.75, 0), Vector3(3.2, 0.18, 1.7), tc)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			b.cyl(Vector3(sx * 1.05, 0.5, sz * 0.95 + sz * 0.05), 0.5, 0.5, 0.16, tc.darkened(0.25), 8)
	b.box(Vector3(0, 1.45, 0), Vector3(3.0, 1.2, 1.6), Color("d8b860"))
	b.box(Vector3(0, 2.1, 0), Vector3(2.4, 0.3, 1.3), Color("c8a850"))
	b.box(Vector3(1.9, 0.7, 0), Vector3(1.0, 0.1, 0.1), tc)   # the shaft
	b.solid(Vector3(0, 1.2, 0), Vector3(3.2, 2.4, 1.8))


static func _compost_heap(b: TownKit.B) -> void:
	b.cyl(Vector3.ZERO, 1.0, 0.5, 0.9, Color("4a3a28"), 7)
	for k in 6:
		b.box(Vector3(b.rng.randf_range(-0.6, 0.6), 0.85, b.rng.randf_range(-0.6, 0.6)), Vector3(0.18, 0.1, 0.18), [Color("6a8a3a"), Color("8a6a3a"), Color("a05a3a")][k % 3], b.rng.randf() * 3.0)
	b.solid(Vector3(0, 0.45, 0), Vector3(1.8, 0.9, 1.8))


static func _feed_sacks(b: TownKit.B) -> void:
	var col := Color("cdb890")
	for i in 3:
		b.cyl(Vector3(-0.5 + i * 0.5, 0.0, 0.0), 0.28, 0.24, 0.7, col.darkened(0.05 * i), 6)
		b.cone(Vector3(-0.5 + i * 0.5, 0.7, 0.0), 0.22, 0.12, col.darkened(0.2), 6)
	b.cyl(Vector3(0.0, 0.0, 0.5), 0.28, 0.24, 0.7, col, 6)
	b.cyl(Vector3(-0.25, 0.7, 0.2), 0.27, 0.23, 0.6, col.lightened(0.04), 6)
	b.solid(Vector3(0, 0.5, 0.2), Vector3(1.6, 1.0, 1.1))


# ================================================================ farm buildings
static func _silo(b: TownKit.B) -> void:
	var wall := b.c("timber").lightened(0.1)
	b.cyl(Vector3.ZERO, 1.9, 1.7, 8.0, wall, 12)
	for y in [1.5, 3.0, 4.5, 6.0]:
		b.cyl(Vector3(0, y, 0), 1.84 - y * 0.02, 1.84 - y * 0.02, 0.1, wall.darkened(0.3), 12, false, false)
	b.cone(Vector3(0, 8.0, 0), 2.0, 1.6, b.c("roof"), 12)
	b.box(Vector3(0, 9.7, 0), Vector3(0.1, 0.5, 0.1), b.c("timber"))
	b.door(Vector3(0, 0, 1.8), 0.9, 1.7, Vector3.BACK)
	b.solid(Vector3(0, 4.0, 0), Vector3(3.4, 8.0, 3.4))


static func _stable(b: TownKit.B) -> void:
	var w := 9.0
	var d := 4.6
	var wood := b.c("timber").lightened(0.1)
	var stone := b.c("stone")
	b.box(Vector3(0, 0.25, 0), Vector3(w + 0.2, 0.5, d + 0.2), stone)
	# back and side walls; the front is open stalls with half doors
	b.box(Vector3(0, 1.6, -d * 0.5), Vector3(w, 2.6, 0.25), wood)
	for sx in [-1, 1]:
		b.box(Vector3(sx * w * 0.5, 1.6, 0), Vector3(0.25, 2.6, d), wood)
	b.solid(Vector3(0, 1.6, -d * 0.5), Vector3(w, 2.6, 0.3))
	b.solid(Vector3(-w * 0.5, 1.6, 0), Vector3(0.3, 2.6, d))
	b.solid(Vector3(w * 0.5, 1.6, 0), Vector3(0.3, 2.6, d))
	var stalls := 3
	for i in stalls + 1:
		var x := -w * 0.5 + i * w / stalls
		b.box(Vector3(x, 1.3, d * 0.5 - 0.3), Vector3(0.22, 2.4, 0.22), wood.darkened(0.1))
		if i > 0 and i < stalls:
			b.box(Vector3(x, 0.8, -0.2), Vector3(0.12, 1.6, d - 0.8), wood.darkened(0.2))
	for i in stalls:
		var xc := -w * 0.5 + (i + 0.5) * w / stalls
		b.box(Vector3(xc, 0.8, d * 0.5 - 0.3), Vector3(w / stalls - 0.4, 0.14, 0.1), wood.darkened(0.15))
		b.box(Vector3(xc, 0.4, -d * 0.5 + 0.5), Vector3(1.0, 0.5, 0.5), Color("d8b860"))   # hay in the manger
	b.gable(Vector3(0, 2.9, 0), w + 0.8, d + 0.9, 1.5, b.c("roof"), wood.darkened(0.2))
	b.window(Vector3(0, 2.4, -d * 0.5 + 0.2), 0.6, 0.5, Vector3.BACK)
	b.light(Vector3(0, 2.0, 0.5), Color("ffb060"), 4.0)


static func _cowshed(b: TownKit.B) -> void:
	var w := 7.0
	var d := 4.4
	var wood := b.c("timber").lightened(0.05)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			b.box(Vector3(sx * w * 0.5, 1.4, sz * d * 0.5), Vector3(0.28, 2.8, 0.28), wood)
			b.solid(Vector3(sx * w * 0.5, 1.4, sz * d * 0.5), Vector3(0.32, 2.8, 0.32))
	b.box(Vector3(0, 1.4, -d * 0.5), Vector3(w, 2.2, 0.18), wood.darkened(0.1))
	b.solid(Vector3(0, 1.4, -d * 0.5), Vector3(w, 2.2, 0.3))
	b.gable(Vector3(0, 2.8, 0), w + 0.8, d + 0.9, 1.4, b.c("roof2"), wood.darkened(0.2))
	b.box(Vector3(0, 0.03, 0), Vector3(w, 0.06, d), Color("6a5a40"))
	b.box(Vector3(-1.5, 0.45, -d * 0.5 + 0.9), Vector3(2.2, 0.9, 0.7), wood)   # a trough
	b.box(Vector3(-1.5, 0.82, -d * 0.5 + 0.9), Vector3(2.0, 0.06, 0.5), Color("3b6470"))
	b.solid(Vector3(-1.5, 0.45, -d * 0.5 + 0.9), Vector3(2.2, 0.9, 0.7))
	b.box(Vector3(1.8, 0.5, -d * 0.5 + 0.8), Vector3(1.4, 1.0, 0.9), Color("d8b860"))
	b.solid(Vector3(1.8, 0.5, -d * 0.5 + 0.8), Vector3(1.4, 1.0, 0.9))


static func _chicken_coop(b: TownKit.B) -> void:
	var wood := b.c("timber").lightened(0.15)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			b.box(Vector3(sx * 0.8, 0.35, sz * 0.6), Vector3(0.12, 0.7, 0.12), wood.darkened(0.2))
	b.box(Vector3(0, 1.1, 0), Vector3(2.0, 0.8, 1.5), wood)
	b.gable(Vector3(0, 1.5, 0), 2.4, 1.9, 0.7, b.c("roof"), wood.darkened(0.2))
	b.box(Vector3(0, 0.95, 0.76), Vector3(0.4, 0.5, 0.05), Color("2a1a10"))   # pop hole
	b.beam(Vector3(0, 0.95, 1.5), Vector3(0, 0.1, 2.5), 0.4, wood.darkened(0.1))   # the ramp
	# a small wire run in front
	b.box(Vector3(0, 0.03, 3.0), Vector3(2.6, 0.06, 2.4), Color("8a7350"))
	for sx in [-1, 1]:
		b.box(Vector3(sx * 1.3, 0.45, 3.0), Vector3(0.05, 0.9, 2.4), wood.darkened(0.1))
	b.box(Vector3(0, 0.45, 4.2), Vector3(2.6, 0.9, 0.05), wood.darkened(0.1))
	b.solid(Vector3(0, 0.9, 0), Vector3(2.2, 1.8, 1.7))
	b.solid(Vector3(-1.3, 0.45, 3.0), Vector3(0.1, 0.9, 2.4))
	b.solid(Vector3(1.3, 0.45, 3.0), Vector3(0.1, 0.9, 2.4))
	b.solid(Vector3(0, 0.45, 4.2), Vector3(2.6, 0.9, 0.1))


static func _tool_shed(b: TownKit.B) -> void:
	var wood := b.c("timber").lightened(0.1)
	b.box(Vector3(0, 1.1, 0), Vector3(3.0, 2.2, 2.4), wood)
	b.door(Vector3(0, 0, 1.2), 0.9, 1.7, Vector3.BACK)
	b.window(Vector3(-1.0, 1.4, 1.2), 0.5, 0.5, Vector3.BACK)
	# lean-to roof, high at the back
	b.quad(Vector3(-1.8, 2.5, 1.4), Vector3(1.8, 2.5, 1.4), Vector3(1.8, 2.9, -1.4), Vector3(-1.8, 2.9, -1.4), b.c("roof"))
	b.quad(Vector3(-1.8, 2.45, 1.4), Vector3(-1.8, 2.85, -1.4), Vector3(1.8, 2.85, -1.4), Vector3(1.8, 2.45, 1.4), b.c("roof").darkened(0.3))
	b.box(Vector3(2.0, 0.7, 0.3), Vector3(0.1, 1.4, 0.1), wood)           # a rake and a spade leaning outside
	b.box(Vector3(2.0, 1.3, 0.3), Vector3(0.5, 0.06, 0.08), Color("9a9a9a"))
	b.solid(Vector3(0, 1.1, 0), Vector3(3.0, 2.2, 2.4))


static func _dovecote(b: TownKit.B) -> void:
	var wall := b.c("stone").lightened(0.1)
	b.cyl(Vector3.ZERO, 1.2, 1.0, 3.6, wall, 8)
	b.cyl(Vector3(0, 3.6, 0), 1.45, 1.45, 0.14, b.c("timber"), 8, false, false)
	for k in 4:
		var a := TAU * k / 4.0
		b.box(Vector3(cos(a) * 1.05, 3.0, sin(a) * 1.05), Vector3(0.3, 0.3, 0.15), Color("2a1a10"), -a + PI * 0.5)
	b.cone(Vector3(0, 3.7, 0), 1.7, 1.7, b.c("roof"), 8)
	b.door(Vector3(0, 0, 1.15), 0.7, 1.5, Vector3.BACK)
	b.solid(Vector3(0, 1.8, 0), Vector3(2.4, 3.6, 2.4))


static func _beehives(b: TownKit.B) -> void:
	var straw := Color("d8b860")
	for i in 3:
		var x := -1.0 + i * 1.0
		var z := 0.2 * (i % 2)
		b.box(Vector3(x, 0.35, z), Vector3(0.8, 0.07, 0.8), b.c("timber"))
		b.cyl(Vector3(x, 0.4, z), 0.34, 0.3, 0.3, straw, 8)
		b.cyl(Vector3(x, 0.7, z), 0.3, 0.2, 0.25, straw.darkened(0.05), 8)
		b.cyl(Vector3(x, 0.95, z), 0.2, 0.0, 0.2, straw.darkened(0.12), 8, false, false)
		b.box(Vector3(x, 0.52, z + 0.31), Vector3(0.12, 0.05, 0.03), Color("2a1a10"))
		for leg in [Vector3(-0.3, 0, -0.3), Vector3(0.3, 0, -0.3), Vector3(-0.3, 0, 0.3), Vector3(0.3, 0, 0.3)]:
			b.box(Vector3(x, 0.17, z) + leg, Vector3(0.07, 0.34, 0.07), b.c("timber").darkened(0.2))
	b.solid(Vector3(0, 0.5, 0.1), Vector3(3.0, 1.0, 1.0))


# ================================================================ pens, gates, hedges
## A fenced pen with a gate gap on the +Z side. Holds animals of the given kind (decoration, no collision).
static func _pen(b: TownKit.B, length: float, animal: String) -> void:
	var w := maxf(length, 5.0)
	var d := maxf(length * 0.75, 4.0)
	var tc := b.c("timber").lightened(0.2)
	b.box(Vector3(0, 0.02, 0), Vector3(w, 0.04, d), Color("6a5a3a") if animal != "pig" else Color("5a4430"))
	var gate := 1.6
	_rail(b, Vector3(-w * 0.5, 0, -d * 0.5), Vector3(w * 0.5, 0, -d * 0.5), tc)
	_rail(b, Vector3(-w * 0.5, 0, -d * 0.5), Vector3(-w * 0.5, 0, d * 0.5), tc)
	_rail(b, Vector3(w * 0.5, 0, -d * 0.5), Vector3(w * 0.5, 0, d * 0.5), tc)
	_rail(b, Vector3(-w * 0.5, 0, d * 0.5), Vector3(-gate * 0.5, 0, d * 0.5), tc)
	_rail(b, Vector3(gate * 0.5, 0, d * 0.5), Vector3(w * 0.5, 0, d * 0.5), tc)
	b.box(Vector3(-w * 0.25, 0.3, -d * 0.5 + 0.7), Vector3(1.6, 0.6, 0.6), tc)           # trough
	b.box(Vector3(-w * 0.25, 0.58, -d * 0.5 + 0.7), Vector3(1.4, 0.04, 0.4), Color("3b6470"))
	b.solid(Vector3(-w * 0.25, 0.3, -d * 0.5 + 0.7), Vector3(1.6, 0.6, 0.6))
	b.box(Vector3(w * 0.25, 0.35, -d * 0.5 + 0.8), Vector3(1.2, 0.7, 0.8), Color("d8b860"))
	b.solid(Vector3(w * 0.25, 0.35, -d * 0.5 + 0.8), Vector3(1.2, 0.7, 0.8))
	var count := 3 if animal != "horse" else 2
	for i in count:
		_animal_geo(b, animal, Vector3(b.rng.randf_range(-w * 0.35, w * 0.35), 0.0, b.rng.randf_range(-d * 0.2, d * 0.25)), b.rng.randf() * TAU, i)


static func _rail(b: TownKit.B, a: Vector3, c: Vector3, tc: Color) -> void:
	var d := c - a
	var len := d.length()
	var n := maxi(1, int(len / 2.0))
	var yaw := atan2(d.x, d.z)
	for i in n + 1:
		b.box(a + d * (float(i) / n) + Vector3(0, 0.55, 0), Vector3(0.14, 1.1, 0.14), tc)
	for y in [0.45, 0.85]:
		b.box(a + d * 0.5 + Vector3(0, y, 0), Vector3(0.07, 0.1, len), tc.darkened(0.1), yaw)
	var mid := a + d * 0.5 + Vector3(0, 0.6, 0)
	b.solid(mid, Vector3(0.3, 1.2, len), yaw)


## A field gate with two posts. variation of length: how wide the opening is.
static func _farm_gate(b: TownKit.B, length: float) -> void:
	var w := maxf(length, 2.0)
	var tc := b.c("timber").lightened(0.2)
	for sx in [-1, 1]:
		b.box(Vector3(sx * (w * 0.5 + 0.1), 0.8, 0), Vector3(0.22, 1.6, 0.22), tc.darkened(0.1))
		b.solid(Vector3(sx * (w * 0.5 + 0.1), 0.8, 0), Vector3(0.26, 1.6, 0.26))
	for y in [0.35, 0.65, 0.95, 1.25]:
		b.box(Vector3(0, y, 0), Vector3(w, 0.09, 0.06), tc)
	b.beam(Vector3(-w * 0.5, 0.3, 0), Vector3(w * 0.5, 1.28, 0), 0.07, tc.darkened(0.1))
	b.box(Vector3(-w * 0.5 + 0.05, 0.8, 0), Vector3(0.08, 1.0, 0.07), tc)
	b.box(Vector3(w * 0.5 - 0.05, 0.8, 0), Vector3(0.08, 1.0, 0.07), tc)


static func _hedge(b: TownKit.B, length: float) -> void:
	var leaf := Color("3f7a34")
	var n := maxi(1, int(length / 1.1))
	for i in n:
		var x := -length * 0.5 + (i + 0.5) * length / n
		b.cyl(Vector3(x, 0.0, 0.0), 0.62, 0.5, 1.0 + 0.15 * (i % 3), leaf.darkened(0.05 * (i % 3)), 6)
		b.cyl(Vector3(x, 0.8, 0.05), 0.48, 0.2, 0.4, leaf.lightened(0.06), 6)
	b.solid(Vector3(0, 0.55, 0), Vector3(length, 1.1, 1.0))


# ================================================================ animals (decoration: they stand still, you walk through them)
static func _animal(b: TownKit.B, kind: String, seed_v: int) -> void:
	_animal_geo(b, kind, Vector3.ZERO, 0.0, seed_v)


static func _animal_geo(b: TownKit.B, kind: String, at: Vector3, yaw: float, v: int) -> void:
	var rot := Basis(Vector3.UP, yaw)
	var P := func(p: Vector3) -> Vector3: return at + rot * p
	match kind:
		"cow":
			var coat: Color = [Color("f0ece4"), Color("6a4a30"), Color("c8a070")][v % 3]
			b.box(P.call(Vector3(0, 1.0, 0)), Vector3(0.9, 0.85, 1.9), coat, yaw)
			b.box(P.call(Vector3(0, 1.15, 1.2)), Vector3(0.6, 0.6, 0.6), coat.darkened(0.04), yaw)
			b.box(P.call(Vector3(0, 1.0, 1.55)), Vector3(0.4, 0.3, 0.2), Color("e8b0a0"), yaw)
			for sx in [-1, 1]:
				b.box(P.call(Vector3(sx * 0.38, 0.4, 0.6)), Vector3(0.18, 0.8, 0.18), coat.darkened(0.15), yaw)
				b.box(P.call(Vector3(sx * 0.38, 0.4, -0.6)), Vector3(0.18, 0.8, 0.18), coat.darkened(0.15), yaw)
				b.box(P.call(Vector3(sx * 0.3, 1.5, 1.15)), Vector3(0.12, 0.08, 0.1), Color("e8e0c0"), yaw)
			if v % 3 == 0:
				b.box(P.call(Vector3(0.2, 1.1, 0.1)), Vector3(0.4, 0.5, 0.5), Color("4a3a30"), yaw)
			b.box(P.call(Vector3(0, 1.1, -1.05)), Vector3(0.08, 0.7, 0.08), coat.darkened(0.3), yaw)
		"sheep":
			var wool := Color("f0ece0")
			b.cyl(P.call(Vector3(0, 0.35, 0)), 0.45, 0.4, 0.6, wool, 7)
			b.box(P.call(Vector3(0, 0.7, 0.55)), Vector3(0.28, 0.3, 0.3), Color("3a3028"), yaw)
			for sx in [-1, 1]:
				b.box(P.call(Vector3(sx * 0.2, 0.15, 0.25)), Vector3(0.09, 0.3, 0.09), Color("3a3028"), yaw)
				b.box(P.call(Vector3(sx * 0.2, 0.15, -0.25)), Vector3(0.09, 0.3, 0.09), Color("3a3028"), yaw)
		"pig":
			var skin := Color("e8a8a0")
			b.box(P.call(Vector3(0, 0.55, 0)), Vector3(0.65, 0.6, 1.1), skin, yaw)
			b.box(P.call(Vector3(0, 0.6, 0.65)), Vector3(0.45, 0.45, 0.4), skin.darkened(0.04), yaw)
			b.box(P.call(Vector3(0, 0.52, 0.9)), Vector3(0.22, 0.18, 0.1), skin.darkened(0.15), yaw)
			for sx in [-1, 1]:
				b.box(P.call(Vector3(sx * 0.22, 0.15, 0.35)), Vector3(0.12, 0.3, 0.12), skin.darkened(0.1), yaw)
				b.box(P.call(Vector3(sx * 0.22, 0.15, -0.35)), Vector3(0.12, 0.3, 0.12), skin.darkened(0.1), yaw)
				b.box(P.call(Vector3(sx * 0.15, 0.88, 0.62)), Vector3(0.12, 0.12, 0.05), skin.darkened(0.2), yaw)
		"chicken":
			var fe: Color = [Color("f0e8d8"), Color("a05a30"), Color("3a3028")][v % 3]
			b.box(P.call(Vector3(0, 0.3, 0)), Vector3(0.28, 0.26, 0.4), fe, yaw)
			b.box(P.call(Vector3(0, 0.5, 0.2)), Vector3(0.14, 0.2, 0.14), fe, yaw)
			b.box(P.call(Vector3(0, 0.6, 0.2)), Vector3(0.05, 0.08, 0.09), Color("d8403a"), yaw)
			b.box(P.call(Vector3(0, 0.5, 0.3)), Vector3(0.05, 0.05, 0.1), Color("e8b040"), yaw)
			b.box(P.call(Vector3(0, 0.38, -0.25)), Vector3(0.06, 0.25, 0.14), fe.darkened(0.15), yaw, false, 0.5)
			b.box(P.call(Vector3(0, 0.1, 0)), Vector3(0.18, 0.2, 0.04), Color("e8b040"), yaw)
		"horse":
			var coat2: Color = [Color("7a4a2a"), Color("2e2a28"), Color("c8c0b0"), Color("a07040")][v % 4]
			b.box(P.call(Vector3(0, 1.3, 0)), Vector3(0.7, 0.8, 1.7), coat2, yaw)
			b.beam(P.call(Vector3(0, 1.5, 0.8)), P.call(Vector3(0, 2.15, 1.2)), 0.38, coat2.darkened(0.04))
			b.box(P.call(Vector3(0, 2.1, 1.45)), Vector3(0.28, 0.32, 0.55), coat2.darkened(0.06), yaw)
			b.box(P.call(Vector3(0, 1.9, 0.95)), Vector3(0.08, 0.5, 0.1), coat2.darkened(0.35), yaw)
			b.box(P.call(Vector3(0, 1.3, -0.95)), Vector3(0.1, 0.8, 0.12), coat2.darkened(0.35), yaw)
			for sx in [-1, 1]:
				b.box(P.call(Vector3(sx * 0.25, 0.5, 0.65)), Vector3(0.14, 1.0, 0.14), coat2.darkened(0.12), yaw)
				b.box(P.call(Vector3(sx * 0.25, 0.5, -0.65)), Vector3(0.14, 1.0, 0.14), coat2.darkened(0.12), yaw)
		"goat":
			var gc := Color("c8bca8") if v % 2 == 0 else Color("6a5a48")
			b.box(P.call(Vector3(0, 0.6, 0)), Vector3(0.45, 0.5, 0.9), gc, yaw)
			b.box(P.call(Vector3(0, 0.85, 0.55)), Vector3(0.28, 0.32, 0.35), gc.darkened(0.05), yaw)
			b.box(P.call(Vector3(0, 0.7, 0.78)), Vector3(0.1, 0.1, 0.1), gc.darkened(0.2), yaw)
			for sx in [-1, 1]:
				b.box(P.call(Vector3(sx * 0.1, 1.12, 0.5)), Vector3(0.05, 0.22, 0.05), Color("3a3028"), yaw, false, -0.3)
				b.box(P.call(Vector3(sx * 0.16, 0.22, 0.3)), Vector3(0.08, 0.44, 0.08), gc.darkened(0.2), yaw)
				b.box(P.call(Vector3(sx * 0.16, 0.22, -0.3)), Vector3(0.08, 0.44, 0.08), gc.darkened(0.2), yaw)
