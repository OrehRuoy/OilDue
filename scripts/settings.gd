extends Control

const CHEVRON := preload("res://assets/icons/chevron_right.png")
const PanScroll = preload("res://scripts/pan_scroll.gd")
const CsvImport = preload("res://scripts/csv_import.gd")
const BackupZip = preload("res://scripts/backup_zip.gd")
const ConfirmSheet = preload("res://scripts/confirm_sheet.gd")
const LEAD_VALUES := [3, 7, 14]
const VMT_SAMPLE := "res://tests/fixtures/vmt-maintenance-sample.csv"
const EXPORT_CSV_PATH := "user://oil-due-export.csv"
const BACKUP_ZIP_PATH := "user://oil-due-backup.zip"
const FILES_HINT := "Find it in Files, On My iPhone, Oil Due."

enum DialogMode { SAVE_CSV, SAVE_ZIP, OPEN_ZIP }
enum PickKind { CSV, ZIP }

@onready var _lead_option: OptionButton = %LeadOption
@onready var _version: Label = %VersionLabel
@onready var _status: Label = %StatusLabel
@onready var _import_dialog: FileDialog = %ImportDialog
@onready var _io_dialog: FileDialog = %IoDialog
@onready var _file_sheet: ColorRect = %FilePickSheet
@onready var _file_rows: VBoxContainer = %FilePickRows
@onready var _file_empty: Label = %FilePickEmpty
@onready var _file_scroll: ScrollContainer = %FilePickScroll

var _dialog_mode := DialogMode.SAVE_CSV
var _pick_kind := PickKind.CSV


func _ready() -> void:
	_lead_option.clear()
	for n in LEAD_VALUES:
		_lead_option.add_item(str(n))
	var current := int(GarageStore.data.get("notify_lead_days", 7))
	var idx := LEAD_VALUES.find(current)
	if idx < 0:
		idx = LEAD_VALUES.find(7)
	_lead_option.select(idx)
	_lead_option.item_selected.connect(_on_lead_selected)
	%HelpButton.pressed.connect(_on_help_pressed)
	%RestorePurchasesButton.pressed.connect(_on_restore_purchases_pressed)
	%ImportCsvButton.pressed.connect(_on_import_csv_pressed)
	%ImportSampleButton.pressed.connect(_on_import_sample_pressed)
	%LoadDemoButton.pressed.connect(_on_load_demo_pressed)
	%TestNotifyButton.pressed.connect(_on_test_notify_pressed)
	%ResetFirstRunButton.pressed.connect(_on_reset_first_run_pressed)
	%ExportCsvButton.pressed.connect(_on_export_csv_pressed)
	%BackupZipButton.pressed.connect(_on_backup_zip_pressed)
	%RestoreZipButton.pressed.connect(_on_restore_zip_pressed)
	%RestoreLastButton.pressed.connect(_on_restore_last_pressed)
	_import_dialog.file_selected.connect(_on_csv_chosen)
	_io_dialog.file_selected.connect(_on_io_chosen)
	_file_sheet.visible = false
	%FilePickCancel.pressed.connect(_close_file_pick)
	_file_sheet.gui_input.connect(_on_file_sheet_gui_input)
	var version := str(ProjectSettings.get_setting("application/config/version", "0.1.0"))
	if version.strip_edges() == "":
		version = "0.1.0"
	_version.text = "Version %s" % version
	_status.text = ""
	_setup_unlock_check()
	_fill_archived()
	if not NotifyService.permission_resolved.is_connected(_on_notify_permission):
		NotifyService.permission_resolved.connect(_on_notify_permission)


func _on_lead_selected(index: int) -> void:
	if index < 0 or index >= LEAD_VALUES.size():
		return
	GarageStore.set_notify_lead_days(int(LEAD_VALUES[index]))
	NotifyService.reschedule()


func _on_help_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/help.tscn")


func _on_restore_purchases_pressed() -> void:
	Purchase.restore()
	if GarageStore.is_unlocked():
		_status.text = "Purchases restored."
	else:
		_status.text = Purchase.last_message if Purchase.last_message != "" else "Nothing to restore."
	_setup_unlock_check()
	_fill_archived()


func _fill_archived() -> void:
	var rows: VBoxContainer = %ArchiveRows
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	var archived := GarageStore.archived_list()
	%GroupArchived.visible = archived.size() > 0
	for item in archived:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var vehicle: Dictionary = item
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 52)
		btn.theme_type_variation = &"SettingsRow"
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.text = _vehicle_display_name(vehicle)
		btn.icon = CHEVRON
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		btn.expand_icon = true
		var vehicle_id := str(vehicle.get("id", ""))
		PanScroll.wire(btn, _on_archived_pressed.bind(vehicle_id))
		rows.add_child(btn)


func _vehicle_display_name(vehicle: Dictionary) -> String:
	var stored := str(vehicle.get("name", "")).strip_edges()
	if stored != "":
		return stored
	return ("%s %s %s" % [
		vehicle.get("year", ""),
		vehicle.get("make", ""),
		vehicle.get("model", ""),
	]).strip_edges()


func _on_archived_pressed(vehicle_id: String) -> void:
	if not GarageStore.is_unlocked():
		GarageStore.unlock_back_scene = "res://scenes/settings.tscn"
		get_tree().change_scene_to_file("res://scenes/unlock.tscn")
		return
	GarageStore.set_archived(vehicle_id, false)
	_fill_archived()
	_status.text = "Restored to garage."


func _on_import_csv_pressed() -> void:
	if _on_ios():
		_open_file_pick(PickKind.CSV)
		return
	_import_dialog.popup_centered()


func _on_load_demo_pressed() -> void:
	GarageStore.load_demo()
	_status.text = "Demo car added."
	_fill_archived()


func _on_test_notify_pressed() -> void:
	if not OS.is_debug_build():
		return
	_status.text = NotifyService.schedule_test(60)


func _on_notify_permission(ok: bool) -> void:
	if _status.text != "Allow notifications to send the test.":
		return
	if ok:
		_status.text = "Test notification in 1 min. You can kill the app."
	else:
		_status.text = "Turn on Notifications in iPhone Settings → Oil Due"


func _on_reset_first_run_pressed() -> void:
	if not OS.is_debug_build():
		return
	ConfirmSheet.present(
		self,
		"Reset to first run?",
		"Clears cars in this editor copy so Welcome to Oil Due shows again. Release builds never see this.",
		"Keep",
		"Reset",
		_on_reset_first_run_confirm
	)


func _on_reset_first_run_confirm() -> void:
	if not OS.is_debug_build():
		return
	GarageStore.debug_reset_first_run()
	get_tree().change_scene_to_file("res://scenes/vehicle_add.tscn")


func _on_import_sample_pressed() -> void:
	_open_preview(CsvImport.parse_file(VMT_SAMPLE))


func _on_csv_chosen(path: String) -> void:
	_open_preview(CsvImport.parse_file(path))


func _open_preview(parsed: Dictionary) -> void:
	GarageStore.pending_import = parsed
	get_tree().change_scene_to_file("res://scenes/import_preview.tscn")


func _on_export_csv_pressed() -> void:
	if _on_ios():
		var stamped := "user://oil-due-export-%s.csv" % _file_stamp()
		if not GarageStore.write_export_csv(stamped):
			_status.text = "Couldn't save the export."
			return
		GarageStore.write_export_csv(EXPORT_CSV_PATH)
		_status.text = "Export saved. %s" % FILES_HINT
		return
	if GarageStore.write_export_csv(EXPORT_CSV_PATH):
		_status.text = "Export saved. %s" % FILES_HINT
	else:
		_status.text = "Couldn't save the export."
		return
	_dialog_mode = DialogMode.SAVE_CSV
	_io_dialog.title = "Export CSV"
	_io_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_io_dialog.filters = PackedStringArray(["*.csv ; CSV"])
	_io_dialog.popup_centered()


func _on_backup_zip_pressed() -> void:
	if _on_ios():
		var stamped := "user://oil-due-backup-%s.zip" % _file_stamp()
		if not GarageStore.write_backup_zip(stamped):
			_status.text = "Couldn't save the backup."
			return
		GarageStore.write_backup_zip(BACKUP_ZIP_PATH)
		_status.text = "Backup saved. %s" % FILES_HINT
		return
	if GarageStore.write_backup_zip(BACKUP_ZIP_PATH):
		_status.text = "Backup saved. %s" % FILES_HINT
	else:
		_status.text = "Couldn't save the backup."
		return
	_dialog_mode = DialogMode.SAVE_ZIP
	_io_dialog.title = "Backup zip"
	_io_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_io_dialog.filters = PackedStringArray(["*.zip ; ZIP"])
	_io_dialog.popup_centered()


func _on_restore_zip_pressed() -> void:
	if _on_ios():
		_open_file_pick(PickKind.ZIP)
		return
	_dialog_mode = DialogMode.OPEN_ZIP
	_io_dialog.title = "Restore zip"
	_io_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_io_dialog.filters = PackedStringArray(["*.zip ; ZIP"])
	_io_dialog.popup_centered()


func _on_restore_last_pressed() -> void:
	if not FileAccess.file_exists(BACKUP_ZIP_PATH):
		GarageStore.last_backup_error = BackupZip.READ_ERROR
		_status.text = GarageStore.last_backup_error
		return
	_open_restore_confirm(BACKUP_ZIP_PATH)


func _on_io_chosen(path: String) -> void:
	if _dialog_mode == DialogMode.SAVE_CSV:
		if GarageStore.write_export_csv(path):
			_status.text = "Export saved. %s" % FILES_HINT
		return
	if _dialog_mode == DialogMode.SAVE_ZIP:
		if GarageStore.write_backup_zip(path):
			_status.text = "Backup saved. %s" % FILES_HINT
		return
	if _dialog_mode == DialogMode.OPEN_ZIP:
		_open_restore_confirm(path)


func _open_restore_confirm(path: String) -> void:
	GarageStore.pending_restore_path = path
	ConfirmSheet.present(
		self,
		"Restore backup?",
		"This replaces the garage on this phone.",
		"Keep",
		"Replace",
		_on_restore_confirmed
	)


func _on_restore_confirmed() -> void:
	var path := GarageStore.pending_restore_path
	if not GarageStore.restore_from_zip(path):
		var msg := GarageStore.last_backup_error.strip_edges()
		if msg == "":
			msg = "Couldn't read this backup. The garage on this phone was not changed."
		_status.text = msg
		GarageStore.pending_restore_path = ""
		return
	GarageStore.pending_restore_path = ""
	get_tree().change_scene_to_file("res://scenes/garage.tscn")


func _setup_unlock_check() -> void:
	var group: Control = %GroupDeveloper
	if not OS.is_debug_build():
		group.visible = false
		return
	group.visible = true
	var box := %UnlockCheck as CheckButton
	box.set_pressed_no_signal(GarageStore.is_unlocked())
	if not box.toggled.is_connected(_on_unlock_toggled):
		box.toggled.connect(_on_unlock_toggled)


func _on_unlock_toggled(pressed: bool) -> void:
	GarageStore.set_unlocked(pressed)
	NotifyService.reschedule()


func _on_ios() -> bool:
	return OS.has_feature("ios")


func _file_stamp() -> String:
	var t := Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d-%02d%02d" % [
		int(t.get("year", 0)),
		int(t.get("month", 0)),
		int(t.get("day", 0)),
		int(t.get("hour", 0)),
		int(t.get("minute", 0)),
	]


func _user_files(ext: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var dir := DirAccess.open("user://")
	if dir == null:
		return out
	var needle := ".%s" % ext.to_lower()
	for name in dir.get_files():
		var file_name := str(name)
		if file_name.to_lower().ends_with(needle):
			out.append(file_name)
	out.sort()
	return out


func _open_file_pick(kind: PickKind) -> void:
	_pick_kind = kind
	for child in _file_rows.get_children():
		_file_rows.remove_child(child)
		child.queue_free()
	var ext := "csv" if kind == PickKind.CSV else "zip"
	var names := _user_files(ext)
	_file_empty.visible = names.is_empty()
	if kind == PickKind.CSV:
		_file_empty.text = "Put a CSV in Files, On My iPhone, Oil Due."
	else:
		_file_empty.text = "Put a zip in Files, On My iPhone, Oil Due."
	_file_scroll.visible = not names.is_empty()
	_file_scroll.custom_minimum_size.y = mini(240, names.size() * 52)
	for file_name in names:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 52)
		btn.theme_type_variation = &"SettingsRow"
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.text = file_name
		btn.clip_text = true
		btn.pressed.connect(_on_user_file_pressed.bind(file_name))
		PanScroll.wire(btn, func() -> void: pass)
		_file_rows.add_child(btn)
	_file_sheet.visible = true


func _on_user_file_pressed(file_name: String) -> void:
	_close_file_pick()
	var path := "user://%s" % file_name
	if _pick_kind == PickKind.CSV:
		_open_preview(CsvImport.parse_file(path))
		return
	_open_restore_confirm(path)


func _close_file_pick() -> void:
	_file_sheet.visible = false


func _on_file_sheet_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			_close_file_pick()
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_close_file_pick()
