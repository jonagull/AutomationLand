class_name BotJobsPanel
extends CanvasLayer

signal open_terminal_requested

var _bot: FarmBot
var _runner: BotRunner
var _selected_idx := 0
var _job_cards: Array = []
var _status_label: Label
var _run_btn: Button
var _stop_btn: Button

const JOBS := [
	{
		icon = "🔄",
		name = "Full Cycle",
		desc = "Plow → fertilise if needed → sow → wait → harvest. Loops forever.",
		key = "full_cycle"
	},
	{
		icon = "🌱",
		name = "Plow Field",
		desc = "Plow every cell in the field once, then return home.",
		key = "plow"
	},
	{
		icon = "🌾",
		name = "Sow Seeds",
		desc = "Sow seeds across the whole field once.",
		key = "sow"
	},
	{
		icon = "🌿",
		name = "Fertilise",
		desc = "Apply fertiliser to every cell once.",
		key = "fertilise"
	},
	{
		icon = "✂",
		name = "Harvest",
		desc = "Harvest every ready crop in the field.",
		key = "harvest"
	},
]

# ── Setup ─────────────────────────────────────────────────────────────────────

func setup(bot: FarmBot, runner: BotRunner) -> void:
	_bot = bot
	_runner = runner
	_runner.started.connect(_on_started)
	_runner.stopped.connect(_on_stopped)

func _ready() -> void:
	layer = 10
	_build_ui()
	hide()

func toggle() -> void:
	if visible: hide()
	else: show()

# ── UI ────────────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.6)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
			hide()
	)
	add_child(bg)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(420, 500)
	panel.offset_left = -210
	panel.offset_right = 210
	panel.offset_top = -250
	panel.offset_bottom = 250
	add_child(panel)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.12, 0.09)
	sb.border_color = Color(0.35, 0.7, 0.35)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", sb)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	# Header
	var header := HBoxContainer.new()
	root.add_child(header)
	var title_col := VBoxContainer.new()
	title_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_col)
	var title := Label.new()
	title.text = "FarmBot"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.55, 1.0, 0.55))
	title_col.add_child(title)
	_status_label = Label.new()
	_status_label.text = "○  Idle — pick a job below"
	_status_label.add_theme_font_size_override("font_size", 11)
	_status_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	title_col.add_child(_status_label)
	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.flat = true
	close_btn.pressed.connect(hide)
	header.add_child(close_btn)

	root.add_child(HSeparator.new())

	# Job cards
	var card_list := VBoxContainer.new()
	card_list.add_theme_constant_override("separation", 6)
	card_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(card_list)

	for i in JOBS.size():
		var card := _make_card(JOBS[i], i)
		card_list.add_child(card)
		_job_cards.append(card)

	root.add_child(HSeparator.new())

	# Run / Stop
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 6)
	root.add_child(btn_row)
	_run_btn = Button.new()
	_run_btn.text = "▶  Start Job"
	_run_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_run_btn.add_theme_font_size_override("font_size", 14)
	_run_btn.pressed.connect(_on_run)
	btn_row.add_child(_run_btn)
	_stop_btn = Button.new()
	_stop_btn.text = "■  Stop"
	_stop_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stop_btn.disabled = true
	_stop_btn.pressed.connect(_on_stop)
	btn_row.add_child(_stop_btn)

	# Terminal link
	var term_btn := Button.new()
	term_btn.text = "{ }  Open Code Terminal  →"
	term_btn.flat = true
	term_btn.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0))
	term_btn.add_theme_font_size_override("font_size", 11)
	term_btn.pressed.connect(func() -> void:
		hide()
		open_terminal_requested.emit()
	)
	root.add_child(term_btn)

	_refresh_cards()

func _make_card(job: Dictionary, idx: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
			_select(idx)
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

func _select(idx: int) -> void:
	_selected_idx = idx
	_refresh_cards()

func _refresh_cards() -> void:
	for i in _job_cards.size():
		var card := _job_cards[i] as PanelContainer
		var selected := (i == _selected_idx)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.15, 0.28, 0.15) if selected else Color(0.07, 0.09, 0.07)
		sb.border_color = Color(0.4, 0.85, 0.4)
		sb.set_border_width_all(1 if selected else 0)
		sb.set_corner_radius_all(5)
		card.add_theme_stylebox_override("panel", sb)
		var name_lbl := card.get_child(0).get_child(0).get_child(1).get_child(0) as Label
		name_lbl.add_theme_color_override("font_color",
			Color(0.88, 1.0, 0.88) if selected else Color(0.78, 0.78, 0.78))

# ── Actions ───────────────────────────────────────────────────────────────────

func _on_run() -> void:
	if not _runner: return
	_runner.start(_get_script(JOBS[_selected_idx].key))

func _on_stop() -> void:
	if _runner: _runner.stop()

func _on_started() -> void:
	_run_btn.disabled = true
	_stop_btn.disabled = false
	_status_label.text = "●  Running — %s" % JOBS[_selected_idx].name
	_status_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))

func _on_stopped() -> void:
	_run_btn.disabled = false
	_stop_btn.disabled = true
	_status_label.text = "○  Idle — pick a job below"
	_status_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		hide()
		get_viewport().set_input_as_handled()

# ── Job scripts ───────────────────────────────────────────────────────────────

func _get_script(key: String) -> String:
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
		"plow":
			return header + """set_tool("plow")
do_field()
"""
		"sow":
			return header + """set_tool("seeder")
do_field()
"""
		"fertilise":
			return header + """set_tool("fertilizer")
do_field()
"""
		"harvest":
			return header + """set_tool("harvester")
do_field()
"""
	return ""
