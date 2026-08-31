extends Control

const ServiceIcons = preload("res://scripts/service_icons.gd")

var _choices: Array = []

@onready var _type_option: OptionButton = %TypeOption
@onready var _custom_block: VBoxContainer = %CustomBlock
@onready var _name_edit: LineEdit = %NameEdit
@onready var _miles_edit: LineEdit = %MilesEdit
@onready var _months_edit: LineEdit = %MonthsEdit
@onready var _error: Label = %ErrorLabel


func _ready() -> void:
	_type_option.add_theme_constant_override("icon_max_width", 28)
	_fill_types()
	_type_option.item_selected.connect(_on_type_selected)
	%AddButton.pressed.connect(_on_add_pressed)
	_on_type_selected(_type_option.selected)
	_error.text = ""


func _fill_types() -> void:
	_choices.clear()
	_type_option.clear()
	var vehicle := GarageStore.vehicle_by_id(GarageStore.selected_vehicle_id)
	if vehicle.is_empty():
		vehicle = GarageStore.primary_vehicle()
	var taken := {}
	for item in vehicle.get("services", []):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		taken[str(item.get("type_id", ""))] = true
	for tmpl in GarageStore.load_templates():
		if typeof(tmpl) != TYPE_DICTIONARY:
			continue
		var type_id := str(tmpl.get("id", ""))
		if type_id == "":
			continue
		if type_id != "custom" and taken.has(type_id):
			continue
		_choices.append(tmpl)
		_type_option.add_icon_item(
			ServiceIcons.texture_for(type_id),
			str(tmpl.get("name", type_id)),
		)
	if _choices.is_empty():
		_choices.append({"id": "custom", "name": "Custom", "interval_miles": 0, "interval_months": 0})
		_type_option.add_icon_item(ServiceIcons.WRENCH, "Custom")


func _on_type_selected(_index: int) -> void:
	var tmpl := _selected_template()
	var is_custom := str(tmpl.get("id", "")) == "custom"
	_custom_block.visible = is_custom
	if is_custom:
		_name_edit.text = ""
		_miles_edit.text = ""
		_months_edit.text = ""


func _selected_template() -> Dictionary:
	var i := _type_option.selected
	if i < 0 or i >= _choices.size():
		return {}
	if typeof(_choices[i]) != TYPE_DICTIONARY:
		return {}
	return _choices[i]


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
