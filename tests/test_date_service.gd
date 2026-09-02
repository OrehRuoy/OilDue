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
	var today := GarageStore.today_ymd()
	var fail := _expect(not DueMath.parse_ymd(today).is_empty(), "today_ymd parses as YYYY-MM-DD")
	if fail != "":
		return fail

	fail = _expect(DateService.apply_ymd("2026-03-15"), "apply_ymd 2026-03-15")
	if fail != "":
		return fail
	fail = _expect(DateService.last_ymd == "2026-03-15", "stores civil string")
	if fail != "":
		return fail
	fail = _expect(DueMath.format_display_date(DateService.last_ymd) == "Mar 15, 2026", "display Mar 15, 2026")
	if fail != "":
		return fail

	DateService.begin_pick("2026-01-02")
	fail = _expect(DateService.last_ymd == "2026-01-02", "begin_pick snapshots")
	if fail != "":
		return fail
	fail = _expect(DateService.apply_ymd("2026-03-15"), "apply after snapshot")
	if fail != "":
		return fail
	DateService.cancel_pick()
	fail = _expect(DateService.last_ymd == "2026-01-02", "cancel_pick restores previous")
	if fail != "":
		return fail

	fail = _expect(not DateService._ios_datepicker(), "ios datepicker false on Windows")
	if fail != "":
		return fail
	return ""


func _expect(ok: bool, message: String) -> String:
	if ok:
		return ""
	return message
