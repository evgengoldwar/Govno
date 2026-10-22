extends "res://scripts/enemy.gd"
## Mini-boss 2: Spider Queen (poison). Weak to fire. Lives on the ceiling.

const Spider = preload("res://scripts/enemies/spider.gd")

var state := "dormant"
var st := 0.0
var ceil_y := 0.0
var last := ""
var volleys := 0


func setup() -> void:
	init_stats(125.0, "poison", Vector2(30, 18), 0)
	is_boss = true
	boss_id = "queen"
	boss_name = "Королева Пауков"
	knock_res = 1.0
	grav = 0.0
	ceil_y = position.y + 20.0
	position.y = ceil_y


func ai(dt: float) -> void:
	st -= dt
	var tp := to_player()
	var enraged := hp < max_hp * 0.5
	match state:
		"dormant":
			if player_dist() < 520.0 and game.boss_start(self):
				state = "move"
				st = 1.5
		"move":
			vel.x = move_toward(vel.x, clampf(tp.x * 1.5, -170.0, 170.0), 400.0 * dt)
			vel.y = 0.0
			position.y = ceil_y + sin(t * 2.0) * 4.0
			if st <= 0.0:
				var opts := ["spit", "brood", "drop"]
				opts.erase(last)
				last = opts[randi() % opts.size()]
				state = last
				st = 0.5
				volleys = 3 if enraged else 2
		"spit":
			vel.x = move_toward(vel.x, 0.0, 600.0 * dt)
			if st <= 0.0:
				var n := 7 if enraged else 5
				for i in range(n):
					var vx := (float(i) - (n - 1) / 2.0) * 85.0 + tp.x * 0.35
					game.proj.spawn({"pos": position + Vector2(0, 14), "vel": Vector2(vx, -60.0), "grav": 650.0, "r": 8.0, "dmg": 1,
						"elem": "poison", "owner": "e", "life": 4.0, "puddle": true})
				game.sfx.play("spit")
				volleys -= 1
				st = 0.7
				if volleys <= 0:
					state = "move"
					st = 1.6
		"brood":
			if st <= 0.0:
				var alive_minions := 0
				for e in game.enemies:
					if is_instance_valid(e) and e != self and e.kind == "spider":
						alive_minions += 1
				for i in range(2 if alive_minions < 3 else 0):
					var s = game.spawn_enemy("spider", position + Vector2((i * 2 - 1) * 30.0, 20), false)
					if s:
						s.hp = 2.0
						s.max_hp = 2.0
						s.coin_drop = 0
				game.sfx.play("spit")
				state = "move"
				st = 1.4
		"drop":
			vel.x = 0.0
			if st <= 0.0:
				grav = 1800.0
				apply_gravity(dt)
				var r := move(dt)
				if r["floor"]:
					game.shake(10.0)
					game.sfx.play("slam")
					for s in [-1.0, 1.0]:
						game.proj.spawn({"pos": Vector2(position.x + s * 30.0, position.y + half.y - 1.0), "vel": Vector2(s * 280.0, 0),
							"r": 12.0, "h": 24.0, "kind": "wave", "dmg": 1, "elem": "poison", "owner": "e", "life": 2.5})
					state = "stunned"
					st = 2.0 if not enraged else 1.4
				return
		"stunned":
			vel = Vector2.ZERO
			if st <= 0.0:
				state = "climb"
		"climb":
			grav = 0.0
			vel = Vector2(0, -320.0)
			position += vel * dt
			if position.y <= ceil_y:
				position.y = ceil_y
				state = "move"
				st = 1.2
			return
	if state != "drop":
		position.x += vel.x * dt
		var rect: Rect2 = game.level.rect_px()
		position.x = clampf(position.x, rect.position.x + 60.0, rect.end.x - 60.0)


func dmg_scale(_el: String, _kb: Vector2) -> float:
	return 1.5 if state == "stunned" else 1.0


func _draw() -> void:
	var col := Color(0.2, 0.15, 0.24)
	var c2 := ecol()
	if state != "drop" and state != "stunned":
		draw_line(Vector2(0, -400), Vector2(0, -10), Color(0.9, 0.9, 0.9, 0.35), 2.0)
	for s in [-1.0, 1.0]:
		for i in range(4):
			var k := sin(t * 6.0 + i) * 4.0
			var a := Vector2(s * 12.0, -2.0 + i * 3.0)
			var b := Vector2(s * (34.0 + i * 4.0), -22.0 + i * 6.0 + k)
			var c := Vector2(s * (46.0 + i * 3.0), 18.0 + i * 2.0 + k)
			draw_polyline(PackedVector2Array([a, b, c]), col.lightened(0.2), 3.0)
	ellipse(Vector2(0, -12), 26.0, 18.0, col)
	ellipse(Vector2(0, -14), 14.0, 9.0, c2.darkened(0.25))
	draw_colored_polygon(PackedVector2Array([Vector2(-6, -18), Vector2(0, -6), Vector2(6, -18), Vector2(0, -24)]), Color(0.9, 0.2, 0.2))
	ellipse(Vector2(0, 8), 14.0, 11.0, col.lightened(0.05))
	for i in range(3):
		draw_circle(Vector2(-6 + i * 6, 6), 2.6, c2.lightened(0.3))
	draw_circle(Vector2(-3, 11), 2.0, c2.lightened(0.3))
	draw_circle(Vector2(3, 11), 2.0, c2.lightened(0.3))
	draw_colored_polygon(PackedVector2Array([Vector2(-8, -2), Vector2(-4, -12), Vector2(0, -4), Vector2(4, -12), Vector2(8, -2)]), Color(0.95, 0.8, 0.3))
	if state == "stunned":
		for i in range(3):
			var a2 := t * 4.0 + i * TAU / 3.0
			draw_circle(Vector2(cos(a2) * 16.0, -24.0 + sin(a2) * 4.0), 3.0, Color(1, 1, 0.5))
