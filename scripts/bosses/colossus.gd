extends "res://scripts/enemy.gd"
## Mini-boss 3: Stone Colossus (earth). Weak to poison.

var state := "dormant"
var st := 0.0
var last := ""
var rocks: Array = []
var second_wave := false


func setup() -> void:
	init_stats(175.0, "earth", Vector2(30, 40), 0)
	is_boss = true
	boss_id = "colossus"
	boss_name = "Каменный Колосс"
	knock_res = 1.0


func ai(dt: float) -> void:
	apply_gravity(dt)
	st -= dt
	var tp := to_player()
	var enraged := hp < max_hp * 0.5
	# telegraphed rocks
	var keep: Array = []
	for rk in rocks:
		rk["t"] = float(rk["t"]) - dt
		if float(rk["t"]) <= 0.0:
			var rect: Rect2 = game.level.rect_px()
			game.proj.spawn({"pos": Vector2(rk["x"], rect.position.y + 40.0), "vel": Vector2(0, 60), "grav": 900.0, "r": 13.0, "dmg": 1,
				"kind": "rock", "elem": "earth", "owner": "e", "life": 3.0})
		else:
			keep.append(rk)
	rocks = keep
	match state:
		"dormant":
			if absf(tp.x) < 520.0 and game.boss_start(self):
				state = "walk"
				st = 1.5
		"walk":
			facing = 1 if tp.x > 0.0 else -1
			vel.x = facing * (70.0 if enraged else 50.0)
			if st <= 0.0:
				var opts := ["stomp", "rain", "charge"]
				opts.erase(last)
				last = opts[randi() % opts.size()]
				state = last + "_wind"
				st = 0.8
		"stomp_wind":
			vel.x = 0.0
			if st <= 0.0:
				_stomp()
				second_wave = enraged
				state = "stomp_after"
				st = 0.5
		"stomp_after":
			if st <= 0.0:
				if second_wave:
					second_wave = false
					_stomp()
					st = 0.5
				else:
					state = "walk"
					st = 1.6
		"rain_wind":
			vel.x = 0.0
			if st <= 0.0:
				var n := 10 if enraged else 7
				for i in range(n):
					rocks.append({"x": game.player.position.x + randf_range(-260.0, 260.0), "t": 0.7 + i * 0.12})
				game.sfx.play("rumble")
				game.shake(4.0)
				state = "walk"
				st = 2.4
		"charge_wind":
			vel.x = 0.0
			facing = 1 if tp.x > 0.0 else -1
			if st <= 0.0:
				state = "charge"
				st = 2.5
				game.sfx.play("charge")
		"charge":
			vel.x = facing * (430.0 if enraged else 360.0)
			if wall_ahead(facing) or st <= 0.0:
				game.shake(12.0)
				game.sfx.play("slam")
				for i in range(4):
					rocks.append({"x": position.x + randf_range(-300.0, 300.0), "t": 0.5 + i * 0.15})
				state = "stunned"
				st = 1.8
		"stunned":
			vel.x = 0.0
			if st <= 0.0:
				state = "walk"
				st = 1.2
	move(dt)


func _stomp() -> void:
	game.shake(10.0)
	game.sfx.play("slam")
	for s in [-1.0, 1.0]:
		game.proj.spawn({"pos": Vector2(position.x + s * 34.0, position.y + half.y - 1.0), "vel": Vector2(s * 290.0, 0),
			"r": 14.0, "h": 34.0, "kind": "wave", "dmg": 1, "elem": "earth", "owner": "e", "life": 2.6})


func dmg_scale(_el: String, _kb: Vector2) -> float:
	return 1.5 if state == "stunned" else 1.0


func _draw() -> void:
	var col := Color(0.42, 0.38, 0.34)
	var c2 := ecol()
	for rk in rocks:
		var x: float = float(rk["x"]) - position.x
		var k := clampf(1.0 - float(rk["t"]), 0.0, 1.0)
		draw_rect(Rect2(x - 14, half.y - 4, 28, 4), Color(0, 0, 0, 0.3 + 0.4 * k))
		draw_line(Vector2(x, half.y - 6), Vector2(x, half.y - 200), Color(1, 0.3, 0.2, 0.12 * k), 3.0)
	var lift := -10.0 if state.ends_with("_wind") else 0.0
	var step := sin(t * 4.0) * 3.0 if absf(vel.x) > 1.0 else 0.0
	draw_rect(Rect2(-24, 18 + step, 18, 22 - step), col.darkened(0.3))
	draw_rect(Rect2(6, 18 - step, 18, 22 + step), col.darkened(0.3))
	draw_colored_polygon(PackedVector2Array([Vector2(-30, 20), Vector2(-34, -16), Vector2(-20, -34), Vector2(20, -34), Vector2(34, -16), Vector2(30, 20)]), col)
	draw_colored_polygon(PackedVector2Array([Vector2(-14, -34), Vector2(-12, -52), Vector2(12, -52), Vector2(14, -34)]), col.lightened(0.08))
	draw_rect(Rect2(-46, -24 + lift, 14, 40), col.darkened(0.12))
	draw_rect(Rect2(32, -24 + lift, 14, 40), col.darkened(0.12))
	draw_rect(Rect2(-48, 12 + lift, 18, 14), col.darkened(0.2))
	draw_rect(Rect2(30, 12 + lift, 18, 14), col.darkened(0.2))
	var pts := PackedVector2Array([Vector2(-18, -20), Vector2(-4, -4), Vector2(-12, 10), Vector2(6, 14)])
	draw_polyline(pts, c2, 3.0)
	draw_polyline(PackedVector2Array([Vector2(18, -22), Vector2(6, -8), Vector2(16, 6)]), c2, 3.0)
	var ec := Color(1, 0.6, 0.2) if state != "stunned" else Color(0.5, 0.5, 0.5)
	draw_circle(Vector2(facing * 3.0 - 5.0, -43), 3.0, ec)
	draw_circle(Vector2(facing * 3.0 + 5.0, -43), 3.0, ec)
	if state == "stunned":
		for i in range(3):
			var a := t * 4.0 + i * TAU / 3.0
			draw_circle(Vector2(cos(a) * 18.0, -60.0 + sin(a) * 4.0), 3.0, Color(1, 1, 0.5))
	if state == "charge_wind":
		draw_arc(Vector2.ZERO, 50.0, 0, TAU, 24, Color(1, 0.4, 0.2, 0.6), 3.0)
