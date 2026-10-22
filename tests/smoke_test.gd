extends SceneTree
## Smoke test: loads every room, simulates frames, fights every boss.
## Run:  godot --headless -s res://tests/smoke_test.gd
## With screenshots (needs a display):  xvfb-run godot --rendering-driver opengl3 -s res://tests/smoke_test.gd -- --shots=DIR

var main = null
var shots := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots = a.substr(8)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in range(n):
		await physics_frame


func _shot(name: String) -> void:
	if shots == "":
		return
	await process_frame
	await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(shots + "/" + name + ".png")


func _run() -> void:
	await _frames(10)
	await _shot("00_title")
	main.ui.close()
	main.new_game()
	await _frames(60)
	await _shot("01_start")
	# give everything
	main.state["elements"] = ["fire", "water", "poison", "air", "earth"]
	main.state["seals"] = 3
	main.state["dash"] = true
	main.state["max_hp"] = 99
	main.state["hp"] = 99
	var ids: Array = main.rooms.keys()
	ids.sort()
	for rid in ids:
		main._load_room(rid)
		var r: Rect2 = main.level.rect_px()
		main.player.position = r.get_center()
		main.player.invuln = 999.0
		main.cam.position = main.player.position
		main.cam.reset_smoothing()
		await _frames(90)
		print("room ", rid, " ok, enemies=", main.enemies.size(), " props=", main.props.size())
		if rid in ["C1", "C6", "K2", "K4", "H2", "H3", "B3"]:
			await _shot("room_" + rid)
	# boss fights: let them run, then kill
	for bid in ["B1", "B2", "B3", "BOSS"]:
		main._load_room(bid)
		var rr: Rect2 = main.level.rect_px()
		main.player.position = Vector2(rr.get_center().x - 100, rr.end.y - 3 * 32)
		main.player.invuln = 999.0
		main.cam.reset_smoothing()
		for k in range(8):
			main.player.form = ["fire", "water", "poison", "air", "earth"][k % 5]
			Input.action_press("attack")
			await _frames(60)
		if main.boss != null:
			print("boss ", main.boss.boss_name, " hp=", main.boss.hp, " phase-check")
			if bid == "BOSS":
				main.boss.hp = main.boss.max_hp * 0.5
				await _frames(120)
				await _shot("boss_lord_p2")
				main.boss.hp = main.boss.max_hp * 0.2
				await _frames(200)
				await _shot("boss_lord_p3")
			else:
				await _shot("boss_" + bid)
			var b = main.boss
			for el in ["fire", "water", "poison", "air", "earth"]:
				if is_instance_valid(b) and b.alive and b.hp > 0.0:
					b.hit(99999.0, el, Vector2.ZERO)
			await _frames(260)
		else:
			print("boss not started in ", bid)
		Input.action_release("attack")
		print("after ", bid, ": elements=", main.state["elements"], " seals=", main.state["seals"], " ui=", main.ui.mode)
		if main.ui.mode != "":
			await _shot("ui_" + main.ui.mode + "_" + bid)
			main.ui.close()
	# menus
	main.ui.open("pause")
	await _frames(5)
	await _shot("pause_map")
	main.ui.close()
	main._load_room("M1")
	main.ui.open_shop("m1")
	await _frames(5)
	await _shot("shop")
	main.ui.close()
	# death
	main.player.invuln = 0.0
	main.state["hp"] = 1
	main.player.hurt(5, main.player.position)
	await _frames(150)
	print("after death ui=", main.ui.mode)
	main.respawn()
	main.ui.close()
	await _frames(30)
	print("respawned in ", main.level.id)
	print("SMOKE TEST DONE")
	quit()
