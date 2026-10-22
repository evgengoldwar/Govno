extends Node2D
## Heads-up display and on-screen touch controls.

const C = preload("res://scripts/consts.gd")

var game = null
var font: Font
var vignette: GradientTexture2D

var touch_seen := false
var joy_id := -1
var joy_origin := Vector2.ZERO
var joy_pos := Vector2.ZERO
var joy_vec := Vector2.ZERO
var btn_touch := {}
var held := {}
var edge := {}
var t := 0.0


func _ready() -> void:
	font = ThemeDB.fallback_font
	touch_seen = OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0))
	g.set_color(1, Color(0, 0, 0, 0.55))
	g.add_point(0.6, Color(0, 0, 0, 0.0))
	vignette = GradientTexture2D.new()
	vignette.gradient = g
	vignette.fill = GradientTexture2D.FILL_RADIAL
	vignette.fill_from = Vector2(0.5, 0.5)
	vignette.fill_to = Vector2(1.05, 1.05)
	vignette.width = 256
	vignette.height = 256


func reset_touch() -> void:
	joy_id = -1
	joy_vec = Vector2.ZERO
	btn_touch.clear()
	held.clear()
	edge.clear()


# ------------------------------------------------------------------ input
func poll(inp) -> void:
	var mx := Input.get_axis("left", "right")
	var my := Input.get_axis("up", "down")
	if joy_id != -1:
		var v := joy_vec
		mx = signf(v.x) if absf(v.x) > 0.3 else 0.0
		my = v.y if absf(v.y) > 0.45 else 0.0
	inp.mx = mx
	inp.my = my
	inp.jump_pressed = Input.is_action_just_pressed("jump") or edge.has("jump")
	inp.jump_held = Input.is_action_pressed("jump") or held.has("jump")
	inp.attack_held = Input.is_action_pressed("attack") or held.has("attack")
	inp.dash_pressed = Input.is_action_just_pressed("dash") or edge.has("dash")
	inp.heal_pressed = Input.is_action_just_pressed("heal") or edge.has("heal")
	inp.interact_pressed = Input.is_action_just_pressed("interact") or edge.has("interact") \
		or (Input.is_action_just_pressed("up") and game.interact_target != null)
	inp.form_sel = ""
	var owned: Array = game.state.get("elements", [])
	for i in range(5):
		if Input.is_action_just_pressed("f" + str(i + 1)) and i < owned.size():
			inp.form_sel = owned[i]
	for e in owned:
		if edge.has("el_" + e):
			inp.form_sel = e
	inp.form_cycle = 0
	if Input.is_action_just_pressed("next"):
		inp.form_cycle = 1
	elif Input.is_action_just_pressed("prev"):
		inp.form_cycle = -1
	inp.map_pressed = Input.is_action_just_pressed("map") or edge.has("map")
	inp.pause_pressed = Input.is_action_just_pressed("pause") or edge.has("pause")
	edge.clear()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		touch_seen = true
		if st.pressed:
			if game.ui.mode != "" or not game.playing:
				return
			_press(st.index, st.position)
		else:
			_release(st.index)
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if sd.index == joy_id:
			joy_pos = sd.position
			var d := joy_pos - joy_origin
			if d.length() > 60.0:
				joy_origin = joy_pos - d.normalized() * 60.0
				d = joy_pos - joy_origin
			joy_vec = d / 50.0
			joy_vec = joy_vec.limit_length(1.0)


func _press(idx: int, pos: Vector2) -> void:
	for b in _buttons():
		var bp: Vector2 = b["pos"]
		if pos.distance_to(bp) < float(b["r"]) * 1.25:
			var id: String = b["id"]
			btn_touch[idx] = id
			held[id] = true
			edge[id] = true
			return
	var size := get_viewport_rect().size
	if pos.x < size.x * 0.5 and pos.y > 80.0:
		joy_id = idx
		joy_origin = pos
		joy_pos = pos
		joy_vec = Vector2.ZERO


func _release(idx: int) -> void:
	if idx == joy_id:
		joy_id = -1
		joy_vec = Vector2.ZERO
	if btn_touch.has(idx):
		held.erase(btn_touch[idx])
		btn_touch.erase(idx)


func _buttons() -> Array:
	var s := get_viewport_rect().size
	var out: Array = []
	out.append({"id": "pause", "pos": Vector2(s.x - 34, 34), "r": 22.0})
	out.append({"id": "map", "pos": Vector2(s.x - 86, 34), "r": 22.0})
	var owned: Array = game.state.get("elements", [])
	for i in range(owned.size()):
		out.append({"id": "el_" + owned[i], "pos": Vector2(s.x - 150 - (owned.size() - 1 - i) * 52, 34), "r": 22.0})
	if touch_seen:
		out.append({"id": "jump", "pos": Vector2(s.x - 82, s.y - 82), "r": 50.0})
		out.append({"id": "attack", "pos": Vector2(s.x - 196, s.y - 64), "r": 42.0})
		out.append({"id": "heal", "pos": Vector2(s.x - 196, s.y - 166), "r": 28.0})
		if game.state.get("dash", false):
			out.append({"id": "dash", "pos": Vector2(s.x - 86, s.y - 196), "r": 32.0})
		if game.interact_target != null:
			out.append({"id": "interact", "pos": Vector2(s.x - 300, s.y - 64), "r": 34.0})
	return out


# ------------------------------------------------------------------ drawing
func tick(dt: float) -> void:
	t += dt
	queue_redraw()


func text(pos: Vector2, s: String, size: int, col: Color, center := false, outline := 4) -> void:
	var p := pos
	if center:
		p.x -= font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x / 2.0
	if outline > 0:
		draw_string_outline(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, Color(0, 0, 0, col.a * 0.85))
	draw_string(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func heart(c: Vector2, s: float, col: Color, filled: bool) -> void:
	if filled:
		draw_circle(c + Vector2(-s * 0.5, -s * 0.25), s * 0.55, col)
		draw_circle(c + Vector2(s * 0.5, -s * 0.25), s * 0.55, col)
		draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 1.03, -s * 0.05), c + Vector2(s * 1.03, -s * 0.05), c + Vector2(0, s)]), col)
	else:
		draw_arc(c + Vector2(-s * 0.5, -s * 0.25), s * 0.55, PI * 0.75, PI * 2.0, 10, col, 2.0)
		draw_arc(c + Vector2(s * 0.5, -s * 0.25), s * 0.55, PI, PI * 2.25, 10, col, 2.0)
		draw_line(c + Vector2(-s * 1.0, 0), c + Vector2(0, s), col, 2.0)
		draw_line(c + Vector2(s * 1.0, 0), c + Vector2(0, s), col, 2.0)


func elem_icon(c: Vector2, e: String, r: float) -> void:
	var col: Color = C.ELEM_COLORS[e]
	match e:
		"fire":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.6, r * 0.5), c + Vector2(-r * 0.3, -r * 0.3), c + Vector2(0, -r * 0.9), c + Vector2(r * 0.3, -r * 0.2), c + Vector2(r * 0.6, r * 0.5)]), col)
			draw_circle(c + Vector2(0, r * 0.35), r * 0.35, Color(1, 0.9, 0.5))
		"water":
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r * 0.9), c + Vector2(r * 0.55, r * 0.1), c + Vector2(-r * 0.55, r * 0.1)]), col)
			draw_circle(c + Vector2(0, r * 0.2), r * 0.55, col)
		"poison":
			draw_circle(c + Vector2(-r * 0.25, r * 0.15), r * 0.42, col)
			draw_circle(c + Vector2(r * 0.3, -r * 0.25), r * 0.3, col)
			draw_circle(c + Vector2(r * 0.25, r * 0.45), r * 0.2, col)
		"air":
			draw_arc(c, r * 0.6, 0, PI * 1.5, 12, col, 3.0)
			draw_arc(c + Vector2(r * 0.15, 0), r * 0.3, PI, PI * 2.6, 10, col, 2.5)
		"earth":
			var pts := PackedVector2Array()
			for i in range(6):
				var a := i * TAU / 6.0 + PI / 6.0
				pts.append(c + Vector2(cos(a), sin(a)) * r * 0.7)
			draw_colored_polygon(pts, col)


func _draw() -> void:
	var s := get_viewport_rect().size
	draw_texture_rect(vignette, Rect2(Vector2.ZERO, s), false)
	if game == null or not game.playing:
		_overlays(s)
		return
	var st: Dictionary = game.state
	# hearts
	var mh := int(st["max_hp"])
	var hp := int(st["hp"])
	for i in range(mh):
		var c := Vector2(26 + (i % 10) * 26, 28 + (i / 10) * 24)
		var low := hp <= 2 and i < hp
		var sc := 9.0 + (sin(t * 10.0) * 1.2 if low else 0.0)
		heart(c, sc, Color(1, 0.28, 0.36) if i < hp else Color(0.6, 0.6, 0.65, 0.6), i < hp)
	# flasks
	var fm := int(st["flasks_max"])
	var fl := int(st["flasks"])
	for i in range(fm):
		var c2 := Vector2(24 + i * 20, 58 + (mh - 1) / 10 * 24)
		var col := Color(0.4, 0.75, 1.0) if i < fl else Color(0.35, 0.35, 0.4, 0.6)
		draw_rect(Rect2(c2.x - 3, c2.y - 11, 6, 5), col.darkened(0.3))
		draw_circle(c2, 7.0, col)
	# coins
	var yo := (mh - 1) / 10 * 24
	draw_circle(Vector2(26, 86 + yo), 7.0, Color(0.95, 0.7, 0.15))
	draw_circle(Vector2(26, 86 + yo), 4.5, Color(1.0, 0.88, 0.35))
	text(Vector2(40, 92 + yo), str(int(st["coins"])), 18, Color(1, 0.92, 0.6))
	# seals
	var seals := int(st["seals"])
	if seals > 0:
		for i in range(3):
			var c3 := Vector2(30 + i * 18, 114 + yo)
			var pts := PackedVector2Array([c3 + Vector2(0, -7), c3 + Vector2(6, 0), c3 + Vector2(0, 7), c3 + Vector2(-6, 0)])
			if i < seals:
				draw_colored_polygon(pts, Color(0.85, 0.4, 1.0))
			else:
				draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.6, 0.4, 0.7, 0.6), 1.5)
	# top-right buttons
	var pl = game.player
	for b in _buttons():
		var id: String = b["id"]
		var bp: Vector2 = b["pos"]
		var r: float = b["r"]
		var pressed := held.has(id)
		if id.begins_with("el_"):
			var e := id.substr(3)
			var active: bool = pl.form == e
			var ec: Color = C.ELEM_COLORS[e]
			draw_circle(bp, r, Color(0, 0, 0, 0.45))
			if active:
				draw_circle(bp, r + 4.0, Color(ec.r, ec.g, ec.b, 0.25))
				draw_arc(bp, r, 0, TAU, 24, ec, 3.0)
			else:
				draw_arc(bp, r, 0, TAU, 24, Color(1, 1, 1, 0.25), 1.5)
			elem_icon(bp, e, r * (0.8 if active else 0.62))
			continue
		var fill := Color(1, 1, 1, 0.2 if pressed else 0.08)
		var ring := Color(1, 1, 1, 0.45 if pressed else 0.25)
		match id:
			"pause":
				draw_circle(bp, r, Color(0, 0, 0, 0.45))
				draw_rect(Rect2(bp.x - 7, bp.y - 8, 5, 16), Color(1, 1, 1, 0.8))
				draw_rect(Rect2(bp.x + 2, bp.y - 8, 5, 16), Color(1, 1, 1, 0.8))
			"map":
				draw_circle(bp, r, Color(0, 0, 0, 0.45))
				draw_rect(Rect2(bp.x - 10, bp.y - 8, 20, 16), Color(1, 1, 1, 0.8), false, 2.0)
				draw_line(bp + Vector2(-3, -8), bp + Vector2(-3, 8), Color(1, 1, 1, 0.8), 1.5)
				draw_line(bp + Vector2(4, -8), bp + Vector2(4, 8), Color(1, 1, 1, 0.8), 1.5)
			"jump":
				draw_circle(bp, r, fill)
				draw_arc(bp, r, 0, TAU, 32, ring, 2.0)
				draw_colored_polygon(PackedVector2Array([bp + Vector2(-14, 8), bp + Vector2(0, -12), bp + Vector2(14, 8)]), Color(1, 1, 1, 0.7))
			"attack":
				var ec2: Color = C.ELEM_COLORS[pl.form]
				draw_circle(bp, r, Color(ec2.r, ec2.g, ec2.b, 0.3 if pressed else 0.15))
				draw_arc(bp, r, 0, TAU, 32, Color(ec2.r, ec2.g, ec2.b, 0.7), 2.0)
				elem_icon(bp, pl.form, 22.0)
			"heal":
				draw_circle(bp, r, fill)
				draw_arc(bp, r, 0, TAU, 24, ring, 2.0)
				draw_circle(bp + Vector2(0, 3), 9.0, Color(0.4, 0.75, 1.0, 0.8))
				draw_rect(Rect2(bp.x - 3, bp.y - 11, 6, 6), Color(0.4, 0.75, 1.0, 0.8))
				text(bp + Vector2(10, 18), str(fl), 13, Color(1, 1, 1, 0.9))
			"dash":
				draw_circle(bp, r, fill)
				draw_arc(bp, r, 0, TAU, 24, ring, 2.0)
				for k in range(3):
					draw_line(bp + Vector2(-12 + k * 7, -7), bp + Vector2(-5 + k * 7, 0), Color(1, 1, 1, 0.7), 2.5)
					draw_line(bp + Vector2(-5 + k * 7, 0), bp + Vector2(-12 + k * 7, 7), Color(1, 1, 1, 0.7), 2.5)
			"interact":
				var pulse := 0.5 + 0.5 * sin(t * 6.0)
				draw_circle(bp, r, Color(1, 0.85, 0.4, 0.2 + 0.15 * pulse))
				draw_arc(bp, r, 0, TAU, 24, Color(1, 0.85, 0.4, 0.8), 2.0)
				text(bp + Vector2(0, 6), game.interact_target.action_label(), 14, Color(1, 0.95, 0.8), true)
	if touch_seen and joy_id != -1:
		draw_circle(joy_origin, 60.0, Color(1, 1, 1, 0.08))
		draw_arc(joy_origin, 60.0, 0, TAU, 32, Color(1, 1, 1, 0.25), 2.0)
		draw_circle(joy_origin + joy_vec * 50.0, 24.0, Color(1, 1, 1, 0.3))
	elif touch_seen:
		var jc := Vector2(110, s.y - 100)
		draw_arc(jc, 60.0, 0, TAU, 32, Color(1, 1, 1, 0.12), 2.0)
		draw_circle(jc, 22.0, Color(1, 1, 1, 0.1))
	# interact prompt for keyboard players
	if game.interact_target != null and not touch_seen:
		var ip: Vector2 = game.interact_target.get_global_transform_with_canvas().origin
		text(ip + Vector2(0, -40), "[E] " + game.interact_target.action_label(), 14, Color(1, 0.95, 0.8), true)
	# boss bar
	var boss = game.boss
	if boss != null and is_instance_valid(boss) and boss.alive:
		var w := minf(420.0, s.x - 360.0)
		var x0 := s.x / 2.0 - w / 2.0
		var y0 := s.y - 34.0 if not touch_seen else 70.0
		var bc: Color = C.ELEM_COLORS[boss.elem]
		text(Vector2(s.x / 2.0, y0 - 8), boss.boss_name, 16, Color(1, 0.9, 0.85), true)
		draw_rect(Rect2(x0 - 2, y0 - 2, w + 4, 14), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(x0, y0, w * clampf(boss.hp / boss.max_hp, 0.0, 1.0), 10), bc)
		draw_rect(Rect2(x0, y0, w * clampf(boss.hp / boss.max_hp, 0.0, 1.0), 3), bc.lightened(0.4))
	_overlays(s)


func _overlays(s: Vector2) -> void:
	# room name
	if game.room_label_t > 0.0:
		var a := clampf(game.room_label_t, 0.0, 1.0)
		text(Vector2(s.x / 2.0, 34), "— " + game.room_label + " —", 18, Color(1, 0.95, 0.85, a), true)
	# hint
	if game.hint_t > 0.0:
		var a2 := clampf(game.hint_t, 0.0, 1.0)
		text(Vector2(s.x / 2.0, s.y * 0.72), game.hint_text, 18, Color(1, 0.85, 0.6, a2), true)
	# banner
	if game.banner_t > 0.0:
		var a3 := clampf(minf(game.banner_t, 3.2 - game.banner_t) * 2.5, 0.0, 1.0)
		draw_rect(Rect2(0, s.y * 0.3 - 40, s.x, 90), Color(0, 0, 0, 0.45 * a3))
		text(Vector2(s.x / 2.0, s.y * 0.3 + 4), game.banner_title, 34, Color(1, 0.92, 0.75, a3), true, 6)
		text(Vector2(s.x / 2.0, s.y * 0.3 + 34), game.banner_sub, 17, Color(0.9, 0.9, 0.95, a3), true)
	if game.flash_t > 0.0:
		draw_rect(Rect2(Vector2.ZERO, s), Color(1, 1, 1, game.flash_t * 0.6))
	if game.fade > 0.0:
		draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, game.fade))
