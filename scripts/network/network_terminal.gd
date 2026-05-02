class_name NetworkTerminal
extends Node2D

var _player_in_range := false

signal terminal_open_requested

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	terminal_open_requested.connect($NetworkTerminalUI.toggle)

func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if _player_in_range and event.is_action_pressed("interact"):
		terminal_open_requested.emit()
		get_viewport().set_input_as_handled()

func _on_interaction_area_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		_player_in_range = true

func _on_interaction_area_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D:
		_player_in_range = false

func _draw() -> void:
	# Desk surface
	draw_rect(Rect2(-14, -4, 30, 12), Color(0.28, 0.20, 0.13))
	draw_rect(Rect2(-14, -4, 30, 12), Color(0.38, 0.28, 0.18), false, 1.0)

	# PC tower (right of desk)
	draw_rect(Rect2(10, -14, 7, 11), Color(0.20, 0.20, 0.24))
	draw_rect(Rect2(10, -14, 7, 11), Color(0.42, 0.42, 0.52), false, 1.0)
	draw_rect(Rect2(12, -12, 3, 1), Color(0.55, 0.55, 0.62))  # disc drive slot
	draw_rect(Rect2(12, -10, 2, 2), Color(0.15, 0.85, 0.25))  # power LED

	# Monitor frame
	draw_rect(Rect2(-13, -20, 21, 15), Color(0.18, 0.18, 0.22))
	draw_rect(Rect2(-13, -20, 21, 15), Color(0.45, 0.45, 0.55), false, 1.0)
	# Screen (dark with green glow)
	draw_rect(Rect2(-11, -18, 17, 11), Color(0.02, 0.07, 0.03))
	# Text lines on screen
	draw_rect(Rect2(-9, -16, 12, 1), Color(0.22, 0.88, 0.30, 0.95))
	draw_rect(Rect2(-9, -14, 9, 1),  Color(0.22, 0.78, 0.30, 0.75))
	draw_rect(Rect2(-9, -12, 13, 1), Color(0.22, 0.78, 0.30, 0.60))
	draw_rect(Rect2(-9, -10, 6, 1),  Color(0.22, 0.78, 0.30, 0.50))
	# Blinking cursor
	draw_rect(Rect2(-9, -10, 2, 1),  Color(0.45, 1.0, 0.55))
	# Monitor neck + base
	draw_rect(Rect2(-3, -5, 4, 3), Color(0.20, 0.20, 0.24))
	draw_rect(Rect2(-6, -2, 10, 2), Color(0.20, 0.20, 0.24))

	# Keyboard
	draw_rect(Rect2(-12, -2, 17, 5), Color(0.16, 0.16, 0.19))
	draw_rect(Rect2(-12, -2, 17, 5), Color(0.36, 0.36, 0.44), false, 0.8)
	# Key rows (small dots)
	for i in 5:
		draw_rect(Rect2(-10 + i * 3, -1, 2, 1), Color(0.30, 0.30, 0.38))
		draw_rect(Rect2(-10 + i * 3,  1, 2, 1), Color(0.30, 0.30, 0.38))
	# Space bar
	draw_rect(Rect2(-6, 3, 9, 1), Color(0.30, 0.30, 0.38))
