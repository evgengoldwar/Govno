extends Node2D
## Animated tiles: liquids, flame walls, seal gates, boss locks.

const C = preload("res://scripts/consts.gd")
const T := C.TILE

var level = null
var tiles: Array = []  # Vector3i(gx, gy, code)
var t := 0.0
var view := Rect2()


func refresh(lv) -> void:
	level = lv
	tiles.clear()
	for ly in range(lv.h):
		for lx in range(lv.w):
			var code: int = lv.cells[ly * lv.w + lx]
			if C.is_liquid(code) or code == C.T_FLAME or code == C.T_SEAL or code == C.T_LOCK:
				tiles.append(Vector3i(lv.ox + lx, lv.oy + ly, code))
	queue_redraw()


func tick(dt: float, view_rect: Rect2) -> void:
	t += dt
	view = view_rect.grow(T * 2)
	queue_redraw()


func _draw() -> void:
	if level == null:
		return
	for v in tiles:
		var tl: Vector3i = v
		var x := float(tl.x * T)
		var y := float(tl.y * T)
		if not view.has_point(Vector2(x, y)):
			continue
		var code: int = level.tget(tl.x, tl.y)
		if code != tl.z:
			continue
		match code:
			C.T_WATER:
				_liquid(tl, x, y, Color(0.18, 0.45, 0.9, 0.55), Color(0.55, 0.8, 1.0, 0.9), false)
			C.T_LAVA:
				_liquid(tl, x, y, Color(0.95, 0.32, 0.06, 0.95), Color(1.0, 0.85, 0.3), true)
			C.T_TOXIC:
				_liquid(tl, x, y, Color(0.35, 0.7, 0.15, 0.8), Color(0.75, 1.0, 0.4), true)
			C.T_FLAME:
				_flame(tl, x, y)
			C.T_SEAL:
				_seal(tl, x, y)
			C.T_LOCK:
				var a := 0.6 + 0.3 * sin(t * 6.0)
				draw_rect(Rect2(x, y, T, T), Color(0.25, 0.05, 0.08))
				for i in range(3):
					draw_rect(Rect2(x + 4 + i * 10, y, 4, T), Color(1.0, 0.25, 0.3, a))


func _liquid(tl: Vector3i, x: float, y: float, body: Color, surf: Color, bubbles: bool) -> void:
	var above: int = level.tget(tl.x, tl.y - 1)
	if above != tl.z:
		var pts := PackedVector2Array()
		var steps := 8
		for i in range(steps + 1):
			var px := x + T * float(i) / steps
			pts.append(Vector2(px, y + 5 + sin(t * 2.5 + px * 0.08) * 2.5))
		pts.append(Vector2(x + T, y + T))
		pts.append(Vector2(x, y + T))
		draw_colored_polygon(pts, body)
		var line := PackedVector2Array()
		for i in range(steps + 1):
			line.append(pts[i])
		draw_polyline(line, surf, 2.0)
		if tl.z == C.T_LAVA:
			draw_rect(Rect2(x, y - 10, T, 10), Color(1.0, 0.4, 0.1, 0.12))
	else:
		draw_rect(Rect2(x, y, T, T), body)
	if bubbles:
		var hh := absi(tl.x * 31 + tl.y * 17) % 100
		var ph := fmod(t * 0.8 + hh * 0.01, 1.0)
		var bx := x + 6 + hh % 20
		var by := y + T - ph * T
		draw_circle(Vector2(bx, by), 2.0 + (hh % 3), Color(surf.r, surf.g, surf.b, 0.6 * (1.0 - ph)))


func _flame(tl: Vector3i, x: float, y: float) -> void:
	draw_rect(Rect2(x, y, T, T), Color(0.55, 0.08, 0.02, 0.9))
	for i in range(3):
		var ph := t * 9.0 + tl.y * 1.7 + i * 2.1
		var hgt := 14.0 + 8.0 * sin(ph)
		var bx := x + 4 + i * 10
		var col := Color(1.0, 0.55 + 0.2 * sin(ph * 0.7), 0.1)
		draw_colored_polygon(PackedVector2Array([
			Vector2(bx - 3, y + T), Vector2(bx + 4 + sin(ph) * 2, y + T - hgt - 10), Vector2(bx + 10, y + T)]), col)
		draw_colored_polygon(PackedVector2Array([
			Vector2(bx, y + T), Vector2(bx + 4, y + T - hgt), Vector2(bx + 7, y + T)]), Color(1.0, 0.9, 0.4))
	draw_rect(Rect2(x - 4, y, T + 8, T), Color(1.0, 0.4, 0.1, 0.08))


func _seal(tl: Vector3i, x: float, y: float) -> void:
	var a := 0.5 + 0.35 * sin(t * 3.0 + tl.x * 0.5)
	draw_rect(Rect2(x, y, T, T), Color(0.18, 0.05, 0.25))
	draw_rect(Rect2(x + 2, y + 2, T - 4, T - 4), Color(0.6, 0.2, 0.9, a * 0.6))
	var cc := Vector2(x + T / 2.0, y + T / 2.0)
	draw_arc(cc, 9.0, t, t + TAU * 0.75, 12, Color(1.0, 0.6, 1.0, a), 2.0)
	draw_circle(cc, 3.0, Color(1.0, 0.8, 1.0, a))
