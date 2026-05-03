extends Node2D

const ZOOM_MIN  := 0.5
const ZOOM_MAX  := 5.0
const ZOOM_STEP := 1.15

@onready var _camera: Camera2D = $Player/Camera2D

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton): return
	var mb := event as InputEventMouseButton
	if not mb.pressed: return
	match mb.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			_adjust_zoom(ZOOM_STEP)
			get_viewport().set_input_as_handled()
		MOUSE_BUTTON_WHEEL_DOWN:
			_adjust_zoom(1.0 / ZOOM_STEP)
			get_viewport().set_input_as_handled()

func _adjust_zoom(factor: float) -> void:
	if not _camera: return
	var z := clampf(_camera.zoom.x * factor, ZOOM_MIN, ZOOM_MAX)
	_camera.zoom = Vector2(z, z)
