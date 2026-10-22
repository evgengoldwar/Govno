extends SceneTree
## Input-driven test: walk, jump, burn the wooden barricade, enter the next room.
## Run:  godot --headless --fixed-fps 60 -s res://tests/play_test.gd

var main = null
var fails := 0


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in range(n):
		await physics_frame


func check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		fails += 1


func _run() -> void:
	await _frames(5)
	main.ui.close()
	main.new_game()
	await _frames(60)
	var p = main.player
	check(p.on_floor, "player stands on the floor at spawn")
	var x0: float = p.position.x
	Input.action_press("right")
	await _frames(40)
	Input.action_release("right")
	check(p.position.x > x0 + 100.0, "walks right (%.0f -> %.0f)" % [x0, p.position.x])
	var y0: float = p.position.y
	Input.action_press("jump")
	await _frames(12)
	check(p.position.y < y0 - 60.0, "jumps up (%.0f -> %.0f)" % [y0, p.position.y])
	Input.action_release("jump")
	await _frames(60)
	check(p.on_floor, "lands again")
	# burn barricade on the left wall
	Input.action_press("left")
	await _frames(80)
	Input.action_release("left")
	var gate_before: int = main.level.tget(main.level.ox, main.level.oy + 16)
	Input.action_press("attack")
	await _frames(40)
	Input.action_release("attack")
	var gate_after: int = main.level.tget(main.level.ox, main.level.oy + 16)
	check(gate_before == 66 and gate_after == 46, "fire burns the wooden barricade (%d -> %d)" % [gate_before, gate_after])
	# walk into C0 and back
	Input.action_press("left")
	await _frames(60)
	Input.action_release("left")
	check(main.level.id == "C0", "entered C0 through the burnt door (now " + main.level.id + ")")
	# teleport near right edge of C1 and walk to C2
	main._load_room("C1")
	var r: Rect2 = main.level.rect_px()
	p.position = Vector2(r.end.x - 80, r.end.y - 3 * 32)
	await _frames(20)
	Input.action_press("right")
	await _frames(60)
	Input.action_release("right")
	check(main.level.id == "C2", "walked into C2 (now " + main.level.id + ")")
	# water form: switch and douse the flame wall at the right of C2
	Input.action_press("f2")
	await _frames(2)
	Input.action_release("f2")
	check(p.form == "water", "switched to water")
	r = main.level.rect_px()
	p.position = Vector2(r.end.x - 200, r.end.y - 3 * 32)
	p.facing = 1
	p.invuln = 99.0
	await _frames(20)
	Input.action_press("attack")
	await _frames(60)
	Input.action_release("attack")
	var fl: int = main.level.tget(main.level.ox + 39, main.level.oy + 16)
	check(fl == 46, "water douses the flame wall (tile %d)" % fl)
	# drop into the flooded cellar through the platform hole, then swim up
	p.position = Vector2((main.level.ox + 5.5) * 32, (main.level.oy + 17) * 32)
	await _frames(20)
	Input.action_press("down")
	await _frames(10)
	await _frames(50)
	Input.action_release("down")
	check(main.level.id == "C6", "dropped down to C6 (now " + main.level.id + ")")
	await _frames(120)
	var depth: float = p.position.y
	for i in range(14):
		Input.action_press("jump")
		await _frames(8)
		Input.action_release("jump")
		await _frames(6)
	check(p.position.y < depth - 100.0 or main.level.id == "C2", "swims upward in water form")
	# boss arena must not lock while the hero stands in a doorway
	p.form = "fire"
	p.invuln = 999.0
	main._load_room("B1")
	var ox: int = main.level.ox
	var oy: int = main.level.oy
	p.position = Vector2((ox + 31.5) * 32, (oy + 19) * 32 - 14)  # in the floor opening from below
	await _frames(10)
	check(main.boss == null, "boss waits while hero is in the floor opening")
	p.position = Vector2((ox + 0.6) * 32, (oy + 18) * 32 - 14)  # in the side doorway
	await _frames(10)
	check(main.boss == null, "boss waits while hero is in the side doorway")
	Input.action_press("right")
	await _frames(190)
	Input.action_release("right")
	check(main.boss != null, "boss fight starts once the hero is inside")
	var free: bool = not main.level.solid_px(p.position) and not main.level.solid_px(p.position + Vector2(0, 12))
	check(free, "hero is not stuck in a wall after the doors lock")
	Input.action_press("right")
	await _frames(30)
	Input.action_release("right")
	check(main.level.id == "B1", "hero can move inside the locked arena")
	print("FAILS: ", fails)
	quit()
