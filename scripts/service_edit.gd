extends Control

const DueMath = preload("res://scripts/due_math.gd")

@onready var _title: Label = %Title
@onready var _date_edit: LineEdit = %DateEdit
@onready var _miles_edit: LineEdit = %MilesEdit
@onready var _cost_edit: LineEdit = %CostEdit
@onready var _notes_edit: LineEdit = %NotesEdit
@onready var _error: Label = %ErrorLabel
@onready var _receipt_preview: TextureRect = %ReceiptPreview


func _ready() -> void:
	_ensure_selection()
	var vehicle := GarageStore.vehicle_by_id(GarageStore.selected_vehicle_id)
	var service := GarageStore.service_by_id(vehicle, GarageStore.selected_service_id)
	var label := str(service.get("label", ""))
	_title.text = label if label != "" else "Log service"
	_date_edit.text = GarageStore.today_ymd()
	_miles_edit.text = str(int(vehicle.get("odometer", 0)))
	_cost_edit.text = ""
	_notes_edit.text = ""
	_error.text = ""
	_receipt_preview.texture = null
	%LogButton.pressed.connect(_on_log_pressed)
	%Back.pressed.connect(_on_back_pressed)
	%ReceiptButton.pressed.connect(_on_receipt_pressed)
	PhotoService.picked.connect(_on_photo_picked)
	PhotoService.failed.connect(_on_photo_failed)


func _exit_tree() -> void:
	if PhotoService.picked.is_connected(_on_photo_picked):
		PhotoService.picked.disconnect(_on_photo_picked)
	if PhotoService.failed.is_connected(_on_photo_failed):
		PhotoService.failed.disconnect(_on_photo_failed)


func _on_back_pressed() -> void:
	GarageStore.pending_receipt_src = ""
	get_tree().change_scene_to_file("res://scenes/service_list.tscn")


func _ensure_selection() -> void:
	if GarageStore.selected_vehicle_id != "" and GarageStore.selected_service_id != "":
		return
	var vehicle := GarageStore.primary_vehicle()
	GarageStore.selected_vehicle_id = str(vehicle.get("id", ""))
	var services: Array = vehicle.get("services", [])
	if services.size() >= 1 and typeof(services[0]) == TYPE_DICTIONARY:
		GarageStore.selected_service_id = str(services[0].get("id", ""))


func _on_receipt_pressed() -> void:
	_error.text = ""
	PhotoService.pick_image()


func _on_photo_picked(src_path: String) -> void:
	GarageStore.pending_receipt_src = src_path
	var img := Image.load_from_file(src_path)
	if img == null or img.is_empty():
		_receipt_preview.texture = null
		return
	_receipt_preview.texture = ImageTexture.create_from_image(img)


func _on_photo_failed(_message: String) -> void:
	_error.text = "Couldn't read that photo."


func _on_log_pressed() -> void:
	_error.text = ""
	var date := _date_edit.text.strip_edges()
	if DueMath.parse_ymd(date).is_empty():
		_error.text = "Enter a real date as YYYY-MM-DD."
		return
	var miles_raw := _miles_edit.text.strip_edges().replace(",", "")
	if not miles_raw.is_valid_int():
		_error.text = "Enter miles as a whole number."
		return
	var miles := int(miles_raw)
	if miles < 0:
		_error.text = "Miles cannot be negative."
		return
	var cost := _dollars_to_cents(_cost_edit.text)
	if not bool(cost["ok"]):
		_error.text = "Enter cost as dollars, or leave blank."
		return
	if not GarageStore.log_service(date, miles, int(cost["cents"]), _notes_edit.text.strip_edges()):
		_error.text = "Could not save this service."
		return
	get_tree().change_scene_to_file("res://scenes/service_list.tscn")


func _dollars_to_cents(raw: String) -> Dictionary:
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
