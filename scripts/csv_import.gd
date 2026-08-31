extends RefCounted
class_name CsvImport

# VMT equipment (vehicle card):
# Id,EquipmentName,Year,Make,Model,VIN,Plate,OilFilter,OilType,TireSize,TirePressure,TireRear,PsiRear,FuelType,Odometer,EngineHour,FuelFilter,AirFilter,HydraulicFilter,Note,PurchaseDate,CreateDate
#
# VMT maintenance (jobs):
# Id,VIN,Plate,Name,Description,Odometer,EngineHour,PartCost,LaborCost,MaintainedBy,Status,ServiceDate,CreateDate,Note

const DueMath = preload("res://scripts/due_math.gd")
const READ_ERROR := "Couldn't read this file. Email it to support and log by hand for now."


static func parse_file(path: String) -> Dictionary:
	var empty := _result(false, "error", READ_ERROR, [], [])
	if path.strip_edges() == "":
		return empty
	if not FileAccess.file_exists(path):
		return empty
	var text := FileAccess.get_file_as_string(path)
	if text.strip_edges() == "":
		return empty
	if text.begins_with("\uFEFF"):
		text = text.substr(1)
	var lines := text.replace("\r\n", "\n").replace("\r", "\n").split("\n")
	var rows: Array = []
	for line in lines:
		if str(line).strip_edges() == "":
			continue
		rows.append(_parse_csv_line(str(line)))
	if rows.is_empty():
		return empty
	var headers: Array = []
	for h in rows[0]:
		headers.append(str(h).strip_edges())
	var kind := _detect_kind(headers)
	var vehicles: Array = []
	var jobs: Array = []
	for i in range(1, rows.size()):
		var cells: Array = rows[i]
		if _row_empty(cells):
			continue
		if kind == "vmt_equipment":
			vehicles.append(_equipment_vehicle(headers, cells))
		elif kind == "vmt_maintenance":
			jobs.append(_maintenance_job(headers, cells))
		else:
			_append_generic(headers, cells, vehicles, jobs)
	return _result(true, kind, "", vehicles, jobs)


static func parse_import_date(raw: String) -> String:
	var s := raw.strip_edges()
	if s == "":
		return ""
	var date_part := s.split(" ")[0].strip_edges()
	if date_part.contains("-") and date_part.length() >= 10:
		var ymd := date_part.substr(0, 10)
		if DueMath.parse_ymd(ymd).is_empty():
			return ""
		return ymd
	var parts := date_part.split("/")
	if parts.size() != 3:
		return ""
	if not parts[0].is_valid_int() or not parts[1].is_valid_int() or not parts[2].is_valid_int():
		return ""
	var month := int(parts[0])
	var day := int(parts[1])
	var year := int(parts[2])
	var ymd := DueMath.format_ymd(year, month, day)
	if DueMath.parse_ymd(ymd).is_empty():
		return ""
	return ymd


static func dollars_to_cents(raw: String) -> Dictionary:
	var s := raw.strip_edges().replace("$", "").replace(",", "")
	if s == "":
		return {"ok": true, "cents": 0}
	var parts := s.split(".")
	if parts.size() >= 3:
		return {"ok": false, "cents": 0}
	if parts.size() == 1:
		if not parts[0].is_valid_int():
			return {"ok": false, "cents": 0}
		var dollars := int(parts[0])
		if dollars < 0:
			return {"ok": false, "cents": 0}
		return {"ok": true, "cents": dollars * 100}
	var dollars_s := parts[0]
	var cents_s := parts[1]
	if dollars_s == "":
		dollars_s = "0"
	if not dollars_s.is_valid_int():
		return {"ok": false, "cents": 0}
	if int(dollars_s) < 0:
		return {"ok": false, "cents": 0}
	if cents_s.length() > 2:
		cents_s = cents_s.substr(0, 2)
	elif cents_s.length() == 1:
		cents_s += "0"
	elif cents_s.length() == 0:
		cents_s = "00"
	if not cents_s.is_valid_int():
		return {"ok": false, "cents": 0}
	return {"ok": true, "cents": int(dollars_s) * 100 + int(cents_s)}


static func _result(ok: bool, kind: String, error: String, vehicles: Array, jobs: Array) -> Dictionary:
	return {
		"ok": ok,
		"kind": kind,
		"error": error,
		"vehicles": vehicles,
		"jobs": jobs,
	}


static func _detect_kind(headers: Array) -> String:
	if _has_header(headers, "EquipmentName") and _has_header(headers, "OilFilter"):
		return "vmt_equipment"
	if (
		_has_header(headers, "ServiceDate")
		and _has_header(headers, "PartCost")
		and _has_header(headers, "Description")
	):
		return "vmt_maintenance"
	return "generic"


static func _has_header(headers: Array, name: String) -> bool:
	for h in headers:
		if str(h) == name:
			return true
	return false


static func _col(headers: Array, cells: Array, name: String) -> String:
	for i in range(headers.size()):
		if str(headers[i]) == name:
			if i < cells.size():
				return str(cells[i]).strip_edges()
			return ""
	return ""


static func _equipment_vehicle(headers: Array, cells: Array) -> Dictionary:
	return {
		"name": _col(headers, cells, "EquipmentName"),
		"year": _as_int_str(_col(headers, cells, "Year")),
		"make": _col(headers, cells, "Make"),
		"model": _col(headers, cells, "Model"),
		"vin": _col(headers, cells, "VIN"),
		"plate": _col(headers, cells, "Plate"),
		"oil_filter": _col(headers, cells, "OilFilter"),
		"tire_size": _col(headers, cells, "TireSize"),
		"odometer": _as_int_str(_col(headers, cells, "Odometer")),
	}


static func _maintenance_job(headers: Array, cells: Array) -> Dictionary:
	var part := dollars_to_cents(_col(headers, cells, "PartCost"))
	var labor := dollars_to_cents(_col(headers, cells, "LaborCost"))
	return {
		"vehicle_name": _col(headers, cells, "Name"),
		"plate": _col(headers, cells, "Plate"),
		"vin": _col(headers, cells, "VIN"),
		"label": _col(headers, cells, "Description"),
		"date": parse_import_date(_col(headers, cells, "ServiceDate")),
		"miles": _as_int_str(_col(headers, cells, "Odometer")),
		"cost_cents": int(part.get("cents", 0)) + int(labor.get("cents", 0)),
		"notes": _col(headers, cells, "Note"),
	}


static func _append_generic(headers: Array, cells: Array, vehicles: Array, jobs: Array) -> void:
	var mapped := {
		"name": "",
		"year": 0,
		"make": "",
		"model": "",
		"vin": "",
		"plate": "",
		"oil_filter": "",
		"tire_size": "",
		"odometer": 0,
		"label": "",
		"date": "",
		"miles": 0,
		"cost_cents": 0,
		"notes": "",
		"vehicle_name": "",
	}
	var has_vehicle := false
	var has_job := false
	for i in range(headers.size()):
		var key := str(headers[i]).to_lower()
		var value := ""
		if i < cells.size():
			value = str(cells[i]).strip_edges()
		if key.contains("date"):
			mapped["date"] = parse_import_date(value)
			has_job = true
		elif key.contains("odo") or key.contains("mile"):
			mapped["odometer"] = _as_int_str(value)
			mapped["miles"] = _as_int_str(value)
		elif key.contains("cost"):
			if key.contains("cent"):
				mapped["cost_cents"] = _as_int_str(value)
			else:
				mapped["cost_cents"] = int(dollars_to_cents(value).get("cents", 0))
			has_job = true
		elif key.contains("desc") or key.contains("service") or key.contains("type"):
			mapped["label"] = value
			has_job = true
		elif key.contains("vin"):
			mapped["vin"] = value
			has_vehicle = true
		elif key.contains("make"):
			mapped["make"] = value
			has_vehicle = true
		elif key.contains("model"):
			mapped["model"] = value
			has_vehicle = true
		elif key.contains("plate"):
			mapped["plate"] = value
		elif key.contains("name") or key.contains("equipment"):
			mapped["name"] = value
			mapped["vehicle_name"] = value
			has_vehicle = true
	if has_vehicle:
		vehicles.append({
			"name": mapped["name"],
			"year": mapped["year"],
			"make": mapped["make"],
			"model": mapped["model"],
			"vin": mapped["vin"],
			"plate": mapped["plate"],
			"oil_filter": mapped["oil_filter"],
			"tire_size": mapped["tire_size"],
			"odometer": mapped["odometer"],
		})
	if has_job:
		jobs.append({
			"vehicle_name": mapped["vehicle_name"],
			"plate": mapped["plate"],
			"vin": mapped["vin"],
			"label": mapped["label"],
			"date": mapped["date"],
			"miles": mapped["miles"],
			"cost_cents": mapped["cost_cents"],
			"notes": mapped["notes"],
		})


static func _as_int_str(raw: String) -> int:
	var s := raw.strip_edges().replace(",", "")
	if s == "":
		return 0
	if s.contains("."):
		s = s.split(".")[0]
	if not s.is_valid_int():
		return 0
	return int(s)


static func _row_empty(cells: Array) -> bool:
	for c in cells:
		if str(c).strip_edges() != "":
			return false
	return true


static func _parse_csv_line(line: String) -> Array:
	var out: Array = []
	var cur := ""
	var in_quotes := false
	var i := 0
	while i < line.length():
		var ch := line[i]
		if in_quotes:
			if ch == "\"":
				if i + 1 < line.length() and line[i + 1] == "\"":
					cur += "\""
					i += 1
				else:
					in_quotes = false
			else:
				cur += ch
		else:
			if ch == "\"":
				in_quotes = true
			elif ch == ",":
				out.append(cur)
				cur = ""
			else:
				cur += ch
		i += 1
	out.append(cur)
	return out
