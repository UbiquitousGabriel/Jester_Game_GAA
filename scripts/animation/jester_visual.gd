extends Node2D
## Drives the Jester's painted sprite animations from gameplay state.
##
## Frames come from tools/art/process_jester_sheets.py: every frame shares one
## canvas whose `anchor` (feet, under the skull) maps to this node's origin.
## The node is mirrored through scale.x for facing, and squash/stretch is
## layered on top of the painted poses.
##
## Attack animations are phase-driven, not fps-driven: their frames are picked
## from the hammer's startup / active / recovery progress, so the impact pose is
## on screen exactly while the hitbox is live, whatever the tuning.

const FRAMES: SpriteFrames = preload("res://resources/animation/jester_frames.tres")

## Frame ranges (indices into the animation) for each hammer phase.
const ATTACK_PHASES := {
	&"light_side": [&"attack_side", [0, 1, 2, 3], [4, 5], [6, 7]],
	&"light_up": [&"attack_up", [0, 1], [2, 3, 4], [5, 6]],
	&"heavy": [&"slam", [2, 3], [4, 5], [6, 7]],
	&"air_down": [&"pogo_strike", [0, 1], [2], [2]],
	&"air_1": [&"air_swing_1", [0, 1], [2, 3], [4]],
	&"air_2": [&"air_swing_2", [0, 1], [2, 3], [4]],
	&"air_finisher": [&"air_finisher", [0, 1], [2, 3, 4, 5, 6], [7, 8]],
}

## Sprites are authored at 2x and drawn at half size.
@export var sprite_scale: float = 0.5
@export_group("Air thresholds")
@export var rise_speed: float = 260.0
@export var fall_speed: float = 260.0
@export_group("Afterimages")
@export var afterimage_interval: float = 0.05
@export var afterimage_life: float = 0.22
@export var afterimage_speed: float = 1050.0
@export var afterimage_color: Color = Color(1.0, 0.35, 0.75, 0.42)

var _player: Player = null
var _hammer: Hammer = null
var _sprite: AnimatedSprite2D = null
var _squash: float = 0.0
## A one-shot animation (land, pogo bounce, vault) holds until this runs out.
var _one_shot_time: float = 0.0
var _afterimage_timer: float = 0.0


func _ready() -> void:
	_player = get_parent() as Player
	if _player == null:
		return
	_hammer = _player.get_node_or_null(^"Hammer") as Hammer

	_sprite = AnimatedSprite2D.new()
	_sprite.name = "Sprite"
	_sprite.sprite_frames = FRAMES
	_sprite.centered = false
	_sprite.offset = -JesterSpriteLayout.ANCHOR
	_sprite.scale = Vector2(sprite_scale, sprite_scale)
	add_child(_sprite)
	_sprite.play(&"idle")

	_player.jumped.connect(_on_jumped)
	_player.landed.connect(_on_landed)
	_player.pogoed.connect(_on_pogoed)
	_player.vaulted.connect(_on_vaulted)
	_player.died.connect(_on_died)
	_player.damaged.connect(_on_damaged)
	_player.glide_started.connect(_on_glide_started)
	if _hammer != null:
		_hammer.hit_landed.connect(_on_hit_landed)
	_player.respawned.connect(_on_respawned)


func _process(delta: float) -> void:
	if _player == null:
		return
	_one_shot_time = maxf(_one_shot_time - delta, 0.0)
	_update_animation()
	# Flicker while invulnerable after a hit.
	if _player.is_invulnerable() and not _player.is_dead():
		_sprite.self_modulate.a = 0.35 if int(Time.get_ticks_msec() / 70) % 2 == 0 else 1.0
	else:
		_sprite.self_modulate.a = 1.0
	_update_afterimages(delta)

	_squash = move_toward(_squash, 0.0, delta * 6.0)
	var stretch := Vector2(1.0 + 0.16 * _squash, 1.0 - 0.16 * _squash)
	scale = Vector2(float(_player.facing) * stretch.x, stretch.y)


# --- Animation selection -------------------------------------------------------


func _update_animation() -> void:
	if _player.is_dead():
		return  # _on_died started the defeat sequence

	if _hammer != null:
		if _hammer.state == Hammer.State.CHARGING:
			_show_frame(&"charge", 0 if _hammer.charge_ratio < 0.25 else 1)
			# Tremble harder as the charge fills.
			_sprite.position = Vector2(randf_range(-1.0, 1.0), 0.0) * 4.0 * _hammer.charge_ratio
			return
		_sprite.position = Vector2.ZERO
		if _hammer.is_attacking() and _hammer.current_attack != null:
			if _show_attack(_hammer.current_attack.id):
				return

	if _player.is_hurt():
		_show_frame(&"hurt", 1)
		return

	if _player.is_gliding():
		_play(&"air_spin")
		return

	if _one_shot_time > 0.0:
		return

	if _player.is_dashing():
		_show_frame(&"dash", 0)
		return

	var velocity := _player.velocity
	if not _player.is_on_floor():
		if velocity.y < -rise_speed:
			_play(&"jump_rise")
		elif velocity.y > fall_speed:
			_show_frame(&"jump_fall", 0)
		else:
			_show_frame(&"jump_apex", 0)
		return

	var speed := absf(velocity.x)
	if speed > 40.0:
		_play(&"run")
		_sprite.speed_scale = clampf(speed / _player.config.max_run_speed, 0.6, 1.7)
	else:
		_play(&"idle")
		_sprite.speed_scale = 1.0


## Returns false for attacks without a mapping (falls through to movement).
func _show_attack(attack_id: StringName) -> bool:
	if not ATTACK_PHASES.has(attack_id):
		return false
	var spec: Array = ATTACK_PHASES[attack_id]
	var phase_frames: Array
	match _hammer.state:
		Hammer.State.STARTUP:
			phase_frames = spec[1]
		Hammer.State.ACTIVE:
			phase_frames = spec[2]
		_:
			phase_frames = spec[3]
	var t := _hammer.phase_progress()
	var pick := mini(int(t * float(phase_frames.size())), phase_frames.size() - 1)
	_show_frame(spec[0], phase_frames[pick])
	return true


func _play(animation: StringName) -> void:
	if _sprite.animation != animation or not _sprite.is_playing():
		_sprite.play(animation)


func _play_one_shot(animation: StringName) -> void:
	_sprite.speed_scale = 1.0
	_sprite.play(animation)
	var count := FRAMES.get_frame_count(animation)
	var fps := maxf(FRAMES.get_animation_speed(animation), 1.0)
	_one_shot_time = float(count) / fps


func _show_frame(animation: StringName, frame: int) -> void:
	if _sprite.animation != animation:
		_sprite.animation = animation
	_sprite.pause()
	_sprite.frame = frame


# --- Afterimages -----------------------------------------------------------------


func _update_afterimages(delta: float) -> void:
	var fast := _player.velocity.length() >= afterimage_speed
	if not (_player.is_dashing() or fast) or _player.is_dead():
		_afterimage_timer = 0.0
		return
	_afterimage_timer -= delta
	if _afterimage_timer > 0.0:
		return
	_afterimage_timer = afterimage_interval
	var texture := FRAMES.get_frame_texture(_sprite.animation, _sprite.frame)
	if texture == null:
		return
	var ghost := Sprite2D.new()
	ghost.texture = texture
	ghost.centered = false
	ghost.offset = _sprite.offset
	ghost.top_level = true
	ghost.global_transform = _sprite.global_transform
	ghost.modulate = afterimage_color
	ghost.z_index = -1
	# Additive-ish glow without needing a shader.
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	ghost.material = material
	_player.get_parent().add_child(ghost)
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, afterimage_life)
	tween.tween_callback(ghost.queue_free)


# --- Signal reactions ------------------------------------------------------------


func _on_jumped() -> void:
	_squash = -0.7
	_sprite.speed_scale = 1.0
	_sprite.play(&"jump_rise")


func _on_hit_landed(target: Node, hit: HitData) -> void:
	var target_2d := target as Node2D
	if target_2d == null:
		return
	var at := target_2d.global_position + Vector2(0.0, -40.0)
	var power := clampf(hit.launch_velocity.length() / 1100.0, 0.7, 1.6)
	Vfx.hit(_player.get_parent(), at, hit.launch_velocity.normalized(), power)


func _on_landed(impact_speed: float) -> void:
	_squash = clampf(impact_speed / 1400.0, 0.15, 0.9)
	if impact_speed > 450.0:
		Vfx.dust(_player.get_parent(), _player.global_position, clampf(impact_speed / 1100.0, 0.7, 1.5))
	# Only plant the landing pose when not carrying run speed into it.
	if absf(_player.velocity.x) < 120.0 and impact_speed > 350.0:
		_play_one_shot(&"land")


func _on_pogoed() -> void:
	_squash = -0.8
	Vfx.dust(_player.get_parent(), _player.global_position + Vector2(0.0, 30.0), 0.8)
	_play_one_shot(&"pogo_bounce")


func _on_vaulted(perfect: bool) -> void:
	_squash = -0.9
	Vfx.dust(_player.get_parent(), _player.global_position, 1.3 if perfect else 1.0)
	_play_one_shot(&"vault")


func _on_damaged(_amount: int) -> void:
	if not _player.is_dead():
		Vfx.hit(_player.get_parent(), _player.global_position + Vector2(0.0, -46.0), Vector2.UP, 0.8)


func _on_glide_started() -> void:
	_squash = -0.5
	Vfx.dust(_player.get_parent(), _player.global_position, 0.7)


func _on_died() -> void:
	_squash = 0.0
	_one_shot_time = 0.0
	_sprite.position = Vector2.ZERO
	_sprite.speed_scale = 1.0
	_sprite.play(&"hurt")
	if not _sprite.animation_finished.is_connected(_on_hurt_finished):
		_sprite.animation_finished.connect(_on_hurt_finished, CONNECT_ONE_SHOT)


func _on_hurt_finished() -> void:
	if _player.is_dead():
		_sprite.play(&"defeat")


func _on_respawned() -> void:
	_one_shot_time = 0.0
	_sprite.play(&"idle")
	# Brief blink so the player can find the Jester after respawning.
	var tween := create_tween()
	for i: int in 3:
		tween.tween_property(_sprite, "modulate:a", 0.25, 0.06)
		tween.tween_property(_sprite, "modulate:a", 1.0, 0.06)

