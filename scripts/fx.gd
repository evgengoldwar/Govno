extends Node2D
## Particles, rings, afterimages and floating texts.

var parts: Array = []
var rings: Array = []
var ghosts: Array = []
var texts: Array = []
var font: Font


func _ready() -> void:
	font = ThemeDB.fallback_font


func clear() -> void:
	parts.clear()
	rings.clear()
	ghosts.clear()
	texts.clear()


func spark(pos: Vector2, vel: Vector2, col: Color, life: float, size: float, grav: float) -> void:
	if parts.size() > 700:
		return
	parts.append({"p": pos, "v": vel, "c": col, "l": life, "m": life, "s": size, "g": grav})


func burst(pos: Vector2, col: Color, n: int, speed: float, life: float, size: float, grav: float) -> void:
	for i in range(n):
		var a := randf() * TAU
		var sp := speed * randf_range(0.3, 1.0)
		spark(pos, Vector2(cos(a), sin(a)) * sp, col, life * randf_range(0.6, 1.0), size * randf_range(0.6, 1.2), grav)


func ring(pos: Vector2, col: Color, radius: float) -> void:
	rings.append({"p": pos, "c": col, "l": 0.35, "m": 0.35, "r": radius})


func ghost(pos: Vector2, col: Color) -> void:
	ghosts.append({"p": pos, "c": col, "l": 0.25, "m": 0.25})


func text(pos: Vector2, s: String, col: Color, size := 16) -> void:
	texts.append({"p": pos, "s": s, "c": col, "l": 0.9, "m": 0.9, "z": size})


func tick(dt: float) -> void:
	var keep: Array = []
	for q in parts:
		q["l"] = float(q["l"]) - dt
		if float(q["l"]) <= 0.0:
			continue
		var v: Vector2 = q["v"]
		v.y += float(q["g"]) * dt
		v *= 0.985
		q["v"] = v
		q["p"] = (q["p"] as Vector2) + v * dt
		keep.append(q)
	parts = keep
	var groups: Array = [rings, ghosts, texts]
	for gi in range(3):
		var arr: Array = groups[gi]
		var k2: Array = []
		for q in arr:
			q["l"] = float(q["l"]) - dt
			if float(q["l"]) > 0.0:
				if gi == 2:
					q["p"] = (q["p"] as Vector2) + Vector2(0, -40.0 * dt)
				k2.append(q)
		arr.clear()
		arr.append_array(k2)
	queue_redraw()


func _draw() -> void:
	for q in ghosts:
		var c: Color = q["c"]
		var k: float = float(q["l"]) / float(q["m"])
		draw_circle(q["p"], 11.0, Color(c.r, c.g, c.b, 0.35 * k))
	for q in parts:
		var c2: Color = q["c"]
		var k2: float = float(q["l"]) / float(q["m"])
		draw_circle(q["p"], float(q["s"]) * (0.4 + 0.6 * k2), Color(c2.r, c2.g, c2.b, c2.a * minf(1.0, k2 * 1.5)))
	for q in rings:
		var c3: Color = q["c"]
		var k3: float = float(q["l"]) / float(q["m"])
		draw_arc(q["p"], float(q["r"]) * (1.4 - k3 * 0.9), 0, TAU, 24, Color(c3.r, c3.g, c3.b, k3), 3.0 * k3 + 1.0)
	for q in texts:
		var c4: Color = q["c"]
		var k4: float = float(q["l"]) / float(q["m"])
		var s: String = q["s"]
		var size: int = q["z"]
		var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var p: Vector2 = q["p"]
		draw_string_outline(font, p - Vector2(w / 2.0, 0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(0, 0, 0, k4))
		draw_string(font, p - Vector2(w / 2.0, 0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(c4.r, c4.g, c4.b, k4))
