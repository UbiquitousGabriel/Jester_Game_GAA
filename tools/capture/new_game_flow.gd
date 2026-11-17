extends Node
## Plays the real new-game flow from the title screen with simulated input and
## takes screenshots, to catch problems the scripted tests skip.

var _out := "/tmp/flow"
var _n := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(_out)
	GameState.erase_slot(2)
	# Run the title as the current scene so its scene change frees it, not us.
	var title_scene: Node = (load("res://scenes/ui/title_screen.tscn") as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(title_scene)
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().current_scene = title_scene
	await _wait(1.5)
	await _shot("title")
	var title := get_tree().current_scene
	title.call(&"_start", 2, true)
	await _wait(2.0)
	await _shot("after_start")
	for i: int in 7:
		_press(&"jump")
		await _wait(1.2)
		await _shot("intro_%d" % i)
	await _wait(2.0)
	await _shot("in_game")
	for i: int in 30:
		_hold(&"move_right", true)
		await _wait(0.1)
	_hold(&"move_right", false)
	_press(&"jump")
	await _wait(0.6)
	await _shot("moved")
	_press(&"pause")
	await _wait(0.5)
	await _shot("pause")
	GameState.erase_slot(2)
	get_tree().quit()


func _press(action: StringName) -> void:
	_hold(action, true)
	await get_tree().create_timer(0.08, true, false, true).timeout
	_hold(action, false)


func _hold(action: StringName, down: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = down
	Input.parse_input_event(ev)


func _wait(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.resize(640, 360)
	_n += 1
	img.save_png("%s/%02d_%s.png" % [_out, _n, name])
	print("shot ", name, " scene=", get_tree().current_scene.name if get_tree().current_scene else "none", " paused=", get_tree().paused, " busy=", Ui.is_busy())
