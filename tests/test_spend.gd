extends Control

const SpendRollup = preload("res://scripts/spend_rollup.gd")


func _ready() -> void:
	var fail := _run()
	if fail == "":
		%Result.text = "PASS"
	else:
		%Result.text = "FAIL: %s" % fail
	print(%Result.text)


func _run() -> String:
	var empty := SpendRollup.rollup({"history": [], "services": []})
	var fail := _expect(int(empty.get("total_cents", -1)) == 0, "empty total")
	if fail != "":
		return fail
	var empty_rows: Array = empty.get("rows", [])
	fail = _expect(empty_rows.is_empty(), "empty rows")
	if fail != "":
		return fail

	var vehicle := {
		"services": [
			{"id": "s_oil", "label": "Oil change"},
			{"id": "s_tire", "label": "Tires"},
		],
		"history": [
			{"service_id": "s_oil", "cost_cents": 1000},
			{"service_id": "s_oil", "cost_cents": 2500},
			{"service_id": "s_tire", "cost_cents": 0},
			{"service_id": "s_tire"},
			{"service_id": "missing", "cost_cents": 500},
		],
	}
	var roll := SpendRollup.rollup(vehicle)
	fail = _expect(int(roll.get("total_cents", 0)) == 4000, "total ignores missing costs")
	if fail != "":
		return fail
	var rows: Array = roll.get("rows", [])
	fail = _expect(rows.size() == 2, "two labels")
	if fail != "":
		return fail
	var first: Dictionary = rows[0]
	var second: Dictionary = rows[1]
	fail = _expect(str(first.get("label", "")) == "Oil change", "highest label first")
	if fail != "":
		return fail
	fail = _expect(int(first.get("cents", 0)) == 3500, "oil cents")
	if fail != "":
		return fail
	fail = _expect(str(second.get("label", "")) == "Other", "missing service is Other")
	if fail != "":
		return fail
	fail = _expect(int(second.get("cents", 0)) == 500, "other cents")
	if fail != "":
		return fail
	return ""


func _expect(ok: bool, message: String) -> String:
	if ok:
		return ""
	return message
