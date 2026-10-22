extends Node2D
## Game root: world loading, rooms, saving, rewards and the main loop.

const C = preload("res://scripts/consts.gd")
const Level = preload("res://scripts/level.gd")
const LevelView = preload("res://scripts/level_view.gd")
const LevelAnim = preload("res://scripts/level_anim.gd")
const Background = preload("res://scripts/background.gd")
const Player = preload("res://scripts/player.gd")
const Projectiles = preload("res://scripts/projectiles.gd")
const Fx = preload("res://scripts/fx.gd")
const Prop = preload("res://scripts/prop.gd")
const Hud = preload("res://scripts/hud.gd")
const Ui = preload("res://scripts/ui.gd")
const Sfx = preload("res://scripts/sfx.gd")
const InputState = preload("res://scripts/input_state.gd")

const ENEMY_SCRIPTS := {
	"slime": preload("res://scripts/enemies/slime.gd"),
	"bat": preload("res://scripts/enemies/bat.gd"),
	"archer": preload("res://scripts/enemies/archer.gd"),
	"knight": preload("res://scripts/enemies/knight.gd"),
	"imp": preload("res://scripts/enemies/imp.gd"),
	"piranha": preload("res://scripts/enemies/piranha.gd"),
	"ghost": preload("res://scripts/enemies/ghost.gd"),
	"spider": preload("res://scripts/enemies/spider.gd"),
	"frog": preload("res://scripts/enemies/frog.gd"),
	"golem": preload("res://scripts/enemies/golem.gd"),
	"turret": preload("res://scripts/enemies/turret.gd"),
	"demon": preload("res://scripts/enemies/demon.gd"),
	"hound": preload("res://scripts/enemies/hound.gd"),
	"skull": preload("res://scripts/enemies/skull.gd"),
	"wraith": preload("res://scripts/enemies/wraith.gd"),
	"boss_warden": preload("res://scripts/bosses/warden.gd"),
	"boss_queen": preload("res://scripts/bosses/queen.gd"),
	"boss_colossus": preload("res://scripts/bosses/colossus.gd"),
	"boss_lord": preload("res://scripts/bosses/lord.gd"),
}
const BOSS_REWARD := {"warden": "poison", "queen": "air", "colossus": "earth"}
const SAVE_PATH := "user://save.json"
const T := C.TILE

var world: Dictionary = {}
var rooms: Dictionary = {}
var shops: Dictionary = {}
var level = null
var view = null
var anim = null
var bg = null
var ents: Node2D
var props_root: Node2D
var player = null
var proj = null
var fx = null
var cam: Camera2D
var hud = null
var ui = null
var sfx = null
var inp = null

var enemies: Array = []
var props: Array = []
var state: Dictionary = {}
var playing := false
var boss = null
var boss_locked: Array = []
var interact_target = null
var seal_tiles: Array = []

var hint_text := ""
var hint_t := 0.0
var banner_title := ""
var banner_sub := ""
var banner_t := 0.0
var room_label := ""
var room_label_t := 0.0
var shake_amt := 0.0
var flash_t := 0.0
var hitstop_t := 0.0
var fade := 0.0
var dead_t := -1.0
var victory_t := -1.0
var reward_t := -1.0
var pending_reward := ""


func _ready() -> void:
	randomize()
	_setup_actions()
	# run the simulation at the display refresh rate so 90/120 Hz phones stay smooth
	var hz := DisplayServer.screen_get_refresh_rate()
	if hz > 61.0:
		Engine.physics_ticks_per_second = clampi(int(round(hz)), 60, 144)
		Engine.max_physics_steps_per_frame = 8
	var f := FileAccess.open("res://data/world.json", FileAccess.READ)
	world = JSON.parse_string(f.get_as_text())
	for r in world["rooms"]:
		rooms[r["id"]] = r
	shops = world["shops"]
	level = Level.new()
	inp = InputState.new()
	state = _default_state()

	bg = Background.new()
	bg.z_index = -20
	add_child(bg)
	view = LevelView.new()
	add_child(view)
	anim = LevelAnim.new()
	add_child(anim)
	props_root = Node2D.new()
	add_child(props_root)
	ents = Node2D.new()
	add_child(ents)
	player = Player.new()
	player.game = self
	player.visible = false
	add_child(player)
	proj = Projectiles.new()
	proj.game = self
	add_child(proj)
	fx = Fx.new()
	add_child(fx)
	cam = Camera2D.new()
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 7.0
	add_child(cam)
	cam.make_current()
	sfx = Sfx.new()
	add_child(sfx)
	var hl := CanvasLayer.new()
	hl.layer = 10
	add_child(hl)
	hud = Hud.new()
	hud.game = self
	hl.add_child(hud)
	var ul := CanvasLayer.new()
	ul.layer = 20
	add_child(ul)
	ui = Ui.new()
	ui.game = self
	ul.add_child(ui)

	_load_room(world["start"])
	player.position = _spawn_pos()
	cam.position = player.position
	cam.reset_smoothing()
	ui.open("title")


func _setup_actions() -> void:
	var map := {
		"left": [KEY_A, KEY_LEFT], "right": [KEY_D, KEY_RIGHT], "up": [KEY_W, KEY_UP], "down": [KEY_S, KEY_DOWN],
		"jump": [KEY_SPACE, KEY_Z, KEY_K], "attack": [KEY_X, KEY_J], "dash": [KEY_C, KEY_SHIFT, KEY_L],
		"heal": [KEY_F, KEY_H], "interact": [KEY_E, KEY_ENTER], "f1": [KEY_1], "f2": [KEY_2], "f3": [KEY_3],
		"f4": [KEY_4], "f5": [KEY_5], "prev": [KEY_Q], "next": [KEY_R], "map": [KEY_M, KEY_TAB], "pause": [KEY_ESCAPE, KEY_P],
	}
	for a in map.keys():
		if not InputMap.has_action(a):
			InputMap.add_action(a)
		for k in map[a]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(a, ev)


func _default_state() -> Dictionary:
	return {
		"max_hp": 5, "hp": 5, "coins": 0, "flasks_max": 2, "flasks": 2, "power": 0, "dash": false, "armor": 0,
		"magnet": false, "map": false, "elements": ["fire", "water"], "seals": 0,
		"removed": {}, "taken": {}, "bosses": {}, "bought": {}, "visited": {},
		"room": world.get("start", "C1"), "altar_room": world.get("start", "C1"), "altar_pos": [], "deaths": 0, "time": 0.0, "won": false,
	}


func _spawn_pos() -> Vector2:
	var r: Dictionary = rooms[world["start"]]
	for e in r["ents"]:
		if e["t"] == "spawn":
			return _ent_pos(r, e) + Vector2(0, -T / 2.0)
	return level.rect_px().get_center()


func _ent_pos(r: Dictionary, e: Dictionary) -> Vector2:
	var ox := int(r["gx"]) * C.CW
	var oy := int(r["gy"]) * C.CH
	return Vector2((ox + float(e["x"]) + 0.5) * T, (oy + float(e["y"]) + 1.0) * T)


# ================================================================== main loop
func _physics_process(delta: float) -> void:
	var dt := minf(delta, 1.0 / 30.0)
	hud.poll(inp)
	fx.tick(dt)
	_update_camera(dt)
	hud.tick(dt)
	hint_t = maxf(0.0, hint_t - dt)
	banner_t = maxf(0.0, banner_t - dt)
	room_label_t = maxf(0.0, room_label_t - dt)
	flash_t = maxf(0.0, flash_t - dt * 2.0)
	fade = maxf(0.0, fade - dt * 2.5)
	if ui.mode != "":
		ui.tick(dt)
		return
	if not playing:
		return
	state["time"] = float(state["time"]) + dt
	if inp.pause_pressed or inp.map_pressed:
		ui.open("pause")
		return
	if hitstop_t > 0.0:
		hitstop_t -= dt
		return
	player.tick(dt)
	_check_transition()
	for e in enemies.duplicate():
		if is_instance_valid(e) and e.alive:
			e.tick(dt)
	for p in props.duplicate():
		if is_instance_valid(p):
			p.tick(dt)
	proj.tick(dt)
	_interactions()
	_check_seals()
	if inp.heal_pressed:
		use_flask()
	if player.dead:
		dead_t -= dt
		if dead_t <= 0.0:
			ui.open("dead")
	if reward_t > 0.0:
		reward_t -= dt
		if reward_t <= 0.0:
			ui.open_reward(pending_reward)
			sfx.play("unlock")
	if victory_t > 0.0:
		victory_t -= dt
		if victory_t <= 0.0:
			state["won"] = true
			save_game()
			ui.open("victory")


func _update_camera(dt: float) -> void:
	if player.visible and not player.dead:
		cam.position = player.position + Vector2(player.facing * 36.0, -20.0)
	cam.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_amt
	shake_amt = move_toward(shake_amt, 0.0, 40.0 * dt)
	var size := get_viewport_rect().size / cam.zoom
	var center := cam.get_screen_center_position()
	bg.tick(dt, center, size, level.biome)
	anim.tick(dt, Rect2(center - size / 2.0, size))


func _check_transition() -> void:
	if player.dead:
		return
	var p: Vector2 = player.position
	if level.contains_px(p):
		return
	var gx := int(floor(p.x / T))
	var gy := int(floor(p.y / T))
	var target := _room_at(gx, gy)
	if target == "":
		var rp: Rect2 = level.rect_px()
		player.position = Vector2(clampf(p.x, rp.position.x + 12.0, rp.end.x - 12.0), clampf(p.y, rp.position.y + 16.0, rp.end.y - 16.0))
		return
	_load_room(target)


func _room_at(gx: int, gy: int) -> String:
	for rid in rooms.keys():
		var r: Dictionary = rooms[rid]
		var x0 := int(r["gx"]) * C.CW
		var y0 := int(r["gy"]) * C.CH
		if gx >= x0 and gx < x0 + int(r["w"]) * C.CW and gy >= y0 and gy < y0 + int(r["h"]) * C.CH:
			return rid
	return ""


# ================================================================== rooms
func _load_room(id: String) -> void:
	for e in enemies:
		if is_instance_valid(e):
			e.queue_free()
	enemies.clear()
	for p in props:
		if is_instance_valid(p):
			p.queue_free()
	props.clear()
	proj.clear()
	boss = null
	boss_locked = []
	interact_target = null
	if player:
		player.wind = 0.0
	var r: Dictionary = rooms[id]
	var removed: Dictionary = state["removed"].get(id, {})
	level.load_room(r, removed)
	refresh_level()
	var rp: Rect2 = level.rect_px()
	cam.limit_left = int(rp.position.x)
	cam.limit_top = int(rp.position.y)
	cam.limit_right = int(rp.end.x)
	cam.limit_bottom = int(rp.end.y)
	seal_tiles.clear()
	for ly in range(level.h):
		for lx in range(level.w):
			if level.cells[ly * level.w + lx] == C.T_SEAL:
				seal_tiles.append(Vector2i(level.ox + lx, level.oy + ly))
	if playing:
		state["room"] = id
		var visited: Dictionary = state["visited"]
		room_label = r["name"]
		room_label_t = 2.5 if not visited.has(id) else 1.6
		visited[id] = true
	var taken: Dictionary = state["taken"]
	var ents_list: Array = r["ents"]
	for i in range(ents_list.size()):
		var e: Dictionary = ents_list[i]
		var tt: String = e["t"]
		var pid := id + ":" + str(i)
		var pos := _ent_pos(r, e)
		match tt:
			"spawn":
				pass
			"coin":
				if not taken.has(pid):
					var c = _make_prop("coin", pos - Vector2(0, T / 2.0), e)
					c.pid = pid
			"heart":
				if not taken.has(pid):
					var h = _make_prop("heart", pos - Vector2(0, T / 2.0), e)
					h.pid = pid
			"chest":
				var ch = _make_prop("chest", pos - Vector2(0, 16), e)
				ch.pid = pid
				ch.opened = taken.has(pid)
			"altar", "merchant", "sign":
				_make_prop(tt, pos - Vector2(0, 16), e)
			_:
				if tt.begins_with("boss_") and state["bosses"].has(tt.substr(5)):
					continue
				var en = spawn_enemy(tt, pos - Vector2(0, T / 2.0))
				if en and en.grav > 0.0 and not (tt == "spider"):
					en.position.y = pos.y - en.half.y - 0.5


func _make_prop(kind: String, pos: Vector2, data: Dictionary):
	var p = Prop.new()
	p.game = self
	p.kind = kind
	p.data = data
	p.position = pos
	props_root.add_child(p)
	props.append(p)
	return p


func spawn_enemy(kind: String, pos: Vector2, hanging := true):
	if not ENEMY_SCRIPTS.has(kind):
		push_warning("unknown enemy " + kind)
		return null
	var e = ENEMY_SCRIPTS[kind].new()
	e.game = self
	e.kind = kind
	e.position = pos
	e.home = pos
	if kind == "spider":
		e.hanging = hanging
	e.setup()
	ents.add_child(e)
	enemies.append(e)
	return e


func refresh_level() -> void:
	view.refresh(level)
	anim.refresh(level)


func spawn_coins(pos: Vector2, n: int) -> void:
	var left := n
	while left > 0:
		var v := 5 if left >= 10 else 1
		left -= v
		var c = _make_prop("coin", pos, {})
		c.dynamic = true
		c.value = v
		c.vel = Vector2(randf_range(-160, 160), randf_range(-420, -220))


# ================================================================== interactions
func _interactions() -> void:
	interact_target = null
	var best := 1e9
	for p in props:
		if is_instance_valid(p) and p.near and p.interactable():
			var d: float = p.position.distance_to(player.position)
			if d < best:
				best = d
				interact_target = p
	if interact_target != null and inp.interact_pressed and not player.dead:
		interact(interact_target)


func interact(p) -> void:
	match p.kind:
		"chest":
			p.opened = true
			state["taken"][p.pid] = true
			spawn_coins(p.position + Vector2(0, -12), int(p.data.get("coins", 10)))
			fx.burst(p.position, Color(1, 0.85, 0.3), 20, 220.0, 0.6, 3.0, 300.0)
			sfx.play("chest")
		"altar":
			state["hp"] = state["max_hp"]
			state["flasks"] = state["flasks_max"]
			state["altar_room"] = level.id
			state["altar_pos"] = [p.position.x, p.position.y]
			save_game()
			banner("Алтарь стихий", "Здоровье и флаконы восстановлены. Игра сохранена.")
			fx.ring(p.position, Color(0.5, 0.85, 1.0), 60.0)
			fx.burst(p.position + Vector2(0, -20), Color(0.5, 0.85, 1.0), 24, 180.0, 0.8, 3.0, -100.0)
			sfx.play("save")
		"merchant":
			ui.open_shop(String(p.data.get("shop", "m1")))


func collect_coin(p) -> void:
	state["coins"] = int(state["coins"]) + int(p.value)
	if p.pid != "":
		state["taken"][p.pid] = true
	fx.burst(p.position, Color(1, 0.85, 0.3), 5, 90.0, 0.3, 2.0, 0.0)
	sfx.play("coin")
	props.erase(p)
	p.queue_free()


func collect_heart(p) -> void:
	state["max_hp"] = int(state["max_hp"]) + 1
	state["hp"] = state["max_hp"]
	state["taken"][p.pid] = true
	banner("Сердце стихий", "Здоровье +1")
	fx.burst(p.position, Color(1, 0.35, 0.45), 30, 240.0, 0.8, 4.0, 0.0)
	sfx.play("unlock")
	props.erase(p)
	p.queue_free()


func use_flask() -> void:
	if player.dead:
		return
	if int(state["flasks"]) <= 0:
		hint("Флаконы пусты — отдохни у алтаря")
		sfx.play("deny")
		return
	if int(state["hp"]) >= int(state["max_hp"]):
		hint("Здоровье и так полное")
		return
	state["flasks"] = int(state["flasks"]) - 1
	state["hp"] = mini(int(state["max_hp"]), int(state["hp"]) + 3)
	fx.burst(player.position, Color(0.45, 0.8, 1.0), 20, 150.0, 0.7, 3.0, -150.0)
	fx.ring(player.position, Color(0.45, 0.8, 1.0), 30.0)
	sfx.play("heal")


func buy(shop: String, item_id: String) -> void:
	var item: Dictionary = {}
	for it in shops.get(shop, []):
		if it["id"] == item_id:
			item = it
	if item.is_empty():
		return
	var price := int(item["price"])
	if state["bought"].has(item_id):
		return
	if int(state["coins"]) < price:
		hint("Не хватает монет")
		sfx.play("deny")
		return
	state["coins"] = int(state["coins"]) - price
	state["bought"][item_id] = true
	match String(item["kind"]):
		"heart":
			state["max_hp"] = int(state["max_hp"]) + 1
			state["hp"] = int(state["hp"]) + 1
		"flask":
			state["flasks_max"] = int(state["flasks_max"]) + 1
			state["flasks"] = int(state["flasks"]) + 1
		"dash":
			state["dash"] = true
		"power":
			state["power"] = int(state["power"]) + 1
		"armor":
			state["armor"] = int(state["armor"]) + 1
		"magnet":
			state["magnet"] = true
		"map":
			state["map"] = true
	sfx.play("buy")
	save_game()


func break_gate(tx: int, ty: int) -> void:
	var code: int = level.tget(tx, ty)
	var keys: Array = level.destroy_group(tx, ty)
	if keys.is_empty():
		return
	var rem: Dictionary = state["removed"].get(level.id, {})
	var col: Color = C.ELEM_COLORS.get(C.GATE_ELEM.get(code, "none"), Color(1, 1, 1))
	for k in keys:
		rem[k] = 1
		var pp: PackedStringArray = String(k).split(",")
		var c := Vector2((level.ox + int(pp[0]) + 0.5) * T, (level.oy + int(pp[1]) + 0.5) * T)
		fx.burst(c, col, 6, 160.0, 0.6, 4.0, 300.0)
	state["removed"][level.id] = rem
	refresh_level()
	shake(5.0)
	sfx.play("break")


func _check_seals() -> void:
	if seal_tiles.is_empty() or int(state["seals"]) < 3:
		return
	for v in seal_tiles:
		var tp: Vector2i = v
		var c := Vector2((tp.x + 0.5) * T, (tp.y + 0.5) * T)
		if c.distance_to(player.position) < 220.0:
			var keys: Array = level.destroy_group(tp.x, tp.y)
			var rem: Dictionary = state["removed"].get(level.id, {})
			for k in keys:
				rem[k] = 1
			state["removed"][level.id] = rem
			refresh_level()
			seal_tiles.clear()
			banner("Врата Ада открыты", "Три печати стражей сломали древний замок")
			fx.ring(c, Color(0.85, 0.4, 1.0), 120.0)
			fx.burst(c, Color(0.85, 0.4, 1.0), 40, 300.0, 1.0, 4.0, 0.0)
			shake(10.0)
			sfx.play("unlock")
			return


# ================================================================== combat events
func on_enemy_dead(e) -> void:
	enemies.erase(e)
	if e.is_boss:
		boss_defeated(e)


func boss_start(b) -> void:
	boss = b
	boss_locked = level.lock_doors()
	refresh_level()
	banner(b.boss_name, "Страж пробудился!")
	shake(8.0)
	sfx.play("roar")


func boss_defeated(b) -> void:
	level.unlock(boss_locked)
	boss_locked = []
	refresh_level()
	boss = null
	state["bosses"][b.boss_id] = true
	for e in enemies.duplicate():
		if is_instance_valid(e) and e.alive:
			e.die()
	proj.clear()
	if b.boss_id == "lord":
		victory_t = 2.5
		banner("Владыка Бездны повержен", "")
		return
	var el: String = BOSS_REWARD.get(b.boss_id, "")
	var els: Array = state["elements"]
	if el != "" and not els.has(el):
		els.append(el)
	state["seals"] = int(state["seals"]) + 1
	state["hp"] = state["max_hp"]
	spawn_coins(b.position, 40)
	fx.burst(b.position, C.ELEM_COLORS.get(el, Color(1, 1, 1)), 60, 400.0, 1.2, 5.0, 0.0)
	pending_reward = el
	reward_t = 1.4
	save_game()


func on_player_dead() -> void:
	dead_t = 1.6
	state["deaths"] = int(state["deaths"]) + 1


func shake(a: float) -> void:
	shake_amt = maxf(shake_amt, a)


func hitstop(t: float) -> void:
	hitstop_t = maxf(hitstop_t, t)


func flash(_t: float) -> void:
	fade = 0.7


func hint(text: String) -> void:
	if hint_text == text and hint_t > 1.0:
		return
	hint_text = text
	hint_t = 2.4


func banner(title: String, sub: String) -> void:
	banner_title = title
	banner_sub = sub
	banner_t = 3.2


func has_elem(e: String) -> bool:
	return state["elements"].has(e)


# ================================================================== game flow
func new_game() -> void:
	state = _default_state()
	playing = true
	_load_room(world["start"])
	var sp := _spawn_pos()
	state["altar_pos"] = [sp.x, sp.y]
	_place_player(sp)
	player.form = "fire"
	save_game()
	banner("Стихии Бездны", "Огонь и вода пробудились в тебе")


func continue_game() -> void:
	if not load_game():
		new_game()
		return
	playing = true
	_respawn_at_altar()


func respawn() -> void:
	_respawn_at_altar()


func _respawn_at_altar() -> void:
	state["hp"] = state["max_hp"]
	state["flasks"] = state["flasks_max"]
	var room: String = state["altar_room"]
	if not rooms.has(room):
		room = world["start"]
	_load_room(room)
	var ap: Array = state["altar_pos"]
	var pos := _spawn_pos() if ap.size() < 2 else Vector2(float(ap[0]), float(ap[1]) - 4.0)
	_place_player(pos)
	fade = 1.0
	dead_t = -1.0


func _place_player(pos: Vector2) -> void:
	player.position = pos
	player.vel = Vector2.ZERO
	player.dead = false
	player.visible = true
	player.invuln = 1.5
	player.safe_pos = pos
	player.wind = 0.0
	if not has_elem(player.form):
		player.form = "fire"
	cam.position = pos
	cam.reset_smoothing()
	hud.reset_touch()


func to_title() -> void:
	playing = false
	player.visible = false
	_load_room(world["start"])
	ui.open("title")


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(state))


func load_game() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var d = JSON.parse_string(f.get_as_text())
	if not (d is Dictionary):
		return false
	var base := _default_state()
	for k in d.keys():
		base[k] = d[k]
	state = base
	return true
