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

const WORLD_LAYER: int = 1
const KILL_PLANE_Y: float = 760.0
const CAMERA_BOUNDS := Rect2(-240.0, -1500.0, 6880.0, 2100.0)

const STONE := Color(0.33, 0.26, 0.45)
const STONE_TRIM := Color(0.55, 0.45, 0.7)
const PLATFORM := Color(0.45, 0.24, 0.5)
const PLATFORM_TRIM := Color(0.98, 0.76, 0.22)
const BANNER := Color(0.74, 0.13, 0.22)

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
	Vector3(4300.0, 0.0, 1.0),
	Vector3(4550.0, 0.0, 1.0),
	Vector3(4800.0, 0.0, 1.0),
	Vector3(5050.0, 0.0, 1.0),
	Vector3(5650.0, -520.0, 1.0),
	Vector3(5850.0, -520.0, 1.0),
]

@onready var _player: Player = $Player
@onready var _camera: FollowCamera = $FollowCamera


func _ready() -> void:
	_build_terrain()
	_build_gadgets()
	_spawn_guards()
	_camera.set_bounds(CAMERA_BOUNDS)
	# Draw the Jester in front of everything built above.
	move_child(_player, -1)


func _physics_process(_delta: float) -> void:
	if Input.is_action_just_pressed(&"debug_restart"):
		ComboTracker.reset()
		get_tree().reload_current_scene()
		return
	# Safety net below the level.
	if _player.global_position.y > KILL_PLANE_Y:
		_player.die()
	for node: Node in get_tree().get_nodes_in_group(&"enemy"):
		var enemy := node as Enemy
		if enemy != null and enemy.global_position.y > KILL_PLANE_Y:
			enemy.queue_free()


func _build_terrain() -> void:
	for rect: Rect2 in SOLIDS:
		_add_block(rect, STONE, STONE_TRIM, false)
	for rect: Rect2 in PLATFORMS:
		_add_block(rect, PLATFORM, PLATFORM_TRIM, true)
		# Hanging banner as a landmark under each platform.
		var banner_top := rect.position + Vector2(rect.size.x * 0.5 - 24.0, rect.size.y)
		add_child(_make_quad(Rect2(banner_top, Vector2(48.0, 90.0)), BANNER))


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


func _add_block(rect: Rect2, fill: Color, trim: Color, one_way: bool) -> void:
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

	body.add_child(_make_quad(Rect2(Vector2.ZERO, rect.size), fill))
	# Bright top edge so landing surfaces read clearly at the wide zoom.
	body.add_child(_make_quad(Rect2(Vector2.ZERO, Vector2(rect.size.x, 8.0)), trim))
	add_child(body)


func _make_quad(rect: Rect2, color: Color) -> Polygon2D:
	var quad := Polygon2D.new()
	quad.polygon = PackedVector2Array(
		[
			rect.position,
			Vector2(rect.end.x, rect.position.y),
			rect.end,
			Vector2(rect.position.x, rect.end.y),
		]
	)
	quad.color = color
	return quad
