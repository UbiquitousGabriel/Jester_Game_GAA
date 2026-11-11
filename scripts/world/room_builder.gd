class_name RoomBuilder
extends RefCounted
## Turns a WorldData room into a live Room: merged-rect collision, a tile-map
## for visuals, one-way ledges, hazards, gates and entities.
##
## Grid legend (tools/world/build_world.py):
##   #  solid   =  one-way ledge   ^  spikes   %  cracked stone (Cracking Slam)
##   ~  spectral barrier (Phantom Step)   C  crate   S  spring   .  air

const WORLD_LAYER := 1
const ONE_WAY_LAYER := 256
const T := 64.0

## Area look: terrain tint, deep-rock tint.
const AREA_TINT := {
	"carnival_gate": Color(1.0, 0.94, 1.0),
	"outer_walls": Color(0.82, 0.86, 1.0),
	"royal_gardens": Color(0.86, 1.0, 0.86),
	"grand_halls": Color(1.0, 0.92, 0.8),
	"clockworks": Color(1.0, 0.84, 0.66),
	"throne_spire": Color(0.92, 0.8, 1.0),
}


static func build(room_id: String) -> Room:
	var data: Dictionary = WorldData.ROOMS[room_id]
	var room := Room.new()
	room.name = "Room_" + room_id
	room.id = room_id
	room.area = data["area"]
	room.kind = data["kind"]
	room.data = data
	var origin := Vector2(float(data["origin"][0]) * WorldData.CELL.x * T, float(data["origin"][1]) * WorldData.CELL.y * T)
	var size := Vector2(float(data["size"][0]) * WorldData.CELL.x * T, float(data["size"][1]) * WorldData.CELL.y * T)
	room.position = origin
	room.rect = Rect2(origin, size)
	for door: Array in data["doors"]:
		room.doors["%s%d" % [door[0], door[1]]] = door[2]

	var rows: Array = data["rows"]
	_build_collision(room, rows)
	_build_tiles(room, rows)
	_build_ledges(room, rows)
	_build_specials(room, rows)
	EntitySpawner.spawn_all(room, data["entities"])
	return room


# --- Collision ---------------------------------------------------------------------


static func _build_collision(room: Room, rows: Array) -> void:
	var h := rows.size()
	var w := String(rows[0]).length()
	var used: Array[PackedByteArray] = []
	for y: int in h:
		var line := PackedByteArray()
		line.resize(w)
		used.append(line)
	var body := StaticBody2D.new()
	body.name = "Terrain"
	body.collision_layer = WORLD_LAYER
	body.collision_mask = 0
	room.add_child(body)
	# Greedy rectangles over solid tiles.
	for y: int in h:
		var row := String(rows[y])
		for x: int in w:
			if row[x] != "#" or used[y][x] == 1:
				continue
			var x1 := x
			while x1 + 1 < w and String(rows[y])[x1 + 1] == "#" and used[y][x1 + 1] == 0:
				x1 += 1
			var y1 := y
			var grow := true
			while grow and y1 + 1 < h:
				var next := String(rows[y1 + 1])
				for xx: int in range(x, x1 + 1):
					if next[xx] != "#" or used[y1 + 1][xx] == 1:
						grow = false
						break
				if grow:
					y1 += 1
			for yy: int in range(y, y1 + 1):
				for xx: int in range(x, x1 + 1):
					used[yy][xx] = 1
			var shape := RectangleShape2D.new()
			shape.size = Vector2(float(x1 - x + 1) * T, float(y1 - y + 1) * T)
			var cs := CollisionShape2D.new()
			cs.shape = shape
			cs.position = Vector2(float(x) * T, float(y) * T) + shape.size * 0.5
			body.add_child(cs)


# --- Visual tiles -------------------------------------------------------------------


static func _build_tiles(room: Room, rows: Array) -> void:
	var layer := TileMapLayer.new()
	layer.name = "Tiles"
	layer.tile_set = TerrainTiles.tileset()
	layer.scale = Vector2(0.5, 0.5)
	layer.z_index = 0
	layer.modulate = AREA_TINT.get(room.area, Color.WHITE)
	room.add_child(layer)
	var h := rows.size()
	var w := String(rows[0]).length()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(room.id)
	var deep := Node2D.new()
	deep.name = "Depth"
	room.add_child(deep)
	for y: int in h:
		var row := String(rows[y])
		for x: int in w:
			if row[x] != "#":
				continue
			var above := String(rows[y - 1])[x] if y > 0 else "#"
			var tile: int
			if above != "#" and above != "%":
				tile = rng.randi() % TerrainTiles.TOP_VARIANTS
			else:
				tile = TerrainTiles.BODY_START + rng.randi() % TerrainTiles.BODY_VARIANTS
			layer.set_cell(Vector2i(x, y), 0, Vector2i(tile, 0))
	# Darken solid mass away from open air so walls read as depth, not texture.
	var poly := _depth_overlay(rows)
	if poly != null:
		deep.add_child(poly)


static func _depth_overlay(rows: Array) -> Node2D:
	var h := rows.size()
	var w := String(rows[0]).length()
	var node := Node2D.new()
	for y: int in h:
		var row := String(rows[y])
		var x := 0
		while x < w:
			if row[x] != "#" or _distance_to_air(rows, x, y) < 2:
				x += 1
				continue
			var x1 := x
			while x1 + 1 < w and row[x1 + 1] == "#" and _distance_to_air(rows, x1 + 1, y) >= 2:
				x1 += 1
			var d := _distance_to_air(rows, x, y)
			var rect := ColorRect.new()
			rect.color = Color(0.07, 0.04, 0.11, clampf(0.25 + 0.18 * float(d - 2), 0.25, 0.85))
			rect.position = Vector2(float(x) * T, float(y) * T)
			rect.size = Vector2(float(x1 - x + 1) * T, T)
			rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			node.add_child(rect)
			x = x1 + 1
	return node


static func _distance_to_air(rows: Array, x: int, y: int) -> int:
	var h := rows.size()
	var w := String(rows[0]).length()
	for r: int in range(1, 4):
		for dy: int in range(-r, r + 1):
			for dx: int in range(-r, r + 1):
				var yy := y + dy
				var xx := x + dx
				if yy < 0 or yy >= h or xx < 0 or xx >= w:
					continue
				if String(rows[yy])[xx] != "#":
					return r
	return 4


# --- One-way ledges ----------------------------------------------------------------


static func _build_ledges(room: Room, rows: Array) -> void:
	var w := String(rows[0]).length()
	var index := 0
	for y: int in rows.size():
		var row := String(rows[y])
		var x := 0
		while x < w:
			if row[x] != "=":
				x += 1
				continue
			var x1 := x
			while x1 + 1 < w and row[x1 + 1] == "=":
				x1 += 1
			var rect := Rect2(float(x) * T, float(y) * T, float(x1 - x + 1) * T, 36.0)
			var body := StaticBody2D.new()
			body.collision_layer = ONE_WAY_LAYER
			body.collision_mask = 0
			body.add_to_group(&"one_way")
			var shape := RectangleShape2D.new()
			shape.size = rect.size
			var cs := CollisionShape2D.new()
			cs.shape = shape
			cs.position = rect.position + rect.size * 0.5
			cs.one_way_collision = true
			body.add_child(cs)
			room.add_child(body)
			LevelArt.dress_platform(room, rect, hash(room.id) + index, rect.size.x >= 8.0 * T)
			index += 1
			x = x1 + 1


# --- Hazards, gates, props ----------------------------------------------------------


static func _build_specials(room: Room, rows: Array) -> void:
	var w := String(rows[0]).length()
	for y: int in rows.size():
		var row := String(rows[y])
		var x := 0
		while x < w:
			var ch := row[x]
			match ch:
				"^":
					var x1 := x
					while x1 + 1 < w and row[x1 + 1] == "^":
						x1 += 1
					var zone := HazardZone.create(Vector2(float(x) * T, float(y) * T + 24.0), Vector2(float(x1 - x + 1) * T, 40.0))
					room.add_child(zone)
					x = x1 + 1
					continue
				"%":
					room.add_child(CrackedWall.create(Vector2(float(x) * T, float(y) * T)))
				"~":
					room.add_child(SpectralBarrier.create(Vector2(float(x) * T, float(y) * T)))
				"C":
					room.add_child(Breakable.create(Vector2(float(x) * T + T * 0.5, float(y + 1) * T)))
				"S":
					room.add_child(BouncePad.create(Vector2(float(x) * T + T * 0.5, float(y + 1) * T)))
			x += 1
