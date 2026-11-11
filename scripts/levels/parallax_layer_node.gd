class_name ParallaxLayerNode
extends Node2D
## One backdrop layer that follows the camera at `scroll_factor`.
##
## Explicit instead of Parallax2D so the alignment rule is easy to read: when
## the camera centre is at y = rest_camera_y, the texture row `ground_row`
## lands on world y = horizon_y. Moving the camera up drops the layer on
## screen (scroll_factor < 1), so the solid bottom is always below the play
## space; a fill rect below the texture covers deep camera positions.

var texture: Texture2D
var scroll_factor: Vector2 = Vector2(0.3, 0.2)
var ground_row: float = 0.0
var tiles: bool = true
var horizon_y: float = 0.0
var rest_camera_y: float = 0.0
## Non-tiling layers are centred on screen when the camera is at this x.
var centre_x: float = 3080.0
var camera: Camera2D

var _sprite: Sprite2D
var _fill: ColorRect


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = texture
	_sprite.centered = false
	_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_sprite.region_enabled = true
	add_child(_sprite)
	_fill = ColorRect.new()
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill.color = texture.get_image().get_pixel(texture.get_width() / 2, texture.get_height() - 2)
	add_child(_fill)


func _process(_delta: float) -> void:
	if camera == null:
		return
	var centre := camera.get_screen_center_position()
	var view := get_viewport_rect().size / camera.zoom
	var tex_w := float(texture.get_width())
	var tex_h := float(texture.get_height())

	# Layer origin in world space.
	var origin_y := horizon_y - ground_row + (centre.y - rest_camera_y) * (1.0 - scroll_factor.y)
	var origin_x := centre.x * (1.0 - scroll_factor.x)
	var left := centre.x - view.x * 0.5 - 8.0
	var width := view.x + 16.0
	if tiles:
		var start := floorf((left - origin_x) / tex_w) * tex_w
		position = Vector2(origin_x + start, origin_y)
		_sprite.region_rect = Rect2(0.0, 0.0, ceilf(width / tex_w + 1.0) * tex_w, tex_h)
	else:
		# Single wide image: centred when the camera is at centre_x, drifting
		# by scroll_factor either side.
		position = Vector2(centre.x - tex_w * 0.5 + (centre_x - centre.x) * scroll_factor.x, origin_y)
		_sprite.region_rect = Rect2(0.0, 0.0, tex_w, tex_h)
	_fill.position = Vector2(left - position.x, tex_h - 2.0)
	_fill.size = Vector2(width, 2000.0)
