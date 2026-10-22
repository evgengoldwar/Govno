extends "res://scripts/enemy.gd"
## Fire imp: hovers near the hero and throws fireballs.

var cd := 2.0
var side := 1.0


func setup() -> void:
	init_stats(4.0, "fire", Vector2(10, 10), 2)
	grav = 0.0
	cd = randf_range(1.0, 2.5)
	side = 1.0 if randf() < 0.5 else -1.0


func ai(dt: float) -> void:
	var tp := to_player()
	var dist := tp.length()
	if dist > 520.0:
		vel = vel.lerp(Vector2(0, sin(t * 2.0) * 20.0), dt)
		move(dt)
		return
	if absf(tp.x) < 60.0:
		side = -side if randf() < dt else side
	var target: Vector2 = game.player.position + Vector2(-side * 150.0, -110.0)
	var d := target - position
	vel = vel.lerp(d.normalized() * minf(160.0, d.length() * 2.5), minf(1.0, 2.5 * dt))
	facing = 1 if tp.x > 0.0 else -1
	move(dt)
	cd -= dt
	if cd <= 0.0 and game.level.los(position, game.player.position):
		cd = 2.2
		game.proj.spawn({"pos": position, "vel": tp.normalized() * 260.0, "r": 7.0, "dmg": 1, "elem": "fire", "owner": "e", "life": 3.0})
		game.sfx.play("fireball")


func _draw() -> void:
	aura_glow()
	var col := Color(0.85, 0.25, 0.15)
	var flap := sin(t * 16.0) * 5.0
	for s in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([Vector2(s * 5.0, -2), Vector2(s * 17.0, -10.0 + flap), Vector2(s * 12.0, 4)]), col.darkened(0.35))
	draw_circle(Vector2.ZERO, 9.0, col)
	draw_colored_polygon(PackedVector2Array([Vector2(-7, -5), Vector2(-9, -15), Vector2(-3, -8)]), col.darkened(0.3))
	draw_colored_polygon(PackedVector2Array([Vector2(7, -5), Vector2(9, -15), Vector2(3, -8)]), col.darkened(0.3))
	draw_line(Vector2(-facing * 6.0, 6), Vector2(-facing * 14.0, 12 + sin(t * 6.0) * 3.0), col, 2.0)
	glow_eyes(Vector2(facing * 2.0, -1), 3.5, 2.0)
	if cd < 0.4:
		draw_circle(Vector2(facing * 10.0, 4), 5.0, Color(1, 0.7, 0.2, 0.8))
	hpbar()
