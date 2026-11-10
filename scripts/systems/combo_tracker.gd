extends Node
## Autoload. Tracks the current hit chain.
##
## Every hammer hit and every enemy-to-enemy collision extends the chain. The
## chain drops when no hit lands within `chain_window` seconds.

signal chain_changed(count: int)
signal chain_ended(final_count: int)

var chain_window: float = 2.5
var chain: int = 0
var best_chain: int = 0

var _time_left: float = 0.0


func register_hit(amount: int = 1) -> void:
	chain += amount
	best_chain = maxi(best_chain, chain)
	_time_left = chain_window
	chain_changed.emit(chain)


func reset() -> void:
	if chain > 0:
		chain_ended.emit(chain)
	chain = 0
	_time_left = 0.0
	chain_changed.emit(0)


func get_time_ratio() -> float:
	if chain_window <= 0.0:
		return 0.0
	return clampf(_time_left / chain_window, 0.0, 1.0)


func _physics_process(delta: float) -> void:
	if chain == 0:
		return
	_time_left -= delta
	if _time_left <= 0.0:
		reset()
