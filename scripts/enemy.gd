extends Node2D
## Base class for all enemies and bosses.

const C = preload("res://scripts/consts.gd")

var game = null
var kind := ""
var hp := 3.0
var max_hp := 3.0
var elem := "none"
var half := Vector2(12, 12)
var vel := Vector2.ZERO
var on_floor := false
var facing := -1
var contact := 1
var coin_drop := 2
var flash := 0.0
var poison_t := 0.0
var poison_acc := 0.0
var alive := true
var t := 0.0
var is_boss := false
var boss_id := ""
var boss_name := ""
var knock_res := 0.0
var grav := 1600.0
var home := Vector2.ZERO
var invulnerable := false
var alpha := 1.0


func setup() -> void:
	pass


func init_stats(h: float, el: String, hf: Vector2, coins: int) -> void:
	hp = h
	max_hp = h
	elem = el
	half = hf
	coin_drop = coins


func tick(dt: float) -> void:
	t += dt
	flash = maxf(0.0, flash - dt)
	if poison_t > 0.0:
		poison_t -= dt
		poison_acc += dt
		if poison_acc >= 0.5:
			poison_acc = 0.0
			_damage(0.5 * C.mult("poison", elem) * (1.0 + 0.25 * float(game.state["power"])), false)
			game.fx.spark(position + Vector2(randf_range(-8, 8), -half.y), Vector2(0, -40), C.ELEM_COLORS["poison"], 0.5, 3.0, 0.0)
			if not alive:
				return
	ai(dt)
	if not alive:
		return
	if contact > 0 and not invulnerable and game.player != null and not game.player.dead:
		if overlaps_player():
			game.player.hurt(contact, position)
	if flash > 0.0:
		modulate = Color(2.2, 2.2, 2.2, alpha)
	elif poison_t > 0.0:
		modulate = Color(0.75, 1.15, 0.65, alpha)
	else:
		modulate = Color(1, 1, 1, alpha)
	# fell out of the room
	if not game.level.rect_px().grow(64).has_point(position):
		alive = false
		game.on_enemy_dead(self)
		queue_free()
		return
	queue_redraw()


func ai(_dt: float) -> void:
	pass


func apply_gravity(dt: float) -> void:
	vel.y = minf(vel.y + grav * dt, 900.0)


func move(dt: float, drop := false) -> Dictionary:
	var r: Dictionary = game.level.move_box(position, half, vel, dt, drop)
	position = r["pos"]
	vel = r["vel"]
	on_floor = r["floor"]
	return r


func pl():
	return game.player


func to_player() -> Vector2:
	return game.player.position - position


func player_dist() -> float:
	return to_player().length()


func edge_ahead(dirx: int) -> bool:
	return not game.level.ground_at(position.x + dirx * (half.x + 4.0), position.y + half.y + 6.0)


func wall_ahead(dirx: int) -> bool:
	return game.level.solid_px(Vector2(position.x + dirx * (half.x + 4.0), position.y))


func hit_test(p: Vector2, r: float) -> bool:
	if invulnerable:
		return false
	var cx := clampf(p.x, position.x - half.x, position.x + half.x)
	var cy := clampf(p.y, position.y - half.y, position.y + half.y)
	return Vector2(cx, cy).distance_to(p) < r + 2.0


func overlaps_player() -> bool:
	var p = game.player
	var a := Rect2(position - half * 0.85, half * 1.7)
	var b := Rect2(p.position - p.half, p.half * 2.0)
	return a.intersects(b)


## Override to block or amplify hits (shields, weak points...).
func dmg_scale(_el: String, _kb: Vector2) -> float:
	return 1.0


func hit(dmg: float, el: String, kb: Vector2) -> void:
	if not alive or invulnerable:
		return
	var m := C.mult(el, elem) * dmg_scale(el, kb)
	if el == "poison":
		poison_t = 3.0
	vel += kb * (1.0 - knock_res)
	var d := dmg * m
	var col := Color(1, 1, 1)
	if m >= 1.9:
		col = Color(1.0, 0.9, 0.3)
	elif m < 0.5:
		col = Color(0.6, 0.6, 0.65)
	game.fx.text(position - Vector2(0, half.y + 8), str(snappedf(d, 0.1)) if d < 10.0 else str(int(d)), col, 15 if m < 1.9 else 19)
	if m < 0.5:
		game.sfx.play("block")
	else:
		game.sfx.play("hit")
	_damage(d, true)


func _damage(d: float, do_flash: bool) -> void:
	hp -= d
	if do_flash:
		flash = 0.08
	if hp <= 0.0 and alive:
		die()


func die() -> void:
	alive = false
	var col: Color = C.ELEM_COLORS[elem]
	game.fx.burst(position, col, 22, 260.0, 0.7, 4.0, 300.0)
	game.fx.burst(position, Color(1, 1, 1), 8, 160.0, 0.4, 3.0, 0.0)
	game.spawn_coins(position, coin_drop)
	game.sfx.play("kill")
	game.on_enemy_dead(self)
	queue_free()


# ---------------------------------------------------------------- drawing helpers
func ecol() -> Color:
	return C.ELEM_COLORS[elem]


func ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	draw_set_transform(c, 0.0, Vector2(rx, ry) / 10.0)
	draw_circle(Vector2.ZERO, 10.0, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func eyes(c: Vector2, spread: float, r: float, look: Vector2, col := Color(1, 1, 1), pupil := Color(0.05, 0.05, 0.08)) -> void:
	for s in [-1.0, 1.0]:
		var p: Vector2 = c + Vector2(s * spread, 0)
		draw_circle(p, r, col)
		draw_circle(p + look.limit_length(1.0) * r * 0.45, r * 0.55, pupil)


func glow_eyes(c: Vector2, spread: float, r: float) -> void:
	var col := ecol()
	for s in [-1.0, 1.0]:
		var p: Vector2 = c + Vector2(s * spread, 0)
		draw_circle(p, r * 2.0, Color(col.r, col.g, col.b, 0.25))
		draw_circle(p, r, col.lightened(0.3))


func aura_glow() -> void:
	var col := ecol()
	draw_circle(Vector2.ZERO, maxf(half.x, half.y) * 1.6, Color(col.r, col.g, col.b, 0.07))


func hpbar() -> void:
	if hp < max_hp and not is_boss:
		var w := half.x * 2.0
		draw_rect(Rect2(-w / 2.0, -half.y - 10, w, 3), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-w / 2.0, -half.y - 10, w * clampf(hp / max_hp, 0.0, 1.0), 3), ecol())
