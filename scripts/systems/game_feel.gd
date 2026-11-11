extends Node
## Autoload. Global impact feedback: hit-stop and screen-shake requests.
##
## Hit-stop slows Engine.time_scale for a short real-time window. Physics still
## advances in fixed steps, so gameplay stays deterministic.

signal shake_requested(strength: float)

const HITSTOP_TIME_SCALE: float = 0.05
const MAX_HITSTOP: float = 0.25

## Player setting: 0 turns screen shake off, 1 is full strength.
var shake_scale: float = 1.0
## Tests switch this off so simulated frames are not slowed down.
var hitstop_enabled: bool = true

var _hitstop_until_msec: int = 0
var _in_hitstop: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func hitstop(duration: float) -> void:
	if not hitstop_enabled or duration <= 0.0:
		return
	var until := Time.get_ticks_msec() + int(minf(duration, MAX_HITSTOP) * 1000.0)
	_hitstop_until_msec = maxi(_hitstop_until_msec, until)
	_in_hitstop = true
	Engine.time_scale = HITSTOP_TIME_SCALE


func shake(strength: float) -> void:
	if strength > 0.0 and shake_scale > 0.0:
		shake_requested.emit(strength * shake_scale)


## Brief slow motion (boss kills, big chains). Real-time duration.
func slow_motion(scale: float, duration: float) -> void:
	if not hitstop_enabled:
		return
	Engine.time_scale = scale
	_in_hitstop = true
	_hitstop_until_msec = maxi(_hitstop_until_msec, Time.get_ticks_msec() + int(duration * 1000.0))


func _process(_delta: float) -> void:
	if _in_hitstop and Time.get_ticks_msec() >= _hitstop_until_msec:
		_in_hitstop = false
		Engine.time_scale = 1.0
