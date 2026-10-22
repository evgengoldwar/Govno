extends "res://scripts/enemy.gd"
## Stone golem: slow, heavy, slams the ground for shockwaves.

var state := "walk"
var st := 0.0


func setup() -> void:
	init_stats(18.0, "earth", Vector2(20, 24), 6)
	knock_res = 0.9


func ai(dt: float) -> void:
	apply_gravity(dt)
	st -= dt
	var tp := to_player()
	match state:
		"walk":
			if tp.length() < 520.0:
				facing = 1 if tp.x > 0.0 else -1
				vel.x = facing * 45.0
				if absf(tp.x) < 140.0 and absf(tp.y) < 90.0 and on_floor:
					state = "wind"
					st = 0.7
			else:
				vel.x = 0.0
		"wind":
			vel.x = 0.0
			if st <= 0.0:
				for s in [-1.0, 1.0]:
					game.proj.spawn({"pos": Vector2(position.x + s * 22.0, position.y + half.y - 1.0), "vel": Vector2(s * 260.0, 0),
						"r": 12.0, "h": 26.0, "kind": "wave", "dmg": 1, "elem": "earth", "owner": "e", "life": 1.6})
				game.shake(6.0)
				game.sfx.play("slam")
				state = "rest"
				st = 1.3
		"rest":
			if st <= 0.0:
				state = "walk"
	move(dt)


func _draw() -> void:
	aura_glow()
	var col := Color(0.45, 0.4, 0.36)
	var lift := -6.0 if state == "wind" else 0.0
	var step := sin(t * 5.0) * 2.0 if absf(vel.x) > 1.0 else 0.0
	draw_rect(Rect2(-14, 12 + step, 10, 12 - step), col.darkened(0.3))
	draw_rect(Rect2(4, 12 - step, 10, 12 + step), col.darkened(0.3))
	draw_colored_polygon(PackedVector2Array([Vector2(-18, 14), Vector2(-20, -10), Vector2(-10, -20), Vector2(12, -20), Vector2(20, -8), Vector2(18, 14)]), col)
	draw_rect(Rect2(-9, -30, 18, 12), col.lightened(0.1))
	draw_rect(Rect2(-26, -10 + lift, 8, 22), col.darkened(0.15))
	draw_rect(Rect2(18, -10 + lift, 8, 22), col.darkened(0.15))
	draw_line(Vector2(-10, -6), Vector2(4, 6), ecol(), 2.0)
	draw_line(Vector2(4, 6), Vector2(10, -4), ecol(), 2.0)
	glow_eyes(Vector2(facing * 2.0, -25), 4.0, 2.0)
	hpbar()
