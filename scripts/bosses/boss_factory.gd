class_name BossFactory
extends RefCounted
## Boss by id (see GameState.BOSSES).


static func create(id: StringName) -> Boss:
	match id:
		&"ringmaster":
			return Ringmaster.new()
		&"executioner":
			return Executioner.new()
		&"mourning_bell":
			return MourningBell.new()
		&"acrobat_twins":
			return AcrobatTwins.new()
		&"colossus":
			return Colossus.new()
		&"king":
			return King.new()
	push_warning("Unknown boss %s" % id)
	return Ringmaster.new()
