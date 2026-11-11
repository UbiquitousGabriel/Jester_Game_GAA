class_name Room
extends Node2D
## One built room of the castle. Holds its data, world rectangle and the
## things the Game needs to query (doors, boss, safe spots).

signal boss_started(boss: Node)
signal boss_finished(boss: Node)

var id: String = ""
var area: String = ""
var kind: String = ""
var data: Dictionary = {}
var rect: Rect2 = Rect2()
## side + index -> neighbour room id
var doors: Dictionary[String, String] = {}
var boss: Node = null
var _locks: Array[Node] = []


func cell_size() -> Vector2:
	return Vector2(WorldData.CELL.x * WorldData.TILE, WorldData.CELL.y * WorldData.TILE)


## Neighbour room through the edge the player crossed, or "" if none.
func door_target(side: String, world_pos: Vector2) -> String:
	var cs := cell_size()
	var local := world_pos - rect.position
	var index := 0
	if side == "L" or side == "R":
		index = clampi(int(floor((local.y - 4.0) / cs.y)), 0, int(rect.size.y / cs.y) - 1)
	else:
		index = clampi(int(floor(local.x / cs.x)), 0, int(rect.size.x / cs.x) - 1)
	return doors.get("%s%d" % [side, index], "")


## Seals every door with a barrier while a boss fight runs.
func lock_doors() -> void:
	for door: Array in data.get("doors", []):
		var barrier := BossBarrier.create(_door_rect(String(door[0]), int(door[1])))
		add_child(barrier)
		_locks.append(barrier)


func unlock_doors() -> void:
	for lock: Node in _locks:
		if is_instance_valid(lock):
			(lock as BossBarrier).open()
	_locks.clear()


func _door_rect(side: String, index: int) -> Rect2:
	var t := float(WorldData.TILE)
	var cs := cell_size()
	var size := rect.size
	match side:
		"L":
			return Rect2(0.0, index * cs.y + 12.0 * t, 2.0 * t, 5.0 * t)
		"R":
			return Rect2(size.x - 2.0 * t, index * cs.y + 12.0 * t, 2.0 * t, 5.0 * t)
		"U":
			return Rect2(index * cs.x + 15.0 * t, 0.0, 6.0 * t, 2.0 * t)
		_:
			return Rect2(index * cs.x + 15.0 * t, size.y - 3.0 * t, 6.0 * t, 3.0 * t)
