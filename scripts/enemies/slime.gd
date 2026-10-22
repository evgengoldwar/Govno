extends "res://scripts/enemy.gd"
## Hopping slime.

var hop_t := 1.0


func setup() -> void:
	init_stats(4.0, "water", Vector2(13, 9), 2)
	hop_t = randf_range(0.4, 1.4)


func ai(dt: float) -> void:
	apply_gravity(dt)
	if on_floor:
		vel.x = move_toward(vel.x, 0.0, 900.0 * dt)
		hop_t -= dt
		if hop_t <= 0.0:
			var tp := to_player()
			if tp.length() < 320.0:
				facing = 1 if tp.x > 0.0 else -1
			elif wall_ahead(facing) or edge_ahead(facing):
				facing = -facing
			vel = Vector2(facing * 150.0, -400.0)
			hop_t = randf_range(0.7, 1.3)
	var r := move(dt)
	if int(r["wall"]) != 0:
		facing = -int(r["wall"])


func _draw() -> void:
	aura_glow()
	var sq := clampf(1.0 - vel.y / 1400.0, 0.75, 1.3)
	var col := Color(0.25, 0.55, 0.95)
	ellipse(Vector2(0, half.y - 9.0 * sq), 14.0 / sq, 10.0 * sq, col)
	ellipse(Vector2(-4, half.y - 13.0 * sq), 4.0, 2.5, Color(1, 1, 1, 0.4))
	eyes(Vector2(facing * 3.0, half.y - 10.0 * sq), 4.5, 3.0, Vector2(facing, 0))
	hpbar()
