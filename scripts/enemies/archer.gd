extends "res://scripts/enemy.gd"
## Skeleton archer: stands still and shoots arrows.

var cd := 1.5


func setup() -> void:
	init_stats(4.0, "none", Vector2(10, 14), 2)
	cd = randf_range(1.0, 2.0)


func ai(dt: float) -> void:
	apply_gravity(dt)
	vel.x = move_toward(vel.x, 0.0, 800.0 * dt)
	move(dt)
	var tp := to_player()
	facing = 1 if tp.x > 0.0 else -1
	if tp.length() < 500.0 and game.level.los(position + Vector2(0, -6), game.player.position):
		cd -= dt
		if cd <= 0.0:
			cd = 2.1
			var target: Vector2 = game.player.position + game.player.vel * 0.25
			var dir := (target - position - Vector2(0, -6)).normalized()
			game.proj.spawn({"pos": position + Vector2(facing * 10.0, -6), "vel": dir * 390.0, "r": 5.0, "dmg": 1,
				"kind": "arrow", "owner": "e", "life": 2.5})
			game.sfx.play("bow")
	else:
		cd = maxf(cd, 0.6)


func _draw() -> void:
	var bone := Color(0.86, 0.84, 0.76)
	var drawing := cd < 0.5
	draw_line(Vector2(0, -2), Vector2(0, 10), bone, 3.0)
	for i in range(3):
		draw_line(Vector2(-5, 0 + i * 3), Vector2(5, 0 + i * 3), bone, 1.5)
	draw_line(Vector2(0, 10), Vector2(-4, 14), bone, 2.0)
	draw_line(Vector2(0, 10), Vector2(4, 14), bone, 2.0)
	draw_circle(Vector2(0, -8), 7.0, bone)
	draw_rect(Rect2(-4, -5, 8, 3), bone.darkened(0.2))
	draw_circle(Vector2(facing * 2.5 - 2.5, -9), 1.8, Color(0.1, 0.05, 0.05))
	draw_circle(Vector2(facing * 2.5 + 2.5, -9), 1.8, Color(0.1, 0.05, 0.05))
	var bx := facing * 10.0
	var pull := 5.0 if drawing else 0.0
	draw_arc(Vector2(bx - facing * 4.0, 0), 11.0, -PI / 2.0 if facing > 0 else PI / 2.0, PI / 2.0 if facing > 0 else PI * 1.5, 10, Color(0.6, 0.4, 0.2), 2.0)
	draw_line(Vector2(bx - facing * 4.0, -11), Vector2(bx - facing * (4.0 + pull), 0), Color(0.9, 0.9, 0.9, 0.7), 1.0)
	draw_line(Vector2(bx - facing * (4.0 + pull), 0), Vector2(bx - facing * 4.0, 11), Color(0.9, 0.9, 0.9, 0.7), 1.0)
	draw_line(Vector2(0, 2), Vector2(bx - facing * (4.0 + pull), 0), bone, 2.0)
	hpbar()
