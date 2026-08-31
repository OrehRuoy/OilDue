extends Control

const CsvImport = preload("res://scripts/csv_import.gd")

@onready var _label: Label = %Result


func _ready() -> void:
	var fail := _run()
	if fail == "":
		_label.text = "PASS"
	else:
		_label.text = "FAIL: %s" % fail
	print(_label.text)


func _run() -> String:
	var equip := CsvImport.parse_file("res://tests/fixtures/vmt-equipment-sample.csv")
	var fail := _expect(bool(equip.get("ok", false)), "equipment ok")
	if fail != "":
		return fail
	fail = _expect(str(equip.get("kind", "")) == "vmt_equipment", "equipment kind")
	if fail != "":
		return fail
	var cars: Array = equip.get("vehicles", [])
	fail = _expect(cars.size() == 1, "equipment one vehicle")
	if fail != "":
		return fail
	var car: Dictionary = cars[0]
	fail = _expect(str(car.get("name", "")) == "OUTLANDER", "equipment name OUTLANDER")
	if fail != "":
		return fail
	fail = _expect(int(car.get("year", 0)) == 2020, "equipment year 2020")
	if fail != "":
		return fail
	fail = _expect(str(car.get("make", "")) == "OUTLANDER", "equipment make as written")
	if fail != "":
		return fail
	fail = _expect(str(car.get("model", "")) == "MITSUBISHI", "equipment model as written")
	if fail != "":
		return fail
	fail = _expect(str(car.get("plate", "")) == "Khgy", "equipment plate Khgy")
	if fail != "":
		return fail
	fail = _expect(int(car.get("odometer", -1)) == 0, "equipment odometer 0")
	if fail != "":
		return fail

	var maint := CsvImport.parse_file("res://tests/fixtures/vmt-maintenance-sample.csv")
	fail = _expect(bool(maint.get("ok", false)), "maintenance ok")
	if fail != "":
		return fail
	fail = _expect(str(maint.get("kind", "")) == "vmt_maintenance", "maintenance kind")
	if fail != "":
		return fail
	var jobs: Array = maint.get("jobs", [])
	fail = _expect(jobs.size() == 1, "maintenance one job")
	if fail != "":
		return fail
	var job: Dictionary = jobs[0]
	fail = _expect(str(job.get("vehicle_name", "")) == "OUTLANDER", "job name OUTLANDER")
	if fail != "":
		return fail
	fail = _expect(str(job.get("label", "")) == "Oil & filter", "job Oil & filter")
	if fail != "":
		return fail
	fail = _expect(int(job.get("miles", 0)) == 79000, "job 79000 mi")
	if fail != "":
		return fail
	fail = _expect(str(job.get("date", "")) == "2026-08-26", "job date 2026-08-26")
	if fail != "":
		return fail
	fail = _expect(int(job.get("cost_cents", 0)) == 12500, "job cost_cents 12500")
	if fail != "":
		return fail
	fail = _expect(str(job.get("plate", "")) == "Khgy", "job plate Khgy")
	if fail != "":
		return fail
	fail = _expect(
		CsvImport.parse_import_date("08/26/2026 14:20:13") == "2026-08-26",
		"time-of-day does not change the civil day"
	)
	if fail != "":
		return fail
	fail = _expect(
		CsvImport.parse_import_date("08/26/2026 23:59:59") == "2026-08-26",
		"late clock still 2026-08-26"
	)
	if fail != "":
		return fail

	var garbage := CsvImport.parse_file("res://tests/fixtures/no-such-file.csv")
	fail = _expect(not bool(garbage.get("ok", true)), "garbage ok == false")
	if fail != "":
		return fail
	fail = _expect(str(garbage.get("kind", "")) == "error", "garbage kind error")
	if fail != "":
		return fail
	fail = _expect(
		str(garbage.get("error", ""))
		== "Couldn't read this file. Email it to support and log by hand for now.",
		"garbage error sentence"
	)
	if fail != "":
		return fail
	return ""


func _expect(ok: bool, message: String) -> String:
	if ok:
		return ""
	return message
