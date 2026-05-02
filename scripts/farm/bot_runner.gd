class_name BotRunner
extends Node

var _bot: FarmBot
var _running := false
var _vars: Dictionary = {}
var _funcs: Dictionary = {}

signal started
signal stopped
signal parse_error(line_number: int, message: String)

func _ready() -> void:
	_bot = get_parent() as FarmBot

func start(script_text: String) -> void:
	if _running:
		return
	var program := _parse_program(script_text)
	if program == null:
		return
	_running = true
	_vars.clear()
	_funcs.clear()
	_collect_funcs(program)
	started.emit()
	_run(program)

func stop() -> void:
	_running = false
	stopped.emit()

func execute_line(line: String) -> void:
	if _running:
		return
	var program := _parse_program(line)
	if program == null or program.is_empty():
		return
	_running = true
	_vars.clear()
	_funcs.clear()
	_collect_funcs(program)
	started.emit()
	_run_immediate(program)

func _run_immediate(program: Array) -> void:
	await _execute_block(program)
	if _running:
		_running = false
		stopped.emit()

func _run(program: Array) -> void:
	_bot.callv("bot_home", [])
	await _bot.command_done
	await _execute_block(program)
	if _running:
		_running = false
		stopped.emit()

func _collect_funcs(block: Array) -> void:
	for item in block:
		if item.get("type") == "func_def":
			_funcs[item["name"]] = item

# ── Execution ────────────────────────────────────────────────────────────────

func _execute_block(block: Array) -> void:
	for item in block:
		if not _running:
			return
		match item.get("type", ""):
			"func_def":
				pass
			"assign":
				_vars[item["var_name"]] = _eval_expr(item["expr"])
			"repeat":
				var cnt = item["count"]
				if cnt is String:
					cnt = _eval_expr(cnt)
				if cnt is float:
					cnt = int(cnt)
				if cnt < 0:
					while _running:
						await _execute_block(item["body"])
				else:
					for _i in cnt:
						if not _running:
							return
						await _execute_block(item["body"])
			"if":
				var executed := false
				for branch in item["branches"]:
					if _eval_cond(branch["cond"]):
						await _execute_block(branch["body"])
						executed = true
						break
				if not executed and item.has("else_body"):
					await _execute_block(item["else_body"])
			"cmd":
				var name: String = item["name"]
				var method: String = "bot_" + name
				if _bot.has_method(method):
					_bot.callv(method, _resolve_args(item["args"]))
					await _bot.command_done
				elif _funcs.has(name):
					await _execute_block(_funcs[name]["body"])
				else:
					parse_error.emit(item.get("line", -1), "Unknown command: " + name)

func _resolve_args(args: Array) -> Array:
	var result := []
	for a in args:
		if a is String:
			var v = _eval_expr(a)
			result.append(int(v) if (v is float and int(v) == v) else v)
		else:
			result.append(a)
	return result

# ── Expression evaluator ─────────────────────────────────────────────────────

func _eval_cond(cond: String) -> bool:
	cond = cond.strip_edges()
	for op in ["==", "!=", ">=", "<=", ">", "<"]:
		var idx := _find_cmp_op(cond, op)
		if idx >= 0:
			var lhs = _eval_expr(cond.substr(0, idx).strip_edges())
			var rhs = _eval_expr(cond.substr(idx + op.length()).strip_edges())
			match op:
				"==": return _vals_eq(lhs, rhs)
				"!=": return not _vals_eq(lhs, rhs)
				">=": return _to_f(lhs) >= _to_f(rhs)
				"<=": return _to_f(lhs) <= _to_f(rhs)
				">":  return _to_f(lhs) > _to_f(rhs)
				"<":  return _to_f(lhs) < _to_f(rhs)
	var v = _eval_expr(cond)
	if v is bool: return v
	if v is int or v is float: return v != 0
	if v is String: return not v.is_empty() and v != "false" and v != "0"
	return false

func _vals_eq(a, b) -> bool:
	if a is String and b is String:
		return (a as String).to_lower() == (b as String).to_lower()
	return a == b

func _to_f(v) -> float:
	if v is float: return v
	if v is int: return float(v)
	if v is String: return float(v) if (v as String).is_valid_float() else 0.0
	return 0.0

func _eval_expr(expr: String) -> Variant:
	expr = expr.strip_edges()
	if expr.is_empty(): return null

	if (expr.begins_with('"') and expr.ends_with('"')) or \
	   (expr.begins_with("'") and expr.ends_with("'")):
		return expr.substr(1, expr.length() - 2)

	if expr.to_lower() == "true": return true
	if expr.to_lower() == "false": return false
	if expr.to_lower() == "null": return null
	if expr.is_valid_int(): return int(expr)
	if expr.is_valid_float(): return float(expr)

	# Function call
	var paren := expr.find("(")
	if paren > 0 and expr.ends_with(")"):
		var fname := expr.substr(0, paren).strip_edges()
		var astr := expr.substr(paren + 1, expr.length() - paren - 2).strip_edges()
		return _call_query(fname, _split_args(astr))

	# Additive (lower precedence — split rightmost first for left-assoc)
	for op in ["+", "-"]:
		var idx := _rfind_arith(expr, op)
		if idx > 0:
			var lv = _eval_expr(expr.substr(0, idx))
			var rv = _eval_expr(expr.substr(idx + 1))
			if lv is String or rv is String:
				if op == "+": return str(lv) + str(rv)
				continue
			if op == "+": return _to_f(lv) + _to_f(rv)
			return _to_f(lv) - _to_f(rv)

	# Multiplicative
	for op in ["*", "/"]:
		var idx := _rfind_arith(expr, op)
		if idx > 0:
			var lv = _eval_expr(expr.substr(0, idx))
			var rv = _eval_expr(expr.substr(idx + 1))
			var rf := _to_f(rv)
			if op == "*": return _to_f(lv) * rf
			return _to_f(lv) / rf if rf != 0.0 else 0.0

	# Unary minus
	if expr.begins_with("-") and expr.length() > 1:
		var inner = _eval_expr(expr.substr(1))
		if inner is int: return -inner
		if inner is float: return -inner

	if _vars.has(expr): return _vars[expr]
	return expr

func _rfind_arith(expr: String, op: String) -> int:
	var depth := 0
	var i := expr.length() - 1
	while i >= 0:
		match expr[i]:
			")": depth += 1
			"(": depth -= 1
			_:
				if depth == 0 and expr[i] == op and i > 0:
					return i
		i -= 1
	return -1

func _find_cmp_op(s: String, op: String) -> int:
	var depth := 0
	var ol := op.length()
	var i := 0
	while i <= s.length() - ol:
		var c := s[i]
		if c == "(":
			depth += 1
		elif c == ")":
			depth -= 1
		elif depth == 0 and s.substr(i, ol) == op:
			if ol == 1 and (op == ">" or op == "<"):
				var nxt := s[i + 1] if i + 1 < s.length() else ""
				if nxt == "=":
					i += 1
					continue
			return i
		i += 1
	return -1

func _split_args(s: String) -> Array:
	var result: Array = []
	if s.is_empty(): return result
	var depth := 0
	var cur := ""
	for ch in s:
		if ch == "(": depth += 1
		elif ch == ")": depth -= 1
		elif ch == "," and depth == 0:
			result.append(cur.strip_edges())
			cur = ""
			continue
		cur += ch
	if not cur.strip_edges().is_empty():
		result.append(cur.strip_edges())
	return result

func _call_query(fname: String, raw: Array) -> Variant:
	match fname.to_lower():
		"get_state":
			if not _bot.field: return "BARE"
			return Field.State.keys()[_bot.field.get_state(_bot._current_cell)]
		"get_ph":
			if not _bot.field: return 7.0
			return _bot.field.get_ph(_bot._current_cell)
		"get_nutrition":
			if not _bot.field: return 50.0
			return _bot.field.get_nutrition(_bot._current_cell)
		"get_posx":
			return _bot._current_cell.x
		"get_posy":
			return _bot._current_cell.y
	return null

# ── Parser ───────────────────────────────────────────────────────────────────

func _parse_program(script_text: String) -> Array:
	var lines := script_text.split("\n")
	var code_stack: Array = [[]]
	var block_stack: Array = []

	for i in lines.size():
		var raw: String = lines[i].strip_edges()
		var ci := raw.find("--")
		if ci == 0: continue
		if ci > 0: raw = raw.substr(0, ci).strip_edges()
		if raw.is_empty(): continue
		var lower := raw.to_lower()

		if lower.begins_with("func "):
			var fname := _parse_func_name(raw)
			if fname.is_empty():
				parse_error.emit(i + 1, "Invalid func declaration")
				return []
			var node := {type="func_def", name=fname, body=[], line=i+1}
			code_stack[-1].append(node)
			code_stack.append(node["body"])
			block_stack.append({kind="func", node=node})

		elif lower.begins_with("repeat"):
			var count := _parse_repeat_count(raw)
			var node := {type="repeat", count=count, body=[], line=i+1}
			code_stack[-1].append(node)
			code_stack.append(node["body"])
			block_stack.append({kind="repeat", node=node})

		elif lower.begins_with("if "):
			var cond := raw.substr(3).strip_edges()
			var node := {type="if", branches=[{cond=cond, body=[]}], line=i+1}
			code_stack[-1].append(node)
			code_stack.append(node["branches"][0]["body"])
			block_stack.append({kind="if", node=node})

		elif lower.begins_with("elseif "):
			if block_stack.is_empty() or not ["if","elseif"].has(block_stack[-1]["kind"]):
				parse_error.emit(i + 1, "Unexpected 'elseif'")
				return []
			var cond := raw.substr(7).strip_edges()
			var if_node: Dictionary = block_stack[-1]["node"]
			code_stack.pop_back()
			var branch := {cond=cond, body=[]}
			if_node["branches"].append(branch)
			code_stack.append(branch["body"])
			block_stack.pop_back()
			block_stack.append({kind="elseif", node=if_node})

		elif lower == "else":
			if block_stack.is_empty() or not ["if","elseif"].has(block_stack[-1]["kind"]):
				parse_error.emit(i + 1, "Unexpected 'else'")
				return []
			var if_node: Dictionary = block_stack[-1]["node"]
			code_stack.pop_back()
			if_node["else_body"] = []
			code_stack.append(if_node["else_body"])
			block_stack.pop_back()
			block_stack.append({kind="else", node=if_node})

		elif lower == "end":
			if block_stack.is_empty():
				parse_error.emit(i + 1, "Unexpected 'end'")
				return []
			code_stack.pop_back()
			block_stack.pop_back()

		elif lower.begins_with("var "):
			var rest := raw.substr(4).strip_edges()
			var eq := rest.find("=")
			if eq < 0:
				code_stack[-1].append({type="assign", var_name=rest, expr="null", line=i+1})
			else:
				code_stack[-1].append({
					type = "assign",
					var_name = rest.substr(0, eq).strip_edges(),
					expr = rest.substr(eq + 1).strip_edges(),
					line = i + 1
				})

		elif _is_assignment(raw):
			var eq := raw.find("=")
			code_stack[-1].append({
				type = "assign",
				var_name = raw.substr(0, eq).strip_edges(),
				expr = raw.substr(eq + 1).strip_edges(),
				line = i + 1
			})

		else:
			var cmd := _parse_line(raw)
			if cmd.is_empty():
				parse_error.emit(i + 1, "Could not parse: " + raw)
				return []
			cmd["type"] = "cmd"
			cmd["line"] = i + 1
			code_stack[-1].append(cmd)

	if code_stack.size() > 1:
		parse_error.emit(-1, "Unclosed block — missing 'end'")
		return []
	return code_stack[0]

func _is_assignment(line: String) -> bool:
	var eq := line.find("=")
	if eq <= 0: return false
	if line[eq - 1] in ["!", "<", ">", "="]: return false
	if eq + 1 < line.length() and line[eq + 1] == "=": return false
	return line.substr(0, eq).strip_edges().is_valid_identifier()

func _parse_func_name(line: String) -> String:
	var rest := line.substr(5).strip_edges()
	var paren := rest.find("(")
	if paren >= 0: rest = rest.substr(0, paren).strip_edges()
	var space := rest.find(" ")
	return rest.substr(0, space) if space >= 0 else rest

func _parse_repeat_count(line: String) -> int:
	var paren := line.find("(")
	if paren == -1:
		var parts := line.split(" ", false)
		if parts.size() < 2: return -1
		var s: String = parts[1].strip_edges()
		return int(s) if s.is_valid_int() else -1
	var close := line.rfind(")")
	var s: String = line.substr(paren + 1, close - paren - 1).strip_edges()
	if s.is_empty(): return -1
	return int(s) if s.is_valid_int() else 1

func _parse_line(line: String) -> Dictionary:
	var paren := line.find("(")
	if paren == -1:
		var parts := line.split(" ", false)
		if parts.is_empty(): return {}
		return {name = parts[0], args = _coerce(parts.slice(1))}
	var name := line.substr(0, paren).strip_edges()
	var close := line.rfind(")")
	if close == -1: return {}
	var args_str := line.substr(paren + 1, close - paren - 1).strip_edges()
	var raw: Array = []
	if not args_str.is_empty():
		for a: String in args_str.split(","):
			raw.append(a.strip_edges())
	return {name = name, args = _coerce(raw)}

func _coerce(raw: Array) -> Array:
	var result := []
	for r in raw:
		var s := str(r)
		if s.is_valid_int():
			result.append(int(s))
		elif s.is_valid_float():
			result.append(float(s))
		elif (s.begins_with('"') and s.ends_with('"')) or (s.begins_with("'") and s.ends_with("'")):
			result.append(s.substr(1, s.length() - 2))
		else:
			result.append(s)
	return result
