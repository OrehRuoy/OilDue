extends Control

const DueMath = preload("res://scripts/due_math.gd")

@onready var _kind: Label = %KindLabel
@onready var _summary: Label = %SummaryLabel
@onready var _photos: Label = %PhotosLabel
@onready var _warning: Label = %WarningLabel
@onready var _error: Label = %ErrorLabel
@onready var _merge: Button = %MergeButton


func _ready() -> void:
	var parsed: Dictionary = GarageStore.pending_import
	if typeof(parsed) != TYPE_DICTIONARY:
		parsed = {}
	var vehicle := GarageStore.vehicle_by_id(GarageStore.selected_vehicle_id)
	if vehicle.is_empty():
		vehicle = GarageStore.primary_vehicle()
	var current_name := str(vehicle.get("name", "")).strip_edges()
	if current_name == "":
		current_name = "this car"
	_photos.text = "CSV does not include photos."
	_merge.text = "Merge onto %s" % current_name
	_merge.custom_minimum_size = Vector2(0, 44)
	_merge.pressed.connect(_on_merge_pressed)
	%CancelButton.pressed.connect(_on_cancel_pressed)

	var ok := bool(parsed.get("ok", false))
	if not ok:
		_kind.text = "error"
		_summary.text = ""
		_warning.text = ""
		var err := str(parsed.get("error", "")).strip_edges()
		if err == "":
			err = "Couldn't read this file. Email it to support and log by hand for now."
		_error.text = err
		_merge.disabled = true
		return

	_error.text = ""
	_kind.text = str(parsed.get("kind", ""))
	_summary.text = _summary_line(parsed)
	_warning.text = _name_warning(parsed, current_name)
	if vehicle.is_empty():
		_merge.disabled = true


func _summary_line(parsed: Dictionary) -> String:
	var kind := str(parsed.get("kind", ""))
	if kind == "vmt_maintenance":
		var jobs: Array = parsed.get("jobs", [])
		if jobs.size() == 1 and typeof(jobs[0]) == TYPE_DICTIONARY:
			var job: Dictionary = jobs[0]
			return "1 job, %s, %s, %s mi, %s" % [
				str(job.get("label", "")),
				str(job.get("date", "")),
				str(int(job.get("miles", 0))),
				DueMath.format_cents(int(job.get("cost_cents", 0))),
			]
		return "%d jobs" % jobs.size()
	if kind == "vmt_equipment":
		var cars: Array = parsed.get("vehicles", [])
		if cars.size() == 1 and typeof(cars[0]) == TYPE_DICTIONARY:
			var car: Dictionary = cars[0]
			return "1 car, %s, %s, plate %s" % [
				str(car.get("name", "")),
				str(int(car.get("year", 0))),
				str(car.get("plate", "")),
			]
		return "%d cars" % cars.size()
	var vehicles: Array = parsed.get("vehicles", [])
	var jobs_g: Array = parsed.get("jobs", [])
	return "%d cars, %d jobs" % [vehicles.size(), jobs_g.size()]


func _name_warning(parsed: Dictionary, current_name: String) -> String:
	var incoming := _incoming_name(parsed)
	if incoming == "" or incoming == current_name:
		return ""
	return "This file is %s. Merge will apply it onto %s." % [incoming, current_name]


func _incoming_name(parsed: Dictionary) -> String:
	var vehicles: Array = parsed.get("vehicles", [])
	if vehicles.size() >= 1 and typeof(vehicles[0]) == TYPE_DICTIONARY:
		var name := str(vehicles[0].get("name", "")).strip_edges()
		if name != "":
			return name
	var jobs: Array = parsed.get("jobs", [])
	if jobs.size() >= 1 and typeof(jobs[0]) == TYPE_DICTIONARY:
		return str(jobs[0].get("vehicle_name", "")).strip_edges()
	return ""


func _on_merge_pressed() -> void:
	if not GarageStore.import_merge(GarageStore.pending_import):
		_error.text = "Couldn't merge onto this car."
		return
	GarageStore.pending_import = {}
	get_tree().change_scene_to_file("res://scenes/garage.tscn")


func _on_cancel_pressed() -> void:
	GarageStore.pending_import = {}
	get_tree().change_scene_to_file("res://scenes/settings.tscn")
