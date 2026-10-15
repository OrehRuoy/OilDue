extends Control

const DueMath = preload("res://scripts/due_math.gd")

var _date := ""


func _ready() -> void:
	%SkipButton.pressed.connect(_go_more)
	%NotSureButton.pressed.connect(_go_more)
	%DateButton.pressed.connect(_on_date_pressed)
	%SaveButton.pressed.connect(_on_save_pressed)
	%SaveButton.disabled = true
	if not DateService.picked.is_connected(_on_date_picked):
		DateService.picked.connect(_on_date_picked)


func _exit_tree() -> void:
	if DateService.picked.is_connected(_on_date_picked):
		DateService.picked.disconnect(_on_date_picked)


func _on_date_pressed() -> void:
	var start := _date if _date != "" else GarageStore.today_ymd()
	DateService.pick(start)


func _on_date_picked(ymd: String) -> void:
	if DueMath.parse_ymd(ymd).is_empty():
		return
	_date = ymd
	var shown := DueMath.format_display_date(ymd)
	%DateButton.text = shown if shown != "" else ymd
	%SaveButton.disabled = false


func _on_save_pressed() -> void:
	if DueMath.parse_ymd(_date).is_empty():
		_go_more()
		return
	var vehicle := GarageStore._current_vehicle()
	var oil_id := ""
	for item in vehicle.get("services", []):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var service: Dictionary = item
		if str(service.get("type_id", "")) == "oil_change":
			oil_id = str(service.get("id", ""))
			break
	if oil_id == "":
		_go_more()
		return
	GarageStore.selected_service_id = oil_id
	var miles := int(vehicle.get("odometer", 0))
	var raw := str(%OdometerEdit.text).strip_edges().replace(",", "")
	if raw != "" and raw.is_valid_int() and int(raw) >= 0:
		miles = DueMath.display_to_miles(int(raw))
	GarageStore.log_service(_date, miles, 0, "")
	_go_more()


func _go_more() -> void:
	get_tree().change_scene_to_file("res://scenes/more_services.tscn")
