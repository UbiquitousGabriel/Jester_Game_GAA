class_name Interactable
extends Area2D
## Something the Jester can use by standing near it and pressing Interact
## (E / Up on the ground / gamepad Y). Shows a bobbing prompt when in range.

@export var prompt: String = "Interact"
@export var radius: float = 90.0

var player_near: bool = false
var _prompt_label: Label
var _time: float = 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var shape := CircleShape2D.new()
	shape.radius = radius
	var cs := CollisionShape2D.new()
	cs.shape = shape
	cs.position = Vector2(0.0, -50.0)
	add_child(cs)
	body_entered.connect(func(b: Node2D) -> void: if b is Player: player_near = true)
	body_exited.connect(func(b: Node2D) -> void: if b is Player: player_near = false)
	_prompt_label = Label.new()
	_prompt_label.text = "[E] " + prompt
	_prompt_label.add_theme_font_size_override(&"font_size", 20)
	_prompt_label.add_theme_color_override(&"font_color", Color(1.0, 0.92, 0.6))
	_prompt_label.add_theme_color_override(&"font_outline_color", Color(0.1, 0.05, 0.13))
	_prompt_label.add_theme_constant_override(&"outline_size", 8)
	_prompt_label.z_index = 20
	_prompt_label.visible = false
	add_child(_prompt_label)
	_build()


## Subclasses add their visuals here.
func _build() -> void:
	pass


## Subclasses act here.
func interact(_player: Player) -> void:
	pass


func can_interact() -> bool:
	return true


func _process(delta: float) -> void:
	_time += delta
	var show := player_near and can_interact() and not Ui.is_busy()
	_prompt_label.visible = show
	if show:
		_prompt_label.position = Vector2(-_prompt_label.size.x * 0.5, -150.0 + sin(_time * 4.0) * 5.0)


func _physics_process(_delta: float) -> void:
	if not player_near or not can_interact() or Ui.is_busy() or get_tree().paused:
		return
	var pressed := Input.is_action_just_pressed(&"interact")
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player == null or player.is_dead():
		return
	if not pressed and Input.is_action_just_pressed(&"move_up") and player.is_on_floor():
		pressed = true
	if pressed:
		interact(player)
