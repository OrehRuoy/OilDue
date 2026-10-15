extends Control

const DueMath = preload("res://scripts/due_math.gd")

@onready var _kind: Label = %KindLabel
@onready var _summary: Label = %SummaryLabel
@onready var _samples: Label = %SampleLabel
@onready var _skipped: Label = %SkippedLabel
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
		current_name = tr("this car")
	_photos.text = tr("CSV does not include photos.")
	_merge.custom_minimum_size = Vector2(0, 44)
	_merge.pressed.connect(_on_merge_pressed)
	%CancelButton.pressed.connect(_on_cancel_pressed)

	var ok := bool(parsed.get("ok", false))
	if not ok:
		_kind.text = ""
		_summary.text = ""
		_samples.text = ""
		_skipped.text = ""
		_warning.text = ""
		var err := str(parsed.get("error", "")).strip_edges()
		if err == "":
			err = "Couldn't read this file. Email it to support and log by hand for now."
		_error.text = tr(err)
		_merge.text = tr("Add these jobs to %s") % current_name
		_merge.disabled = true
		return

	_error.text = ""
	_kind.text = _kind_line(str(parsed.get("kind", "")))
	_summary.text = _summary_line(parsed)
	_samples.text = _sample_block(parsed)
	_skipped.text = _skipped_line(int(parsed.get("skipped", 0)))
	_warning.text = _name_warning(parsed, current_name)
	var jobs: Array = parsed.get("jobs", [])
	if jobs.size() > 0:
		_merge.text = tr("Add these jobs to %s") % current_name
	else:
		_merge.text = tr("Update %s from this file") % current_name
	var can_write := _can_write(parsed) and not vehicle.is_empty()
	_merge.disabled = not can_write
	if not can_write and _error.text == "":
		_error.text = tr("No jobs to import.")


func _kind_line(kind: String) -> String:
	if kind == "vmt_maintenance":
		return tr("Vehicle Maintenance Tracker jobs")
	if kind == "vmt_equipment":
		return tr("Vehicle Maintenance Tracker car")
	return tr("Spreadsheet")


func _summary_line(parsed: Dictionary) -> String:
	var kind := str(parsed.get("kind", ""))
	var jobs: Array = parsed.get("jobs", [])
	var vehicles: Array = parsed.get("vehicles", [])
	if kind == "vmt_maintenance":
		if jobs.size() == 1:
			return tr("1 job")
		return tr("%d jobs") % jobs.size()
	if kind == "vmt_equipment":
		if vehicles.size() == 1:
			return tr("1 car")
		return tr("%d cars") % vehicles.size()
	var car_bit := tr("1 car") if vehicles.size() == 1 else tr("%d cars") % vehicles.size()
	var job_bit := tr("1 job") if jobs.size() == 1 else tr("%d jobs") % jobs.size()
	return tr("%s, %s") % [car_bit, job_bit]


func _sample_block(parsed: Dictionary) -> String:
	var lines: PackedStringArray = PackedStringArray()
	var jobs: Array = parsed.get("jobs", [])
	var job_n := mini(3, jobs.size())
	for i in job_n:
		if typeof(jobs[i]) != TYPE_DICTIONARY:
			continue
		var job: Dictionary = jobs[i]
		var shown := DueMath.format_display_date(str(job.get("date", "")))
		if shown == "":
			shown = str(job.get("date", ""))
		lines.append("%s · %s · %s · %s" % [
			shown,
			tr(str(job.get("label", ""))),
			DueMath.format_distance(int(job.get("miles", 0))),
			DueMath.format_cents(int(job.get("cost_cents", 0))),
		])
	if not lines.is_empty():
		return "\n".join(lines)
	var vehicles: Array = parsed.get("vehicles", [])
	var car_n := mini(3, vehicles.size())
	for i in car_n:
		if typeof(vehicles[i]) != TYPE_DICTIONARY:
			continue
		var car: Dictionary = vehicles[i]
		var name := str(car.get("name", "")).strip_edges()
		var year := int(car.get("year", 0))
		var year_s := str(year) if year > 0 else ""
		var spec := ("%s %s %s" % [year_s, str(car.get("make", "")), str(car.get("model", ""))]).strip_edges()
		if name == "":
			lines.append(spec)
		elif spec == "":
			lines.append(name)
		else:
			lines.append("%s · %s" % [name, spec])
	return "\n".join(lines)


func _skipped_line(skipped: int) -> String:
	if skipped == 1:
		return tr("Skipped 1 row with no date or job name.")
	if skipped > 1:
		return tr("Skipped %d rows with no date or job name.") % skipped
	return ""


func _can_write(parsed: Dictionary) -> bool:
	var jobs: Array = parsed.get("jobs", [])
	if jobs.size() > 0:
		return true
	var vehicles: Array = parsed.get("vehicles", [])
	if vehicles.is_empty():
		return false
	var kind := str(parsed.get("kind", ""))
	return kind == "vmt_equipment" or kind == "generic"


func _name_warning(parsed: Dictionary, current_name: String) -> String:
	var incoming := _incoming_name(parsed)
	if incoming == "" or incoming == current_name:
		return ""
	return tr("This file is %s. Merge will apply it onto %s.") % [incoming, current_name]


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
		_error.text = tr("Couldn't merge onto this car.")
		return
	GarageStore.pending_import = {}
	get_tree().change_scene_to_file("res://scenes/garage.tscn")


func _on_cancel_pressed() -> void:
	GarageStore.pending_import = {}
	get_tree().change_scene_to_file("res://scenes/settings.tscn")
