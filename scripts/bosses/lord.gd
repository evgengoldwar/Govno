extends "res://scripts/enemy.gd"
## Final boss: the Abyss Lord. His aura cycles through the elements; only the
## element that beats the current aura really hurts him.

const ORDER := ["fire", "water", "poison", "earth", "air"]

var state := "dormant"
var st := 0.0
var phase := 1
var aura := "fire"
var next_aura := "water"
var aura_t := 7.0
var atk_cd := 2.0
var volley := 0
var vt := 0.0
var spiral_cd := 4.0
var spiral_a := 0.0
var rocks: Array = []
var beams: Array = []
var wind_t := 0.0
var wind_dir := 1.0
var targets: Array = []
var target_i := 0
var move_t := 0.0
var lava_on := false
var lava_warn := 0.0
var lava_tiles: Array = []
var dying_t := 0.0
var absorbed_hint := 0.0


func setup() -> void:
	init_stats(640.0, "fire", Vector2(26, 30), 0)
	is_boss = true
	boss_id = "lord"
	boss_name = "Владыка Бездны"
	knock_res = 1.0
	grav = 0.0
	home = position
	var rect: Rect2 = game.level.rect_px()
	targets = [
		Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y + 150.0),
		Vector2(rect.position.x + 190.0, rect.position.y + 170.0),
		Vector2(rect.end.x - 190.0, rect.position.y + 170.0),
		Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y + 260.0),
	]
	aura = "fire"
	elem = aura


func _period() -> float:
	return [7.0, 5.5, 4.5][phase - 1]


func ai(dt: float) -> void:
	st -= dt
	absorbed_hint -= dt
	var rect: Rect2 = game.level.rect_px()
	if state == "dormant":
		position = home + Vector2(0, sin(t * 1.5) * 6.0)
		if player_dist() < 470.0 and game.boss_start(self):
			state = "fight"
			atk_cd = 2.5
			aura_t = _period()
		return
	if state == "dying":
		dying_t -= dt
		position += Vector2(randf_range(-2, 2), randf_range(-2, 2))
		if randf() < 0.4:
			var c: Color = C.ELEM_COLORS[ORDER[randi() % 5]]
			game.fx.burst(position + Vector2(randf_range(-30, 30), randf_range(-30, 30)), c, 12, 260.0, 0.8, 5.0, 0.0)
			game.sfx.play("kill")
		if dying_t <= 0.0:
			game.fx.burst(position, Color(1, 1, 1), 80, 500.0, 1.4, 6.0, 0.0)
			for e in ORDER:
				game.fx.ring(position, C.ELEM_COLORS[e], 80.0 + ORDER.find(e) * 30.0)
			_set_lava(false)
			game.player.wind = 0.0
			alive = false
			game.on_enemy_dead(self)
			queue_free()
		return

	# --- phases
	var frac := hp / max_hp
	var new_phase := 1 if frac > 0.66 else (2 if frac > 0.33 else 3)
	if new_phase != phase:
		phase = new_phase
		game.banner("Фаза " + str(phase), "Владыка Бездны в ярости!" if phase == 2 else "Пол становится лавой — огонь спасёт!")
		game.shake(10.0)
		game.sfx.play("roar")
		if phase == 3:
			lava_warn = 1.6
	contact = 2 if phase == 3 else 1
	if lava_warn > 0.0:
		lava_warn -= dt
		if lava_warn <= 0.0:
			_set_lava(true)

	# --- aura cycle
	aura_t -= dt
	if aura_t <= 1.1 and next_aura == aura:
		var opts: Array = ORDER.duplicate()
		opts.erase(aura)
		next_aura = opts[randi() % opts.size()]
	if aura_t <= 0.0:
		aura = next_aura
		elem = aura
		aura_t = _period()
		game.fx.ring(position, C.ELEM_COLORS[aura], 90.0)
		game.sfx.play("switch")
		_maybe_summon()

	# --- movement between anchor points
	move_t -= dt
	if move_t <= 0.0:
		move_t = randf_range(2.5, 4.0) / (1.0 + 0.25 * (phase - 1))
		target_i = (target_i + 1 + randi() % (targets.size() - 1)) % targets.size()
	var tgt: Vector2 = targets[target_i] + Vector2(sin(t * 1.3) * 30.0, sin(t * 2.1) * 14.0)
	position = position.lerp(tgt, minf(1.0, dt * 1.6))
	facing = 1 if to_player().x > 0.0 else -1

	# --- attacks
	atk_cd -= dt
	if atk_cd <= 0.0 and volley <= 0:
		_start_attack()
	if volley > 0:
		vt -= dt
		if vt <= 0.0:
			_attack_step()
	if phase >= 2:
		spiral_cd -= dt
		if spiral_cd <= 0.0:
			spiral_cd = 4.2 if phase == 2 else 3.0
			var n := 12 if phase == 2 else 16
			spiral_a += 0.35
			for i in range(n):
				var a := spiral_a + i * TAU / n
				game.proj.spawn({"pos": position, "vel": Vector2(cos(a), sin(a)) * 165.0, "r": 7.0, "dmg": 1, "elem": aura, "owner": "e", "life": 4.5})
			game.sfx.play("crystal")

	# --- wind
	if wind_t > 0.0:
		wind_t -= dt
		var pl = game.player
		if not pl.dead:
			pl.wind = wind_dir * 170.0 * (0.35 if pl.form == "earth" else 1.0)
		if wind_t <= 0.0:
			pl.wind = 0.0
		if randf() < 0.6:
			var y := randf_range(rect.position.y + 40.0, rect.end.y - 60.0)
			var x := rect.position.x + 20.0 if wind_dir > 0.0 else rect.end.x - 20.0
			game.fx.spark(Vector2(x, y), Vector2(wind_dir * 600.0, 0), Color(0.85, 0.95, 1.0, 0.5), 1.2, 2.0, 0.0)

	# --- telegraphed rocks and beams
	var keep: Array = []
	for rk in rocks:
		rk["t"] = float(rk["t"]) - dt
		if float(rk["t"]) <= 0.0:
			game.proj.spawn({"pos": Vector2(rk["x"], rect.position.y + 40.0), "vel": Vector2(0, 80), "grav": 950.0, "r": 13.0, "dmg": 1,
				"kind": "rock", "elem": "earth", "owner": "e", "life": 3.0})
		else:
			keep.append(rk)
	rocks = keep
	var keep2: Array = []
	for bm in beams:
		bm["t"] = float(bm["t"]) - dt
		if float(bm["t"]) <= 0.0:
			game.proj.spawn({"pos": Vector2(bm["x"], rect.end.y - C.TILE * 2.0), "vel": Vector2.ZERO, "r": 16.0, "h": rect.size.y, "kind": "beam",
				"dmg": 2, "elem": aura, "owner": "e", "life": 0.45, "walls": false})
			game.shake(4.0)
			game.sfx.play("beam")
		else:
			keep2.append(bm)
	beams = keep2


func _start_attack() -> void:
	match aura:
		"fire":
			volley = 3 if phase < 3 else 4
		"water":
			volley = 2 if phase < 3 else 3
		"poison":
			volley = 2
		"earth":
			volley = 1
		"air":
			volley = 4
	vt = 0.3
	if phase == 3 and randf() < 0.45:
		var px: float = game.player.position.x
		for dx in [-110.0, 0.0, 110.0]:
			beams.append({"x": px + dx, "t": 0.9 + absf(dx) * 0.002})


func _attack_step() -> void:
	volley -= 1
	var tp := to_player()
	var rect: Rect2 = game.level.rect_px()
	var floor_y: float = rect.end.y - C.TILE * 2.0
	match aura:
		"fire":
			vt = 0.45
			var n := 7 if phase < 3 else 9
			for i in range(n):
				var a := (float(i) - (n - 1) / 2.0) * 0.17
				game.proj.spawn({"pos": position, "vel": tp.normalized().rotated(a) * 300.0, "r": 8.0, "dmg": 1, "elem": "fire", "owner": "e", "life": 3.0})
			game.sfx.play("fireball")
		"water":
			vt = 1.0
			var from_left := volley % 2 == 0
			var x := rect.position.x + 50.0 if from_left else rect.end.x - 50.0
			game.proj.spawn({"pos": Vector2(x, floor_y), "vel": Vector2(310.0 if from_left else -310.0, 0), "r": 18.0, "h": 46.0,
				"kind": "wave", "dmg": 1, "elem": "water", "owner": "e", "life": 4.0})
			game.sfx.play("wave")
			if phase >= 2:
				for i in range(5):
					game.proj.spawn({"pos": position, "vel": Vector2(randf_range(-160, 160), -200), "grav": 500.0, "r": 6.0, "dmg": 1, "elem": "water", "owner": "e", "life": 3.0})
		"poison":
			vt = 0.8
			for i in range(6):
				var vx := (float(i) - 2.5) * 70.0 + tp.x * 0.4
				game.proj.spawn({"pos": position, "vel": Vector2(vx, -220.0), "grav": 600.0, "r": 8.0, "dmg": 1, "elem": "poison", "owner": "e",
					"life": 4.0, "puddle": true})
			game.sfx.play("spit")
		"earth":
			vt = 0.5
			var n2 := 10 if phase == 1 else (12 if phase == 2 else 15)
			for i in range(n2):
				rocks.append({"x": randf_range(rect.position.x + 50.0, rect.end.x - 50.0), "t": 0.8 + i * 0.1})
			rocks.append({"x": game.player.position.x, "t": 0.8})
			game.sfx.play("rumble")
			game.shake(4.0)
		"air":
			vt = 0.55
			if volley == 3 or (volley > 0 and wind_t <= 0.0):
				wind_t = 2.6
				wind_dir = 1.0 if randf() < 0.5 else -1.0
				game.sfx.play("wind")
			game.proj.spawn({"pos": position, "vel": tp.normalized().rotated(randf_range(-0.6, 0.6)) * 150.0, "r": 9.0, "dmg": 1, "elem": "air",
				"owner": "e", "life": 5.0, "homing": 1.4, "walls": false})
	if volley <= 0:
		atk_cd = [2.2, 1.7, 1.3][phase - 1]


func _maybe_summon() -> void:
	if phase < 2:
		return
	var n := 0
	for e in game.enemies:
		if is_instance_valid(e) and e != self and e.alive:
			n += 1
	if n < 2:
		var k := "imp" if randf() < 0.5 else "skull"
		game.spawn_enemy(k, position + Vector2(randf_range(-60, 60), 30), false)


func _set_lava(on: bool) -> void:
	if on == lava_on:
		return
	lava_on = on
	var lv = game.level
	var row: int = lv.oy + lv.h - 2
	if on:
		lava_tiles.clear()
		for lx in range(1, lv.w - 1):
			if lx >= 13 and lx <= 26:
				continue
			var gx: int = lv.ox + lx
			if lv.tget(gx, row) == C.T_SOLID:
				lava_tiles.append(gx)
				lv.tset(gx, row, C.T_LAVA)
	else:
		for gx in lava_tiles:
			lv.tset(gx, row, C.T_SOLID)
		lava_tiles.clear()
	game.refresh_level()


func dmg_scale(el: String, _kb: Vector2) -> float:
	if state != "fight":
		return 0.0
	if C.BEATS.get(el, "") == aura:
		return 1.0
	if el == aura:
		if absorbed_hint <= 0.0:
			absorbed_hint = 2.0
			game.hint("Аура поглощает эту стихию!")
		return 0.0
	return 0.3


func die() -> void:
	if state == "dying":
		return
	state = "dying"
	dying_t = 3.0
	hp = 0.0
	invulnerable = true
	contact = 0
	game.proj.clear()
	game.sfx.play("roar")
	game.shake(14.0)


func _draw() -> void:
	var col: Color = C.ELEM_COLORS[aura]
	var warn := aura_t < 1.1 and next_aura != aura and state == "fight"
	if warn and int(t * 10.0) % 2 == 0:
		col = C.ELEM_COLORS[next_aura]
	# telegraphs
	var floor_off: float = game.level.rect_px().end.y - C.TILE * 2.0 - position.y
	for rk in rocks:
		var x: float = float(rk["x"]) - position.x
		var k := clampf(1.0 - float(rk["t"]), 0.0, 1.0)
		draw_rect(Rect2(x - 14, floor_off - 4, 28, 4), Color(0, 0, 0, 0.3 + 0.5 * k))
	for bm in beams:
		var x2: float = float(bm["x"]) - position.x
		draw_line(Vector2(x2, floor_off), Vector2(x2, floor_off - 700.0), Color(col.r, col.g, col.b, 0.35 + 0.3 * sin(t * 30.0)), 2.0)
	if lava_warn > 0.0 and int(t * 8.0) % 2 == 0:
		draw_rect(Rect2(-700, floor_off - 2, 1400, 6), Color(1, 0.4, 0.1, 0.6))
	# aura
	var pulse := 1.0 + 0.08 * sin(t * 4.0)
	draw_circle(Vector2.ZERO, 70.0 * pulse, Color(col.r, col.g, col.b, 0.08))
	draw_circle(Vector2.ZERO, 50.0 * pulse, Color(col.r, col.g, col.b, 0.1))
	draw_arc(Vector2.ZERO, 58.0 * pulse, t, t + TAU, 40, Color(col.r, col.g, col.b, 0.6), 2.0)
	# robe
	var robe := Color(0.1, 0.06, 0.12)
	var pts := PackedVector2Array([Vector2(-14, -18), Vector2(14, -18), Vector2(26, 10)])
	for i in range(6):
		pts.append(Vector2(26.0 - i * 10.4, 32.0 + sin(t * 5.0 + i) * 4.0))
	pts.append(Vector2(-26, 10))
	draw_colored_polygon(pts, robe)
	draw_polyline(pts, col.darkened(0.2), 2.0)
	# arms
	var sway := sin(t * 2.0) * 6.0
	draw_line(Vector2(-14, -12), Vector2(-34, 4 + sway), robe.lightened(0.1), 6.0)
	draw_line(Vector2(14, -12), Vector2(34, 4 - sway), robe.lightened(0.1), 6.0)
	draw_circle(Vector2(-34, 4 + sway), 6.0, col)
	draw_circle(Vector2(34, 4 - sway), 6.0, col)
	# head / mask
	draw_circle(Vector2(0, -26), 13.0, robe.lightened(0.05))
	draw_colored_polygon(PackedVector2Array([Vector2(-9, -32), Vector2(9, -32), Vector2(7, -18), Vector2(0, -14), Vector2(-7, -18)]), Color(0.85, 0.82, 0.75))
	draw_circle(Vector2(-4, -26), 2.6, col.lightened(0.3))
	draw_circle(Vector2(4, -26), 2.6, col.lightened(0.3))
	# crown
	draw_colored_polygon(PackedVector2Array([Vector2(-13, -36), Vector2(-15, -50), Vector2(-7, -42), Vector2(0, -54), Vector2(7, -42), Vector2(15, -50), Vector2(13, -36)]), Color(0.95, 0.75, 0.25))
	# orbiting element orbs
	for i in range(5):
		var e: String = ORDER[i]
		var a := t * 1.2 + i * TAU / 5.0
		var r := 9.0 if e == aura else 5.0
		var p := Vector2(cos(a) * 46.0, sin(a) * 16.0 - 6.0)
		var ec: Color = C.ELEM_COLORS[e]
		draw_circle(p, r * 1.8, Color(ec.r, ec.g, ec.b, 0.2))
		draw_circle(p, r, ec)
	if state == "dying":
		draw_circle(Vector2.ZERO, 40.0 + randf() * 20.0, Color(1, 1, 1, 0.3))
