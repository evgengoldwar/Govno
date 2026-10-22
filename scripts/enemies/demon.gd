extends "res://scripts/enemy.gd"
## Demon: circles the hero and fires bursts of fireballs.

var cd := 2.0
var burst := 0
var bt := 0.0
var ang := 0.0


func setup() -> void:
	init_stats(10.0, "fire", Vector2(14, 14), 5)
	grav = 0.0
	ang = randf() * TAU
	cd = randf_range(1.0, 2.0)


func ai(dt: float) -> void:
	var tp := to_player()
	if tp.length() > 600.0:
		vel = vel.lerp(Vector2.ZERO, dt)
		move(dt)
		return
	ang += dt * 0.7
	var target: Vector2 = game.player.position + Vector2(cos(ang) * 220.0, -absf(sin(ang)) * 110.0 - 70.0)
	var d := target - position
	vel = vel.lerp(d.normalized() * minf(170.0, d.length() * 2.0), minf(1.0, 2.0 * dt))
	facing = 1 if tp.x > 0.0 else -1
	move(dt)
	cd -= dt
	if cd <= 0.0:
		cd = 2.0
		burst = 3
		bt = 0.0
	if burst > 0:
		bt -= dt
		if bt <= 0.0:
			bt = 0.13
			burst -= 1
			game.proj.spawn({"pos": position, "vel": tp.normalized() * 300.0, "r": 7.0, "dmg": 1, "elem": "fire", "owner": "e", "life": 3.0})
			game.sfx.play("fireball")


func _draw() -> void:
	aura_glow()
	var col := Color(0.5, 0.1, 0.12)
	var flap := sin(t * 9.0) * 8.0
	for s in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([Vector2(s * 6.0, -6), Vector2(s * 28.0, -18.0 + flap), Vector2(s * 6.0, 6)]), col.darkened(0.3))
		draw_colored_polygon(PackedVector2Array([Vector2(s * 8.0, 2), Vector2(s * 28.0, -18.0 + flap), Vector2(s * 20.0, 6.0 + flap * 0.3)]), col.darkened(0.3))
	draw_circle(Vector2.ZERO, 13.0, col)
	for s2 in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([Vector2(s2 * 8.0, -8), Vector2(s2 * 14.0, -22), Vector2(s2 * 4.0, -11)]), Color(0.9, 0.85, 0.7))
	draw_line(Vector2(-5, 6), Vector2(5, 6), Color(1, 0.6, 0.2), 2.0)
	glow_eyes(Vector2(facing * 2.0, -2), 5.0, 2.4)
	hpbar()
