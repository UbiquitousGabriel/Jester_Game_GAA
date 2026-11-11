extends Node
## Loads every script under res://scripts and reports any that fail to compile.

func _ready() -> void:
	var bad := 0
	var files := _collect("res://scripts")
	for path: String in files:
		var s := load(path) as Script
		if s == null or not s.can_instantiate() and not path.ends_with("world_data.gd") and not path.ends_with("story.gd") and not path.ends_with("_layout.gd"):
			if s == null or not s.can_instantiate():
				print("FAILED: ", path)
				bad += 1
	print("checked %d scripts, %d failed" % [files.size(), bad])
	get_tree().quit(1 if bad > 0 else 0)


func _collect(dir: String) -> Array[String]:
	var out: Array[String] = []
	for f: String in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir + "/" + f)
	for d: String in DirAccess.get_directories_at(dir):
		out.append_array(_collect(dir + "/" + d))
	return out
