extends Control

const DueMath = preload("res://scripts/due_math.gd")


func _ready() -> void:
	var fail := _run()
	if fail == "":
		%Result.text = "PASS"
	else:
		%Result.text = "FAIL: %s" % fail
	print(%Result.text)


func _run() -> String:
	var snap: Dictionary = GarageStore.data.duplicate(true)
	var snap_vid := GarageStore.selected_vehicle_id
	var snap_sid := GarageStore.selected_service_id
	var snap_hid := GarageStore.selected_history_id
	var fail := _cases()
	GarageStore.data = snap
	GarageStore.selected_vehicle_id = snap_vid
	GarageStore.selected_service_id = snap_sid
	GarageStore.selected_history_id = snap_hid
	GarageStore.save()
	return fail


func _cases() -> String:
	GarageStore.data = {
		"schema": 1,
		"unlocked": true,
		"vehicles": [{
			"id": "v_test",
			"name": "Test",
			"archived": false,
			"odometer": 80000,
			"odometer_date": "2026-01-01",
			"services": [{
				"id": "s_oil",
				"type_id": "oil_change",
				"label": "Oil Change",
				"interval_miles": 5000,
				"interval_months": 6,
				"last_date": "",
				"last_miles": 0,
				"next_date": "",
				"next_miles": 0,
				"notify": false,
			}],
			"history": [],
		}],
	}
	GarageStore.selected_vehicle_id = "v_test"
	GarageStore.selected_service_id = "s_oil"
	GarageStore.selected_history_id = ""

	var fail := _expect(GarageStore.log_service("2026-01-15", 80000, 5000, "first"), "log older job")
	if fail != "":
		return fail
	fail = _expect(GarageStore.log_service("2026-03-15", 85000, 8000, "second"), "log newer job")
	if fail != "":
		return fail

	var vehicle := GarageStore.vehicle_by_id("v_test")
	var service := GarageStore.service_by_id(vehicle, "s_oil")
	fail = _expect(str(service.get("last_date", "")) == "2026-03-15", "after logs last_date newest")
	if fail != "":
		return fail
	fail = _expect(int(service.get("last_miles", 0)) == 85000, "after logs last_miles newest")
	if fail != "":
		return fail
	fail = _expect(str(service.get("next_date", "")) == "2026-09-15", "after logs next_date")
	if fail != "":
		return fail
	fail = _expect(int(service.get("next_miles", 0)) == 90000, "after logs next_miles")
	if fail != "":
		return fail
	fail = _expect(int(vehicle.get("odometer", 0)) == 85000, "odometer raised by newer log")
	if fail != "":
		return fail

	var jobs: Array = GarageStore.history_for_selected()
	fail = _expect(jobs.size() == 2, "two jobs logged")
	if fail != "":
		return fail
	var newer_id := str(jobs[0].get("id", ""))
	var older_id := str(jobs[1].get("id", ""))
	fail = _expect(str(jobs[0].get("date", "")) == "2026-03-15", "sorted newer first")
	if fail != "":
		return fail

	fail = _expect(
		GarageStore.update_history(older_id, "2026-01-20", 70000, 4500, "first edited"),
		"edit older date/cost/miles down"
	)
	if fail != "":
		return fail
	vehicle = GarageStore.vehicle_by_id("v_test")
	service = GarageStore.service_by_id(vehicle, "s_oil")
	fail = _expect(str(service.get("last_date", "")) == "2026-03-15", "edit older keeps newest last_date")
	if fail != "":
		return fail
	fail = _expect(int(service.get("last_miles", 0)) == 85000, "edit older keeps newest last_miles")
	if fail != "":
		return fail
	fail = _expect(str(service.get("next_date", "")) == "2026-09-15", "edit older keeps newest next_date")
	if fail != "":
		return fail
	fail = _expect(int(service.get("next_miles", 0)) == 90000, "edit older keeps newest next_miles")
	if fail != "":
		return fail
	fail = _expect(int(vehicle.get("odometer", 0)) == 85000, "odometer not lowered")
	if fail != "":
		return fail
	var older := GarageStore.history_job(older_id)
	fail = _expect(str(older.get("date", "")) == "2026-01-20", "older date updated")
	if fail != "":
		return fail
	fail = _expect(int(older.get("cost_cents", 0)) == 4500, "older cost updated")
	if fail != "":
		return fail

	fail = _expect(GarageStore.delete_history(newer_id), "delete newer job")
	if fail != "":
		return fail
	jobs = GarageStore.history_for_selected()
	fail = _expect(jobs.size() == 1, "one job remains")
	if fail != "":
		return fail
	vehicle = GarageStore.vehicle_by_id("v_test")
	service = GarageStore.service_by_id(vehicle, "s_oil")
	fail = _expect(str(service.get("last_date", "")) == "2026-01-20", "after delete last_date remaining")
	if fail != "":
		return fail
	fail = _expect(int(service.get("last_miles", 0)) == 70000, "after delete last_miles remaining")
	if fail != "":
		return fail
	fail = _expect(str(service.get("next_date", "")) == "2026-07-20", "after delete next_date")
	if fail != "":
		return fail
	fail = _expect(int(service.get("next_miles", 0)) == 75000, "after delete next_miles")
	if fail != "":
		return fail
	fail = _expect(int(vehicle.get("odometer", 0)) == 85000, "odometer still not lowered")
	if fail != "":
		return fail

	fail = _expect(GarageStore.log_service("2026-04-01", 86000, 0, ""), "new log appends")
	if fail != "":
		return fail
	jobs = GarageStore.history_for_selected()
	fail = _expect(jobs.size() == 2, "log appends not overwrite")
	if fail != "":
		return fail
	fail = _expect(GarageStore.history_job(older_id).is_empty() == false, "older job still there")
	if fail != "":
		return fail
	return ""


func _expect(ok: bool, message: String) -> String:
	if ok:
		return ""
	return message
