extends Node

var _bots: Array = []
var _fields: Array = []

func register_bot(bot) -> void:
	if not _bots.has(bot):
		_bots.append(bot)

func unregister_bot(bot) -> void:
	_bots.erase(bot)

func get_bots() -> Array:
	return _bots

func register_field(field) -> void:
	if not _fields.has(field):
		_fields.append(field)

func unregister_field(field) -> void:
	_fields.erase(field)

func get_fields() -> Array:
	return _fields
