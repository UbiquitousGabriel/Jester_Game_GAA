extends Node
## Scripted showcase for capturing footage of the Jester's animations.
## Not a test. Record with:
##   godot --path . --write-movie out.avi --fixed-fps 60 res://tools/capture/showcase.tscn

const PLAYGROUND: PackedScene = preload("res://scenes/levels/movement_playground.tscn")
const FOOT_GUARD: PackedScene = preload("res://scenes/enemies/foot_guard.tscn")

var _level: Node2D
var _player: Player


func _ready() -> void:
	_level = PLAYGROUND.instantiate() as Node2D
	add_child(_level)
	_player = _level.get_node(^"Player") as Player
	await _run()
	get_tree().quit()


func _run() -> void:
	for node: Node in get_tree().get_nodes_in_group(&"enemy"):
		node.queue_free()
	await _wait(1.2)  # idle

	await _hold(&"move_right", 0.9)  # run
	await _wait(0.4)

	await _tap(&"jump", 0.3)  # jump: rise, apex, fall, land
	await _wait(0.9)

	_spawn_guard(_player.global_position + Vector2(80.0, 0.0))
	_spawn_guard(_player.global_position + Vector2(300.0, 0.0))
	await _wait(0.2)
	await _tap(&"attack_light", 0.05)  # side swing into a chain
	await _wait(0.9)

	Input.action_press(&"move_up")
	await _tap(&"attack_light", 0.05)  # upswing
	Input.action_release(&"move_up")
	await _wait(0.7)

	_spawn_guard(_player.global_position + Vector2(90.0, 0.0))
	await _wait(0.2)
	await _tap(&"attack_heavy", 0.75)  # charged heavy
	await _wait(1.0)

	await _tap(&"dash", 0.05)  # dash with afterimages
	await _wait(0.8)

	# Pogo off a guard twice.
	var stool := _spawn_guard(_player.global_position + Vector2(0.0, 0.0))
	stool.max_health = 99
	stool.health = 99
	await _tap(&"jump", 0.35)
	await _wait(0.25)
	for i: int in 2:
		Input.action_press(&"move_down")
		await _tap(&"attack_light", 0.05)
		await _wait(0.55)
		Input.action_release(&"move_down")
	await _wait(0.8)

	# Vault.
	Input.action_press(&"move_down")
	await _tap(&"attack_heavy", 0.05)
	Input.action_release(&"move_down")
	await _wait(1.4)

	# Walk into the spike pit.
	_player.global_position = Vector2(1400.0, -4.0)
	_player.velocity = Vector2.ZERO
	await _wait(0.3)
	await _hold(&"move_right", 0.5)
	await _wait(1.8)


func _spawn_guard(at: Vector2) -> Enemy:
	var guard := FOOT_GUARD.instantiate() as Enemy
	guard.patrol_enabled = false
	_level.add_child(guard)
	guard.global_position = at
	return guard


func _tap(action: StringName, hold: float) -> void:
	Input.action_press(action)
	await _wait(hold)
	Input.action_release(action)


func _hold(action: StringName, seconds: float) -> void:
	Input.action_press(action)
	await _wait(seconds)
	Input.action_release(action)


func _wait(seconds: float) -> void:
	var frames := maxi(int(round(seconds * 60.0)), 1)
	for i: int in frames:
		await get_tree().physics_frame
