extends "res://scripts/enemy.gd"
## Spider: hangs from the ceiling and drops on the hero, then chases.

var hanging := true
var anchor_y := 0.0
var hop_cd := 1.0


func setup() -> void:
	init_stats(4.0, "poison", Vector2(11, 8), 2)
	if hanging:
		var y := position.y
		var n := 0
		while not game.level.solid_px(Vector2(position.x, y - 16.0)) and n < 30:
			y -= 16.0
			n += 1
		anchor_y = floorf((y - 16.0) / C.TILE) * C.TILE + C.TILE
		position.y = anchor_y + 40.0
		home = position


func ai(dt: float) -> void:
	if hanging:
		position.y = home.y + sin(t * 1.5) * 6.0
		var tp := to_player()
		if absf(tp.x) < 80.0 and tp.y > 0.0 and tp.y < 420.0:
			hanging = false
			vel = Vector2.ZERO
		return
	apply_gravity(dt)
	var tp2 := to_player()
	if on_floor:
		facing = 1 if tp2.x > 0.0 else -1
		vel.x = move_toward(vel.x, facing * 115.0, 600.0 * dt)
		hop_cd -= dt
		if hop_cd <= 0.0 and absf(tp2.x) < 160.0:
			hop_cd = randf_range(1.2, 2.0)
			vel.y = -360.0
	move(dt)


func _draw() -> void:
	aura_glow()
	var col := Color(0.2, 0.18, 0.22)
	if hanging:
		draw_line(Vector2(0, anchor_y - position.y), Vector2(0, -6), Color(0.9, 0.9, 0.9, 0.5), 1.0)
	for s in [-1.0, 1.0]:
		for i in range(4):
			var k := sin(t * 14.0 + i * 1.3) * 3.0 if not hanging else 0.0
			var a := Vector2(s * 5.0, -1.0 + i * 1.5)
			var b := Vector2(s * (12.0 + i), -7.0 + i * 2.0 + k)
			var c := Vector2(s * (16.0 + i * 1.5), 8.0 + k * 0.5)
			draw_polyline(PackedVector2Array([a, b, c]), col.lightened(0.15), 2.0)
	ellipse(Vector2(0, 0), 10.0, 8.0, col)
	ellipse(Vector2(0, 2), 6.0, 4.0, ecol().darkened(0.3))
	glow_eyes(Vector2(facing * 3.0, -3), 2.5, 1.6)
	hpbar()
