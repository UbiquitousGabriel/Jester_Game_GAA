extends CanvasLayer
## Prototype HUD: chain counter, speed readout and a controls reminder.
## Built in code so the graybox has no theme or font dependencies yet.

const GOLD := Color(0.98, 0.76, 0.22)
const CREAM := Color(0.97, 0.93, 0.84)
const INK := Color(0.14, 0.08, 0.2)

const HEART: Texture2D = preload("res://assets/environments/pack/heart.png")
const HELP_TEXT := (
	"Move A/D   Jump Space   Dash Shift   Restart R\n"
	+ "Light J: swing  (air: 3-hit combo,  W: upswing,  S in air: pogo)\n"
	+ "Heavy K: hold to charge  (S on ground: vault)\n"
	+ "Jump again in the air: hammer twirl glide"
)

@export var player_path: NodePath

var _player: Player = null
var _chain_label: Label = null
var _info_label: Label = null
var _hearts: HBoxContainer = null


func _ready() -> void:
	if not player_path.is_empty():
		_player = get_node_or_null(player_path) as Player

	_hearts = HBoxContainer.new()
	_hearts.add_theme_constant_override(&"separation", 6)
	_hearts.position = Vector2(32.0, 26.0)
	add_child(_hearts)

	var help := _make_label(22, CREAM)
	help.text = HELP_TEXT
	help.position = Vector2(34.0, 96.0)
	help.modulate.a = 0.85

	_info_label = _make_label(28, CREAM)
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_info_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_info_label.set_anchors_and_offsets_preset(
		Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 32
	)

	_chain_label = _make_label(84, GOLD)
	_chain_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_chain_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_chain_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_chain_label.set_anchors_and_offsets_preset(
		Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 48
	)
	_chain_label.visible = false

	ComboTracker.chain_changed.connect(_on_chain_changed)
	if _player != null:
		_player.health_changed.connect(_on_health_changed)
		_on_health_changed(_player.health, _player.max_health)


func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	_info_label.text = "Speed %d\nBest chain x%d" % [
		int(_player.velocity.length()), ComboTracker.best_chain
	]
	if _chain_label.visible:
		_chain_label.modulate.a = 0.35 + 0.65 * ComboTracker.get_time_ratio()


func _make_label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", color)
	label.add_theme_color_override(&"font_outline_color", INK)
	label.add_theme_constant_override(&"outline_size", 10)
	add_child(label)
	return label


func _on_chain_changed(count: int) -> void:
	_chain_label.visible = count >= 2
	_chain_label.text = "x%d CHAIN!" % count


func _on_health_changed(health: int, max_health: int) -> void:
	while _hearts.get_child_count() < max_health:
		var heart := TextureRect.new()
		heart.texture = HEART
		heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		heart.custom_minimum_size = Vector2(56.0, 54.0)
		heart.pivot_offset = Vector2(28.0, 27.0)
		_hearts.add_child(heart)
	for i: int in _hearts.get_child_count():
		var heart := _hearts.get_child(i) as TextureRect
		var full := i < health
		var was_full := heart.modulate.a > 0.5
		heart.modulate = Color.WHITE if full else Color(0.25, 0.15, 0.3, 0.45)
		if was_full and not full:
			heart.scale = Vector2(1.5, 1.5)
			heart.create_tween().tween_property(heart, "scale", Vector2.ONE, 0.25)
