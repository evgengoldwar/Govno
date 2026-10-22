extends "res://scripts/enemy.gd"
## Fish that patrols water and darts at swimmers.

func setup() -> void:
	init_stats(3.0, "water", Vector2(11, 7), 2)
	grav = 0.0
	facing = 1 if randf() < 0.5 else -1


func ai(dt: float) -> void:
	var lv = game.level
	var tp := to_player()
	var pl_in_water: bool = lv.at_px(game.player.position) == C.T_WATER
	var want: Vector2
	if pl_in_water and tp.length() < 280.0:
		want = tp.normalized() * 165.0
	else:
		want = Vector2(facing * 60.0, sin(t * 2.0) * 25.0)
	vel = vel.lerp(want, minf(1.0, 3.0 * dt))
	var ahead: Vector2 = position + vel.normalized() * 16.0
	if lv.at_px(ahead) != C.T_WATER:
		vel = -vel * 0.5
		facing = -facing
	if absf(vel.x) > 5.0:
		facing = 1 if vel.x > 0.0 else -1
	move(dt)


func _draw() -> void:
	var col := Color(0.35, 0.5, 0.75)
	var wig := sin(t * 14.0) * 3.0
	draw_colored_polygon(PackedVector2Array([Vector2(-facing * 8.0, 0), Vector2(-facing * 18.0, -7.0 + wig), Vector2(-facing * 18.0, 7.0 + wig)]), col.darkened(0.3))
	ellipse(Vector2.ZERO, 12.0, 7.5, col)
	for i in range(3):
		var x := facing * (6.0 + i * 1.8)
		draw_colored_polygon(PackedVector2Array([Vector2(x, 2), Vector2(x + facing * 1.5, 5), Vector2(x + facing * 3.0, 2)]), Color(1, 1, 1))
	draw_circle(Vector2(facing * 5.0, -2), 2.5, Color(1, 0.9, 0.3))
	draw_circle(Vector2(facing * 5.5, -2), 1.2, Color(0, 0, 0))
	hpbar()
