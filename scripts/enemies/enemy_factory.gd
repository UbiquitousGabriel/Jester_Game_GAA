class_name EnemyFactory
extends RefCounted
## Builds every regular enemy by kind. Sprite enemies come from their scenes;
## the rest are code-built Enemies with a brain and a labelled-shape body
## until their art arrives (see docs/ASSET_REQUESTS.pdf).

const SCENES := {
	"guard": "res://scenes/enemies/foot_guard.tscn",
	"mace_knight": "res://scenes/enemies/mace_knight.tscn",
	"bat": "res://scenes/enemies/bat_knight.tscn",
}

## label, size, colour, shape, health, mass, flying, brain, bells
const SPECS := {
	"arbalest": ["Arbalest", Vector2(54.0, 92.0), Color(0.55, 0.42, 0.7), LabelledShape.Kind.BOX, 2, 1.0, false, preload("res://scripts/enemies/brains/arbalest_brain.gd"), 4],
	"bulwark": ["Bulwark", Vector2(70.0, 104.0), Color(0.45, 0.5, 0.65), LabelledShape.Kind.TALL, 4, 1.8, false, preload("res://scripts/enemies/brains/bulwark_brain.gd"), 6],
	"springer": ["Springer", Vector2(50.0, 66.0), Color(0.9, 0.45, 0.25), LabelledShape.Kind.DIAMOND, 2, 0.8, false, preload("res://scripts/enemies/brains/springer_brain.gd"), 3],
	"hound": ["Gargoyle Hound", Vector2(92.0, 52.0), Color(0.5, 0.48, 0.45), LabelledShape.Kind.BOX, 3, 1.2, false, preload("res://scripts/enemies/brains/hound_brain.gd"), 5],
	"wisp": ["Wisp", Vector2(52.0, 52.0), Color(0.55, 0.95, 0.9, 0.85), LabelledShape.Kind.CIRCLE, 2, 0.6, true, preload("res://scripts/enemies/brains/wisp_brain.gd"), 4],
	"balloon": ["Balloon Clown", Vector2(70.0, 70.0), Color(0.95, 0.35, 0.45), LabelledShape.Kind.CIRCLE, 1, 0.5, true, preload("res://scripts/enemies/brains/balloon_brain.gd"), 3],
	"cannon": ["Siege Cannon", Vector2(96.0, 70.0), Color(0.35, 0.33, 0.4), LabelledShape.Kind.BOX, 4, 3.0, false, preload("res://scripts/enemies/brains/cannon_brain.gd"), 7],
	"inquisitor": ["Inquisitor", Vector2(56.0, 110.0), Color(0.75, 0.25, 0.5), LabelledShape.Kind.TALL, 5, 1.1, false, preload("res://scripts/enemies/brains/inquisitor_brain.gd"), 9],
	"porcelain": ["Porcelain Courtier", Vector2(48.0, 88.0), Color(0.95, 0.93, 0.97), LabelledShape.Kind.CAPSULE, 2, 0.8, false, preload("res://scripts/enemies/brains/porcelain_brain.gd"), 5],
	"clockwork_knight": ["Clockwork Knight", Vector2(72.0, 112.0), Color(0.75, 0.55, 0.3), LabelledShape.Kind.TALL, 7, 2.0, false, preload("res://scripts/enemies/brains/clockwork_knight_brain.gd"), 10],
}

const GUARD_BRAIN := preload("res://scripts/enemies/brains/guard_brain.gd")


static func create(kind: String, tier: int = 0) -> Enemy:
	var enemy: Enemy = null
	var bells := 3
	if SCENES.has(kind):
		enemy = (load(SCENES[kind]) as PackedScene).instantiate() as Enemy
		if kind == "guard":
			var brain: EnemyBrain = GUARD_BRAIN.new()
			brain.name = "Brain"
			enemy.add_child(brain)
		bells = {"guard": 3, "mace_knight": 7, "bat": 3}[kind]
	elif SPECS.has(kind):
		enemy = _build(kind)
		bells = SPECS[kind][8]
	else:
		push_warning("Unknown enemy kind %s" % kind)
		return null
	enemy.max_health += tier / 2
	for child: Node in enemy.get_children():
		if child is EnemyBrain:
			(child as EnemyBrain).tier = tier
	Feedback.bind_enemy(enemy, bells + tier)
	return enemy


static func _build(kind: String) -> Enemy:
	var spec: Array = SPECS[kind]
	var size: Vector2 = spec[1]
	var flying: bool = spec[6]
	var enemy := Enemy.new()
	enemy.name = String(spec[0]).replace(" ", "")
	enemy.collision_layer = 4
	enemy.collision_mask = 1 | 128 | 256
	enemy.max_health = spec[4]
	enemy.mass = spec[5]
	enemy.flying = flying
	if flying:
		enemy.launch_gravity = 1150.0
		enemy.air_recover_time = 0.4
		enemy.launch_threshold = 200.0
	if kind == "cannon":
		enemy.patrol_enabled = false
		enemy.launch_threshold = 600.0
	var cs := CollisionShape2D.new()
	if flying:
		var circle := CircleShape2D.new()
		circle.radius = size.x * 0.5
		cs.shape = circle
	else:
		var rect := RectangleShape2D.new()
		rect.size = Vector2(minf(size.x, 60.0), size.y - 4.0)
		cs.shape = rect
		cs.position = Vector2(0.0, -size.y * 0.5 + 2.0)
	enemy.add_child(cs)
	var brain: EnemyBrain = (spec[7] as GDScript).new()
	brain.name = "Brain"
	if kind == "balloon":
		brain.contact_damage = 0
	enemy.add_child(brain)
	var visual := ShapeEnemyVisual.new()
	visual.name = "Visual"
	visual.label = spec[0]
	visual.size = size
	visual.color = spec[2]
	visual.kind = spec[3]
	visual.centred = flying
	visual.bob = 4.0 if flying else 0.0
	enemy.add_child(visual)
	if kind == "porcelain":
		enemy.defeated.connect(func() -> void:
			Audio.sfx(&"shatter")
			Vfx.burst(enemy.get_parent(), enemy.global_position + Vector2(0.0, -40.0), Color(0.95, 0.95, 1.0), 20, 1.0))
	return enemy
