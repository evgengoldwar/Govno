extends "res://scripts/enemy.gd"
## Flaming skull: bounces around the room diagonally.

func setup() -> void:
	init_stats(4.0, "fire", Vector2(10, 10), 2)
	grav = 0.0
	knock_res = 1.0
	vel = Vector2(160.0 if randf() < 0.5 else -160.0, 130.0 if randf() < 0.5 else -130.0)


func ai(dt: float) -> void:
	var before := vel
	var r := move(dt)
	if int(r["wall"]) != 0:
		vel.x = -before.x
	else:
		vel.x = before.x
	if r["floor"] or r["ceil"]:
		vel.y = -before.y
	else:
		vel.y = before.y
	facing = 1 if vel.x > 0.0 else -1
	if randf() < 0.5:
		game.fx.spark(position + Vector2(randf_range(-5, 5), randf_range(-5, 5)), -vel * 0.2, Color(1, 0.5, 0.15), 0.35, 3.0, -60.0)


func _draw() -> void:
	draw_circle(Vector2.ZERO, 16.0, Color(1, 0.4, 0.1, 0.18))
	var bone := Color(0.92, 0.88, 0.78)
	draw_circle(Vector2(0, -2), 9.0, bone)
	draw_rect(Rect2(-5, 4, 10, 5), bone)
	draw_circle(Vector2(-3.5, -2), 2.6, Color(1, 0.4, 0.1))
	draw_circle(Vector2(3.5, -2), 2.6, Color(1, 0.4, 0.1))
	for i in range(3):
		draw_line(Vector2(-3 + i * 3, 5), Vector2(-3 + i * 3, 9), bone.darkened(0.4), 1.0)
	hpbar()
