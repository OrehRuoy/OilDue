extends Control

const CsvExport = preload("res://scripts/csv_export.gd")
const BackupZip = preload("res://scripts/backup_zip.gd")
const TEMP_ZIP := "user://test-day9.zip"

@onready var _label: Label = %Result


func _ready() -> void:
	var fail := _run()
	if fail == "":
		_label.text = "PASS"
	else:
		_label.text = "FAIL: %s" % fail
	print(_label.text)


func _run() -> String:
	var data := {
		"schema": 1,
		"vehicles": [
			{
				"name": "Daily",
				"year": 2018,
				"make": "Honda",
				"model": "Civic",
				"vin": "",
				"plate": "",
				"services": [
					{"id": "svc_oil", "label": "Oil & filter"},
					{"id": "svc_wipers", "label": "Wipers"},
				],
				"history": [
					{
						"service_id": "svc_oil",
						"date": "2026-08-26",
						"miles": 79000,
						"cost_cents": 12500,
						"notes": "oil, filter",
					}
				],
			}
		],
	}
	var csv := CsvExport.jobs_csv(data)
	var fail := _expect(csv.contains("2026-08-26"), "csv has 2026-08-26")
	if fail != "":
		return fail
	fail = _expect(not csv.contains("2026-08-25"), "csv is not 2026-08-25")
	if fail != "":
		return fail
	fail = _expect(csv.contains("125.00"), "csv has 125.00")
	if fail != "":
		return fail
	fail = _expect(not _has_unix_integer(csv), "csv has no unix integer")
	if fail != "":
		return fail
	fail = _expect(csv.contains("\"oil, filter\""), "comma notes are quoted")
	if fail != "":
		return fail
	fail = _expect(not csv.contains("Wipers"), "Wipers with no history get no row")
	if fail != "":
		return fail

	var json_text := JSON.stringify({
		"schema": 1,
		"vehicles": [
			{
				"name": "Daily",
				"history": [{"date": "2026-08-26"}],
			}
		],
	})
	fail = _expect(BackupZip.write_zip(TEMP_ZIP, json_text, "user://photos-missing"), "write temp zip")
	if fail != "":
		_cleanup_zip()
		return fail
	var packed := BackupZip.read_zip(TEMP_ZIP)
	fail = _expect(bool(packed.get("ok", false)), "zip ok true")
	if fail != "":
		_cleanup_zip()
		return fail
	var parsed := JSON.new()
	fail = _expect(parsed.parse(str(packed.get("json_text", ""))) == OK, "zip json parses")
	if fail != "":
		_cleanup_zip()
		return fail
	fail = _expect(typeof(parsed.data) == TYPE_DICTIONARY, "zip json is dictionary")
	if fail != "":
		_cleanup_zip()
		return fail
	var payload: Dictionary = parsed.data
	var vehicles: Array = payload.get("vehicles", [])
	fail = _expect(vehicles.size() == 1, "zip one vehicle")
	if fail != "":
		_cleanup_zip()
		return fail
	var history: Array = vehicles[0].get("history", [])
	fail = _expect(history.size() == 1, "zip one history row")
	if fail != "":
		_cleanup_zip()
		return fail
	fail = _expect(str(history[0].get("date", "")) == "2026-08-26", "zip date string unchanged")
	if fail != "":
		_cleanup_zip()
		return fail
	_cleanup_zip()
	return ""


func _has_unix_integer(csv: String) -> bool:
	for token in csv.split(",", false):
		var t := token.strip_edges().replace("\"", "")
		if t.is_valid_int() and t.length() >= 10:
			return true
	return false


func _cleanup_zip() -> void:
	if FileAccess.file_exists(TEMP_ZIP):
		DirAccess.remove_absolute(TEMP_ZIP)


func _expect(ok: bool, message: String) -> String:
	if ok:
		return ""
	return message
