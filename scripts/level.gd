extends RefCounted
## Tile data and collision for the currently loaded room.
## Everything works in global coordinates: room tile origin is (ox, oy).

const C = preload("res://scripts/consts.gd")
const T := C.TILE

var data: Dictionary = {}
var id := ""
var biome := "castle"
var ox := 0
var oy := 0
var w := 0
var h := 0
var cells := PackedByteArray()


func load_room(r: Dictionary, removed: Dictionary) -> void:
	data = r
	id = r["id"]
	biome = r["biome"]
	ox = int(r["gx"]) * C.CW
	oy = int(r["gy"]) * C.CH
	w = int(r["w"]) * C.CW
	h = int(r["h"]) * C.CH
	cells = PackedByteArray()
	cells.resize(w * h)
	var rows: Array = r["tiles"]
	for y in range(h):
		var row: String = rows[y]
		for x in range(w):
			cells[y * w + x] = row.unicode_at(x)
	for k in removed.keys():
		var p: PackedStringArray = String(k).split(",")
		var lx := int(p[0])
		var ly := int(p[1])
		if lx >= 0 and lx < w and ly >= 0 and ly < h:
			cells[ly * w + lx] = C.T_EMPTY


func rect_px() -> Rect2:
	return Rect2(ox * T, oy * T, w * T, h * T)


func contains_px(p: Vector2) -> bool:
	return rect_px().has_point(p)


func tget(gx: int, gy: int) -> int:
	var lx := clampi(gx - ox, 0, w - 1)
	var ly := clampi(gy - oy, 0, h - 1)
	var code: int = cells[ly * w + lx]
	# beyond the border the room continues as its edge tile, except platforms
	if code == C.T_ONEWAY and (ly != gy - oy or lx != gx - ox):
		return C.T_EMPTY
	return code


func tset(gx: int, gy: int, code: int) -> void:
	var lx := gx - ox
	var ly := gy - oy
	if lx >= 0 and lx < w and ly >= 0 and ly < h:
		cells[ly * w + lx] = code


func at_px(p: Vector2) -> int:
	return tget(int(floor(p.x / T)), int(floor(p.y / T)))


func solid_px(p: Vector2) -> bool:
	return C.is_solid(at_px(p))


## Move an axis-aligned box. Returns {pos, vel, floor, ceil, wall}
func move_box(pos: Vector2, half: Vector2, vel: Vector2, dt: float, drop := false) -> Dictionary:
	var res := {"pos": pos, "vel": vel, "floor": false, "ceil": false, "wall": 0, "floor_code": 0}
	var p := pos
	var v := vel
	# --- X
	var dx := v.x * dt
	if dx != 0.0:
		var nx := p.x + dx
		var top := int(floor((p.y - half.y + 1.0) / T))
		var bot := int(floor((p.y + half.y - 1.0) / T))
		if dx > 0.0:
			var old_edge := p.x + half.x
			var tx := int(floor((nx + half.x) / T))
			var hit := false
			for ty in range(top, bot + 1):
				if C.is_solid(tget(tx, ty)) and old_edge <= tx * T + 0.5:
					hit = true
					break
			if hit:
				nx = tx * T - half.x - 0.01
				v.x = 0.0
				res["wall"] = 1
		else:
			var old_edge2 := p.x - half.x
			var tx2 := int(floor((nx - half.x) / T))
			var hit2 := false
			for ty in range(top, bot + 1):
				if C.is_solid(tget(tx2, ty)) and old_edge2 >= (tx2 + 1) * T - 0.5:
					hit2 = true
					break
			if hit2:
				nx = (tx2 + 1) * T + half.x + 0.01
				v.x = 0.0
				res["wall"] = -1
		p.x = nx
	# --- Y
	var dy := v.y * dt
	if dy != 0.0:
		var ny := p.y + dy
		var left := int(floor((p.x - half.x + 1.0) / T))
		var right := int(floor((p.x + half.x - 1.0) / T))
		if dy > 0.0:
			var old_b := p.y + half.y
			var ty3 := int(floor((ny + half.y) / T))
			var hit3 := false
			var code_hit := 0
			for tx3 in range(left, right + 1):
				var c := tget(tx3, ty3)
				if C.is_solid(c) and old_b <= ty3 * T + 0.5:
					hit3 = true
					code_hit = c
					break
				if c == C.T_ONEWAY and not drop and old_b <= ty3 * T + 0.5:
					hit3 = true
					code_hit = c
			if hit3:
				ny = ty3 * T - half.y - 0.01
				v.y = 0.0
				res["floor"] = true
				res["floor_code"] = code_hit
		else:
			var old_t := p.y - half.y
			var ty4 := int(floor((ny - half.y) / T))
			var hit4 := false
			for tx4 in range(left, right + 1):
				if C.is_solid(tget(tx4, ty4)) and old_t >= (ty4 + 1) * T - 0.5:
					hit4 = true
					break
			if hit4:
				ny = (ty4 + 1) * T + half.y + 0.01
				v.y = 0.0
				res["ceil"] = true
		p.y = ny
	res["pos"] = p
	res["vel"] = v
	return res


## Is there ground under a point (for edge detection of walkers)?
func ground_at(px: float, py: float) -> bool:
	var c := at_px(Vector2(px, py))
	return C.is_solid(c) or c == C.T_ONEWAY


## Returns true if any tile of the given code overlaps the box.
func box_has(pos: Vector2, half: Vector2, code: int, shrink := 2.0) -> bool:
	var x0 := int(floor((pos.x - half.x + shrink) / T))
	var x1 := int(floor((pos.x + half.x - shrink) / T))
	var y0 := int(floor((pos.y - half.y + shrink) / T))
	var y1 := int(floor((pos.y + half.y - shrink) / T))
	for ty in range(y0, y1 + 1):
		for tx in range(x0, x1 + 1):
			if tget(tx, ty) == code:
				return true
	return false


## Spikes: only lower part of the tile hurts.
func box_spikes(pos: Vector2, half: Vector2) -> bool:
	var x0 := int(floor((pos.x - half.x + 3.0) / T))
	var x1 := int(floor((pos.x + half.x - 3.0) / T))
	var yb := pos.y + half.y
	var ty := int(floor((yb - 1.0) / T))
	for tx in range(x0, x1 + 1):
		if tget(tx, ty) == C.T_SPIKE and yb > ty * T + T * 0.45:
			return true
	return false


## Flood-fill destroy a gate group starting at tile. Returns list of local "x,y" keys.
func destroy_group(gx: int, gy: int) -> Array:
	var code := tget(gx, gy)
	var out: Array = []
	var stack: Array = [Vector2i(gx, gy)]
	var seen := {}
	while stack.size() > 0:
		var c: Vector2i = stack.pop_back()
		if seen.has(c):
			continue
		seen[c] = true
		var lx := c.x - ox
		var ly := c.y - oy
		if lx < 0 or ly < 0 or lx >= w or ly >= h:
			continue
		if cells[ly * w + lx] != code:
			continue
		cells[ly * w + lx] = C.T_EMPTY
		out.append("%d,%d" % [lx, ly])
		stack.append(Vector2i(c.x + 1, c.y))
		stack.append(Vector2i(c.x - 1, c.y))
		stack.append(Vector2i(c.x, c.y + 1))
		stack.append(Vector2i(c.x, c.y - 1))
	return out


## Fill every walkable opening on the room border with lock tiles (boss fights).
func lock_doors() -> Array:
	var locked: Array = []
	for x in range(w):
		for y in [0, h - 1]:
			var c: int = cells[y * w + x]
			if not C.is_solid(c):
				locked.append(Vector3i(x, y, c))
				cells[y * w + x] = C.T_LOCK
			if y == h - 1 and h >= 2:
				var c2: int = cells[(h - 2) * w + x]
				if c == C.T_ONEWAY and not C.is_solid(c2):
					locked.append(Vector3i(x, h - 2, c2))
					cells[(h - 2) * w + x] = C.T_LOCK
	for y in range(1, h - 1):
		for x in [0, w - 1]:
			var c3: int = cells[y * w + x]
			if not C.is_solid(c3):
				locked.append(Vector3i(x, y, c3))
				cells[y * w + x] = C.T_LOCK
	return locked


func unlock(locked: Array) -> void:
	for v in locked:
		var p: Vector3i = v
		cells[p.y * w + p.x] = p.z


## Simple line of sight between two points (solid tiles block).
func los(a: Vector2, b: Vector2) -> bool:
	var d := b - a
	var n := int(d.length() / 12.0) + 1
	for i in range(1, n):
		var p := a + d * (float(i) / n)
		if solid_px(p):
			return false
	return true
