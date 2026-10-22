extends Node2D
## Pickups and interactables: coin, chest, heart, altar, merchant, sign.

const C = preload("res://scripts/consts.gd")

var game = null
var kind := "coin"
var pid := ""
var data: Dictionary = {}
var t := 0.0
var vel := Vector2.ZERO
var dynamic := false
var life := 12.0
var opened := false
var near := false
var value := 1
var font: Font


func _ready() -> void:
	font = ThemeDB.fallback_font
	t = randf() * 3.0


func interactable() -> bool:
	return (kind == "chest" and not opened) or kind == "altar" or kind == "merchant"


func action_label() -> String:
	match kind:
		"chest":
			return "Открыть"
		"altar":
			return "Отдых"
		"merchant":
			return "Торг"
	return ""


func tick(dt: float) -> void:
	t += dt
	var pl = game.player
	var d: float = pl.position.distance_to(position)
	near = d < 64.0 and not pl.dead
	match kind:
		"coin":
			var mag := 150.0 if game.state["magnet"] else 46.0
			if dynamic:
				life -= dt
				if life <= 0.0:
					queue_free_prop()
					return
			if d < mag and not pl.dead and (not dynamic or life < 11.6):
				vel = vel.lerp((pl.position - position).normalized() * 520.0, minf(1.0, dt * 8.0))
				position += vel * dt
			elif dynamic:
				vel.y = minf(vel.y + 1200.0 * dt, 700.0)
				var before := vel
				var r: Dictionary = game.level.move_box(position, Vector2(5, 5), vel, dt)
				position = r["pos"]
				vel = r["vel"]
				if r["floor"]:
					vel.y = -before.y * 0.45 if absf(before.y) > 120.0 else 0.0
					vel.x *= 0.8
				if int(r["wall"]) != 0:
					vel.x = -before.x * 0.5
			if d < 16.0 and not pl.dead:
				game.collect_coin(self)
				return
		"heart":
			if d < 26.0 and not pl.dead:
				game.collect_heart(self)
				return
	queue_redraw()


func queue_free_prop() -> void:
	game.props.erase(self)
	queue_free()


func _draw() -> void:
	match kind:
		"coin":
			if dynamic and life < 3.0 and int(t * 10.0) % 2 == 0:
				return
			var sx := absf(cos(t * 4.0)) * 0.8 + 0.2
			draw_circle(Vector2.ZERO, 9.0, Color(1, 0.85, 0.3, 0.12))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(sx, 1.0))
			draw_circle(Vector2.ZERO, 5.5, Color(0.95, 0.7, 0.15))
			draw_circle(Vector2.ZERO, 3.5, Color(1.0, 0.88, 0.35))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"heart":
			var b := sin(t * 3.0) * 3.0
			draw_circle(Vector2(0, b), 22.0, Color(1, 0.3, 0.4, 0.15))
			_heart(Vector2(0, b), 11.0, Color(1.0, 0.3, 0.4))
		"chest":
			var base := Color(0.5, 0.32, 0.16)
			var trim := Color(0.95, 0.75, 0.3)
			if near and not opened:
				draw_circle(Vector2(0, 4), 26.0, Color(1, 0.85, 0.3, 0.12 + 0.06 * sin(t * 5.0)))
			draw_rect(Rect2(-14, 0, 28, 16), base)
			draw_rect(Rect2(-14, 0, 28, 16), trim, false, 2.0)
			if opened:
				draw_rect(Rect2(-14, -14, 28, 6), base.darkened(0.3))
				draw_rect(Rect2(-12, -2, 24, 3), Color(0.1, 0.06, 0.03))
			else:
				draw_rect(Rect2(-15, -9, 30, 10), base.lightened(0.1))
				draw_rect(Rect2(-15, -9, 30, 10), trim, false, 2.0)
				draw_rect(Rect2(-3, -3, 6, 7), trim)
		"altar":
			var fl := sin(t * 8.0)
			draw_circle(Vector2(0, -18), 30.0, Color(0.5, 0.8, 1.0, 0.07 + 0.03 * fl))
			draw_rect(Rect2(-16, 6, 32, 10), Color(0.5, 0.5, 0.58))
			draw_rect(Rect2(-11, -6, 22, 12), Color(0.62, 0.62, 0.7))
			draw_rect(Rect2(-14, -9, 28, 4), Color(0.7, 0.7, 0.78))
			draw_colored_polygon(PackedVector2Array([Vector2(-6, -9), Vector2(-1 + fl * 2.0, -30), Vector2(1, -18), Vector2(4 - fl, -27), Vector2(6, -9)]), Color(0.45, 0.8, 1.0))
			draw_colored_polygon(PackedVector2Array([Vector2(-3, -9), Vector2(0, -20 + fl), Vector2(3, -9)]), Color(0.9, 0.97, 1.0))
		"merchant":
			var robe := Color(0.3, 0.22, 0.4)
			var bob := sin(t * 2.0) * 1.5
			draw_colored_polygon(PackedVector2Array([Vector2(-12, 16), Vector2(-8, -10 + bob), Vector2(8, -10 + bob), Vector2(12, 16)]), robe)
			draw_circle(Vector2(0, -14 + bob), 9.0, robe.lightened(0.1))
			draw_circle(Vector2(0, -13 + bob), 6.0, Color(0.05, 0.04, 0.08))
			draw_circle(Vector2(-2.5, -14 + bob), 1.6, Color(1, 0.85, 0.3))
			draw_circle(Vector2(2.5, -14 + bob), 1.6, Color(1, 0.85, 0.3))
			draw_rect(Rect2(-24, -2, 14, 18), Color(0.45, 0.3, 0.18))
			draw_line(Vector2(14, -6 + bob), Vector2(20, 8), Color(0.4, 0.3, 0.2), 2.0)
			draw_circle(Vector2(20, 12), 9.0, Color(1, 0.8, 0.4, 0.15 + 0.05 * sin(t * 6.0)))
			draw_circle(Vector2(20, 12), 3.5, Color(1, 0.85, 0.4))
			if near:
				_label("Торговец", Vector2(0, -34), Color(1, 0.85, 0.4))
		"sign":
			draw_rect(Rect2(-2, -2, 4, 18), Color(0.4, 0.3, 0.2))
			draw_rect(Rect2(-13, -14, 26, 14), Color(0.55, 0.42, 0.26))
			draw_rect(Rect2(-13, -14, 26, 14), Color(0.3, 0.22, 0.12), false, 2.0)
			for i in range(2):
				draw_line(Vector2(-8, -10 + i * 5), Vector2(8, -10 + i * 5), Color(0.3, 0.22, 0.12), 1.5)
			if near:
				_bubble(String(data.get("text", "")))


func _heart(c: Vector2, s: float, col: Color) -> void:
	draw_circle(c + Vector2(-s * 0.5, -s * 0.25), s * 0.55, col)
	draw_circle(c + Vector2(s * 0.5, -s * 0.25), s * 0.55, col)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 1.03, -s * 0.05), c + Vector2(s * 1.03, -s * 0.05), c + Vector2(0, s)]), col)


func _label(s: String, at: Vector2, col: Color) -> void:
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	draw_string_outline(font, at - Vector2(w / 2.0, 0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color(0, 0, 0))
	draw_string(font, at - Vector2(w / 2.0, 0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col)


func _bubble(s: String) -> void:
	var width := 280.0
	var size := 14
	var lines := font.get_multiline_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, width, size)
	var box := Rect2(-width / 2.0 - 10.0, -30.0 - lines.y - 14.0, width + 20.0, lines.y + 14.0)
	draw_rect(box, Color(0.05, 0.05, 0.08, 0.85))
	draw_rect(box, Color(1, 0.85, 0.5, 0.6), false, 1.5)
	draw_multiline_string(font, Vector2(-width / 2.0, box.position.y + 7.0 + font.get_ascent(size)), s, HORIZONTAL_ALIGNMENT_CENTER, width, size, -1, Color(1, 0.95, 0.85))
