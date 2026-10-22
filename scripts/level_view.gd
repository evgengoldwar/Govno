extends Node2D
## Draws static tiles of the current room. Redrawn only when tiles change.

const C = preload("res://scripts/consts.gd")
const T := C.TILE

var level = null


func refresh(lv) -> void:
	level = lv
	queue_redraw()


func _hash(x: int, y: int) -> int:
	var hh := (x * 73856093) ^ (y * 19349663)
	return absi(hh) % 1000


func _open(code: int) -> bool:
	return not C.is_solid(code)


func _draw() -> void:
	if level == null:
		return
	var pal: Dictionary = C.BIOME[level.biome]
	var wall: Color = pal["wall"]
	var edge: Color = pal["edge"]
	var dark: Color = pal["dark"]
	var plat: Color = pal["plat"]
	for ly in range(level.h):
		for lx in range(level.w):
			var gx: int = level.ox + lx
			var gy: int = level.oy + ly
			var code: int = level.cells[ly * level.w + lx]
			var x := float(gx * T)
			var y := float(gy * T)
			if code == C.T_SOLID:
				_draw_solid(gx, gy, x, y, wall, edge, dark, level.biome)
			elif code == C.T_ONEWAY:
				draw_rect(Rect2(x, y, T, 7), plat)
				draw_rect(Rect2(x, y, T, 2), plat.lightened(0.3))
				draw_rect(Rect2(x, y + 7, T, 2), plat.darkened(0.45))
				if lx % 3 == 0:
					draw_rect(Rect2(x + 4, y + 9, 3, 5), plat.darkened(0.3))
			elif code == C.T_WOOD:
				_draw_wood(x, y, level.biome)
			elif code == C.T_GRATE:
				draw_rect(Rect2(x, y, T, T), Color(0.12, 0.16, 0.13))
				for i in range(4):
					draw_rect(Rect2(x + 3 + i * 8, y, 4, T), Color(0.38, 0.55, 0.33))
					draw_rect(Rect2(x + 3 + i * 8, y, 1, T), Color(0.55, 0.75, 0.45))
				draw_rect(Rect2(x, y + 13, T, 4), Color(0.3, 0.42, 0.27))
			elif code == C.T_CRACK:
				draw_rect(Rect2(x, y, T, T), Color(0.48, 0.42, 0.36))
				draw_rect(Rect2(x + 1, y + 1, T - 2, T - 2), Color(0.56, 0.5, 0.42))
				var hh := _hash(gx, gy)
				var a := Vector2(x + 6 + hh % 10, y + 2)
				var b := Vector2(x + 16, y + 14 + hh % 6)
				var c2 := Vector2(x + 10 + hh % 12, y + T - 2)
				draw_polyline(PackedVector2Array([a, b, c2]), Color(0.22, 0.18, 0.15), 2.0)
				draw_line(b, Vector2(x + T - 3, y + 10 + hh % 9), Color(0.22, 0.18, 0.15), 1.5)
			elif code == C.T_SPIKE:
				var sc := Color(0.86, 0.86, 0.9) if level.biome != "hell" else Color(0.95, 0.75, 0.65)
				for i in range(3):
					var bx := x + i * (T / 3.0)
					var pts := PackedVector2Array([
						Vector2(bx + 1, y + T), Vector2(bx + T / 6.0, y + 8), Vector2(bx + T / 3.0 - 1, y + T)])
					draw_colored_polygon(pts, sc.darkened(0.35))
					draw_line(Vector2(bx + T / 6.0, y + 8), Vector2(bx + 2, y + T), sc, 1.5)


func _draw_solid(gx: int, gy: int, x: float, y: float, wall: Color, edge: Color, dark: Color, biome: String) -> void:
	draw_rect(Rect2(x, y, T, T), wall)
	var hh := _hash(gx, gy)
	if biome == "castle":
		var line := wall.darkened(0.25)
		draw_rect(Rect2(x, y + T / 2.0 - 1, T, 2), line)
		var off := 0.0 if gy % 2 == 0 else T / 2.0
		draw_rect(Rect2(x + off, y, 2, T / 2.0), line)
		draw_rect(Rect2(x + fmod(off + T / 2.0, T), y + T / 2.0, 2, T / 2.0), line)
	elif biome == "cave":
		if hh < 450:
			draw_circle(Vector2(x + 6 + hh % 20, y + 8 + (hh / 20) % 16), 2.0 + hh % 3, wall.lightened(0.08))
		if hh % 7 == 0:
			draw_circle(Vector2(x + 18, y + 20), 3.0, Color(0.35, 0.9, 0.8, 0.35))
	else:
		if hh < 160:
			draw_line(Vector2(x + 4 + hh % 12, y + 4), Vector2(x + 14 + hh % 10, y + T - 6), Color(1.0, 0.4, 0.1, 0.35), 2.0)
		elif hh < 500:
			draw_rect(Rect2(x + hh % 22, y + (hh / 22) % 22, 5, 3), wall.darkened(0.2))
	var up: int = level.tget(gx, gy - 1)
	var dn: int = level.tget(gx, gy + 1)
	var lf: int = level.tget(gx - 1, gy)
	var rt: int = level.tget(gx + 1, gy)
	if _open(up):
		draw_rect(Rect2(x, y, T, 4), edge)
		draw_rect(Rect2(x, y, T, 1), edge.lightened(0.35))
		if biome == "cave" and hh % 3 == 0:
			draw_rect(Rect2(x + 6 + hh % 14, y - 3, 3, 3), Color(0.35, 0.7, 0.45))
	if _open(dn):
		draw_rect(Rect2(x, y + T - 4, T, 4), dark)
		if biome == "cave" and hh % 4 == 0:
			var sx := x + 6 + hh % 18
			draw_colored_polygon(PackedVector2Array([Vector2(sx, y + T), Vector2(sx + 7, y + T), Vector2(sx + 3.5, y + T + 9)]), wall)
	if _open(lf):
		draw_rect(Rect2(x, y, 3, T), edge.darkened(0.15))
	if _open(rt):
		draw_rect(Rect2(x + T - 3, y, 3, T), dark.lightened(0.05))


func _draw_wood(x: float, y: float, biome: String) -> void:
	if biome == "cave":
		draw_rect(Rect2(x, y, T, T), Color(0.85, 0.9, 0.9, 0.08))
		var cc := Vector2(x + T / 2.0, y + T / 2.0)
		var col := Color(0.9, 0.94, 0.95, 0.75)
		draw_line(Vector2(x, y), Vector2(x + T, y + T), col, 1.0)
		draw_line(Vector2(x + T, y), Vector2(x, y + T), col, 1.0)
		draw_line(Vector2(x + T / 2.0, y), Vector2(x + T / 2.0, y + T), col, 1.0)
		draw_arc(cc, 6.0, 0, TAU, 10, col, 1.0)
		draw_arc(cc, 12.0, 0, TAU, 12, col, 1.0)
	else:
		var base := Color(0.45, 0.29, 0.16) if biome == "castle" else Color(0.3, 0.17, 0.1)
		draw_rect(Rect2(x, y, T, T), base)
		for i in range(3):
			draw_rect(Rect2(x, y + i * 11, T, 2), base.darkened(0.4))
		draw_line(Vector2(x + 2, y + 2), Vector2(x + T - 2, y + T - 2), base.lightened(0.25), 3.0)
		draw_circle(Vector2(x + 5, y + 6), 1.5, Color(0.7, 0.7, 0.7))
		draw_circle(Vector2(x + T - 5, y + T - 6), 1.5, Color(0.7, 0.7, 0.7))
