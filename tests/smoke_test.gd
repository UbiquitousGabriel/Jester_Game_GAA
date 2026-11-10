extends Node
## Scripted smoke test. Run headless through tools/validate.sh, or directly:
##   godot --headless --path . res://tests/smoke_test.tscn
## Exit code 0 = all checks passed, 1 = at least one failed.
##
## Drives the real playground with simulated input. It verifies mechanics work,
## not that they feel good; feel needs a human playtest.

const PLAYGROUND: PackedScene = preload("res://scenes/levels/movement_playground.tscn")
const FOOT_GUARD: PackedScene = preload("res://scenes/enemies/foot_guard.tscn")

var _passed: int = 0
var _failures: Array[String] = []


func _ready() -> void:
	GameFeel.hitstop_enabled = false
	await _run()
	print("")
	print("Smoke test: %d passed, %d failed" % [_passed, _failures.size()])
	for failure: String in _failures:
		print("  FAILED: ", failure)
	get_tree().quit(1 if not _failures.is_empty() else 0)


func _run() -> void:
	var level := PLAYGROUND.instantiate() as Node2D
	add_child(level)
	var player := level.get_node(^"Player") as Player
	_check(player != null, "playground contains a Player")
	if player == null:
		return

	# Clear the level's own patrolling guards so they cannot wander into a test.
	for node: Node in get_tree().get_nodes_in_group(&"enemy"):
		node.queue_free()

	# --- Landing ---
	await _frames(60)
	_check(player.is_on_floor(), "player settles on the start ground")

	# --- Running ---
	var start_x := player.global_position.x
	Input.action_press(&"move_right")
	await _frames(45)
	_check(player.global_position.x > start_x + 150.0, "holding right moves the player right")
	_check(
		absf(player.velocity.x - player.config.max_run_speed) < 5.0,
		"run reaches max_run_speed (got %.1f)" % player.velocity.x
	)
	Input.action_release(&"move_right")
	await _frames(30)
	_check(absf(player.velocity.x) < 1.0, "releasing input decelerates to a stop")

	# --- Full jump ---
	var ground_y := player.global_position.y
	Input.action_press(&"jump")
	var full_apex: float = await _track_apex(player, 70)
	Input.action_release(&"jump")
	var full_height := ground_y - full_apex
	_check(
		absf(full_height - player.config.jump_height) < 25.0,
		"held jump reaches about jump_height (got %.1f)" % full_height
	)
	_check(player.is_on_floor(), "player lands after a full jump")

	# --- Short hop (variable jump height) ---
	Input.action_press(&"jump")
	await _frames(3)
	Input.action_release(&"jump")
	var short_apex: float = await _track_apex(player, 70)
	var short_height := ground_y - short_apex
	_check(
		short_height > 10.0 and short_height < full_height * 0.75,
		"tapped jump is lower than a held jump (got %.1f)" % short_height
	)

	# --- Dash ---
	var dash_start_x := player.global_position.x
	Input.action_press(&"dash")
	await _frames(2)
	Input.action_release(&"dash")
	_check(player.is_dashing(), "dash starts on input")
	await _frames(30)
	_check(player.global_position.x > dash_start_x + 120.0, "dash covers ground")

	# --- Hammer hit launches an enemy ---
	await _frames(30)
	var target := _spawn_guard(level, player.global_position + Vector2(70.0, 0.0))
	await _frames(2)
	Input.action_press(&"attack_light")
	await _frames(2)
	Input.action_release(&"attack_light")
	await _frames(12)
	_check(target.health == target.max_health - 1, "light attack damages the guard")
	_check(target.state == Enemy.State.LAUNCHED, "light attack launches the guard")
	_check(ComboTracker.chain >= 1, "hammer hit registers on the combo tracker")
	target.queue_free()

	# --- Enemy-to-enemy chain collision ---
	var base := player.global_position + Vector2(-500.0, 0.0)
	var projectile := _spawn_guard(level, base)
	var victim := _spawn_guard(level, base + Vector2(220.0, 0.0))
	var victim_hits: Array[int] = [0]
	victim.hit_taken.connect(func(_hit: HitData) -> void: victim_hits[0] += 1)
	await _frames(5)
	var hit := HitData.new()
	hit.launch_velocity = Vector2(1200.0, -350.0)
	projectile.take_hit(hit)
	_check(projectile.state == Enemy.State.LAUNCHED, "take_hit puts an enemy in LAUNCHED")
	await _frames(120)
	_check(
		victim_hits[0] == 1,
		"launched enemy hits the second enemy exactly once (got %d)" % victim_hits[0]
	)
	_check(victim.health == victim.max_health - 1, "collision damages the second enemy once")


func _spawn_guard(level: Node, at: Vector2) -> Enemy:
	var guard := FOOT_GUARD.instantiate() as Enemy
	guard.patrol_enabled = false
	level.add_child(guard)
	guard.global_position = at
	return guard


## Returns the highest point (lowest y) reached over `frame_count` frames.
func _track_apex(body: Node2D, frame_count: int) -> float:
	var apex := body.global_position.y
	for i: int in frame_count:
		await get_tree().physics_frame
		apex = minf(apex, body.global_position.y)
	return apex


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


func _check(condition: bool, description: String) -> void:
	if condition:
		_passed += 1
		print("  ok    ", description)
	else:
		_failures.append(description)
		print("  FAIL  ", description)
