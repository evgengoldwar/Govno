extends "res://scripts/enemy.gd"
## Hellhound: fast runner that leaps at the hero.

var cd := 1.0


func setup() -> void:
	init_stats(8.0, "fire", Vector2(16, 10), 4)


func ai(dt: float) -> void:
	apply_gravity(dt)
	cd -= dt
	var tp := to_player()
	if on_floor:
		if tp.length() < 520.0:
			facing = 1 if tp.x > 0.0 else -1
			vel.x = move_toward(vel.x, facing * 215.0, 900.0 * dt)
			if cd <= 0.0 and absf(tp.x) < 230.0:
				cd = 1.6
				vel = Vector2(facing * 360.0, -440.0)
				game.sfx.play("growl")
			elif wall_ahead(facing):
				vel.y = -420.0
		else:
			vel.x = move_toward(vel.x, 0.0, 600.0 * dt)
	move(dt)


func _draw() -> void:
	aura_glow()
	var col := Color(0.25, 0.1, 0.1)
	var run := sin(t * 18.0) * 4.0 if absf(vel.x) > 10.0 else 0.0
	for i in range(4):
		var lx := -11.0 + i * 7.0
		draw_line(Vector2(lx, 4), Vector2(lx + (run if i % 2 == 0 else -run), 10), col, 3.0)
	ellipse(Vector2(0, 0), 15.0, 7.0, col)
	draw_circle(Vector2(facing * 14.0, -5), 7.0, col)
	draw_colored_polygon(PackedVector2Array([Vector2(facing * 10.0, -10), Vector2(facing * 12.0, -18), Vector2(facing * 15.0, -10)]), col)
	for i in range(4):
		var mx := -10.0 + i * 5.0
		var hh := 6.0 + sin(t * 12.0 + i) * 3.0
		draw_colored_polygon(PackedVector2Array([Vector2(mx - 3, -5), Vector2(mx, -5 - hh), Vector2(mx + 3, -5)]), Color(1, 0.45 + i * 0.08, 0.1))
	draw_circle(Vector2(facing * 16.0, -6), 2.0, Color(1, 0.9, 0.3))
	hpbar()
