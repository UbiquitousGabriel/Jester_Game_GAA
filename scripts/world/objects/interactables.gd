extends RefCounted
## Concrete interactables. Each is a small class so scenes stay code-built.


class SignPost extends Interactable:
	var key: String = ""

	func _build() -> void:
		prompt = "Read"
		var post := Node2D.new()
		post.set_script(preload("res://scripts/world/objects/sign_visual.gd"))
		add_child(post)

	func interact(_player: Player) -> void:
		Audio.sfx(&"page")
		Ui.dialog([Story.SIGNS.get(key, key)], "Sign")


class Shrine extends Interactable:
	var room_id: String = ""

	func _build() -> void:
		prompt = "Rest"
		var bust := Sprite2D.new()
		bust.texture = preload("res://assets/environments/pack/jester_bust.png")
		bust.centered = false
		bust.scale = Vector2(0.6, 0.6)
		bust.position = Vector2(-bust.texture.get_width() * 0.3, -bust.texture.get_height() * 0.6 - 60.0)
		add_child(bust)
		var block := Sprite2D.new()
		block.texture = preload("res://assets/environments/pack/stone_block.png")
		block.centered = false
		block.scale = Vector2(0.7, 0.9)
		block.position = Vector2(-block.texture.get_width() * 0.35, -block.texture.get_height() * 0.9)
		add_child(block)
		LevelArt.add_light(self, Vector2(0.0, -120.0), Color(1.0, 0.8, 0.55), 1.0, 1.4)
		LevelArt.add_glow(self, Vector2(0.0, -120.0), Color(1.0, 0.8, 0.55), 0.35, 1.2)

	func interact(player: Player) -> void:
		player.heal_full()
		GameState.set_shrine(room_id, global_position + Vector2(0.0, -4.0))
		GameState.save()
		Audio.sfx(&"shrine")
		GameFeel.shake(2.0)
		Vfx.cloud(get_parent(), global_position + Vector2(0.0, -80.0), 1.2)
		Ui.shrine_menu()


class ShopKeeper extends Interactable:
	var area: String = ""

	func _build() -> void:
		prompt = "Shop"
		var pippet := LabelledShape.new()
		pippet.label = "Pippet"
		pippet.size = Vector2(44.0, 70.0)
		pippet.color = Color(0.3, 0.55, 0.85)
		pippet.bob = 2.0
		add_child(pippet)
		var cart := Sprite2D.new()
		cart.texture = preload("res://assets/environments/pack/cart.png")
		cart.centered = false
		cart.scale = Vector2(0.6, 0.6)
		cart.position = Vector2(40.0, -cart.texture.get_height() * 0.6)
		cart.z_index = -1
		add_child(cart)

	func interact(_player: Player) -> void:
		Audio.sfx(&"page")
		Ui.shop(area)


class Npc extends Interactable:
	var who: String = "spook"
	var area: String = ""
	var _line: int = 0

	func _build() -> void:
		prompt = "Talk"
		var shape := LabelledShape.new()
		if who == "spook":
			shape.label = "Court Spook"
			shape.kind = LabelledShape.Kind.BELL
			shape.size = Vector2(56.0, 76.0)
			shape.color = Color(0.55, 0.9, 0.95, 0.85)
			shape.bob = 6.0
			shape.position = Vector2(0.0, -20.0)
		else:
			shape.label = "Pippet"
			shape.size = Vector2(44.0, 70.0)
			shape.color = Color(0.3, 0.55, 0.85)
			shape.bob = 2.0
		add_child(shape)

	func interact(_player: Player) -> void:
		var lines: Array = Story.SPOOK.get(area, Story.SPOOK["carnival_gate"]) if who == "spook" else Story.PIPPET
		Audio.sfx(&"talk")
		Ui.dialog([lines[_line % lines.size()]], "Court Spook" if who == "spook" else "Pippet")
		_line += 1


class Altar extends Interactable:
	var ability: StringName = &""
	var boss: StringName = &""
	var _orb: Node2D

	func _build() -> void:
		prompt = "Claim"
		var block := Sprite2D.new()
		block.texture = preload("res://assets/environments/pack/stone_block.png")
		block.centered = false
		block.scale = Vector2(0.8, 0.8)
		block.position = Vector2(-block.texture.get_width() * 0.4, -block.texture.get_height() * 0.8)
		add_child(block)
		_orb = LevelArt.add_glow(self, Vector2(0.0, -110.0), Color(1.0, 0.85, 0.4), 0.9, 0.6)
		LevelArt.add_light(self, Vector2(0.0, -110.0), Color(1.0, 0.85, 0.4), 1.2, 1.3)

	func can_interact() -> bool:
		return GameState.boss_defeated(boss) and not GameState.has(ability)

	func _process(delta: float) -> void:
		super._process(delta)
		visible = GameState.boss_defeated(boss)
		if _orb:
			_orb.visible = not GameState.has(ability)
			_orb.scale = Vector2.ONE * (0.6 + 0.08 * sin(_time * 5.0))

	func interact(_player: Player) -> void:
		Ui.ability_get(ability)


class EndingThrone extends Interactable:
	func _build() -> void:
		prompt = "Take a bow"
		var throne := Sprite2D.new()
		throne.texture = preload("res://assets/environments/pack/throne.png")
		throne.centered = false
		throne.scale = Vector2(1.2, 1.2)
		throne.position = Vector2(-throne.texture.get_width() * 0.6, -throne.texture.get_height() * 1.2)
		add_child(throne)

	func can_interact() -> bool:
		return GameState.boss_defeated(&"king")

	func _process(delta: float) -> void:
		super._process(delta)
		visible = GameState.boss_defeated(&"king")

	func interact(_player: Player) -> void:
		Ui.ending()


class SealDoor extends Interactable:
	var _body: StaticBody2D

	func _build() -> void:
		prompt = "Inspect"
		_body = StaticBody2D.new()
		# Lore only: the real lock is on the King's hall doors (Game).
		_body.collision_layer = 0
		var shape := RectangleShape2D.new()
		shape.size = Vector2(96.0, 320.0)
		var cs := CollisionShape2D.new()
		cs.shape = shape
		cs.position = Vector2(0.0, -160.0)
		_body.add_child(cs)
		add_child(_body)
		var gate := Sprite2D.new()
		gate.texture = preload("res://assets/environments/pack/gate_golden.png")
		gate.centered = false
		gate.scale = Vector2(0.95, 1.0)
		gate.position = Vector2(-gate.texture.get_width() * 0.475, -gate.texture.get_height())
		add_child(gate)

	func _process(delta: float) -> void:
		super._process(delta)
		if GameState.all_seals() and modulate.a > 0.5:
			modulate.a = 0.35

	func interact(_player: Player) -> void:
		var count := 0
		for id: StringName in GameState.BOSSES:
			if id != &"king" and GameState.boss_defeated(id):
				count += 1
		if count >= 5:
			Ui.dialog(["The five seals blaze. The gate stands open."], "Seal Door")
		else:
			Ui.dialog(["Five seals ring this gate. %d of them glow." % count,
				"Beat the castle's five champions and it will open."], "Seal Door")
