extends Node2D
## Procedural placeholder for the Jester (undead skeleton) and his clown hammer.
## Drawn with primitives until the sprite pipeline exists (docs/ART_PIPELINE.md).
## Origin is at the feet; the node is mirrored through scale.x for facing.

const CRIMSON := Color(0.8, 0.14, 0.26)
const PURPLE := Color(0.43, 0.2, 0.62)
const GOLD := Color(0.98, 0.76, 0.22)
const CREAM := Color(0.97, 0.93, 0.84)
const INK := Color(0.14, 0.08, 0.2)
const WOOD := Color(0.5, 0.32, 0.2)

const HAND := Vector2(8.0, -30.0)

var _player: Player = null
var _hammer: Hammer = null
var _squash: float = 0.0


func _ready() -> void:
	_player = get_parent() as Player
	if _player == null:
		return
	_hammer = _player.get_node_or_null(^"Hammer") as Hammer
	_player.landed.connect(_on_landed)
	_player.pogoed.connect(_on_stretch)
	_player.vaulted.connect(_on_vaulted)


func _process(delta: float) -> void:
	if _player == null:
		return
	_squash = move_toward(_squash, 0.0, delta * 5.0)
	scale = Vector2(float(_player.facing) * (1.0 + 0.2 * _squash), 1.0 - 0.2 * _squash)
	queue_redraw()


func _draw() -> void:
	# Dash streak behind the body.
	if _player != null and _player.is_dashing():
		draw_rect(Rect2(-70.0, -50.0, 56.0, 8.0), Color(GOLD, 0.6))
		draw_rect(Rect2(-90.0, -30.0, 70.0, 8.0), Color(CRIMSON, 0.5))

	# Shoes
	draw_rect(Rect2(-16.0, -8.0, 14.0, 8.0), CRIMSON)
	draw_rect(Rect2(4.0, -8.0, 16.0, 8.0), CRIMSON)
	# Striped tunic
	draw_rect(Rect2(-14.0, -36.0, 28.0, 28.0), PURPLE)
	draw_rect(Rect2(-5.0, -36.0, 10.0, 28.0), CRIMSON)
	# Ruff
	draw_rect(Rect2(-18.0, -42.0, 36.0, 8.0), CREAM)
	# Skull
	draw_circle(Vector2(0.0, -56.0), 17.0, CREAM)
	draw_circle(Vector2(3.0, -58.0), 4.5, INK)
	draw_circle(Vector2(12.0, -58.0), 3.5, INK)
	draw_rect(Rect2(2.0, -47.0, 12.0, 2.0), INK)
	# Two-tone jester hat with bells
	draw_colored_polygon(
		PackedVector2Array([Vector2(-17.0, -64.0), Vector2(2.0, -72.0), Vector2(-32.0, -88.0)]),
		CRIMSON
	)
	draw_colored_polygon(
		PackedVector2Array([Vector2(-4.0, -70.0), Vector2(17.0, -64.0), Vector2(27.0, -92.0)]),
		PURPLE
	)
	draw_circle(Vector2(-32.0, -88.0), 5.0, GOLD)
	draw_circle(Vector2(27.0, -92.0), 5.0, GOLD)

	_draw_hammer()


func _draw_hammer() -> void:
	var size := 1.0
	if _hammer != null and _hammer.state == Hammer.State.CHARGING:
		size = 1.0 + 0.35 * _hammer.charge_ratio
	draw_set_transform(HAND, _hammer_angle(), Vector2(size, size))
	draw_line(Vector2.ZERO, Vector2(56.0, 0.0), WOOD, 7.0)
	draw_rect(Rect2(48.0, -27.0, 38.0, 54.0), CRIMSON)
	draw_rect(Rect2(48.0, -27.0, 38.0, 8.0), GOLD)
	draw_rect(Rect2(48.0, 19.0, 38.0, 8.0), GOLD)
	draw_colored_polygon(_star(Vector2(67.0, 0.0), 11.0, 5.0), GOLD)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Hammer angle in radians. 0 points forward, -90 degrees points up.
func _hammer_angle() -> float:
	if _hammer == null:
		return deg_to_rad(-150.0)
	if _hammer.state == Hammer.State.CHARGING:
		return deg_to_rad(-165.0 - 25.0 * _hammer.charge_ratio)
	if _hammer.current_attack == null:
		return deg_to_rad(-150.0)
	# The swing completes during startup + active, then holds through recovery.
	var t := minf(_hammer.attack_progress() * 2.5, 1.0)
	match _hammer.current_attack.id:
		&"air_down":
			return deg_to_rad(90.0)
		&"light_up":
			return deg_to_rad(lerpf(20.0, -160.0, t))
		&"heavy":
			return deg_to_rad(lerpf(-175.0, 50.0, t))
	return deg_to_rad(lerpf(-130.0, 30.0, t))


func _star(centre: Vector2, outer: float, inner: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i: int in 10:
		var radius := outer if i % 2 == 0 else inner
		var angle := -PI / 2.0 + float(i) * PI / 5.0
		points.append(centre + Vector2.from_angle(angle) * radius)
	return points


func _on_landed(impact_speed: float) -> void:
	_squash = clampf(impact_speed / 1200.0, 0.2, 1.0)


func _on_stretch() -> void:
	_squash = -0.6


func _on_vaulted(_perfect: bool) -> void:
	_squash = -0.8
