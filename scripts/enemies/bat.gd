extends "res://scripts/enemy.gd"
## Bat: sleeps until the hero comes close, then swoops in a wavy line.

var awake := false


func setup() -> void:
	init_stats(2.0, "air", Vector2(10, 8), 1)
	grav = 0.0


func ai(dt: float) -> void:
	if not awake:
		position.y = home.y + sin(t * 2.0) * 3.0
		if player_dist() < 330.0:
			awake = true
		return
	var tp := to_player() + Vector2(0, -18)
	var want := tp.normalized() * 135.0 + Vector2(0, sin(t * 5.0) * 90.0)
	vel = vel.lerp(want, minf(1.0, 2.0 * dt))
	facing = 1 if vel.x > 0.0 else -1
	move(dt)


func _draw() -> void:
	aura_glow()
	var flap := sin(t * 20.0) * 0.8 if awake else 0.2
	var wc := Color(0.3, 0.25, 0.4)
	for s in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([Vector2(s * 4.0, -3), Vector2(s * 21.0, -6.0 - flap * 9.0), Vector2(s * 5.0, 4)]), wc)
		draw_colored_polygon(PackedVector2Array([Vector2(s * 5.0, 0), Vector2(s * 21.0, -6.0 - flap * 9.0), Vector2(s * 14.0, 4.0 + flap * 2.0)]), wc)
	draw_circle(Vector2.ZERO, 8.0, Color(0.38, 0.32, 0.5))
	draw_colored_polygon(PackedVector2Array([Vector2(-6, -5), Vector2(-4, -12), Vector2(-1, -6)]), Color(0.38, 0.32, 0.5))
	draw_colored_polygon(PackedVector2Array([Vector2(6, -5), Vector2(4, -12), Vector2(1, -6)]), Color(0.38, 0.32, 0.5))
	glow_eyes(Vector2(0, -1), 3.0, 1.8)
	hpbar()
