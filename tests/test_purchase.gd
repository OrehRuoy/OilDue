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
	var back := GarageStore.unlock_back_scene
	var cont := GarageStore.unlock_continue_scene
	var fail := _cases()
	GarageStore.data = snap
	GarageStore.unlock_back_scene = back
	GarageStore.unlock_continue_scene = cont
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
	fail = _expect(Purchase.localized_price() == "$2.99", "editor localized_price is $2.99")
	if fail != "":
		return fail

	GarageStore.set_unlock_return("res://scenes/garage.tscn", "res://scenes/vehicle_add.tscn")
	fail = _expect(
		GarageStore.consume_unlock_destination(true) == "res://scenes/vehicle_add.tscn",
		"unlock after add-car continues to vehicle_add"
	)
	if fail != "":
		return fail
	fail = _expect(GarageStore.unlock_continue_scene == "", "continue scene clears after consume")
	if fail != "":
		return fail

	GarageStore.set_unlock_return("res://scenes/garage.tscn", "res://scenes/vehicle_add.tscn")
	fail = _expect(
		GarageStore.consume_unlock_destination(false) == "res://scenes/garage.tscn",
		"back without unlock returns to garage"
	)
	if fail != "":
		return fail
	fail = _expect(GarageStore.unlock_continue_scene == "", "continue scene clears on back")
	if fail != "":
		return fail

	GarageStore.set_unlock_return("res://scenes/settings.tscn")
	fail = _expect(
		GarageStore.consume_unlock_destination(true) == "res://scenes/settings.tscn",
		"unlock from settings returns to settings"
	)
	if fail != "":
		return fail
	return ""


func _expect(ok: bool, message: String) -> String:
	if ok:
		return ""
	return message
