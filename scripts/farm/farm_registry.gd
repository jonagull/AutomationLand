extends Node

var _fields: Dictionary = {}  # name -> Field

func register(field_name: String, field: Field) -> void:
	_fields[field_name] = field

func unregister(field_name: String) -> void:
	_fields.erase(field_name)

func get_field(field_name: String) -> Field:
	return _fields.get(field_name, null)

func list() -> Array:
	return _fields.keys()
