@tool
class_name FarmBot
extends Node2D

@export var move_duration: float = 0.8
@export var work_duration: float = 0.7
@export var turn_duration: float = 0.4

@export var field: Field
@export var home_cell: Vector2i = Vector2i(0, 0)
@export var active_tool: Field.Tool = Field.Tool.SEEDER

var _current_cell: Vector2i
var _player_in_range := false
var facing := Vector2i(0, -1)  # up
var _is_working := false
var current_script: String = ""
var log_history: Array[String] = []

signal command_done
signal log_output(text: String)
signal terminal_open_requested

func _ready() -> void:
	_current_cell = home_cell
	rotation = 0.0
	if field:
		global_position = field.cell_center_world(_current_cell)
	if Engine.is_editor_hint():
		return
	NetworkManager.register_bot(self)
	var runner := $BotRunner as BotRunner
	var terminal := $BotTerminal as BotTerminal
	if terminal and runner:
		terminal.setup(self, runner)
	terminal_open_requested.connect($BotTerminal.toggle)

func _exit_tree() -> void:
	if not Engine.is_editor_hint():
		NetworkManager.unregister_bot(self)

func load_script(code: String) -> void:
	current_script = code
	var terminal := $BotTerminal as BotTerminal
	if terminal:
		terminal.load_script(code)

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
	var body_color := Color.ORANGE if _is_working else Color.CYAN
	draw_rect(Rect2(-8, -8, 16, 16), body_color)
	draw_rect(Rect2(-8, -8, 16, 16), Color.WHITE, false, 1.5)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -10), Vector2(-4, -2), Vector2(4, -2),
	]), Color.WHITE)

# ── Bot API ─────────────────────────────────────────────────────────────────
# Every function must emit command_done when finished (even on failure).
# Sync functions await one process frame so the runner's await is ready first.

func bot_move_to(x: int, y: int) -> void:
	var target := Vector2i(x, y)
	if not field or not field.is_valid_cell(target):
		_log("move_to: invalid cell (%d, %d)" % [x, y])
		await get_tree().process_frame
		command_done.emit()
		return
	_current_cell = target
	var tween := create_tween()
	tween.tween_property(self, "global_position", field.cell_center_world(target), move_duration)
	await tween.finished
	command_done.emit()

func bot_use_tool() -> void:
	_is_working = true
	queue_redraw()
	if field:
		var ok := field.apply_tool(_current_cell, active_tool)
		if not ok:
			_log("use_tool at (%d,%d): wrong state" % [_current_cell.x, _current_cell.y])
	await get_tree().create_timer(work_duration).timeout
	_is_working = false
	queue_redraw()
	command_done.emit()

func bot_home() -> void:
	await bot_move_to(home_cell.x, home_cell.y)

func bot_face(direction: String) -> void:
	match direction.to_lower():
		"up":    facing = Vector2i(0, -1);  rotation = 0.0
		"right": facing = Vector2i(1, 0);   rotation = PI / 2.0
		"down":  facing = Vector2i(0, 1);   rotation = PI
		"left":  facing = Vector2i(-1, 0);  rotation = -PI / 2.0
		_: _log("face: unknown direction '%s'" % direction)
	queue_redraw()
	await get_tree().process_frame
	command_done.emit()

func bot_move_forward() -> void:
	await bot_move_to(_current_cell.x + facing.x, _current_cell.y + facing.y)

func bot_turn_right() -> void:
	facing = Vector2i(-facing.y, facing.x)
	var tween := create_tween()
	tween.tween_property(self, "rotation", rotation + PI / 2.0, turn_duration)
	await tween.finished
	command_done.emit()

func bot_turn_left() -> void:
	facing = Vector2i(facing.y, -facing.x)
	var tween := create_tween()
	tween.tween_property(self, "rotation", rotation - PI / 2.0, turn_duration)
	await tween.finished
	command_done.emit()

func bot_wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
	command_done.emit()

func bot_set_tool(tool_name: String) -> void:
	match tool_name.to_lower():
		"plow":       active_tool = Field.Tool.PLOW
		"seeder":     active_tool = Field.Tool.SEEDER
		"harvester":  active_tool = Field.Tool.HARVESTER
		"ph_up":      active_tool = Field.Tool.PH_UP
		"ph_down":    active_tool = Field.Tool.PH_DOWN
		"fertilizer": active_tool = Field.Tool.FERTILIZER
		_: _log("set_tool: unknown '%s'" % tool_name)
	await get_tree().process_frame
	command_done.emit()

func bot_get_state(x: int, y: int) -> void:
	if field:
		var s := field.get_state(Vector2i(x, y))
		_log("state(%d,%d) = %s" % [x, y, Field.State.keys()[s]])
	await get_tree().process_frame
	command_done.emit()

func bot_check_ph(x: int, y: int) -> void:
	if field:
		_log("pH(%d,%d) = %.1f" % [x, y, field.get_ph(Vector2i(x, y))])
	await get_tree().process_frame
	command_done.emit()

func bot_check_nutrition(x: int, y: int) -> void:
	if field:
		_log("nutrition(%d,%d) = %.1f" % [x, y, field.get_nutrition(Vector2i(x, y))])
	await get_tree().process_frame
	command_done.emit()

func bot_set_field(name: String) -> void:
	var f := FarmRegistry.get_field(name)
	if f:
		field = f
		_log("Field set to '%s'" % name)
	else:
		var known := ", ".join(FarmRegistry.list())
		_log("Field '%s' not found. Known fields: %s" % [name, known if known else "(none)"])
	await get_tree().process_frame
	command_done.emit()

func bot_set_home(x: int, y: int) -> void:
	home_cell = Vector2i(x, y)
	_log("Home set to (%d, %d)" % [x, y])
	await get_tree().process_frame
	command_done.emit()

func bot_print(msg) -> void:
	_log(str(msg))
	await get_tree().process_frame
	command_done.emit()

func _log(text: String) -> void:
	log_output.emit(text)
	log_history.append(text)
	if log_history.size() > 200:
		log_history.pop_front()
