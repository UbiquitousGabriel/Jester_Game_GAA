class_name Vfx
extends RefCounted
## One-shot visual effects built from the tileset pack's effect art.
## Purely cosmetic: nothing here touches gameplay state.

const BURST: Texture2D = preload("res://assets/environments/pack/fx_burst.png")
const CLOUD: Texture2D = preload("res://assets/environments/pack/fx_cloud.png")
const SMOKE: Texture2D = preload("res://assets/environments/pack/fx_smoke_small.png")
const STAR: Texture2D = preload("res://assets/effects/star.png")
const SPARK: Texture2D = preload("res://assets/effects/spark.png")
const SOFT: Texture2D = preload("res://assets/effects/soft_circle.png")

const Z_FX := 6


## Hammer or chain impact: flash, burst, sparks and stars.
static func hit(parent: Node, at: Vector2, direction: Vector2, power: float = 1.0) -> void:
	var flash := _sprite(parent, SOFT, at, Color(1.0, 0.95, 0.8, 0.9), 0.9 * power, true)
	_fade(flash, 0.12, 1.5 * power)

	var burst := _sprite(parent, BURST, at, Color.WHITE, 0.35 * power, false)
	burst.rotation = direction.angle() + PI * 0.5 if direction != Vector2.ZERO else 0.0
	_pop(burst, 0.18, 0.55 * power)

	_particles(parent, at, SPARK, 10, 0.25, Vector2(380.0, 820.0) * power, 0.08, 0.16, direction,
		Color(1.0, 0.95, 0.75), true)
	_particles(parent, at, STAR, 5, 0.55, Vector2(220.0, 520.0) * power, 0.22, 0.38, direction,
		Color.WHITE, false, Vector2(0.0, 1400.0))


## Puff of dust at the feet.
static func dust(parent: Node, feet: Vector2, size: float = 1.0) -> void:
	for side: float in [-1.0, 1.0]:
		var puff := _sprite(parent, SMOKE, feet + Vector2(side * 18.0 * size, -10.0 * size),
			Color(1.0, 1.0, 1.0, 0.85), 0.32 * size, false)
		puff.flip_h = side < 0.0
		var tween := puff.create_tween().set_parallel()
		tween.tween_property(puff, "position:x", puff.position.x + side * 34.0 * size, 0.35)
		tween.tween_property(puff, "scale", puff.scale * 1.4, 0.35)
		tween.tween_property(puff, "modulate:a", 0.0, 0.35)
		tween.chain().tween_callback(puff.queue_free)


## Bigger cloud for crate breaks and heavy landings.
static func cloud(parent: Node, at: Vector2, size: float = 1.0) -> void:
	var puff := _sprite(parent, CLOUD, at, Color(1.0, 1.0, 1.0, 0.9), 0.38 * size, false)
	_pop(puff, 0.45, 0.6 * size)


# --- Internals -------------------------------------------------------------------


static func _sprite(parent: Node, texture: Texture2D, at: Vector2, color: Color, size: float, additive: bool) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.global_position = at
	sprite.modulate = color
	sprite.scale = Vector2(size, size)
	sprite.z_index = Z_FX
	if additive:
		var material := CanvasItemMaterial.new()
		material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		sprite.material = material
	parent.add_child(sprite)
	sprite.global_position = at
	return sprite


static func _pop(sprite: Sprite2D, time: float, peak: float) -> void:
	sprite.scale = Vector2(peak, peak) * 0.4
	var tween := sprite.create_tween()
	tween.tween_property(sprite, "scale", Vector2(peak, peak), time * 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "modulate:a", 0.0, time * 0.7)
	tween.tween_callback(sprite.queue_free)


static func _fade(sprite: Sprite2D, time: float, grow: float) -> void:
	var tween := sprite.create_tween().set_parallel()
	tween.tween_property(sprite, "scale", Vector2(grow, grow), time)
	tween.tween_property(sprite, "modulate:a", 0.0, time)
	tween.chain().tween_callback(sprite.queue_free)


static func _particles(parent: Node, at: Vector2, texture: Texture2D, amount: int, lifetime: float,
		speed: Vector2, scale_min: float, scale_max: float, direction: Vector2, color: Color,
		additive: bool, gravity: Vector2 = Vector2.ZERO) -> void:
	var p := CPUParticles2D.new()
	p.texture = texture
	p.amount = amount
	p.lifetime = lifetime
	p.one_shot = true
	p.explosiveness = 1.0
	p.local_coords = false
	p.direction = direction if direction != Vector2.ZERO else Vector2.UP
	p.spread = 70.0
	p.initial_velocity_min = speed.x
	p.initial_velocity_max = speed.y
	p.damping_min = 600.0
	p.damping_max = 1200.0
	p.gravity = gravity
	p.angular_velocity_min = -540.0
	p.angular_velocity_max = 540.0
	p.scale_amount_min = scale_min
	p.scale_amount_max = scale_max
	p.color = color
	var ramp := Gradient.new()
	ramp.set_color(0, Color.WHITE)
	ramp.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	p.color_ramp = ramp
	p.z_index = Z_FX
	if additive:
		var material := CanvasItemMaterial.new()
		material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		p.material = material
	parent.add_child(p)
	p.global_position = at
	p.emitting = true
	p.finished.connect(p.queue_free)
