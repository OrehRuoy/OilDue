extends Control

const ServiceIcons = preload("res://scripts/service_icons.gd")
const PanScroll = preload("res://scripts/pan_scroll.gd")
const COLOR_SURFACE := Color("#2A2622")
const COLOR_SELECTED := Color("#3D3832")
const COLOR_CREAM := Color("#EDE4D4")
const COLOR_PRIMARY := Color("#F4EFE6")

var _choices: Array = []
var _selected := -1
var _row_buttons: Array = []

@onready var _type_rows: VBoxContainer = %TypeRows
@onready var _custom_block: VBoxContainer = %CustomBlock
@onready var _name_edit: LineEdit = %NameEdit
@onready var _miles_edit: LineEdit = %MilesEdit
@onready var _months_edit: LineEdit = %MonthsEdit
@onready var _error: Label = %ErrorLabel


func _ready() -> void:
	_fill_types()
	%AddButton.pressed.connect(_on_add_pressed)
	_apply_selection(-1)
	_error.text = ""
	PanScroll.wire_fields(_custom_block)


func _fill_types() -> void:
	_choices.clear()
	for child in _type_rows.get_children():
		_type_rows.remove_child(child)
		child.queue_free()
	_row_buttons.clear()
	var vehicle := GarageStore.vehicle_by_id(GarageStore.selected_vehicle_id)
	if vehicle.is_empty():
		vehicle = GarageStore.primary_vehicle()
	var taken := {}
	for item in vehicle.get("services", []):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		taken[str(item.get("type_id", ""))] = true
	var custom_tmpl: Dictionary = {}
	for tmpl in GarageStore.load_templates():
		if typeof(tmpl) != TYPE_DICTIONARY:
			continue
		var type_id := str(tmpl.get("id", ""))
		if type_id == "":
			continue
		if type_id == "custom":
			custom_tmpl = tmpl
			continue
		if taken.has(type_id):
			continue
		_choices.append(tmpl)
	if custom_tmpl.is_empty():
		custom_tmpl = {"id": "custom", "name": "Custom", "interval_miles": 0, "interval_months": 0}
	_choices.append(custom_tmpl)
	for i in range(_choices.size()):
		var row_tmpl: Dictionary = _choices[i]
		var btn := _make_type_row(i, row_tmpl)
		_row_buttons.append(btn)
		_type_rows.add_child(btn)
		if i < _choices.size() - 1:
			var line := ColorRect.new()
			line.custom_minimum_size = Vector2(0, 1)
			line.color = COLOR_SELECTED
			line.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_type_rows.add_child(line)
	_selected = -1


func _make_type_row(index: int, tmpl: Dictionary) -> Button:
	var type_id := str(tmpl.get("id", ""))
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 52)
	btn.clip_contents = false
	btn.flat = true
	btn.text = ""
	btn.pressed.connect(_on_type_row_pressed.bind(index))
	PanScroll.wire(btn, _on_type_row_pressed.bind(index))

	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.offset_left = 12
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

	var label := Label.new()
	label.text = str(tmpl.get("name", type_id))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", COLOR_PRIMARY)
	label.add_theme_font_size_override("font_size", 17)

	hbox.add_child(glyph)
	hbox.add_child(label)
	btn.add_child(hbox)
	btn.add_theme_stylebox_override("normal", _row_style(false))
	btn.add_theme_stylebox_override("hover", _row_style(false))
	btn.add_theme_stylebox_override("pressed", _row_style(false))
	btn.add_theme_stylebox_override("focus", _row_style(false))
	return btn


func _on_type_row_pressed(index: int) -> void:
	_apply_selection(index)


func _apply_selection(index: int) -> void:
	if index >= _choices.size():
		return
	_selected = index
	for i in range(_row_buttons.size()):
		var btn: Button = _row_buttons[i]
		var on := i == _selected
		btn.add_theme_stylebox_override("normal", _row_style(on))
		btn.add_theme_stylebox_override("hover", _row_style(on))
		btn.add_theme_stylebox_override("pressed", _row_style(on))
		btn.add_theme_stylebox_override("focus", _row_style(on))
	var picked := _selected >= 0
	%AddButton.disabled = not picked
	var tmpl := _selected_template()
	var is_custom := str(tmpl.get("id", "")) == "custom"
	_custom_block.visible = is_custom
	if is_custom:
		_name_edit.text = ""
		_miles_edit.text = ""
		_months_edit.text = ""


func _row_style(selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_SELECTED if selected else COLOR_SURFACE
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	if selected:
		style.border_color = COLOR_CREAM
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
	return style


func _selected_template() -> Dictionary:
	if _selected < 0 or _selected >= _choices.size():
		return {}
	if typeof(_choices[_selected]) != TYPE_DICTIONARY:
		return {}
	return _choices[_selected]


func _on_add_pressed() -> void:
	_error.text = ""
	var tmpl := _selected_template()
	if tmpl.is_empty():
		_error.text = "Pick a service."
		return
	var type_id := str(tmpl.get("id", ""))
	var label := str(tmpl.get("name", ""))
	var miles := int(tmpl.get("interval_miles", 0))
	var months := int(tmpl.get("interval_months", 0))
	if type_id == "custom":
		label = _name_edit.text.strip_edges()
		if label == "":
			_error.text = "Enter a name."
			return
		var miles_parsed := _parse_optional_int(_miles_edit.text)
		if not bool(miles_parsed["ok"]):
			_error.text = "Interval miles must be a whole number, or blank."
			return
		var months_parsed := _parse_optional_int(_months_edit.text)
		if not bool(months_parsed["ok"]):
			_error.text = "Interval months must be a whole number, or blank."
			return
		miles = int(miles_parsed["value"])
		months = int(months_parsed["value"])
	if not GarageStore.add_service(type_id, label, miles, months):
		_error.text = "Could not add this service."
		return
	get_tree().change_scene_to_file("res://scenes/garage.tscn")


func _parse_optional_int(raw: String) -> Dictionary:
	var s := raw.strip_edges()
	if s == "":
		return {"ok": true, "value": 0}
	if not s.is_valid_int():
		return {"ok": false, "value": 0}
	var n := int(s)
	if n < 0:
		return {"ok": false, "value": 0}
	return {"ok": true, "value": n}
