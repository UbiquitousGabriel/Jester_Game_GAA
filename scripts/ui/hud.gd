extends CanvasLayer
## Prototype HUD: chain counter, speed readout and a controls reminder.
## Built in code so the graybox has no theme or font dependencies yet.

const GOLD := Color(0.98, 0.76, 0.22)
const CREAM := Color(0.97, 0.93, 0.84)
const INK := Color(0.14, 0.08, 0.2)

const HELP_TEXT := (
	"Move  A/D        Jump  Space        Dash  Shift\n"
	+ "Light  J  (hold W: upswing,  hold S in air: pogo)\n"
	+ "Heavy  K  (hold to charge,  hold S on ground: vault)\n"
	+ "Restart  R"
)

@export var player_path: NodePath

var _player: Player = null
var _chain_label: Label = null
var _info_label: Label = null


func _ready() -> void:
	if not player_path.is_empty():
		_player = get_node_or_null(player_path) as Player

	var help := _make_label(28, CREAM)
	help.text = HELP_TEXT
	help.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, 32)

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
