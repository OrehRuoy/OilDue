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
var _open_settings_btn: Button


func _ready() -> void:
	_ensure_selection()
	_style_date_field()
	_style_notes_field()
	_fill_form()
	_error.text = ""
	_apply_distance_caption()
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
	_cost_edit.placeholder_text = DueMath.format_cost_input(4550)
	if _editing:
		_title.text = tr("Edit job")
		%LogButton.text = tr("Save")
		_delete_btn.visible = true
		_ymd = str(job.get("date", "")).strip_edges()
		if DueMath.parse_ymd(_ymd).is_empty():
			_ymd = GarageStore.today_ymd()
		_miles_edit.text = DueMath.format_miles(DueMath.miles_to_display(int(job.get("miles", 0))))
		_cost_edit.text = DueMath.format_cost_input(int(job.get("cost_cents", 0)))
		_notes_edit.text = str(job.get("notes", ""))
		var receipt := str(job.get("receipt", "")).strip_edges()
		_set_receipt_preview(PhotoService.load_texture(receipt))
	else:
		GarageStore.selected_history_id = ""
		var label := str(service.get("label", ""))
		_title.text = tr(label) if label != "" else tr("Log service")
		%LogButton.text = tr("Log this service")
		_delete_btn.visible = false
		_ymd = GarageStore.today_ymd()
		_miles_edit.text = DueMath.format_miles(DueMath.miles_to_display(int(vehicle.get("odometer", 0))))
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
	if _remind_allowed():
		_notify.on = bool(service.get("notify", false))
	else:
		_notify.on = false
	if not _notify.toggled.is_connected(_on_notify_toggled):
		_notify.toggled.connect(_on_notify_toggled)


func _on_notify_toggled(want_on: bool) -> void:
	_error.text = ""
	if not _remind_allowed():
		if not want_on:
			_notify_pending = false
			_notify.on = false
			GarageStore.set_service_notify(false)
			NotifyService.reschedule()
			return
		_notify_pending = false
		_notify.on = false
		GarageStore.set_unlock_return("res://scenes/service_edit.tscn")
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


func _apply_distance_caption() -> void:
	var parent := _miles_edit.get_parent()
	if parent == null or parent.get_child_count() < 1:
		return
	var cap := parent.get_child(0)
	if cap is Label:
		cap.text = tr("Kilometers") if DueMath.distance_unit() == "km" else tr("Miles")


func _remind_allowed() -> bool:
	if Purchase.is_unlocked():
		return true
	var vehicles := GarageStore.vehicles_list()
	if vehicles.is_empty() or typeof(vehicles[0]) != TYPE_DICTIONARY:
		return false
	var first: Dictionary = vehicles[0]
	if str(first.get("id", "")) != GarageStore.selected_vehicle_id:
		return false
	var service := GarageStore.service_by_id(first, GarageStore.selected_service_id)
	return str(service.get("type_id", "")) == "oil_change"


func _on_permission_resolved(ok: bool) -> void:
	if not _notify_pending:
		return
	_notify_pending = false
	if not _remind_allowed():
		_notify.on = false
		return
	if ok:
		_notify.on = true
		GarageStore.set_service_notify(true)
		if _open_settings_btn != null:
			_open_settings_btn.visible = false
		return
	_notify.on = false
	GarageStore.set_service_notify(false)
	_error.text = tr("Reminders are off in iPhone Settings")
	_show_open_settings()


func _show_open_settings() -> void:
	if _open_settings_btn == null:
		_open_settings_btn = Button.new()
		_open_settings_btn.text = tr("Open Settings")
		_open_settings_btn.custom_minimum_size = Vector2(0, 48)
		_open_settings_btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_open_settings_btn.pressed.connect(NotifyService.open_settings)
		var parent := _error.get_parent()
		parent.add_child(_open_settings_btn)
		parent.move_child(_open_settings_btn, _error.get_index() + 1)
	_open_settings_btn.visible = true


func _on_photo_picked(src_path: String) -> void:
	GarageStore.pending_receipt_src = src_path
	var img := Image.load_from_file(src_path)
	if img == null or img.is_empty():
		_set_receipt_preview(null)
		return
	_set_receipt_preview(ImageTexture.create_from_image(img))


func _on_photo_failed(message: String) -> void:
	_error.text = tr(message) if message.strip_edges() != "" else tr("Couldn't read that photo.")


func _on_log_pressed() -> void:
	_error.text = ""
	var date := _ymd.strip_edges()
	if DueMath.parse_ymd(date).is_empty():
		_error.text = tr("Pick a date.")
		return
	var miles_raw := _miles_edit.text.strip_edges().replace(",", "")
	if not miles_raw.is_valid_int():
		_error.text = tr("Enter kilometers as a whole number.") if DueMath.distance_unit() == "km" else tr("Enter miles as a whole number.")
		return
	var miles := DueMath.display_to_miles(int(miles_raw))
	if miles < 0:
		_error.text = tr("Kilometers cannot be negative.") if DueMath.distance_unit() == "km" else tr("Miles cannot be negative.")
		return
	var cost := DueMath.parse_cents(_cost_edit.text)
	if not bool(cost["ok"]):
		_error.text = tr("Enter cost as a number, or leave blank.")
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
		_error.text = tr("Could not save this service.")
		return
	GarageStore.selected_history_id = ""
	get_tree().change_scene_to_file("res://scenes/service_list.tscn")


func _on_delete_pressed() -> void:
	ConfirmSheet.present(self, tr("Delete this job?"), "", tr("Keep"), tr("Delete"), _on_delete_confirmed)


func _on_delete_confirmed() -> void:
	if not _editing:
		return
	if not GarageStore.delete_history(GarageStore.selected_history_id):
		_error.text = tr("Could not delete this job.")
		return
	GarageStore.pending_receipt_src = ""
	GarageStore.selected_history_id = ""
	get_tree().change_scene_to_file("res://scenes/service_list.tscn")


func _set_receipt_preview(tex: Texture2D) -> void:
	_receipt_preview.texture = tex
	_receipt_preview.visible = tex != null


