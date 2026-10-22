extends Node2D
## Parallax background drawn in world space around the camera.

const C = preload("res://scripts/consts.gd")

var biome := "castle"
var cam_center := Vector2.ZERO
var view_size := Vector2(960, 540)
var t := 0.0


func tick(dt: float, center: Vector2, size: Vector2, b: String) -> void:
	t += dt
	cam_center = center
	view_size = size
	biome = b
	queue_redraw()


func _draw() -> void:
	var pal: Dictionary = C.BIOME[biome]
	var tl := cam_center - view_size * 0.5 - Vector2(4, 4)
	var sz := view_size + Vector2(8, 8)
	var top: Color = pal["bg_top"]
	var bot: Color = pal["bg_bot"]
	draw_polygon(PackedVector2Array([tl, tl + Vector2(sz.x, 0), tl + sz, tl + Vector2(0, sz.y)]),
		PackedColorArray([top, top, bot, bot]))
	var far: Color = pal["far"]
	match biome:
		"castle":
			_castle(tl, sz, far, pal["accent"])
		"cave":
			_cave(tl, sz, far, pal["accent"])
		_:
			_hell(tl, sz, far, pal["accent"])


func _layer_x(par: float, period: float) -> float:
	return -fmod(cam_center.x * par, period)


func _castle(tl: Vector2, sz: Vector2, far: Color, acc: Color) -> void:
	# moon
	draw_circle(tl + Vector2(sz.x * 0.78, 90), 34, Color(0.85, 0.85, 0.75, 0.12))
	draw_circle(tl + Vector2(sz.x * 0.78, 90), 24, Color(0.9, 0.9, 0.8, 0.18))
	for layer in range(2):
		var par := 0.15 + layer * 0.2
		var period := 420.0 - layer * 80.0
		var col := far.lightened(layer * 0.06)
		var base_y := tl.y + sz.y * (0.55 + layer * 0.15)
		var x0 := tl.x + _layer_x(par, period) - period
		while x0 < tl.x + sz.x + period:
			var sd := int(floor((x0 - tl.x + cam_center.x * par) / period)) + layer * 7
			var hgt := 120.0 + float(absi(sd * 37) % 90)
			var wdt := 70.0 + float(absi(sd * 13) % 40)
			var bx := x0 + 40
			draw_rect(Rect2(bx, base_y - hgt, wdt, hgt + sz.y), col)
			draw_colored_polygon(PackedVector2Array([Vector2(bx - 8, base_y - hgt), Vector2(bx + wdt / 2.0, base_y - hgt - 50), Vector2(bx + wdt + 8, base_y - hgt)]), col)
			for k in range(3):
				var wy := base_y - hgt + 30 + k * 34
				var lit := (absi(sd * 11 + k * 5) % 3) == 0
				var wc := Color(acc.r, acc.g, acc.b, 0.35 + 0.1 * sin(t * 2.0 + k)) if lit else col.darkened(0.3)
				draw_rect(Rect2(bx + wdt / 2.0 - 5, wy, 10, 16), wc)
			x0 += period
	# drifting dust
	for k in range(18):
		var px := tl.x + fmod(k * 137.0 + t * (8.0 + k % 5) - cam_center.x * 0.1, sz.x + 40.0)
		var py := tl.y + fmod(k * 71.0 + sin(t * 0.5 + k) * 20.0 + 1000.0, sz.y)
		draw_circle(Vector2(px, py), 1.5, Color(1, 1, 1, 0.12))


func _cave(tl: Vector2, sz: Vector2, far: Color, acc: Color) -> void:
	for layer in range(2):
		var par := 0.2 + layer * 0.25
		var period := 180.0 + layer * 60.0
		var col := far.lightened(layer * 0.05)
		var x0 := tl.x + _layer_x(par, period) - period
		while x0 < tl.x + sz.x + period:
			var sd := int(floor((x0 - tl.x + cam_center.x * par) / period)) + layer * 13
			var hl := 60.0 + float(absi(sd * 41) % 120)
			var hb := 50.0 + float(absi(sd * 29) % 100)
			var wdt := 50.0 + float(absi(sd * 17) % 50)
			draw_colored_polygon(PackedVector2Array([Vector2(x0, tl.y), Vector2(x0 + wdt, tl.y), Vector2(x0 + wdt * 0.5, tl.y + hl)]), col)
			draw_colored_polygon(PackedVector2Array([Vector2(x0 + 60, tl.y + sz.y), Vector2(x0 + 60 + wdt, tl.y + sz.y), Vector2(x0 + 60 + wdt * 0.5, tl.y + sz.y - hb)]), col)
			if absi(sd) % 3 == 0:
				var cp := Vector2(x0 + 60 + wdt * 0.5, tl.y + sz.y - hb - 8)
				draw_circle(cp, 10.0, Color(acc.r, acc.g, acc.b, 0.06 + 0.04 * sin(t * 2.0 + sd)))
			x0 += period
	for k in range(24):
		var px := tl.x + fmod(k * 97.0 + sin(t * 0.3 + k) * 30.0 - cam_center.x * 0.3 + 5000.0, sz.x)
		var py := tl.y + fmod(k * 53.0 - t * (6.0 + k % 4) + 5000.0, sz.y)
		draw_circle(Vector2(px, py), 1.6, Color(acc.r, acc.g, acc.b, 0.25))


func _hell(tl: Vector2, sz: Vector2, far: Color, acc: Color) -> void:
	draw_rect(Rect2(tl.x, tl.y + sz.y * 0.6, sz.x, sz.y * 0.4), Color(0.6, 0.12, 0.04, 0.12))
	for layer in range(2):
		var par := 0.15 + layer * 0.2
		var period := 260.0 + layer * 40.0
		var col := far.lightened(layer * 0.05)
		var x0 := tl.x + _layer_x(par, period) - period
		var base_y := tl.y + sz.y * (0.62 + layer * 0.14)
		while x0 < tl.x + sz.x + period:
			var sd := int(floor((x0 - tl.x + cam_center.x * par) / period)) + layer * 5
			var h1 := 80.0 + float(absi(sd * 23) % 110)
			var h2 := 40.0 + float(absi(sd * 31) % 80)
			draw_colored_polygon(PackedVector2Array([
				Vector2(x0, base_y), Vector2(x0 + period * 0.3, base_y - h1), Vector2(x0 + period * 0.45, base_y - h1 * 0.6),
				Vector2(x0 + period * 0.7, base_y - h2), Vector2(x0 + period + 2, base_y), Vector2(x0 + period + 2, tl.y + sz.y + 4),
				Vector2(x0, tl.y + sz.y + 4)]), col)
			x0 += period
	for k in range(30):
		var px := tl.x + fmod(k * 113.0 + sin(t + k) * 12.0 - cam_center.x * 0.25 + 9000.0, sz.x)
		var ph := fmod(t * (0.15 + (k % 5) * 0.03) + k * 0.13, 1.0)
		var py := tl.y + sz.y * (1.0 - ph)
		draw_circle(Vector2(px, py), 1.8, Color(acc.r, acc.g * 0.8, acc.b, 0.6 * (1.0 - ph)))
