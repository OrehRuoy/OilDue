extends Control

const LOCALES := ["en", "de", "fr", "es_419", "pt_BR"]
const CsvImport = preload("res://scripts/csv_import.gd")
const CsvExport = preload("res://scripts/csv_export.gd")


func _ready() -> void:
	TranslationServer.set_locale("en")
	var fail := _run()
	if fail == "":
		%Result.text = "PASS"
	else:
		%Result.text = "FAIL: %s" % fail
	print(%Result.text)


func _run() -> String:
	var fail := _translations()
	if fail != "":
		return fail
	fail = _device_language()
	if fail != "":
		return fail
	fail = _units()
	if fail != "":
		return fail
	return _currency()


func _device_language() -> String:
	var imp := FileAccess.get_file_as_string("res://translations/oil_due.csv.import")
	if not imp.contains('importer="keep"'):
		return "oil_due.csv must stay importer keep so the device build contains the CSV"
	var header := FileAccess.get_file_as_string("res://translations/oil_due.csv").split("\n")[0]
	if header.split(",").has("ja"):
		return "do not add a Japanese column"
	var cases := {
		"fr_FR": "fr",
		"fr-FR": "fr",
		"fr": "fr",
		"de_DE": "de",
		"de-AT": "de",
		"es_MX": "es_419",
		"es-419": "es_419",
		"es_ES": "es_419",
		"pt_BR": "pt_BR",
		"pt-PT": "pt_BR",
		"pt": "pt_BR",
		"en_US": "en",
		"en_FR": "en",
		"en": "en",
		"ja_JP": "en",
		"ja": "en",
	}
	for raw in cases.keys():
		var got := GarageStore.locale_id_for(str(raw))
		if got != str(cases[raw]):
			return "%s mapped to %s, want %s" % [raw, got, cases[raw]]
	GarageStore._install_translations()
	var expect := {
		"fr": {"Settings": "Réglages", "Add service": "Ajouter un entretien", "Tire rotation": "Permutation", "Lead days": "Jours d'avance", "Kilometers": "Kilomètres", "Back": "Retour"},
		"de": {"Settings": "Einstellungen", "Add service": "Service hinzufügen", "Kilometers": "Kilometer", "Back": "Zurück"},
		"es_419": {"Settings": "Ajustes", "Add service": "Agregar servicio", "Kilometers": "Kilómetros", "Back": "Atrás"},
		"pt_BR": {"Settings": "Ajustes", "Add service": "Adicionar serviço", "Kilometers": "Quilômetros", "Back": "Voltar"},
	}
	for loc in expect.keys():
		TranslationServer.set_locale(str(loc))
		var rows: Dictionary = expect[loc]
		for key in rows.keys():
			var shown := str(TranslationServer.translate(str(key)))
			if shown != str(rows[key]):
				TranslationServer.set_locale("en")
				return "%s %s is \"%s\", want \"%s\"" % [loc, key, shown, rows[key]]
	TranslationServer.set_locale("ja")
	if str(TranslationServer.translate("Settings")) != "Settings":
		TranslationServer.set_locale("en")
		return "Japanese must fall back to English"
	TranslationServer.set_locale("en")
	if str(TranslationServer.translate("Settings")) != "Settings":
		return "English Settings changed"
	return ""


func _translations() -> String:
	var catalog := _catalog()
	if catalog.is_empty():
		return "translation csv missing"
	var keys := _tr_keys()
	if keys.is_empty():
		return "no tr() keys found"
	for key in keys:
		if not catalog.has(key):
			return "missing translation key: %s" % key
		var row: Dictionary = catalog[key]
		for loc in LOCALES:
			if str(row.get(loc, "")).strip_edges() == "":
				return "empty %s for: %s" % [loc, key]
	return ""


func _units() -> String:
	var snap: Dictionary = GarageStore.data.duplicate(true)
	var prev_vehicle := GarageStore.selected_vehicle_id
	var fail := _unit_cases()
	GarageStore.selected_vehicle_id = prev_vehicle
	GarageStore.data = snap
	GarageStore.save()
	return fail


func _unit_cases() -> String:
	var migrated: Dictionary = GarageStore._migrate({"schema": 1, "vehicles": [{"id": "keep"}]}, 1)
	var fail := _expect(str(migrated.get("distance_unit", "")) == "mi", "existing garage stays miles")
	if fail != "":
		return fail
	var kept: Array = migrated.get("vehicles", [])
	fail = _expect(kept.size() == 1 and str(kept[0].get("id", "")) == "keep", "migrate keeps the car")
	if fail != "":
		return fail
	var seeded: Dictionary = GarageStore._seed()
	fail = _expect(
		str(seeded.get("distance_unit", "")) == DueMath.unit_for_locale(OS.get_locale()),
		"new empty garage uses the region"
	)
	if fail != "":
		return fail
	fail = _expect((seeded.get("vehicles", []) as Array).is_empty(), "seed has no cars")
	if fail != "":
		return fail

	var next_date := "2027-04-15"
	GarageStore.data = {
		"schema": 1,
		"distance_unit": "mi",
		"vehicles": [{
			"id": "v_unit",
			"name": "Unit",
			"odometer": 1000,
			"archived": false,
			"services": [{
				"id": "s_oil",
				"type_id": "oil_change",
				"label": "Oil change",
				"notify": false,
				"next_date": next_date,
				"next_miles": 6000,
				"interval_miles": 5000,
				"interval_months": 6,
			}],
			"history": [],
		}],
	}
	GarageStore.selected_vehicle_id = "v_unit"
	GarageStore.data["distance_unit"] = "km"
	GarageStore.data["distance_unit"] = "mi"
	var vehicle: Dictionary = GarageStore.vehicle_by_id("v_unit")
	var service: Dictionary = vehicle.get("services", [])[0]
	fail = _expect(str(service.get("next_date", "")) == next_date, "unit switch keeps the due date")
	if fail != "":
		return fail
	fail = _expect(int(vehicle.get("odometer", 0)) == 1000, "unit switch keeps stored miles")
	if fail != "":
		return fail
	fail = _expect(int(service.get("next_miles", 0)) == 6000, "unit switch keeps stored next miles")
	if fail != "":
		return fail

	GarageStore.data["distance_unit"] = "km"
	var stored := DueMath.display_to_miles(8000)
	GarageStore.set_odometer(stored)
	vehicle = GarageStore.vehicle_by_id("v_unit")
	service = vehicle.get("services", [])[0]
	fail = _expect(DueMath.miles_to_display(int(vehicle.get("odometer", 0))) == 8000, "8000 km redisplays as 8000 km")
	if fail != "":
		return fail
	fail = _expect(int(vehicle.get("odometer", 0)) != 8000, "8000 km is stored as miles")
	if fail != "":
		return fail
	fail = _expect(str(service.get("next_date", "")) == next_date, "saving kilometers keeps the due date")
	return fail


func _catalog() -> Dictionary:
	var text := FileAccess.get_file_as_string("res://translations/oil_due.csv")
	var lines := text.split("\n")
	if lines.size() < 2:
		return {}
	var header := _csv_fields(str(lines[0]))
	var books := {}
	for line_i in range(1, lines.size()):
		var line := str(lines[line_i])
		if line.strip_edges() == "":
			continue
		var cols := _csv_fields(line)
		if cols.is_empty():
			continue
		var key := str(cols[0])
		var row := {}
		for i in range(1, header.size()):
			var loc := str(header[i]).strip_edges()
			row[loc] = str(cols[i]) if i < cols.size() else ""
		books[key] = row
	return books


func _tr_keys() -> PackedStringArray:
	var found := {}
	for path in ["res://scripts", "res://tests"]:
		_scan_dir(path, found)
	var keys: PackedStringArray = PackedStringArray()
	for key in found.keys():
		keys.append(str(key))
	return keys


func _scan_dir(path: String, found: Dictionary) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name != "." and name != "..":
			var full := "%s/%s" % [path, name]
			if dir.current_is_dir():
				_scan_dir(full, found)
			elif name.ends_with(".gd"):
				_scan_file(full, found)
		name = dir.get_next()
	dir.list_dir_end()


func _scan_file(path: String, found: Dictionary) -> void:
	var text := FileAccess.get_file_as_string(path)
	_collect(text, "tr(\"", found)
	_collect(text, "TranslationServer.translate(\"", found)


func _collect(text: String, needle: String, found: Dictionary) -> void:
	var from := 0
	while true:
		var at := text.find(needle, from)
		if at < 0:
			return
		var start := at + needle.length()
		var end := start
		while end < text.length():
			if text[end] == "\\" and end + 1 < text.length():
				end += 2
				continue
			if text[end] == "\"":
				break
			end += 1
		if end >= text.length():
			return
		var key := text.substr(start, end - start).replace("\\\"", "\"")
		if key != "":
			found[key] = true
		from = end + 1


func _csv_fields(line: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var cur := ""
	var quoted := false
	var i := 0
	var raw := line.replace("\r", "")
	while i < raw.length():
		var c := raw[i]
		if quoted:
			if c == "\"":
				if i + 1 < raw.length() and raw[i + 1] == "\"":
					cur += "\""
					i += 1
				else:
					quoted = false
			else:
				cur += c
		elif c == "\"":
			quoted = true
		elif c == ",":
			out.append(cur)
			cur = ""
		else:
			cur += c
		i += 1
	out.append(cur)
	return out


func _currency() -> String:
	var snap: Dictionary = GarageStore.data.duplicate(true)
	var prev_vehicle := GarageStore.selected_vehicle_id
	var fail := _currency_cases()
	GarageStore.selected_vehicle_id = prev_vehicle
	GarageStore.data = snap
	GarageStore.save()
	return fail


func _currency_cases() -> String:
	var fail := _expect(DueMath.currency_for_locale("de_DE") == "EUR", "de_DE is EUR")
	if fail != "":
		return fail
	fail = _expect(DueMath.currency_for_locale("fr_CA") == "CAD", "fr_CA is CAD")
	if fail != "":
		return fail
	fail = _expect(DueMath.currency_for_locale("es_MX") == "MXN", "es_MX is MXN")
	if fail != "":
		return fail
	fail = _expect(DueMath.currency_for_locale("pt_BR") == "BRL", "pt_BR is BRL")
	if fail != "":
		return fail
	fail = _expect(DueMath.currency_for_locale("en_GB") == "GBP", "en_GB is GBP")
	if fail != "":
		return fail
	fail = _expect(DueMath.currency_for_locale("en_AU") == "AUD", "en_AU is AUD")
	if fail != "":
		return fail
	fail = _expect(DueMath.currency_for_locale("en_IN") == "INR", "en_IN is INR")
	if fail != "":
		return fail
	fail = _expect(DueMath.currency_for_locale("ja_JP") == "JPY", "ja_JP is JPY")
	if fail != "":
		return fail
	fail = _expect(DueMath.currency_for_locale("en_ZZ") == "USD", "unknown region is USD")
	if fail != "":
		return fail
	fail = _expect(DueMath.format_cents(4550, "EUR") == "45,50 €", "de_DE formats 45.5")
	if fail != "":
		return fail
	fail = _expect(DueMath.format_cents(4550, "BRL") == "R$ 45,50", "pt_BR formats 45.5")
	if fail != "":
		return fail
	fail = _expect(DueMath.format_cents(4550, "USD") == "$45.50", "en_US formats 45.5")
	if fail != "":
		return fail
	var yen := DueMath.format_cents(4550, "JPY")
	fail = _expect(yen == "¥46" or yen == "¥45", "ja_JP has no decimals, got %s" % yen)
	if fail != "":
		return fail
	fail = _expect(DueMath.format_cents(450000, "JPY") == "¥4,500", "yen groups thousands")
	if fail != "":
		return fail
	var parsed: Dictionary = DueMath.parse_cents("45,50")
	fail = _expect(
		bool(parsed.get("ok", false)) and is_equal_approx(float(parsed.get("cents", 0)) / 100.0, 45.5),
		"45,50 parses to 45.5"
	)
	if fail != "":
		return fail
	fail = _expect(int(DueMath.parse_cents("45.50").get("cents", 0)) == 4550, "45.50 parses to 45.5")
	if fail != "":
		return fail

	var migrated: Dictionary = GarageStore._migrate({"schema": 1, "vehicles": []}, 1)
	fail = _expect(str(migrated.get("currency", "")) == "USD", "existing garage stays USD")
	if fail != "":
		return fail
	var kept: Dictionary = GarageStore._migrate({"schema": 1, "currency": "EUR", "vehicles": []}, 1)
	fail = _expect(str(kept.get("currency", "")) == "EUR", "stored currency is kept")
	if fail != "":
		return fail
	var seeded: Dictionary = GarageStore._seed()
	fail = _expect(
		str(seeded.get("currency", "")) == DueMath.currency_for_locale(OS.get_locale()),
		"new empty garage uses the detected currency"
	)
	if fail != "":
		return fail

	GarageStore.data = {
		"schema": 1,
		"currency": "USD",
		"distance_unit": "mi",
		"vehicles": [{
			"id": "v_cur",
			"name": "Cur",
			"archived": false,
			"odometer": 1000,
			"services": [{
				"id": "s_oil",
				"type_id": "oil_change",
				"label": "Oil change",
			}],
			"history": [{
				"id": "h1",
				"service_id": "s_oil",
				"date": "2026-01-01",
				"miles": 1000,
				"cost_cents": 4550,
				"notes": "",
			}],
		}],
	}
	GarageStore.selected_vehicle_id = "v_cur"
	GarageStore.data["currency"] = "GBP"
	GarageStore.save()
	var vehicle: Dictionary = GarageStore.vehicle_by_id("v_cur")
	var history: Array = vehicle.get("history", [])
	fail = _expect(history.size() == 1 and int(history[0].get("cost_cents", 0)) == 4550, "switching currency keeps the amount")
	if fail != "":
		return fail
	fail = _expect(DueMath.format_cents(4550) == "£45.50", "display follows the chosen currency")
	if fail != "":
		return fail

	var plain: Dictionary = CsvImport.parse_text(
		"vehicle_name,service,date,miles,cost,notes\nCur,Oil change,2026-02-01,1100,45.50,\n"
	)
	fail = _expect(str(plain.get("currency", "missing")) == "", "file without a currency keeps no code")
	if fail != "":
		return fail
	fail = _expect(GarageStore.import_merge(plain), "import without currency")
	if fail != "":
		return fail
	fail = _expect(str(GarageStore.data.get("currency", "")) == "GBP", "import without currency keeps GBP")
	if fail != "":
		return fail
	fail = _expect(_history_cents("h1") == 4550, "import leaves the stored amount")
	if fail != "":
		return fail

	var euro: Dictionary = CsvImport.parse_text(
		"vehicle_name,service,date,miles,cost (EUR),notes\nCur,Oil change,2026-03-01,1200,\"45,50\",\n"
	)
	fail = _expect(str(euro.get("currency", "")) == "EUR", "cost header carries EUR")
	if fail != "":
		return fail
	var euro_jobs: Array = euro.get("jobs", [])
	fail = _expect(
		euro_jobs.size() == 1 and int(euro_jobs[0].get("cost_cents", 0)) == 4550,
		"imported 45,50 is 45.5"
	)
	if fail != "":
		return fail
	fail = _expect(GarageStore.import_merge(euro), "import with currency")
	if fail != "":
		return fail
	fail = _expect(str(GarageStore.data.get("currency", "")) == "EUR", "import applies the file currency")
	if fail != "":
		return fail
	fail = _expect(_history_cents("h1") == 4550, "applying currency does not convert amounts")
	if fail != "":
		return fail
	var exported := CsvExport.jobs_csv(GarageStore.data)
	fail = _expect(exported.contains("cost (EUR)"), "export header names the currency")
	if fail != "":
		return fail
	fail = _expect(exported.contains("45,50 €"), "export formats the amount")
	if fail != "":
		return fail
	return ""


func _history_cents(job_id: String) -> int:
	var vehicle: Dictionary = GarageStore.vehicle_by_id("v_cur")
	for item in vehicle.get("history", []):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		if str(item.get("id", "")) == job_id:
			return int(item.get("cost_cents", 0))
	return -1


func _expect(ok: bool, message: String) -> String:
	if ok:
		return ""
	return message
