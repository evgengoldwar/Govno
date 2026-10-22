extends Node2D
## The elemental hero. Switches between unlocked elements.

const C = preload("res://scripts/consts.gd")

const SPEED := 235.0
const ACC := 2300.0
const AIR_ACC := 1600.0
const GRAV := 1700.0
const JUMP_V := 760.0
const DJUMP_V := 690.0
const MAX_FALL := 820.0
const COYOTE := 0.1
const BUF := 0.13
const DASH_V := 640.0
const DASH_T := 0.17
const DASH_CD := 0.5

const SHOTS := {
	"fire": {"speed": 560.0, "dmg": 2.0, "cd": 0.24, "r": 7.0, "grav": 0.0, "life": 0.8, "kb": 120.0, "pierce": 0, "lift": 0.0},
	"water": {"speed": 470.0, "dmg": 1.8, "cd": 0.27, "r": 8.0, "grav": 0.0, "life": 0.9, "kb": 260.0, "pierce": 1, "lift": 0.0},
	"poison": {"speed": 420.0, "dmg": 1.2, "cd": 0.3, "r": 7.0, "grav": 700.0, "life": 1.2, "kb": 60.0, "pierce": 0, "lift": -170.0},
	"air": {"speed": 640.0, "dmg": 1.3, "cd": 0.2, "r": 10.0, "grav": 0.0, "life": 0.38, "kb": 480.0, "pierce": 2, "lift": 0.0},
	"earth": {"speed": 440.0, "dmg": 4.0, "cd": 0.46, "r": 9.0, "grav": 1000.0, "life": 1.4, "kb": 300.0, "pierce": 0, "lift": -260.0},
}

var game = null
var vel := Vector2.ZERO
var half := Vector2(9, 13)
var facing := 1
var on_floor := false
var coyote := 0.0
var jump_buf := 0.0
var air_jumps := 0
var form := "fire"
var invuln := 0.0
var shoot_cd := 0.0
var dash_t := 0.0
var dash_cd := 0.0
var dash_air_used := false
var swim_cd := 0.0
var safe_pos := Vector2.ZERO
var safe_timer := 0.0
var water_dmg_t := 0.0
var freeze := 0.0
var knock_t := 0.0
var anim := 0.0
var squash := Vector2.ONE
var dead := false
var trail_t := 0.0
var down_t := 0.0
var drop_t := 0.0
var liquid := 0
var native_liquid := false
var wind := 0.0


func set_form(f: String) -> void:
	if f == form:
		return
	form = f
	squash = Vector2(1.3, 0.75)
	if game:
		game.fx.ring(position, C.ELEM_COLORS[f], 26.0)
		game.fx.burst(position, C.ELEM_COLORS[f], 10, 140.0, 0.4, 3.0, 0.0)
		game.sfx.play("switch")


func tick(dt: float) -> void:
	anim += dt
	invuln = maxf(0.0, invuln - dt)
	dash_cd = maxf(0.0, dash_cd - dt)
	swim_cd = maxf(0.0, swim_cd - dt)
	knock_t = maxf(0.0, knock_t - dt)
	jump_buf = maxf(0.0, jump_buf - dt)
	squash = squash.lerp(Vector2.ONE, minf(1.0, dt * 12.0))
	queue_redraw()
	if dead:
		return
	if freeze > 0.0:
		freeze -= dt
		vel = Vector2.ZERO
		return
	var inp = game.inp
	var lv = game.level

	# --- element switching
	if inp.form_sel != "" and game.has_elem(inp.form_sel):
		set_form(inp.form_sel)
	if inp.form_cycle != 0:
		var owned: Array = game.state["elements"]
		var idx := owned.find(form)
		idx = (idx + inp.form_cycle + owned.size()) % owned.size()
		set_form(owned[idx])

	# --- liquids & hazards
	liquid = lv.at_px(position)
	native_liquid = (liquid == C.T_WATER and form == "water") or (liquid == C.T_LAVA and form == "fire") \
		or (liquid == C.T_TOXIC and form == "poison")
	if form != "fire" and lv.box_has(position, half, C.T_LAVA, 4.0):
		hazard_hit("Лава! Только огонь выдержит жар")
		return
	if form != "poison" and lv.box_has(position, half, C.T_TOXIC, 4.0):
		hazard_hit("Отрава! Только яд не боится яда")
		return
	if form != "earth" and lv.box_spikes(position, half):
		hazard_hit("Шипы! Каменная кожа земли защитит")
		return
	var in_water := liquid == C.T_WATER
	if in_water and form == "fire":
		water_dmg_t += dt
		if water_dmg_t > 0.9:
			water_dmg_t = 0.0
			game.hint("Огонь гаснет в воде!")
			hurt(1, position + Vector2(0, 10), false)
			game.fx.burst(position, Color(0.8, 0.8, 0.8, 0.6), 8, 80.0, 0.6, 4.0, -100.0)
	else:
		water_dmg_t = 0.0

	# --- horizontal
	var mx: float = inp.mx
	if dash_t > 0.0:
		dash_t -= dt
		vel = Vector2(facing * DASH_V, 0.0)
		if int(anim * 60.0) % 3 == 0:
			game.fx.ghost(position, C.ELEM_COLORS[form])
	else:
		var spd := SPEED
		if C.is_liquid(liquid) and not native_liquid:
			spd *= 0.55
		elif native_liquid:
			spd *= 0.9
		var acc := ACC if on_floor else AIR_ACC
		if knock_t > 0.0:
			acc *= 0.25
		vel.x = move_toward(vel.x, mx * spd + wind, acc * dt)
		if absf(mx) > 0.25 and knock_t <= 0.0:
			facing = 1 if mx > 0.0 else -1
		# gravity
		var g := GRAV
		var max_fall := MAX_FALL
		if C.is_liquid(liquid):
			if native_liquid:
				g *= 0.25
				max_fall = 110.0
			else:
				g *= 0.5
				max_fall = 220.0
		elif vel.y < 0.0 and not inp.jump_held:
			g *= 2.3
		vel.y = minf(vel.y + g * dt, max_fall)

	# --- jump
	if inp.jump_pressed:
		jump_buf = BUF
	if jump_buf > 0.0 and dash_t <= 0.0:
		if native_liquid and swim_cd <= 0.0:
			var head: int = lv.at_px(position - Vector2(0, half.y + 8))
			var surface := not C.is_liquid(head)
			vel.y = -JUMP_V if surface else -430.0
			swim_cd = 0.2
			jump_buf = 0.0
			game.fx.burst(position + Vector2(0, half.y), C.ELEM_COLORS[form], 6, 90.0, 0.4, 3.0, 0.0)
			game.sfx.play("swim")
		elif on_floor or coyote > 0.0:
			var jv := JUMP_V
			if C.is_liquid(liquid) and not native_liquid:
				jv *= 0.55
			vel.y = -jv
			coyote = 0.0
			jump_buf = 0.0
			on_floor = false
			squash = Vector2(0.7, 1.3)
			game.fx.burst(position + Vector2(0, half.y), Color(1, 1, 1, 0.5), 6, 70.0, 0.3, 3.0, 0.0)
			game.sfx.play("jump")
		elif form == "air" and air_jumps > 0 and not C.is_liquid(liquid):
			vel.y = -DJUMP_V
			air_jumps -= 1
			jump_buf = 0.0
			squash = Vector2(0.7, 1.3)
			game.fx.ring(position + Vector2(0, half.y), C.ELEM_COLORS["air"], 22.0)
			game.fx.burst(position + Vector2(0, half.y), C.ELEM_COLORS["air"], 10, 160.0, 0.35, 3.0, 0.0)
			game.sfx.play("djump")

	# --- dash
	if inp.dash_pressed and game.state["dash"] and dash_cd <= 0.0 and (on_floor or not dash_air_used):
		dash_t = DASH_T
		dash_cd = DASH_CD
		invuln = maxf(invuln, DASH_T + 0.05)
		if absf(mx) > 0.25:
			facing = 1 if mx > 0.0 else -1
		if not on_floor:
			dash_air_used = true
		game.sfx.play("dash")

	# --- drop through one-way platforms by holding down
	if inp.my > 0.7 and on_floor:
		down_t += dt
	else:
		down_t = 0.0
	drop_t = maxf(0.0, drop_t - dt)
	if down_t > 0.12 and drop_t <= 0.0:
		drop_t = 0.22
		down_t = 0.0
		vel.y = maxf(vel.y, 120.0)
	var drop := drop_t > 0.0

	# --- move
	var r: Dictionary = lv.move_box(position, half, vel, dt, drop)
	position = r["pos"]
	vel = r["vel"]
	var was := on_floor
	on_floor = r["floor"]
	if on_floor:
		coyote = COYOTE
		air_jumps = 1
		dash_air_used = false
		if not was:
			squash = Vector2(1.3, 0.75)
			game.fx.burst(position + Vector2(0, half.y), Color(1, 1, 1, 0.35), 5, 60.0, 0.3, 3.0, 0.0)
	else:
		coyote -= dt

	# flame walls burn on touch
	if lv.box_has(position, half + Vector2(3, 3), C.T_FLAME, 0.0):
		var fx := floorf(position.x / C.TILE)
		hurt(1, Vector2((fx + 0.5) * C.TILE, position.y), true)
		game.hint("Пламя погасит только вода")

	# --- shooting (hold to auto-fire)
	shoot_cd -= dt
	if inp.attack_held and shoot_cd <= 0.0 and dash_t <= 0.0:
		shoot(inp)

	# --- safe spot for hazard respawns
	if on_floor and r["floor_code"] != C.T_ONEWAY and not C.is_liquid(liquid):
		safe_timer += dt
		if safe_timer > 0.3:
			safe_pos = position
	else:
		safe_timer = 0.0

	# --- ambient trail
	trail_t -= dt
	if trail_t <= 0.0:
		trail_t = 0.07
		_trail()


func shoot(inp) -> void:
	var s: Dictionary = SHOTS[form]
	shoot_cd = s["cd"]
	var dir := Vector2(facing, 0)
	if inp.my < -0.5:
		dir = Vector2(sign(inp.mx), -1).normalized() if absf(inp.mx) > 0.45 else Vector2(0, -1)
	elif inp.my > 0.5 and not on_floor:
		dir = Vector2(sign(inp.mx), 1).normalized() if absf(inp.mx) > 0.45 else Vector2(0, 1)
	var v: Vector2 = dir * float(s["speed"])
	if dir.y == 0.0:
		v.y += float(s["lift"])
	var dmg: float = float(s["dmg"]) * (1.0 + 0.25 * float(game.state["power"]))
	var origin := position + Vector2(dir.x * 12.0, -2.0 + dir.y * 10.0)
	game.proj.spawn({
		"pos": origin, "vel": v, "r": s["r"], "dmg": dmg, "elem": form, "owner": "p",
		"life": s["life"], "grav": s["grav"], "kb": s["kb"], "pierce": s["pierce"],
	})
	if dir.y == 0.0:
		vel.x -= facing * (40.0 if form != "air" else 90.0)
	squash = Vector2(1.12, 0.9)
	game.sfx.play("shoot_" + form)


func hurt(dmg: int, from: Vector2, knock := true) -> void:
	if invuln > 0.0 or dead or game.state["hp"] <= 0:
		return
	game.state["hp"] = int(game.state["hp"]) - dmg
	invuln = 1.0 + 0.45 * float(game.state["armor"])
	if knock:
		var dx := signf(position.x - from.x)
		if dx == 0.0:
			dx = -facing
		vel = Vector2(dx * 280.0, -330.0)
		knock_t = 0.25
		dash_t = 0.0
	game.shake(7.0)
	game.hitstop(0.06)
	game.fx.burst(position, Color(1, 0.3, 0.3), 14, 220.0, 0.5, 3.5, 300.0)
	game.sfx.play("hurt")
	if int(game.state["hp"]) <= 0:
		die()


func hazard_hit(msg: String) -> void:
	game.hint(msg)
	game.fx.burst(position, C.ELEM_COLORS[form], 16, 200.0, 0.5, 4.0, 200.0)
	if invuln <= 0.0:
		game.state["hp"] = int(game.state["hp"]) - 1
		game.sfx.play("hurt")
		game.shake(6.0)
		if int(game.state["hp"]) <= 0:
			die()
			return
	position = safe_pos
	vel = Vector2.ZERO
	invuln = 1.2
	freeze = 0.35
	game.flash(0.35)


func die() -> void:
	dead = true
	game.fx.burst(position, C.ELEM_COLORS[form], 40, 320.0, 1.0, 5.0, 200.0)
	game.fx.ring(position, Color(1, 1, 1), 60.0)
	game.sfx.play("die")
	game.on_player_dead()


func _trail() -> void:
	var col: Color = C.ELEM_COLORS[form]
	match form:
		"fire":
			game.fx.spark(position + Vector2(randf_range(-6, 6), -8), Vector2(randf_range(-20, 20), -70), col, 0.45, 3.0, -40.0)
		"water":
			if randf() < 0.5:
				game.fx.spark(position + Vector2(randf_range(-7, 7), 4), Vector2(0, 30), col, 0.5, 2.0, 300.0)
		"poison":
			game.fx.spark(position + Vector2(randf_range(-8, 8), randf_range(-8, 8)), Vector2(0, -25), col, 0.6, 2.5, -10.0)
		"air":
			var a := anim * 8.0
			game.fx.spark(position + Vector2(cos(a), sin(a)) * 15.0, Vector2(-sin(a), cos(a)) * 40.0, col, 0.3, 2.0, 0.0)
		"earth":
			if randf() < 0.3:
				game.fx.spark(position + Vector2(randf_range(-6, 6), 10), Vector2(randf_range(-30, 30), -40), col.darkened(0.3), 0.5, 2.5, 400.0)


func _draw() -> void:
	if dead:
		return
	if invuln > 0.0 and int(anim * 18.0) % 2 == 0 and dash_t <= 0.0:
		return
	var col: Color = C.ELEM_COLORS[form]
	draw_circle(Vector2(0, -1), 26.0, Color(col.r, col.g, col.b, 0.07))
	draw_circle(Vector2(0, -1), 18.0, Color(col.r, col.g, col.b, 0.1))
	draw_set_transform(Vector2(0, half.y), 0.0, squash)
	var base := Vector2(0, -half.y - 1)
	var dark := col.darkened(0.45)
	match form:
		"fire":
			var fl := sin(anim * 14.0) * 2.0
			draw_colored_polygon(PackedVector2Array([base + Vector2(-9, -4), base + Vector2(-2 + fl, -22), base + Vector2(2, -10), base + Vector2(6 - fl, -19), base + Vector2(9, -4)]), col)
			draw_colored_polygon(PackedVector2Array([base + Vector2(-5, -4), base + Vector2(0 + fl, -15), base + Vector2(5, -4)]), Color(1, 0.9, 0.45))
			draw_circle(base, 11.0, col)
			draw_circle(base + Vector2(0, 2), 7.5, Color(1, 0.8, 0.35))
		"water":
			draw_colored_polygon(PackedVector2Array([base + Vector2(-9, -5), base + Vector2(0, -21), base + Vector2(9, -5)]), col)
			draw_circle(base, 11.0, col)
			draw_circle(base + Vector2(-4, -4), 3.0, Color(1, 1, 1, 0.6))
		"poison":
			draw_circle(base, 11.5, col)
			for i in range(3):
				var a := anim * 2.0 + i * TAU / 3.0
				draw_circle(base + Vector2(cos(a) * 14.0, sin(a) * 6.0 - 4.0), 3.0, col.lightened(0.2))
			draw_circle(base + Vector2(3, 4), 4.0, dark)
		"air":
			draw_circle(base, 11.0, col)
			for i in range(2):
				var a2 := anim * 6.0 + i * PI
				draw_arc(base, 15.0, a2, a2 + 1.6, 8, Color(col.r, col.g, col.b, 0.7), 2.0)
		"earth":
			var pts := PackedVector2Array()
			for i in range(6):
				var a3 := i * TAU / 6.0 + PI / 6.0
				pts.append(base + Vector2(cos(a3), sin(a3)) * 12.5)
			draw_colored_polygon(pts, col)
			draw_line(base + Vector2(-6, 6), base + Vector2(1, 0), dark, 2.0)
			draw_line(base + Vector2(1, 0), base + Vector2(-1, -7), dark, 2.0)
	# eyes
	var ex := 3.5 * facing
	var look := Vector2(facing * 1.5, 0)
	if game and game.inp.my < -0.5:
		look = Vector2(0, -1.5)
	var blink := 1.0 if fmod(anim, 3.7) > 0.12 else 0.2
	for s in [-1, 1]:
		var ep := base + Vector2(ex + s * 4.0, -1)
		draw_set_transform(Vector2(0, half.y) + ep * squash, 0.0, Vector2(squash.x, squash.y * blink))
		draw_circle(Vector2.ZERO, 3.2, Color(1, 1, 1))
		draw_circle(look, 1.8, Color(0.08, 0.06, 0.1))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
