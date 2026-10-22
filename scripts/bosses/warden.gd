extends "res://scripts/enemy.gd"
## Mini-boss 1: Flame Warden (fire). Weak to water.

var state := "dormant"
var st := 0.0
var fans := 0
var last := ""


func setup() -> void:
	init_stats(85.0, "fire", Vector2(16, 26), 0)
	is_boss = true
	boss_id = "warden"
	boss_name = "Пылающий Страж"
	knock_res = 1.0


func ai(dt: float) -> void:
	apply_gravity(dt)
	st -= dt
	var tp := to_player()
	var enraged := hp < max_hp * 0.5
	var spd := 1.3 if enraged else 1.0
	match state:
		"dormant":
			if absf(tp.x) < 420.0 and game.boss_start(self):
				state = "idle"
				st = 1.2
		"idle":
			vel.x = move_toward(vel.x, 0.0, 1500.0 * dt)
			facing = 1 if tp.x > 0.0 else -1
			if st <= 0.0:
				var opts := ["dash", "leap", "fan"]
				opts.erase(last)
				last = opts[randi() % opts.size()]
				state = last + "_wind"
				st = 0.55 / spd
				fans = 3 if enraged else 2
		"dash_wind":
			vel.x = 0.0
			if st <= 0.0:
				state = "dash"
				st = 1.4
				game.sfx.play("charge")
		"dash":
			vel.x = facing * 560.0 * spd
			if int(t * 30.0) % 2 == 0:
				game.fx.spark(position + Vector2(0, half.y - 4), Vector2(-facing * 60.0, -40), ecol(), 0.5, 5.0, -50.0)
			if wall_ahead(facing) or st <= 0.0:
				game.shake(5.0)
				if enraged:
					_waves(1)
				state = "idle"
				st = 0.9 / spd
		"leap_wind":
			vel.x = 0.0
			if st <= 0.0:
				var air_t := 0.9
				vel = Vector2(clampf(tp.x / air_t, -600.0, 600.0), -720.0)
				on_floor = false
				state = "leap"
				st = 0.2
		"leap":
			if on_floor and st <= 0.0:
				game.shake(9.0)
				game.sfx.play("slam")
				_waves(1)
				state = "idle"
				st = 1.0 / spd
		"fan_wind":
			vel.x = 0.0
			if st <= 0.0:
				var n := 7 if enraged else 5
				for i in range(n):
					var a := (float(i) - (n - 1) / 2.0) * 0.2
					game.proj.spawn({"pos": position + Vector2(facing * 14.0, -14), "vel": (to_player() + Vector2(0, -10)).normalized().rotated(a) * 290.0,
						"r": 8.0, "dmg": 1, "elem": "fire", "owner": "e", "life": 3.0})
				game.sfx.play("fireball")
				fans -= 1
				st = 0.5
				if fans <= 0:
					state = "idle"
					st = 1.0 / spd
	move(dt)


func _waves(_n: int) -> void:
	for s in [-1.0, 1.0]:
		game.proj.spawn({"pos": Vector2(position.x + s * 20.0, position.y + half.y - 1.0), "vel": Vector2(s * 300.0, 0),
			"r": 12.0, "h": 30.0, "kind": "wave", "dmg": 1, "elem": "fire", "owner": "e", "life": 2.5})


func _draw() -> void:
	var col := Color(0.3, 0.22, 0.22)
	var c2 := ecol()
	draw_circle(Vector2(0, -6), 44.0, Color(c2.r, c2.g, c2.b, 0.08))
	var crouch := 6.0 if state.ends_with("_wind") else 0.0
	draw_rect(Rect2(-12, 10, 9, 16), col.darkened(0.3))
	draw_rect(Rect2(3, 10, 9, 16), col.darkened(0.3))
	draw_colored_polygon(PackedVector2Array([Vector2(-16, 12), Vector2(-18, -12 + crouch), Vector2(18, -12 + crouch), Vector2(16, 12)]), col)
	draw_rect(Rect2(-18, -14 + crouch, 36, 5), c2.darkened(0.2))
	# flaming head
	var fl := sin(t * 12.0) * 3.0
	draw_colored_polygon(PackedVector2Array([Vector2(-11, -14 + crouch), Vector2(-8 + fl, -40 + crouch), Vector2(-2, -28 + crouch),
		Vector2(3 - fl, -46 + crouch), Vector2(7, -30 + crouch), Vector2(12 + fl, -38 + crouch), Vector2(11, -14 + crouch)]), c2)
	draw_colored_polygon(PackedVector2Array([Vector2(-7, -14 + crouch), Vector2(0, -34 + crouch), Vector2(7, -14 + crouch)]), Color(1, 0.9, 0.5))
	draw_rect(Rect2(-8, -26 + crouch, 16, 5), Color(0.15, 0.1, 0.1))
	draw_circle(Vector2(facing * 2.0 - 3.0, -24 + crouch), 1.6, Color(1, 1, 0.8))
	draw_circle(Vector2(facing * 2.0 + 3.0, -24 + crouch), 1.6, Color(1, 1, 0.8))
	# blade
	var bx := facing * 22.0
	draw_line(Vector2(bx, 4), Vector2(bx + facing * 6.0, -30), c2.lightened(0.3), 4.0)
	draw_line(Vector2(bx - 6, 4), Vector2(bx + 6, 4), Color(0.6, 0.5, 0.3), 3.0)
	if state.ends_with("_wind"):
		draw_arc(Vector2(0, -6), 34.0, 0, TAU, 24, Color(1, 0.8, 0.3, 0.6), 2.0)
