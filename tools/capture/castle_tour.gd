extends Node
## Screenshot tour of the castle for review: one room per area, every boss
## mid-fight, and the main menus. Run with a display (xvfb-run).
##   godot --path . res://tools/capture/castle_tour.tscn -- <out_dir>

var _out := "/tmp/tour"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(_out)
	GameState.new_game(2)
	for a: StringName in GameState.ABILITIES:
		GameState.unlock(a)
	GameState.charms_owned[&"rubber_nose"] = true
	GameState.charms_owned[&"lucky_bell"] = true
	GameState.bells = 420
	var game: Game = (load("res://scenes/game/game.tscn") as PackedScene).instantiate()
	game.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(game)
	await _wait(0.5)
	if Ui.is_busy():
		Ui.call(&"_close")
	await _wait(1.6)
	await _shot("00_start")
	var by_area: Dictionary = {}
	for id: String in WorldData.ROOMS:
		var d: Dictionary = WorldData.ROOMS[id]
		var area := String(d["area"])
		if String(d["kind"]) == "normal" and int(d["size"][0]) >= 2 and not by_area.has(area):
			by_area[area] = id
	var i := 1
	for area: String in by_area:
		game.call(&"_load_room", by_area[area])
		var r: Rect2 = game.room.rect
		game.player.global_position = _floor_spot(game, r.position + Vector2(r.size.x * 0.3, 200.0))
		game.camera.snap()
		await _wait(2.2)
		await _shot("%02d_%s" % [i, area])
		i += 1
	for id: String in WorldData.ROOMS:
		if String(WorldData.ROOMS[id]["kind"]) != "boss":
			continue
		game.call(&"_load_room", id)
		var r: Rect2 = game.room.rect
		game.player.global_position = _floor_spot(game, r.get_center() + Vector2(-380.0, 0.0))
		game.camera.snap()
		for k: int in 40:
			await _wait(0.1)
			if Ui.is_busy():
				Ui.call(&"_close")
		for k: int in 30:
			game.player.set(&"_invulnerable_timer", 5.0)
			game.player.health = game.player.max_health
			await _wait(0.1)
		var boss := game.room.boss as Boss
		await _shot("%02d_boss_%s" % [i, boss.boss_id if boss else &"none"])
		i += 1
	Ui.open_map(false)
	await _wait(0.4)
	await _shot("%02d_map" % i)
	Ui.call(&"_close")
	await _wait(0.3)
	Ui.shop("carnival_gate")
	await _wait(0.4)
	await _shot("%02d_shop" % (i + 1))
	Ui.call(&"_close")
	await _wait(0.3)
	Ui.ability_get(&"vault")
	await _wait(0.5)
	await _shot("%02d_ability" % (i + 2))
	GameState.erase_slot(2)
	get_tree().quit()


func _floor_spot(game: Game, near: Vector2) -> Vector2:
	var space := game.get_world_2d().direct_space_state
	for dx: float in [0.0, 200.0, -200.0, 400.0, -400.0, 600.0]:
		var from := near + Vector2(dx, -300.0)
		var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(0.0, 1400.0), 1 | 256)
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			return hit["position"] + Vector2(0.0, -2.0)
	return near


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.resize(960, 540, Image.INTERPOLATE_BILINEAR)
	img.save_png("%s/%s.png" % [_out, name])
	print("shot ", name)
