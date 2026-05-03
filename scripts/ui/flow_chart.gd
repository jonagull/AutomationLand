class_name FlowChart
extends Control

const NW   := 155.0
const NH   := 56.0
const PR   := 7.0
const PHIT := PR + 6.0

# ── Wire canvas overlay ───────────────────────────────────────────────────────
class WireCanvas extends Control:
	var fc  # FlowChart — untyped to avoid circular reference
	func _draw() -> void:
		if fc:
			fc._draw_wires(self)

# ── Flow node ─────────────────────────────────────────────────────────────────
class FlowNode extends Control:
	var ntype: String  = ""
	var col:   Color   = Color.GRAY
	var _arg:  Control = null
	var out_conns: Dictionary = {}  # port_name -> FlowNode

	static func make(t: String, pos: Vector2) -> FlowNode:
		var n           := FlowNode.new()
		n.ntype         = t
		n.col           = FlowNode.col_for(t)
		n.custom_minimum_size = Vector2(NW, NH)
		n.size          = Vector2(NW, NH)
		n.position      = pos - Vector2(NW * 0.5, NH * 0.5)
		n.mouse_filter  = Control.MOUSE_FILTER_PASS
		n._build_arg()
		return n

	static func col_for(t: String) -> Color:
		if   t == "start":    return Color(0.18, 0.58, 0.22)
		elif t == "end":      return Color(0.65, 0.18, 0.18)
		elif t == "command":  return Color(0.22, 0.40, 0.80)
		elif t == "decision": return Color(0.72, 0.54, 0.05)
		elif t == "loop":     return Color(0.70, 0.38, 0.05)
		return Color.GRAY

	func _build_arg() -> void:
		if ntype == "command":
			var ob := OptionButton.new()
			for cmd in [
				"move_forward", "turn_right", "turn_left", "use_tool", "home",
				'face("right")', 'face("left")', 'face("up")', 'face("down")',
				'set_tool("plow")', 'set_tool("seeder")',
				'set_tool("harvester")', 'set_tool("fertilizer")',
				"wait(1)", "wait(5)", "wait(30)",
			]:
				ob.add_item(cmd)
			ob.add_theme_font_size_override("font_size", 9)
			ob.custom_minimum_size = Vector2(NW - 8, 20)
			ob.position            = Vector2(4, NH - 26)
			ob.mouse_filter        = Control.MOUSE_FILTER_STOP
			add_child(ob)
			_arg = ob
		elif ntype == "decision":
			var le := LineEdit.new()
			le.text                = "get_nutrition() < 30"
			le.add_theme_font_size_override("font_size", 9)
			le.custom_minimum_size = Vector2(NW - 8, 20)
			le.position            = Vector2(4, NH - 26)
			le.mouse_filter        = Control.MOUSE_FILTER_STOP
			add_child(le)
			_arg = le
		elif ntype == "loop":
			var le := LineEdit.new()
			le.text                = "8"
			le.placeholder_text    = "count (empty=∞)"
			le.add_theme_font_size_override("font_size", 9)
			le.custom_minimum_size = Vector2(NW - 8, 20)
			le.position            = Vector2(4, NH - 26)
			le.mouse_filter        = Control.MOUSE_FILTER_STOP
			add_child(le)
			_arg = le

	func has_in() -> bool:
		return ntype != "start"

	func out_names() -> Array:
		if ntype == "decision": return ["yes", "no"]
		if ntype == "loop":     return ["body", "done"]
		if ntype == "end":      return []
		return ["next"]

	func in_local()  -> Vector2: return Vector2(NW * 0.5, 0.0)
	func in_global() -> Vector2: return global_position + in_local()

	func out_local(p: String) -> Vector2:
		if ntype == "decision":
			return Vector2(NW * 0.28, NH) if p == "yes" else Vector2(NW * 0.72, NH)
		if ntype == "loop":
			return Vector2(NW * 0.28, NH) if p == "body" else Vector2(NW * 0.72, NH)
		return Vector2(NW * 0.5, NH)

	func out_global(p: String) -> Vector2: return global_position + out_local(p)

	func hit_out(gpos: Vector2) -> String:
		for p in out_names():
			if out_global(p).distance_to(gpos) <= PHIT:
				return p
		return ""

	func hit_in(gpos: Vector2) -> bool:
		return has_in() and in_global().distance_to(gpos) <= PHIT

	func hit_body(gpos: Vector2) -> bool:
		return Rect2(global_position, size).has_point(gpos)

	func _draw() -> void:
		var cd := col.darkened(0.28)
		if ntype == "start" or ntype == "end":
			var r: float = NH * 0.5
			draw_rect(Rect2(r, 0.0, NW - r * 2.0, NH), col)
			draw_circle(Vector2(r, r), r, col)
			draw_circle(Vector2(NW - r, r), r, col)
		else:
			draw_rect(Rect2(0.0, 0.0, NW, NH), col)
			draw_rect(Rect2(0.0, 0.0, NW, NH), cd, false, 1.5)

		var lbl: String
		if   ntype == "start":    lbl = "START"
		elif ntype == "end":      lbl = "END"
		elif ntype == "command":  lbl = "DO"
		elif ntype == "decision": lbl = "IF"
		elif ntype == "loop":     lbl = "LOOP"
		else:                     lbl = ntype.to_upper()
		draw_string(ThemeDB.fallback_font, Vector2(10.0, 15.0),
			lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)

		if has_in():
			draw_circle(in_local(), PR, Color(0.92, 0.92, 0.92))
			draw_circle(in_local(), PR, cd, false, 1.5)

		for pname in out_names():
			var p := out_local(pname)
			draw_circle(p, PR, Color(0.92, 0.92, 0.92))
			draw_circle(p, PR, cd, false, 1.5)
			if out_names().size() > 1:
				draw_string(ThemeDB.fallback_font, p + Vector2(-10.0, PR + 10.0),
					pname, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.85, 0.85, 0.85))

	func arg_val() -> String:
		if not _arg: return ""
		if _arg is OptionButton:
			return (_arg as OptionButton).get_item_text((_arg as OptionButton).selected)
		return (_arg as LineEdit).text.strip_edges()

	func script_line() -> String:
		var av := arg_val()
		if ntype == "command":
			return av if av.contains("(") else av + "()"
		if ntype == "decision":
			return "if " + av
		if ntype == "loop":
			return "repeat(%s)" % av if av.is_valid_int() else "repeat"
		return ""

# ── FlowChart vars ────────────────────────────────────────────────────────────
var _canvas:     Control
var _wire_layer: WireCanvas
var _nodes:      Array = []

# Each connection: {src: FlowNode, port: String, dst: FlowNode}
var _conns: Array = []

var _drag_node: FlowNode = null
var _drag_off:  Vector2

var _wire_src:  FlowNode = null
var _wire_port: String   = ""
var _wire_tip:  Vector2

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	_seed_nodes()

# ── UI ────────────────────────────────────────────────────────────────────────
func _make_pal_btn(parent: Control, label: String, ntype: String, col: Color) -> void:
	var btn := Button.new()
	btn.text = label
	btn.add_theme_font_size_override("font_size", 11)
	btn.add_theme_color_override("font_color", Color.WHITE)
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = col
	bsb.set_corner_radius_all(3)
	bsb.content_margin_left   = 8
	bsb.content_margin_right  = 8
	bsb.content_margin_top    = 3
	bsb.content_margin_bottom = 3
	btn.add_theme_stylebox_override("normal", bsb)
	var bsh := bsb.duplicate() as StyleBoxFlat
	bsh.bg_color = col.lightened(0.2)
	btn.add_theme_stylebox_override("hover", bsh)
	btn.pressed.connect(_add_node.bind(ntype))
	parent.add_child(btn)

func _build_ui() -> void:
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.add_theme_constant_override("separation", 0)
	add_child(vb)

	# Palette bar
	var pal_wrap := PanelContainer.new()
	var pal_bg   := StyleBoxFlat.new()
	pal_bg.bg_color = Color(0.09, 0.09, 0.11)
	pal_wrap.add_theme_stylebox_override("panel", pal_bg)
	vb.add_child(pal_wrap)

	var pal_mg := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		pal_mg.add_theme_constant_override("margin_" + s, 5)
	pal_wrap.add_child(pal_mg)

	var pal := HBoxContainer.new()
	pal.add_theme_constant_override("separation", 4)
	pal_mg.add_child(pal)

	var hint := Label.new()
	hint.text = "Drag nodes · Connect ports · Right-click to delete"
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color(0.45, 0.45, 0.5))
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pal.add_child(hint)

	_make_pal_btn(pal, "+ Start",   "start",    Color(0.18, 0.58, 0.22))
	_make_pal_btn(pal, "+ End",     "end",      Color(0.65, 0.18, 0.18))
	_make_pal_btn(pal, "+ Command", "command",  Color(0.22, 0.40, 0.80))
	_make_pal_btn(pal, "+ If",      "decision", Color(0.72, 0.54, 0.05))
	_make_pal_btn(pal, "+ Loop",    "loop",     Color(0.70, 0.38, 0.05))

	# Canvas
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(scroll)

	_canvas = Control.new()
	_canvas.custom_minimum_size = Vector2(2400, 1800)
	_canvas.mouse_filter        = Control.MOUSE_FILTER_PASS
	scroll.add_child(_canvas)

	_wire_layer = WireCanvas.new()
	_wire_layer.fc = self
	_wire_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_wire_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_wire_layer)

func _seed_nodes() -> void:
	var sn := FlowNode.make("start",   Vector2(300.0,  80.0))
	var cn := FlowNode.make("command", Vector2(300.0, 210.0))
	var en := FlowNode.make("end",     Vector2(300.0, 350.0))
	for n in [sn, cn, en]:
		_canvas.add_child(n)
		_nodes.append(n)
	_wire_layer.queue_redraw()

# ── Input ─────────────────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if not visible: return

	if event is InputEventMouseButton:
		var mb   := event as InputEventMouseButton
		var gpos := mb.global_position
		var cpos := _canvas.get_local_mouse_position()

		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				# Check output ports first
				for n in _nodes:
					var nd := n as FlowNode
					var hp := nd.hit_out(gpos)
					if hp != "":
						_wire_src  = nd
						_wire_port = hp
						_wire_tip  = cpos
						get_viewport().set_input_as_handled()
						return
				# Check node body for drag
				for i in range(_nodes.size() - 1, -1, -1):
					var nd := _nodes[i] as FlowNode
					if nd.hit_body(gpos):
						_drag_node = nd
						_drag_off  = cpos - nd.position
						_canvas.move_child(nd, _canvas.get_child_count() - 1)
						get_viewport().set_input_as_handled()
						return
			else:
				if _wire_src:
					for n in _nodes:
						var nd := n as FlowNode
						if nd == _wire_src: continue
						if nd.hit_in(gpos):
							_wire_connect(_wire_src, _wire_port, nd)
							break
					_wire_src  = null
					_wire_port = ""
					_wire_layer.queue_redraw()
					get_viewport().set_input_as_handled()
				if _drag_node:
					_drag_node = null
					get_viewport().set_input_as_handled()

		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			for i in range(_nodes.size() - 1, -1, -1):
				var nd := _nodes[i] as FlowNode
				if nd.hit_body(gpos):
					_delete_node(nd)
					get_viewport().set_input_as_handled()
					return

	elif event is InputEventMouseMotion:
		var cpos := _canvas.get_local_mouse_position()
		if _drag_node:
			_drag_node.position = cpos - _drag_off
			_wire_layer.queue_redraw()
			get_viewport().set_input_as_handled()
		elif _wire_src:
			_wire_tip = cpos
			_wire_layer.queue_redraw()
			get_viewport().set_input_as_handled()

func _wire_connect(src: FlowNode, port: String, dst: FlowNode) -> void:
	# Remove any existing connection from this port
	var kept: Array = []
	for c in _conns:
		if not (c.src == src and c.port == port):
			kept.append(c)
	_conns = kept
	src.out_conns[port] = dst
	_conns.append({"src": src, "port": port, "dst": dst})

func _delete_node(nd: FlowNode) -> void:
	var kept: Array = []
	for c in _conns:
		if c.src != nd and c.dst != nd:
			kept.append(c)
	_conns = kept
	for n in _nodes:
		var other := n as FlowNode
		for p in other.out_conns.keys():
			if other.out_conns[p] == nd:
				other.out_conns.erase(p)
	_nodes.erase(nd)
	nd.queue_free()
	_wire_layer.queue_redraw()

func _add_node(t: String) -> void:
	var cpos := _canvas.get_local_mouse_position()
	var in_canvas := Rect2(Vector2.ZERO, _canvas.size).has_point(cpos)
	var pos := cpos if in_canvas else Vector2(300.0 + _nodes.size() * 22.0, 150.0)
	var n := FlowNode.make(t, pos)
	_canvas.add_child(n)
	_nodes.append(n)
	_wire_layer.queue_redraw()

# ── Wire drawing ──────────────────────────────────────────────────────────────
func _draw_wires(layer: Control) -> void:
	for conn in _conns:
		var sn := conn.src as FlowNode
		var dn := conn.dst as FlowNode
		if not is_instance_valid(sn) or not is_instance_valid(dn): continue
		var a := sn.position + sn.out_local(conn.port)
		var b := dn.position + dn.in_local()
		_draw_bezier(layer, a, b, Color(0.80, 0.80, 0.80, 0.9))

	if _wire_src:
		var a := _wire_src.position + _wire_src.out_local(_wire_port)
		_draw_bezier(layer, a, _wire_tip, Color(1.0, 0.95, 0.4, 0.85))

func _draw_bezier(layer: Control, a: Vector2, b: Vector2, col: Color) -> void:
	var dy: float = absf(b.y - a.y)
	var cp1 := a + Vector2(0.0,  dy * 0.55)
	var cp2 := b + Vector2(0.0, -dy * 0.55)
	var prev := a
	for i in range(1, 28):
		var t := float(i) / 27.0
		var u := 1.0 - t
		var p := u*u*u*a + 3.0*u*u*t*cp1 + 3.0*u*t*t*cp2 + t*t*t*b
		layer.draw_line(prev, p, col, 2.0)
		prev = p

# ── Code generation ───────────────────────────────────────────────────────────
func generate_script() -> String:
	var start: FlowNode = null
	for n in _nodes:
		if (n as FlowNode).ntype == "start":
			start = n as FlowNode
			break
	if not start:
		return "-- No Start node found. Add one from the palette.\n"
	var visited: Dictionary = {}
	return _gen(start, 0, visited)

func _gen(node: FlowNode, indent: int, visited: Dictionary) -> String:
	if not is_instance_valid(node): return ""
	if visited.has(node): return ""
	visited[node] = true
	var p := "  ".repeat(indent)

	if node.ntype == "start":
		var nxt = node.out_conns.get("next")
		return _gen(nxt as FlowNode, indent, visited)

	if node.ntype == "end":
		return ""

	if node.ntype == "command":
		var nxt = node.out_conns.get("next")
		return p + node.script_line() + "\n" + _gen(nxt as FlowNode, indent, visited)

	if node.ntype == "decision":
		var yes_nd = node.out_conns.get("yes")
		var no_nd  = node.out_conns.get("no")
		var out := p + node.script_line() + "\n"
		out += _gen(yes_nd as FlowNode, indent + 1, visited)
		if no_nd:
			out += p + "else\n"
			out += _gen(no_nd as FlowNode, indent + 1, visited)
		out += p + "end\n"
		return out

	if node.ntype == "loop":
		var body_nd = node.out_conns.get("body")
		var done_nd = node.out_conns.get("done")
		var out := p + node.script_line() + "\n"
		out += _gen(body_nd as FlowNode, indent + 1, visited)
		out += p + "end\n"
		out += _gen(done_nd as FlowNode, indent, visited)
		return out

	return ""
