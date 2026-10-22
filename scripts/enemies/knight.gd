extends "res://scripts/enemy.gd"
## Shielded knight: patrols and charges. Blocks hits from the front.

var state := "patrol"
var st := 0.0


func setup() -> void:
	init_stats(9.0, "earth", Vector2(12, 16), 4)
	knock_res = 0.6


func ai(dt: float) -> void:
	apply_gravity(dt)
	st -= dt
	var tp := to_player()
	match state:
		"patrol":
			vel.x = facing * 55.0
			if on_floor and (wall_ahead(facing) or edge_ahead(facing)):
				facing = -facing
			if absf(tp.x) < 300.0 and absf(tp.y) < 60.0:
				facing = 1 if tp.x > 0.0 else -1
				state = "wind"
				st = 0.45
		"wind":
			vel.x = 0.0
			if st <= 0.0:
				state = "charge"
				st = 1.0
				game.sfx.play("charge")
		"charge":
			vel.x = facing * 300.0
			if on_floor and (wall_ahead(facing) or edge_ahead(facing)):
				vel.x = 0.0
				st = 0.0
			if st <= 0.0:
				state = "rest"
				st = 0.8
		"rest":
			vel.x = move_toward(vel.x, 0.0, 1200.0 * dt)
			if st <= 0.0:
				state = "patrol"
	move(dt)


func dmg_scale(_el: String, kb: Vector2) -> float:
	if kb.x != 0.0 and signf(kb.x) == -float(facing) and absf(kb.y) < absf(kb.x):
		game.fx.burst(position + Vector2(facing * 14.0, 0), Color(1, 1, 0.8), 6, 150.0, 0.2, 2.0, 0.0)
		return 0.25
	return 1.0


func _draw() -> void:
	aura_glow()
	var steel := Color(0.55, 0.58, 0.66)
	var lean := 0.0
	if state == "charge":
		lean = facing * 3.0
	elif state == "wind":
		lean = -facing * 2.0
	var bob := sin(t * 10.0) * 1.0 if absf(vel.x) > 1.0 else 0.0
	draw_rect(Rect2(-9 + lean, -6 + bob, 18, 18), steel.darkened(0.15))
	draw_rect(Rect2(-7, 12, 5, 4), steel.darkened(0.4))
	draw_rect(Rect2(2, 12, 5, 4), steel.darkened(0.4))
	draw_rect(Rect2(-8 + lean, -17 + bob, 16, 12), steel)
	draw_rect(Rect2(-6 + lean + facing * 2.0, -12 + bob, 12, 2), ecol().lightened(0.4) if state != "patrol" else Color(0.1, 0.1, 0.12))
	draw_colored_polygon(PackedVector2Array([Vector2(-2 + lean, -17 + bob), Vector2(0 + lean, -23 + bob), Vector2(2 + lean, -17 + bob)]), Color(0.8, 0.2, 0.2))
	var sx := facing * 12.0 + lean
	draw_rect(Rect2(sx - 3, -10 + bob, 6, 22), Color(0.45, 0.35, 0.25))
	draw_rect(Rect2(sx - 3, -10 + bob, 6, 22), ecol(), false, 1.5)
	if state == "wind":
		draw_circle(Vector2(0, -2), 20.0, Color(1, 0.5, 0.2, 0.15))
	hpbar()
