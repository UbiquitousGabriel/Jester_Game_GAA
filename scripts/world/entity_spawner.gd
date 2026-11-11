class_name EntitySpawner
extends RefCounted
## Spawns a room's entities from WorldData. Coordinates are tiles: ground
## things stand on the tile below (x, y); flyers are centred on (x, y).

const INTERACTABLES := preload("res://scripts/world/objects/interactables.gd")
const PACK := "res://assets/environments/pack/"


static func spawn_all(room: Room, entities: Array) -> void:
	for e: Array in entities:
		var kind := String(e[0])
		var tile := Vector2(float(e[1]), float(e[2]))
		var extra: Dictionary = e[3] if e.size() > 3 else {}
		var feet := Vector2(tile.x * 64.0 + 32.0, (tile.y + 1.0) * 64.0)
		var centre := Vector2(tile.x * 64.0 + 32.0, tile.y * 64.0 + 32.0)
		match kind:
			"sign":
				var s: Interactable = INTERACTABLES.SignPost.new()
				s.key = String(extra.get("text", ""))
				_place(room, s, feet)
			"lamp":
				LevelArt.add_lamp_post(room, feet)
			"torch":
				var torch := LevelArt.add_prop(room, load(PACK + "brazier.png"), feet, 0.9, false, -8)
				var at := feet + Vector2(0.0, -torch.texture.get_height() * 0.36)
				LevelArt.add_light(room, at, Color(1.0, 0.6, 0.3), 0.9, 1.1)
				LevelArt.add_glow(room, at, Color(1.0, 0.6, 0.3), 0.45, 0.8)
			"enemy":
				var enemy := EnemyFactory.create(String(extra.get("kind", "guard")), int(extra.get("tier", 0)))
				if enemy != null:
					var flying := bool(enemy.get(&"flying")) if enemy is Enemy else false
					enemy.position = centre if flying else feet
					room.add_child(enemy)
			"heart":
				if not GameState.is_picked(String(extra["id"])):
					room.add_child(Pickup.create(Pickup.Kind.HEART_PIECE, centre, String(extra["id"])))
			"joke":
				if not GameState.is_picked(String(extra["id"])):
					room.add_child(Pickup.create(Pickup.Kind.JOKE, centre, String(extra["id"])))
			"bells":
				if not GameState.is_picked(String(extra["id"])):
					room.add_child(Pickup.create(Pickup.Kind.BELL_CACHE, centre, String(extra["id"])))
			"shrine":
				var shrine: Interactable = INTERACTABLES.Shrine.new()
				shrine.room_id = room.id
				_place(room, shrine, feet)
			"shop":
				var shop: Interactable = INTERACTABLES.ShopKeeper.new()
				shop.area = room.area
				_place(room, shop, feet)
			"npc":
				var npc: Interactable = INTERACTABLES.Npc.new()
				npc.who = String(extra.get("who", "spook"))
				npc.area = String(extra.get("area", room.area))
				_place(room, npc, feet)
			"boss":
				var id := StringName(extra.get("id", "ringmaster"))
				if not GameState.boss_defeated(id):
					var boss := BossFactory.create(id)
					boss.position = feet
					room.add_child(boss)
					room.boss = boss
			"altar":
				var altar: Interactable = INTERACTABLES.Altar.new()
				altar.ability = StringName(extra["ability"])
				altar.boss = StringName(extra["boss"])
				_place(room, altar, feet)
			"ending":
				_place(room, INTERACTABLES.EndingThrone.new(), feet)
			"seal_door":
				_place(room, INTERACTABLES.SealDoor.new(), feet)


static func _place(room: Room, node: Node2D, feet: Vector2) -> void:
	node.position = feet
	room.add_child(node)
