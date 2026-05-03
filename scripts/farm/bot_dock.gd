@tool
class_name BotDock
extends Node2D

func _draw() -> void:
	# Base platform
	draw_rect(Rect2(-24, -8, 48, 16), Color(0.22, 0.18, 0.12))
	draw_rect(Rect2(-24, -8, 48, 16), Color(0.42, 0.32, 0.18), false, 1.5)
	# Charging bay indent
	draw_rect(Rect2(-12, -6, 24, 12), Color(0.10, 0.09, 0.08))
	draw_rect(Rect2(-12, -6, 24, 12), Color(0.28, 0.55, 0.28), false, 1.0)
	# Status light
	draw_circle(Vector2(18, -10), 3.5, Color(0.25, 0.9, 0.25))
	draw_circle(Vector2(18, -10), 3.5, Color(1.0, 1.0, 1.0), false, 0.5)
	# Label
	draw_string(ThemeDB.fallback_font, Vector2(-23, -12),
		"BOT DOCK", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.5, 0.85, 0.5))
