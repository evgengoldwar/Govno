extends Node2D
## Modal screens: title, pause + world map, shop, death, reward and victory.

const C = preload("res://scripts/consts.gd")

var game = null
var font: Font
var mode := ""
var shop_id := ""
var reward_elem := ""
var buttons: Array = []
var sel := 0
var t := 0.0
var open_t := 0.0


func _ready() -> void:
	font = ThemeDB.fallback_font


func open(m: String) -> void:
	mode = m
	sel = 0
	open_t = 0.0
	game.hud.reset_touch()
	game.sfx.play("select")
	queue_redraw()


func open_shop(id: String) -> void:
	shop_id = id
	open("shop")


func open_reward(e: String) -> void:
	reward_elem = e
	open("reward")


func close() -> void:
	mode = ""
	game.hud.reset_touch()
	queue_redraw()


func tick(dt: float) -> void:
	t += dt
	open_t += dt
	if mode == "":
		return
	if buttons.size() > 0:
		if Input.is_action_just_pressed("ui_down") or Input.is_action_just_pressed("down"):
			sel = (sel + 1) % buttons.size()
			game.sfx.play("select")
		elif Input.is_action_just_pressed("ui_up") or Input.is_action_just_pressed("up"):
			sel = (sel - 1 + buttons.size()) % buttons.size()
			game.sfx.play("select")
		elif (Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("jump")) and open_t > 0.25:
			_activate(buttons[clampi(sel, 0, buttons.size() - 1)]["id"])
			return
	if (Input.is_action_just_pressed("ui_cancel") or Input.is_action_just_pressed("pause")) and open_t > 0.1:
		if mode == "pause" or mode == "shop":
			close()
	elif Input.is_action_just_pressed("map") and mode == "pause" and open_t > 0.1:
		close()
	queue_redraw()


func _input(event: InputEvent) -> void:
	if mode == "":
		return
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed and open_t > 0.25:
		var p: Vector2 = (event as InputEventScreenTouch).position
		for i in range(buttons.size()):
			var r: Rect2 = buttons[i]["rect"]
			if r.has_point(p):
				sel = i
				_activate(buttons[i]["id"])
				get_viewport().set_input_as_handled()
				return


func _activate(id: String) -> void:
	match id:
		"new":
			close()
			game.new_game()
		"continue":
			close()
			game.continue_game()
		"resume", "close":
			close()
		"menu":
			game.to_title()
		"respawn":
			close()
			game.respawn()
		"next":
			close()
		_:
			if id.begins_with("buy:"):
				game.buy(shop_id, id.substr(4))


# ------------------------------------------------------------------ drawing helpers
func text(pos: Vector2, s: String, size: int, col: Color, center := false, outline := 4) -> void:
	var p := pos
	if center:
		p.x -= font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x / 2.0
	if outline > 0:
		draw_string_outline(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, Color(0, 0, 0, col.a * 0.9))
	draw_string(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func button(id: String, r: Rect2, label: String, enabled := true, sub := "") -> void:
	var i := buttons.size()
	buttons.append({"id": id, "rect": r})
	var hot := i == sel
	var base := Color(0.12, 0.12, 0.18, 0.92) if enabled else Color(0.1, 0.1, 0.12, 0.7)
	draw_rect(r, base)
	draw_rect(r, Color(1, 0.85, 0.5, 0.9) if hot else Color(1, 1, 1, 0.2), false, 2.0 if hot else 1.0)
	var col := Color(1, 0.95, 0.85) if enabled else Color(0.55, 0.55, 0.6)
	if sub == "":
		text(Vector2(r.position.x + r.size.x / 2.0, r.position.y + r.size.y / 2.0 + 7), label, 20, col, true)
	else:
		text(Vector2(r.position.x + 14, r.position.y + 24), label, 18, col)
		text(Vector2(r.position.x + 14, r.position.y + 44), sub, 13, Color(col.r, col.g, col.b, 0.75), false, 3)


func panel(r: Rect2) -> void:
	draw_rect(r, Color(0.04, 0.04, 0.07, 0.94))
	draw_rect(r, Color(1, 0.85, 0.5, 0.5), false, 2.0)


func _draw() -> void:
	buttons.clear()
	if mode == "":
		return
	var s := get_viewport_rect().size
	match mode:
		"title":
			_title(s)
		"pause":
			_pause(s)
		"shop":
			_shop(s)
		"dead":
			_dead(s)
		"reward":
			_reward(s)
		"victory":
			_victory(s)
	sel = clampi(sel, 0, maxi(0, buttons.size() - 1))


func _title(s: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, 0.45))
	var c := Vector2(s.x / 2.0, s.y * 0.3)
	for i in range(5):
		var e: String = C.ELEMS[i]
		var a := t * 0.8 + i * TAU / 5.0
		var p := c + Vector2(cos(a) * 190.0, sin(a) * 34.0)
		var col: Color = C.ELEM_COLORS[e]
		draw_circle(p, 16.0, Color(col.r, col.g, col.b, 0.2))
		draw_circle(p, 8.0, col)
	text(c + Vector2(0, 10), "СТИХИИ БЕЗДНЫ", 52, Color(1, 0.92, 0.75), true, 8)
	text(c + Vector2(0, 44), "метроидвания о силе пяти стихий", 17, Color(0.85, 0.85, 0.95), true)
	var bw := 280.0
	var y := s.y * 0.55
	if game.has_save():
		button("continue", Rect2(s.x / 2.0 - bw / 2.0, y, bw, 50), "Продолжить")
		y += 62.0
	button("new", Rect2(s.x / 2.0 - bw / 2.0, y, bw, 50), "Новая игра")
	text(Vector2(s.x / 2.0, s.y - 46), "Клавиатура: ←→ / A D — бег, Пробел — прыжок, X — атака, C — рывок, F — флакон,", 13, Color(1, 1, 1, 0.55), true, 3)
	text(Vector2(s.x / 2.0, s.y - 26), "E — действие, 1-5 / Q R — стихии, M — карта, Esc — пауза. На телефоне — сенсорные кнопки.", 13, Color(1, 1, 1, 0.55), true, 3)


func _pause(s: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, 0.6))
	var st: Dictionary = game.state
	var map_r := Rect2(24, 24, s.x - 300, s.y - 48)
	panel(map_r)
	text(Vector2(map_r.position.x + map_r.size.x / 2.0, map_r.position.y + 28), "Карта мира", 20, Color(1, 0.92, 0.75), true)
	_map(Rect2(map_r.position + Vector2(16, 44), map_r.size - Vector2(32, 60)))
	var side := Rect2(s.x - 262, 24, 238, s.y - 48)
	panel(side)
	var x := side.position.x + 16
	var y := side.position.y + 34
	text(Vector2(x, y), "Монеты: " + str(int(st["coins"])), 17, Color(1, 0.9, 0.5))
	y += 26
	text(Vector2(x, y), "Здоровье: " + str(int(st["hp"])) + "/" + str(int(st["max_hp"])), 17, Color(1, 0.6, 0.65))
	y += 26
	text(Vector2(x, y), "Флаконы: " + str(int(st["flasks"])) + "/" + str(int(st["flasks_max"])), 17, Color(0.55, 0.8, 1.0))
	y += 26
	text(Vector2(x, y), "Печати: " + str(int(st["seals"])) + "/3", 17, Color(0.85, 0.5, 1.0))
	y += 26
	text(Vector2(x, y), "Сила: +" + str(int(st["power"]) * 25) + "%", 17, Color(1, 0.75, 0.5))
	y += 30
	text(Vector2(x, y), "Стихии:", 15, Color(0.9, 0.9, 0.95))
	y += 6
	for e in st["elements"]:
		y += 22
		var col: Color = C.ELEM_COLORS[e]
		draw_circle(Vector2(x + 8, y - 5), 6.0, col)
		text(Vector2(x + 20, y), C.ELEM_NAMES[e], 15, col)
	y += 30
	var secs := int(st["time"])
	text(Vector2(x, y), "Время: %d:%02d" % [secs / 60, secs % 60], 14, Color(0.8, 0.8, 0.85))
	y += 20
	text(Vector2(x, y), "Смертей: " + str(int(st["deaths"])), 14, Color(0.8, 0.8, 0.85))
	button("resume", Rect2(x, side.end.y - 124, 206, 46), "Продолжить")
	button("menu", Rect2(x, side.end.y - 66, 206, 46), "В меню")


func _map(area: Rect2) -> void:
	var cols := 8
	var rows := 9
	var cw := minf(area.size.x / cols, (area.size.y - 16.0) * 2.0 / rows)
	var ch := cw * 0.5
	var origin := area.position + Vector2((area.size.x - cw * cols) / 2.0, (area.size.y - 16.0 - ch * rows) / 2.0)
	var st: Dictionary = game.state
	var visited: Dictionary = st["visited"]
	var has_map: bool = st["map"]
	for rid in game.rooms.keys():
		var r: Dictionary = game.rooms[rid]
		var seen := visited.has(rid)
		if not seen and not has_map:
			continue
		var rr := Rect2(origin + Vector2(float(r["gx"]) * cw, float(r["gy"]) * ch), Vector2(float(r["w"]) * cw, float(r["h"]) * ch)).grow(-2.0)
		var pal: Dictionary = C.BIOME[r["biome"]]
		var col: Color = pal["edge"]
		if seen:
			draw_rect(rr, col.darkened(0.2))
		draw_rect(rr, col.lightened(0.2), false, 1.5)
		if rid == game.level.id and int(t * 3.0) % 2 == 0:
			draw_rect(rr, Color(1, 1, 1, 0.9), false, 2.0)
		if seen:
			var icons := []
			for e in r["ents"]:
				var tt: String = e["t"]
				if tt == "altar" or tt == "merchant" or tt.begins_with("boss_"):
					icons.append(tt)
			var ix := rr.position.x + 8.0
			for ic in icons:
				var ip := Vector2(ix, rr.position.y + 9.0)
				if ic == "altar":
					draw_circle(ip, 4.0, Color(0.45, 0.8, 1.0))
				elif ic == "merchant":
					draw_circle(ip, 4.0, Color(1, 0.85, 0.3))
				else:
					var bid: String = String(ic).substr(5)
					var done: bool = st["bosses"].has(bid)
					draw_circle(ip, 5.0, Color(0.4, 0.4, 0.4) if done else Color(1, 0.25, 0.25))
				ix += 12.0
	# player marker
	var pl = game.player
	var gx: float = pl.position.x / C.TILE / C.CW
	var gy: float = pl.position.y / C.TILE / C.CH
	var pp := origin + Vector2(gx * cw, gy * ch)
	draw_circle(pp, 6.0, Color(1, 1, 1))
	draw_circle(pp, 4.0, C.ELEM_COLORS[pl.form])
	var ly := area.end.y - 4
	draw_circle(Vector2(area.position.x + 8, ly - 5), 4.0, Color(0.45, 0.8, 1.0))
	text(Vector2(area.position.x + 16, ly), "алтарь", 12, Color(0.8, 0.8, 0.85), false, 2)
	draw_circle(Vector2(area.position.x + 80, ly - 5), 4.0, Color(1, 0.85, 0.3))
	text(Vector2(area.position.x + 88, ly), "торговец", 12, Color(0.8, 0.8, 0.85), false, 2)
	draw_circle(Vector2(area.position.x + 166, ly - 5), 4.0, Color(1, 0.25, 0.25))
	text(Vector2(area.position.x + 174, ly), "страж", 12, Color(0.8, 0.8, 0.85), false, 2)


func _shop(s: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, 0.6))
	var items: Array = game.shops.get(shop_id, [])
	var w := minf(560.0, s.x - 40.0)
	var h := 120.0 + items.size() * 64.0
	var r := Rect2(s.x / 2.0 - w / 2.0, maxf(10.0, s.y / 2.0 - h / 2.0), w, minf(h, s.y - 20.0))
	panel(r)
	text(Vector2(s.x / 2.0, r.position.y + 32), "Лавка торговца", 22, Color(1, 0.92, 0.75), true)
	text(Vector2(r.end.x - 20 - font.get_string_size("Монеты: 0000", HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x, r.position.y + 32),
		"Монеты: " + str(int(game.state["coins"])), 16, Color(1, 0.9, 0.5))
	var y := r.position.y + 50
	var rowh := minf(58.0, (r.size.y - 110.0) / maxf(1.0, items.size()))
	for it in items:
		var bought: bool = game.state["bought"].has(it["id"])
		var price := int(it["price"])
		var can: bool = not bought and int(game.state["coins"]) >= price
		var label := String(it["name"]) + ("   — куплено" if bought else "   " + str(price) + " мон.")
		button("buy:" + String(it["id"]), Rect2(r.position.x + 16, y, w - 32, rowh - 6), label, can, String(it["desc"]))
		y += rowh
	button("close", Rect2(s.x / 2.0 - 100, r.end.y - 52, 200, 40), "Уйти")


func _dead(s: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.08, 0, 0, 0.7))
	text(Vector2(s.x / 2.0, s.y * 0.38), "ТЫ ПАЛ", 56, Color(1, 0.35, 0.35), true, 8)
	text(Vector2(s.x / 2.0, s.y * 0.38 + 36), "Стихии возвращают тебя к последнему алтарю...", 17, Color(0.9, 0.85, 0.85), true)
	button("respawn", Rect2(s.x / 2.0 - 150, s.y * 0.58, 300, 52), "Возродиться")


func _reward(s: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, 0.55))
	var col: Color = C.ELEM_COLORS.get(reward_elem, Color(1, 1, 1))
	var c := Vector2(s.x / 2.0, s.y * 0.32)
	var pulse := 1.0 + 0.1 * sin(t * 4.0)
	draw_circle(c, 60.0 * pulse, Color(col.r, col.g, col.b, 0.15))
	draw_circle(c, 34.0, Color(0, 0, 0, 0.5))
	_icon(c, reward_elem, 30.0)
	text(c + Vector2(0, 80), "Новая стихия: " + String(C.ELEM_NAMES.get(reward_elem, "")).to_upper(), 30, col, true, 6)
	text(c + Vector2(0, 112), C.ELEM_DESC.get(reward_elem, ""), 18, Color(0.95, 0.95, 1.0), true)
	text(c + Vector2(0, 140), "Получена печать стража (" + str(int(game.state["seals"])) + "/3). Старые места теперь откроют новые тайны.", 15, Color(0.85, 0.7, 1.0), true)
	button("next", Rect2(s.x / 2.0 - 120, s.y * 0.75, 240, 48), "Дальше")


func _icon(c: Vector2, e: String, r: float) -> void:
	var col: Color = C.ELEM_COLORS.get(e, Color(1, 1, 1))
	match e:
		"poison":
			draw_circle(c + Vector2(-r * 0.25, r * 0.15), r * 0.42, col)
			draw_circle(c + Vector2(r * 0.3, -r * 0.25), r * 0.3, col)
			draw_circle(c + Vector2(r * 0.25, r * 0.45), r * 0.2, col)
		"air":
			draw_arc(c, r * 0.6, 0, PI * 1.5, 16, col, 4.0)
			draw_arc(c + Vector2(r * 0.15, 0), r * 0.3, PI, PI * 2.6, 12, col, 3.0)
		"earth":
			var pts := PackedVector2Array()
			for i in range(6):
				var a := i * TAU / 6.0 + PI / 6.0
				pts.append(c + Vector2(cos(a), sin(a)) * r * 0.7)
			draw_colored_polygon(pts, col)
		_:
			draw_circle(c, r * 0.6, col)


func _victory(s: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, 0.7))
	var c := Vector2(s.x / 2.0, s.y * 0.3)
	for i in range(5):
		var e: String = C.ELEMS[i]
		var a := t * 1.2 + i * TAU / 5.0
		draw_circle(c + Vector2(cos(a), sin(a)) * 120.0, 10.0, C.ELEM_COLORS[e])
	text(c + Vector2(0, 12), "ПОБЕДА", 60, Color(1, 0.92, 0.6), true, 8)
	var st: Dictionary = game.state
	var secs := int(st["time"])
	text(c + Vector2(0, 160), "Владыка Бездны повержен. Пять стихий снова в равновесии.", 18, Color(0.95, 0.95, 1.0), true)
	text(c + Vector2(0, 190), "Время: %d:%02d   Смертей: %d   Монет: %d" % [secs / 60, secs % 60, int(st["deaths"]), int(st["coins"])], 16, Color(0.85, 0.85, 0.9), true)
	button("menu", Rect2(s.x / 2.0 - 120, s.y * 0.78, 240, 48), "В меню")
