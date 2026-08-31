extends RefCounted
class_name CsvExport

const HEADER := "vehicle_name,year,make,model,vin,plate,service,date,miles,cost,notes"


static func jobs_csv(data: Dictionary) -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append(HEADER)
	var vehicles: Array = data.get("vehicles", [])
	for item in vehicles:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var vehicle: Dictionary = item
		var services: Array = vehicle.get("services", [])
		for hist_item in vehicle.get("history", []):
			if typeof(hist_item) != TYPE_DICTIONARY:
				continue
			var job: Dictionary = hist_item
			var service_id := str(job.get("service_id", ""))
			var label := _service_label(services, service_id)
			var cents := int(job.get("cost_cents", 0))
			if cents < 0:
				cents = 0
			var fields: PackedStringArray = PackedStringArray([
				_csv_field(str(vehicle.get("name", ""))),
				_csv_field(str(int(vehicle.get("year", 0)))),
				_csv_field(str(vehicle.get("make", ""))),
				_csv_field(str(vehicle.get("model", ""))),
				_csv_field(str(vehicle.get("vin", ""))),
				_csv_field(str(vehicle.get("plate", ""))),
				_csv_field(label),
				_csv_field(str(job.get("date", ""))),
				_csv_field(str(int(job.get("miles", 0)))),
				_csv_field(_cents_to_dollars(cents)),
				_csv_field(str(job.get("notes", ""))),
			])
			lines.append(",".join(fields))
	return "\n".join(lines) + "\n"


static func _cents_to_dollars(cents: int) -> String:
	var n := cents
	if n < 0:
		n = 0
	var dollars := n / 100
	var rem := n % 100
	return "%d.%02d" % [dollars, rem]


static func _service_label(services: Array, service_id: String) -> String:
	if service_id == "":
		return ""
	for item in services:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var service: Dictionary = item
		if str(service.get("id", "")) == service_id:
			return str(service.get("label", ""))
	return ""


static func _csv_field(value: String) -> String:
	if value.contains(",") or value.contains("\"") or value.contains("\n") or value.contains("\r"):
		return "\"%s\"" % value.replace("\"", "\"\"")
	return value
