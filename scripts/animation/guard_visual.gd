extends Node2D
## Drives the Court Guard's sprite from the Enemy state machine.
##
## The Court Guard is temporarily played by the Community Aide (sleepy,
## duck-print pyjamas, living human): frames from
## tools/art/process_aide_sheets.py. Swap FRAMES and the layout constant when
## real guard art exists; the state mapping stays.
##
## This node sits at the body centre so launch tumbles rotate around the
## middle of the body; the sprite inside it is offset back down to the feet.

const FRAMES: SpriteFrames = preload("res://resources/animation/community_aide_frames.tres")
const FLASH_TIME: float = 0.09
## Frames are authored at 2x.
const SPRITE_SCALE: float = 0.5
## Airborne frames inside the "airborne" animation.
const AIR_RISING: int = 0
const AIR_APEX: int = 1
const AIR_FALLING: int = 2

@export var walk_fps_at_patrol_speed: float = 10.0
@export var apex_band: float = 220.0
@export var flash_color: Color = Color(2.6, 2.6, 2.6)

var _enemy: Enemy = null
var _sprite: AnimatedSprite2D = null
var _facing: int = -1
var _centre_height: float = 52.0


func _ready() -> void:
	_enemy = get_parent() as Enemy
	if _enemy != null:
		_enemy.collided_with_enemy.connect(_on_collided)
	_centre_height = CommunityAideSpriteLayout.STANDING_HEIGHT * SPRITE_SCALE * 0.5
	position = Vector2(0.0, -_centre_height)

	_sprite = AnimatedSprite2D.new()
	_sprite.name = "Sprite"
	_sprite.sprite_frames = FRAMES
	_sprite.centered = false
	_sprite.offset = -CommunityAideSpriteLayout.ANCHOR
	_sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	_sprite.position = Vector2(0.0, _centre_height)
	add_child(_sprite)
	# Desynchronise idle loops so a crowd does not breathe in unison.
	_sprite.play(&"idle")
	_sprite.frame = randi() % FRAMES.get_frame_count(&"idle")


func _process(delta: float) -> void:
	if _enemy == null:
		return
	_update_pose(delta)
	_sprite.self_modulate = flash_color if _enemy.time_since_hit < FLASH_TIME else Color.WHITE
	scale.x = float(_facing)


func _update_pose(delta: float) -> void:
	var blend := minf(delta * 14.0, 1.0)
	match _enemy.state:
		Enemy.State.GROUNDED:
			_upright(blend)
			_facing = _enemy.patrol_direction
			if absf(_enemy.velocity.x) > 5.0:
				_play(&"walk")
				_sprite.speed_scale = absf(_enemy.velocity.x) / maxf(_enemy.patrol_speed, 1.0)
				_sprite.speed_scale *= walk_fps_at_patrol_speed / FRAMES.get_animation_speed(&"walk")
			else:
				_play(&"idle")
				_sprite.speed_scale = 1.0
		Enemy.State.STAGGERED:
			_upright(blend)
			_hold(&"impact", 0)
		Enemy.State.LAUNCHED:
			var vy := _enemy.velocity.y
			var pose := AIR_APEX
			if vy < -apex_band:
				pose = AIR_RISING
			elif vy > apex_band:
				pose = AIR_FALLING
			_hold(&"airborne", pose)
			if absf(_enemy.velocity.x) > 10.0:
				_facing = -int(signf(_enemy.velocity.x))  # flung backwards
			var spin := clampf(_enemy.velocity.length() / 90.0, 3.0, 18.0)
			rotation += signf(_enemy.velocity.x) * spin * delta
		Enemy.State.KNOCKED_DOWN, Enemy.State.DEFEATED:
			_hold(&"impact", 0)
			# Lie flat on his back.
			rotation = lerp_angle(rotation, PI * 0.5, blend)
			position.y = lerpf(position.y, -14.0, blend)
		Enemy.State.RECOVER:
			_upright(blend)
			_hold(&"crouch", 0)


func _upright(blend: float) -> void:
	rotation = lerp_angle(rotation, 0.0, blend)
	position.y = lerpf(position.y, -_centre_height, blend)


func _play(animation: StringName) -> void:
	if _sprite.animation != animation or not _sprite.is_playing():
		_sprite.play(animation)


func _hold(animation: StringName, frame: int) -> void:
	if _sprite.animation != animation:
		_sprite.animation = animation
	_sprite.pause()
	_sprite.frame = frame


func _on_collided(other: Enemy) -> void:
	var at := (_enemy.global_position + other.global_position) * 0.5 + Vector2(0.0, -40.0)
	Vfx.hit(_enemy.get_parent(), at, _enemy.velocity.normalized(), 1.0)
