extends Control

const DueMath = preload("res://scripts/due_math.gd")
const ServiceIcons = preload("res://scripts/service_icons.gd")
const TAP_MIN := 44.0
const ROW_MIN := 56.0
const TILE := 60.0
const CONTENT_PAD := 16
const COLOR_PRIMARY := Color("#F2F2F7")
const COLOR_SURFACE := Color("#2A2622")
const COLOR_HAIRLINE := Color("#3D3832")
const COLOR_SECONDARY := Color("#8E8E93")
const COLOR_ACCENT := Color("#FF453A")
const CHEVRON := preload("res://assets/icons/chevron_right.png")

const STATUS_ORDER := {
	"Overdue": 0,
	"Due soon": 1,
	"OK": 2,
}

const STATUS_LABELS := {
	"overdue": "Overdue",
	"due_soon": "Due soon",
	"ok": "OK",
}

const STATUS_COLOR := {
	"Overdue": Color("#FF453A"),
	"Due soon": Color("#FF9F0A"),
	"OK": Color("#30D158"),
}

@onready var _safe_area: MarginContainer = %SafeArea
@onready var _photo_slot: Panel = %PhotoSlot
@onready var _car_name: Button = %CarName
@onready var _car_switch: OptionButton = %CarSwitch
@onready var _car_strip: ScrollContainer = %CarStrip
@onready var _car_tiles: HBoxContainer = %CarTiles
@onready var _odometer: Label = %Odometer
@onready var _photo_rect: TextureRect = %PhotoRect
@onready var _summary: Label = %Summary
@onready var _service_rows: VBoxContainer = %ServiceRows
@onready var _miles_popup: ColorRect = %MilesPopup
@onready var _miles_edit: LineEdit = %MilesEdit

var _miles: int = 0


func _ready() -> void:
	_car_switch.visible = false
	_refresh_from_store()
	_miles_popup.visible = false
	%UpdateMiles.pressed.connect(_on_update_miles_pressed)
	%Gear.pressed.connect(_on_gear_pressed)
	%Add.pressed.connect(_on_add_pressed)
	%MilesCancel.pressed.connect(_on_miles_cancel)
	%MilesSet.pressed.connect(_on_miles_set)
	_miles_edit.text_submitted.connect(func(_t: String) -> void: _on_miles_set())
	_car_name.pressed.connect(_open_vehicle_edit)
	%PhotoSlot.gui_input.connect(_on_photo_gui_input)
	get_viewport().size_changed.connect(_apply_safe_area)
	_apply_safe_area()


func _current_display_vehicle() -> Dictionary:
	var vehicle := GarageStore.vehicle_by_id(GarageStore.selected_vehicle_id)
	if vehicle.is_empty():
		vehicle = GarageStore.primary_vehicle()
		GarageStore.selected_vehicle_id = str(vehicle.get("id", ""))
	return vehicle


func _refresh_from_store() -> void:
	var vehicle := _current_display_vehicle()
	_car_name.text = _vehicle_display_name(vehicle)
	_fill_header(str(vehicle.get("id", "")))
	_miles = int(vehicle.get("odometer", 0))
	_refresh_odometer()
	_apply_header_photo(str(vehicle.get("photo", "")))
	_build_rows(vehicle)


func _apply_header_photo(filename: String) -> void:
	var tex := PhotoService.load_texture(filename)
	if tex != null:
		_photo_rect.texture = tex
		_photo_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_photo_rect.modulate = Color.WHITE
	else:
		_photo_rect.texture = ServiceIcons.CAR
		_photo_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_photo_rect.modulate = Color.WHITE


func _fill_header(current_id: String) -> void:
	_car_switch.visible = false
	var vehicles := GarageStore.vehicles_list()
	var multi := vehicles.size() >= 2
	_car_strip.visible = multi
	_photo_slot.visible = not multi
	_car_name.visible = not multi
	for child in _car_tiles.get_children():
		_car_tiles.remove_child(child)
		child.queue_free()
	if not multi:
		return
	for item in vehicles:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var vehicle: Dictionary = item
		var vid := str(vehicle.get("id", ""))
		_car_tiles.add_child(_make_tile(vehicle, vid == current_id))


func _make_tile(vehicle: Dictionary, selected: bool) -> Control:
	var vid := str(vehicle.get("id", ""))
	var wrap := Button.new()
	wrap.custom_minimum_size = Vector2(TILE, 82)
	wrap.flat = true
	var empty := StyleBoxEmpty.new()
	wrap.add_theme_stylebox_override("normal", empty)
	wrap.add_theme_stylebox_override("hover", empty)
	wrap.add_theme_stylebox_override("pressed", empty)
	wrap.add_theme_stylebox_override("focus", empty)
	wrap.pressed.connect(_on_tile_pressed.bind(vid))

	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 4)
	col.alignment = BoxContainer.ALIGNMENT_BEGIN

	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(TILE, TILE)
	panel.clip_contents = true
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_SURFACE
	style.set_corner_radius_all(12)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = COLOR_ACCENT if selected else COLOR_HAIRLINE
	panel.add_theme_stylebox_override("panel", style)

	var pad := MarginContainer.new()
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_theme_constant_override("margin_left", 4)
	pad.add_theme_constant_override("margin_top", 4)
	pad.add_theme_constant_override("margin_right", 4)
	pad.add_theme_constant_override("margin_bottom", 4)

	var hole := Panel.new()
	hole.clip_contents = true
	hole.clip_children = Control.CLIP_CHILDREN_AND_DRAW
	hole.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hole_style := StyleBoxFlat.new()
	hole_style.bg_color = COLOR_SURFACE
	hole_style.set_corner_radius_all(8)
	hole.add_theme_stylebox_override("panel", hole_style)

	var tex := PhotoService.load_texture(str(vehicle.get("photo", "")))
	if tex != null:
		var pic := TextureRect.new()
		pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		pic.texture = tex
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hole.add_child(pic)
	else:
		var glyph := TextureRect.new()
		glyph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		glyph.texture = ServiceIcons.CAR
		glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		glyph.modulate = Color.WHITE
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hole.add_child(glyph)
	pad.add_child(hole)
	panel.add_child(pad)

	var name_label := Label.new()
	name_label.text = _vehicle_display_name(vehicle)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.add_theme_color_override("font_color", COLOR_SECONDARY)
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.custom_minimum_size = Vector2(TILE, 0)

	col.add_child(panel)
	col.add_child(name_label)
	wrap.add_child(col)
	return wrap


func _on_tile_pressed(vehicle_id: String) -> void:
	if vehicle_id == GarageStore.selected_vehicle_id:
		_open_vehicle_edit.call_deferred()
		return
	GarageStore.selected_vehicle_id = vehicle_id
	_refresh_from_store.call_deferred()


func _vehicle_display_name(vehicle: Dictionary) -> String:
	var stored := str(vehicle.get("name", "")).strip_edges()
	if stored != "":
		return stored
	return ("%s %s %s" % [
		vehicle.get("year", ""),
		vehicle.get("make", ""),
		vehicle.get("model", ""),
	]).strip_edges()


func _apply_safe_area() -> void:
	var win := DisplayServer.window_get_size()
	if win.x <= 0 or win.y <= 0:
		return
	var safe := DisplayServer.get_display_safe_area()
	var vp := get_viewport_rect().size
	var sx := vp.x / float(win.x)
	var sy := vp.y / float(win.y)
	_safe_area.add_theme_constant_override(
		"margin_left", maxi(CONTENT_PAD, int(round(safe.position.x * sx)))
	)
	_safe_area.add_theme_constant_override(
		"margin_top", maxi(CONTENT_PAD, int(round(safe.position.y * sy)))
	)
	_safe_area.add_theme_constant_override(
		"margin_right", maxi(CONTENT_PAD, int(round((win.x - safe.end.x) * sx)))
	)
	_safe_area.add_theme_constant_override(
		"margin_bottom", maxi(CONTENT_PAD, int(round((win.y - safe.end.y) * sy)))
	)


func _refresh_odometer() -> void:
	_odometer.text = "%s mi" % _format_miles(_miles)


func _format_miles(value: int) -> String:
	var digits := str(value)
	var out := ""
	var count := 0
	for i in range(digits.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			out = "," + out
		out = digits[i] + out
		count += 1
	return out


func _build_rows(vehicle: Dictionary) -> void:
	for child in _service_rows.get_children():
		child.queue_free()
	var today := GarageStore.today_ymd()
	var odometer := int(vehicle.get("odometer", 0))
	var vehicle_id := str(vehicle.get("id", ""))
	var rows: Array = []
	for item in vehicle.get("services", []):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var service: Dictionary = item
		rows.append({
			"name": str(service.get("label", "")),
			"status": _status_for(service, odometer, today),
			"service_id": str(service.get("id", "")),
			"vehicle_id": vehicle_id,
			"type_id": str(service.get("type_id", "")),
			"next_date": str(service.get("next_date", "")),
			"next_miles": _as_int(service.get("next_miles"), 0),
		})
	rows.sort_custom(_status_sort)
	_refresh_summary(rows)
	var count := rows.size()
	var i := 0
	for row in rows:
		_service_rows.add_child(_make_row(row, i, count))
		i += 1


func _refresh_summary(rows: Array) -> void:
	var overdue := 0
	var soon := 0
	for row in rows:
		var status := str(row.get("status", ""))
		if status == "Overdue":
			overdue += 1
		elif status == "Due soon":
			soon += 1
	if overdue >= 1:
		_summary.text = "1 overdue" if overdue == 1 else "%d overdue" % overdue
		_summary.add_theme_color_override("font_color", STATUS_COLOR["Overdue"])
	elif soon >= 1:
		_summary.text = "1 due soon" if soon == 1 else "%d due soon" % soon
		_summary.add_theme_color_override("font_color", STATUS_COLOR["Due soon"])
	else:
		_summary.text = "All caught up"
		_summary.add_theme_color_override("font_color", STATUS_COLOR["OK"])


func _due_subtitle(next_date: String, next_miles: int) -> String:
	var date := next_date.strip_edges()
	var shown := DueMath.format_display_date(date)
	var has_date := shown != ""
	var has_miles := next_miles > 0
	if has_date and has_miles:
		return "Due %s · %s mi" % [shown, _format_miles(next_miles)]
	if has_date:
		return "Due %s" % shown
	if has_miles:
		return "Due %s mi" % _format_miles(next_miles)
	return "Log a first job"


func _status_for(service: Dictionary, odometer: int, today: String) -> String:
	var lead_days := int(GarageStore.data.get("notify_lead_days", 7))
	var code := DueMath.status(
		today,
		odometer,
		str(service.get("next_date", "")),
		_as_int(service.get("next_miles"), 0),
		lead_days,
		_as_int(service.get("interval_miles"), 0),
		_as_int(service.get("interval_months"), 0),
	)
	return str(STATUS_LABELS.get(code, "OK"))


func _as_int(value: Variant, fallback: int) -> int:
	if value == null:
		return fallback
	var value_type := typeof(value)
	if value_type == TYPE_INT or value_type == TYPE_FLOAT:
		return int(value)
	return fallback


func _status_sort(a: Dictionary, b: Dictionary) -> bool:
	return int(STATUS_ORDER.get(str(a["status"]), 9)) < int(STATUS_ORDER.get(str(b["status"]), 9))


func _make_row(row: Dictionary, index: int, count: int) -> Control:
	var service_name := str(row.get("name", ""))
	var status := str(row.get("status", "OK"))
	var vehicle_id := str(row.get("vehicle_id", ""))
	var service_id := str(row.get("service_id", ""))
	var type_id := str(row.get("type_id", ""))
	var next_date := str(row.get("next_date", ""))
	var next_miles := int(row.get("next_miles", 0))
	var status_color: Color = STATUS_COLOR.get(status, COLOR_PRIMARY)

	var wrap := Control.new()
	wrap.custom_minimum_size = Vector2(0, maxf(TAP_MIN, ROW_MIN))
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.clip_contents = true

	var btn := Button.new()
	btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn.pressed.connect(_on_service_row_pressed.bind(vehicle_id, service_id))
	var style := _row_style(index, count)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_stylebox_override("focus", style)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.offset_left = 16
	hbox.offset_right = -12
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 10)

	var glyph := TextureRect.new()
	glyph.texture = ServiceIcons.texture_for(type_id)
	glyph.custom_minimum_size = Vector2(28, 28)
	glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	glyph.modulate = Color.WHITE
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	titles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	titles.add_theme_constant_override("separation", 1)

	var name_label := Label.new()
	name_label.text = service_name
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.add_theme_color_override("font_color", COLOR_PRIMARY)
	name_label.add_theme_font_size_override("font_size", 17)

	var sub_label := Label.new()
	sub_label.text = _due_subtitle(next_date, next_miles)
	sub_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub_label.add_theme_color_override("font_color", COLOR_SECONDARY)
	sub_label.add_theme_font_size_override("font_size", 13)

	titles.add_child(name_label)
	titles.add_child(sub_label)

	var status_label := Label.new()
	status_label.text = status
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	status_label.add_theme_color_override("font_color", status_color)
	status_label.add_theme_font_size_override("font_size", 13)

	var chevron := TextureRect.new()
	chevron.texture = CHEVRON
	chevron.custom_minimum_size = Vector2(14, 14)
	chevron.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	chevron.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	chevron.modulate = COLOR_SECONDARY
	chevron.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chevron.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	hbox.add_child(glyph)
	hbox.add_child(titles)
	hbox.add_child(status_label)
	hbox.add_child(chevron)
	wrap.add_child(btn)
	wrap.add_child(hbox)
	if index < count - 1:
		var line := ColorRect.new()
		line.color = COLOR_HAIRLINE
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		line.offset_left = 16
		line.offset_right = -16
		line.offset_top = -1
		line.offset_bottom = 0
		wrap.add_child(line)
	return wrap


func _row_style(index: int, count: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_SURFACE
	if index == 0:
		style.corner_radius_top_left = 12
		style.corner_radius_top_right = 12
	if index == count - 1:
		style.corner_radius_bottom_left = 12
		style.corner_radius_bottom_right = 12
	return style


func _on_update_miles_pressed() -> void:
	_miles_edit.text = str(_miles)
	_miles_popup.visible = true
	_miles_edit.grab_focus()


func _on_miles_cancel() -> void:
	_miles_popup.visible = false


func _on_miles_set() -> void:
	var raw := _miles_edit.text.strip_edges().replace(",", "")
	if raw.is_valid_int():
		var parsed := int(raw)
		if parsed >= 0:
			GarageStore.set_odometer(parsed)
			_refresh_from_store()
	_miles_popup.visible = false


func _on_add_pressed() -> void:
	var vehicle := _current_display_vehicle()
	if GarageStore.selected_vehicle_id == "":
		GarageStore.selected_vehicle_id = str(vehicle.get("id", ""))
	get_tree().change_scene_to_file("res://scenes/service_add.tscn")


func _on_gear_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/settings.tscn")


func _on_photo_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			_open_vehicle_edit()


func _open_vehicle_edit() -> void:
	var vehicle := _current_display_vehicle()
	if GarageStore.selected_vehicle_id == "":
		GarageStore.selected_vehicle_id = str(vehicle.get("id", ""))
	get_tree().change_scene_to_file("res://scenes/vehicle_edit.tscn")


func _on_service_row_pressed(vehicle_id: String, service_id: String) -> void:
	GarageStore.selected_vehicle_id = vehicle_id
	GarageStore.selected_service_id = service_id
	get_tree().change_scene_to_file("res://scenes/service_list.tscn")
