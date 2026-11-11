class_name Game
extends Node2D
## The castle run: loads one room at a time from WorldData, moves between
## rooms through doors, handles pits, deaths and shrine respawns, starts and
## finishes boss fights, and sets each area's mood (light, sky, music).
##
## Rooms use world coordinates, so crossing a door never moves the Jester:
## the old room is freed and the neighbour is built where it already sits.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/ui/hud.tscn")
const SKY: Texture2D = preload("res://assets/environments/carnival_gate/sky.png")
const CASTLE: Texture2D = preload("res://assets/environments/carnival_gate/castle_far.png")
const CARNIVAL_FAR: Texture2D = preload("res://assets/environments/carnival_gate/carnival_far.png")
const WALL: Texture2D = preload("res://assets/environments/pack/tile_stone_dark.png")
const PACK := "res://assets/environments/pack/"

## Per-area mood. modulate: world darkness; sky: sky tint; wall: back-wall
## opacity (0 = open sky); motes: ambient particle colour; light: player light.
const MOOD := {
	"carnival_gate": {"modulate": Color(0.86, 0.8, 0.95), "sky": Color(1.0, 1.0, 1.0), "wall": 0.0,
		"wall_tint": Color(0.5, 0.35, 0.55), "motes": Color(1.0, 0.7, 0.45), "light": Color(1.0, 0.85, 0.65),
		"music": &"carnival_gate", "ambience": &"amb_wind"},
	"outer_walls": {"modulate": Color(0.66, 0.7, 0.9), "sky": Color(0.6, 0.68, 1.0), "wall": 0.55,
		"wall_tint": Color(0.42, 0.45, 0.62), "motes": Color(0.75, 0.85, 1.0), "light": Color(0.85, 0.9, 1.0),
		"music": &"outer_walls", "ambience": &"amb_wind"},
	"royal_gardens": {"modulate": Color(0.66, 0.82, 0.68), "sky": Color(0.62, 0.95, 0.7), "wall": 0.0,
		"wall_tint": Color(0.3, 0.45, 0.32), "motes": Color(0.7, 1.0, 0.6), "light": Color(0.9, 1.0, 0.8),
		"music": &"royal_gardens", "ambience": &"amb_garden"},
	"grand_halls": {"modulate": Color(0.62, 0.52, 0.5), "sky": Color(1.0, 0.8, 0.6), "wall": 1.0,
		"wall_tint": Color(0.62, 0.45, 0.4), "motes": Color(1.0, 0.85, 0.5), "light": Color(1.0, 0.82, 0.6),
		"music": &"grand_halls", "ambience": &"amb_halls"},
	"clockworks": {"modulate": Color(0.55, 0.42, 0.34), "sky": Color(1.0, 0.7, 0.45), "wall": 1.0,
		"wall_tint": Color(0.58, 0.4, 0.28), "motes": Color(1.0, 0.65, 0.3), "light": Color(1.0, 0.75, 0.5),
		"music": &"clockworks", "ambience": &"amb_gears"},
	"throne_spire": {"modulate": Color(0.56, 0.44, 0.7), "sky": Color(0.8, 0.55, 1.0), "wall": 0.75,
		"wall_tint": Color(0.45, 0.32, 0.6), "motes": Color(0.85, 0.6, 1.0), "light": Color(0.95, 0.8, 1.0),
		"music": &"throne_spire", "ambience": &"amb_wind"},
}

var room: Room = null
var player: Player
var camera: FollowCamera

var _world: Node2D
var _modulate: CanvasModulate
var _sky_rect: TextureRect
var _castle: ParallaxLayerNode
var _carnival: ParallaxLayerNode
var _motes: CPUParticles2D
var _player_light: PointLight2D
var _area: String = ""
var _cell_rooms: Dictionary[Vector2i, String] = {}
var _transitioning: bool = false
var _safe_position: Vector2 = Vector2.ZERO
var _full_death: bool = false
var _boss_active: bool = false
var _encore_used: bool = false
var _last_chain_banner: int = 0
var _new_game: bool = false


func _ready() -> void:
	GameState.playing = true
	for id: String in WorldData.ROOMS:
		var d: Dictionary = WorldData.ROOMS[id]
		for cx: int in int(d["size"][0]):
			for cy: int in int(d["size"][1]):
				_cell_rooms[Vector2i(int(d["origin"][0]) + cx, int(d["origin"][1]) + cy)] = id

	_build_backdrop()
	_world = Node2D.new()
	_world.name = "World"
	add_child(_world)
	_modulate = CanvasModulate.new()
	add_child(_modulate)

	player = PLAYER_SCENE.instantiate() as Player
	player.use_progression = true
	player.max_health = GameState.max_hearts()
	player.position = GameState.shrine_position
	add_child(player)
	player.refresh_max_health()
	player.heal_full()
	_player_light = LevelArt.add_light(player, Vector2(0.0, -50.0), Color(1.0, 0.85, 0.65), 0.75, 2.6)
	_player_light.shadow_enabled = false

	camera = FollowCamera.new()
	camera.name = "Camera"
	add_child(camera)
	camera.set_target(player)
	_motes = _make_motes()
	camera.add_child(_motes)

	var hud := HUD_SCENE.instantiate()
	add_child(hud)
	hud.call(&"bind_player", player)

	_connect_player()
	ComboTracker.chain_changed.connect(_on_chain_changed)
	ComboTracker.reset()

	var start := GameState.shrine_room if WorldData.ROOMS.has(GameState.shrine_room) else WorldData.START_ROOM
	_load_room(start)
	_safe_position = player.global_position
	player.respawn_position = _safe_position
	camera.snap()
	Ui.in_game = true
	Ui.set_black(true)
	_new_game = GameState.play_time < 1.0 and not GameState.flags.has("intro_seen")
	_begin.call_deferred()


func _begin() -> void:
	if _new_game:
		GameState.flags["intro_seen"] = true
		Audio.music(&"intro", 0.5)
		Ui.story_cards(Story.INTRO)
		await Ui.closed
		Ui.set_black(true)
		GameState.save()
	_apply_area(room.area, true)
	await Ui.fade_in(0.8)


func _physics_process(_delta: float) -> void:
	if room == null or _transitioning:
		return
	Ui.current_room = room.id
	Ui.player_position = player.global_position
	if player.is_dead():
		return
	_track_safe_ground()
	var p := player.global_position
	var r := room.rect
	var side := ""
	if p.x < r.position.x:
		side = "L"
	elif p.x > r.end.x:
		side = "R"
	elif p.y < r.position.y + 8.0:
		side = "U"
	elif p.y > r.end.y + 8.0:
		side = "D"
	if side != "":
		var target := room.door_target(side, p)
		if target != "" and not (_boss_active and side != "D"):
			_go_through(target, side)
		elif side == "D":
			_pit()
		else:
			# No door this way (or locked in a boss fight): keep him inside.
			player.global_position = Vector2(clampf(p.x, r.position.x + 40.0, r.end.x - 40.0), maxf(p.y, r.position.y + 90.0))
	_check_boss()
	# Enemies that fall out of the room are gone.
	for node: Node in get_tree().get_nodes_in_group(&"enemy"):
		var enemy := node as Enemy
		if enemy != null and enemy.global_position.y > r.end.y + 600.0:
			enemy.queue_free()


# --- Rooms ---------------------------------------------------------------------------


func _load_room(id: String) -> void:
	if room != null:
		_world.remove_child(room)
		room.queue_free()
	_boss_active = false
	Ui.boss_bar_hide()
	room = RoomBuilder.build(id)
	_dress_room(room)
	_world.add_child(room)
	GameState.visited[id] = true
	camera.set_bounds(room.rect)
	camera.base_zoom = 0.86 if room.kind == "boss" else 1.0
	_place_backdrop()
	if room.area != _area:
		_apply_area(room.area, false)


func _go_through(target: String, side: String) -> void:
	var t: Dictionary = WorldData.ROOMS[target]
	if String(t["kind"]) == "boss" and String(t["area"]) == "throne_spire" and not GameState.all_seals() \
			and not GameState.boss_defeated(&"king"):
		# The King's hall stays sealed until the five champions fall.
		var count := 0
		for id: StringName in GameState.BOSSES:
			if id != &"king" and GameState.boss_defeated(id):
				count += 1
		var r := room.rect
		player.global_position = Vector2(clampf(player.global_position.x, r.position.x + 90.0, r.end.x - 90.0),
			clampf(player.global_position.y, r.position.y + 120.0, r.end.y - 10.0))
		player.velocity = Vector2(-player.velocity.x * 0.5, minf(player.velocity.y, 0.0))
		Audio.sfx(&"deny")
		Ui.toast("Five seals bar the King's hall. %d of them glow." % count, Ui.GOLD)
		return
	_transitioning = true
	var exit_velocity := player.velocity
	await Ui.fade_out(0.1)
	_load_room(target)
	# Make sure he is inside the new room (rooms can be offset by a cell edge).
	var r := room.rect
	player.global_position.x = clampf(player.global_position.x, r.position.x + 24.0, r.end.x - 24.0)
	if side == "U":
		player.velocity.y = minf(exit_velocity.y, -980.0)
	camera.snap()
	_safe_position = player.global_position
	await Ui.fade_in(0.16)
	_transitioning = false


func _room_at(world_position: Vector2) -> String:
	var cell := Vector2i(floori(world_position.x / float(WorldData.CELL.x * WorldData.TILE)),
		floori(world_position.y / float(WorldData.CELL.y * WorldData.TILE)))
	return _cell_rooms.get(cell, "")


func _pit() -> void:
	Audio.sfx(&"fall")
	player.respawn_position = _safe_position
	player.hazard_hit()


## Remember the last spot he stood fully on solid, still ground.
func _track_safe_ground() -> void:
	if not player.is_on_floor() or player.is_hurt() or player.is_dashing():
		return
	var space := get_world_2d().direct_space_state
	for dx: float in [-18.0, 18.0]:
		var from := player.global_position + Vector2(dx, -4.0)
		var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(0.0, 16.0), 1 | 256)
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			return
		var body := hit.get("collider") as CollisionObject2D
		if body == null or body.collision_layer & 64 != 0:
			return
	# Not right next to spikes.
	var params := PhysicsShapeQueryParameters2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(180.0, 120.0)
	params.shape = shape
	params.transform = Transform2D(0.0, player.global_position + Vector2(0.0, 20.0))
	params.collision_mask = 32
	params.collide_with_areas = true
	params.collide_with_bodies = false
	if not space.intersect_shape(params, 1).is_empty():
		return
	_safe_position = player.global_position
	if not _full_death:
		player.respawn_position = _safe_position


# --- Death and respawn ----------------------------------------------------------------


func _on_player_died() -> void:
	Audio.sfx(&"die")
	_full_death = player.health <= 0
	if _full_death:
		GameState.deaths += 1
		player.respawn_position = GameState.shrine_position
		ComboTracker.reset()
		Ui.toast("Bonk.", Ui.RED)
		await get_tree().create_timer(0.35).timeout
		Ui.fade_out(0.45)
	else:
		Ui.fade_out(0.3)


func _on_player_respawned() -> void:
	if _full_death:
		_full_death = false
		_load_room(_room_at(player.global_position) if _room_at(player.global_position) != "" else GameState.shrine_room)
		player.refresh_max_health()
		player.heal_full()
		_safe_position = player.global_position
	camera.snap()
	Ui.fade_in(0.35)


# --- Bosses -------------------------------------------------------------------------------


func _check_boss() -> void:
	if _boss_active or room.boss == null or not is_instance_valid(room.boss):
		return
	# Far enough in from the doors (doors sit at the side walls and floor).
	var inner := room.rect.grow_individual(-260.0, -64.0, -260.0, 0.0)
	if not inner.has_point(player.global_position):
		return
	var boss := room.boss as Boss
	if boss == null or boss.active or not boss.is_alive() or boss.boss_health_changed.get_connections().size() > 0:
		return
	_boss_active = true
	room.lock_doors()
	Audio.sfx(&"gate_slam")
	GameFeel.shake(10.0)
	Audio.music(&"boss_king" if boss.boss_id == &"king" else &"boss", 0.6)
	Ui.boss_bar_show(GameState.BOSSES[boss.boss_id])
	boss.boss_health_changed.connect(func(ratio: float) -> void: Ui.boss_bar_set(ratio))
	boss.boss_defeated.connect(_on_boss_defeated.bind(boss))
	var lines: Array = Story.BOSS_LINES.get(String(boss.boss_id), [])
	boss.activate(player, lines)


func _on_boss_defeated(boss: Boss) -> void:
	var id := boss.boss_id
	GameState.bosses[id] = true
	GameState.save()
	_boss_active = false
	GameFeel.slow_motion(0.2, 0.9)
	camera.punch(0.1)
	Ui.boss_bar_hide()
	Ui.banner("TOUGH CROWD, SILENCED!" if id != &"king" else "THE KING IS LAUGHING!")
	Audio.sfx(&"boss_defeat")
	await get_tree().create_timer(1.6).timeout
	if room != null:
		room.unlock_doors()
	Audio.sfx(&"gate_open")
	Audio.music(MOOD[room.area]["music"] if room else &"", 2.0)
	if id != &"king":
		Ui.toast("A seal of the Court glows. Something waits nearby.", Ui.GOLD)
	else:
		Ui.toast("The throne is empty. Take your bow.", Ui.GOLD)


# --- Mood ----------------------------------------------------------------------------------


func _apply_area(area: String, instant: bool) -> void:
	var changed := area != _area
	_area = area
	var mood: Dictionary = MOOD.get(area, MOOD["carnival_gate"])
	var t := 0.01 if instant else 1.2
	create_tween().tween_property(_modulate, "color", mood["modulate"], t)
	create_tween().tween_property(_sky_rect, "modulate", mood["sky"], t)
	_player_light.color = mood["light"]
	_carnival.visible = area == "carnival_gate"
	_motes.color = mood["motes"]
	if not _boss_active:
		Audio.music(mood["music"])
	Audio.ambience(mood["ambience"])
	if changed or instant:
		Ui.area_title(String(WorldData.AREAS[area]["name"]), String(Story.AREA_SUBTITLES.get(area, "")))


func _build_backdrop() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Sky"
	layer.layer = -100
	_sky_rect = TextureRect.new()
	_sky_rect.texture = SKY
	_sky_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sky_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sky_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_sky_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_sky_rect)
	add_child(layer)
	_castle = ParallaxLayerNode.new()
	_castle.texture = CASTLE
	_castle.scroll_factor = Vector2(0.06, 0.04)
	_castle.ground_row = 990.0
	_castle.tiles = false
	_castle.z_index = LevelArt.Z_SKY_LAYERS
	add_child(_castle)
	_carnival = ParallaxLayerNode.new()
	_carnival.texture = CARNIVAL_FAR
	_carnival.scroll_factor = Vector2(0.25, 0.14)
	_carnival.ground_row = 710.0
	_carnival.z_index = LevelArt.Z_SKY_LAYERS + 2
	add_child(_carnival)


func _place_backdrop() -> void:
	for layer: ParallaxLayerNode in [_castle, _carnival]:
		layer.camera = camera
		layer.horizon_y = room.rect.end.y - 120.0
		layer.rest_camera_y = room.rect.end.y - 560.0
		layer.centre_x = room.rect.get_center().x


## Back wall and wall dressing (banners, lanterns, candelabras) per area.
func _dress_room(r: Room) -> void:
	var mood: Dictionary = MOOD.get(r.area, MOOD["carnival_gate"])
	var alpha: float = mood["wall"]
	if alpha > 0.0:
		var wall := Sprite2D.new()
		wall.texture = WALL
		wall.centered = false
		wall.scale = Vector2(0.5, 0.5)
		wall.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		wall.region_enabled = true
		wall.region_rect = Rect2(Vector2.ZERO, r.rect.size * 2.0)
		wall.modulate = Color(mood["wall_tint"], alpha)
		wall.z_index = -40
		r.add_child(wall)
		r.move_child(wall, 0)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(r.id) + 99
	var rows: Array = r.data["rows"]
	var h := rows.size()
	var w := String(rows[0]).length()
	var props: Array[String] = []
	match r.area:
		"grand_halls", "throne_spire":
			props = ["banner_crown.png", "banner_fleur.png", "banner_diamond.png", "candelabra.png"]
		"outer_walls":
			props = ["banner_red.png", "lantern_hanging.png"]
		"clockworks":
			props = ["lantern_hanging_b.png"]
		"royal_gardens":
			props = ["arch_vines.png", "flower_pot.png"]
		_:
			props = ["lantern_hanging.png", "barrel.png"]
	# Hang things from ceilings and stand things on floors, sparsely.
	var x := rng.randi_range(4, 9)
	while x < w - 4:
		var name: String = props[rng.randi() % props.size()]
		var hanging := name.begins_with("banner") or name.begins_with("lantern")
		for y: int in range(2, h - 2):
			var here := String(rows[y])[x]
			if hanging and String(rows[y - 1])[x] == "#" and here == "." and y + 3 < h and String(rows[y + 2])[x] == ".":
				var tex: Texture2D = load(PACK + name)
				var s := Sprite2D.new()
				s.texture = tex
				s.centered = false
				s.scale = Vector2(0.5, 0.5)
				s.position = Vector2(float(x) * 64.0 + 32.0 - tex.get_width() * 0.25, float(y) * 64.0 - 6.0)
				s.z_index = LevelArt.Z_DECOR
				r.add_child(s)
				if name.begins_with("lantern"):
					var at := s.position + Vector2(tex.get_width() * 0.25, tex.get_height() * 0.4)
					LevelArt.add_light(r, at, mood["light"], 0.7, 1.0)
					LevelArt.add_glow(r, at, mood["light"], 0.35, 0.6)
				break
			if not hanging and here == "." and y + 1 < h and String(rows[y + 1])[x] == "#" and String(rows[y - 1])[x] == ".":
				var tex: Texture2D = load(PACK + name)
				LevelArt.add_prop(r, tex, Vector2(float(x) * 64.0 + 32.0, float(y + 1) * 64.0), 0.8, rng.randf() < 0.5, LevelArt.Z_DECOR - 2)
				if name == "candelabra.png":
					var at := Vector2(float(x) * 64.0 + 32.0, float(y + 1) * 64.0 - tex.get_height() * 0.35)
					LevelArt.add_light(r, at, mood["light"], 0.8, 1.1)
					LevelArt.add_glow(r, at, mood["light"], 0.3, 0.5)
				break
		x += rng.randi_range(9, 16)
	if r.area == "clockworks":
		for i: int in rng.randi_range(2, 4):
			var gear := Gear.new()
			gear.position = Vector2(rng.randf_range(200.0, r.rect.size.x - 200.0), rng.randf_range(200.0, r.rect.size.y - 300.0))
			gear.radius = rng.randf_range(90.0, 220.0)
			gear.speed = rng.randf_range(-0.6, 0.6)
			gear.z_index = -35
			r.add_child(gear)


func _make_motes() -> CPUParticles2D:
	var m := CPUParticles2D.new()
	m.texture = LevelArt.SOFT
	m.amount = 60
	m.lifetime = 7.0
	m.preprocess = 7.0
	m.local_coords = false
	m.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	m.emission_rect_extents = Vector2(1500.0, 900.0)
	m.direction = Vector2(0.3, -1.0)
	m.spread = 50.0
	m.gravity = Vector2(0.0, -6.0)
	m.initial_velocity_min = 8.0
	m.initial_velocity_max = 26.0
	m.scale_amount_min = 0.03
	m.scale_amount_max = 0.08
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 1.0, 1.0, 0.0))
	ramp.add_point(0.25, Color(1.0, 1.0, 1.0, 0.8))
	ramp.set_color(ramp.get_point_count() - 1, Color(1.0, 1.0, 1.0, 0.0))
	m.color_ramp = ramp
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	m.material = material
	m.z_index = 5
	return m


# --- Feedback hooks ------------------------------------------------------------------------


func _connect_player() -> void:
	player.died.connect(_on_player_died)
	player.respawned.connect(_on_player_respawned)
	player.landed.connect(_on_landed)
	Feedback.bind_player(player)


func _on_landed(speed: float) -> void:
	if speed > 1050.0 and player.has_charm(&"pratfall"):
		var at := player.global_position
		Vfx.ring(self, at + Vector2(0.0, -10.0), Color(1.0, 0.8, 0.5), 1.6)
		Combat.area_damage(player, Rect2(at + Vector2(-220.0, -90.0), Vector2(440.0, 100.0)), 1, Vector2(500.0, -700.0), player)


func _on_chain_changed(count: int) -> void:
	if count == 0:
		_encore_used = false
		_last_chain_banner = 0
		return
	if count >= 10 and not _encore_used and player.has_charm(&"encore") and player.health < player.max_health:
		_encore_used = true
		player.heal(1)
		Ui.toast("Encore! +1 heart", Ui.GOLD)
	for mark: int in [10, 20, 35, 50, 75, 100]:
		if count >= mark and _last_chain_banner < mark:
			_last_chain_banner = mark
			Ui.banner("x%d CHAIN!" % mark)
			Audio.sfx(&"chain_milestone")
			camera.punch(0.04)


## Slowly turning clockwork gear drawn behind the Clockworks rooms.
class Gear extends Node2D:
	var radius: float = 120.0
	var speed: float = 0.3

	func _process(delta: float) -> void:
		rotation += speed * delta

	func _draw() -> void:
		var c := Color(0.22, 0.14, 0.1, 0.85)
		var teeth := int(radius / 14.0)
		for i: int in teeth:
			var a := TAU * float(i) / float(teeth)
			var dir := Vector2.from_angle(a)
			var side := dir.orthogonal() * 12.0
			var p := dir * radius
			draw_colored_polygon(PackedVector2Array([p - side, p + side, p + dir * 22.0 + side * 0.7, p + dir * 22.0 - side * 0.7]), c)
		draw_circle(Vector2.ZERO, radius, c)
		draw_circle(Vector2.ZERO, radius * 0.55, Color(0.12, 0.07, 0.06, 0.9))
		for i: int in 5:
			var a := TAU * float(i) / 5.0
			draw_line(Vector2.ZERO, Vector2.from_angle(a) * radius * 0.9, c, radius * 0.12)
		draw_circle(Vector2.ZERO, radius * 0.16, c)
