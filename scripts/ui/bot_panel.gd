class_name BotPanel
extends CanvasLayer

enum Mode { JOBS, BLOCKS, SCRIPT, FLOW }

# ── Preset job definitions ────────────────────────────────────────────────────
const JOBS := [
	{icon="🔄", name="Full Cycle",  desc="Plow → fertilise if needed → sow → wait → harvest. Loops forever.", key="full_cycle"},
	{icon="🌱", name="Plow Field",  desc="Plow every cell in the field once, then return home.",               key="plow"},
	{icon="🌾", name="Sow Seeds",   desc="Sow seeds across the whole field once.",                             key="sow"},
	{icon="🌿", name="Fertilise",   desc="Apply fertiliser to every cell once.",                               key="fertilise"},
	{icon="✂",  name="Harvest",     desc="Harvest every ready crop in the field.",                             key="harvest"},
]

# ── Jobs tab ──────────────────────────────────────────────────────────────────
var _selected_job := 0
var _job_cards: Array = []
var _jobs_view: ScrollContainer

# ── Blocks tab ────────────────────────────────────────────────────────────────
var _block_editor: BlockEditor

# ── Flow tab ──────────────────────────────────────────────────────────────────
var _flow_chart: FlowChart

# ── Script tab ────────────────────────────────────────────────────────────────
var _script_view: VBoxContainer
var _code_edit: CodeEdit
var _caret_label: Label

# ── Shared UI ─────────────────────────────────────────────────────────────────
var _run_btn: Button
var _stop_btn: Button
var _status_label: Label
var _output_log: RichTextLabel
var _jobs_tab_btn: Button
var _blocks_tab_btn: Button
var _script_tab_btn: Button
var _flow_tab_btn: Button
var _mode := Mode.JOBS

# ── Bot refs ──────────────────────────────────────────────────────────────────
var _bot: FarmBot
var _runner: BotRunner

# ── Setup ─────────────────────────────────────────────────────────────────────

func setup(bot: FarmBot, runner: BotRunner) -> void:
	_bot = bot
	_runner = runner
	_bot.log_output.connect(_append_log)
	_runner.started.connect(_on_started)
	_runner.stopped.connect(_on_stopped)
	_runner.parse_error.connect(_on_parse_error)
	_bot.current_script = _code_edit.text
	_code_edit.text_changed.connect(func() -> void: _bot.current_script = _code_edit.text)

func load_script(code: String) -> void:
	_code_edit.text = code

func _ready() -> void:
	layer = 10
	_build_ui()
	hide()

func toggle() -> void:
	if visible: hide()
	else: show()

# ── Build ─────────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.65)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
			hide()
	)
	add_child(bg)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(820, 580)
	panel.offset_left   = -410
	panel.offset_right  =  410
	panel.offset_top    = -290
	panel.offset_bottom =  290
	add_child(panel)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.11, 0.11, 0.13)
	sb.border_color = Color(0.32, 0.32, 0.42)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(5)
	panel.add_theme_stylebox_override("panel", sb)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	margin.add_child(root)

	# ── Header ────────────────────────────────────────────────────────────
	var header := HBoxContainer.new()
	root.add_child(header)

	var title := Label.new()
	title.text = "FarmBot"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.55, 1.0, 0.55))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	_status_label = Label.new()
	_status_label.text = "○  Idle"
	_status_label.add_theme_font_size_override("font_size", 11)
	_status_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(_status_label)

	var home_btn := Button.new()
	home_btn.text = "⌂  Home"
	home_btn.flat = true
	home_btn.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
	home_btn.add_theme_font_size_override("font_size", 12)
	home_btn.pressed.connect(_on_home)
	header.add_child(home_btn)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.flat = true
	close_btn.pressed.connect(hide)
	header.add_child(close_btn)

	# ── Tab bar ───────────────────────────────────────────────────────────
	var tab_bar := HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 2)
	root.add_child(tab_bar)

	_jobs_tab_btn = Button.new()
	_jobs_tab_btn.text = "Jobs"
	_jobs_tab_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_jobs_tab_btn.pressed.connect(_set_tab.bind(Mode.JOBS))
	tab_bar.add_child(_jobs_tab_btn)

	_blocks_tab_btn = Button.new()
	_blocks_tab_btn.text = "Blocks"
	_blocks_tab_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_blocks_tab_btn.pressed.connect(_set_tab.bind(Mode.BLOCKS))
	tab_bar.add_child(_blocks_tab_btn)

	_script_tab_btn = Button.new()
	_script_tab_btn.text = "Script"
	_script_tab_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_script_tab_btn.pressed.connect(_set_tab.bind(Mode.SCRIPT))
	tab_bar.add_child(_script_tab_btn)

	_flow_tab_btn = Button.new()
	_flow_tab_btn.text = "Flow"
	_flow_tab_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_flow_tab_btn.pressed.connect(_set_tab.bind(Mode.FLOW))
	tab_bar.add_child(_flow_tab_btn)

	root.add_child(HSeparator.new())

	# ── Jobs tab ──────────────────────────────────────────────────────────
	_jobs_view = ScrollContainer.new()
	_jobs_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_jobs_view.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(_jobs_view)

	var card_list := VBoxContainer.new()
	card_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_list.add_theme_constant_override("separation", 6)
	_jobs_view.add_child(card_list)

	for i in JOBS.size():
		var card := _make_job_card(JOBS[i], i)
		card_list.add_child(card)
		_job_cards.append(card)

	_refresh_job_cards()

	# ── Blocks tab ────────────────────────────────────────────────────────
	_block_editor = BlockEditor.new()
	_block_editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_block_editor.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	_block_editor.custom_minimum_size   = Vector2(0, 360)
	_block_editor.visible = false
	root.add_child(_block_editor)

	# ── Flow tab ──────────────────────────────────────────────────────────
	_flow_chart = FlowChart.new()
	_flow_chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_flow_chart.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	_flow_chart.custom_minimum_size   = Vector2(0, 360)
	_flow_chart.visible = false
	root.add_child(_flow_chart)

	# ── Script tab ────────────────────────────────────────────────────────
	_script_view = VBoxContainer.new()
	_script_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_script_view.add_theme_constant_override("separation", 4)
	_script_view.visible = false
	root.add_child(_script_view)

	_code_edit = CodeEdit.new()
	_code_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_code_edit.custom_minimum_size = Vector2(0, 260)
	_code_edit.gutters_draw_line_numbers = true
	_code_edit.gutters_draw_fold_gutter  = true
	_code_edit.auto_brace_completion_enabled = true
	_code_edit.indent_automatic = true
	_code_edit.indent_size = 2
	_code_edit.code_completion_enabled = true
	_code_edit.syntax_highlighter = _make_highlighter()
	_code_edit.text = _default_script()
	_code_edit.add_theme_font_size_override("font_size", 13)
	_style_code_edit(_code_edit)
	_code_edit.gui_input.connect(_on_code_edit_input)
	_code_edit.code_completion_requested.connect(_on_completion_requested)
	_code_edit.caret_changed.connect(_on_caret_changed)
	_script_view.add_child(_code_edit)

	_caret_label = Label.new()
	_caret_label.text = "Ln 1, Col 1   |   Ctrl+Enter = Run"
	_caret_label.add_theme_color_override("font_color", Color(0.45, 0.45, 0.55))
	_caret_label.add_theme_font_size_override("font_size", 11)
	_caret_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_script_view.add_child(_caret_label)

	root.add_child(HSeparator.new())

	# ── Action row ────────────────────────────────────────────────────────
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 4)
	root.add_child(btn_row)

	_run_btn = Button.new()
	_run_btn.text = "▶  Run"
	_run_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_run_btn.pressed.connect(_on_run)
	btn_row.add_child(_run_btn)

	_stop_btn = Button.new()
	_stop_btn.text = "■  Stop"
	_stop_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stop_btn.disabled = true
	_stop_btn.pressed.connect(_on_stop)
	btn_row.add_child(_stop_btn)

	var clear_btn := Button.new()
	clear_btn.text = "⌫  Clear"
	clear_btn.pressed.connect(func() -> void: _output_log.clear())
	btn_row.add_child(clear_btn)

	# ── Output log ────────────────────────────────────────────────────────
	_output_log = RichTextLabel.new()
	_output_log.custom_minimum_size = Vector2(0, 68)
	_output_log.bbcode_enabled = true
	_output_log.scroll_following = true
	_output_log.selection_enabled = true
	_output_log.add_theme_font_size_override("font_size", 12)
	_style_log(_output_log)
	root.add_child(_output_log)

	_update_tab_style()

# ── Job cards ─────────────────────────────────────────────────────────────────

func _make_job_card(job: Dictionary, idx: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
			_select_job(idx)
	)

	var inner := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		inner.add_theme_constant_override("margin_" + side, 8)
	card.add_child(inner)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	inner.add_child(hbox)

	var icon := Label.new()
	icon.text = job.icon
	icon.add_theme_font_size_override("font_size", 26)
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.custom_minimum_size = Vector2(32, 0)
	hbox.add_child(icon)

	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(text_col)

	var name_lbl := Label.new()
	name_lbl.text = job.name
	name_lbl.add_theme_font_size_override("font_size", 14)
	text_col.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = job.desc
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	text_col.add_child(desc_lbl)

	return card

func _select_job(idx: int) -> void:
	_selected_job = idx
	_refresh_job_cards()

func _refresh_job_cards() -> void:
	for i in _job_cards.size():
		var card := _job_cards[i] as PanelContainer
		var selected := (i == _selected_job)
		var csb := StyleBoxFlat.new()
		csb.bg_color    = Color(0.15, 0.28, 0.15) if selected else Color(0.07, 0.09, 0.07)
		csb.border_color = Color(0.4, 0.85, 0.4)
		csb.set_border_width_all(1 if selected else 0)
		csb.set_corner_radius_all(5)
		card.add_theme_stylebox_override("panel", csb)
		# name label is at: card → MarginContainer → HBoxContainer → VBoxContainer → Label[0]
		var name_lbl := card.get_child(0).get_child(0).get_child(1).get_child(0) as Label
		name_lbl.add_theme_color_override("font_color",
			Color(0.88, 1.0, 0.88) if selected else Color(0.78, 0.78, 0.78))

# ── Tab switching ─────────────────────────────────────────────────────────────

func _set_tab(mode: Mode) -> void:
	_mode = mode
	_jobs_view.visible    = (mode == Mode.JOBS)
	_block_editor.visible = (mode == Mode.BLOCKS)
	_flow_chart.visible   = (mode == Mode.FLOW)
	_script_view.visible  = (mode == Mode.SCRIPT)
	_update_tab_style()
	if mode == Mode.SCRIPT:
		_code_edit.grab_focus()

func _update_tab_style() -> void:
	for pair in [
		[_jobs_tab_btn, Mode.JOBS], [_blocks_tab_btn, Mode.BLOCKS],
		[_script_tab_btn, Mode.SCRIPT], [_flow_tab_btn, Mode.FLOW],
	]:
		var btn := pair[0] as Button
		var m: int = pair[1]
		btn.flat = (_mode != m)
		btn.add_theme_color_override("font_color",
			Color(1.0, 1.0, 1.0) if _mode == m else Color(0.5, 0.5, 0.5))

# ── Actions ───────────────────────────────────────────────────────────────────

func _on_run() -> void:
	if not _runner: return
	_clear_error_highlights()
	_output_log.clear()
	match _mode:
		Mode.JOBS:
			_runner.start(_get_job_script(JOBS[_selected_job].key))
		Mode.BLOCKS:
			_runner.start(_block_editor.generate_script())
		Mode.FLOW:
			_runner.start(_flow_chart.generate_script())
		Mode.SCRIPT:
			_runner.start(_code_edit.text)

func _on_stop() -> void:
	if _runner: _runner.stop()

func _on_home() -> void:
	if _runner: _runner.stop()
	if _bot:    _bot.return_to_dock()

# ── Runner callbacks ──────────────────────────────────────────────────────────

func _on_started() -> void:
	_run_btn.disabled  = true
	_stop_btn.disabled = false
	var job_name: String
	match _mode:
		Mode.JOBS:   job_name = JOBS[_selected_job].name
		Mode.BLOCKS: job_name = "blocks"
		Mode.FLOW:   job_name = "flow"
		_:           job_name = "script"
	_status_label.text = "●  Running — %s" % job_name
	_status_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))

func _on_stopped() -> void:
	_run_btn.disabled  = false
	_stop_btn.disabled = true
	_status_label.text = "○  Idle"
	_status_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))

# ── Log ───────────────────────────────────────────────────────────────────────

func _append_log(text: String) -> void:
	_output_log.append_text(text + "\n")

func _on_parse_error(line: int, msg: String) -> void:
	_output_log.append_text("[color=red]Line %d: %s[/color]\n" % [line, msg])
	if line > 0 and _code_edit and line <= _code_edit.get_line_count():
		_code_edit.set_line_background_color(line - 1, Color(0.7, 0.1, 0.1, 0.35))

func _clear_error_highlights() -> void:
	if not _code_edit: return
	for i in _code_edit.get_line_count():
		_code_edit.set_line_background_color(i, Color.TRANSPARENT)

# ── Code edit ─────────────────────────────────────────────────────────────────

func _on_code_edit_input(event: InputEvent) -> void:
	if not (event is InputEventKey and (event as InputEventKey).pressed): return
	var key := event as InputEventKey
	if key.keycode == KEY_ENTER and key.ctrl_pressed:
		if not _run_btn.disabled: _on_run()
		_code_edit.accept_event()
	elif key.keycode == KEY_ESCAPE:
		hide()
		_code_edit.accept_event()

func _on_caret_changed() -> void:
	_caret_label.text = "Ln %d, Col %d   |   Ctrl+Enter = Run" % [
		_code_edit.get_caret_line() + 1,
		_code_edit.get_caret_column() + 1,
	]

func _on_completion_requested() -> void:
	for kw in ["if ", "elseif ", "else", "end", "repeat", "var ", "func ", "true", "false"]:
		_code_edit.add_code_completion_option(CodeEdit.KIND_PLAIN_TEXT, kw.strip_edges(), kw)
	for cmd in ["move_forward", "turn_right", "turn_left", "face", "use_tool", "home",
				"wait", "set_tool", "set_field", "set_home", "get_state",
				"print", "check_ph", "check_nutrition", "get_posx", "get_posy"]:
		_code_edit.add_code_completion_option(CodeEdit.KIND_FUNCTION, cmd, cmd + "(")
	_code_edit.update_code_completion_options(true)

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		hide()
		get_viewport().set_input_as_handled()

# ── Styling ───────────────────────────────────────────────────────────────────

func _style_code_edit(ce: CodeEdit) -> void:
	var csb := StyleBoxFlat.new()
	csb.bg_color = Color(0.08, 0.08, 0.10)
	csb.set_border_width_all(1)
	csb.border_color = Color(0.25, 0.25, 0.35)
	csb.set_corner_radius_all(2)
	ce.add_theme_stylebox_override("normal", csb)
	ce.add_theme_stylebox_override("focus", csb)
	ce.add_theme_color_override("font_color",       Color(0.88, 0.88, 0.88))
	ce.add_theme_color_override("caret_color",      Color(0.9,  0.7,  0.3))
	ce.add_theme_color_override("selection_color",  Color(0.2,  0.4,  0.7, 0.5))
	ce.add_theme_color_override("line_number_color",Color(0.4,  0.4,  0.5))
	ce.add_theme_color_override("current_line_color",Color(1.0, 1.0,  1.0, 0.04))

func _style_log(rtl: RichTextLabel) -> void:
	var csb := StyleBoxFlat.new()
	csb.bg_color = Color(0.05, 0.07, 0.05)
	csb.set_border_width_all(1)
	csb.border_color = Color(0.2, 0.35, 0.2)
	csb.set_corner_radius_all(2)
	rtl.add_theme_stylebox_override("normal", csb)
	rtl.add_theme_color_override("default_color", Color(0.82, 0.95, 0.82))

func _make_highlighter() -> CodeHighlighter:
	var h := CodeHighlighter.new()
	h.number_color         = Color(0.85, 0.65, 0.25)
	h.symbol_color         = Color(0.75, 0.75, 0.75)
	h.function_color       = Color(0.45, 0.85, 1.0)
	h.member_variable_color = Color(0.9, 0.55, 0.35)
	for kw in ["if", "elseif", "else", "end", "repeat", "var", "func", "true", "false"]:
		h.add_keyword_color(kw, Color(0.85, 0.45, 0.85))
	for kw in ["move_forward", "turn_right", "turn_left", "face", "use_tool", "home",
			"wait", "set_tool", "set_field", "set_home", "get_state", "print",
			"check_ph", "check_nutrition", "get_posx", "get_posy"]:
		h.add_keyword_color(kw, Color(0.45, 0.85, 1.0))
	for kw in ["plow", "seeder", "harvester", "ph_up", "ph_down", "fertilizer"]:
		h.add_keyword_color(kw, Color(0.6, 0.92, 0.5))
	h.add_color_region("--", "", Color(0.45, 0.55, 0.45), true)
	h.add_color_region('"',  '"', Color(0.82, 0.92, 0.5))
	h.add_color_region("'",  "'", Color(0.82, 0.92, 0.5))
	return h

func _default_script() -> String:
	return """set_field("field")
set_home(0, 0)

func sweep()
  use_tool()
  repeat(23)
    move_forward()
    use_tool()
  end
end

func do_field()
  face("right")
  repeat(8)
    sweep()
    turn_right()
    move_forward()
    turn_right()
    sweep()
    turn_left()
    move_forward()
    turn_left()
  end
  home()
end

-- Edit your script here, then press Run
set_tool("plow")
do_field()
"""

# ── Preset job scripts ────────────────────────────────────────────────────────

func _get_job_script(key: String) -> String:
	var header := """set_field("field")
set_home(0, 0)

func sweep()
  use_tool()
  repeat(23)
    move_forward()
    use_tool()
  end
end

func do_field()
  face("right")
  repeat(8)
    sweep()
    turn_right()
    move_forward()
    turn_right()
    sweep()
    turn_left()
    move_forward()
    turn_left()
  end
  home()
end

"""
	match key:
		"full_cycle":
			return header + """repeat
  set_tool("plow")
  do_field()

  if get_nutrition() < 30
    set_tool("fertilizer")
    do_field()
  end

  set_tool("seeder")
  do_field()

  wait(240)

  set_tool("harvester")
  do_field()
end
"""
		"plow":      return header + 'set_tool("plow")\ndo_field()\n'
		"sow":       return header + 'set_tool("seeder")\ndo_field()\n'
		"fertilise": return header + 'set_tool("fertilizer")\ndo_field()\n'
		"harvest":   return header + 'set_tool("harvester")\ndo_field()\n'
	return ""
