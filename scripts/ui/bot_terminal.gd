class_name BotTerminal
extends CanvasLayer

enum Mode { BLOCKS, SCRIPT }

# ── Script tab ────────────────────────────────────────────────────────────────
var _code_edit: CodeEdit
var _script_output: RichTextLabel
var _status_label: Label
var _script_view: VBoxContainer

# ── Blocks tab ────────────────────────────────────────────────────────────────
var _block_editor: BlockEditor

# ── Shared UI ─────────────────────────────────────────────────────────────────
var _run_btn: Button
var _stop_btn: Button
var _blocks_tab_btn: Button
var _script_tab_btn: Button
var _mode := Mode.BLOCKS

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
	if visible:
		hide()
	else:
		show()
		if _mode == Mode.SCRIPT:
			_code_edit.grab_focus()

# ── Build ─────────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.65)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(780, 560)
	panel.offset_left = -390
	panel.offset_right = 390
	panel.offset_top = -280
	panel.offset_bottom = 280
	add_child(panel)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.12, 0.14)
	sb.border_color = Color(0.35, 0.35, 0.45)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", sb)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	margin.add_child(root)

	# Header
	var header := HBoxContainer.new()
	root.add_child(header)
	var title := Label.new()
	title.text = "FarmBot Terminal"
	title.add_theme_font_size_override("font_size", 15)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var home_btn := Button.new()
	home_btn.text = "⌂  Home to Dock"
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

	# Tab bar
	var tab_bar := HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 2)
	root.add_child(tab_bar)
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

	root.add_child(HSeparator.new())

	# ── Blocks tab content ────────────────────────────────────────────────
	_block_editor = BlockEditor.new()
	_block_editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_block_editor.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	_block_editor.custom_minimum_size   = Vector2(0, 340)
	root.add_child(_block_editor)

	# ── Script tab content ────────────────────────────────────────────────
	_script_view = VBoxContainer.new()
	_script_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_script_view.add_theme_constant_override("separation", 6)
	_script_view.visible = false
	root.add_child(_script_view)

	_code_edit = CodeEdit.new()
	_code_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_code_edit.custom_minimum_size = Vector2(0, 240)
	_code_edit.gutters_draw_line_numbers = true
	_code_edit.gutters_draw_fold_gutter = true
	_code_edit.auto_brace_completion_enabled = true
	_code_edit.indent_automatic = true
	_code_edit.indent_size = 2
	_code_edit.code_completion_enabled = true
	_code_edit.syntax_highlighter = _make_highlighter()
	_code_edit.text = _default_script()
	_code_edit.add_theme_font_size_override("font_size", 14)
	_style_code_edit(_code_edit)
	_code_edit.gui_input.connect(_on_code_edit_input)
	_code_edit.code_completion_requested.connect(_on_completion_requested)
	_code_edit.caret_changed.connect(_on_caret_changed)
	_script_view.add_child(_code_edit)

	_status_label = Label.new()
	_status_label.text = "Ln 1, Col 1   |   Ctrl+Enter = Run"
	_status_label.add_theme_color_override("font_color", Color(0.45, 0.45, 0.55))
	_status_label.add_theme_font_size_override("font_size", 11)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_script_view.add_child(_status_label)

	root.add_child(HSeparator.new())

	# ── Action row (always visible) ────────────────────────────────────────
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
	clear_btn.text = "⌫  Clear Log"
	clear_btn.pressed.connect(func() -> void: _script_output.clear())
	btn_row.add_child(clear_btn)

	# ── Output log (always visible) ────────────────────────────────────────
	_script_output = RichTextLabel.new()
	_script_output.custom_minimum_size = Vector2(0, 72)
	_script_output.bbcode_enabled = true
	_script_output.scroll_following = true
	_script_output.selection_enabled = true
	_script_output.add_theme_font_size_override("font_size", 12)
	_style_log_output(_script_output)
	root.add_child(_script_output)

	_update_tab_style()

# ── Tab switching ─────────────────────────────────────────────────────────────

func _set_tab(mode: Mode) -> void:
	_mode = mode
	_block_editor.visible = (mode == Mode.BLOCKS)
	_script_view.visible  = (mode == Mode.SCRIPT)
	_update_tab_style()
	if mode == Mode.SCRIPT:
		_code_edit.grab_focus()

func _update_tab_style() -> void:
	for pair in [[_blocks_tab_btn, Mode.BLOCKS], [_script_tab_btn, Mode.SCRIPT]]:
		var btn := pair[0] as Button
		var m: int = pair[1]
		btn.flat = (_mode != m)
		btn.add_theme_color_override("font_color",
			Color(1.0, 1.0, 1.0) if _mode == m else Color(0.5, 0.5, 0.5))

# ── Actions ───────────────────────────────────────────────────────────────────

func _on_run() -> void:
	if not _runner: return
	_clear_error_highlights()
	_script_output.clear()
	var code := _block_editor.generate_script() if _mode == Mode.BLOCKS else _code_edit.text
	_runner.start(code)

func _on_stop() -> void:
	if _runner: _runner.stop()

func _on_home() -> void:
	if _runner: _runner.stop()
	if _bot: _bot.return_to_dock()

# ── Runner callbacks ──────────────────────────────────────────────────────────

func _on_started() -> void:
	_run_btn.disabled = true
	_stop_btn.disabled = false

func _on_stopped() -> void:
	_run_btn.disabled = false
	_stop_btn.disabled = true

# ── Log ───────────────────────────────────────────────────────────────────────

func _append_log(text: String) -> void:
	_script_output.append_text(text + "\n")

func _on_parse_error(line: int, msg: String) -> void:
	_script_output.append_text("[color=red]Line %d: %s[/color]\n" % [line, msg])
	if line > 0 and line <= _code_edit.get_line_count():
		_code_edit.set_line_background_color(line - 1, Color(0.7, 0.1, 0.1, 0.35))

func _clear_error_highlights() -> void:
	for i in _code_edit.get_line_count():
		_code_edit.set_line_background_color(i, Color.TRANSPARENT)

# ── Code edit input ───────────────────────────────────────────────────────────

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
	_status_label.text = "Ln %d, Col %d   |   Ctrl+Enter = Run" % [
		_code_edit.get_caret_line() + 1,
		_code_edit.get_caret_column() + 1
	]

func _on_completion_requested() -> void:
	var keywords := ["if ", "elseif ", "else", "end", "repeat", "var ", "func ", "true", "false"]
	var commands := [
		"move_to", "move_forward", "turn_right", "turn_left", "face",
		"use_tool", "home", "wait", "set_tool", "set_field", "set_home",
		"get_state", "print", "check_ph", "check_nutrition", "get_posx", "get_posy",
	]
	for kw in keywords:
		_code_edit.add_code_completion_option(CodeEdit.KIND_PLAIN_TEXT, kw.strip_edges(), kw)
	for cmd in commands:
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
	ce.add_theme_color_override("font_color", Color(0.88, 0.88, 0.88))
	ce.add_theme_color_override("caret_color", Color(0.9, 0.7, 0.3))
	ce.add_theme_color_override("selection_color", Color(0.2, 0.4, 0.7, 0.5))
	ce.add_theme_color_override("line_number_color", Color(0.4, 0.4, 0.5))
	ce.add_theme_color_override("current_line_color", Color(1.0, 1.0, 1.0, 0.04))

func _style_log_output(rtl: RichTextLabel) -> void:
	var csb := StyleBoxFlat.new()
	csb.bg_color = Color(0.05, 0.07, 0.05)
	csb.set_border_width_all(1)
	csb.border_color = Color(0.2, 0.35, 0.2)
	csb.set_corner_radius_all(2)
	rtl.add_theme_stylebox_override("normal", csb)
	rtl.add_theme_color_override("default_color", Color(0.82, 0.95, 0.82))

func _make_highlighter() -> CodeHighlighter:
	var h := CodeHighlighter.new()
	h.number_color = Color(0.85, 0.65, 0.25)
	h.symbol_color = Color(0.75, 0.75, 0.75)
	h.function_color = Color(0.45, 0.85, 1.0)
	h.member_variable_color = Color(0.9, 0.55, 0.35)
	for kw in ["if", "elseif", "else", "end", "repeat", "var", "func", "true", "false"]:
		h.add_keyword_color(kw, Color(0.85, 0.45, 0.85))
	for kw in ["move_to", "move_forward", "turn_right", "turn_left", "face", "use_tool",
			"home", "wait", "set_tool", "set_field", "set_home", "get_state", "print",
			"check_ph", "check_nutrition", "get_posx", "get_posy"]:
		h.add_keyword_color(kw, Color(0.45, 0.85, 1.0))
	for kw in ["plow", "seeder", "harvester", "ph_up", "ph_down", "fertilizer"]:
		h.add_keyword_color(kw, Color(0.6, 0.92, 0.5))
	h.add_color_region("--", "", Color(0.45, 0.55, 0.45), true)
	h.add_color_region('"', '"', Color(0.82, 0.92, 0.5))
	h.add_color_region("'", "'", Color(0.82, 0.92, 0.5))
	return h

func _default_script() -> String:
	return \
"""-- FarmBot script — full farming cycle: plow -> sow -> grow -> harvest -> repeat
--
-- Movement:  move_forward()  turn_right()  turn_left()  face(dir)  home()
-- Tools:     use_tool()  set_tool("plow"|"seeder"|"harvester"|"ph_up"|"ph_down"|"fertilizer")
-- Query:     get_state()  get_ph()  get_nutrition()  (current cell only)
-- Position:  get_posx()  get_posy()
-- Commands:  print(value)  wait(secs)
-- Variables: var x = 5    x = x + 1
-- Control:   if cond ... elseif cond ... else ... end
-- Loops:     repeat(n) ... end  |  repeat ... end  (loops forever)
-- Functions: func name() ... end

set_field("field")
set_home(0, 0)

repeat

  set_tool("plow")
  face("right")
  repeat(8)
    use_tool()
    repeat(23)
      move_forward()
      use_tool()
    end
    turn_right()
    move_forward()
    turn_right()
    use_tool()
    repeat(23)
      move_forward()
      use_tool()
    end
    turn_left()
    move_forward()
    turn_left()
  end
  home()

  if get_nutrition() < 30
	set_tool("fertilizer")
	face("right")
    repeat(8)
      use_tool()
      repeat(23)
        move_forward()
        use_tool()
      end
      turn_right()
      move_forward()
      turn_right()
      use_tool()
      repeat(23)
        move_forward()
        use_tool()
      end
      turn_left()
      move_forward()
      turn_left()
    end
    home()
  end

  set_tool("seeder")
  face("right")
  repeat(8)
    use_tool()
    repeat(23)
      move_forward()
      use_tool()
    end
    turn_right()
    move_forward()
    turn_right()
    use_tool()
    repeat(23)
      move_forward()
      use_tool()
    end
    turn_left()
    move_forward()
    turn_left()
  end
  home()

  wait(240)

  set_tool("harvester")
  face("right")
  repeat(8)
    use_tool()
    repeat(23)
      move_forward()
      use_tool()
    end
    turn_right()
    move_forward()
    turn_right()
    use_tool()
    repeat(23)
      move_forward()
      use_tool()
    end
    turn_left()
    move_forward()
    turn_left()
  end
  home()

end
"""
