extends Control

const HistoryPdf = preload("res://scripts/history_pdf.gd")
const PdfText = preload("res://scripts/pdf_text.gd")


func _ready() -> void:
	var fail := _run()
	if fail == "":
		%Result.text = "PASS"
	else:
		%Result.text = "FAIL: %s" % fail
	print(%Result.text)


func _run() -> String:
	var notes := ""
	for _i in 200:
		notes += "q"
	var vehicle := {
		"name": "Daily",
		"year": 2018,
		"make": "Honda",
		"model": "Civic",
		"services": [{"id": "s_oil", "label": "Oil change"}],
		"history": [
			{
				"id": "h_01",
				"service_id": "s_oil",
				"date": "2024-01-02",
				"miles": 1000,
				"cost_cents": 2500,
				"notes": "first",
				"receipt": "h_01.jpg",
			},
			{
				"id": "h_02",
				"service_id": "s_oil",
				"date": "2025-06-01",
				"miles": 5000,
				"cost_cents": 0,
				"notes": notes,
			},
		],
	}
	var fail := _expect(HistoryPdf.has_jobs(vehicle), "has jobs")
	if fail != "":
		return fail
	fail = _expect(not HistoryPdf.has_jobs({"history": []}), "empty history")
	if fail != "":
		return fail
	var bytes := HistoryPdf.for_vehicle(vehicle)
	var path := "user://day45-history-test.pdf"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return "could not write test pdf"
	file.store_buffer(bytes)
	file.close()
	var back := FileAccess.get_file_as_bytes(path)
	var dir := DirAccess.open("user://")
	if dir != null:
		dir.remove("day45-history-test.pdf")
	var text := back.get_string_from_utf8()
	fail = _expect(text.begins_with("%PDF-"), "starts with %PDF-")
	if fail != "":
		return fail
	fail = _expect(text.contains("Daily"), "contains car name")
	if fail != "":
		return fail
	fail = _expect(text.contains("2018 Honda Civic"), "contains year make model")
	if fail != "":
		return fail
	fail = _expect(text.contains("Oil change"), "contains service label")
	if fail != "":
		return fail
	fail = _expect(text.contains("$25.00"), "shows a logged cost")
	if fail != "":
		return fail
	fail = _expect(not text.contains("$0.00"), "skips a missing cost")
	if fail != "":
		return fail
	fail = _expect(not text.contains("h_01.jpg"), "skips receipt file names")
	if fail != "":
		return fail
	var newer := text.find("Jun 1, 2025")
	var older := text.find("Jan 2, 2024")
	fail = _expect(newer >= 0 and older > newer, "newest job first")
	if fail != "":
		return fail
	fail = _expect(text.count("q") == 120, "notes stop at 120 characters")
	if fail != "":
		return fail
	fail = _expect(text.contains("Oil Due"), "footer")
	if fail != "":
		return fail
	var many: PackedStringArray = PackedStringArray()
	for i in 80:
		many.append("Line %d" % i)
	var paged := PdfText.render(many).get_string_from_utf8()
	fail = _expect(paged.contains("/Count 2"), "long history uses a second page")
	if fail != "":
		return fail
	return ""


func _expect(ok: bool, message: String) -> String:
	if ok:
		return ""
	return message
