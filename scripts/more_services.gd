extends Control

const CHOICES := [
	{"id": "tire_replace", "label": "Tires"},
	{"id": "brake_inspect", "label": "Brakes"},
	{"id": "air_filter", "label": "Filters"},
	{"id": "coolant", "label": "Coolant"},
	{"id": "battery", "label": "Battery"},
	{"id": "wipers", "label": "Wipers"},
	{"id": "inspection", "label": "Inspection"},
	{"id": "custom", "label": "Custom"},
]


func _ready() -> void:
	%DoneButton.pressed.connect(_on_done)
	for item in CHOICES:
		var choice: Dictionary = item
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 48)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.text = tr(str(choice.get("label", "")))
		var type_id := str(choice.get("id", ""))
		btn.pressed.connect(_on_add.bind(type_id, btn))
		%ChoiceList.add_child(btn)


func _on_add(type_id: String, btn: Button) -> void:
	if type_id == "custom":
		get_tree().change_scene_to_file("res://scenes/service_add.tscn")
		return
	if _has_type(type_id):
		btn.disabled = true
		return
	var tmpl := _template(type_id)
	var label := str(tmpl.get("name", type_id))
	var miles := int(tmpl.get("interval_miles", 0))
	var months := int(tmpl.get("interval_months", 0))
	if GarageStore.add_service(type_id, label, miles, months):
		btn.disabled = true
		btn.text = tr("%s added") % tr(label)


func _has_type(type_id: String) -> bool:
	var vehicle := GarageStore._current_vehicle()
	for item in vehicle.get("services", []):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		if str(item.get("type_id", "")) == type_id:
			return true
	return false


func _template(type_id: String) -> Dictionary:
	for item in GarageStore.load_templates():
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = item
		if str(row.get("id", "")) == type_id:
			return row
	return {}


func _on_done() -> void:
	get_tree().change_scene_to_file("res://scenes/garage.tscn")
