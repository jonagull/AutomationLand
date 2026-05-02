## Temporary debug helper — attach to the Player node to test the field.
## 1 = Plow, 2 = Seed, 3 = Harvest
extends Node

@export var field: Field

func _unhandled_input(event: InputEvent) -> void:
	if not field:
		return
	var player := get_parent() as CharacterBody2D
	if not player:
		return
	var cell := field.world_to_cell(player.global_position)
	if not field.is_valid_cell(cell):
		return
	if event.is_action_pressed("ui_select"):   # Space
		_try_tool(cell, Field.Tool.PLOW, "Plow")
	elif event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1: _try_tool(cell, Field.Tool.PLOW,      "Plow")
			KEY_2: _try_tool(cell, Field.Tool.SEEDER,    "Seed")
			KEY_3: _try_tool(cell, Field.Tool.HARVESTER, "Harvest")

func _try_tool(cell: Vector2i, tool: Field.Tool, label: String) -> void:
	var ok := field.apply_tool(cell, tool)
	print("%s at %s: %s" % [label, cell, "ok" if ok else "wrong state"])
