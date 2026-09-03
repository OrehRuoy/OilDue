extends Node

const DueMath = preload("res://scripts/due_math.gd")
const CsvExport = preload("res://scripts/csv_export.gd")
const BackupZip = preload("res://scripts/backup_zip.gd")
const SCHEMA := 1
const PATH := "user://garage.json"
const TMP_PATH := "user://garage.json.tmp"
const BACKUP_DIR := "user://backups"
const BACKUP_KEEP := 10
const PHOTOS_DIR := "user://photos"
const MONTH_DAYS := [0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

var data: Dictionary = {}
var selected_vehicle_id: String = ""
var selected_service_id: String = ""
var selected_history_id: String = ""
var pending_import: Dictionary = {}
var last_backup_error: String = ""
var pending_restore_path: String = ""
var pending_receipt_src: String = ""
var unlock_back_scene: String = "res://scenes/garage.tscn"


func _ready() -> void:
	load_from_disk()


func load_from_disk() -> void:
	var parsed := _try_parse(PATH)
	if parsed.is_empty():
		parsed = _try_newest_backup()
		if not parsed.is_empty():
			data = _migrate(parsed, int(parsed.get("schema", 0)))
			_coerce_ints(data)
			save()
			return
		data = _seed()
		save()
		return
	data = _migrate(parsed, int(parsed.get("schema", 0)))
	_coerce_ints(data)


func save() -> void:
	_atomic_write(JSON.stringify(data, "\t"))
	_write_backup()
	_prune_backups()


func primary_vehicle() -> Dictionary:
	var vehicles: Array = data.get("vehicles", [])
	for item in vehicles:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var vehicle: Dictionary = item
		if not bool(vehicle.get("archived", false)):
			return vehicle
	if vehicles.size() >= 1 and typeof(vehicles[0]) == TYPE_DICTIONARY:
		return vehicles[0]
	return {}


func set_odometer(miles: int) -> void:
	var vehicle := _current_vehicle()
	if vehicle.is_empty():
		return
	vehicle["odometer"] = miles
	vehicle["odometer_date"] = today_ymd()
	save()
	NotifyService.reschedule()


func _current_vehicle() -> Dictionary:
	var vehicle := vehicle_by_id(selected_vehicle_id)
	if vehicle.is_empty():
		vehicle = primary_vehicle()
	return vehicle


func is_unlocked() -> bool:
	return bool(data.get("unlocked", false))


func set_unlocked(v: bool) -> void:
	data["unlocked"] = v
	save()
	NotifyService.reschedule()


func archived_list() -> Array:
	var out: Array = []
	for item in data.get("vehicles", []):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var vehicle: Dictionary = item
		if bool(vehicle.get("archived", false)):
			out.append(vehicle)
	return out


func set_archived(vehicle_id: String, archived: bool) -> void:
	var vehicle := vehicle_by_id(vehicle_id)
	if vehicle.is_empty():
		return
	vehicle["archived"] = archived
	if archived and selected_vehicle_id == vehicle_id:
		var live := vehicles_list()
		if live.size() >= 1:
			selected_vehicle_id = str(live[0].get("id", ""))
		else:
			selected_vehicle_id = ""
	save()
	NotifyService.reschedule()


func set_service_notify(on: bool) -> void:
	var vehicle := vehicle_by_id(selected_vehicle_id)
	var service := service_by_id(vehicle, selected_service_id)
	if service.is_empty():
		return
	service["notify"] = on
	save()
	NotifyService.reschedule()


func vehicles_list() -> Array:
	var out: Array = []
	for item in data.get("vehicles", []):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var vehicle: Dictionary = item
		if bool(vehicle.get("archived", false)):
			continue
		out.append(vehicle)
	return out


func add_vehicle(year: int, make: String, model: String, name: String, odometer: int) -> bool:
	if vehicles_list().size() >= 1 and not is_unlocked():
		return false
	var miles := int(odometer)
	if miles < 0:
		miles = 0
	var make_s := make.strip_edges()
	var model_s := model.strip_edges()
	var name_s := name.strip_edges()
	if name_s == "":
		name_s = ("%s %s %s" % [int(year), make_s, model_s]).strip_edges()
	if not data.has("vehicles") or typeof(data["vehicles"]) != TYPE_ARRAY:
		data["vehicles"] = []
	var vehicles: Array = data["vehicles"]
	var vid := _next_vehicle_id()
	vehicles.append({
		"id": vid,
		"year": int(year),
		"make": make_s,
		"model": model_s,
		"name": name_s,
		"vin": "",
		"plate": "",
		"odometer": miles,
		"odometer_date": today_ymd(),
		"photo": "",
		"archived": false,
		"services": [],
		"history": [],
	})
	selected_vehicle_id = vid
	selected_service_id = ""
	var oil_label := "Oil change"
	var oil_miles := 5000
	var oil_months := 6
	for item in load_templates():
		if str(item.get("id", "")) != "oil_change":
			continue
		oil_label = str(item.get("name", oil_label))
		oil_miles = int(item.get("interval_miles", oil_miles))
		oil_months = int(item.get("interval_months", oil_months))
		break
	add_service("oil_change", oil_label, oil_miles, oil_months)
	return true


func _next_vehicle_id() -> String:
	var taken := {}
	for item in data.get("vehicles", []):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		taken[str(item.get("id", ""))] = true
	var n := 2
	while taken.has("v_%02d" % n):
		n += 1
	return "v_%02d" % n


func vehicle_by_id(vehicle_id: String) -> Dictionary:
	if vehicle_id == "":
		return {}
	var vehicles: Array = data.get("vehicles", [])
	for item in vehicles:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var vehicle: Dictionary = item
		if str(vehicle.get("id", "")) == vehicle_id:
			return vehicle
	return {}


func service_by_id(vehicle: Dictionary, service_id: String) -> Dictionary:
	if vehicle.is_empty() or service_id == "":
		return {}
	for item in vehicle.get("services", []):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var service: Dictionary = item
		if str(service.get("id", "")) == service_id:
			return service
	return {}


func log_service(date: String, miles: int, cost_cents: int, notes: String) -> bool:
	if DueMath.parse_ymd(date).is_empty():
		return false
	if miles < 0:
		return false
	var vehicle := vehicle_by_id(selected_vehicle_id)
	if vehicle.is_empty():
		return false
	var service := service_by_id(vehicle, selected_service_id)
	if service.is_empty():
		return false
	if not vehicle.has("history") or typeof(vehicle["history"]) != TYPE_ARRAY:
		vehicle["history"] = []
	var history: Array = vehicle["history"]
	var hid := _next_history_id(history)
	history.append({
		"id": hid,
		"service_id": selected_service_id,
		"date": date,
		"miles": miles,
		"cost_cents": cost_cents,
		"notes": notes,
		"receipt": "",
	})
	service["last_date"] = date
	service["last_miles"] = miles
	var interval_miles := _as_int(service.get("interval_miles"), 0)
	var interval_months := _as_int(service.get("interval_months"), 0)
	service["next_date"] = DueMath.compute_next_date(date, interval_months)
	service["next_miles"] = DueMath.compute_next_miles(miles, interval_miles)
	if miles > int(vehicle.get("odometer", 0)):
		vehicle["odometer"] = miles
		vehicle["odometer_date"] = date
	save()
	var src := pending_receipt_src.strip_edges()
	pending_receipt_src = ""
	if src != "":
		var dest_name := "%s.jpg" % hid
		if PhotoService.save_jpeg(src, dest_name):
			var row: Dictionary = history[history.size() - 1]
			row["receipt"] = dest_name
			save()
	NotifyService.reschedule()
	return true


func history_for_selected() -> Array:
	var out: Array = []
	if selected_vehicle_id == "" or selected_service_id == "":
		return out
	var vehicle := vehicle_by_id(selected_vehicle_id)
	if vehicle.is_empty():
		return out
	for item in vehicle.get("history", []):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = item
		if str(row.get("service_id", "")) != selected_service_id:
			continue
		row["miles"] = _as_int(row.get("miles"), 0)
		row["cost_cents"] = _as_int(row.get("cost_cents"), 0)
		out.append(row)
	out.sort_custom(_history_newer)
	return out


func history_job(hid: String) -> Dictionary:
	var want := hid.strip_edges()
	if want == "":
		return {}
	var vehicle := vehicle_by_id(selected_vehicle_id)
	if vehicle.is_empty():
		return {}
	for item in vehicle.get("history", []):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = item
		if str(row.get("id", "")) == want:
			return row
	return {}


func update_history(hid: String, date: String, miles: int, cost_cents: int, notes: String) -> bool:
	if DueMath.parse_ymd(date).is_empty():
		return false
	if miles < 0:
		return false
	var vehicle := vehicle_by_id(selected_vehicle_id)
	if vehicle.is_empty():
		return false
	var job := history_job(hid)
	if job.is_empty():
		return false
	if str(job.get("service_id", "")) != selected_service_id:
		return false
	var service := service_by_id(vehicle, selected_service_id)
	if service.is_empty():
		return false
	job["date"] = date
	job["miles"] = miles
	job["cost_cents"] = cost_cents
	job["notes"] = notes
	_roll_from_history(vehicle, service)
	if miles > int(vehicle.get("odometer", 0)):
		vehicle["odometer"] = miles
		vehicle["odometer_date"] = date
	save()
	var src := pending_receipt_src.strip_edges()
	pending_receipt_src = ""
	if src != "":
		var dest_name := str(job.get("receipt", "")).strip_edges()
		if dest_name == "":
			dest_name = "%s.jpg" % hid.strip_edges()
		if PhotoService.save_jpeg(src, dest_name):
			job["receipt"] = dest_name
			save()
	NotifyService.reschedule()
	return true


func delete_history(hid: String) -> bool:
	var want := hid.strip_edges()
	if want == "":
		return false
	var vehicle := vehicle_by_id(selected_vehicle_id)
	if vehicle.is_empty():
		return false
	if not vehicle.has("history") or typeof(vehicle["history"]) != TYPE_ARRAY:
		return false
	var history: Array = vehicle["history"]
	var sid := ""
	var kept: Array = []
	var found := false
	for item in history:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = item
		if str(row.get("id", "")) == want:
			found = true
			sid = str(row.get("service_id", ""))
			PhotoService.delete_photo(str(row.get("receipt", "")))
			continue
		kept.append(row)
	if not found:
		return false
	vehicle["history"] = kept
	var service := service_by_id(vehicle, sid)
	if not service.is_empty():
		_roll_from_history(vehicle, service)
	selected_history_id = ""
	save()
	NotifyService.reschedule()
	return true


func _roll_from_history(vehicle: Dictionary, service: Dictionary) -> void:
	var newest := _newest_history_for(vehicle, str(service.get("id", "")))
	if newest.is_empty():
		service["last_date"] = ""
		service["last_miles"] = 0
		service["next_date"] = ""
		service["next_miles"] = 0
		return
	service["last_date"] = str(newest.get("date", ""))
	service["last_miles"] = _as_int(newest.get("miles"), 0)
	var interval_miles := _as_int(service.get("interval_miles"), 0)
	var interval_months := _as_int(service.get("interval_months"), 0)
	service["next_date"] = DueMath.compute_next_date(str(service["last_date"]), interval_months)
	service["next_miles"] = DueMath.compute_next_miles(int(service["last_miles"]), interval_miles)


func update_primary_vehicle(fields: Dictionary) -> void:
	var vehicle := vehicle_by_id(selected_vehicle_id)
	if vehicle.is_empty():
		vehicle = primary_vehicle()
	if vehicle.is_empty():
		return
	if fields.has("year"):
		vehicle["year"] = int(fields["year"])
	for key in ["make", "model", "name", "vin", "plate", "tire_size", "oil_filter"]:
		if fields.has(key):
			vehicle[key] = str(fields[key])
	save()


func set_vehicle_photo(filename: String) -> void:
	var vehicle := vehicle_by_id(selected_vehicle_id)
	if vehicle.is_empty():
		vehicle = primary_vehicle()
	if vehicle.is_empty():
		return
	vehicle["photo"] = filename.get_file().strip_edges()
	save()


func update_service_intervals(interval_miles: int, interval_months: int) -> bool:
	var vehicle := vehicle_by_id(selected_vehicle_id)
	if vehicle.is_empty():
		return false
	var service := service_by_id(vehicle, selected_service_id)
	if service.is_empty():
		return false
	var miles := int(interval_miles)
	var months := int(interval_months)
	if miles < 0:
		miles = 0
	if months < 0:
		months = 0
	service["interval_miles"] = miles
	service["interval_months"] = months
	var last_date := str(service.get("last_date", "")).strip_edges()
	var last_miles := _as_int(service.get("last_miles"), 0)
	var has_last := not DueMath.parse_ymd(last_date).is_empty() or last_miles > 0
	if has_last:
		service["next_date"] = DueMath.compute_next_date(last_date, months)
		service["next_miles"] = DueMath.compute_next_miles(last_miles, miles)
	else:
		service["next_date"] = ""
		service["next_miles"] = 0
	save()
	NotifyService.reschedule()
	return true


func delete_selected_service() -> bool:
	var vehicle := vehicle_by_id(selected_vehicle_id)
	if vehicle.is_empty():
		return false
	if selected_service_id == "":
		return false
	var service := service_by_id(vehicle, selected_service_id)
	if service.is_empty():
		return false
	var sid := selected_service_id
	var services: Array = vehicle.get("services", [])
	var kept_services: Array = []
	for item in services:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		if str(item.get("id", "")) == sid:
			continue
		kept_services.append(item)
	vehicle["services"] = kept_services
	var kept_history: Array = []
	for item in vehicle.get("history", []):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		if str(item.get("service_id", "")) == sid:
			PhotoService.delete_photo(str(item.get("receipt", "")))
			continue
		kept_history.append(item)
	vehicle["history"] = kept_history
	selected_service_id = ""
	selected_history_id = ""
	save()
	NotifyService.reschedule()
	return true


func load_templates() -> Array:
	var path := "res://data/templates.json"
	if not FileAccess.file_exists(path):
		return []
	var text := FileAccess.get_file_as_string(path)
	if text.strip_edges() == "":
		return []
	var json := JSON.new()
	if json.parse(text) != OK:
		push_error("GarageStore: templates parse failed")
		return []
	if typeof(json.data) != TYPE_ARRAY:
		return []
	var out: Array = []
	for item in json.data:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = item
		out.append({
			"id": str(row.get("id", "")),
			"name": str(row.get("name", "")),
			"interval_miles": _as_int(row.get("interval_miles"), 0),
			"interval_months": _as_int(row.get("interval_months"), 0),
		})
	return out


func add_service(type_id: String, label: String, interval_miles: int, interval_months: int) -> bool:
	var vehicle := vehicle_by_id(selected_vehicle_id)
	if vehicle.is_empty():
		vehicle = primary_vehicle()
	if vehicle.is_empty():
		return false
	if not vehicle.has("services") or typeof(vehicle["services"]) != TYPE_ARRAY:
		vehicle["services"] = []
	var services: Array = vehicle["services"]
	if type_id != "custom":
		for item in services:
			if typeof(item) != TYPE_DICTIONARY:
				continue
			if str(item.get("type_id", "")) == type_id:
				return false
	services.append({
		"id": _next_service_id(services, type_id),
		"type_id": type_id,
		"label": label,
		"interval_miles": int(interval_miles),
		"interval_months": int(interval_months),
		"last_date": "",
		"last_miles": 0,
		"next_date": "",
		"next_miles": 0,
		"notify": false,
	})
	save()
	return true


func set_notify_lead_days(n: int) -> void:
	if n != 3 and n != 7 and n != 14:
		return
	data["notify_lead_days"] = n
	save()


func import_merge(parsed: Dictionary) -> bool:
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	if not bool(parsed.get("ok", false)):
		return false
	var vehicle := vehicle_by_id(selected_vehicle_id)
	if vehicle.is_empty():
		vehicle = primary_vehicle()
	if vehicle.is_empty():
		return false
	selected_vehicle_id = str(vehicle.get("id", ""))
	for item in parsed.get("vehicles", []):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		_merge_vehicle_fields(vehicle, item)
	var touched: Dictionary = {}
	for item in parsed.get("jobs", []):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var job: Dictionary = item
		var label := str(job.get("label", "")).strip_edges()
		if label == "":
			continue
		var date := str(job.get("date", "")).strip_edges()
		if DueMath.parse_ymd(date).is_empty():
			continue
		var miles := int(job.get("miles", 0))
		var cost_cents := int(job.get("cost_cents", 0))
		var notes := str(job.get("notes", ""))
		var service := _match_import_service(vehicle, label)
		if service.is_empty():
			if not add_service("custom", label, 0, 0):
				continue
			service = _match_import_service(vehicle, label)
		if service.is_empty():
			continue
		var service_id := str(service.get("id", ""))
		if _history_dupe(vehicle, service_id, date, miles):
			continue
		if not vehicle.has("history") or typeof(vehicle["history"]) != TYPE_ARRAY:
			vehicle["history"] = []
		var history: Array = vehicle["history"]
		history.append({
			"id": _next_history_id(history),
			"service_id": service_id,
			"date": date,
			"miles": miles,
			"cost_cents": cost_cents,
			"notes": notes,
			"receipt": "",
		})
		touched[service_id] = true
		if miles > int(vehicle.get("odometer", 0)):
			vehicle["odometer"] = miles
			vehicle["odometer_date"] = date
	for service_id in touched.keys():
		var service := service_by_id(vehicle, str(service_id))
		if service.is_empty():
			continue
		var newest := _newest_history_for(vehicle, str(service_id))
		if newest.is_empty():
			continue
		service["last_date"] = str(newest.get("date", ""))
		service["last_miles"] = int(newest.get("miles", 0))
		var interval_miles := _as_int(service.get("interval_miles"), 0)
		var interval_months := _as_int(service.get("interval_months"), 0)
		service["next_date"] = DueMath.compute_next_date(str(service["last_date"]), interval_months)
		service["next_miles"] = DueMath.compute_next_miles(int(service["last_miles"]), interval_miles)
	save()
	return true


func _merge_vehicle_fields(vehicle: Dictionary, incoming: Dictionary) -> void:
	var year := int(incoming.get("year", 0))
	if year != 0:
		vehicle["year"] = year
	for key in ["make", "model", "name", "vin", "plate", "oil_filter", "tire_size"]:
		var value := str(incoming.get(key, "")).strip_edges()
		if value != "":
			vehicle[key] = value
	var odometer := int(incoming.get("odometer", 0))
	if odometer > int(vehicle.get("odometer", 0)):
		vehicle["odometer"] = odometer


func _match_import_service(vehicle: Dictionary, label: String) -> Dictionary:
	var services: Array = vehicle.get("services", [])
	var lower := label.to_lower()
	var type_id := ""
	if lower.contains("oil"):
		type_id = "oil_change"
	elif lower.contains("tire"):
		type_id = "tire_rotation"
	elif lower.contains("brake"):
		type_id = "brake_inspect"
	if type_id != "":
		for item in services:
			if typeof(item) != TYPE_DICTIONARY:
				continue
			var service: Dictionary = item
			if str(service.get("type_id", "")) == type_id:
				return service
	for item in services:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var service: Dictionary = item
		if str(service.get("label", "")).strip_edges().to_lower() == lower:
			return service
	return {}


func _history_dupe(vehicle: Dictionary, service_id: String, date: String, miles: int) -> bool:
	for item in vehicle.get("history", []):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = item
		if str(row.get("service_id", "")) != service_id:
			continue
		if str(row.get("date", "")) != date:
			continue
		if int(row.get("miles", 0)) != miles:
			continue
		return true
	return false


func _newest_history_for(vehicle: Dictionary, service_id: String) -> Dictionary:
	var newest: Dictionary = {}
	for item in vehicle.get("history", []):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = item
		if str(row.get("service_id", "")) != service_id:
			continue
		if newest.is_empty():
			newest = row
			continue
		var cmp := DueMath.compare_ymd(str(row.get("date", "")), str(newest.get("date", "")))
		if cmp > 0:
			newest = row
		elif cmp == 0 and int(row.get("miles", 0)) > int(newest.get("miles", 0)):
			newest = row
	return newest


func export_jobs_csv() -> String:
	return CsvExport.jobs_csv(data)


func write_export_csv(path: String) -> bool:
	if path.strip_edges() == "":
		return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(export_jobs_csv())
	file.flush()
	file.close()
	return true


func write_backup_zip(path: String) -> bool:
	if path.strip_edges() == "":
		return false
	var json_text := JSON.stringify(data, "\t")
	return BackupZip.write_zip(path, json_text, PHOTOS_DIR)


func restore_from_zip(path: String) -> bool:
	var packed := BackupZip.read_zip(path)
	if not bool(packed.get("ok", false)):
		last_backup_error = str(packed.get("error", BackupZip.READ_ERROR))
		return false
	_atomic_write(str(packed.get("json_text", "")))
	_write_restored_photos(packed.get("photos", {}))
	load_from_disk()
	last_backup_error = ""
	return true


func _write_restored_photos(photos: Variant) -> void:
	if typeof(photos) != TYPE_DICTIONARY:
		return
	var bag: Dictionary = photos
	if bag.is_empty():
		return
	var user_dir := DirAccess.open("user://")
	if user_dir == null:
		return
	user_dir.make_dir("photos")
	for name in bag.keys():
		var fname := str(name).get_file()
		if fname == "":
			continue
		var bytes: Variant = bag[name]
		if typeof(bytes) != TYPE_PACKED_BYTE_ARRAY:
			continue
		var dest := "%s/%s" % [PHOTOS_DIR, fname]
		var file := FileAccess.open(dest, FileAccess.WRITE)
		if file == null:
			continue
		file.store_buffer(bytes)
		file.flush()
		file.close()


func _next_service_id(services: Array, type_id: String) -> String:
	var taken := {}
	for item in services:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		taken[str(item.get("id", ""))] = true
	var base := "s_%s" % type_id
	if not taken.has(base):
		return base
	var n := 2
	while taken.has("%s_%d" % [base, n]):
		n += 1
	return "%s_%d" % [base, n]


func _history_newer(a: Dictionary, b: Dictionary) -> bool:
	var date_a := str(a.get("date", ""))
	var date_b := str(b.get("date", ""))
	if date_a != date_b:
		return date_a > date_b
	return str(a.get("id", "")) > str(b.get("id", ""))


func _next_history_id(history: Array) -> String:
	var max_n := 0
	for item in history:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var hid := str(item.get("id", ""))
		if hid.begins_with("h_"):
			var n := int(hid.substr(2))
			if n > max_n:
				max_n = n
	return "h_%02d" % (max_n + 1)


func _as_int(value: Variant, fallback: int) -> int:
	if value == null:
		return fallback
	var value_type := typeof(value)
	if value_type == TYPE_INT or value_type == TYPE_FLOAT:
		return int(value)
	return fallback


func today_ymd() -> String:
	var d := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [int(d.year), int(d.month), int(d.day)]


func add_days_ymd(ymd: String, delta: int) -> String:
	var parts := ymd.split("-")
	if parts.size() != 3:
		return ymd
	var ordinal := _ymd_to_ordinal(int(parts[0]), int(parts[1]), int(parts[2]))
	return _ordinal_to_ymd(ordinal + delta)


func _migrate(payload: Dictionary, from_version: int) -> Dictionary:
	if from_version >= SCHEMA + 1:
		return payload
	if from_version <= 0:
		if not payload.has("units"):
			payload["units"] = "mi"
		if not payload.has("currency"):
			payload["currency"] = "USD"
		if not payload.has("notify_lead_days"):
			payload["notify_lead_days"] = 7
		if not payload.has("unlocked"):
			payload["unlocked"] = false
		if not payload.has("vehicles"):
			payload["vehicles"] = []
	payload["schema"] = SCHEMA
	return payload


func _seed() -> Dictionary:
	return {
		"schema": SCHEMA,
		"units": "mi",
		"currency": "USD",
		"notify_lead_days": 7,
		"unlocked": false,
		"vehicles": [
			{
				"id": "v_01",
				"year": 0,
				"make": "",
				"model": "",
				"name": "My car",
				"vin": "",
				"plate": "",
				"odometer": 0,
				"odometer_date": "",
				"photo": "",
				"archived": false,
				"services": [],
				"history": [],
			},
		],
	}


func demo_vehicle() -> Dictionary:
	var today := today_ymd()
	return {
		"id": "v1",
		"year": 2018,
		"make": "Honda",
		"model": "Civic",
		"name": "2018 Civic",
		"vin": "",
		"plate": "",
		"odometer": 87420,
		"odometer_date": today,
		"photo": "",
		"archived": false,
		"services": [
			{
				"id": "svc_oil",
				"type_id": "oil_change",
				"label": "Oil change",
				"interval_miles": 5000,
				"interval_months": 6,
				"last_date": add_days_ymd(today, -210),
				"last_miles": 80000,
				"next_date": add_days_ymd(today, -30),
				"next_miles": 85000,
				"notify": true,
			},
			{
				"id": "svc_tire",
				"type_id": "tire_rotation",
				"label": "Tire rotation",
				"interval_miles": 7500,
				"interval_months": 6,
				"last_date": add_days_ymd(today, -177),
				"last_miles": 80120,
				"next_date": add_days_ymd(today, 3),
				"next_miles": 87620,
				"notify": true,
			},
			{
				"id": "svc_brake",
				"type_id": "brake_inspect",
				"label": "Brake inspection",
				"interval_miles": null,
				"interval_months": 12,
				"last_date": add_days_ymd(today, -185),
				"last_miles": null,
				"next_date": add_days_ymd(today, 180),
				"next_miles": null,
				"notify": true,
			},
		],
		"history": [],
	}


func load_demo() -> void:
	if not data.has("vehicles") or typeof(data["vehicles"]) != TYPE_ARRAY:
		data["vehicles"] = []
	var vehicle := demo_vehicle()
	vehicle["id"] = _next_vehicle_id()
	var vehicles: Array = data["vehicles"]
	vehicles.append(vehicle)
	selected_vehicle_id = str(vehicle.get("id", ""))
	selected_service_id = ""
	save()
	NotifyService.reschedule()


func _try_parse(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	if text.strip_edges() == "":
		return {}
	var json := JSON.new()
	if json.parse(text) != OK:
		push_error("GarageStore: parse failed %s" % path)
		return {}
	if typeof(json.data) != TYPE_DICTIONARY:
		push_error("GarageStore: not an object %s" % path)
		return {}
	return json.data


func _try_newest_backup() -> Dictionary:
	var dir := DirAccess.open(BACKUP_DIR)
	if dir == null:
		return {}
	var names: Array[String] = []
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.begins_with("garage-") and fname.ends_with(".json"):
			names.append(fname)
		fname = dir.get_next()
	dir.list_dir_end()
	names.sort()
	var i := names.size()
	while i >= 1:
		i -= 1
		var parsed := _try_parse("%s/%s" % [BACKUP_DIR, names[i]])
		if not parsed.is_empty():
			return parsed
	return {}


func _atomic_write(text: String) -> void:
	var tmp := FileAccess.open(TMP_PATH, FileAccess.WRITE)
	if tmp == null:
		push_error("GarageStore: cannot open tmp %s" % FileAccess.get_open_error())
		return
	tmp.store_string(text)
	tmp.flush()
	tmp.close()
	var dir := DirAccess.open("user://")
	if dir == null:
		push_error("GarageStore: cannot open user://")
		return
	if FileAccess.file_exists(PATH):
		var err := dir.rename("garage.json.tmp", "garage.json")
		if err != OK:
			dir.remove("garage.json")
			err = dir.rename("garage.json.tmp", "garage.json")
			if err != OK:
				push_error("GarageStore: rename failed %s" % err)
	else:
		var err := dir.rename("garage.json.tmp", "garage.json")
		if err != OK:
			push_error("GarageStore: rename failed %s" % err)


func _write_backup() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var user_dir := DirAccess.open("user://")
	if user_dir == null:
		return
	user_dir.make_dir("backups")
	var dt := Time.get_datetime_dict_from_system()
	var stamp := "garage-%04d%02d%02d-%02d%02d%02d.json" % [
		int(dt.year), int(dt.month), int(dt.day),
		int(dt.hour), int(dt.minute), int(dt.second),
	]
	var dest := "%s/%s" % [BACKUP_DIR, stamp]
	var backup := FileAccess.open(dest, FileAccess.WRITE)
	if backup == null:
		push_error("GarageStore: cannot write backup")
		return
	backup.store_string(FileAccess.get_file_as_string(PATH))
	backup.flush()
	backup.close()


func _prune_backups() -> void:
	var dir := DirAccess.open(BACKUP_DIR)
	if dir == null:
		return
	var names: Array[String] = []
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.begins_with("garage-") and fname.ends_with(".json"):
			names.append(fname)
		fname = dir.get_next()
	dir.list_dir_end()
	names.sort()
	while names.size() >= BACKUP_KEEP + 1:
		dir.remove(names[0])
		names.remove_at(0)


func _coerce_ints(payload: Dictionary) -> void:
	payload["schema"] = int(payload.get("schema", SCHEMA))
	payload["notify_lead_days"] = int(payload.get("notify_lead_days", 7))
	payload["unlocked"] = bool(payload.get("unlocked", false))
	var vehicles: Array = payload.get("vehicles", [])
	for item in vehicles:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var vehicle: Dictionary = item
		vehicle["year"] = int(vehicle.get("year", 0))
		vehicle["odometer"] = int(vehicle.get("odometer", 0))
		vehicle["archived"] = bool(vehicle.get("archived", false))
		for svc_item in vehicle.get("services", []):
			if typeof(svc_item) != TYPE_DICTIONARY:
				continue
			var service: Dictionary = svc_item
			_coerce_optional_int(service, "interval_miles")
			_coerce_optional_int(service, "interval_months")
			_coerce_optional_int(service, "last_miles")
			_coerce_optional_int(service, "next_miles")
			service["notify"] = bool(service.get("notify", false))
		for hist_item in vehicle.get("history", []):
			if typeof(hist_item) != TYPE_DICTIONARY:
				continue
			var row: Dictionary = hist_item
			_coerce_optional_int(row, "miles")
			row["cost_cents"] = int(row.get("cost_cents", 0))


func _coerce_optional_int(payload: Dictionary, key: String) -> void:
	if not payload.has(key) or payload[key] == null:
		payload[key] = null
		return
	payload[key] = int(payload[key])


func _is_leap(year: int) -> bool:
	return year % 4 == 0 and (year % 100 != 0 or year % 400 == 0)


func _days_in_month(year: int, month: int) -> int:
	if month == 2 and _is_leap(year):
		return 29
	return MONTH_DAYS[month]


func _ymd_to_ordinal(year: int, month: int, day: int) -> int:
	var n := day
	var y := 1
	while y <= year - 1:
		n += 366 if _is_leap(y) else 365
		y += 1
	var m := 1
	while m <= month - 1:
		n += _days_in_month(year, m)
		m += 1
	return n


func _ordinal_to_ymd(n: int) -> String:
	var year := 1
	while true:
		var year_days := 366 if _is_leap(year) else 365
		if n <= year_days:
			break
		n -= year_days
		year += 1
	var month := 1
	while true:
		var month_days := _days_in_month(year, month)
		if n <= month_days:
			break
		n -= month_days
		month += 1
	return "%04d-%02d-%02d" % [year, month, n]
