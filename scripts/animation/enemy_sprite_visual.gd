class_name EnemySpriteVisual
extends Node2D
## Data-driven sprite visual for brain-driven enemies (mace knight, bat
## knight). Picks animations from the Enemy state and the brain's attack
## phase; attack frames follow phase progress so impacts match hitboxes.

@export var frames: SpriteFrames
## Canvas pixel that maps to the enemy origin (from the generated layout).
@export var anchor: Vector2 = Vector2.ZERO
@export var sprite_scale: float = 0.5
## Height above the origin used as the tumble pivot (0 for flyers whose
## origin is already the body centre).
@export var pivot_height: float = 50.0

@export_group("Animations")
@export var idle_anim: StringName = &"idle"
@export var move_anim: StringName = &"walk"
@export var hurt_anim: StringName = &"hurt"
@export var launched_anim: StringName = &"launched"
@export var death_anim: StringName = &"death"
## Frame of death_anim held while knocked down (lying).
@export var knocked_down_frame: int = 4
## [animation, frames] per brain phase.
@export var windup: Array = []
@export var active: Array = []
@export var recover: Array = []
@export var move_threshold: float = 12.0

@export_group("Feel")
@export var spin_rate: float = 1.0
@export var flash_color: Color = Color(2.6, 2.6, 2.6)

var _enemy: Enemy = null
var _sprite: AnimatedSprite2D = null
var _facing: int = -1
var _dead_played: bool = false


func _ready() -> void:
	_enemy = get_parent() as Enemy
	position = Vector2(0.0, -pivot_height)
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "Sprite"
	_sprite.sprite_frames = frames
	_sprite.centered = false
	_sprite.offset = -anchor
	_sprite.scale = Vector2(sprite_scale, sprite_scale)
	_sprite.position = Vector2(0.0, pivot_height)
	add_child(_sprite)
	_sprite.play(idle_anim)
	_sprite.frame = randi() % maxi(frames.get_frame_count(idle_anim), 1)
	if _enemy != null:
		_enemy.collided_with_enemy.connect(_on_collided)
		_enemy.defeated.connect(_on_defeated)


func _process(delta: float) -> void:
	if _enemy == null:
		return
	_update(delta)
	_sprite.self_modulate = flash_color if _enemy.time_since_hit < 0.09 else Color.WHITE
	scale.x = float(_facing)


func _update(delta: float) -> void:
	var blend := minf(delta * 14.0, 1.0)
	var brain := _enemy.brain
	match _enemy.state:
		Enemy.State.GROUNDED:
			_upright(blend)
			_facing = _enemy.patrol_direction
			if brain != null and brain.phase != EnemyBrain.Phase.NONE:
				var spec: Array = windup
				if brain.phase == EnemyBrain.Phase.ACTIVE:
					spec = active
				elif brain.phase == EnemyBrain.Phase.RECOVER:
					spec = recover
				if spec.size() == 2:
					var list: Array = spec[1]
					var pick := mini(int(brain.phase_progress() * float(list.size())), list.size() - 1)
					_hold(spec[0], list[pick])
					return
			if _enemy.velocity.length() > move_threshold and move_anim != &"":
				_play(move_anim)
			else:
				_play(idle_anim)
		Enemy.State.STAGGERED, Enemy.State.RECOVER:
			_upright(blend)
			_play(hurt_anim)
		Enemy.State.LAUNCHED:
			_hold(launched_anim, 0)
			if absf(_enemy.velocity.x) > 10.0:
				_facing = -int(signf(_enemy.velocity.x))
			var spin := clampf(_enemy.velocity.length() / 90.0, 3.0, 18.0) * spin_rate
			rotation += signf(_enemy.velocity.x) * spin * delta
		Enemy.State.KNOCKED_DOWN:
			_upright(blend)
			_hold(death_anim, knocked_down_frame)
		Enemy.State.DEFEATED:
			_upright(blend)
			if not _dead_played:
				_dead_played = true
				_sprite.play(death_anim)


func _upright(blend: float) -> void:
	rotation = lerp_angle(rotation, 0.0, blend)


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


func _on_defeated() -> void:
	rotation = 0.0
	Vfx.cloud(_enemy.get_parent(), _enemy.global_position + Vector2(0.0, -30.0), 0.9)
