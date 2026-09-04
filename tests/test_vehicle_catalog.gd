extends Control

const VehicleCatalog = preload("res://scripts/vehicle_catalog.gd")


func _ready() -> void:
	var fail := _run()
	if fail == "":
		%Result.text = "PASS"
	else:
		%Result.text = "FAIL: %s" % fail
	print(%Result.text)


func _run() -> String:
	var makes := VehicleCatalog.makes()
	var fail := _expect(makes.size() >= 30, "enough makes")
	if fail != "":
		return fail
	fail = _expect(_has(makes, "Honda"), "Honda in makes")
	if fail != "":
		return fail
	fail = _expect(_has(makes, "Toyota"), "Toyota in makes")
	if fail != "":
		return fail
	var honda := VehicleCatalog.models("Honda")
	fail = _expect(_has(honda, "Civic"), "Civic in Honda")
	if fail != "":
		return fail
	fail = _expect(VehicleCatalog.models("").is_empty(), "empty make has no models")
	if fail != "":
		return fail
	fail = _expect(VehicleCatalog.models("NoSuchMake").is_empty(), "unknown make has no models")
	if fail != "":
		return fail
	fail = _expect(VehicleCatalog.has_model("Honda", "civic"), "has_model case-insensitive")
	if fail != "":
		return fail
	fail = _expect(not VehicleCatalog.has_model("Toyota", "Civic"), "Civic not a Toyota")
	if fail != "":
		return fail
	fail = _expect(VehicleCatalog.canonical_make("honda") == "Honda", "canonical Honda")
	if fail != "":
		return fail
	fail = _expect(VehicleCatalog.canonical_make("Koenigsegg") == "Koenigsegg", "custom make kept")
	if fail != "":
		return fail
	var hon := VehicleCatalog.filter(makes, "hon")
	fail = _expect(_has(hon, "Honda") and hon.size() < makes.size(), "filter hon")
	if fail != "":
		return fail
	return ""


func _has(items: PackedStringArray, want: String) -> bool:
	for item in items:
		if str(item) == want:
			return true
	return false


func _expect(ok: bool, label: String) -> String:
	if ok:
		return ""
	return label
