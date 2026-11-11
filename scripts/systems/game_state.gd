extends Node
## Autoload. Everything that persists across rooms and sessions: abilities,
## charms, hearts, bells, collectibles, map knowledge, bosses, story flags,
## the last shrine. Saved as JSON in user://save_<slot>.json.

signal changed
signal ability_unlocked(id: StringName)
signal bells_changed(amount: int)

const SAVE_VERSION := 1
const SLOTS := 3
const BASE_HEARTS := 5
const PIECES_PER_HEART := 4
const CHARM_SLOTS := 3

## Abilities in the order the castle hands them out.
const ABILITIES := {
	&"glide": {
		"name": "Hammer Twirl",
		"boss": &"ringmaster",
		"text": "Press Jump again in the air and hold to twirl the hammer: glide over chasms and spin through foes.",
	},
	&"vault": {
		"name": "Hammer Vault",
		"boss": &"executioner",
		"text": "Hold Down and press Heavy on the ground to plant the hammer and vault over tall walls.",
	},
	&"slam": {
		"name": "Cracking Slam",
		"boss": &"mourning_bell",
		"text": "A fully charged Heavy now shatters cracked stone and sends out a shockwave.",
	},
	&"wallkick": {
		"name": "Wall Bounce",
		"boss": &"acrobat_twins",
		"text": "Jump while touching a wall to bounce off it. Climb shafts by bouncing between walls.",
	},
	&"ghost_dash": {
		"name": "Phantom Step",
		"boss": &"colossus",
		"text": "Your dash now slips through spectral barriers, and you cannot be hurt mid-dash.",
	},
}

## Passive charms. Equip up to CHARM_SLOTS at a shrine.
const CHARMS := {
	&"rubber_nose": {"name": "Rubber Nose", "price": 120, "text": "Pogo bounces go 20% higher."},
	&"juggler_gloves": {"name": "Juggler's Gloves", "price": 180, "text": "Air swings hang longer and bounce higher."},
	&"lucky_bell": {"name": "Lucky Bell", "price": 150, "text": "Foes drop half again as many bells, and bells fly to you."},
	&"heavy_head": {"name": "Heavy Head", "price": 260, "text": "Charged hits and air finishers deal +1 damage."},
	&"spring_heels": {"name": "Spring Heels", "price": 140, "text": "Jump 12% higher."},
	&"cartwheel": {"name": "Cartwheel", "price": 160, "text": "Dashes travel farther."},
	&"thick_skull": {"name": "Thick Skull", "price": 220, "text": "Longer invulnerability after being hit."},
	&"pratfall": {"name": "Pratfall", "price": 200, "text": "Landing hard sends out a small shockwave."},
	&"encore": {"name": "Encore", "price": 300, "text": "Chains of 10+ hits restore a heart (once per chain)."},
}

const BOSSES := {
	&"ringmaster": "The Ringmaster",
	&"executioner": "The Executioner",
	&"mourning_bell": "The Mourning Bell",
	&"acrobat_twins": "The Acrobat Twins",
	&"colossus": "The Clockwork Colossus",
	&"king": "The King",
}

var slot: int = 0
var abilities: Dictionary[StringName, bool] = {}
var charms_owned: Dictionary[StringName, bool] = {}
var charms_equipped: Array[StringName] = []
var heart_pieces: int = 0
var bells: int = 0
var picked: Dictionary[String, bool] = {}
var visited: Dictionary[String, bool] = {}
var bosses: Dictionary[StringName, bool] = {}
var jokes: Dictionary[String, bool] = {}
var flags: Dictionary[String, bool] = {}
var shrine_room: String = ""
var shrine_position: Vector2 = Vector2.ZERO
var play_time: float = 0.0
var deaths: int = 0
var playing: bool = false


func _process(delta: float) -> void:
	if playing and not get_tree().paused:
		play_time += delta


# --- Queries ----------------------------------------------------------------------


func has(ability: StringName) -> bool:
	return abilities.get(ability, false)


func has_charm(charm: StringName) -> bool:
	return charms_equipped.has(charm)


func max_hearts() -> int:
	return BASE_HEARTS + heart_pieces / PIECES_PER_HEART


func is_picked(id: String) -> bool:
	return picked.get(id, false)


func boss_defeated(id: StringName) -> bool:
	return bosses.get(id, false)


func all_seals() -> bool:
	for id: StringName in BOSSES:
		if id != &"king" and not boss_defeated(id):
			return false
	return true


func completion_percent() -> float:
	var total := 0.0
	var got := 0.0
	total += ABILITIES.size() * 4.0
	got += abilities.size() * 4.0
	total += BOSSES.size() * 3.0
	got += bosses.size() * 3.0
	total += float(WorldData.HEART_PIECE_COUNT)
	got += float(heart_pieces)
	total += float(WorldData.JOKE_COUNT)
	got += float(jokes.size())
	total += CHARMS.size()
	got += charms_owned.size()
	return 100.0 * got / maxf(total, 1.0)


# --- Changes ----------------------------------------------------------------------


func unlock(ability: StringName) -> void:
	if has(ability):
		return
	abilities[ability] = true
	ability_unlocked.emit(ability)
	changed.emit()


func add_bells(amount: int) -> void:
	bells = maxi(bells + amount, 0)
	bells_changed.emit(bells)


func pick(id: String) -> void:
	picked[id] = true
	changed.emit()


func add_heart_piece() -> bool:
	## Returns true when the piece completed a new heart.
	heart_pieces += 1
	changed.emit()
	return heart_pieces % PIECES_PER_HEART == 0


func toggle_charm(charm: StringName) -> bool:
	if not charms_owned.get(charm, false):
		return false
	if charms_equipped.has(charm):
		charms_equipped.erase(charm)
	elif charms_equipped.size() < CHARM_SLOTS:
		charms_equipped.append(charm)
	else:
		return false
	changed.emit()
	return true


func set_shrine(room_id: String, position: Vector2) -> void:
	shrine_room = room_id
	shrine_position = position


# --- Save slots -------------------------------------------------------------------


func new_game(new_slot: int) -> void:
	slot = new_slot
	abilities.clear()
	charms_owned.clear()
	charms_equipped.clear()
	heart_pieces = 0
	bells = 0
	picked.clear()
	visited.clear()
	bosses.clear()
	jokes.clear()
	flags.clear()
	shrine_room = WorldData.START_ROOM
	shrine_position = WorldData.START_POSITION
	play_time = 0.0
	deaths = 0
	changed.emit()


func save() -> void:
	var data := {
		"version": SAVE_VERSION,
		"abilities": abilities.keys(),
		"charms_owned": charms_owned.keys(),
		"charms_equipped": charms_equipped,
		"heart_pieces": heart_pieces,
		"bells": bells,
		"picked": picked.keys(),
		"visited": visited.keys(),
		"bosses": bosses.keys(),
		"jokes": jokes.keys(),
		"flags": flags.keys(),
		"shrine_room": shrine_room,
		"shrine_position": [shrine_position.x, shrine_position.y],
		"play_time": play_time,
		"deaths": deaths,
	}
	var file := FileAccess.open(_path(slot), FileAccess.WRITE)
	if file == null:
		push_error("Could not write save slot %d" % slot)
		return
	file.store_string(JSON.stringify(data))


func load_slot(which: int) -> bool:
	var data := peek(which)
	if data.is_empty():
		return false
	new_game(which)
	for id: String in data.get("abilities", []):
		abilities[StringName(id)] = true
	for id: String in data.get("charms_owned", []):
		charms_owned[StringName(id)] = true
	for id: String in data.get("charms_equipped", []):
		charms_equipped.append(StringName(id))
	heart_pieces = int(data.get("heart_pieces", 0))
	bells = int(data.get("bells", 0))
	for id: String in data.get("picked", []):
		picked[id] = true
	for id: String in data.get("visited", []):
		visited[id] = true
	for id: String in data.get("bosses", []):
		bosses[StringName(id)] = true
	for id: String in data.get("jokes", []):
		jokes[id] = true
	for id: String in data.get("flags", []):
		flags[id] = true
	shrine_room = String(data.get("shrine_room", WorldData.START_ROOM))
	if not WorldData.ROOMS.has(shrine_room):
		shrine_room = WorldData.START_ROOM
	var pos: Array = data.get("shrine_position", [WorldData.START_POSITION.x, WorldData.START_POSITION.y])
	shrine_position = Vector2(float(pos[0]), float(pos[1]))
	play_time = float(data.get("play_time", 0.0))
	deaths = int(data.get("deaths", 0))
	changed.emit()
	return true


## Summary of a slot for the title screen; empty when the slot is unused.
func peek(which: int) -> Dictionary:
	if not FileAccess.file_exists(_path(which)):
		return {}
	var text := FileAccess.get_file_as_string(_path(which))
	var data: Variant = JSON.parse_string(text)
	if data is Dictionary:
		return data
	return {}


func erase_slot(which: int) -> void:
	if FileAccess.file_exists(_path(which)):
		DirAccess.remove_absolute(_path(which))


func _path(which: int) -> String:
	return "user://save_%d.json" % which
