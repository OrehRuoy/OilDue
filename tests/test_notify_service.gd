extends Control


func _ready() -> void:
	var fail := _run()
	if fail == "":
		%Result.text = "PASS"
	else:
		%Result.text = "FAIL: %s" % fail
	print(%Result.text)


func _run() -> String:
	var snap: Dictionary = GarageStore.data.duplicate(true)
	var fail := _cases()
	GarageStore.data = snap
	NotifyService.last_plan = []
	return fail


func _cases() -> String:
	var today := GarageStore.today_ymd()
	var tomorrow := GarageStore.add_days_ymd(today, 1)
	var yesterday := GarageStore.add_days_ymd(today, -1)

	GarageStore.data = _fixture(false, true, tomorrow)
	NotifyService.reschedule()
	var fail := _expect(NotifyService.last_plan.size() == 0, "locked schedules nothing")
	if fail != "":
		return fail

	GarageStore.data = _fixture(true, true, tomorrow)
	NotifyService.reschedule()
	fail = _expect(NotifyService.last_plan.size() == 1, "unlocked notify tomorrow schedules one")
	if fail != "":
		return fail
	var row: Dictionary = NotifyService.last_plan[0]
	fail = _expect(str(row.get("fire_ymd", "")) == tomorrow, "fire_ymd is tomorrow")
	if fail != "":
		return fail

	GarageStore.data = _fixture(true, false, tomorrow)
	NotifyService.reschedule()
	fail = _expect(NotifyService.last_plan.size() == 0, "notify false schedules none")
	if fail != "":
		return fail

	GarageStore.data = _fixture(true, true, yesterday)
	NotifyService.reschedule()
	fail = _expect(NotifyService.last_plan.size() == 0, "past next_date schedules none")
	if fail != "":
		return fail
	return ""


func _fixture(unlocked: bool, notify_on: bool, next_date: String) -> Dictionary:
	return {
		"unlocked": unlocked,
		"vehicles": [{
			"id": "v_test",
			"name": "Daily",
			"archived": false,
			"services": [{
				"id": "s_oil",
				"label": "Oil change",
				"notify": notify_on,
				"next_date": next_date,
			}],
		}],
	}


func _expect(ok: bool, message: String) -> String:
	if ok:
		return ""
	return message
