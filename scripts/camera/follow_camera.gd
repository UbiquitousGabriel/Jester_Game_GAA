class_name FollowCamera
extends Camera2D
## Zoomed-out follow camera: velocity look-ahead, dead-zoned vertical tracking,
## level bounds, speed-based dynamic zoom and screen shake.
##
## Framing target (Bible section 6): the hero occupies roughly 5-9% of viewport
## height in traversal rooms. With a 72 px hero on a 1080 px viewport that is
## zoom 1.0 at rest, easing out to `fast_zoom` at speed.

@export var target_path: NodePath

@export_group("Look-ahead")
## Pixels of look-ahead per pixel/second of target velocity.
@export var lookahead_factor: float = 0.32
@export var max_lookahead: Vector2 = Vector2(420.0, 200.0)
@export var lookahead_smoothing: float = 3.0

@export_group("Tracking")
@export var horizontal_smoothing: float = 9.0
@export var vertical_smoothing: float = 5.0
## The camera ignores vertical movement inside this band (pixels).
@export var vertical_dead_zone: float = 80.0
## Negative values frame the action slightly above the hero.
@export var vertical_offset: float = -140.0

@export_group("Zoom")
@export var base_zoom: float = 1.0
@export var dynamic_zoom_enabled: bool = true
## Zoom level reached at `zoom_out_full_speed`. Lower = further out.
@export var fast_zoom: float = 0.82
@export var zoom_out_start_speed: float = 550.0
@export var zoom_out_full_speed: float = 1400.0
@export var zoom_smoothing: float = 2.0

@export_group("Shake")
@export var max_shake: float = 28.0
@export var shake_decay: float = 60.0

var _target: Node2D = null
var _focus: Vector2 = Vector2.ZERO
var _lookahead: Vector2 = Vector2.ZERO
var _current_zoom: float = 1.0
var _shake: float = 0.0
var _bounds: Rect2 = Rect2()
var _has_bounds: bool = false
var _last_shake_msec: int = 0
var _rng := RandomNumberGenerator.new()
var _punch: float = 0.0


func _ready() -> void:
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	position_smoothing_enabled = false
	_current_zoom = base_zoom
	zoom = Vector2(base_zoom, base_zoom)
	if not target_path.is_empty():
		_target = get_node_or_null(target_path) as Node2D
	if _target != null:
		_focus = _target.global_position + Vector2(0.0, vertical_offset)
		global_position = _focus
	GameFeel.shake_requested.connect(add_shake)
	_last_shake_msec = Time.get_ticks_msec()
	make_current()


func set_target(target: Node2D) -> void:
	_target = target


## Restrict the view to a world-space rectangle.
func set_bounds(bounds: Rect2) -> void:
	_bounds = bounds
	_has_bounds = true
	limit_left = int(bounds.position.x)
	limit_top = int(bounds.position.y)
	limit_right = int(bounds.end.x)
	limit_bottom = int(bounds.end.y)


## Jump straight to the target (room changes, respawns).
func snap() -> void:
	if _target == null:
		return
	_lookahead = Vector2.ZERO
	_focus = _target.global_position + Vector2(0.0, vertical_offset)
	_clamp_focus_to_bounds()
	global_position = _focus
	reset_smoothing()


## Brief zoom-in kick for big impacts (decays on its own).
func punch(amount: float) -> void:
	_punch = minf(_punch + amount, 0.12)


func add_shake(strength: float) -> void:
	_shake = minf(_shake + strength, max_shake)


func _physics_process(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		return

	var target_velocity := Vector2.ZERO
	var body := _target as CharacterBody2D
	if body != null:
		target_velocity = body.velocity

	# Look ahead in the direction of travel so landings are visible early.
	var desired_lookahead := Vector2(
		clampf(target_velocity.x * lookahead_factor, -max_lookahead.x, max_lookahead.x),
		clampf(target_velocity.y * lookahead_factor * 0.5, -max_lookahead.y, max_lookahead.y)
	)
	_lookahead = _lookahead.lerp(desired_lookahead, _blend(lookahead_smoothing, delta))

	var desired := _target.global_position + Vector2(0.0, vertical_offset) + _lookahead
	_focus.x = lerpf(_focus.x, desired.x, _blend(horizontal_smoothing, delta))
	var vertical_error := desired.y - _focus.y
	if absf(vertical_error) > vertical_dead_zone:
		var goal_y := desired.y - signf(vertical_error) * vertical_dead_zone
		_focus.y = lerpf(_focus.y, goal_y, _blend(vertical_smoothing, delta))

	_update_zoom(target_velocity.length(), delta)
	_clamp_focus_to_bounds()
	global_position = _focus


func _process(_delta: float) -> void:
	# Shake decays in real time so it keeps moving during hit-stop.
	var now := Time.get_ticks_msec()
	var real_delta := float(now - _last_shake_msec) / 1000.0
	_last_shake_msec = now
	if _shake <= 0.0:
		offset = Vector2.ZERO
		return
	_shake = maxf(_shake - shake_decay * real_delta, 0.0)
	offset = Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)) * _shake


func _update_zoom(speed: float, delta: float) -> void:
	var goal := base_zoom
	if dynamic_zoom_enabled:
		var span := maxf(zoom_out_full_speed - zoom_out_start_speed, 1.0)
		var t := clampf((speed - zoom_out_start_speed) / span, 0.0, 1.0)
		goal = lerpf(base_zoom, fast_zoom, t)
	_current_zoom = lerpf(_current_zoom, goal, _blend(zoom_smoothing, delta))
	_punch = move_toward(_punch, 0.0, delta * 0.5)
	zoom = Vector2.ONE * (_current_zoom + _punch)


func _clamp_focus_to_bounds() -> void:
	if not _has_bounds:
		return
	var half_view := get_viewport_rect().size / (2.0 * _current_zoom)
	if _bounds.size.x > half_view.x * 2.0:
		_focus.x = clampf(_focus.x, _bounds.position.x + half_view.x, _bounds.end.x - half_view.x)
	if _bounds.size.y > half_view.y * 2.0:
		_focus.y = clampf(_focus.y, _bounds.position.y + half_view.y, _bounds.end.y - half_view.y)


## Frame-rate independent exponential smoothing factor.
func _blend(rate: float, delta: float) -> float:
	return 1.0 - exp(-rate * delta)
