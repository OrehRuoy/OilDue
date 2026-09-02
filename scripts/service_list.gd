extends Control

const DueMath = preload("res://scripts/due_math.gd")
const ServiceIcons = preload("res://scripts/service_icons.gd")
const PanScroll = preload("res://scripts/pan_scroll.gd")
const ConfirmSheet = preload("res://scripts/confirm_sheet.gd")
const TAP_MIN := 44.0
const EMPTY_MIN := 52.0
const ROW_MIN := 80.0
const COLOR_PRIMARY := Color("#F4EFE6")
const COLOR_SURFACE := Color("#2A2622")
const COLOR_HAIRLINE := Color("#3D3832")
const COLOR_SECONDARY := Color("#9A9388")
const COLOR_MUTED := Color("#9A9388")

@onready var _title: Label = %Title
@onready var _title_icon: TextureRect = %TitleIcon
@onready var _rows: VBoxContainer = %HistoryRows
@onready var _miles_edit: LineEdit = %IntervalMilesEdit
@onready var _months_edit: LineEdit = %IntervalMonthsEdit
@onready var _error: Label = %ErrorLabel


func _ready() -> void:
	_ensure_selection()
	var vehicle := GarageStore.vehicle_by_id(GarageStore.selected_vehicle_id)
	var service := GarageStore.service_by_id(vehicle, GarageStore.selected_service_id)
	var label := str(service.get("label", "")).strip_edges()
	_title.text = label if label != "" else "History"
	_title_icon.texture = ServiceIcons.texture_for(str(service.get("type_id", "")))
	_title_icon.modulate = Color.WHITE
	_miles_edit.text = str(_as_int(service.get("interval_miles"), 0))
	_months_edit.text = str(_as_int(service.get("interval_months"), 0))
	_error.text = ""
	_build_rows()
	%LogButton.pressed.connect(_on_log_pressed)
	%SaveIntervalsButton.pressed.connect(_on_save_intervals_pressed)
	%DeleteServiceButton.pressed.connect(_on_delete_pressed)
	PanScroll.wire_fields($Margin/PageHost/Column/PageScroll)


func _ensure_selection() -> void:
	if GarageStore.selected_vehicle_id != "" and GarageStore.selected_service_id != "":
		return
	var vehicle := GarageStore.primary_vehicle()
	GarageStore.selected_vehicle_id = str(vehicle.get("id", ""))
	var services: Array = vehicle.get("services", [])
	if services.size() >= 1 and typeof(services[0]) == TYPE_DICTIONARY:
		GarageStore.selected_service_id = str(services[0].get("id", ""))


func _as_int(value: Variant, fallback: int) -> int:
	if value == null:
		return fallback
	var value_type := typeof(value)
	if value_type == TYPE_INT or value_type == TYPE_FLOAT:
		return int(value)
	return fallback


func _parse_interval(raw: String) -> Dictionary:
	var s := raw.strip_edges()
	if s == "":
		return {"ok": true, "value": 0}
	if not s.is_valid_int():
		return {"ok": false, "value": 0}
	var n := int(s)
	if n < 0:
		return {"ok": false, "value": 0}
	return {"ok": true, "value": n}


func _format_miles(value: int) -> String:
	return DueMath.format_miles(value)


func _build_rows() -> void:
	for child in _rows.get_children():
		child.queue_free()
	var jobs: Array = GarageStore.history_for_selected()
	var list: Array = []
	for item in jobs:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		list.append(item)
	if list.is_empty():
		_rows.add_child(_make_empty_row())
		return
	var count := list.size()
	var i := 0
	while i < count:
		var job: Dictionary = list[i]
		_rows.add_child(_make_row(job, i, count))
		i += 1


func _make_empty_row() -> Control:
	var wrap := Control.new()
	wrap.custom_minimum_size = Vector2(0, EMPTY_MIN)
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_SURFACE
	style.set_corner_radius_all(12)
	style.content_margin_left = 16
	style.content_margin_right = 16
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.text = "No jobs yet"
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", COLOR_SECONDARY)
	label.add_theme_font_size_override("font_size", 15)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	wrap.add_child(panel)
	PanScroll.wire(wrap, func() -> void: pass)
	return wrap


func _make_row(job: Dictionary, index: int, count: int) -> Control:
	var wrap := VBoxContainer.new()
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.add_theme_constant_override("separation", 0)
	wrap.clip_contents = false
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_SURFACE
	if index == 0:
		style.corner_radius_top_left = 12
		style.corner_radius_top_right = 12
	if index == count - 1:
		style.corner_radius_bottom_left = 12
		style.corner_radius_bottom_right = 12
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, ROW_MIN)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	hbox.add_child(_make_thumb_slot(str(job.get("receipt", "")).strip_edges()))
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	titles.add_theme_constant_override("separation", 1)
	var date_label := Label.new()
	var shown := DueMath.format_display_date(str(job.get("date", "")))
	date_label.text = shown if shown != "" else str(job.get("date", ""))
	date_label.add_theme_color_override("font_color", COLOR_PRIMARY)
	date_label.add_theme_font_size_override("font_size", 17)
	date_label.clip_text = false
	var cost_cents := int(job.get("cost_cents", 0))
	var cost_bit := "—" if cost_cents == 0 else DueMath.format_cents(cost_cents)
	var sub_label := Label.new()
	sub_label.text = "%s mi · %s" % [_format_miles(int(job.get("miles", 0))), cost_bit]
	sub_label.add_theme_color_override("font_color", COLOR_MUTED)
	sub_label.add_theme_font_size_override("font_size", 13)
	sub_label.clip_text = false
	titles.add_child(date_label)
	titles.add_child(sub_label)
	hbox.add_child(titles)
	panel.add_child(hbox)
	wrap.add_child(panel)
	if index < count - 1:
		var line := ColorRect.new()
		line.custom_minimum_size = Vector2(0, 1)
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.color = COLOR_HAIRLINE
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wrap.add_child(line)
	PanScroll.wire(wrap, _on_job_tapped.bind(str(job.get("id", ""))))
	return wrap


func _make_thumb_slot(receipt: String) -> Control:
	var slot := Control.new()
	slot.custom_minimum_size = Vector2(40, 40)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var thumb := PhotoService.load_texture(receipt)
	if thumb == null:
		return slot
	var pic := TextureRect.new()
	pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pic.custom_minimum_size = Vector2(40, 40)
	pic.texture = thumb
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.clip_contents = true
	slot.add_child(pic)
	return slot


func _on_log_pressed() -> void:
	GarageStore.selected_history_id = ""
	get_tree().change_scene_to_file("res://scenes/service_edit.tscn")


func _on_job_tapped(hid: String) -> void:
	if hid.strip_edges() == "":
		return
	GarageStore.selected_history_id = hid
	get_tree().change_scene_to_file("res://scenes/service_edit.tscn")


func _on_save_intervals_pressed() -> void:
	_error.text = ""
	var miles := _parse_interval(_miles_edit.text)
	var months := _parse_interval(_months_edit.text)
	if not bool(miles["ok"]) or not bool(months["ok"]):
		_error.text = "Enter intervals as whole numbers, or leave blank."
		return
	if not GarageStore.update_service_intervals(int(miles["value"]), int(months["value"])):
		_error.text = "Could not save intervals."
		return
	_miles_edit.text = str(int(miles["value"]))
	_months_edit.text = str(int(months["value"]))


func _on_delete_pressed() -> void:
	var vehicle := GarageStore.vehicle_by_id(GarageStore.selected_vehicle_id)
	var service := GarageStore.service_by_id(vehicle, GarageStore.selected_service_id)
	var label := str(service.get("label", "")).strip_edges()
	if label == "":
		label = "this service"
	ConfirmSheet.present(
		self,
		"Delete service?",
		"This removes %s and its jobs." % label,
		"Keep",
		"Delete",
		_on_delete_confirmed
	)


func _on_delete_confirmed() -> void:
	GarageStore.delete_selected_service()
	get_tree().change_scene_to_file("res://scenes/garage.tscn")
