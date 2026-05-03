class_name BlockEditor
extends Control

const BH    := 32.0   # block body height
const BUMP  := 8.0    # bump / notch tab height
const NX    := 10.0   # tab x offset
const NW    := 22.0   # tab width
const SLOT  := BH + BUMP  # vertical step per connected block
const SNAP  := 22.0   # snap radius
const TBW   := 150.0  # toolbox width
const IND   := 18.0   # C-block inner indent

const DEFS := [
	{c="move_forward", l="move forward",  cat="Motion",  col=Color(0.28,0.47,0.92), a=[]},
	{c="turn_right",   l="turn right",    cat="Motion",  col=Color(0.28,0.47,0.92), a=[]},
	{c="turn_left",    l="turn left",     cat="Motion",  col=Color(0.28,0.47,0.92), a=[]},
	{c="face",         l="face",          cat="Motion",  col=Color(0.28,0.47,0.92),
		a=[{t="opts", opts=["right","left","up","down"], v="right"}]},
	{c="home",         l="home",          cat="Motion",  col=Color(0.28,0.47,0.92), a=[]},
	{c="set_tool",     l="set tool",      cat="Tool",    col=Color(0.88,0.52,0.15),
		a=[{t="opts", opts=["plow","seeder","harvester","fertilizer","ph_up","ph_down"], v="plow"}]},
	{c="use_tool",     l="use tool",      cat="Tool",    col=Color(0.88,0.52,0.15), a=[]},
	{c="wait",         l="wait secs",     cat="Control", col=Color(0.80,0.60,0.08),
		a=[{t="num", v="1"}]},
	{c="repeat",       l="repeat",        cat="Control", col=Color(0.80,0.60,0.08),
		a=[{t="num", v="8"}], wrap=true},
	{c="repeat_inf",   l="repeat forever",cat="Control", col=Color(0.80,0.60,0.08),
		a=[], wrap=true},
	{c="set_field",    l="set field",     cat="Setup",   col=Color(0.32,0.68,0.32),
		a=[{t="str", v="field"}]},
	{c="set_home",     l="set home",      cat="Setup",   col=Color(0.32,0.68,0.32),
		a=[{t="num", v="0"}, {t="num", v="0"}]},
	{c="print_val",    l="print",         cat="Setup",   col=Color(0.32,0.68,0.32),
		a=[{t="str", v="hello"}]},
]

# ── Block ─────────────────────────────────────────────────────────────────────
class Block extends Control:
	var cmd    := ""
	var lbl    := ""
	var col    := Color.WHITE
	var is_wrap := false
	var _adef: Array = []
	var _actrl: Array = []

	var next_b        # Block or null  — sequence below
	var prev_b        # Block or null  — sequence above
	var inner_first   # Block or null  — first block inside C

	static func make(d: Dictionary) -> Block:
		var b        := Block.new()
		b.cmd        = d.c
		b.lbl        = d.l
		b.col        = d.col
		b.is_wrap    = d.get("wrap", false)
		b._adef      = d.get("a", [])
		b.mouse_filter = Control.MOUSE_FILTER_PASS
		b._build_args()
		b._refresh_size()
		return b

	# ── arg controls ──────────────────────────────────────────────────────────
	func _build_args() -> void:
		for ad in _adef:
			var ctrl: Control
			if ad.t == "opts":
				var ob := OptionButton.new()
				for opt in (ad.opts as Array):
					ob.add_item(opt)
				ob.add_theme_font_size_override("font_size", 10)
				ob.custom_minimum_size = Vector2(78, 22)
				ob.mouse_filter = Control.MOUSE_FILTER_STOP
				ctrl = ob
			else:
				var le := LineEdit.new()
				le.text = str(ad.v)
				le.add_theme_font_size_override("font_size", 11)
				le.custom_minimum_size = Vector2(36 if ad.t == "num" else 54, 22)
				le.mouse_filter = Control.MOUSE_FILTER_STOP
				ctrl = le
			add_child(ctrl)
			_actrl.append(ctrl)

	func _refresh_size() -> void:
		var w := _calc_w()
		if is_wrap:
			var ih = max(_inner_h(), 36.0)
			custom_minimum_size = Vector2(w, BUMP + BH + ih + BH * 0.55 + BUMP)
		else:
			custom_minimum_size = Vector2(w, BUMP + BH + BUMP)
		size = custom_minimum_size
		_place_args()

	func _calc_w() -> float:
		var lw := ThemeDB.fallback_font.get_string_size(
			lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		var w := 8.0 + lw + 4.0
		for ctrl in _actrl:
			w += ctrl.custom_minimum_size.x + 5.0
		return max(w + 8.0, 118.0)

	func _place_args() -> void:
		var lw := ThemeDB.fallback_font.get_string_size(
			lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		var x := 8.0 + lw + 6.0
		var cy := BUMP + (BH - 22.0) * 0.5
		for ctrl in _actrl:
			ctrl.position = Vector2(x, cy)
			x += ctrl.custom_minimum_size.x + 5.0

	# ── heights ───────────────────────────────────────────────────────────────
	func _inner_h() -> float:
		var h := 0.0
		var cur = inner_first
		while cur:
			h += (cur as Block)._slot_h()
			cur = (cur as Block).next_b
		return h

	func _slot_h() -> float:
		if is_wrap: return _total_h()
		return SLOT

	func _total_h() -> float:
		if is_wrap: return BUMP + BH + max(_inner_h(), 36.0) + BH * 0.55 + BUMP
		return BUMP + BH + BUMP

	# ── connection points (workspace-local) ───────────────────────────────────
	func snap_top_local() -> Vector2:
		return position + Vector2(NX + NW * 0.5, 0.0)

	func snap_bot_local() -> Vector2:
		return position + Vector2(NX + NW * 0.5, _total_h())

	func inner_rect_global() -> Rect2:
		if not is_wrap: return Rect2()
		return Rect2(global_position + Vector2(IND, BUMP + BH),
					 Vector2(size.x - IND, max(_inner_h(), 36.0)))

	# ── draw ──────────────────────────────────────────────────────────────────
	func _draw() -> void:
		var w := size.x
		var cd := col.darkened(0.28)
		if is_wrap:
			_draw_c(w, cd)
		else:
			_draw_flat(w, cd)
		draw_string(ThemeDB.fallback_font,
			Vector2(8.0, BUMP + BH * 0.67),
			lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)

	func _draw_flat(w: float, cd: Color) -> void:
		if prev_b != null:
			# top notch
			draw_rect(Rect2(0,    0, NX,              BUMP), col)
			draw_rect(Rect2(NX+NW,0, w - NX - NW,    BUMP), col)
		else:
			draw_rect(Rect2(0, 0, w, BUMP), col)
		draw_rect(Rect2(0, BUMP, w, BH), col)
		# bottom bump
		if next_b != null or prev_b == null:
			_bump(w, BUMP + BH, col, cd)
		else:
			draw_rect(Rect2(0, BUMP + BH, w, BUMP), col)
		_outline_flat(w, cd)

	func _outline_flat(w: float, cd: Color) -> void:
		var h := BUMP + BH + (BUMP if (next_b != null or prev_b == null) else BUMP)
		draw_line(Vector2(0,0), Vector2(0,h), cd, 1.0)
		draw_line(Vector2(w,0), Vector2(w,h), cd, 1.0)

	func _draw_c(w: float, cd: Color) -> void:
		var ih:     float = max(_inner_h(), 36.0)
		var fh:     float = BH * 0.55
		var body_y: float = BUMP + BH
		var foot_y: float = body_y + ih

		# header
		if prev_b != null:
			draw_rect(Rect2(0,    0, NX,           BUMP), col)
			draw_rect(Rect2(NX+NW,0, w-NX-NW,     BUMP), col)
		else:
			draw_rect(Rect2(0, 0, w, BUMP), col)
		draw_rect(Rect2(0, BUMP, w, BH), col)

		# left arm + inner area
		draw_rect(Rect2(0,   body_y, IND, ih), col)
		draw_rect(Rect2(IND, body_y, w - IND, ih), col.darkened(0.38))
		if inner_first == null:
			draw_string(ThemeDB.fallback_font, Vector2(IND + 6, body_y + 22),
				"← blocks here", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.6,0.6,0.6))

		# footer + bottom bump
		draw_rect(Rect2(0, foot_y, w, fh), col)
		_bump(w, foot_y + fh, col, cd)

		# outline
		draw_line(Vector2(0,0), Vector2(0, foot_y+fh+BUMP), cd, 1.0)
		draw_line(Vector2(w,0), Vector2(w, foot_y+fh+BUMP), cd, 1.0)

	func _bump(w: float, y: float, c: Color, cd: Color) -> void:
		draw_rect(Rect2(0,    y, NX,          BUMP), c)
		draw_rect(Rect2(NX,   y, NW,          BUMP), c)
		draw_rect(Rect2(NX+NW,y, w-NX-NW,    BUMP), c)
		draw_line(Vector2(NX,   y), Vector2(NX,   y+BUMP), cd, 1.0)
		draw_line(Vector2(NX,   y+BUMP), Vector2(NX+NW, y+BUMP), cd, 1.0)
		draw_line(Vector2(NX+NW,y+BUMP), Vector2(NX+NW, y),      cd, 1.0)

	# ── code gen ──────────────────────────────────────────────────────────────
	func to_script(indent: int) -> String:
		var p  := "  ".repeat(indent)
		var av := _arg_vals()
		var ln: String
		match cmd:
			"move_forward": ln = "move_forward()"
			"turn_right":   ln = "turn_right()"
			"turn_left":    ln = "turn_left()"
			"face":         ln = 'face("%s")' % av[0]
			"home":         ln = "home()"
			"set_tool":     ln = 'set_tool("%s")' % av[0]
			"use_tool":     ln = "use_tool()"
			"wait":         ln = "wait(%s)" % av[0]
			"repeat":       ln = "repeat(%s)" % av[0]
			"repeat_inf":   ln = "repeat"
			"set_field":    ln = 'set_field("%s")' % av[0]
			"set_home":     ln = "set_home(%s, %s)" % [av[0], av[1]]
			"print_val":    ln = 'print("%s")' % av[0]
			_:              ln = "-- " + cmd
		var out := p + ln + "\n"
		if is_wrap:
			var cur = inner_first
			while cur:
				out += (cur as Block).to_script(indent + 1)
				cur = (cur as Block).next_b
			out += p + "end\n"
		if next_b:
			out += (next_b as Block).to_script(indent)
		return out

	func _arg_vals() -> Array:
		var v: Array = []
		for ctrl in _actrl:
			if ctrl is OptionButton:
				v.append((ctrl as OptionButton).get_item_text(
					(ctrl as OptionButton).selected))
			else:
				v.append((ctrl as LineEdit).text)
		return v

# ── BlockEditor vars ──────────────────────────────────────────────────────────
var _workspace: Control
var _all_blocks: Array = []
var _dragging: Block  = null
var _drag_stack: Array = []  # block + all next_b while dragging
var _drag_offset: Vector2

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()

# ── UI build ──────────────────────────────────────────────────────────────────
func _build_ui() -> void:
	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 0)
	add_child(hbox)

	# Toolbox
	var tb_scroll := ScrollContainer.new()
	tb_scroll.custom_minimum_size = Vector2(TBW, 0)
	tb_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tb_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hbox.add_child(tb_scroll)

	var tb_bg := PanelContainer.new()
	tb_bg.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var tb_sb := StyleBoxFlat.new()
	tb_sb.bg_color = Color(0.10, 0.10, 0.12)
	tb_bg.add_theme_stylebox_override("panel", tb_sb)
	tb_scroll.add_child(tb_bg)

	var tb_margin := MarginContainer.new()
	for s in ["left","right","top","bottom"]:
		tb_margin.add_theme_constant_override("margin_" + s, 6)
	tb_bg.add_child(tb_margin)

	var tb_vb := VBoxContainer.new()
	tb_vb.add_theme_constant_override("separation", 4)
	tb_margin.add_child(tb_vb)

	var cur_cat := ""
	for def in DEFS:
		if def.cat != cur_cat:
			cur_cat = def.cat
			var cl := Label.new()
			cl.text = cur_cat.to_upper()
			cl.add_theme_font_size_override("font_size", 9)
			cl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.50))
			if tb_vb.get_child_count() > 0:
				tb_vb.add_child(HSeparator.new())
			tb_vb.add_child(cl)
		tb_vb.add_child(_make_proto_btn(def))

	hbox.add_child(VSeparator.new())

	# Workspace
	var ws_scroll := ScrollContainer.new()
	ws_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ws_scroll.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	hbox.add_child(ws_scroll)

	_workspace = Control.new()
	_workspace.custom_minimum_size = Vector2(2000, 1500)
	_workspace.mouse_filter = Control.MOUSE_FILTER_PASS
	var ws_bg := StyleBoxFlat.new()
	ws_bg.bg_color = Color(0.11, 0.11, 0.13)
	_workspace.add_theme_stylebox_override("panel", ws_bg)
	ws_scroll.add_child(_workspace)

func _make_proto_btn(def: Dictionary) -> Button:
	var btn := Button.new()
	btn.text = def.l
	btn.add_theme_font_size_override("font_size", 11)
	btn.add_theme_color_override("font_color", Color.WHITE)
	var sb := StyleBoxFlat.new()
	sb.bg_color = (def.col as Color)
	sb.set_corner_radius_all(3)
	sb.content_margin_left   = 8
	sb.content_margin_right  = 8
	sb.content_margin_top    = 4
	sb.content_margin_bottom = 4
	btn.add_theme_stylebox_override("normal", sb)
	var sbh := sb.duplicate() as StyleBoxFlat
	sbh.bg_color = (def.col as Color).lightened(0.2)
	btn.add_theme_stylebox_override("hover", sbh)
	btn.pressed.connect(_spawn_from_toolbox.bind(def))
	return btn

# ── Spawning ──────────────────────────────────────────────────────────────────
func _spawn_from_toolbox(def: Dictionary) -> void:
	var ws_pos := _workspace.get_local_mouse_position()
	var b := _spawn(def, ws_pos)
	call_deferred("_start_drag", b, get_global_mouse_position())

func _spawn(def: Dictionary, at: Vector2) -> Block:
	var b := Block.make(def) as Block
	b.position = at
	_workspace.add_child(b)
	_all_blocks.append(b)
	return b

# ── Input / drag ──────────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if not visible: return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				var ws_pos := _workspace.get_local_mouse_position()
				var hit := _block_at(ws_pos)
				if hit:
					if mb.shift_pressed:
						_delete_block(hit)
					else:
						_start_drag(hit, mb.global_position)
					get_viewport().set_input_as_handled()
			else:
				if _dragging:
					_finish_drag()
					get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion and _dragging != null:
		var ws_pos := _workspace.get_local_mouse_position()
		var top_block := _drag_stack[0] as Block
		top_block.position = ws_pos - _drag_offset
		_layout_drag_stack()
		get_viewport().set_input_as_handled()

func _block_at(ws_pos: Vector2) -> Block:
	# Iterate in reverse (top-most drawn last)
	for i in range(_all_blocks.size() - 1, -1, -1):
		var b := _all_blocks[i] as Block
		if Rect2(b.position, b.size).has_point(ws_pos):
			return b
	return null

func _start_drag(block: Block, global_mouse: Vector2) -> void:
	_detach(block)
	_dragging = block
	_drag_stack = _collect_stack(block)
	_drag_offset = _workspace.get_local_mouse_position() - block.position
	# Bring drag stack to front
	for b in _drag_stack:
		_workspace.move_child(b as Block, _workspace.get_child_count() - 1)

func _collect_stack(top: Block) -> Array:
	var arr: Array = []
	var cur = top
	while cur:
		arr.append(cur)
		cur = (cur as Block).next_b
	return arr

func _layout_drag_stack() -> void:
	if _drag_stack.is_empty(): return
	var top := _drag_stack[0] as Block
	var y := top.position.y
	for blk in _drag_stack:
		var b := blk as Block
		b.position = Vector2(top.position.x, y)
		y += b._slot_h()

func _finish_drag() -> void:
	var top := _drag_stack[0] as Block
	_try_snap(top)
	_dragging = null
	_drag_stack = []
	_refresh_all()

func _try_snap(block: Block) -> void:
	var top_pt := block.snap_top_local()
	var bot_pt := block.snap_bot_local()
	var best_dist := SNAP
	var best_target: Block = null
	var snap_mode := ""   # "below" = connect block below target; "above" = connect target below block

	for b in _all_blocks:
		var candidate := b as Block
		if _drag_stack.has(candidate): continue

		# Check if candidate's bottom connects to block's top
		var d1 := candidate.snap_bot_local().distance_to(top_pt)
		if d1 < best_dist:
			best_dist = d1
			best_target = candidate
			snap_mode = "below_target"

		# Check if block's bottom connects to candidate's top
		var d2 := bot_pt.distance_to(candidate.snap_top_local())
		if d2 < best_dist:
			best_dist = d2
			best_target = candidate
			snap_mode = "above_target"

	if best_target == null:
		# Check C-block inner area
		for b in _all_blocks:
			var cb := b as Block
			if not cb.is_wrap or _drag_stack.has(cb): continue
			if cb.inner_rect_global().has_point(block.global_position + Vector2(NX + NW*0.5, BUMP)):
				_set_inner(cb, block)
				return

	if best_target == null: return

	if snap_mode == "below_target":
		# Displace any existing next_b of target
		var displaced = best_target.next_b
		_link(best_target, block)
		# Attach displaced to end of dragged stack
		if displaced:
			var stack_tail := _drag_stack[-1] as Block
			_link(stack_tail, displaced as Block)
	else:
		# block goes above best_target — best_target becomes next of block's tail
		var stack_tail := _drag_stack[-1] as Block
		if best_target.prev_b:
			_link(best_target.prev_b as Block, block)
		else:
			block.prev_b = null
		_link(stack_tail, best_target)

	_layout_from_root(_find_root(block))

func _find_root(b: Block) -> Block:
	var cur = b
	while (cur as Block).prev_b != null:
		cur = (cur as Block).prev_b
	return cur as Block

func _link(a: Block, b: Block) -> void:
	a.next_b = b
	b.prev_b = a

func _detach(block: Block) -> void:
	var pb = block.prev_b
	var nb = block.next_b
	# Only detach the single block; nb moves with it (becomes part of drag stack)
	if pb:
		(pb as Block).next_b = null
		block.prev_b = null
	# Also detach from C-block inner
	for b in _all_blocks:
		var cb := b as Block
		if cb.is_wrap and cb.inner_first == block:
			cb.inner_first = nb
			if nb: (nb as Block).prev_b = null
			block.next_b = null
			cb._refresh_size()
			cb.queue_redraw()
			return

func _set_inner(c_block: Block, first: Block) -> void:
	if c_block.inner_first:
		# Append to end of existing inner sequence
		var tail = c_block.inner_first
		while (tail as Block).next_b:
			tail = (tail as Block).next_b
		_link(tail as Block, first)
	else:
		c_block.inner_first = first
		first.prev_b = null
	c_block._refresh_size()
	c_block.queue_redraw()
	# Position inside
	var ip := c_block.position + Vector2(IND, BUMP + BH)
	first.position = ip
	_layout_from_root(first)

func _layout_from_root(root: Block) -> void:
	var pos := root.position
	var cur: Block = root
	while cur:
		cur._refresh_size()
		cur.position = pos
		cur.queue_redraw()
		pos.y += cur._slot_h()
		cur = cur.next_b as Block

func _delete_block(block: Block) -> void:
	_detach(block)
	# Collect full stack from this block
	var to_delete := _collect_stack(block)
	for b in to_delete:
		var blk := b as Block
		_all_blocks.erase(blk)
		blk.queue_free()

func _refresh_all() -> void:
	for b in _all_blocks:
		(b as Block)._refresh_size()
		(b as Block).queue_redraw()

# ── Code generation ───────────────────────────────────────────────────────────
func generate_script() -> String:
	var roots: Array = []
	for b in _all_blocks:
		var blk := b as Block
		if blk.prev_b == null and not _is_inner(blk):
			roots.append(blk)
	# Sort roots top-to-bottom by y position
	roots.sort_custom(func(a: Block, b: Block) -> bool: return a.position.y < b.position.y)
	var out := ""
	for r in roots:
		out += (r as Block).to_script(0)
	return out

func _is_inner(b: Block) -> bool:
	for blk in _all_blocks:
		var cb := blk as Block
		if cb.is_wrap and cb.inner_first != null:
			var cur = cb.inner_first
			while cur:
				if cur == b: return true
				cur = (cur as Block).next_b
	return false
