extends Node
## Records a Ringmaster fight driven by a scripted "bot" that shows off the
## aerial kit: jumps, air strings with hang time, pogos, the twirl glide,
## vaults, dashes and wall bounces.
##   xvfb-run godot --path . --write-movie /tmp/clip.avi --fixed-fps 60 res://tools/capture/boss_clip.tscn

const BOSS_HEALTH := 22
const MAX_SECONDS := 80.0

var game: Game
var player: Player
var boss: Boss
var _time: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.new_game(2)
	GameState.flags["intro_seen"] = true
	for a: StringName in GameState.ABILITIES:
		GameState.unlock(a)
	game = (load("res://scenes/game/game.tscn") as PackedScene).instantiate()
	game.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(game)
	player = game.player
	await _f(5)
	var room_id := ""
	for id: String in WorldData.ROOMS:
		if String(WorldData.ROOMS[id]["kind"]) == "boss" and String(WorldData.ROOMS[id]["area"]) == "carnival_gate":
			room_id = id
	game.call(&"_load_room", room_id)
	var r: Rect2 = game.room.rect
	player.global_position = Vector2(r.position.x + 300.0, r.end.y - 3.0 * 64.0 - 2.0)
	game.camera.snap()
	boss = game.room.boss as Boss
	boss.max_health = BOSS_HEALTH
	boss.health = BOSS_HEALTH
	Ui.fade_in(0.3)
	# Walk in: the arena locks and the Ringmaster speaks.
	await _hold_for(&"move_right", 1.6)
	await _f(60)
	await _wait_real(1.8)
	Ui.call(&"_close")
	await _wait_real(0.5)
	if Ui.is_busy():
		Ui.call(&"_close")
	await _f(30)
	await _fight()
	GameState.erase_slot(2)
	get_tree().quit()


func _physics_process(delta: float) -> void:
	_time += delta
	if player != null and _time > 1.0 and int(_time * 60.0) % 90 == 0:
		player.heal(1)


func _fight() -> void:
	var moves: Array[Callable] = [_air_string, _glide_over, _pogo_chain, _vault_combo, _wall_bounce, _dash_dodge]
	var i := 0
	while _time < MAX_SECONDS and is_instance_valid(boss) and boss.health > 0:
		if Ui.is_busy():
			Ui.call(&"_close")
		await _approach(190.0)
		await moves[i % moves.size()].call()
		i += 1
		await _f(6)
	# Let the defeat play out.
	for k: int in 300:
		if Ui.is_busy():
			Ui.call(&"_close")
		await _f(1)


# --- Maneuvers ---------------------------------------------------------------------------


func _air_string() -> void:
	_face_boss()
	await _press(&"jump", 10)
	await _f(8)
	_steer_to_boss()
	for k: int in 3:
		await _press(&"attack_light", 3)
		await _f(14)
	_release_moves()
	await _land()


func _glide_over() -> void:
	var side := _boss_side()
	Input.action_press(&"move_right" if side > 0 else &"move_left")
	await _press(&"jump", 14)
	await _f(10)
	Input.action_press(&"jump")
	for k: int in 50:
		await _f(1)
		if k == 20:
			await _press(&"attack_light", 3)
	Input.action_release(&"jump")
	_release_moves()
	await _land()
	_face_boss()
	await _press(&"attack_light", 3)
	await _f(12)
	await _press(&"attack_light", 3)
	await _f(16)


func _pogo_chain() -> void:
	# Jump above the boss and bounce off its head with down-strikes.
	_steer_to_boss()
	await _press(&"jump", 16)
	await _f(6)
	Input.action_press(&"move_up")
	await _press(&"dash", 3)
	Input.action_release(&"move_up")
	for k: int in 3:
		_steer_to_boss(0.0)
		await _f(8)
		Input.action_press(&"move_down")
		await _press(&"attack_light", 3)
		Input.action_release(&"move_down")
		await _f(16)
	_release_moves()
	await _land()


func _vault_combo() -> void:
	_face_boss()
	await _approach(170.0)
	Input.action_press(&"move_down")
	await _press(&"attack_heavy", 4)
	Input.action_release(&"move_down")
	await _f(20)
	_steer_to_boss()
	for k: int in 3:
		await _press(&"attack_light", 3)
		await _f(13)
	Input.action_press(&"move_down")
	await _press(&"attack_light", 3)
	Input.action_release(&"move_down")
	_release_moves()
	await _land()


func _wall_bounce() -> void:
	# Run to the nearer wall, kick off it twice, then dive back in.
	var r: Rect2 = game.room.rect
	var to_left := player.global_position.x - r.position.x < r.end.x - player.global_position.x
	var action := &"move_left" if to_left else &"move_right"
	var away := &"move_right" if to_left else &"move_left"
	Input.action_press(action)
	for k: int in 120:
		await _f(1)
		if absf(player.global_position.x - (r.position.x if to_left else r.end.x)) < 230.0:
			break
	await _press(&"jump", 12)
	for k: int in 30:
		await _f(1)
		if player.is_on_wall():
			break
	await _press(&"jump", 6)
	await _f(14)
	Input.action_release(away)
	Input.action_press(action)
	await _f(10)
	await _press(&"jump", 6)
	Input.action_release(action)
	Input.action_press(away)
	await _f(18)
	await _press(&"dash", 3)
	await _f(8)
	await _press(&"attack_light", 3)
	await _f(14)
	await _press(&"attack_light", 3)
	_release_moves()
	await _land()


func _dash_dodge() -> void:
	# Wait for a windup, dash through it, punish from the air.
	for k: int in 40:
		await _f(1)
		if boss._attack != &"" and boss._t < 0.3:
			break
	_face_boss()
	await _press(&"jump", 8)
	await _press(&"dash", 3)
	await _f(14)
	_face_boss()
	_steer_to_boss()
	await _press(&"attack_light", 3)
	await _f(14)
	await _press(&"attack_light", 3)
	await _f(14)
	await _press(&"attack_light", 3)
	_release_moves()
	await _land()


# --- Helpers ------------------------------------------------------------------------------


func _alive() -> bool:
	return is_instance_valid(boss) and boss.health > 0


func _boss_side() -> float:
	if not is_instance_valid(boss):
		return 1.0
	return signf(boss.global_position.x - player.global_position.x)


func _face_boss() -> void:
	_release_moves()
	var a := &"move_right" if _boss_side() > 0.0 else &"move_left"
	Input.action_press(a)
	await_frame_release(a)


func await_frame_release(a: StringName) -> void:
	get_tree().create_timer(0.05, true, true, false).timeout.connect(func() -> void: Input.action_release(a))


func _steer_to_boss(margin: float = 60.0) -> void:
	_release_moves()
	if not is_instance_valid(boss):
		return
	var dx := boss.global_position.x - player.global_position.x
	if absf(dx) > margin:
		Input.action_press(&"move_right" if dx > 0.0 else &"move_left")


func _release_moves() -> void:
	for a: StringName in [&"move_left", &"move_right", &"move_up", &"move_down"]:
		Input.action_release(a)


func _approach(distance: float) -> void:
	for k: int in 120:
		if not _alive():
			return
		var dx := boss.global_position.x - player.global_position.x
		if absf(dx) < distance:
			break
		_release_moves()
		Input.action_press(&"move_right" if dx > 0.0 else &"move_left")
		await _f(1)
	_release_moves()


func _land() -> void:
	for k: int in 90:
		await _f(1)
		if player.is_on_floor():
			break


func _press(action: StringName, frames: int) -> void:
	Input.action_press(action)
	await _f(frames)
	Input.action_release(action)


func _hold_for(action: StringName, seconds: float) -> void:
	Input.action_press(action)
	await _f(int(seconds * 60.0))
	Input.action_release(action)


func _f(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame


func _wait_real(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout
