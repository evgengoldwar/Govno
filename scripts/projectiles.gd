extends Node2D
## All projectiles (player and enemy) in one lightweight manager.

const C = preload("res://scripts/consts.gd")

var game = null
var list: Array = []


func clear() -> void:
	list.clear()
	queue_redraw()


func spawn(d: Dictionary) -> void:
	var p := {
		"pos": Vector2.ZERO, "vel": Vector2.ZERO, "r": 7.0, "dmg": 1.0, "elem": "none", "owner": "e",
		"life": 3.0, "grav": 0.0, "kb": 0.0, "pierce": 0, "kind": "orb", "t": 0.0, "hits": [],
		"walls": true, "immune": "", "h": 0.0, "homing": 0.0,
	}
	for k in d.keys():
		p[k] = d[k]
	if not p.has("color"):
		p["color"] = C.ELEM_COLORS.get(p["elem"], Color(1, 1, 1))
	list.append(p)


func tick(dt: float) -> void:
	var lv = game.level
	var pl = game.player
	var keep: Array = []
	var cur: Array = list
	list = []
	for p in cur:
		p["t"] = float(p["t"]) + dt
		p["life"] = float(p["life"]) - dt
		var v: Vector2 = p["vel"]
		v.y += float(p["grav"]) * dt
		if float(p["homing"]) > 0.0 and pl != null and not pl.dead:
			var want: Vector2 = (pl.position - p["pos"]).normalized() * v.length()
			v = v.lerp(want, minf(1.0, float(p["homing"]) * dt))
		p["vel"] = v
		var pos: Vector2 = p["pos"] + v * dt
		p["pos"] = pos
		var dead := float(p["life"]) <= 0.0
		var kind: String = p["kind"]
		# --- tiles
		if not dead and p["walls"]:
			var probe := pos
			if kind == "wave":
				probe = pos + Vector2(signf(v.x) * float(p["r"]), -4)
			var code: int = lv.at_px(probe)
			if C.is_solid(code):
				dead = true
				if p["owner"] == "p":
					var tx := int(floor(probe.x / C.TILE))
					var ty := int(floor(probe.y / C.TILE))
					if C.GATE_ELEM.get(code, "") == p["elem"]:
						game.break_gate(tx, ty)
					elif C.GATE_HINT.has(code):
						game.hint(C.GATE_HINT[code])
				elif p.get("puddle", false):
					var fy := floorf(probe.y / C.TILE) * C.TILE
					spawn({"pos": Vector2(pos.x, fy), "kind": "puddle", "r": 26.0, "h": 16.0, "life": 4.5, "dmg": 1,
						"elem": "poison", "immune": "poison", "walls": false})
				game.fx.burst(pos - v.normalized() * 4.0, p["color"], 6, 110.0, 0.3, 2.5, 0.0)
		# --- hits
		if not dead:
			if p["owner"] == "p":
				for e in game.enemies:
					if not is_instance_valid(e) or not e.alive:
						continue
					var hits: Array = p["hits"]
					if hits.has(e.get_instance_id()):
						continue
					if e.hit_test(pos, float(p["r"])):
						hits.append(e.get_instance_id())
						var kb: Vector2 = v.normalized() * float(p["kb"])
						e.hit(float(p["dmg"]), p["elem"], kb)
						game.fx.burst(pos, p["color"], 8, 160.0, 0.3, 3.0, 0.0)
						p["pierce"] = int(p["pierce"]) - 1
						if int(p["pierce"]) < 0:
							dead = true
							break
			elif pl != null and not pl.dead and p["immune"] != pl.form:
				if _hits_player(p, pos, pl):
					pl.hurt(int(p["dmg"]), pos - v.normalized() * 10.0)
					if kind != "puddle" and kind != "wave" and kind != "beam":
						dead = true
		if not dead:
			keep.append(p)
	keep.append_array(list)
	list = keep
	queue_redraw()


func _hits_player(p: Dictionary, pos: Vector2, pl) -> bool:
	var r: float = p["r"]
	var hh: float = p["h"]
	var box_c: Vector2 = pl.position
	var box_h: Vector2 = pl.half
	if p["kind"] == "wave" or p["kind"] == "puddle" or p["kind"] == "beam":
		# rectangle anchored at bottom (pos is bottom-center)
		var rr := Rect2(pos.x - r, pos.y - hh, r * 2.0, hh)
		return rr.intersects(Rect2(box_c - box_h, box_h * 2.0))
	var cx := clampf(pos.x, box_c.x - box_h.x, box_c.x + box_h.x)
	var cy := clampf(pos.y, box_c.y - box_h.y, box_c.y + box_h.y)
	return Vector2(cx, cy).distance_to(pos) < r * 0.85


func _draw() -> void:
	for p in list:
		var pos: Vector2 = p["pos"]
		var v: Vector2 = p["vel"]
		var col: Color = p["color"]
		var r: float = p["r"]
		var kind: String = p["kind"]
		var t: float = p["t"]
		match kind:
			"arrow":
				var d := v.normalized()
				draw_line(pos - d * 16.0, pos, Color(0.85, 0.8, 0.7), 2.0)
				draw_colored_polygon(PackedVector2Array([pos + d * 6.0, pos + d.orthogonal() * 4.0, pos - d.orthogonal() * 4.0]), Color(0.9, 0.9, 0.95))
			"wave":
				var hh: float = p["h"]
				var pts := PackedVector2Array([Vector2(pos.x - r, pos.y), Vector2(pos.x - r * 0.4, pos.y - hh), Vector2(pos.x, pos.y - hh * 0.6),
					Vector2(pos.x + r * 0.4, pos.y - hh * 0.95), Vector2(pos.x + r, pos.y)])
				draw_colored_polygon(pts, Color(col.r, col.g, col.b, 0.85))
				draw_polyline(pts, col.lightened(0.4), 2.0)
			"puddle":
				var hh2: float = p["h"]
				var a := clampf(float(p["life"]), 0.0, 1.0)
				draw_rect(Rect2(pos.x - r, pos.y - hh2 * 0.5, r * 2.0, hh2 * 0.5), Color(col.r, col.g, col.b, 0.55 * a))
				for i in range(3):
					var bx := pos.x - r + fmod(t * 30.0 + i * r * 0.7, r * 2.0)
					draw_circle(Vector2(bx, pos.y - hh2 * 0.5 - 2.0 - fmod(t * 9.0 + i * 3.0, 8.0)), 2.5, Color(col.r, col.g, col.b, 0.7 * a))
			"beam":
				var hh3: float = p["h"]
				var a2 := 0.5 + 0.5 * sin(t * 40.0)
				draw_rect(Rect2(pos.x - r, pos.y - hh3, r * 2.0, hh3), Color(col.r, col.g, col.b, 0.35 + 0.3 * a2))
				draw_rect(Rect2(pos.x - r * 0.35, pos.y - hh3, r * 0.7, hh3), Color(1, 1, 1, 0.6))
			"rock":
				_rock(pos, r, t * 5.0, col)
			_:
				if p["elem"] == "earth":
					draw_circle(pos, r * 1.8, Color(col.r, col.g, col.b, 0.12))
					_rock(pos, r, t * 9.0, col)
				else:
					var d2 := v.normalized()
					draw_circle(pos, r * 2.2, Color(col.r, col.g, col.b, 0.13))
					draw_line(pos - d2 * r * 2.6, pos, Color(col.r, col.g, col.b, 0.35), r * 1.3)
					draw_circle(pos, r, col)
					draw_circle(pos, r * 0.5, col.lightened(0.6))
					if p["elem"] == "air":
						draw_arc(pos, r * 1.4, t * 12.0, t * 12.0 + 2.5, 8, col, 2.0)


func _rock(pos: Vector2, r: float, ang: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(5):
		var a := ang + i * TAU / 5.0
		pts.append(pos + Vector2(cos(a), sin(a)) * r * (0.85 + 0.15 * float(i % 2)))
	draw_colored_polygon(pts, col)
	draw_polyline(pts + PackedVector2Array([pts[0]]), col.darkened(0.4), 1.5)
