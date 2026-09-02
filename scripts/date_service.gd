extends Node

signal picked(ymd: String)
signal cancelled()

const DueMath = preload("res://scripts/due_math.gd")
const COLOR_DIM := Color(0.101961, 0.090196, 0.078431, 0.55)
const COLOR_CARD := Color("#2A2622")
const COLOR_TEXT := Color("#F4EFE6")
const COLOR_MUTED := Color("#9A9388")
const COLOR_RING := Color("#FF453A")
const WEEKDAYS := ["S", "M", "T", "W", "T", "F", "S"]

var last_ymd := ""
var _before := ""
var _view_year := 0
var _view_month := 0
var _sheet: Control
var _month_label: Label
var _day_buttons: Array = []


func _ios_datepicker() -> bool:
	return OS.has_feature("ios") and Engine.has_singleton("DatePicker")


func pick(ymd: String) -> void:
	begin_pick(ymd)
	if _ios_datepicker():
		_present_native(last_ymd)
		return
	_open_sheet(last_ymd)


func begin_pick(ymd: String) -> void:
	var start := ymd.strip_edges()
	if DueMath.parse_ymd(start).is_empty():
		start = GarageStore.today_ymd()
	_before = start
	last_ymd = start


func apply_ymd(s: String) -> bool:
	var raw := s.strip_edges()
	if DueMath.parse_ymd(raw).is_empty():
		return false
	last_ymd = raw
	return true


func cancel_pick() -> void:
	last_ymd = _before
	_close_sheet()
	cancelled.emit()


func _present_native(ymd: String) -> void:
	var picker := Engine.get_singleton("DatePicker")
	if picker == null:
		_open_sheet(ymd)
		return
	var picked_cb := Callable(self, "_on_native_picked")
	var cancel_cb := Callable(self, "_on_native_cancelled")
	if picker.has_signal("date_picked") and not picker.is_connected("date_picked", picked_cb):
		picker.connect("date_picked", picked_cb)
	if picker.has_signal("date_cancelled") and not picker.is_connected("date_cancelled", cancel_cb):
		picker.connect("date_cancelled", cancel_cb)
	if picker.has_method("present"):
		picker.call("present", ymd)


func _on_native_picked(ymd: String = "") -> void:
	if apply_ymd(str(ymd)):
		picked.emit(last_ymd)
	else:
		cancel_pick()


func _on_native_cancelled(_unused = null) -> void:
	cancel_pick()


func _open_sheet(ymd: String) -> void:
	_close_sheet()
	var parsed := DueMath.parse_ymd(ymd)
	if parsed.is_empty():
		parsed = DueMath.parse_ymd(GarageStore.today_ymd())
	_view_year = int(parsed.year)
	_view_month = int(parsed.month)
	var host := get_tree().current_scene if get_tree() != null else null
	if host == null:
		host = self
	_sheet = _make_sheet()
	host.add_child(_sheet)
	_rebuild_grid()


func _close_sheet() -> void:
	if _sheet == null:
		return
	_sheet.queue_free()
	_sheet = null
	_month_label = null
	_day_buttons.clear()


func _make_sheet() -> Control:
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = COLOR_DIM
	dim.gui_input.connect(_on_dim_gui_input)

	var dock := VBoxContainer.new()
	dock.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dock.add_theme_constant_override("separation", 0)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dock.add_child(spacer)

	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = COLOR_CARD
	card_style.set_corner_radius_all(16)
	card_style.content_margin_left = 16
	card_style.content_margin_right = 16
	card_style.content_margin_top = 16
	card_style.content_margin_bottom = 16
	card.add_theme_stylebox_override("panel", card_style)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.mouse_filter = Control.MOUSE_FILTER_STOP

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	var prev := Button.new()
	prev.custom_minimum_size = Vector2(44, 44)
	prev.text = "<"
	prev.pressed.connect(_on_prev_month)
	_month_label = Label.new()
	_month_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_month_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_month_label.add_theme_font_size_override("font_size", 17)
	_month_label.add_theme_color_override("font_color", COLOR_TEXT)
	var next := Button.new()
	next.custom_minimum_size = Vector2(44, 44)
	next.text = ">"
	next.pressed.connect(_on_next_month)
	head.add_child(prev)
	head.add_child(_month_label)
	head.add_child(next)
	col.add_child(head)

	var week := HBoxContainer.new()
	week.add_theme_constant_override("separation", 0)
	for name in WEEKDAYS:
		var w := Label.new()
		w.text = name
		w.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		w.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		w.add_theme_font_size_override("font_size", 13)
		w.add_theme_color_override("font_color", COLOR_MUTED)
		week.add_child(w)
	col.add_child(week)

	var grid := GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	_day_buttons.clear()
	for i in range(42):
		var day := Button.new()
		day.custom_minimum_size = Vector2(0, 44)
		day.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		day.add_theme_font_size_override("font_size", 17)
		day.pressed.connect(_on_day_pressed.bind(i))
		grid.add_child(day)
		_day_buttons.append(day)
	col.add_child(grid)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	var today := Button.new()
	today.custom_minimum_size = Vector2(0, 52)
	today.text = "Today"
	today.pressed.connect(_on_today_pressed)
	var grow := Control.new()
	grow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var done := Button.new()
	done.custom_minimum_size = Vector2(120, 52)
	done.theme_type_variation = &"CreamButton"
	done.text = "Done"
	done.pressed.connect(_on_done_pressed)
	actions.add_child(today)
	actions.add_child(grow)
	actions.add_child(done)
	col.add_child(actions)

	card.add_child(col)
	dock.add_child(card)
	dim.add_child(dock)
	return dim


func _rebuild_grid() -> void:
	if _month_label != null:
		_month_label.text = "%s %d" % [DueMath.MONTH_ABBR[_view_month], _view_year]
	var sel := DueMath.parse_ymd(last_ymd)
	for i in range(42):
		var btn: Button = _day_buttons[i]
		var cell: Dictionary = _cell_date(i)
		btn.disabled = false
		btn.text = str(int(cell.day))
		var in_view := bool(cell.in_view)
		btn.modulate = Color.WHITE if in_view else Color(1, 1, 1, 0.45)
		var is_sel := (
			not sel.is_empty()
			and int(sel.year) == int(cell.year)
			and int(sel.month) == int(cell.month)
			and int(sel.day) == int(cell.day)
		)
		_style_day(btn, is_sel)
		if not in_view and not is_sel:
			btn.add_theme_color_override("font_color", COLOR_MUTED)


func _style_day(btn: Button, selected: bool) -> void:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(8)
	style.bg_color = COLOR_CARD
	if selected:
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.border_color = COLOR_RING
		btn.add_theme_color_override("font_color", COLOR_TEXT)
	else:
		btn.add_theme_color_override("font_color", COLOR_TEXT)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_stylebox_override("disabled", style)
	btn.add_theme_stylebox_override("focus", style)


func _weekday(year: int, month: int, day: int) -> int:
	var unix := Time.get_unix_time_from_datetime_dict({
		"year": year,
		"month": month,
		"day": day,
		"hour": 12,
		"minute": 0,
		"second": 0,
	})
	var dict := Time.get_datetime_dict_from_unix_time(int(unix))
	return int(dict.get("weekday", 0))


func _on_prev_month() -> void:
	_view_month -= 1
	if _view_month < 1:
		_view_month = 12
		_view_year -= 1
	_rebuild_grid()


func _on_next_month() -> void:
	_view_month += 1
	if _view_month > 12:
		_view_month = 1
		_view_year += 1
	_rebuild_grid()


func _cell_date(index: int) -> Dictionary:
	var first_wd := _weekday(_view_year, _view_month, 1)
	var day_n := index - first_wd + 1
	var year := _view_year
	var month := _view_month
	var in_view := true
	if day_n < 1:
		in_view = false
		month -= 1
		if month < 1:
			month = 12
			year -= 1
		day_n += DueMath.days_in_month(year, month)
	else:
		var dim := DueMath.days_in_month(_view_year, _view_month)
		if day_n > dim:
			in_view = false
			day_n -= dim
			month += 1
			if month > 12:
				month = 1
				year += 1
	return {"year": year, "month": month, "day": day_n, "in_view": in_view}


func _on_day_pressed(index: int) -> void:
	var cell: Dictionary = _cell_date(index)
	var ymd := DueMath.format_ymd(int(cell.year), int(cell.month), int(cell.day))
	if apply_ymd(ymd):
		_rebuild_grid()
		picked.emit(last_ymd)


func _on_today_pressed() -> void:
	var today := GarageStore.today_ymd()
	if apply_ymd(today):
		picked.emit(last_ymd)
	_close_sheet()


func _on_done_pressed() -> void:
	if apply_ymd(last_ymd):
		picked.emit(last_ymd)
	_close_sheet()


func _on_dim_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			cancel_pick()
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			cancel_pick()
