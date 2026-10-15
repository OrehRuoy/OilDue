extends Control


func _ready() -> void:
	TranslationServer.set_locale("en")
	var fail := _run()
	if fail == "":
		%Result.text = "PASS"
	else:
		%Result.text = "FAIL: %s" % fail
	print(%Result.text)


class FakeSched:
	extends RefCounted
	var scheduled: Array = []
	var cancelled: Array = []

	func schedule(data: NotificationData) -> void:
		scheduled.append(data)

	func cancel(nid: int) -> void:
		cancelled.append(int(nid))


func _run() -> String:
	var snap: Dictionary = GarageStore.data.duplicate(true)
	var prev_sched: Object = NotifyService.scheduler_override
	var fail := _cases()
	NotifyService.scheduler_override = prev_sched
	NotifyService.last_plan = []
	GarageStore.data = snap
	GarageStore.save()
	return fail


func _cases() -> String:
	var today := GarageStore.today_ymd()
	var tomorrow := GarageStore.add_days_ymd(today, 1)
	var yesterday := GarageStore.add_days_ymd(today, -1)

	GarageStore.data = _fixture(false, true, tomorrow)
	NotifyService.reschedule()
	var fail := _expect(NotifyService.last_plan.size() == 1, "free oil reminder schedules one")
	if fail != "":
		return fail

	GarageStore.data = _fixture(true, true, tomorrow)
	NotifyService.reschedule()
	fail = _expect(NotifyService.last_plan.size() == 2, "unlocked notify tomorrow schedules every service")
	if fail != "":
		return fail
	var row: Dictionary = NotifyService.last_plan[0]
	fail = _expect(str(row.get("fire_ymd", "")) == tomorrow, "fire_ymd is tomorrow")
	if fail != "":
		return fail

	GarageStore.data = _fixture(true, false, tomorrow)
	NotifyService.reschedule()
	fail = _expect(NotifyService.last_plan.size() == 1, "oil notify false leaves the tire reminder")
	if fail != "":
		return fail

	GarageStore.data = _fixture(true, true, yesterday)
	NotifyService.reschedule()
	fail = _expect(NotifyService.last_plan.size() == 0, "past next_date schedules none")
	if fail != "":
		return fail

	var fake := FakeSched.new()
	NotifyService.scheduler_override = fake
	GarageStore.data = _fixture(true, true, tomorrow)
	var archived_id := NotifyService._stable_id("v_old", "s_old")
	NotifyService.reschedule()
	fail = _expect(fake.scheduled.size() == 2, "fake scheduler got both notifications")
	if fail != "":
		return fail
	fail = _expect(fake.cancelled.has(archived_id), "archived service id is cancelled")
	if fail != "":
		return fail
	var expected := NotifyService.local_nine_unix(tomorrow)
	var ids: Array = []
	for item in fake.scheduled:
		var note: NotificationData = item
		var fired: int = int(Time.get_unix_time_from_system()) + int(note.get_delay())
		fail = _expect(absi(fired - expected) <= 2, "schedule lands at 09:00 local")
		if fail != "":
			return fail
		ids.append(note.get_id())
	GarageStore.data["vehicles"][0]["services"][0]["notify"] = false
	GarageStore.data["vehicles"][0]["services"][1]["notify"] = false
	fake.scheduled.clear()
	var cancel_before := fake.cancelled.size()
	NotifyService.reschedule()
	fail = _expect(fake.scheduled.is_empty(), "notify off does not schedule")
	if fail != "":
		return fail
	var cancelled_after: Array = fake.cancelled.slice(cancel_before)
	for nid in ids:
		fail = _expect(cancelled_after.has(nid), "notify off cancels the id")
		if fail != "":
			return fail
	if fail != "":
		return fail
	NotifyService.scheduler_override = null
	return ""


func _fixture(unlocked: bool, notify_on: bool, next_date: String) -> Dictionary:
	return {
		"unlocked": unlocked,
		"scheduled_ids": [],
		"vehicles": [
			{
				"id": "v_test",
				"name": "Daily",
				"archived": false,
				"services": [
					{
						"id": "s_oil",
						"type_id": "oil_change",
						"label": "Oil change",
						"notify": notify_on,
						"next_date": next_date,
					},
					{
						"id": "s_tire",
						"type_id": "tire_replace",
						"label": "Tires",
						"notify": true,
						"next_date": next_date,
					},
				],
			},
			{
				"id": "v_old",
				"name": "Sold",
				"archived": true,
				"services": [{
					"id": "s_old",
					"label": "Oil change",
					"notify": true,
					"next_date": next_date,
				}],
			},
		],
	}


func _expect(ok: bool, message: String) -> String:
	if ok:
		return ""
	return message
