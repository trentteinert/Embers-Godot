class_name LayoutMap
extends RefCounted
## The painted island plan (see assets/thornvale_world_*.png) as game data: sea, inland water, snow, rock, zone
## and road masks, plus the pin positions. Everything is in image units (u, v in 0..1) and maps onto the
## 1200 x 1200 cell world with the town at the middle.

const CU := 0.515        # image position that sits on the world's centre cell (Hearthmoor's plaza)
const CV := 0.53
const SX := 1180.0       # cells across the whole image
const SY := 790.0
const W := 1200
const WORLD_CX := 600.0

var sea := PackedByteArray()
var inl := PackedByteArray()
var snow := PackedByteArray()
var rock := PackedByteArray()
var zone := PackedByteArray()
var road := PackedByteArray()


func _init() -> void:
	var raw := Marshalls.base64_to_raw(LayoutData.BLOB).decompress(540000, FileAccess.COMPRESSION_DEFLATE)
	var n := LayoutData.GX * LayoutData.GY
	sea = raw.slice(0, n)
	inl = raw.slice(n, n * 2)
	snow = raw.slice(n * 2, n * 3)
	rock = raw.slice(n * 3, n * 4)
	zone = raw.slice(n * 4, n * 5)
	road = raw.slice(n * 5, n * 5 + LayoutData.PX * LayoutData.PY)


func cell_uv(x: float, y: float) -> Vector2:
	return Vector2(CU + (x - WORLD_CX) / SX, CV + (y - WORLD_CX) / SY)


func uv_cell(uv: Vector2) -> Vector2:
	return Vector2(WORLD_CX + (uv.x - CU) * SX, WORLD_CX + (uv.y - CV) * SY)


func pin(name: String) -> Vector2i:
	var c := uv_cell(LayoutData.PINS[name])
	return Vector2i(roundi(c.x), roundi(c.y))


## Bilinear sample of a 0..255 mask, 0..1. Outside the picture is `outside`.
func samp(a: PackedByteArray, x: float, y: float, outside := 0.0) -> float:
	var uv := cell_uv(x, y)
	var fx := uv.x * LayoutData.GX - 0.5
	var fy := uv.y * LayoutData.GY - 0.5
	if fx < -1.0 or fy < -1.0 or fx > LayoutData.GX or fy > LayoutData.GY:
		return outside
	var x0 := floori(fx)
	var y0 := floori(fy)
	var tx := fx - x0
	var ty := fy - y0
	var v00 := _at(a, x0, y0, outside)
	var v10 := _at(a, x0 + 1, y0, outside)
	var v01 := _at(a, x0, y0 + 1, outside)
	var v11 := _at(a, x0 + 1, y0 + 1, outside)
	return lerpf(lerpf(v00, v10, tx), lerpf(v01, v11, tx), ty)


func _at(a: PackedByteArray, x: int, y: int, outside: float) -> float:
	if x < 0 or y < 0 or x >= LayoutData.GX or y >= LayoutData.GY:
		return outside
	return float(a[y * LayoutData.GX + x]) / 255.0


## Zone index at a world cell (nearest node), or -1 off the picture.
func zone_at(x: float, y: float) -> int:
	var uv := cell_uv(x, y)
	var ix := int(uv.x * LayoutData.GX)
	var iy := int(uv.y * LayoutData.GY)
	if ix < 0 or iy < 0 or ix >= LayoutData.GX or iy >= LayoutData.GY:
		return -1
	return int(zone[iy * LayoutData.GX + ix])
