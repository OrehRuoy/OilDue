extends RefCounted
class_name SpendRollup


static func rollup(vehicle: Dictionary) -> Dictionary:
	var totals: Dictionary = {}
	var total := 0
	var services: Array = vehicle.get("services", [])
	for item in vehicle.get("history", []):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var job: Dictionary = item
		var cents := int(job.get("cost_cents", 0))
		if cents <= 0:
			continue
		var label := _label(services, str(job.get("service_id", "")))
		if label == "":
			label = "Other"
		totals[label] = int(totals.get(label, 0)) + cents
		total += cents
	var rows: Array = []
	for key in totals.keys():
		rows.append({"label": str(key), "cents": int(totals[key])})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ca := int(a.get("cents", 0))
		var cb := int(b.get("cents", 0))
		if ca != cb:
			return ca > cb
		return str(a.get("label", "")) < str(b.get("label", ""))
	)
	return {"total_cents": total, "rows": rows}


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
