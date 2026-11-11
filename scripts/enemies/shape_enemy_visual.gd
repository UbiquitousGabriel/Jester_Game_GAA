class_name ShapeEnemyVisual
extends LabelledShape
## Labelled-shape stand-in for enemies without sprites. Reads the Enemy's
## state and brain phase: wind-ups crouch and glow red, active moves
## stretch, launches spin, hits flash, defeats squash flat.

var _enemy: Enemy
var _spin: float = 0.0
## Flyers have their origin at the body centre; shapes draw from the feet.
var centred: bool = false


func _ready() -> void:
	_enemy = get_parent() as Enemy
	if centred:
		position.y = size.y * 0.5


func _process(delta: float) -> void:
	super._process(delta)
	if _enemy == null:
		return
	if _enemy.time_since_hit < 0.05:
		flash = 1.0
		squash = 0.5
	var brain := _enemy.brain
	eye_glow = Color(1.0, 0.95, 0.6)
	match _enemy.state:
		Enemy.State.GROUNDED:
			facing = _enemy.patrol_direction
			_spin = lerp_angle(_spin, 0.0, minf(delta * 12.0, 1.0))
			if brain != null:
				match brain.phase:
					EnemyBrain.Phase.WINDUP:
						squash = 0.45 * brain.phase_progress()
						eye_glow = Color(1.0, 0.25, 0.2)
						position.x = randf_range(-2.0, 2.0) * brain.phase_progress()
					EnemyBrain.Phase.ACTIVE:
						squash = -0.3
						eye_glow = Color(1.0, 0.4, 0.2)
						position.x = 0.0
					_:
						position.x = 0.0
		Enemy.State.LAUNCHED:
			_spin += signf(_enemy.velocity.x) * clampf(_enemy.velocity.length() / 90.0, 3.0, 16.0) * delta
		Enemy.State.DEFEATED:
			squash = 0.9
			eye_glow = Color(0.3, 0.2, 0.3)
		_:
			_spin = lerp_angle(_spin, 0.0, minf(delta * 12.0, 1.0))
	rotation = _spin
