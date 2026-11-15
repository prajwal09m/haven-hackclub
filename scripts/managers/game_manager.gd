extends Node
class_name GameManager

signal game_paused(paused: bool)

func set_game_paused(paused: bool) -> void:
	if get_tree().paused == paused:
		return
	get_tree().paused = paused
	game_paused.emit(paused)

func toggle_pause() -> void:
	set_game_paused(!get_tree().paused)

func is_game_paused() -> bool:
	return get_tree().paused
