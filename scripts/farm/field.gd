@tool
class_name Field
extends Node2D

const CELL_SIZE := 16

enum State { BARE, PLOWED, SEEDED, GROWING, READY }
enum Tool { NONE, PLOW, SEEDER, HARVESTER, PH_UP, PH_DOWN, FERTILIZER }

const TRANSITIONS: Dictionary = {
	State.BARE:   { Tool.PLOW:      State.PLOWED },
	State.PLOWED: { Tool.SEEDER:    State.SEEDED },
	State.READY:  { Tool.HARVESTER: State.BARE   },
}

const GROW_TIME_1 := 90.0   # SEEDED -> GROWING
const GROW_TIME_2 := 150.0  # GROWING -> READY  (4 min total)

const COLORS: Dictionary = {
	State.BARE:    Color(0.55, 0.30, 0.10),
	State.PLOWED:  Color(0.35, 0.18, 0.06),
	State.SEEDED:  Color(0.32, 0.16, 0.06),
	State.GROWING: Color(0.52, 0.75, 0.27),
	State.READY:   Color(0.85, 0.72, 0.18),
}

@export var field_name: String = "field"

@export var width: int = 24:
	set(v):
		width = v
		_initialize_field()
		queue_redraw()

@export var height: int = 16:
	set(v):
		height = v
		_initialize_field()
		queue_redraw()

var _cells: Dictionary = {}
var _grow_timers: Dictionary = {}
var _ph: Dictionary = {}
var _nutrition: Dictionary = {}

signal cell_changed(cell: Vector2i, new_state: State)

func _ready() -> void:
	_initialize_field()
	if not Engine.is_editor_hint() and not field_name.is_empty():
		FarmRegistry.register(field_name, self)
		NetworkManager.register_field(self)

func _exit_tree() -> void:
	if not Engine.is_editor_hint() and not field_name.is_empty():
		FarmRegistry.unregister(field_name)
		NetworkManager.unregister_field(self)

func _initialize_field() -> void:
	_cells.clear()
	_grow_timers.clear()
	_ph.clear()
	_nutrition.clear()
	for x in width:
		for y in height:
			var c := Vector2i(x, y)
			_cells[c] = State.BARE
			_ph[c] = 7.0
			_nutrition[c] = 50.0

func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _grow_timers.is_empty():
		return
	var finished: Array[Vector2i] = []
	for cell in _grow_timers:
		_grow_timers[cell] -= delta
		if _grow_timers[cell] <= 0.0:
			finished.append(cell)
	for cell in finished:
		_grow_timers.erase(cell)
		var current := get_state(cell)
		if current == State.SEEDED:
			_set_state(cell, State.GROWING)
			_grow_timers[cell] = GROW_TIME_2
		elif current == State.GROWING:
			_set_state(cell, State.READY)
			_nutrition[cell] = maxf(_nutrition.get(cell, 50.0) - 15.0, 0.0)

func apply_tool(cell: Vector2i, tool: Tool) -> bool:
	match tool:
		Tool.PH_UP:
			_ph[cell] = minf(_ph.get(cell, 7.0) + 0.5, 14.0)
			cell_changed.emit(cell, get_state(cell))
			return true
		Tool.PH_DOWN:
			_ph[cell] = maxf(_ph.get(cell, 7.0) - 0.5, 0.0)
			cell_changed.emit(cell, get_state(cell))
			return true
		Tool.FERTILIZER:
			_nutrition[cell] = minf(_nutrition.get(cell, 50.0) + 20.0, 100.0)
			cell_changed.emit(cell, get_state(cell))
			return true
	var current := get_state(cell)
	if not TRANSITIONS.has(current):
		return false
	if not TRANSITIONS[current].has(tool):
		return false
	var next: State = TRANSITIONS[current][tool]
	_set_state(cell, next)
	if next == State.SEEDED:
		_grow_timers[cell] = GROW_TIME_1
	elif next == State.BARE:
		_grow_timers.erase(cell)
	return true

func get_ph(cell: Vector2i) -> float:
	return _ph.get(cell, 7.0)

func get_nutrition(cell: Vector2i) -> float:
	return _nutrition.get(cell, 50.0)

func count_cells_in_state(state: State) -> int:
	var n := 0
	for cell in _cells:
		if _cells[cell] == state:
			n += 1
	return n

func average_nutrition() -> float:
	if _nutrition.is_empty(): return 50.0
	var sum := 0.0
	for cell in _nutrition:
		sum += _nutrition[cell]
	return sum / _nutrition.size()

func average_ph() -> float:
	if _ph.is_empty(): return 7.0
	var sum := 0.0
	for cell in _ph:
		sum += _ph[cell]
	return sum / _ph.size()

func get_state(cell: Vector2i) -> State:
	return _cells.get(cell, State.BARE)

func is_valid_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < width and cell.y >= 0 and cell.y < height

func world_to_cell(world_pos: Vector2) -> Vector2i:
	var local := to_local(world_pos)
	return Vector2i(int(local.x / CELL_SIZE), int(local.y / CELL_SIZE))

func cell_to_world(cell: Vector2i) -> Vector2:
	return to_global(Vector2(cell.x * CELL_SIZE, cell.y * CELL_SIZE))

func cell_center_world(cell: Vector2i) -> Vector2:
	return to_global(Vector2((cell.x + 0.5) * CELL_SIZE, (cell.y + 0.5) * CELL_SIZE))

func bounds_world() -> Rect2:
	return Rect2(to_global(Vector2.ZERO), Vector2(width * CELL_SIZE, height * CELL_SIZE))

func _set_state(cell: Vector2i, state: State) -> void:
	_cells[cell] = state
	cell_changed.emit(cell, state)
	queue_redraw()

func _draw() -> void:
	for cell in _cells:
		var state: State = _cells[cell]
		draw_rect(
			Rect2(cell.x * CELL_SIZE, cell.y * CELL_SIZE, CELL_SIZE - 1, CELL_SIZE - 1),
			COLORS[state]
		)
	draw_rect(Rect2(0, 0, width * CELL_SIZE, height * CELL_SIZE), Color.WHITE, false, 1.0)
