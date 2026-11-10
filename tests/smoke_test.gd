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
	var visual_sprite := player.get_node_or_null(^"Visual/Sprite") as AnimatedSprite2D
	_check(
		visual_sprite != null and visual_sprite.animation == &"idle" and visual_sprite.is_playing(),
		"standing still plays the painted idle animation"
	)
	for anim: StringName in [&"idle", &"run", &"jump_rise", &"attack_side", &"slam", &"pogo_bounce", &"defeat"]:
		_check(
			visual_sprite != null and visual_sprite.sprite_frames.get_frame_count(anim) > 0,
			"sprite frames include '%s'" % anim
		)

	# --- Running ---
	var start_x := player.global_position.x
	Input.action_press(&"move_right")
	await _frames(45)
	_check(player.global_position.x > start_x + 150.0, "holding right moves the player right")
	_check(visual_sprite.animation == &"run", "running plays the run animation")
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
	# Re-measure: the full jump can land on a one-way platform above the start.
	await _frames(10)
	ground_y = player.global_position.y
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
	var guard_sprite := target.get_node_or_null(^"Visual/Sprite") as AnimatedSprite2D
	_check(
		guard_sprite != null and guard_sprite.animation == &"airborne",
		"launched guard shows an airborne pose (got %s)" % (guard_sprite.animation if guard_sprite else "none")
	)
	_check(ComboTracker.chain >= 1, "hammer hit registers on the combo tracker")
	target.queue_free()

	# --- Enemy-to-enemy chain collision ---
	var base := player.global_position + Vector2(-500.0, 0.0)
	var projectile := _spawn_guard(level, base)
	await _frames(3)
	var idle_sprite := projectile.get_node_or_null(^"Visual/Sprite") as AnimatedSprite2D
	_check(
		idle_sprite != null and idle_sprite.animation == &"idle" and idle_sprite.is_playing(),
		"a standing guard plays the idle animation"
	)
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
	projectile.queue_free()
	victim.queue_free()
	await _frames(5)

	# --- Hammer vault ---
	var counts: Dictionary[String, int] = {"pogo": 0, "vault": 0, "respawn": 0}
	player.pogoed.connect(func() -> void: counts["pogo"] += 1)
	player.vaulted.connect(func(_perfect: bool) -> void: counts["vault"] += 1)
	player.respawned.connect(func() -> void: counts["respawn"] += 1)
	player.global_position = Vector2(200.0, -4.0)
	player.velocity = Vector2.ZERO
	await _frames(40)
	ground_y = player.global_position.y
	Input.action_press(&"move_down")
	Input.action_press(&"attack_heavy")
	var vault_apex: float = await _track_apex(player, 4)
	Input.action_release(&"attack_heavy")
	Input.action_release(&"move_down")
	vault_apex = minf(vault_apex, await _track_apex(player, 80))
	_check(counts["vault"] == 1, "down + heavy on the ground vaults once")
	_check(
		ground_y - vault_apex > player.config.jump_height + 20.0,
		"vault goes higher than a jump (got %.1f)" % (ground_y - vault_apex)
	)

	# --- Pogo off an enemy ---
	await _frames(30)
	var stool := _spawn_guard(level, Vector2(300.0, 0.0))
	await _frames(5)
	player.global_position = Vector2(300.0, -190.0)
	player.velocity = Vector2.ZERO
	Input.action_press(&"move_down")
	Input.action_press(&"attack_light")
	await _frames(3)
	Input.action_release(&"attack_light")
	await _frames(25)
	Input.action_release(&"move_down")
	_check(counts["pogo"] == 1, "down + light in the air pogos off an enemy (got %d)" % counts["pogo"])
	_check(stool.health == stool.max_health - 1, "pogo damages the enemy")
	stool.queue_free()
	await _frames(90)

	# --- Pogo off spikes, then fall into them ---
	var respawns_before: int = counts["respawn"]
	var pogos_before: int = counts["pogo"]
	player.global_position = Vector2(1700.0, 60.0)
	player.velocity = Vector2.ZERO
	Input.action_press(&"move_down")
	Input.action_press(&"attack_light")
	await _frames(3)
	Input.action_release(&"attack_light")
	await _frames(12)
	Input.action_release(&"move_down")
	_check(counts["pogo"] == pogos_before + 1, "pogo bounces off spikes")
	_check(counts["respawn"] == respawns_before, "pogo over spikes does not respawn the player")
	var waited := 0
	while not player.is_dead() and waited < 120:
		await get_tree().physics_frame
		waited += 1
	await _frames(4)
	var sprite := player.get_node(^"Visual/Sprite") as AnimatedSprite2D
	_check(player.is_dead(), "spikes start the death beat before respawning")
	_check(
		sprite != null and (sprite.animation == &"hurt" or sprite.animation == &"defeat"),
		"death plays the hurt/defeat animation (got %s)" % (sprite.animation if sprite else "none")
	)
	await _frames(70)
	_check(counts["respawn"] == respawns_before + 1, "falling into spikes respawns the player")
	_check(player.global_position.x < 1500.0, "respawn returns the player to a checkpoint")

	# --- Bounce pad ---
	await _frames(30)
	pogos_before = counts["pogo"]
	player.global_position = Vector2(1250.0, -60.0)
	player.velocity = Vector2.ZERO
	var pad_apex: float = await _track_apex(player, 90)
	_check(counts["pogo"] > pogos_before, "bounce pad launches the player")
	_check(pad_apex < -450.0, "bounce pad reaches the upper elevation (apex y %.1f)" % pad_apex)

	# --- Launched enemy smashes a crate and dies on spikes ---
	var crates_before := get_tree().get_nodes_in_group(&"breakable").size()
	var wrecker := _spawn_guard(level, Vector2(2150.0, 0.0))
	await _frames(5)
	var crate_hit := HitData.new()
	crate_hit.launch_velocity = Vector2(1400.0, -250.0)
	wrecker.take_hit(crate_hit)
	await _frames(60)
	var crates_after := get_tree().get_nodes_in_group(&"breakable").size()
	_check(crates_after < crates_before, "launched enemy smashes crates (%d -> %d)" % [crates_before, crates_after])

	var doomed := _spawn_guard(level, Vector2(1400.0, 0.0))
	await _frames(5)
	var spike_hit := HitData.new()
	spike_hit.launch_velocity = Vector2(500.0, -500.0)
	doomed.take_hit(spike_hit)
	await _frames(90)
	_check(
		not is_instance_valid(doomed) or doomed.state == Enemy.State.DEFEATED,
		"enemy launched into spikes is defeated"
	)


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
