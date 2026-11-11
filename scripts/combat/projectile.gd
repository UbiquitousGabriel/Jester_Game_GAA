class_name Projectile
extends Area2D
## Enemy and boss shots: bolts, orbs, cannonballs, hoops, knives, gears.
## Any hammer hit reflects a projectile back the way the Jester swung; a
## reflected shot hurts enemies and bosses instead (a parry).
##
## spec keys: radius, damage, gravity, life, color, kind ("orb", "bolt",
## "ball", "ring", "blade", "card"), homing (turn rate), speed_cap,
## reflectable, through_walls, label.

const PROP_LAYER := 64
const ENEMY_MASK := 4
const PLAYER_MASK := 2
const WORLD_MASK := 1

var velocity: Vector2 = Vector2.ZERO
var radius: float = 16.0
var damage: int = 1
var gravity_force: float = 0.0
var life: float = 4.0
var color: Color = Color(1.0, 0.5, 0.4)
var kind: String = "orb"
var homing: float = 0.0
var speed_cap: float = 2000.0
var reflectable: bool = true
var through_walls: bool = false
var reflected: bool = false
## Seconds after which the shot turns around (thrown crowns and axes).
var boomerang: float = 0.0
var _turned: bool = false
var _time: float = 0.0
var _trail: CPUParticles2D


static func create(at: Vector2, vel: Vector2, spec: Dictionary = {}) -> Projectile:
	var p := Projectile.new()
	# Positions are world space whatever the parent (rooms are offset).
	p.top_level = true
	p.position = at
	p.velocity = vel
	p.radius = float(spec.get("radius", 16.0))
	p.damage = int(spec.get("damage", 1))
	p.gravity_force = float(spec.get("gravity", 0.0))
	p.life = float(spec.get("life", 4.0))
	p.color = spec.get("color", Color(1.0, 0.5, 0.4))
	p.kind = String(spec.get("kind", "orb"))
	p.homing = float(spec.get("homing", 0.0))
	p.speed_cap = float(spec.get("speed_cap", 2000.0))
	p.reflectable = bool(spec.get("reflectable", true))
	p.through_walls = bool(spec.get("through_walls", false))
	p.boomerang = float(spec.get("boomerang", 0.0))
	return p


func _ready() -> void:
	collision_layer = PROP_LAYER if reflectable else 0
	collision_mask = 0
	monitoring = false
	var shape := CircleShape2D.new()
	shape.radius = radius + 10.0
	var cs := CollisionShape2D.new()
	cs.shape = shape
	add_child(cs)
	z_index = 4
	_trail = CPUParticles2D.new()
	_trail.texture = LevelArt.SOFT
	_trail.amount = 16
	_trail.lifetime = 0.3
	_trail.local_coords = false
	_trail.gravity = Vector2.ZERO
	_trail.scale_amount_min = radius / 90.0
	_trail.scale_amount_max = radius / 60.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(color, 0.7))
	ramp.set_color(1, Color(color, 0.0))
	_trail.color_ramp = ramp
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_trail.material = mat
	_trail.show_behind_parent = true
	add_child(_trail)
	LevelArt.add_light(self, Vector2.ZERO, color, 0.6, radius / 40.0)


func _physics_process(delta: float) -> void:
	_time += delta
	if _time > life:
		_pop(false)
		return
	if homing > 0.0 and not reflected:
		var player := get_tree().get_first_node_in_group(&"player") as Node2D
		if player != null:
			var want := (player.global_position + Vector2(0.0, -40.0) - global_position).angle()
			var speed := velocity.length()
			velocity = Vector2.from_angle(rotate_toward(velocity.angle(), want, homing * delta)) * speed
	if boomerang > 0.0 and not _turned and _time >= boomerang and not reflected:
		_turned = true
		velocity = -velocity
	velocity.y += gravity_force * delta
	velocity = velocity.limit_length(speed_cap)
	var from := global_position
	var to := from + velocity * delta
	if not through_walls and _time > 0.05:
		var q := PhysicsRayQueryParameters2D.create(from, to, WORLD_MASK)
		var hit := get_world_2d().direct_space_state.intersect_ray(q)
		if not hit.is_empty():
			global_position = hit["position"]
			_pop(true)
			return
	global_position = to
	rotation = velocity.angle() if kind in ["bolt", "blade", "card"] else rotation + delta * 6.0
	if reflected:
		_hit_enemies()
	elif Combat.circle_hits_player(self, global_position, radius, damage):
		_pop(true)
	queue_redraw()


## The hammer calls this: send the shot back.
func take_hit(hit: HitData) -> void:
	if reflected or not reflectable:
		return
	reflected = true
	homing = 0.0
	gravity_force *= 0.3
	var dir := hit.launch_velocity.normalized()
	if dir == Vector2.ZERO:
		dir = -velocity.normalized()
	# Aim at the nearest enemy roughly in the swing direction.
	var best: Node2D = null
	var best_score := 1e9
	for node: Node in get_tree().get_nodes_in_group(&"enemy"):
		var e := node as Node2D
		if e == null:
			continue
		var to := e.global_position + Vector2(0.0, -40.0) - global_position
		if to.length() > 1400.0 or to.normalized().dot(dir) < 0.2:
			continue
		if to.length() < best_score:
			best_score = to.length()
			best = e
	if best != null:
		dir = (best.global_position + Vector2(0.0, -40.0) - global_position).normalized()
	velocity = dir * maxf(velocity.length() * 1.5, 1100.0)
	speed_cap = maxf(speed_cap, 1800.0)
	color = Color(1.0, 0.92, 0.5)
	life = _time + 2.5
	Audio.sfx(&"parry")
	GameFeel.hitstop(0.05)
	Vfx.hit(get_parent(), global_position, dir, 0.7)


func _hit_enemies() -> void:
	var shape := CircleShape2D.new()
	shape.radius = radius + 12.0
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.transform = Transform2D(0.0, global_position)
	params.collision_mask = ENEMY_MASK
	for result: Dictionary in get_world_2d().direct_space_state.intersect_shape(params, 4):
		var node := result.get("collider") as Node
		if node != null and node.has_method(&"take_hit"):
			var hit := HitData.new()
			hit.attack_id = &"parry"
			hit.damage = maxi(damage, 1) + 1
			hit.source = self
			hit.launch_velocity = velocity.normalized() * 700.0 + Vector2(0.0, -300.0)
			node.call(&"take_hit", hit)
			ComboTracker.register_hit()
			_pop(true)
			return


func _pop(effects: bool) -> void:
	if effects:
		Vfx.burst(get_parent(), global_position, color, 8, 0.5)
		Audio.sfx(&"shot_pop", 0.1, -6.0)
	queue_free()


func _draw() -> void:
	var ink := Color(0.1, 0.05, 0.13)
	var c := color.lightened(0.15) if not reflected else Color(1.0, 0.95, 0.6)
	match kind:
		"bolt", "blade":
			var l := radius * 2.2
			draw_line(Vector2(-l, 0.0), Vector2(l, 0.0), ink, radius * 0.9)
			draw_line(Vector2(-l, 0.0), Vector2(l, 0.0), c, radius * 0.5)
			draw_colored_polygon(PackedVector2Array([Vector2(l + radius, 0.0), Vector2(l - 4.0, -radius * 0.7), Vector2(l - 4.0, radius * 0.7)]), c)
		"ring":
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24, ink, 9.0)
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24, c, 5.0)
		"card":
			draw_rect(Rect2(-radius * 0.7 - 3.0, -radius - 3.0, radius * 1.4 + 6.0, radius * 2.0 + 6.0), ink)
			draw_rect(Rect2(-radius * 0.7, -radius, radius * 1.4, radius * 2.0), Color(0.97, 0.93, 0.84))
			draw_circle(Vector2.ZERO, radius * 0.35, c)
		"gear":
			for i: int in 8:
				var a := TAU * float(i) / 8.0
				draw_line(Vector2.ZERO, Vector2.from_angle(a) * (radius + 6.0), ink, 8.0)
			draw_circle(Vector2.ZERO, radius + 3.0, ink)
			draw_circle(Vector2.ZERO, radius, c)
			draw_circle(Vector2.ZERO, radius * 0.35, ink)
		_:
			draw_circle(Vector2.ZERO, radius + 4.0, ink)
			draw_circle(Vector2.ZERO, radius, c)
			draw_circle(Vector2(-radius * 0.3, -radius * 0.3), radius * 0.35, c.lightened(0.5))
