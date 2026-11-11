class_name SpectralBarrier
extends StaticBody2D
## A shimmering wall of court magic. Solid, except to a Phantom Step dash.

const SPECTRAL_LAYER := 128

var _time: float = 0.0


static func create(top_left: Vector2) -> SpectralBarrier:
	var barrier := SpectralBarrier.new()
	barrier.position = top_left
	return barrier


func _ready() -> void:
	collision_layer = SPECTRAL_LAYER
	collision_mask = 0
	var shape := RectangleShape2D.new()
	shape.size = Vector2(64.0, 64.0)
	var cs := CollisionShape2D.new()
	cs.shape = shape
	cs.position = Vector2(32.0, 32.0)
	add_child(cs)
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	self.material = material
	_time = randf() * 10.0


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var a := 0.35 + 0.15 * sin(_time * 3.0)
	draw_rect(Rect2(4.0, 0.0, 56.0, 64.0), Color(0.45, 0.85, 1.0, a))
	for i: int in 4:
		var y := fmod(_time * 60.0 + float(i) * 16.0, 64.0)
		draw_line(Vector2(8.0, y), Vector2(56.0, y), Color(0.8, 0.95, 1.0, a * 1.4), 2.0)
	draw_rect(Rect2(4.0, 0.0, 56.0, 64.0), Color(0.7, 0.95, 1.0, a + 0.2), false, 2.0)
