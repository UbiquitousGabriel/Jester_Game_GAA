class_name LabelledShape
extends Node2D
## Placeholder body for characters without sprites yet: an inked silhouette
## in the character's palette with eyes and a name tag. Drawn, not textured,
## so it is obviously a stand-in (docs/ASSET_REQUESTS.pdf lists the art).
## Origin is at the feet. Reacts to squash, flash, facing and bobbing.

enum Kind { CAPSULE, BOX, CIRCLE, DIAMOND, BELL, TALL }

@export var label: String = "???"
@export var size: Vector2 = Vector2(60.0, 90.0)
@export var color: Color = Color(0.6, 0.3, 0.5)
@export var accent: Color = Color(0.98, 0.76, 0.22)
@export var kind: Kind = Kind.CAPSULE
@export var bob: float = 0.0
@export var show_label: bool = true

var facing: int = 1
var flash: float = 0.0
var squash: float = 0.0
var eye_glow: Color = Color(1.0, 0.95, 0.6)
var _time: float = 0.0


func _process(delta: float) -> void:
	_time += delta
	flash = maxf(flash - delta * 8.0, 0.0)
	squash = move_toward(squash, 0.0, delta * 5.0)
	queue_redraw()


func _draw() -> void:
	var s := size * Vector2(1.0 + 0.2 * squash, 1.0 - 0.2 * squash)
	var lift := sin(_time * 3.0) * bob
	var body := Rect2(-s.x * 0.5, -s.y + lift, s.x, s.y)
	var fill := color.lerp(Color.WHITE, clampf(flash, 0.0, 1.0))
	var ink := Color(0.1, 0.05, 0.13)
	match kind:
		Kind.CIRCLE:
			var c := body.get_center()
			draw_circle(c, s.x * 0.5 + 4.0, ink)
			draw_circle(c, s.x * 0.5, fill)
			draw_circle(c + Vector2(-s.x * 0.15, -s.y * 0.15), s.x * 0.18, fill.lightened(0.25))
		Kind.DIAMOND:
			var c := body.get_center()
			var pts := PackedVector2Array([c + Vector2(0, -s.y * 0.5), c + Vector2(s.x * 0.5, 0), c + Vector2(0, s.y * 0.5), c + Vector2(-s.x * 0.5, 0)])
			draw_colored_polygon(_grow(pts, c, 5.0), ink)
			draw_colored_polygon(pts, fill)
		Kind.BELL:
			var top := body.position + Vector2(s.x * 0.5, 0.0)
			var pts := PackedVector2Array([
				top + Vector2(-s.x * 0.22, 0.0), top + Vector2(s.x * 0.22, 0.0),
				top + Vector2(s.x * 0.35, s.y * 0.6), top + Vector2(s.x * 0.5, s.y * 0.92),
				top + Vector2(-s.x * 0.5, s.y * 0.92), top + Vector2(-s.x * 0.35, s.y * 0.6)])
			draw_colored_polygon(_grow(pts, body.get_center(), 5.0), ink)
			draw_colored_polygon(pts, fill)
			draw_circle(top + Vector2(0.0, s.y * 0.98), s.x * 0.1, accent)
		_:
			var radius := minf(s.x, s.y) * (0.45 if kind == Kind.CAPSULE else 0.12)
			_round_rect(body.grow(4.0), radius + 4.0, ink)
			_round_rect(body, radius, fill)
			draw_rect(Rect2(body.position.x + 6.0, body.position.y + s.y * 0.55, s.x - 12.0, 8.0), accent)
	# Eyes, looking toward facing.
	var eye_y := body.position.y + s.y * (0.3 if kind != Kind.BELL else 0.5)
	var dx := float(facing) * s.x * 0.12
	for side: float in [-1.0, 1.0]:
		var e := Vector2(body.get_center().x + side * s.x * 0.16 + dx, eye_y)
		draw_circle(e, maxf(s.x * 0.08, 4.0), ink)
		draw_circle(e, maxf(s.x * 0.05, 2.5), eye_glow)
	if show_label:
		var font := ThemeDB.fallback_font
		var text_size := 18
		var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, text_size).x
		var pos := Vector2(-w * 0.5, body.position.y - 12.0)
		draw_string_outline(font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, 6, ink)
		draw_string(font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, Color(1.0, 0.95, 0.85))


func hit_flash() -> void:
	flash = 1.0
	squash = 0.6


func _round_rect(r: Rect2, radius: float, c: Color) -> void:
	radius = minf(radius, minf(r.size.x, r.size.y) * 0.5)
	draw_rect(Rect2(r.position.x + radius, r.position.y, r.size.x - radius * 2.0, r.size.y), c)
	draw_rect(Rect2(r.position.x, r.position.y + radius, r.size.x, r.size.y - radius * 2.0), c)
	for corner: Vector2 in [r.position + Vector2(radius, radius), Vector2(r.end.x - radius, r.position.y + radius),
			Vector2(r.position.x + radius, r.end.y - radius), r.end - Vector2(radius, radius)]:
		draw_circle(corner, radius, c)


func _grow(pts: PackedVector2Array, c: Vector2, by: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in pts:
		out.append(p + (p - c).normalized() * by)
	return out
