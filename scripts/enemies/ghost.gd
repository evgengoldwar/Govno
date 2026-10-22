extends "res://scripts/enemy.gd"
## Ghost: drifts through walls, fades out and becomes untouchable.

func setup() -> void:
	init_stats(5.0, "air", Vector2(11, 13), 2)
	grav = 0.0
	t = randf() * 5.0


func ai(dt: float) -> void:
	var ph := fmod(t, 5.5)
	alpha = 1.0
	if ph > 3.8:
		alpha = clampf(absf(ph - 4.65) / 0.85, 0.12, 1.0)
	invulnerable = alpha < 0.4
	var tp := to_player()
	if tp.length() < 430.0:
		vel = vel.lerp(tp.normalized() * 75.0, minf(1.0, dt * 1.5))
	else:
		vel = vel.lerp(Vector2(0, sin(t) * 20.0), dt)
	facing = 1 if tp.x > 0.0 else -1
	position += vel * dt


func _draw() -> void:
	var col := Color(0.85, 0.9, 1.0, 0.85)
	draw_circle(Vector2.ZERO, 22.0, Color(0.8, 0.9, 1.0, 0.06))
	draw_circle(Vector2(0, -3), 11.0, col)
	var pts := PackedVector2Array([Vector2(-11, -3), Vector2(11, -3)])
	for i in range(5):
		var x := 11.0 - i * 5.5
		pts.append(Vector2(x, 12.0 + sin(t * 6.0 + i) * 2.5))
	draw_colored_polygon(pts, col)
	draw_circle(Vector2(facing * 2.0 - 4.0, -4), 2.6, Color(0.1, 0.1, 0.2))
	draw_circle(Vector2(facing * 2.0 + 4.0, -4), 2.6, Color(0.1, 0.1, 0.2))
	ellipse(Vector2(facing * 2.0, 3), 2.5, 3.0 + sin(t * 3.0), Color(0.1, 0.1, 0.2))
	hpbar()
