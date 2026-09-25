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

	var empty := CsvImport.parse_text("")
	fail = _expect(not bool(empty.get("ok", true)), "empty not ok")
	if fail != "":
		return fail
	fail = _expect(str(empty.get("error", "")) == "This file has no rows.", "empty no rows")
	if fail != "":
		return fail

	var header_only := "Id,VIN,Plate,Name,Description,Odometer,EngineHour,PartCost,LaborCost,MaintainedBy,Status,ServiceDate,CreateDate,Note\n"
	var bare := CsvImport.parse_text(header_only)
	fail = _expect(not bool(bare.get("ok", true)), "header only not ok")
	if fail != "":
		return fail
	fail = _expect(str(bare.get("error", "")) == "This file has no rows.", "header only no rows")
	if fail != "":
		return fail

	var folded := CsvImport.parse_text(
		"servicedate,partcost,description,name,odometer,laborcost\n"
		+ "2026-08-26T14:20:13,100,Oil & filter,OUTLANDER,79000,25\n"
	)
	fail = _expect(str(folded.get("kind", "")) == "vmt_maintenance", "headers ignore case")
	if fail != "":
		return fail
	var folded_jobs: Array = folded.get("jobs", [])
	fail = _expect(folded_jobs.size() == 1, "folded one job")
	if fail != "":
		return fail
	var folded_job: Dictionary = folded_jobs[0]
	fail = _expect(str(folded_job.get("date", "")) == "2026-08-26", "T time stays on the civil day")
	if fail != "":
		return fail
	fail = _expect(int(folded_job.get("cost_cents", 0)) == 12500, "folded cost 12500")
	if fail != "":
		return fail

	var semi := CsvImport.parse_text(
		"ServiceDate;PartCost;Description;Name;Odometer;LaborCost\n"
		+ "8/5/2026;10;Tires;OUTLANDER;1000;2\n"
	)
	fail = _expect(str(semi.get("kind", "")) == "vmt_maintenance", "semicolon kind")
	if fail != "":
		return fail
	var semi_jobs: Array = semi.get("jobs", [])
	fail = _expect(semi_jobs.size() == 1, "semicolon one job")
	if fail != "":
		return fail
	var semi_job: Dictionary = semi_jobs[0]
	fail = _expect(str(semi_job.get("date", "")) == "2026-08-05", "unpadded M/D/YYYY")
	if fail != "":
		return fail
	fail = _expect(str(semi_job.get("label", "")) == "Tires", "semicolon label")
	if fail != "":
		return fail

	var mixed := CsvImport.parse_text(
		"ServiceDate,PartCost,Description,LaborCost\n"
		+ "not-a-date,1,Oil,0\n"
		+ ",1,,0\n"
		+ "08/01/2026,4,Brakes,1\n"
	)
	fail = _expect(bool(mixed.get("ok", false)), "mixed file ok")
	if fail != "":
		return fail
	var mixed_jobs: Array = mixed.get("jobs", [])
	fail = _expect(mixed_jobs.size() == 1, "mixed keeps the dated job")
	if fail != "":
		return fail
	fail = _expect(int(mixed.get("skipped", 0)) == 2, "mixed skips two rows")
	if fail != "":
		return fail
	return ""


func _expect(ok: bool, message: String) -> String:
	if ok:
		return ""
	return message
