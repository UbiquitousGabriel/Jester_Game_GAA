extends Node2D
## Procedural placeholder for the Court Guard: a living human soldier.
## World rule (Bible section 3): royal forces are human. The helmet has a dark
## eye slit, with a visible human jaw below it. No skull faces.
##
## This node sits at the body centre (40 px above the feet) so launch spin
## rotates around the middle of the body.

const STEEL := Color(0.62, 0.64, 0.72)
const DARK_STEEL := Color(0.36, 0.37, 0.46)
const CRIMSON := Color(0.74, 0.13, 0.22)
const PURPLE := Color(0.4, 0.2, 0.56)
const GOLD := Color(0.98, 0.76, 0.22)
const SKIN := Color(0.93, 0.72, 0.58)
const INK := Color(0.14, 0.08, 0.2)
const WOOD := Color(0.5, 0.32, 0.2)

const CENTRE_HEIGHT: float = 40.0
const FLASH_TIME: float = 0.08

var _enemy: Enemy = null
var _facing: int = -1


func _ready() -> void:
	_enemy = get_parent() as Enemy


func _process(delta: float) -> void:
	if _enemy == null:
		return
	match _enemy.state:
		Enemy.State.LAUNCHED:
			# Tumble in the direction of travel.
			rotation += signf(_enemy.velocity.x) * clampf(_enemy.velocity.length() / 80.0, 4.0, 22.0) * delta
			position.y = -CENTRE_HEIGHT
		Enemy.State.KNOCKED_DOWN, Enemy.State.DEFEATED:
			rotation = lerp_angle(rotation, float(_facing) * -PI / 2.0, minf(delta * 18.0, 1.0))
			position.y = lerpf(position.y, -16.0, minf(delta * 18.0, 1.0))
		_:
			rotation = lerp_angle(rotation, 0.0, minf(delta * 12.0, 1.0))
			position.y = lerpf(position.y, -CENTRE_HEIGHT, minf(delta * 12.0, 1.0))
			if _enemy.state == Enemy.State.GROUNDED:
				_facing = _enemy.patrol_direction
	scale.x = float(_facing)
	queue_redraw()


func _draw() -> void:
	# Legs
	draw_rect(Rect2(-12.0, 18.0, 10.0, 22.0), _tint(DARK_STEEL))
	draw_rect(Rect2(2.0, 18.0, 10.0, 22.0), _tint(DARK_STEEL))
	# Spear (behind the body)
	draw_line(Vector2(-18.0, 34.0), Vector2(-18.0, -58.0), _tint(WOOD), 4.0)
	draw_colored_polygon(
		PackedVector2Array([Vector2(-24.0, -56.0), Vector2(-12.0, -56.0), Vector2(-18.0, -74.0)]),
		_tint(STEEL)
	)
	# Tabard with royal emblem
	draw_rect(Rect2(-16.0, -12.0, 32.0, 32.0), _tint(CRIMSON))
	draw_rect(Rect2(-6.0, -4.0, 12.0, 10.0), _tint(GOLD))
	# Human face under the helmet
	draw_circle(Vector2(0.0, -22.0), 13.0, _tint(SKIN))
	# Helmet with eye slit and plume
	draw_rect(Rect2(-15.0, -38.0, 30.0, 17.0), _tint(STEEL))
	draw_rect(Rect2(1.0, -29.0, 13.0, 3.0), _tint(INK))
	draw_colored_polygon(
		PackedVector2Array([Vector2(-6.0, -38.0), Vector2(6.0, -38.0), Vector2(-12.0, -54.0)]),
		_tint(CRIMSON)
	)
	# Shield held in front
	draw_rect(Rect2(10.0, -10.0, 14.0, 30.0), _tint(PURPLE))
	draw_rect(Rect2(10.0, -10.0, 14.0, 30.0), _tint(GOLD), false, 3.0)


## Flash white for a few frames after any hit.
func _tint(base: Color) -> Color:
	if _enemy != null and _enemy.time_since_hit < FLASH_TIME:
		return Color.WHITE
	return base
