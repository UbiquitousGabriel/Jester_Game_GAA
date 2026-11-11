extends CanvasLayer
## Autoload. Every overlay the game shows: fades, toasts, area titles, the
## boss bar, dialogue, item cards, shrine and shop menus, pause, map,
## settings, the intro and the ending. Built in code with one shared theme.
##
## Modal screens pause the tree; Ui itself always processes. `is_busy()` is
## true while any modal is open so gameplay input ignores the same presses.

signal closed

const GOLD := Color(0.98, 0.76, 0.22)
const CREAM := Color(0.97, 0.93, 0.84)
const INK := Color(0.1, 0.05, 0.13)
const PANEL := Color(0.16, 0.09, 0.22, 0.94)
const RED := Color(0.86, 0.22, 0.3)
const SETTINGS_PATH := "user://settings.cfg"
const TITLE_SCENE := "res://scenes/ui/title_screen.tscn"

const AREA_COLORS := {
	"carnival_gate": Color(0.92, 0.36, 0.5),
	"outer_walls": Color(0.45, 0.55, 0.85),
	"royal_gardens": Color(0.42, 0.75, 0.4),
	"grand_halls": Color(0.9, 0.7, 0.35),
	"clockworks": Color(0.85, 0.5, 0.25),
	"throne_spire": Color(0.65, 0.4, 0.9),
}

## Charms each area's shop sells.
const SHOP_STOCK := {
	"carnival_gate": [&"rubber_nose", &"spring_heels"],
	"outer_walls": [&"lucky_bell", &"cartwheel"],
	"royal_gardens": [&"juggler_gloves", &"pratfall"],
	"grand_halls": [&"thick_skull", &"heavy_head"],
	"clockworks": [&"encore"],
	"throne_spire": [],
}

var ui_theme: Theme
var settings := {"music": 0.7, "sfx": 0.85, "shake": 1.0, "fullscreen": false}
## The Game sets this so pause and map open from gameplay.
var in_game: bool = false
## The Game sets this for the map's "you are here".
var current_room: String = ""
var player_position: Vector2 = Vector2.ZERO

var _modal: Control = null
var _modal_age: float = 0.0
var _unpause_pending: bool = false
var _fade: ColorRect
var _toasts: VBoxContainer
var _area_box: VBoxContainer
var _area_name: Label
var _area_sub: Label
var _boss_box: Control
var _boss_name: Label
var _boss_fill: ColorRect
var _boss_lag: ColorRect
var _boss_ratio: float = 1.0
var _banner: Label


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	ui_theme = _make_theme()
	_build_hud_overlays()
	_load_settings()


func _process(delta: float) -> void:
	_modal_age += delta
	if _boss_box.visible:
		var w := _boss_box.size.x - 8.0
		_boss_fill.size.x = w * _boss_ratio
		_boss_lag.size.x = move_toward(_boss_lag.size.x, w * _boss_ratio, delta * 220.0)


func _unhandled_input(event: InputEvent) -> void:
	if not in_game or _modal != null or _unpause_pending:
		return
	if event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		open_pause()
	elif event.is_action_pressed(&"map"):
		get_viewport().set_input_as_handled()
		open_map(false)


func is_busy() -> bool:
	return _modal != null or _unpause_pending


# --- Lightweight overlays -------------------------------------------------------------


func toast(text: String, color: Color = CREAM) -> void:
	var label := _label(text, 26, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toasts.add_child(label)
	label.modulate.a = 0.0
	var tween := label.create_tween()
	tween.tween_property(label, "modulate:a", 1.0, 0.15)
	tween.tween_interval(2.6)
	tween.tween_property(label, "modulate:a", 0.0, 0.4)
	tween.tween_callback(label.queue_free)


func area_title(area_name: String, subtitle: String) -> void:
	_area_name.text = area_name
	_area_sub.text = subtitle
	_area_box.modulate.a = 0.0
	_area_box.visible = true
	var tween := _area_box.create_tween()
	tween.tween_property(_area_box, "modulate:a", 1.0, 0.6)
	tween.tween_interval(2.4)
	tween.tween_property(_area_box, "modulate:a", 0.0, 0.9)


## Big centre banner ("DEFEATED", "CHAIN x20").
func banner(text: String, color: Color = GOLD) -> void:
	_banner.text = text
	_banner.add_theme_color_override(&"font_color", color)
	_banner.visible = true
	_banner.pivot_offset = _banner.size * 0.5
	_banner.scale = Vector2(1.6, 1.6)
	_banner.modulate.a = 1.0
	var tween := _banner.create_tween()
	tween.tween_property(_banner, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(1.4)
	tween.tween_property(_banner, "modulate:a", 0.0, 0.5)


func boss_bar_show(boss_name: String) -> void:
	_boss_name.text = boss_name
	_boss_ratio = 1.0
	_boss_box.visible = true
	_boss_box.modulate.a = 0.0
	_boss_box.create_tween().tween_property(_boss_box, "modulate:a", 1.0, 0.5)
	await get_tree().process_frame
	_boss_lag.size.x = _boss_box.size.x - 8.0


func boss_bar_set(ratio: float) -> void:
	_boss_ratio = clampf(ratio, 0.0, 1.0)


func boss_bar_hide() -> void:
	_boss_box.visible = false


func fade_out(time: float = 0.25) -> void:
	_fade.visible = true
	var tween := _fade.create_tween()
	tween.tween_property(_fade, "color:a", 1.0, time)
	await tween.finished


func fade_in(time: float = 0.3) -> void:
	var tween := _fade.create_tween()
	tween.tween_property(_fade, "color:a", 0.0, time)
	await tween.finished
	_fade.visible = _fade.color.a > 0.01


func set_black(on: bool) -> void:
	_fade.visible = on
	_fade.color.a = 1.0 if on else 0.0


# --- Modal plumbing ---------------------------------------------------------------------


func _open(panel: Control) -> void:
	if _modal != null:
		_modal.queue_free()
	_modal = panel
	_modal_age = 0.0
	add_child(panel)
	get_tree().paused = true


func _close() -> void:
	if _modal != null:
		_modal.queue_free()
	_modal = null
	# Unpause a beat later so the closing press does not also jump or swing.
	_unpause_pending = true
	await get_tree().create_timer(0.09, true, false, true).timeout
	_unpause_pending = false
	if _modal == null:
		get_tree().paused = false
	closed.emit()


func _accept_pressed(event: InputEvent) -> bool:
	if _modal_age < 0.18:
		return false
	for action: StringName in [&"ui_accept", &"jump", &"interact", &"attack_light"]:
		if event.is_action_pressed(action):
			return true
	return false


# --- Dialogue and cards -----------------------------------------------------------------


## Lines shown one at a time. Await `closed` to continue after it.
func dialog(lines: Array, speaker: String = "") -> void:
	var root := _ModalInput.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = ui_theme
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.custom_minimum_size = Vector2(1200.0, 220.0)
	panel.position = Vector2(-600.0, -280.0)
	root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 10)
	panel.add_child(box)
	if speaker != "":
		box.add_child(_label(speaker, 26, GOLD))
	var text := _label("", 30, CREAM)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(1140.0, 0.0)
	text.visible_ratio = 0.0
	box.add_child(text)
	var hint := _label("▼", 22, GOLD)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(hint)
	var state := {"index": 0}
	text.text = String(lines[0])
	root.set(&"handler", func(event: InputEvent) -> void:
		if not _accept_pressed(event):
			return
		if text.visible_ratio < 1.0:
			text.visible_ratio = 1.0
			return
		state["index"] += 1
		if state["index"] >= lines.size():
			_close()
			return
		Audio.sfx(&"talk", 0.1, -6.0)
		text.text = String(lines[state["index"]])
		text.visible_ratio = 0.0
		_modal_age = 0.1)
	root.set(&"tick", func(delta: float) -> void:
		if text.visible_ratio < 1.0:
			text.visible_ratio = minf(text.visible_ratio + delta * 60.0 / maxf(float(text.text.length()), 1.0), 1.0)
		hint.modulate.a = 0.5 + 0.5 * sin(_modal_age * 6.0))
	_open(root)


## Centred card for pickups: title, text, dismiss.
func item_popup(title: String, text: String, color: Color = GOLD) -> void:
	var root := _card(title, text, color, "Continue")
	Audio.sfx(&"fanfare_small")
	_open(root)


## Ability unlock: unlock, save, and explain the new move.
func ability_get(ability: StringName) -> void:
	var info: Dictionary = GameState.ABILITIES[ability]
	GameState.unlock(ability)
	GameState.save()
	GameFeel.shake(10.0)
	Audio.sfx(&"fanfare")
	var root := _card("NEW TRICK: " + String(info["name"]).to_upper(), String(info["text"]), GOLD, "Got it")
	_open(root)


func _card(title: String, text: String, color: Color, button_text: String) -> _ModalInput:
	var root := _dim_root()
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(980.0, 0.0)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(centre)
	centre.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 22)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)
	var t := _label(title, 46, color)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	var body := _label(text, 30, CREAM)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.custom_minimum_size = Vector2(900.0, 0.0)
	box.add_child(body)
	var button := Button.new()
	button.text = button_text
	button.custom_minimum_size = Vector2(260.0, 60.0)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(func() -> void: if _modal_age > 0.3: _close())
	box.add_child(button)
	panel.scale = Vector2(0.8, 0.8)
	panel.pivot_offset = Vector2(490.0, 150.0)
	panel.create_tween().tween_property(panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	button.call_deferred(&"grab_focus")
	return root


# --- Shrine: rest and charms ------------------------------------------------------------


func shrine_menu() -> void:
	var root := _dim_root()
	var panel := _menu_panel(root, "SHRINE OF THE GRIN", "Rested. Progress saved. Equip up to %d charms." % GameState.CHARM_SLOTS)
	var list: VBoxContainer = panel.get_meta(&"list")
	var info: Label = panel.get_meta(&"info")
	if GameState.charms_owned.is_empty():
		list.add_child(_label("You own no charms yet. Pippet sells them for bells.", 26, CREAM))
	for id: StringName in GameState.CHARMS:
		if not GameState.charms_owned.get(id, false):
			continue
		var data: Dictionary = GameState.CHARMS[id]
		var button := Button.new()
		button.toggle_mode = true
		button.button_pressed = GameState.has_charm(id)
		button.text = String(data["name"])
		button.custom_minimum_size = Vector2(520.0, 54.0)
		button.focus_entered.connect(func() -> void: info.text = String(data["text"]))
		button.toggled.connect(func(on: bool) -> void:
			if on != GameState.has_charm(id):
				if not GameState.toggle_charm(id):
					button.set_pressed_no_signal(false)
					Audio.sfx(&"deny")
					info.text = "All %d charm slots are full." % GameState.CHARM_SLOTS
					return
				Audio.sfx(&"equip")
				GameState.save()
				var player := get_tree().get_first_node_in_group(&"player") as Player
				if player:
					player.refresh_max_health())
		list.add_child(button)
	_add_close_button(list, "Leave")
	_open(root)
	_focus_first(list)


# --- Shop -------------------------------------------------------------------------------


func shop(area: String) -> void:
	var root := _dim_root()
	var panel := _menu_panel(root, "PIPPET'S CART", "\"Bells for baubles, friend. No refunds, no returns, no regrets.\"")
	var list: VBoxContainer = panel.get_meta(&"list")
	var info: Label = panel.get_meta(&"info")
	var wallet := _label("", 28, GOLD)
	list.add_child(wallet)
	var refresh := func() -> void: wallet.text = "Bells: %d" % GameState.bells
	refresh.call()
	var stock: Array = SHOP_STOCK.get(area, [])
	var any := false
	for id: StringName in stock:
		var data: Dictionary = GameState.CHARMS[id]
		var price := int(data["price"])
		var button := Button.new()
		button.custom_minimum_size = Vector2(620.0, 54.0)
		var owned: bool = GameState.charms_owned.get(id, false)
		button.text = "%s   —   %s" % [data["name"], "SOLD" if owned else "%d bells" % price]
		button.disabled = owned
		button.focus_entered.connect(func() -> void: info.text = String(data["text"]))
		button.pressed.connect(func() -> void:
			if GameState.bells < price:
				Audio.sfx(&"deny")
				info.text = "\"You're %d bells short, friend.\"" % (price - GameState.bells)
				return
			GameState.add_bells(-price)
			GameState.charms_owned[id] = true
			if GameState.charms_equipped.size() < GameState.CHARM_SLOTS:
				GameState.charms_equipped.append(id)
			GameState.save()
			Audio.sfx(&"buy")
			button.text = "%s   —   SOLD" % data["name"]
			button.disabled = true
			info.text = "Equipped! Swap charms at any shrine."
			refresh.call())
		list.add_child(button)
		any = true
	if not any:
		list.add_child(_label("\"Sold out up here. Even I don't climb this high.\"", 26, CREAM))
	_add_close_button(list, "Leave")
	_open(root)
	_focus_first(list)


# --- Pause, map, settings -----------------------------------------------------------------


func open_pause() -> void:
	var root := _dim_root()
	var panel := _menu_panel(root, "PAUSED", _stats_line())
	var list: VBoxContainer = panel.get_meta(&"list")
	_button(list, "Resume", func() -> void: _close())
	_button(list, "Map", func() -> void: open_map(true))
	_button(list, "Charms & Tricks", func() -> void: _open_collection())
	_button(list, "Settings", func() -> void: open_settings(true))
	_button(list, "Save & Quit to Title", func() -> void: quit_to_title())
	Audio.sfx(&"page", 0.0, -4.0)
	_open(root)
	_focus_first(list)
	root.set(&"handler", func(event: InputEvent) -> void:
		if event.is_action_pressed(&"pause") and _modal_age > 0.2:
			_close())


func quit_to_title() -> void:
	if GameState.playing:
		GameState.save()
	GameState.playing = false
	in_game = false
	boss_bar_hide()
	if _modal != null:
		_modal.queue_free()
		_modal = null
	await fade_out(0.4)
	get_tree().paused = false
	Audio.music(&"title")
	get_tree().change_scene_to_file(TITLE_SCENE)
	await get_tree().process_frame
	await get_tree().process_frame
	fade_in(0.5)


func _stats_line() -> String:
	var t := int(GameState.play_time)
	return "%d:%02d:%02d played   ·   %d%% complete   ·   %d bells   ·   %d / %d jokes" % [
		t / 3600, (t / 60) % 60, t % 60, int(GameState.completion_percent()), GameState.bells,
		GameState.jokes.size(), WorldData.JOKE_COUNT]


func _open_collection() -> void:
	var root := _dim_root()
	var panel := _menu_panel(root, "CHARMS & TRICKS", "")
	var list: VBoxContainer = panel.get_meta(&"list")
	var info: Label = panel.get_meta(&"info")
	for id: StringName in GameState.ABILITIES:
		var data: Dictionary = GameState.ABILITIES[id]
		var got := GameState.has(id)
		var b := _button(list, ("★ " if got else "· ") + (String(data["name"]) if got else "???"), func() -> void: pass)
		b.focus_entered.connect(func() -> void: info.text = String(data["text"]) if got else "Defeat %s." % GameState.BOSSES[data["boss"]])
	for id: StringName in GameState.CHARMS:
		var data: Dictionary = GameState.CHARMS[id]
		var owned: bool = GameState.charms_owned.get(id, false)
		var mark := "◆ " if GameState.has_charm(id) else ("◇ " if owned else "· ")
		var b := _button(list, mark + (String(data["name"]) if owned else "???"), func() -> void: pass)
		b.focus_entered.connect(func() -> void: info.text = String(data["text"]) if owned else "Sold somewhere in the castle.")
	_add_close_button(list, "Back", func() -> void: open_pause())
	_open(root)
	_focus_first(list)


func open_map(from_pause: bool) -> void:
	var root := _dim_root()
	var view := _MapView.new()
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	view.offset_left = 80.0
	view.offset_top = 120.0
	view.offset_right = -80.0
	view.offset_bottom = -110.0
	view.current_room = current_room
	view.player_position = player_position
	root.add_child(view)
	var title := _label("MAP OF THE COURT", 40, GOLD)
	title.position = Vector2(80.0, 40.0)
	root.add_child(title)
	var legend := _label("+ shrine   $ shop   B boss   ? friend   ●  you      [M / Esc] close", 22, CREAM)
	legend.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	legend.position = Vector2(80.0, -70.0)
	root.add_child(legend)
	root.set(&"handler", func(event: InputEvent) -> void:
		if _modal_age < 0.15:
			return
		if event.is_action_pressed(&"map") or event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel") \
				or event.is_action_pressed(&"interact"):
			if from_pause:
				open_pause()
			else:
				_close())
	Audio.sfx(&"page", 0.0, -4.0)
	_open(root)


func open_settings(from_pause: bool, on_close: Callable = Callable()) -> void:
	var root := _dim_root()
	var panel := _menu_panel(root, "SETTINGS", "")
	var list: VBoxContainer = panel.get_meta(&"list")
	_slider(list, "Music", "music")
	_slider(list, "Sound effects", "sfx")
	_slider(list, "Screen shake", "shake")
	var full := CheckButton.new()
	full.text = "Fullscreen"
	full.button_pressed = bool(settings["fullscreen"])
	full.toggled.connect(func(on: bool) -> void:
		settings["fullscreen"] = on
		_apply_settings()
		_save_settings())
	list.add_child(full)
	list.add_child(_label("Controls: A/D move · Space jump · J light · K heavy · Shift dash · E interact · M map · Esc pause\nGamepad: stick · A jump · X light · B heavy · RB dash · Y interact · Back map · Start pause", 20, CREAM))
	_add_close_button(list, "Back", func() -> void:
		if from_pause:
			open_pause()
		else:
			_close()
			if on_close.is_valid():
				on_close.call())
	_open(root)
	_focus_first(list)


func _slider(list: VBoxContainer, text: String, key: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 20)
	var label := _label(text, 26, CREAM)
	label.custom_minimum_size = Vector2(260.0, 0.0)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = float(settings[key])
	slider.custom_minimum_size = Vector2(380.0, 40.0)
	slider.value_changed.connect(func(v: float) -> void:
		settings[key] = v
		_apply_settings()
		if key == "sfx":
			Audio.sfx(&"bell", 0.0)
		_save_settings())
	row.add_child(slider)
	list.add_child(row)


# --- Intro and ending ---------------------------------------------------------------------


## Full-screen story cards. Await `closed`.
func story_cards(lines: Array, final_text: String = "") -> void:
	var root := _ModalInput.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = ui_theme
	var black := ColorRect.new()
	black.color = Color(0.03, 0.01, 0.05)
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(black)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(centre)
	var text := _label("", 40, CREAM)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.custom_minimum_size = Vector2(1300.0, 0.0)
	centre.add_child(text)
	var all := lines.duplicate()
	if final_text != "":
		all.append(final_text)
	var state := {"index": 0}
	var show := func() -> void:
		text.text = String(all[state["index"]])
		text.modulate.a = 0.0
		text.create_tween().tween_property(text, "modulate:a", 1.0, 0.8)
	show.call()
	root.set(&"handler", func(event: InputEvent) -> void:
		if not _accept_pressed(event) and not event.is_action_pressed(&"pause"):
			return
		if event.is_action_pressed(&"pause"):
			state["index"] = all.size()
		else:
			state["index"] += 1
		_modal_age = 0.0
		if state["index"] >= all.size():
			_close()
			return
		Audio.sfx(&"page", 0.0, -8.0)
		show.call())
	_open(root)


func ending() -> void:
	in_game = false
	GameState.flags["complete"] = true
	GameState.save()
	Audio.music(&"ending", 3.0)
	await fade_out(1.5)
	var t := int(GameState.play_time)
	var stats := "THE END\n\nTime  %d:%02d:%02d\nFalls  %d\nCompletion  %d%%\nJokes found  %d / %d\n\nThank you for playing The Jester's Court." % [
		t / 3600, (t / 60) % 60, t % 60, GameState.deaths, int(GameState.completion_percent()),
		GameState.jokes.size(), WorldData.JOKE_COUNT]
	story_cards(Story.ENDING, stats)
	await get_tree().process_frame
	set_black(false)
	await closed
	quit_to_title()


# --- Building blocks ----------------------------------------------------------------------


func _dim_root() -> _ModalInput:
	var root := _ModalInput.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = ui_theme
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.02, 0.07, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	return root


func _menu_panel(root: Control, title: String, subtitle: String) -> PanelContainer:
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(centre)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(900.0, 0.0)
	centre.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 14)
	panel.add_child(box)
	var t := _label(title, 44, GOLD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	var info := _label(subtitle, 24, CREAM)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.custom_minimum_size = Vector2(840.0, 60.0)
	box.add_child(info)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(840.0, 0.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override(&"separation", 8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.alignment = BoxContainer.ALIGNMENT_CENTER
	scroll.add_child(list)
	list.resized.connect(func() -> void: scroll.custom_minimum_size.y = minf(list.size.y, 620.0))
	panel.set_meta(&"list", list)
	panel.set_meta(&"info", info)
	return panel


func _button(list: VBoxContainer, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(520.0, 54.0)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(func() -> void:
		if _modal_age > 0.15:
			Audio.sfx(&"click", 0.0, -6.0)
			action.call())
	button.focus_entered.connect(func() -> void: Audio.sfx(&"tick", 0.0, -12.0))
	list.add_child(button)
	return button


func _add_close_button(list: VBoxContainer, text: String, action: Callable = Callable()) -> void:
	_button(list, text, func() -> void:
		if action.is_valid():
			action.call()
		else:
			_close())


func _focus_first(list: Control) -> void:
	for child: Node in list.get_children():
		var c := child as Control
		if c != null and c.focus_mode != Control.FOCUS_NONE and (not c is BaseButton or not (c as BaseButton).disabled):
			c.call_deferred(&"grab_focus")
			return
		if child.get_child_count() > 0:
			for sub: Node in child.get_children():
				var s := sub as Control
				if s != null and s.focus_mode != Control.FOCUS_NONE:
					s.call_deferred(&"grab_focus")
					return


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", color)
	label.add_theme_color_override(&"font_outline_color", INK)
	label.add_theme_constant_override(&"outline_size", 8)
	return label


func _build_hud_overlays() -> void:
	_toasts = VBoxContainer.new()
	_toasts.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toasts.position = Vector2(-500.0, 150.0)
	_toasts.custom_minimum_size = Vector2(1000.0, 0.0)
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toasts)

	_area_box = VBoxContainer.new()
	_area_box.set_anchors_preset(Control.PRESET_CENTER)
	_area_box.position = Vector2(-700.0, -260.0)
	_area_box.custom_minimum_size = Vector2(1400.0, 0.0)
	_area_box.visible = false
	_area_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_area_box)
	_area_name = _label("", 84, GOLD)
	_area_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_area_name.add_theme_constant_override(&"outline_size", 18)
	_area_box.add_child(_area_name)
	_area_sub = _label("", 32, CREAM)
	_area_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_area_box.add_child(_area_sub)

	_banner = _label("", 110, GOLD)
	_banner.add_theme_constant_override(&"outline_size", 22)
	_banner.set_anchors_preset(Control.PRESET_CENTER)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.position = Vector2(-700.0, -100.0)
	_banner.custom_minimum_size = Vector2(1400.0, 0.0)
	_banner.visible = false
	add_child(_banner)

	_boss_box = Control.new()
	_boss_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_boss_box.position = Vector2(-640.0, -110.0)
	_boss_box.size = Vector2(1280.0, 34.0)
	_boss_box.visible = false
	add_child(_boss_box)
	var back := ColorRect.new()
	back.color = INK
	back.size = Vector2(1280.0, 34.0)
	_boss_box.add_child(back)
	_boss_lag = ColorRect.new()
	_boss_lag.color = Color(1.0, 0.95, 0.8)
	_boss_lag.position = Vector2(4.0, 4.0)
	_boss_lag.size = Vector2(1272.0, 26.0)
	_boss_box.add_child(_boss_lag)
	_boss_fill = ColorRect.new()
	_boss_fill.color = RED
	_boss_fill.position = Vector2(4.0, 4.0)
	_boss_fill.size = Vector2(1272.0, 26.0)
	_boss_box.add_child(_boss_fill)
	_boss_name = _label("", 34, CREAM)
	_boss_name.position = Vector2(0.0, -48.0)
	_boss_box.add_child(_boss_name)

	_fade = ColorRect.new()
	_fade.color = Color(0.02, 0.01, 0.04, 0.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.visible = false
	_fade.z_index = 100
	add_child(_fade)


func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 28
	var panel := StyleBoxFlat.new()
	panel.bg_color = PANEL
	panel.border_color = GOLD
	panel.set_border_width_all(4)
	panel.set_corner_radius_all(18)
	panel.set_content_margin_all(34.0)
	panel.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	panel.shadow_size = 18
	t.set_stylebox(&"panel", &"PanelContainer", panel)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.26, 0.15, 0.34)
	normal.set_corner_radius_all(12)
	normal.set_content_margin_all(10.0)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.42, 0.22, 0.48)
	var focus := normal.duplicate() as StyleBoxFlat
	focus.bg_color = Color(0.5, 0.26, 0.5)
	focus.border_color = GOLD
	focus.set_border_width_all(3)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.62, 0.36, 0.2)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.18, 0.12, 0.22)
	for cls: StringName in [&"Button", &"CheckButton"]:
		t.set_stylebox(&"normal", cls, normal)
		t.set_stylebox(&"hover", cls, hover)
		t.set_stylebox(&"focus", cls, focus)
		t.set_stylebox(&"pressed", cls, pressed)
		t.set_stylebox(&"hover_pressed", cls, pressed)
		t.set_stylebox(&"disabled", cls, disabled)
		t.set_color(&"font_color", cls, CREAM)
		t.set_color(&"font_focus_color", cls, Color.WHITE)
		t.set_color(&"font_hover_color", cls, Color.WHITE)
		t.set_color(&"font_pressed_color", cls, GOLD)
		t.set_color(&"font_hover_pressed_color", cls, GOLD)
		t.set_color(&"font_disabled_color", cls, Color(0.6, 0.55, 0.6))
	return t


# --- Settings -----------------------------------------------------------------------------


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		for key: String in settings:
			settings[key] = cfg.get_value("settings", key, settings[key])
	_apply_settings()


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	for key: String in settings:
		cfg.set_value("settings", key, settings[key])
	cfg.save(SETTINGS_PATH)


func _apply_settings() -> void:
	Audio.set_volume(&"Music", float(settings["music"]))
	Audio.set_volume(&"Ambience", float(settings["music"]))
	Audio.set_volume(&"SFX", float(settings["sfx"]))
	GameFeel.shake_scale = float(settings["shake"])
	if DisplayServer.get_name() != "headless":
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if settings["fullscreen"] else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode:
			DisplayServer.window_set_mode(mode)


# --- Inner classes ------------------------------------------------------------------------


## A Control whose input and per-frame work are given as callables.
class _ModalInput extends Control:
	var handler: Callable
	var tick: Callable

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _input(event: InputEvent) -> void:
		if handler.is_valid() and not event is InputEventMouseMotion:
			handler.call(event)

	func _process(delta: float) -> void:
		if tick.is_valid():
			tick.call(delta)


## Draws the explored castle.
class _MapView extends Control:
	var current_room: String = ""
	var player_position: Vector2 = Vector2.ZERO
	var _time: float = 0.0

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _draw() -> void:
		var min_c := Vector2(1e9, 1e9)
		var max_c := Vector2(-1e9, -1e9)
		for id: String in WorldData.ROOMS:
			var d: Dictionary = WorldData.ROOMS[id]
			var o := Vector2(float(d["origin"][0]), float(d["origin"][1]))
			var s := Vector2(float(d["size"][0]), float(d["size"][1]))
			min_c = min_c.min(o)
			max_c = max_c.max(o + s)
		var span := max_c - min_c
		var cell := minf(size.x / span.x, size.y / (span.y * 0.56))
		var cell_size := Vector2(cell, cell * 0.56)
		var offset := (size - span * cell_size) * 0.5
		var known: Dictionary[String, bool] = {}
		for id: String in GameState.visited:
			known[id] = true
			if WorldData.ROOMS.has(id):
				for door: Array in WorldData.ROOMS[id]["doors"]:
					if not known.has(String(door[2])):
						known[String(door[2])] = false
		var font := ThemeDB.fallback_font
		for id: String in known:
			if not WorldData.ROOMS.has(id):
				continue
			var d: Dictionary = WorldData.ROOMS[id]
			var o := (Vector2(float(d["origin"][0]), float(d["origin"][1])) - min_c) * cell_size + offset
			var s := Vector2(float(d["size"][0]), float(d["size"][1])) * cell_size
			var r := Rect2(o, s).grow(-3.0)
			var color: Color = AREA_COLORS.get(String(d["area"]), Color.GRAY)
			if known[id]:
				draw_rect(r, color.darkened(0.35))
				draw_rect(r, color.lightened(0.2), false, 3.0)
				var mark := ""
				match String(d["kind"]):
					"shrine": mark = "+"
					"shop": mark = "$"
					"boss": mark = "B" if not _boss_done(d) else ""
					"npc": mark = "?"
				for e: Array in d["entities"]:
					if String(e[0]) == "heart" and not GameState.is_picked(String(e[3]["id"])):
						mark += "♥"
				if mark != "":
					draw_string_outline(font, r.get_center() + Vector2(-10.0, 8.0), mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 6, INK)
					draw_string(font, r.get_center() + Vector2(-10.0, 8.0), mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, CREAM)
			else:
				draw_rect(r, Color(color, 0.35), false, 2.0)
		if WorldData.ROOMS.has(current_room):
			var world_cell := player_position / Vector2(WorldData.CELL * WorldData.TILE)
			var p := (world_cell - min_c) * cell_size + offset
			var pulse := 7.0 + 3.0 * sin(_time * 6.0)
			draw_circle(p, pulse + 3.0, INK)
			draw_circle(p, pulse, Color(1.0, 0.95, 0.5))

	func _boss_done(d: Dictionary) -> bool:
		for e: Array in d["entities"]:
			if String(e[0]) == "boss":
				return GameState.boss_defeated(StringName(e[3]["id"]))
		return false
