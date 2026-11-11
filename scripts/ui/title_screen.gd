extends Control
## Title screen: three save slots, settings and quit, over the carnival sky.

const GAME_SCENE := "res://scenes/game/game.tscn"
const SKY: Texture2D = preload("res://assets/environments/carnival_gate/sky.png")
const CASTLE: Texture2D = preload("res://assets/environments/carnival_gate/castle_far.png")
const CARNIVAL: Texture2D = preload("res://assets/environments/carnival_gate/carnival_near.png")

var _list: VBoxContainer
var _time: float = 0.0
var _castle: TextureRect
var _title: Label


func _ready() -> void:
	theme = Ui.ui_theme
	Ui.in_game = false
	GameState.playing = false
	get_tree().paused = false
	Engine.time_scale = 1.0
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var sky := TextureRect.new()
	sky.texture = SKY
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(sky)
	_castle = TextureRect.new()
	_castle.texture = CASTLE
	_castle.set_anchors_preset(Control.PRESET_FULL_RECT)
	_castle.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_castle.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_castle.modulate = Color(0.8, 0.75, 0.95)
	add_child(_castle)
	var near := TextureRect.new()
	near.texture = CARNIVAL
	near.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	near.custom_minimum_size = Vector2(0.0, 520.0)
	near.position.y = -520.0
	near.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	near.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(near)
	var shade := ColorRect.new()
	shade.color = Color(0.05, 0.02, 0.08, 0.35)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	_title = Label.new()
	_title.text = "The Jester's Court"
	_title.add_theme_font_size_override(&"font_size", 120)
	_title.add_theme_color_override(&"font_color", Ui.GOLD)
	_title.add_theme_color_override(&"font_outline_color", Ui.INK)
	_title.add_theme_constant_override(&"outline_size", 26)
	_title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.position = Vector2(-800.0, 90.0)
	_title.custom_minimum_size = Vector2(1600.0, 0.0)
	add_child(_title)
	var sub := Label.new()
	sub.text = "One last joke. The punchline is upstairs."
	sub.add_theme_font_size_override(&"font_size", 32)
	sub.add_theme_color_override(&"font_color", Ui.CREAM)
	sub.add_theme_color_override(&"font_outline_color", Ui.INK)
	sub.add_theme_constant_override(&"outline_size", 10)
	sub.set_anchors_preset(Control.PRESET_CENTER_TOP)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position = Vector2(-800.0, 250.0)
	sub.custom_minimum_size = Vector2(1600.0, 0.0)
	add_child(sub)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.offset_top = 260.0
	add_child(centre)
	var panel := PanelContainer.new()
	centre.add_child(panel)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override(&"separation", 12)
	panel.add_child(_list)
	_build_menu()
	Audio.music(&"title", 1.0)


func _process(delta: float) -> void:
	_time += delta
	_castle.position.x = sin(_time * 0.1) * 20.0
	_title.rotation = sin(_time * 1.3) * 0.012
	_title.pivot_offset = _title.size * 0.5


func _build_menu() -> void:
	for child: Node in _list.get_children():
		child.queue_free()
	for slot: int in GameState.SLOTS:
		var data := GameState.peek(slot)
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 10)
		var button := Button.new()
		button.custom_minimum_size = Vector2(640.0, 64.0)
		if data.is_empty():
			button.text = "Slot %d   —   New Game" % (slot + 1)
		else:
			var t := int(float(data.get("play_time", 0.0)))
			var area := String(WorldData.ROOMS.get(String(data.get("shrine_room", "")), {}).get("area", "carnival_gate"))
			button.text = "Slot %d   —   %s   %d:%02d" % [slot + 1, WorldData.AREAS[area]["name"], t / 3600, (t / 60) % 60]
			if data.get("flags", []).has("complete"):
				button.text += "   ★"
		button.pressed.connect(_start.bind(slot, data.is_empty()))
		button.focus_entered.connect(func() -> void: Audio.sfx(&"tick", 0.0, -12.0))
		row.add_child(button)
		if not data.is_empty():
			var erase := Button.new()
			erase.text = "Erase"
			erase.custom_minimum_size = Vector2(130.0, 64.0)
			erase.pressed.connect(_erase.bind(slot, erase))
			row.add_child(erase)
		_list.add_child(row)
	var yard := Button.new()
	yard.text = "Training Yard"
	yard.custom_minimum_size = Vector2(640.0, 56.0)
	yard.pressed.connect(func() -> void:
		await Ui.fade_out(0.4)
		get_tree().change_scene_to_file("res://scenes/levels/movement_playground.tscn")
		await get_tree().process_frame
		Ui.fade_in(0.4))
	_list.add_child(yard)
	var settings := Button.new()
	settings.text = "Settings"
	settings.custom_minimum_size = Vector2(640.0, 56.0)
	settings.pressed.connect(func() -> void: Ui.open_settings(false, _refocus))
	_list.add_child(settings)
	var quit := Button.new()
	quit.text = "Quit"
	quit.custom_minimum_size = Vector2(640.0, 56.0)
	quit.pressed.connect(func() -> void: get_tree().quit())
	_list.add_child(quit)
	_refocus.call_deferred()


func _refocus() -> void:
	var first := _list.get_child(0)
	if first != null and first.get_child_count() > 0:
		(first.get_child(0) as Control).grab_focus()


func _erase(slot: int, button: Button) -> void:
	if button.text != "Sure?":
		button.text = "Sure?"
		return
	GameState.erase_slot(slot)
	Audio.sfx(&"shatter")
	_build_menu()


func _start(slot: int, fresh: bool) -> void:
	Audio.sfx(&"click")
	if fresh:
		GameState.new_game(slot)
		GameState.save()
	else:
		GameState.load_slot(slot)
	await Ui.fade_out(0.5)
	get_tree().change_scene_to_file(GAME_SCENE)
