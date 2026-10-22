extends "res://scripts/enemy.gd"
## Toxic frog: big jumps and poison spit.

var jt := 1.0
var jumps := 0


func setup() -> void:
	init_stats(5.0, "poison", Vector2(12, 9), 3)
	jt = randf_range(0.5, 1.5)


func ai(dt: float) -> void:
	apply_gravity(dt)
	var tp := to_player()
	if on_floor:
		vel.x = move_toward(vel.x, 0.0, 1200.0 * dt)
		facing = 1 if tp.x > 0.0 else -1
		jt -= dt
		if jt <= 0.0 and tp.length() < 420.0:
			jumps += 1
			jt = 1.3
			if jumps % 3 == 0:
				var v := Vector2(tp.x * 1.1, -380.0)
				v.x = clampf(v.x, -320.0, 320.0)
				game.proj.spawn({"pos": position + Vector2(0, -6), "vel": v, "grav": 800.0, "r": 7.0, "dmg": 1, "elem": "poison", "owner": "e", "life": 2.0})
				game.sfx.play("spit")
			else:
				vel = Vector2(clampf(tp.x * 1.2, -230.0, 230.0), -520.0)
	move(dt)


func _draw() -> void:
	aura_glow()
	var col := Color(0.35, 0.62, 0.22)
	var sq := 1.0 if on_floor else 1.15
	ellipse(Vector2(0, 2), 13.0 / sq, 8.0 * sq, col)
	draw_circle(Vector2(-6, -6), 4.5, col)
	draw_circle(Vector2(6, -6), 4.5, col)
	draw_circle(Vector2(-6, -7), 2.5, Color(1, 0.95, 0.4))
	draw_circle(Vector2(6, -7), 2.5, Color(1, 0.95, 0.4))
	draw_rect(Rect2(-6.5, -7.5, 1, 2), Color(0, 0, 0))
	draw_rect(Rect2(5.5, -7.5, 1, 2), Color(0, 0, 0))
	draw_line(Vector2(-6, 3), Vector2(6, 3), col.darkened(0.5), 1.5)
	for s in [-1.0, 1.0]:
		draw_circle(Vector2(s * 9.0, 4), 2.0, Color(0.7, 0.9, 0.3))
	hpbar()
