extends Control

const DueMath = preload("res://scripts/due_math.gd")
const ServiceIcons = preload("res://scripts/service_icons.gd")
const PanScroll = preload("res://scripts/pan_scroll.gd")
const TAP_MIN := 44.0
const ROW_MIN := 64.0
const TILE := 72.0
const TILE_WRAP_H := 120.0
const COLOR_PRIMARY := Color("#F4EFE6")
const COLOR_SURFACE := Color("#2A2622")
const COLOR_HAIRLINE := Color("#3D3832")
const COLOR_SECONDARY := Color("#9A9388")
const COLOR_MUTED := Color("#9A9388")
const COLOR_ACCENT := Color("#FF453A")
const COLOR_SOON := Color("#FF9F0A")
const CHEVRON := preload("res://assets/icons/chevron_right.png")
const ConfirmSheet = preload("res://scripts/confirm_sheet.gd")

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
	"OK": Color("#9A9388"),
}

@onready var _car_strip: ScrollContainer = %CarStrip
@onready var _car_tiles: HBoxContainer = %CarTiles
@onready var _card_photo: Panel = %CardPhoto
@onready var _card_hole: Panel = %CardHole
@onready var _card_nick: Button = %CardNick
@onready var _due_chip: Label = %DueChip
@onready var _card_spec: Label = %CardSpec
@onready var _miles_val: Button = %MilesVal
@onready var _due_cap: Label = %DueCap
@onready var _due_val: Label = %DueVal
@onready var _log_button: Button = %LogButton
@onready var _add_service: Button = %AddService
@onready var _service_rows: VBoxContainer = %ServiceRows
@onready var _listing_card: Control = %ListingCard
@onready var _welcome_card: Control = %WelcomeCard
@onready var _service_scroll: Control = %ServiceScroll
@onready var _miles_popup: ColorRect = %MilesPopup
@onready var _miles_edit: LineEdit = %MilesEdit

var _miles: int = 0
var _focus_service_id := ""
var _leaving := false


func _ready() -> void:
	if GarageStore.vehicles_list().is_empty():
		_go("res://scenes/vehicle_add.tscn")
		return
	_refresh_from_store()
	_miles_popup.visible = false
	%Gear.pressed.connect(_on_gear_pressed)
	%AddService.pressed.connect(_on_add_pressed)
	%MilesCancel.pressed.connect(_on_miles_cancel)
	%MilesSet.pressed.connect(_on_miles_set)
	_miles_popup.gui_input.connect(_on_miles_dim_gui_input)
	_miles_edit.text_submitted.connect(func(_t: String) -> void: _on_miles_set())
	_card_nick.pressed.connect(_open_vehicle_edit)
	_card_photo.gui_input.connect(_on_photo_gui_input)
	_miles_val.pressed.connect(_on_update_miles_pressed)
	_log_button.pressed.connect(_on_log_pressed)
	%WelcomeAdd.pressed.connect(_on_welcome_add_pressed)
	NotifyService.reschedule()
	_maybe_show_log_tip()


func _current_display_vehicle() -> Dictionary:
	var vehicle := GarageStore.vehicle_by_id(GarageStore.selected_vehicle_id)
	if vehicle.is_empty() or bool(vehicle.get("archived", false)):
		vehicle = GarageStore.primary_vehicle()
		GarageStore.selected_vehicle_id = str(vehicle.get("id", ""))
	return vehicle


func _refresh_from_store() -> void:
	if GarageStore.vehicles_list().is_empty():
		_go("res://scenes/vehicle_add.tscn")
		return
	_welcome_card.visible = false
	_listing_card.visible = true
	_service_scroll.visible = true
	var vehicle := _current_display_vehicle()
	_fill_header(str(vehicle.get("id", "")))
	_miles = int(vehicle.get("odometer", 0))
	_fill_card(vehicle)
	_build_rows(vehicle)


func _maybe_show_log_tip() -> void:
	if bool(GarageStore.data.get("log_tip_seen", true)):
		return
	ConfirmSheet.present(
		self,
		"When you do a service, tap Log.",
		"",
		"Got it",
		"",
		Callable(),
		_on_log_tip_dismissed
	)


func _on_log_tip_dismissed() -> void:
	GarageStore.mark_log_tip_seen()


func _fill_card_photo(filename: String) -> void:
	for child in _card_hole.get_children():
		_card_hole.remove_child(child)
		child.queue_free()
	var tex := PhotoService.load_texture(filename)
	if tex != null:
		var pic := TextureRect.new()
		pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pic.texture = tex
		_card_hole.add_child(pic)
		return
	var wrap := CenterContainer.new()
	wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ServiceIcons.CAR != null:
		var glyph := TextureRect.new()
		glyph.texture = ServiceIcons.CAR
		glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		glyph.custom_minimum_size = Vector2(40, 40)
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wrap.add_child(glyph)
	_card_hole.add_child(wrap)


func _fill_header(current_id: String) -> void:
	var vehicles := GarageStore.vehicles_list()
	_car_strip.visible = true
	for child in _car_tiles.get_children():
		_car_tiles.remove_child(child)
		child.queue_free()
	for item in vehicles:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var vehicle: Dictionary = item
		var vid := str(vehicle.get("id", ""))
		_car_tiles.add_child(_make_tile(vehicle, vid == current_id))
	_car_tiles.add_child(_make_add_tile())


func _make_tile(vehicle: Dictionary, selected: bool) -> Control:
	var vid := str(vehicle.get("id", ""))
	var wrap := Button.new()
	wrap.custom_minimum_size = Vector2(TILE, TILE_WRAP_H)
	wrap.flat = true
	var empty := StyleBoxEmpty.new()
	wrap.add_theme_stylebox_override("normal", empty)
	wrap.add_theme_stylebox_override("hover", empty)
	wrap.add_theme_stylebox_override("pressed", empty)
	wrap.add_theme_stylebox_override("focus", empty)
	PanScroll.wire(wrap, _on_tile_pressed.bind(vid))

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
	elif ServiceIcons.CAR != null:
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
	name_label.text = _tile_caption_text(vehicle)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.clip_text = false
	name_label.max_lines_visible = 3
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.add_theme_color_override("font_color", COLOR_SECONDARY)
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.custom_minimum_size = Vector2(TILE, 36)

	col.add_child(panel)
	col.add_child(name_label)
	wrap.add_child(col)
	return wrap


func _make_add_tile() -> Control:
	var wrap := Button.new()
	wrap.custom_minimum_size = Vector2(TILE, TILE_WRAP_H)
	wrap.flat = true
	var empty := StyleBoxEmpty.new()
	wrap.add_theme_stylebox_override("normal", empty)
	wrap.add_theme_stylebox_override("hover", empty)
	wrap.add_theme_stylebox_override("pressed", empty)
	wrap.add_theme_stylebox_override("focus", empty)
	PanScroll.wire(wrap, _on_add_car_tile_pressed)

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
	style.border_color = COLOR_HAIRLINE
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

	var plus := Label.new()
	plus.text = "+"
	plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plus.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	plus.add_theme_color_override("font_color", COLOR_PRIMARY)
	plus.add_theme_font_size_override("font_size", 28)
	plus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hole.add_child(plus)
	pad.add_child(hole)
	panel.add_child(pad)

	var name_label := Label.new()
	name_label.text = "Add"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.add_theme_color_override("font_color", COLOR_MUTED)
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.custom_minimum_size = Vector2(TILE, 0)

	col.add_child(panel)
	col.add_child(name_label)
	wrap.add_child(col)
	return wrap


func _on_add_car_tile_pressed() -> void:
	if GarageStore.vehicles_list().is_empty() or GarageStore.is_unlocked():
		_go("res://scenes/vehicle_add.tscn")
		return
	GarageStore.unlock_back_scene = "res://scenes/garage.tscn"
	_go("res://scenes/unlock.tscn")


func _on_welcome_add_pressed() -> void:
	_on_add_car_tile_pressed()


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
	return _vehicle_spec_line(vehicle)


func _generated_vehicle_name(vehicle: Dictionary) -> String:
	var year := _as_int(vehicle.get("year"), 0)
	var make := str(vehicle.get("make", "")).strip_edges()
	var model := str(vehicle.get("model", "")).strip_edges()
	return ("%s %s %s" % [year, make, model]).strip_edges()


func _card_nick_text(vehicle: Dictionary) -> String:
	var stored := str(vehicle.get("name", "")).strip_edges()
	if stored == "" or stored != _generated_vehicle_name(vehicle):
		return _vehicle_display_name(vehicle)
	var year := _as_int(vehicle.get("year"), 0)
	var rest := ("%s %s" % [
		str(vehicle.get("make", "")).strip_edges(),
		str(vehicle.get("model", "")).strip_edges(),
	]).strip_edges()
	if year > 0 and rest != "":
		return "%s\n%s" % [str(year), rest]
	return stored


func _tile_caption_text(vehicle: Dictionary) -> String:
	var stored := str(vehicle.get("name", "")).strip_edges()
	if stored != "" and stored != _generated_vehicle_name(vehicle):
		return stored
	var year := _as_int(vehicle.get("year"), 0)
	var make := str(vehicle.get("make", "")).strip_edges()
	var model := str(vehicle.get("model", "")).strip_edges()
	var parts: PackedStringArray = PackedStringArray()
	if year > 0:
		parts.append(str(year))
	if make != "":
		parts.append(make)
	if model != "":
		parts.append(model)
	if parts.is_empty():
		return stored
	return "\n".join(parts)


func _apply_card_nick(nick: String) -> void:
	for child in _card_nick.get_children():
		_card_nick.remove_child(child)
		child.queue_free()
	_card_nick.text = ""
	_card_nick.clip_text = false
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 0)
	var lines := nick.split("\n")
	for i in range(lines.size()):
		var lab := Label.new()
		lab.text = str(lines[i])
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lab.clip_text = false
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lab.add_theme_color_override("font_color", COLOR_PRIMARY)
		lab.add_theme_font_size_override("font_size", 24 if i == 0 else 17)
		col.add_child(lab)
	_card_nick.add_child(col)
	_card_nick.custom_minimum_size.y = 56 if lines.size() > 1 else 44


func _vehicle_spec_line(vehicle: Dictionary) -> String:
	var year := _as_int(vehicle.get("year"), 0)
	var make := str(vehicle.get("make", "")).strip_edges()
	var model := str(vehicle.get("model", "")).strip_edges()
	var parts: PackedStringArray = PackedStringArray()
	if year > 0:
		parts.append(str(year))
	if make != "":
		parts.append(make)
	if model != "":
		parts.append(model)
	return " ".join(parts)


func _fill_card(vehicle: Dictionary) -> void:
	_fill_card_photo(str(vehicle.get("photo", "")))
	var nick := _card_nick_text(vehicle)
	_apply_card_nick(nick)
	var spec := _vehicle_spec_line(vehicle)
	var stacked := nick.contains("\n")
	_card_spec.text = "" if stacked else spec
	_card_spec.visible = not stacked and spec != ""
	_miles_val.text = _format_miles(_miles)
	var rows := _collect_rows(vehicle)
	_add_service.text = "Add another service" if rows.size() >= 1 else "Add service"
	if rows.is_empty():
		_focus_service_id = ""
		_due_cap.text = "OIL"
		_due_val.text = "—"
		_style_chip("OK")
		_log_button.visible = false
		return
	var top: Dictionary = rows[0]
	_focus_service_id = str(top.get("service_id", ""))
	var type_id := str(top.get("type_id", ""))
	if type_id == "oil_change":
		_due_cap.text = "OIL"
		_log_button.text = "Log oil"
	else:
		var label := str(top.get("name", "")).strip_edges().to_upper()
		_due_cap.text = label if label != "" else "DUE"
		_log_button.text = "Log this service"
	var shown := DueMath.format_display_date(str(top.get("next_date", "")))
	_due_val.text = shown if shown != "" else "—"
	_style_chip(str(top.get("status", "OK")))
	_log_button.visible = _focus_service_id != ""


func _style_chip(status: String) -> void:
	_due_chip.text = status
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(10)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	if status == "Overdue":
		style.bg_color = COLOR_ACCENT
		_due_chip.add_theme_color_override("font_color", COLOR_PRIMARY)
	elif status == "Due soon":
		style.bg_color = COLOR_SURFACE
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		style.border_color = COLOR_SOON
		_due_chip.add_theme_color_override("font_color", COLOR_SOON)
	else:
		style.bg_color = COLOR_SURFACE
		_due_chip.add_theme_color_override("font_color", COLOR_MUTED)
	_due_chip.add_theme_stylebox_override("normal", style)


func _format_miles(value: int) -> String:
	return DueMath.format_miles(value)


func _collect_rows(vehicle: Dictionary) -> Array:
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
	return rows


func _build_rows(vehicle: Dictionary) -> void:
	for child in _service_rows.get_children():
		child.queue_free()
	var rows := _collect_rows(vehicle)
	var count := rows.size()
	var i := 0
	for row in rows:
		_service_rows.add_child(_make_row(row, i, count))
		i += 1


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
	btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	PanScroll.wire(wrap, _on_service_row_pressed.bind(vehicle_id, service_id))
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


func _on_miles_dim_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			_on_miles_cancel()
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_on_miles_cancel()


func _on_miles_set() -> void:
	var raw := _miles_edit.text.strip_edges().replace(",", "")
	if raw.is_valid_int():
		var parsed := int(raw)
		if parsed >= 0:
			GarageStore.set_odometer(parsed)
			_refresh_from_store()
	_miles_popup.visible = false


func _on_log_pressed() -> void:
	if _focus_service_id == "":
		return
	var vehicle := _current_display_vehicle()
	GarageStore.selected_vehicle_id = str(vehicle.get("id", ""))
	GarageStore.selected_service_id = _focus_service_id
	_go("res://scenes/service_edit.tscn")


func _on_add_pressed() -> void:
	var vehicle := _current_display_vehicle()
	if GarageStore.selected_vehicle_id == "":
		GarageStore.selected_vehicle_id = str(vehicle.get("id", ""))
	_go("res://scenes/service_add.tscn")


func _on_gear_pressed() -> void:
	_go("res://scenes/settings.tscn")


func _on_photo_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			_open_vehicle_edit()
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_open_vehicle_edit()


func _open_vehicle_edit() -> void:
	var vehicle := _current_display_vehicle()
	if GarageStore.selected_vehicle_id == "":
		GarageStore.selected_vehicle_id = str(vehicle.get("id", ""))
	_go("res://scenes/vehicle_edit.tscn")


func _on_service_row_pressed(vehicle_id: String, service_id: String) -> void:
	GarageStore.selected_vehicle_id = vehicle_id
	GarageStore.selected_service_id = service_id
	_go("res://scenes/service_list.tscn")


func _go(path: String) -> void:
	if _leaving:
		return
	_leaving = true
	get_tree().change_scene_to_file(path)
