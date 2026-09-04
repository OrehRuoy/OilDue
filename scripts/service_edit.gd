extends Control

const DueMath = preload("res://scripts/due_math.gd")
const IosSwitch = preload("res://scripts/ios_switch.gd")
const PanScroll = preload("res://scripts/pan_scroll.gd")
const ConfirmSheet = preload("res://scripts/confirm_sheet.gd")

@onready var _title: Label = %Title
@onready var _date_field: Button = %DateField
@onready var _miles_edit: LineEdit = %MilesEdit
@onready var _cost_edit: LineEdit = %CostEdit
@onready var _notes_edit: TextEdit = %NotesEdit
@onready var _error: Label = %ErrorLabel
@onready var _receipt_preview: TextureRect = %ReceiptPreview
@onready var _notify: IosSwitch = %NotifySwitch
@onready var _delete_btn: Button = %DeleteJobButton
@onready var _kb_pad: Control = %KeyboardPad

var _ymd := ""
var _editing := false
var _notify_pending := false


func _ready() -> void:
	_ensure_selection()
	_style_date_field()
	_style_notes_field()
	_fill_form()
	_error.text = ""
	set_process(DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD))
	%LogButton.pressed.connect(_on_log_pressed)
	%Back.pressed.connect(_on_back_pressed)
	%ReceiptButton.pressed.connect(_on_receipt_pressed)
	_miles_edit.focus_exited.connect(_on_miles_focus_exited)
	_delete_btn.pressed.connect(_on_delete_pressed)
	PanScroll.wire(_date_field, _on_date_pressed)
	PanScroll.wire_fields($Margin/PageHost)
	PanScroll.wire($Margin/PageHost/Column/FormGroup, func() -> void: pass)
	_setup_notify()
	if not NotifyService.permission_resolved.is_connected(_on_permission_resolved):
		NotifyService.permission_resolved.connect(_on_permission_resolved)
	PhotoService.picked.connect(_on_photo_picked)
	PhotoService.failed.connect(_on_photo_failed)
	DateService.picked.connect(_on_date_picked)
	DateService.cancelled.connect(_on_date_cancelled)


func _process(_delta: float) -> void:
	var kb := DisplayServer.virtual_keyboard_get_height()
	if kb < 0:
		kb = 0
	_kb_pad.custom_minimum_size.y = kb


func _exit_tree() -> void:
	if PhotoService.picked.is_connected(_on_photo_picked):
		PhotoService.picked.disconnect(_on_photo_picked)
	if PhotoService.failed.is_connected(_on_photo_failed):
		PhotoService.failed.disconnect(_on_photo_failed)
	if DateService.picked.is_connected(_on_date_picked):
		DateService.picked.disconnect(_on_date_picked)
	if DateService.cancelled.is_connected(_on_date_cancelled):
		DateService.cancelled.disconnect(_on_date_cancelled)
	if NotifyService.permission_resolved.is_connected(_on_permission_resolved):
		NotifyService.permission_resolved.disconnect(_on_permission_resolved)


func _on_back_pressed() -> void:
	GarageStore.pending_receipt_src = ""
	GarageStore.selected_history_id = ""
	get_tree().change_scene_to_file("res://scenes/service_list.tscn")


func _ensure_selection() -> void:
	if GarageStore.selected_vehicle_id != "" and GarageStore.selected_service_id != "":
		return
	var vehicle := GarageStore.primary_vehicle()
	GarageStore.selected_vehicle_id = str(vehicle.get("id", ""))
	var services: Array = vehicle.get("services", [])
	if services.size() >= 1 and typeof(services[0]) == TYPE_DICTIONARY:
		GarageStore.selected_service_id = str(services[0].get("id", ""))


func _fill_form() -> void:
	var vehicle := GarageStore.vehicle_by_id(GarageStore.selected_vehicle_id)
	var service := GarageStore.service_by_id(vehicle, GarageStore.selected_service_id)
	var job := GarageStore.history_job(GarageStore.selected_history_id)
	_editing = not job.is_empty()
	if _editing:
		_title.text = "Edit job"
		%LogButton.text = "Save"
		_delete_btn.visible = true
		_ymd = str(job.get("date", "")).strip_edges()
		if DueMath.parse_ymd(_ymd).is_empty():
			_ymd = GarageStore.today_ymd()
		_miles_edit.text = DueMath.format_miles(int(job.get("miles", 0)))
		_cost_edit.text = _cents_to_dollars_field(int(job.get("cost_cents", 0)))
		_notes_edit.text = str(job.get("notes", ""))
		var receipt := str(job.get("receipt", "")).strip_edges()
		_set_receipt_preview(PhotoService.load_texture(receipt))
	else:
		GarageStore.selected_history_id = ""
		var label := str(service.get("label", ""))
		_title.text = label if label != "" else "Log service"
		%LogButton.text = "Log this service"
		_delete_btn.visible = false
		_ymd = GarageStore.today_ymd()
		_miles_edit.text = DueMath.format_miles(int(vehicle.get("odometer", 0)))
		_cost_edit.text = ""
		_notes_edit.text = ""
		_set_receipt_preview(null)
	_refresh_date_label()


func _style_date_field() -> void:
	_date_field.add_theme_color_override("font_color", Color("#F2F2F7"))
	_date_field.add_theme_color_override("font_hover_color", Color("#F2F2F7"))
	_date_field.add_theme_color_override("font_pressed_color", Color("#F2F2F7"))
	_date_field.add_theme_font_size_override("font_size", 17)
	_date_field.alignment = HORIZONTAL_ALIGNMENT_RIGHT


func _style_notes_field() -> void:
	var empty := StyleBoxEmpty.new()
	_notes_edit.add_theme_stylebox_override("normal", empty)
	_notes_edit.add_theme_stylebox_override("focus", empty)
	_notes_edit.add_theme_color_override("font_color", Color("#F2F2F7"))
	_notes_edit.add_theme_font_size_override("font_size", 17)


func _on_date_pressed() -> void:
	DateService.pick(_ymd)


func _on_date_picked(ymd: String) -> void:
	if DueMath.parse_ymd(ymd).is_empty():
		return
	_ymd = ymd
	_refresh_date_label()


func _on_date_cancelled() -> void:
	_ymd = DateService.last_ymd
	_refresh_date_label()


func _refresh_date_label() -> void:
	var shown := DueMath.format_display_date(_ymd)
	_date_field.text = shown if shown != "" else _ymd


func _on_receipt_pressed() -> void:
	_error.text = ""
	PhotoService.pick_image()


func _on_miles_focus_exited() -> void:
	var raw := _miles_edit.text.strip_edges().replace(",", "")
	if raw.is_valid_int():
		_miles_edit.text = DueMath.format_miles(int(raw))


func _setup_notify() -> void:
	var vehicle := GarageStore.vehicle_by_id(GarageStore.selected_vehicle_id)
	var service := GarageStore.service_by_id(vehicle, GarageStore.selected_service_id)
	if Purchase.is_unlocked():
		_notify.on = bool(service.get("notify", false))
	else:
		_notify.on = false
	if not _notify.toggled.is_connected(_on_notify_toggled):
		_notify.toggled.connect(_on_notify_toggled)


func _on_notify_toggled(want_on: bool) -> void:
	_error.text = ""
	if not Purchase.is_unlocked():
		if not want_on:
			_notify_pending = false
			_notify.on = false
			GarageStore.set_service_notify(false)
			NotifyService.reschedule()
			return
		_notify_pending = false
		_notify.on = false
		GarageStore.unlock_back_scene = "res://scenes/service_edit.tscn"
		get_tree().change_scene_to_file("res://scenes/unlock.tscn")
		return
	if not want_on:
		_notify_pending = false
		_notify.on = false
		GarageStore.set_service_notify(false)
		return
	_notify.on = true
	if NotifyService.has_os_permission():
		_notify_pending = false
		GarageStore.set_service_notify(true)
		return
	_notify_pending = true
	NotifyService.ensure_permission()


func _on_permission_resolved(ok: bool) -> void:
	if not _notify_pending:
		return
	_notify_pending = false
	if not Purchase.is_unlocked():
		_notify.on = false
		return
	if ok:
		_notify.on = true
		GarageStore.set_service_notify(true)
		return
	_notify.on = false
	GarageStore.set_service_notify(false)
	_error.text = "Turn on Notifications in iPhone Settings → Oil Due"


func _on_photo_picked(src_path: String) -> void:
	GarageStore.pending_receipt_src = src_path
	var img := Image.load_from_file(src_path)
	if img == null or img.is_empty():
		_set_receipt_preview(null)
		return
	_set_receipt_preview(ImageTexture.create_from_image(img))


func _on_photo_failed(_message: String) -> void:
	_error.text = "Couldn't read that photo."


func _on_log_pressed() -> void:
	_error.text = ""
	var date := _ymd.strip_edges()
	if DueMath.parse_ymd(date).is_empty():
		_error.text = "Pick a date."
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
	var notes := _notes_edit.text.strip_edges()
	var ok := false
	if _editing:
		ok = GarageStore.update_history(
			GarageStore.selected_history_id, date, miles, int(cost["cents"]), notes
		)
	else:
		ok = GarageStore.log_service(date, miles, int(cost["cents"]), notes)
	if not ok:
		_error.text = "Could not save this service."
		return
	GarageStore.selected_history_id = ""
	get_tree().change_scene_to_file("res://scenes/service_list.tscn")


func _on_delete_pressed() -> void:
	ConfirmSheet.present(self, "Delete this job?", "", "Keep", "Delete", _on_delete_confirmed)


func _on_delete_confirmed() -> void:
	if not _editing:
		return
	if not GarageStore.delete_history(GarageStore.selected_history_id):
		_error.text = "Could not delete this job."
		return
	GarageStore.pending_receipt_src = ""
	GarageStore.selected_history_id = ""
	get_tree().change_scene_to_file("res://scenes/service_list.tscn")


func _set_receipt_preview(tex: Texture2D) -> void:
	_receipt_preview.texture = tex
	_receipt_preview.visible = tex != null


func _cents_to_dollars_field(cents: int) -> String:
	if cents <= 0:
		return ""
	var dollars := cents / 100
	var rem := cents % 100
	if rem == 0:
		return str(dollars)
	return "%d.%02d" % [dollars, rem]


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
