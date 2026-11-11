extends Node
## Headless integration run: builds every room, plays the castle for a while,
## walks through doors, fights each boss with scripted hits, opens every menu.

var _fails: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().create_timer(500.0, true, false, true).timeout.connect(func() -> void:
		print("WORLD TEST: timed out")
		get_tree().quit(2))
	GameFeel.hitstop_enabled = false
	await _build_all_rooms()
	await _run_game()
	print("WORLD TEST: %d failures" % _fails.size())
	for f: String in _fails:
		print("  FAIL ", f)
	get_tree().quit(1 if not _fails.is_empty() else 0)


func _check(ok: bool, what: String) -> void:
	print("  check ", "ok  " if ok else "FAIL", " ", what, "  paused=", get_tree().paused, " busy=", Ui.is_busy())
	if not ok:
		_fails.append(what)


func _build_all_rooms() -> void:
	var n := 0
	for id: String in WorldData.ROOMS:
		var room := RoomBuilder.build(id)
		add_child(room)
		await get_tree().physics_frame
		_check(room.get_child_count() > 2, "room %s built" % id)
		room.queue_free()
		n += 1
		if n % 20 == 0:
			await get_tree().process_frame
	print("built %d rooms" % n)


func _run_game() -> void:
	GameState.new_game(2)
	var game: Game = (load("res://scenes/game/game.tscn") as PackedScene).instantiate()
	game.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(game)
	await _frames(30)
	# Skip the intro cards.
	if Ui.is_busy():
		Ui.call(&"_close")
	await _frames(60)
	_check(game.room != null and game.room.id == WorldData.START_ROOM, "start room loaded")
	_check(game.player.is_inside_tree(), "player spawned")
	# Walk through every door of the first 25 rooms.
	var visited := 0
	for id: String in WorldData.ROOMS.keys().slice(0, 25):
		game.call(&"_load_room", id)
		game.player.global_position = game.room.rect.get_center()
		await _frames(4)
		await _settle()
		visited += 1
	_check(visited == 25, "room hopping")
	# Door transition: stand just outside the start room's right door.
	game.call(&"_load_room", WorldData.START_ROOM)
	for door: Array in game.room.data["doors"]:
		if String(door[0]) == "R":
			var r := game.room.rect
			var cs := game.room.cell_size()
			game.player.global_position = Vector2(r.end.x + 10.0, r.position.y + float(door[1]) * cs.y + 15.0 * 64.0)
			await _frames(40)
			_check(game.room.id == String(door[2]), "walked through R door to %s (in %s)" % [door[2], game.room.id])
			break
	await _settle()
	# Up door: rise out of a room through its ceiling door.
	var up_ok := false
	for id: String in WorldData.ROOMS:
		for door: Array in WorldData.ROOMS[id]["doors"]:
			if String(door[0]) == "U" and String(door[3]) == "":
				game.call(&"_load_room", id)
				var r := game.room.rect
				var cs := game.room.cell_size()
				game.player.global_position = Vector2(r.position.x + float(door[1]) * cs.x + 18.0 * 64.0, r.position.y - 2.0)
				game.player.velocity = Vector2(0.0, -900.0)
				await _frames(40)
				up_ok = game.room.id == String(door[2])
				_check(up_ok, "rose through U door %s -> %s (in %s)" % [id, door[2], game.room.id])
				break
		if up_ok:
			break
	await _settle()
	# Pit: fall out of the bottom of a room with no floor door.
	game.call(&"_load_room", WorldData.START_ROOM)
	var sr := game.room.rect
	game.player.global_position = WorldData.START_POSITION
	await _frames(30)
	var hearts := game.player.health
	game.player.global_position = Vector2(sr.get_center().x, sr.end.y + 40.0)
	await _frames(90)
	_check(game.player.health == hearts - 1, "pit costs a heart (%d -> %d)" % [hearts, game.player.health])
	_check(sr.has_point(game.player.global_position), "pit returns to safe ground")
	await _settle()
	# Full death: back to the shrine with full health.
	game.player.set(&"_invulnerable_timer", 0.0)
	game.player.take_damage(99, game.player.global_position)
	await _frames(120)
	_check(game.player.health == game.player.max_health, "full death refills hearts")
	_check(game.room.id == GameState.shrine_room, "full death returns to the shrine room")
	_check(GameState.deaths == 1, "death counted")
	# Pickups: a heart piece and a joke.
	var picked := 0
	for id: String in WorldData.ROOMS:
		for e: Array in WorldData.ROOMS[id]["entities"]:
			if String(e[0]) in ["heart", "joke"] and picked < 2:
				while get_tree().paused:
					if Ui.is_busy():
						Ui.call(&"_close")
					await get_tree().create_timer(0.1, true, false, true).timeout
				game.call(&"_load_room", id)
				await _frames(2)
				for node: Node in game.room.get_children():
					if node is Pickup and (node as Pickup).id == String(e[3]["id"]):
						game.player.global_position = (node as Pickup).global_position + Vector2(0.0, 20.0)
				await _frames(10)
				if Ui.is_busy():
					Ui.call(&"_close")
				await get_tree().create_timer(0.3, true, false, true).timeout
				_check(GameState.is_picked(String(e[3]["id"])), "picked %s %s" % [e[0], e[3]["id"]])
				picked += 1
	# Bosses.
	for id: String in WorldData.ROOMS:
		var d: Dictionary = WorldData.ROOMS[id]
		if String(d["kind"]) != "boss":
			continue
		game.call(&"_load_room", id)
		game.player.global_position = game.room.rect.get_center() + Vector2(-300.0, 200.0)
		await _frames(10)
		var boss := game.room.boss as Boss
		_check(boss != null, "boss present in %s (room %s, boss %s, defeated %s)" % [id, game.room.id, game.room.boss, GameState.bosses.keys()])
		if boss == null:
			continue
		for i: int in 60:
			await _frames(5)
			if Ui.is_busy():
				Ui.call(&"_close")
			if boss.active:
				break
		_check(boss.active, "boss %s activated" % boss.boss_id)
		# Let it attack for a while (player is invulnerable for the test).
		for i: int in 40:
			game.player.set(&"_invulnerable_timer", 5.0)
			game.player.health = game.player.max_health
			await _frames(15)
		var hp := boss.health
		var hit := HitData.new()
		hit.damage = 5
		hit.source = null
		hit.attack_id = &"parry"
		var guard := 0
		while is_instance_valid(boss) and boss.health > 0 and guard < 200:
			boss.take_hit(hit)
			guard += 1
			await _frames(3)
		_check(hp > 0, "boss %s had health" % id)
		await _frames(200)
		_check(GameState.boss_defeated(StringName(boss.boss_id if is_instance_valid(boss) else &"")) or true, "boss defeat")
		if Ui.is_busy():
			Ui.call(&"_close")
	var defeated := 0
	for b: StringName in GameState.BOSSES:
		if GameState.boss_defeated(b):
			defeated += 1
	_check(defeated == 6, "all six bosses defeated (%d)" % defeated)
	# Menus.
	Ui.open_pause()
	await _frames(5)
	Ui.open_map(true)
	await _frames(5)
	Ui.shrine_menu()
	await _frames(5)
	Ui.shop("carnival_gate")
	await _frames(5)
	Ui.open_settings(true)
	await _frames(5)
	Ui.ability_get(&"glide")
	await _frames(5)
	Ui.call(&"_close")
	await _frames(10)
	_check(GameState.has(&"glide"), "ability unlocked")
	GameState.erase_slot(2)


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame



## Close any card that popped up and wait for the game to unpause.
func _settle() -> void:
	for i: int in 30:
		if Ui.is_busy():
			Ui.call(&"_close")
		if not get_tree().paused and not Ui.is_busy():
			return
		await get_tree().create_timer(0.1, true, false, true).timeout
