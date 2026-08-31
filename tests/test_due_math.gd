extends Control

const DueMath = preload("res://scripts/due_math.gd")

@onready var _label: Label = %Result


func _ready() -> void:
	var fail := _run()
	if fail == "":
		_label.text = "PASS"
	else:
		_label.text = "FAIL: %s" % fail
	print(_label.text)


func _run() -> String:
	var fail := _expect(
		DueMath.add_months_ymd("2024-01-31", 1) == "2024-02-29",
		"2024-01-31 + 1 month = 2024-02-29"
	)
	if fail != "":
		return fail
	fail = _expect(
		DueMath.add_months_ymd("2025-01-31", 1) == "2025-02-28",
		"2025-01-31 + 1 month = 2025-02-28"
	)
	if fail != "":
		return fail
	fail = _expect(
		DueMath.add_months_ymd("2024-02-29", 12) == "2025-02-28",
		"2024-02-29 + 12 months = 2025-02-28"
	)
	if fail != "":
		return fail
	fail = _expect(
		DueMath.add_months_ymd("2026-08-31", 6) == "2027-02-28",
		"2026-08-31 + 6 months = 2027-02-28"
	)
	if fail != "":
		return fail
	fail = _expect(
		DueMath.add_months_ymd("2026-03-01", 6) == "2026-09-01",
		"2026-03-01 + 6 months = 2026-09-01"
	)
	if fail != "":
		return fail

	var oil_next_date := DueMath.compute_next_date("2026-03-01", 6)
	fail = _expect(oil_next_date == "2026-09-01", "oil next_date 2026-09-01")
	if fail != "":
		return fail
	var oil_next_miles := DueMath.compute_next_miles(82400, 5000)
	fail = _expect(oil_next_miles == 87400, "oil next_miles 87400")
	if fail != "":
		return fail
	fail = _expect(
		DueMath.status("2026-08-27", 87420, oil_next_date, oil_next_miles, 7, 5000, 6) == "overdue",
		"oil overdue by miles"
	)
	if fail != "":
		return fail

	var logged_date := DueMath.compute_next_date("2026-08-27", 6)
	fail = _expect(logged_date == "2027-02-27", "after log next_date 2027-02-27")
	if fail != "":
		return fail
	var logged_miles := DueMath.compute_next_miles(88000, 5000)
	fail = _expect(logged_miles == 93000, "after log next_miles 93000")
	if fail != "":
		return fail
	fail = _expect(
		DueMath.status("2026-08-27", 88000, logged_date, logged_miles, 7, 5000, 6) == "ok",
		"after log status ok"
	)
	if fail != "":
		return fail

	fail = _expect(
		DueMath.status("2026-08-27", 999999, "2027-08-27", 1000, 7, 0, 12) == "ok",
		"date-only ignores miles"
	)
	if fail != "":
		return fail
	fail = _expect(
		DueMath.status("2028-01-01", 1000, "2020-01-01", 50000, 7, 5000, 0) == "ok",
		"miles-only ignores date"
	)
	if fail != "":
		return fail
	fail = _expect(
		DueMath.status("2026-08-27", 1000, "2026-08-27", 50000, 7, 5000, 6) == "overdue",
		"today == next_date is overdue"
	)
	if fail != "":
		return fail
	fail = _expect(
		DueMath.format_display_date("2026-08-30") == "Aug 30, 2026",
		"display date Aug 30, 2026"
	)
	if fail != "":
		return fail
	fail = _expect(
		DueMath.format_display_date("bad") == "",
		"invalid date displays empty"
	)
	if fail != "":
		return fail
	return ""


func _expect(ok: bool, message: String) -> String:
	if ok:
		return ""
	return message
