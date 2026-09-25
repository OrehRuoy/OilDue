extends RefCounted
class_name HistoryPdf

const DueMath = preload("res://scripts/due_math.gd")
const PdfText = preload("res://scripts/pdf_text.gd")
const NOTE_MAX := 120


static func has_jobs(vehicle: Dictionary) -> bool:
	for item in vehicle.get("history", []):
		if typeof(item) == TYPE_DICTIONARY:
			return true
	return false


static func for_vehicle(vehicle: Dictionary) -> PackedByteArray:
	return PdfText.render(_lines(vehicle))


static func _lines(vehicle: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var name := str(vehicle.get("name", "")).strip_edges()
	if name == "":
		name = "Car"
	lines.append(name)
	var spec := _spec(vehicle)
	if spec != "":
		lines.append(spec)
	lines.append("")
	var services: Array = vehicle.get("services", [])
	for item in _jobs_newest(vehicle):
		var job: Dictionary = item
		var shown := DueMath.format_display_date(str(job.get("date", "")))
		if shown == "":
			shown = str(job.get("date", ""))
		var miles := DueMath.format_miles(int(job.get("miles", 0)))
		var label := _label(services, str(job.get("service_id", "")))
		if label == "":
			label = "Job"
		var cents := int(job.get("cost_cents", 0))
		var cost := ""
		if cents > 0:
			cost = "  " + DueMath.format_cents(cents)
		lines.append("%s  %s mi  %s%s" % [shown, miles, label, cost])
		var notes := str(job.get("notes", "")).replace("\n", " ").replace("\r", " ").strip_edges()
		if notes.length() > NOTE_MAX:
			notes = notes.substr(0, NOTE_MAX)
		if notes != "":
			lines.append(notes)
		lines.append("")
	return lines


static func _spec(vehicle: Dictionary) -> String:
	var bits: PackedStringArray = PackedStringArray()
	var year := int(vehicle.get("year", 0))
	if year > 0:
		bits.append(str(year))
	var make := str(vehicle.get("make", "")).strip_edges()
	if make != "":
		bits.append(make)
	var model := str(vehicle.get("model", "")).strip_edges()
	if model != "":
		bits.append(model)
	return " ".join(bits)


static func _jobs_newest(vehicle: Dictionary) -> Array:
	var out: Array = []
	for item in vehicle.get("history", []):
		if typeof(item) == TYPE_DICTIONARY:
			out.append(item)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var date_a := str(a.get("date", ""))
		var date_b := str(b.get("date", ""))
		if date_a != date_b:
			return date_a > date_b
		return str(a.get("id", "")) > str(b.get("id", ""))
	)
	return out


static func _label(services: Array, service_id: String) -> String:
	if service_id == "":
		return ""
	for item in services:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var service: Dictionary = item
		if str(service.get("id", "")) == service_id:
			return str(service.get("label", "")).strip_edges()
	return ""
