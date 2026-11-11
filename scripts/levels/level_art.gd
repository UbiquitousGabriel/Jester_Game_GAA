class_name LevelArt
extends RefCounted
## Builds the Carnival Gate dressing around level geometry: sky, parallax
## backdrops, terrain, platforms, decor and lights.
##
## Terrain, platforms and props come from the creative director's tileset pack
## (tools/art/slice_tileset.py -> assets/environments/pack). Sky, parallax
## backdrops, lamp posts and the gate sign come from
## tools/art/build_environment.py. All gameplay-layer art is 2x, drawn at 0.5.

const DIR := "res://assets/environments/carnival_gate/"
const SKY: Texture2D = preload(DIR + "sky.png")
const CASTLE: Texture2D = preload(DIR + "castle_far.png")
const CARNIVAL_FAR: Texture2D = preload(DIR + "carnival_far.png")
const CARNIVAL_NEAR: Texture2D = preload(DIR + "carnival_near.png")
const PACK := "res://assets/environments/pack/"
const TOP_TILES: Array[Texture2D] = [
	preload(PACK + "tile_stone_mossy_top.png"),
	preload(PACK + "tile_moss.png"),
	preload(PACK + "tile_stone_mossy_top.png"),
	preload(PACK + "tile_moss_a.png"),
	preload(PACK + "tile_stone_mossy_top.png"),
	preload(PACK + "tile_moss_b.png"),
	preload(PACK + "tile_moss_c.png"),
]
const BODY_TILES: Array[Texture2D] = [
	preload(PACK + "tile_stone.png"),
	preload(PACK + "tile_stone_light.png"),
	preload(PACK + "tile_stone.png"),
	preload(PACK + "tile_stone_cracked.png"),
	preload(PACK + "tile_stone_dark.png"),
]
const LEDGE_WOOD: Texture2D = preload(PACK + "ledge_wood.png")
const LEDGE_STONE: Texture2D = preload(PACK + "ledge_stone.png")
const BANNERS: Array[Texture2D] = [
	preload(PACK + "banner_crown.png"),
	preload(PACK + "banner_diamond.png"),
	preload(PACK + "banner_fleur.png"),
	preload(PACK + "banner_red.png"),
	preload(PACK + "banner_crown_wide.png"),
]
const DRAPERY: Texture2D = preload(PACK + "drapery_swag.png")
const LANTERN: Texture2D = preload(PACK + "lantern_hanging.png")
## World size of one terrain tile (pack tiles are 2x, about 128 px).
const TILE := 64.0
## Rows of tiles drawn under a ground surface before a flat dark fill.
const TILE_ROWS := 5
const DEEP_FILL := Color(0.16, 0.1, 0.24)
const LAMP_POST: Texture2D = preload(DIR + "lamp_post.png")
const GATE: Texture2D = preload(DIR + "gate.png")
const LIGHT: Texture2D = preload("res://assets/effects/light.png")
const SOFT: Texture2D = preload("res://assets/effects/soft_circle.png")

const INK := Color(0.11, 0.06, 0.14)
const WARM := Color(1.0, 0.68, 0.36)

## Draw order (z_index).
const Z_SKY_LAYERS := -60
const Z_DECOR := -10
const Z_TERRAIN := 0
const Z_FRONT_DECOR := 1


## Screen-fixed sky behind everything.
static func add_sky(root: Node) -> void:
	var layer := CanvasLayer.new()
	layer.name = "Sky"
	layer.layer = -100
	var rect := TextureRect.new()
	rect.texture = SKY
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)
	root.add_child(layer)


## Three parallax backdrop layers. `horizon_y` is the world y their ground
## line sits on when the camera is at `rest_camera_y`.
static func add_backdrops(root: Node, camera: Camera2D, horizon_y: float, rest_camera_y: float) -> void:
	# texture, scroll factor, texture row of its ground line, tiles, z.
	# The castle's ground row sits lower than the horizon so its towers rise
	# above the carnival as the area's landmark.
	var specs := [
		[CASTLE, Vector2(0.10, 0.06), 820.0 + 170.0, false, Z_SKY_LAYERS],
		[CARNIVAL_FAR, Vector2(0.28, 0.16), 640.0 + 70.0, true, Z_SKY_LAYERS + 2],
		[CARNIVAL_NEAR, Vector2(0.52, 0.32), 700.0, true, Z_SKY_LAYERS + 4],
	]
	for spec: Array in specs:
		var layer := ParallaxLayerNode.new()
		layer.texture = spec[0]
		layer.scroll_factor = spec[1]
		layer.ground_row = spec[2]
		layer.tiles = spec[3]
		layer.horizon_y = horizon_y
		layer.rest_camera_y = rest_camera_y
		layer.camera = camera
		layer.z_index = spec[4]
		root.add_child(layer)


## Solid ground: mossy top row, stone rows below, dark fill further down.
## Tiles are stretched slightly so a whole number fits each block exactly.
static func dress_solid(root: Node, rect: Rect2, seed: int) -> void:
	var node := Node2D.new()
	node.name = "SolidArt"
	node.position = rect.position
	node.z_index = Z_TERRAIN
	root.add_child(node)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var cols := maxi(1, roundi(rect.size.x / TILE))
	var tile_w := rect.size.x / float(cols)
	var is_wall := rect.size.y > rect.size.x * 4.0
	var rows := mini(ceili(rect.size.y / TILE), TILE_ROWS if not is_wall else 999)
	for row: int in rows:
		for col: int in cols:
			var texture: Texture2D
			if row == 0 and not is_wall:
				texture = TOP_TILES[rng.randi() % TOP_TILES.size()]
			else:
				texture = BODY_TILES[rng.randi() % BODY_TILES.size()]
			var tile := Sprite2D.new()
			tile.texture = texture
			tile.centered = false
			var h := minf(TILE, rect.size.y - float(row) * TILE)
			tile.scale = Vector2(tile_w / texture.get_width(), TILE / texture.get_height())
			if h < TILE:
				tile.region_enabled = true
				tile.region_rect = Rect2(0, 0, texture.get_width(), texture.get_height() * h / TILE)
			tile.position = Vector2(col * tile_w, row * TILE)
			# The walkable top row stays bright; rows below fall into shadow
			# so the ground has weight without competing with characters.
			var shade := 0.5 if is_wall else maxf(1.0 - 0.24 * float(row), 0.38)
			if row > 0 and not is_wall:
				shade = minf(shade, 0.72)
			tile.modulate = Color(shade * 0.96, shade * 0.9, shade * 1.08)
			node.add_child(tile)
	var drawn := float(rows) * TILE
	if rect.size.y > drawn:
		var fill := ColorRect.new()
		fill.color = DEEP_FILL
		fill.position = Vector2(0.0, drawn)
		fill.size = Vector2(rect.size.x, rect.size.y - drawn)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.add_child(fill)


## One-way platform: wooden ledge low down, stone ledge up high, with a
## hanging banner and, on wide ones, drapery and a lantern.
static func dress_platform(root: Node, rect: Rect2, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var node := Node2D.new()
	node.name = "PlatformArt"
	node.position = rect.position
	node.z_index = Z_TERRAIN
	root.add_child(node)
	var high := rect.position.y < -450.0
	var texture := LEDGE_STONE if high else LEDGE_WOOD
	# Ledges read better slightly larger than sheet scale (2x art at 0.6).
	var k := 0.6

	if rect.size.x >= 500.0 and not high:
		var swag := Sprite2D.new()
		swag.texture = DRAPERY
		swag.centered = false
		swag.scale = Vector2(0.5, 0.5)
		swag.position = Vector2(rect.size.x * 0.5 - DRAPERY.get_width() * 0.25, 20.0)
		node.add_child(swag)
	var banner_tex: Texture2D = BANNERS[rng.randi() % BANNERS.size()]
	var banner := Sprite2D.new()
	banner.texture = banner_tex
	banner.centered = false
	banner.scale = Vector2(0.5, 0.5)
	var bx := rect.size.x * (0.25 if rect.size.x >= 500.0 else 0.5) - banner_tex.get_width() * 0.25
	banner.position = Vector2(bx, 18.0)
	node.add_child(banner)
	if rect.size.x >= 600.0:
		var lx := rect.size.x * 0.78
		var lantern := Sprite2D.new()
		lantern.texture = LANTERN
		lantern.centered = false
		lantern.scale = Vector2(0.5, 0.5)
		lantern.position = Vector2(lx - LANTERN.get_width() * 0.25, 22.0)
		node.add_child(lantern)
		var glow_at := rect.position + Vector2(lx, 22.0 + LANTERN.get_height() * 0.33)
		add_light(root, glow_at, WARM, 0.8, 0.9)
		add_glow(root, glow_at, WARM, 0.5, 0.75)

	var ledge := NinePatchRect.new()
	ledge.texture = texture
	ledge.patch_margin_left = 40
	ledge.patch_margin_right = 40
	ledge.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE_FIT
	ledge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ledge.scale = Vector2(k, k)
	ledge.size = Vector2(rect.size.x / ledge.scale.x, texture.get_height())
	ledge.position = Vector2(0.0, -6.0)
	node.add_child(ledge)


## A decor sprite standing on the ground. `feet` is its bottom centre.
static func add_prop(root: Node, texture: Texture2D, feet: Vector2, size: float = 1.0, flip: bool = false, z: int = Z_DECOR) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.flip_h = flip
	var k := 0.5 * size
	sprite.scale = Vector2(k, k)
	sprite.position = feet - Vector2(texture.get_width() * k * 0.5, texture.get_height() * k)
	sprite.z_index = z
	root.add_child(sprite)
	return sprite


## Lamp post standing on the ground at `foot`, with a warm light.
static func add_lamp_post(root: Node, foot: Vector2) -> void:
	var post := Sprite2D.new()
	post.texture = LAMP_POST
	post.centered = false
	post.scale = Vector2(0.5, 0.5)
	post.position = foot + Vector2(-27.5, -208.0)
	post.z_index = Z_DECOR
	root.add_child(post)
	var lantern := foot + Vector2(17.5, -177.0)
	add_light(root, lantern, WARM, 0.9, 1.1)
	add_glow(root, lantern, WARM, 0.45, 0.9)


static func add_gate(root: Node, centre_foot: Vector2) -> void:
	var gate := Sprite2D.new()
	gate.texture = GATE
	gate.centered = false
	gate.scale = Vector2(0.5, 0.5)
	gate.position = centre_foot + Vector2(-GATE.get_width() * 0.25, -GATE.get_height() * 0.5 + 6.0)
	gate.z_index = Z_DECOR
	root.add_child(gate)
	add_light(root, centre_foot + Vector2(0.0, -250.0), Color(1.0, 0.55, 0.45), 0.6, 2.0)


## Additive 2D light (lights up nearby sprites).
static func add_light(root: Node, at: Vector2, color: Color, energy: float, size: float) -> PointLight2D:
	var light := PointLight2D.new()
	light.texture = LIGHT
	light.color = color
	light.energy = energy
	light.texture_scale = size
	light.blend_mode = Light2D.BLEND_MODE_ADD
	light.position = at
	root.add_child(light)
	return light


## Soft visible halo (the light itself only affects what it touches).
static func add_glow(root: Node, at: Vector2, color: Color, alpha: float, size: float) -> Sprite2D:
	var glow := Sprite2D.new()
	glow.texture = SOFT
	glow.modulate = Color(color, alpha)
	glow.scale = Vector2(size, size)
	glow.position = at
	glow.z_index = Z_DECOR + 1
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = material
	root.add_child(glow)
	return glow


## Drifting embers around the camera.
static func add_embers(camera: Camera2D) -> void:
	var embers := CPUParticles2D.new()
	embers.name = "Embers"
	embers.texture = SOFT
	embers.amount = 70
	embers.lifetime = 7.0
	embers.preprocess = 7.0
	embers.local_coords = false
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	embers.emission_rect_extents = Vector2(1500.0, 900.0)
	embers.direction = Vector2(0.3, -1.0)
	embers.spread = 40.0
	embers.gravity = Vector2(0.0, -6.0)
	embers.initial_velocity_min = 8.0
	embers.initial_velocity_max = 26.0
	embers.scale_amount_min = 0.03
	embers.scale_amount_max = 0.08
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.75, 0.45, 0.0))
	ramp.add_point(0.2, Color(1.0, 0.8, 0.5, 0.8))
	ramp.add_point(0.8, Color(1.0, 0.55, 0.7, 0.6))
	ramp.set_color(ramp.get_point_count() - 1, Color(1.0, 0.5, 0.7, 0.0))
	embers.color_ramp = ramp
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	embers.material = material
	embers.z_index = 5
	camera.add_child(embers)


## Sprite2D tiling `texture` (authored at 2x) over `size` world pixels.
## `world_origin` keeps patterns continuous across neighbouring blocks.
static func _tiled(texture: Texture2D, size: Vector2, world_origin: Vector2) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.scale = Vector2(0.5, 0.5)
	sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	sprite.region_enabled = true
	sprite.region_rect = Rect2(world_origin * 2.0, size * 2.0)
	return sprite
