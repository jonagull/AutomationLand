class_name NetworkTerminalUI
extends CanvasLayer

enum Mode { SCRIPT, CLI }

var _selected_bot: FarmBot = null
var _bot_buttons: Dictionary = {}

var _bot_list: VBoxContainer
var _field_container: VBoxContainer
var _code_edit: CodeEdit
var _script_output: RichTextLabel
var _run_btn: Button
var _stop_btn: Button
var _bot_name_label: Label
var _bot_status_label: Label
var _refresh_timer: Timer

var _script_view: VBoxContainer
var _cli_view: VBoxContainer
var _cli_output: RichTextLabel
var _cli_input: LineEdit
var _cli_history: Array[String] = []
var _cli_history_idx := -1
var _script_tab_btn: Button
var _cli_tab_btn: Button
var _mode := Mode.SCRIPT

func _ready() -> void:
	layer = 10
	_build_ui()
	hide()
	_refresh_timer = Timer.new()
	_refresh_timer.wait_time = 1.0
	_refresh_timer.timeout.connect(_refresh_status)
	add_child(_refresh_timer)

func toggle() -> void:
	if visible:
		_close()
	else:
		_open()

func _open() -> void:
	show()
	_populate_bots()
	_populate_fields()
	_refresh_timer.start()
	if _selected_bot == null:
		var bots := NetworkManager.get_bots()
		if bots.size() > 0:
			_select_bot(bots[0] as FarmBot)

func _close() -> void:
	hide()
	_refresh_timer.stop()

# ── UI build ─────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.65)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(780, 530)
	panel.offset_left = -390
	panel.offset_right = 390
	panel.offset_top = -265
	panel.offset_bottom = 265
	add_child(panel)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.11, 0.09)
	sb.border_color = Color(0.3, 0.65, 0.3)
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
	title.text = "Network Terminal"
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var hint := Label.new()
	hint.text = "Ctrl+Enter = Run   Esc = Close"
	hint.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	hint.add_theme_font_size_override("font_size", 11)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(hint)
	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.flat = true
	close_btn.pressed.connect(_close)
	header.add_child(close_btn)

	root.add_child(HSeparator.new())

	# Body: left + right
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)

	# ── Left panel ────────────────────────────────────────────────────────
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(190, 0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 3)
	scroll.add_child(left)

	var bots_hdr := Label.new()
	bots_hdr.text = "BOTS"
	bots_hdr.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
	bots_hdr.add_theme_font_size_override("font_size", 11)
	left.add_child(bots_hdr)

	_bot_list = VBoxContainer.new()
	_bot_list.add_theme_constant_override("separation", 2)
	left.add_child(_bot_list)

	left.add_child(HSeparator.new())

	var fields_hdr := Label.new()
	fields_hdr.text = "FIELDS"
	fields_hdr.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
	fields_hdr.add_theme_font_size_override("font_size", 11)
	left.add_child(fields_hdr)

	_field_container = VBoxContainer.new()
	_field_container.add_theme_constant_override("separation", 3)
	left.add_child(_field_container)

	body.add_child(VSeparator.new())

	# ── Right panel ───────────────────────────────────────────────────────
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	body.add_child(right)

	# Bot header + tab bar
	var bot_hdr := HBoxContainer.new()
	right.add_child(bot_hdr)
	_bot_name_label = Label.new()
	_bot_name_label.text = "No bot selected"
	_bot_name_label.add_theme_font_size_override("font_size", 13)
	_bot_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bot_hdr.add_child(_bot_name_label)
	_bot_status_label = Label.new()
	_bot_status_label.text = ""
	_bot_status_label.add_theme_font_size_override("font_size", 11)
	bot_hdr.add_child(_bot_status_label)

	var tab_bar := HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 2)
	right.add_child(tab_bar)
	_script_tab_btn = Button.new()
	_script_tab_btn.text = "Script"
	_script_tab_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_script_tab_btn.pressed.connect(_set_tab.bind(Mode.SCRIPT))
	tab_bar.add_child(_script_tab_btn)
	_cli_tab_btn = Button.new()
	_cli_tab_btn.text = "CLI"
	_cli_tab_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cli_tab_btn.pressed.connect(_set_tab.bind(Mode.CLI))
	tab_bar.add_child(_cli_tab_btn)

	right.add_child(HSeparator.new())

	# ── Script view ───────────────────────────────────────────────────────
	_script_view = VBoxContainer.new()
	_script_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_script_view.add_theme_constant_override("separation", 6)
	right.add_child(_script_view)

	_code_edit = CodeEdit.new()
	_code_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_code_edit.custom_minimum_size = Vector2(0, 180)
	_code_edit.gutters_draw_line_numbers = true
	_code_edit.auto_brace_completion_enabled = true
	_code_edit.indent_automatic = true
	_code_edit.indent_size = 2
	_code_edit.syntax_highlighter = _make_highlighter()
	_code_edit.add_theme_font_size_override("font_size", 13)
	_style_code_edit(_code_edit)
	_code_edit.gui_input.connect(_on_code_edit_input)
	_script_view.add_child(_code_edit)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 4)
	_script_view.add_child(btn_row)
	_run_btn = Button.new()
	_run_btn.text = "▶  Run"
	_run_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_run_btn.disabled = true
	_run_btn.pressed.connect(_on_run)
	btn_row.add_child(_run_btn)
	_stop_btn = Button.new()
	_stop_btn.text = "■  Stop"
	_stop_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stop_btn.disabled = true
	_stop_btn.pressed.connect(_on_stop)
	btn_row.add_child(_stop_btn)
	var copy_btn := Button.new()
	copy_btn.text = "⎘  Copy to All"
	copy_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy_btn.pressed.connect(_on_copy_to_all)
	btn_row.add_child(copy_btn)

	_script_view.add_child(HSeparator.new())

	_script_output = RichTextLabel.new()
	_script_output.custom_minimum_size = Vector2(0, 80)
	_script_output.bbcode_enabled = true
	_script_output.scroll_following = true
	_script_output.selection_enabled = true
	_script_output.add_theme_font_size_override("font_size", 11)
	_script_view.add_child(_script_output)

	# ── CLI view ──────────────────────────────────────────────────────────
	_cli_view = VBoxContainer.new()
	_cli_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_cli_view.add_theme_constant_override("separation", 4)
	_cli_view.visible = false
	right.add_child(_cli_view)

	_cli_output = RichTextLabel.new()
	_cli_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_cli_output.bbcode_enabled = true
	_cli_output.scroll_following = true
	_cli_output.selection_enabled = true
	_cli_output.add_theme_font_size_override("font_size", 13)
	_style_cli_output(_cli_output)
	_cli_view.add_child(_cli_output)

	var cli_row := HBoxContainer.new()
	cli_row.add_theme_constant_override("separation", 6)
	_cli_view.add_child(cli_row)
	var prompt := Label.new()
	prompt.text = ">"
	prompt.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
	prompt.add_theme_font_size_override("font_size", 14)
	cli_row.add_child(prompt)
	_cli_input = LineEdit.new()
	_cli_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cli_input.placeholder_text = "type a command and press Enter..."
	_cli_input.add_theme_font_size_override("font_size", 13)
	_cli_input.gui_input.connect(_on_cli_key)
	cli_row.add_child(_cli_input)
	var enter_btn := Button.new()
	enter_btn.text = "↵"
	enter_btn.pressed.connect(_cli_submit)
	cli_row.add_child(enter_btn)

	_update_tab_style()

# ── Population ───────────────────────────────────────────────────────────────

func _populate_bots() -> void:
	for child in _bot_list.get_children():
		child.queue_free()
	_bot_buttons.clear()

	for b in NetworkManager.get_bots():
		var bot := b as FarmBot
		if not bot: continue
		var btn := Button.new()
		btn.flat = true
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 12)
		btn.pressed.connect(_select_bot.bind(bot))
		_bot_list.add_child(btn)
		_bot_buttons[bot] = btn
		_refresh_bot_button(bot)

func _populate_fields() -> void:
	for child in _field_container.get_children():
		child.queue_free()
	for f in NetworkManager.get_fields():
		var field := f as Field
		if not field: continue
		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		lbl.text = _field_summary(field)
		_field_container.add_child(lbl)

func _field_summary(field: Field) -> String:
	var ready := field.count_cells_in_state(Field.State.READY)
	var growing := field.count_cells_in_state(Field.State.GROWING)
	var total := field.width * field.height
	var nutr := field.average_nutrition()
	return "%s  %dx%d\n  Ready:%d  Growing:%d\n  Nutr:%.0f  pH:%.1f" % [
		field.field_name, field.width, field.height,
		ready, growing, nutr, field.average_ph()
	]

# ── Refresh ───────────────────────────────────────────────────────────────────

func _refresh_status() -> void:
	for b in _bot_buttons:
		_refresh_bot_button(b as FarmBot)
	# Refresh field stats in-place
	var fields := NetworkManager.get_fields()
	var labels := _field_container.get_children()
	for i in mini(fields.size(), labels.size()):
		var lbl := labels[i] as Label
		if lbl:
			lbl.text = _field_summary(fields[i] as Field)

func _refresh_bot_button(bot: FarmBot) -> void:
	if not _bot_buttons.has(bot): return
	var btn := _bot_buttons[bot] as Button
	var runner := bot.get_node_or_null("BotRunner") as BotRunner
	var running := runner != null and runner._running
	btn.text = ("● " if running else "○ ") + bot.name
	if bot == _selected_bot:
		btn.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	else:
		btn.add_theme_color_override("font_color",
			Color(0.4, 1.0, 0.4) if running else Color(0.6, 0.6, 0.6))

# ── Selection ────────────────────────────────────────────────────────────────

func _select_bot(bot: FarmBot) -> void:
	if _selected_bot:
		_disconnect_bot(_selected_bot)

	_selected_bot = bot

	var runner := bot.get_node_or_null("BotRunner") as BotRunner
	if runner:
		if not runner.started.is_connected(_on_runner_started):
			runner.started.connect(_on_runner_started)
		if not runner.stopped.is_connected(_on_runner_stopped):
			runner.stopped.connect(_on_runner_stopped)
		_run_btn.disabled = runner._running
		_stop_btn.disabled = not runner._running

	if not bot.log_output.is_connected(_append_log):
		bot.log_output.connect(_append_log)

	_bot_name_label.text = bot.name
	_update_status_label()

	_code_edit.text = bot.current_script

	_script_output.clear()
	for line in bot.log_history:
		_script_output.append_text(line + "\n")
	_cli_output.clear()

	for b in _bot_buttons:
		_refresh_bot_button(b as FarmBot)

func _disconnect_bot(bot: FarmBot) -> void:
	if bot.log_output.is_connected(_append_log):
		bot.log_output.disconnect(_append_log)
	var runner := bot.get_node_or_null("BotRunner") as BotRunner
	if runner:
		if runner.started.is_connected(_on_runner_started):
			runner.started.disconnect(_on_runner_started)
		if runner.stopped.is_connected(_on_runner_stopped):
			runner.stopped.disconnect(_on_runner_stopped)

func _update_status_label() -> void:
	if not _selected_bot:
		_bot_status_label.text = ""
		return
	var runner := _selected_bot.get_node_or_null("BotRunner") as BotRunner
	if runner and runner._running:
		_bot_status_label.text = "● Running"
		_bot_status_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
	else:
		_bot_status_label.text = "○ Idle"
		_bot_status_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))

# ── Actions ───────────────────────────────────────────────────────────────────

func _on_run() -> void:
	if not _selected_bot: return
	var runner := _selected_bot.get_node_or_null("BotRunner") as BotRunner
	if not runner: return
	var code := _code_edit.text
	_selected_bot.load_script(code)
	_script_output.clear()
	runner.start(code)

func _on_stop() -> void:
	if not _selected_bot: return
	var runner := _selected_bot.get_node_or_null("BotRunner") as BotRunner
	if runner:
		runner.stop()

func _on_copy_to_all() -> void:
	var code := _code_edit.text
	for b in NetworkManager.get_bots():
		var bot := b as FarmBot
		if bot:
			bot.load_script(code)

func _append_log(text: String) -> void:
	if _mode == Mode.CLI:
		_cli_output.append_text(text + "\n")
	else:
		_script_output.append_text(text + "\n")

func _on_runner_started() -> void:
	_run_btn.disabled = true
	_stop_btn.disabled = false
	_update_status_label()

func _on_runner_stopped() -> void:
	_run_btn.disabled = false
	_stop_btn.disabled = true
	_update_status_label()

func _on_code_edit_input(event: InputEvent) -> void:
	if not (event is InputEventKey and (event as InputEventKey).pressed):
		return
	var key := event as InputEventKey
	if key.keycode == KEY_ENTER and key.ctrl_pressed:
		if not _run_btn.disabled:
			_on_run()
		_code_edit.accept_event()
	elif key.keycode == KEY_ESCAPE:
		_close()
		_code_edit.accept_event()

# ── Tab / CLI ─────────────────────────────────────────────────────────────────

func _set_tab(mode: Mode) -> void:
	_mode = mode
	_script_view.visible = (mode == Mode.SCRIPT)
	_cli_view.visible = (mode == Mode.CLI)
	_update_tab_style()
	if mode == Mode.CLI:
		_cli_input.grab_focus()
	else:
		_code_edit.grab_focus()

func _update_tab_style() -> void:
	_script_tab_btn.flat = (_mode != Mode.SCRIPT)
	_cli_tab_btn.flat = (_mode != Mode.CLI)
	_script_tab_btn.add_theme_color_override("font_color",
		Color(1.0, 1.0, 1.0) if _mode == Mode.SCRIPT else Color(0.5, 0.5, 0.5))
	_cli_tab_btn.add_theme_color_override("font_color",
		Color(1.0, 1.0, 1.0) if _mode == Mode.CLI else Color(0.5, 0.5, 0.5))

func _on_cli_key(event: InputEvent) -> void:
	if not (event is InputEventKey and (event as InputEventKey).pressed): return
	var key := event as InputEventKey
	match key.keycode:
		KEY_ENTER, KEY_KP_ENTER:
			_cli_submit()
			_cli_input.accept_event()
		KEY_UP:
			if _cli_history_idx < _cli_history.size() - 1:
				_cli_history_idx += 1
				_cli_input.text = _cli_history[_cli_history.size() - 1 - _cli_history_idx]
				_cli_input.caret_column = _cli_input.text.length()
			_cli_input.accept_event()
		KEY_DOWN:
			if _cli_history_idx > 0:
				_cli_history_idx -= 1
				_cli_input.text = _cli_history[_cli_history.size() - 1 - _cli_history_idx]
				_cli_input.caret_column = _cli_input.text.length()
			elif _cli_history_idx == 0:
				_cli_history_idx = -1
				_cli_input.text = ""
			_cli_input.accept_event()
		KEY_ESCAPE:
			_close()
			_cli_input.accept_event()

func _cli_submit() -> void:
	var text := _cli_input.text.strip_edges()
	_cli_input.text = ""
	_cli_input.grab_focus()
	if text.is_empty(): return
	_cli_history.append(text)
	_cli_history_idx = -1
	_cli_output.append_text("[color=#3d7a3d]> %s[/color]\n" % text)
	if not _selected_bot:
		_cli_output.append_text("[color=red]No bot selected[/color]\n")
		return
	var runner := _selected_bot.get_node_or_null("BotRunner") as BotRunner
	if runner:
		runner.execute_line(text)

# ── Styling ───────────────────────────────────────────────────────────────────

func _style_cli_output(rtl: RichTextLabel) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.07, 0.04)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.2, 0.4, 0.2)
	sb.set_corner_radius_all(2)
	rtl.add_theme_stylebox_override("normal", sb)
	rtl.add_theme_color_override("default_color", Color(0.80, 0.95, 0.80))

func _style_code_edit(ce: CodeEdit) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.08, 0.06)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.2, 0.4, 0.2)
	sb.set_corner_radius_all(2)
	ce.add_theme_stylebox_override("normal", sb)
	ce.add_theme_stylebox_override("focus", sb)
	ce.add_theme_color_override("font_color", Color(0.85, 0.92, 0.85))
	ce.add_theme_color_override("caret_color", Color(0.5, 1.0, 0.5))
	ce.add_theme_color_override("selection_color", Color(0.2, 0.5, 0.2, 0.5))
	ce.add_theme_color_override("line_number_color", Color(0.35, 0.55, 0.35))
	ce.add_theme_color_override("current_line_color", Color(1.0, 1.0, 1.0, 0.03))

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
	h.add_color_region("--", "", Color(0.4, 0.6, 0.4), true)
	h.add_color_region('"', '"', Color(0.82, 0.92, 0.5))
	h.add_color_region("'", "'", Color(0.82, 0.92, 0.5))
	return h
