extends "res://scripts/enemy.gd"
## Crystal turret: shoots 3-way bursts of water shards.

var cd := 2.0


func setup() -> void:
	init_stats(6.0, "water", Vector2(12, 14), 3)
	grav = 0.0
	knock_res = 1.0
	cd = randf_range(1.0, 2.4)


func ai(dt: float) -> void:
	vel = Vector2.ZERO
	var tp := to_player()
	if tp.length() < 540.0 and game.level.los(position, game.player.position):
		cd -= dt
		if cd <= 0.0:
			cd = 2.4
			for a in [-0.28, 0.0, 0.28]:
				game.proj.spawn({"pos": position, "vel": tp.normalized().rotated(a) * 240.0, "r": 6.0, "dmg": 1, "elem": "water", "owner": "e", "life": 3.5})
			game.sfx.play("crystal")


func _draw() -> void:
	var col := Color(0.4, 0.85, 1.0)
	var charge := clampf(1.0 - cd / 0.6, 0.0, 1.0)
	draw_circle(Vector2.ZERO, 26.0, Color(col.r, col.g, col.b, 0.07 + charge * 0.15))
	var pts := PackedVector2Array([Vector2(0, -16), Vector2(11, 0), Vector2(0, 16), Vector2(-11, 0)])
	draw_colored_polygon(pts, col.darkened(0.35))
	draw_colored_polygon(PackedVector2Array([Vector2(0, -16), Vector2(11, 0), Vector2(0, 0)]), col)
	draw_colored_polygon(PackedVector2Array([Vector2(0, 16), Vector2(-11, 0), Vector2(0, 0)]), col.darkened(0.1))
	var a := t * 2.0
	draw_circle(Vector2(cos(a), sin(a)) * 3.0, 3.0 + charge * 2.0, Color(1, 1, 1, 0.8))
	hpbar()
