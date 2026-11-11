extends Node2D
## A small wooden notice board (procedural placeholder).

func _draw() -> void:
	var ink := Color(0.1, 0.05, 0.13)
	draw_rect(Rect2(-5.0, -70.0, 10.0, 70.0), ink)
	draw_rect(Rect2(-3.0, -70.0, 6.0, 70.0), Color(0.55, 0.35, 0.2))
	draw_rect(Rect2(-34.0, -100.0, 68.0, 44.0), ink)
	draw_rect(Rect2(-30.0, -96.0, 60.0, 36.0), Color(0.78, 0.55, 0.32))
	draw_string(ThemeDB.fallback_font, Vector2(-6.0, -68.0), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, ink)
