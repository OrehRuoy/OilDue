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
	GarageStore.save()
	return fail


func _cases() -> String:
	var fail := _expect(Purchase.PRODUCT_ID == "unlock_oil_due", "product id unlock_oil_due")
	if fail != "":
		return fail

	GarageStore.data["unlocked"] = false
	Purchase.restore()
	fail = _expect(true, "restore in editor does not crash")
	if fail != "":
		return fail
	fail = _expect(not GarageStore.is_unlocked(), "editor restore does not unlock")
	if fail != "":
		return fail

	Purchase.buy()
	fail = _expect(GarageStore.is_unlocked(), "editor buy sets unlocked")
	if fail != "":
		return fail
	fail = _expect(Purchase.last_ok, "editor buy last_ok")
	if fail != "":
		return fail
	return ""


func _expect(ok: bool, message: String) -> String:
	if ok:
		return ""
	return message
