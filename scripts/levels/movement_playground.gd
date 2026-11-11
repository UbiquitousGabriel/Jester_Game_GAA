extends Node2D
## Graybox movement and combat playground (Milestones 1-2).
##
## Geometry is built from the data tables below so the layout is easy to read
## and retune. Three elevations, one-way upper platforms, a spike pit to pogo
## across, a gap with an enemy stepping stone, bounce-pad recovery routes,
## breakable crates and a walled arena for chain collisions.
##
## Coordinates: y = 0 is the main ground surface, negative y is up.

const FOOT_GUARD_SCENE: PackedScene = preload("res://scenes/enemies/foot_guard.tscn")
const MACE_KNIGHT_SCENE: PackedScene = preload("res://scenes/enemies/mace_knight.tscn")
const BAT_KNIGHT_SCENE: PackedScene = preload("res://scenes/enemies/bat_knight.tscn")

const WORLD_LAYER: int = 1
const KILL_PLANE_Y: float = 760.0
const CAMERA_BOUNDS := Rect2(-240.0, -1500.0, 6880.0, 2100.0)

## Camera centre y when the Jester stands on the main ground; backdrops are
## aligned to it.
const REST_CAMERA_Y := -150.0

const PACK := "res://assets/environments/pack/"
## Decor: texture, bottom-centre position, scale, flip, z (-10 behind, 1 front).
const DECOR := [
	["tent.png", Vector2(380.0, 0.0), 1.55, false, -12],
	["barrel.png", Vector2(560.0, 0.0), 1.0, false, -10],
	["barrel.png", Vector2(600.0, 0.0), 0.9, true, -11],
	["jester_bust.png", Vector2(1420.0, 0.0), 1.0, false, -10],
	["cart.png", Vector2(2150.0, 0.0), 1.2, false, -12],
	["flower_pot.png", Vector2(2280.0, 0.0), 0.8, false, -10],
	["arch_vines.png", Vector2(3080.0, 0.0), 1.4, false, -14],
	["fire.png", Vector2(3330.0, 0.0), 0.8, false, -10],
	["rubble.png", Vector2(3960.0, 0.0), 1.0, false, -10],
	["barrel.png", Vector2(4420.0, 0.0), 1.0, true, -10],
	["arch_column.png", Vector2(4980.0, 0.0), 1.25, false, -14],
	["flower_pot.png", Vector2(5560.0, 0.0), 0.8, true, -10],
	["gate_golden.png", Vector2(6290.0, 0.0), 1.2, false, -12],
]
const LAMP_POSTS: Array[float] = [820.0, 1980.0, 2900.0, 4100.0, 4700.0, 5300.0, 6050.0]
## Warm firelight on the decor that emits it: position, energy, size.
const FIRE_LIGHTS := [
	[Vector2(3330.0, -50.0), 1.0, 1.4],
]

## Solid blocks: ground, pit floors, walls.
const SOLIDS: Array[Rect2] = [
	Rect2(-200.0, 0.0, 1700.0, 500.0),  # start ground
	Rect2(1500.0, 240.0, 400.0, 260.0),  # spike pit floor
	Rect2(1900.0, 0.0, 1500.0, 500.0),  # middle ground
	Rect2(3400.0, 260.0, 500.0, 240.0),  # gap floor (slow recovery route)
	Rect2(3600.0, 60.0, 100.0, 200.0),  # stepping-stone island
	Rect2(3900.0, 0.0, 2500.0, 500.0),  # arena ground
	Rect2(-240.0, -1500.0, 40.0, 2000.0),  # left wall
	Rect2(6400.0, -1500.0, 40.0, 2000.0),  # right wall (ricochets)
]

## One-way platforms: jump or launch up through them, land on top.
const PLATFORMS: Array[Rect2] = [
	# Middle elevation
	Rect2(500.0, -200.0, 400.0, 36.0),
	Rect2(1300.0, -300.0, 800.0, 36.0),
	Rect2(2500.0, -210.0, 500.0, 36.0),
	Rect2(3300.0, -320.0, 700.0, 36.0),
	Rect2(4500.0, -220.0, 600.0, 36.0),
	# Upper elevation
	Rect2(900.0, -540.0, 400.0, 36.0),
	Rect2(2100.0, -560.0, 600.0, 36.0),
	Rect2(3000.0, -620.0, 500.0, 36.0),
	Rect2(4100.0, -600.0, 500.0, 36.0),
	Rect2(5300.0, -520.0, 700.0, 36.0),
	# Top perch
	Rect2(2600.0, -900.0, 600.0, 36.0),
]

## Spike strips: top-left corner and size.
const SPIKES: Array[Rect2] = [
	Rect2(1500.0, 200.0, 400.0, 40.0),
]

## Bounce pads: x, y of the top surface, z = bounce speed.
const BOUNCE_PADS: Array[Vector3] = [
	Vector3(1250.0, 0.0, 1850.0),
	Vector3(2200.0, 0.0, 1850.0),
	Vector3(3840.0, 260.0, 1500.0),
	Vector3(5380.0, 0.0, 1850.0),
]

## Crates: bottom-centre positions (64 px cubes).
const CRATES: Array[Vector2] = [
	Vector2(2350.0, 0.0),
	Vector2(2350.0, -64.0),
	Vector2(2414.0, 0.0),
	Vector2(5700.0, 0.0),
	Vector2(5764.0, 0.0),
	Vector2(5700.0, -64.0),
	Vector2(5764.0, -64.0),
	Vector2(5732.0, -128.0),
]

const CHECKPOINTS: Array[Vector2] = [
	Vector2(120.0, 0.0),
	Vector2(2000.0, 0.0),
	Vector2(4000.0, 0.0),
]

## Guards: x, y of the feet, z = 1 to patrol or 0 to stand still.
const GUARDS: Array[Vector3] = [
	Vector3(900.0, 0.0, 1.0),
	Vector3(1120.0, 0.0, 1.0),
	Vector3(1700.0, -300.0, 1.0),
	Vector3(2700.0, 0.0, 1.0),
	Vector3(2950.0, 0.0, 1.0),
	Vector3(3150.0, 0.0, 1.0),
	Vector3(2750.0, -210.0, 1.0),
	Vector3(3650.0, 60.0, 0.0),  # stepping stone: pogo off him to cross the gap
	Vector3(4550.0, 0.0, 1.0),
	Vector3(4800.0, 0.0, 1.0),
	Vector3(5650.0, -520.0, 1.0),
]

## Mace knights (heavy ground bruisers): feet positions.
const KNIGHTS: Array[Vector2] = [
	Vector2(4300.0, 0.0),
	Vector2(5150.0, 0.0),
	Vector2(5880.0, -520.0),
]

## Bat knights (flyers): roost positions they hover around.
const BATS: Array[Vector2] = [
	Vector2(1700.0, -470.0),
	Vector2(2650.0, -760.0),
	Vector2(3660.0, -330.0),
	Vector2(4650.0, -560.0),
	Vector2(5550.0, -780.0),
]

@onready var _player: Player = $Player
@onready var _camera: FollowCamera = $FollowCamera


func _ready() -> void:
	LevelArt.add_sky(self)
	LevelArt.add_backdrops(self, _camera, 0.0, REST_CAMERA_Y)
	_build_terrain()
	_build_decor()
	_build_gadgets()
	_spawn_guards()
	_camera.set_bounds(CAMERA_BOUNDS)
	LevelArt.add_embers(_camera)
	# Draw the Jester in front of everything built above.
	move_child(_player, -1)


func _physics_process(_delta: float) -> void:
	if Input.is_action_just_pressed(&"debug_restart"):
		ComboTracker.reset()
		get_tree().reload_current_scene()
		return
	# Safety net below the level.
	if _player.global_position.y > KILL_PLANE_Y:
		_player.hazard_hit()
	for node: Node in get_tree().get_nodes_in_group(&"enemy"):
		var enemy := node as Enemy
		if enemy != null and enemy.global_position.y > KILL_PLANE_Y:
			enemy.queue_free()


func _build_terrain() -> void:
	for i: int in SOLIDS.size():
		_add_block(SOLIDS[i], false)
		LevelArt.dress_solid(self, SOLIDS[i], 100 + i)
	for i: int in PLATFORMS.size():
		_add_block(PLATFORMS[i], true)
		LevelArt.dress_platform(self, PLATFORMS[i], 200 + i)


func _build_decor() -> void:
	LevelArt.add_gate(self, Vector2(40.0, 0.0))
	for spec: Array in DECOR:
		var texture: Texture2D = load(PACK + String(spec[0]))
		LevelArt.add_prop(self, texture, spec[1], spec[2], spec[3], spec[4])
	for x: float in LAMP_POSTS:
		LevelArt.add_lamp_post(self, Vector2(x, 0.0))
	for light: Array in FIRE_LIGHTS:
		LevelArt.add_light(self, light[0], Color(1.0, 0.6, 0.3), light[1], light[2])
		LevelArt.add_glow(self, light[0], Color(1.0, 0.6, 0.3), 0.5, 1.2)


func _build_gadgets() -> void:
	for rect: Rect2 in SPIKES:
		add_child(HazardZone.create(rect.position, rect.size))
	for pad: Vector3 in BOUNCE_PADS:
		add_child(BouncePad.create(Vector2(pad.x, pad.y), pad.z))
	for crate_position: Vector2 in CRATES:
		add_child(Breakable.create(crate_position))
	for checkpoint_position: Vector2 in CHECKPOINTS:
		add_child(Checkpoint.create(checkpoint_position))


func _spawn_guards() -> void:
	for spawn: Vector3 in GUARDS:
		var guard := FOOT_GUARD_SCENE.instantiate() as Enemy
		guard.position = Vector2(spawn.x, spawn.y)
		guard.patrol_enabled = spawn.z > 0.5
		add_child(guard)
	for feet: Vector2 in KNIGHTS:
		var knight := MACE_KNIGHT_SCENE.instantiate() as Enemy
		knight.position = feet
		add_child(knight)
	for roost: Vector2 in BATS:
		var bat := BAT_KNIGHT_SCENE.instantiate() as Enemy
		bat.position = roost
		add_child(bat)


## Collision only; LevelArt draws the visuals.
func _add_block(rect: Rect2, one_way: bool) -> void:
	var body := StaticBody2D.new()
	body.position = rect.position
	body.collision_layer = WORLD_LAYER
	body.collision_mask = 0

	var shape := RectangleShape2D.new()
	shape.size = rect.size
	var collider := CollisionShape2D.new()
	collider.shape = shape
	collider.position = rect.size * 0.5
	collider.one_way_collision = one_way
	body.add_child(collider)
	add_child(body)

