extends "res://scripts/enemy.gd"
## Wraith: teleports near the hero and releases a ring of bolts.

var state := "float"
var st := 2.0


func setup() -> void:
	init_stats(9.0, "water", Vector2(12, 16), 5)
	grav = 0.0
	st = randf_range(1.0, 2.5)


func ai(dt: float) -> void:
	st -= dt
	var tp := to_player()
	facing = 1 if tp.x > 0.0 else -1
	match state:
		"float":
			alpha = 1.0
			invulnerable = false
			vel = vel.lerp(tp.normalized() * 40.0 + Vector2(0, sin(t * 2.0) * 30.0), dt)
			position += vel * dt
			if st <= 0.0 and tp.length() < 600.0:
				state = "out"
				st = 0.5
		"out":
			alpha = clampf(st / 0.5, 0.0, 1.0)
			invulnerable = true
			if st <= 0.0:
				_teleport()
				state = "in"
				st = 0.5
		"in":
			alpha = clampf(1.0 - st / 0.5, 0.0, 1.0)
			if st <= 0.0:
				invulnerable = false
				for i in range(8):
					var a := i * TAU / 8.0 + t
					game.proj.spawn({"pos": position, "vel": Vector2(cos(a), sin(a)) * 170.0, "r": 6.0, "dmg": 1, "elem": "water", "owner": "e", "life": 3.0})
				game.sfx.play("crystal")
				state = "float"
				st = 2.6


func _teleport() -> void:
	var lv = game.level
	for i in range(12):
		var a := randf() * TAU
		var d := randf_range(150.0, 240.0)
		var p: Vector2 = game.player.position + Vector2(cos(a) * d, -absf(sin(a)) * d * 0.7)
		if lv.contains_px(p) and not lv.solid_px(p) and not lv.solid_px(p + Vector2(0, -16)) and not lv.solid_px(p + Vector2(0, 16)):
			position = p
			return


func _draw() -> void:
	var col := Color(0.25, 0.2, 0.45)
	draw_circle(Vector2.ZERO, 24.0, Color(0.4, 0.5, 1.0, 0.08))
	var pts := PackedVector2Array([Vector2(0, -20), Vector2(11, -10), Vector2(13, 8)])
	for i in range(5):
		pts.append(Vector2(13.0 - i * 6.5, 16.0 + sin(t * 7.0 + i) * 3.0))
	pts.append(Vector2(-13, 8))
	pts.append(Vector2(-11, -10))
	draw_colored_polygon(pts, col)
	draw_circle(Vector2(0, -8), 7.0, Color(0.05, 0.04, 0.1))
	glow_eyes(Vector2(facing * 1.5, -8), 3.0, 1.8)
	hpbar()
