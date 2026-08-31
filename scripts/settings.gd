extends Control

const CsvImport = preload("res://scripts/csv_import.gd")
const BackupZip = preload("res://scripts/backup_zip.gd")
const LEAD_VALUES := [3, 7, 14]
const VMT_SAMPLE := "res://tests/fixtures/vmt-maintenance-sample.csv"
const EXPORT_CSV_PATH := "user://oil-due-export.csv"
const BACKUP_ZIP_PATH := "user://oil-due-backup.zip"

enum DialogMode { SAVE_CSV, SAVE_ZIP, OPEN_ZIP }

@onready var _lead_option: OptionButton = %LeadOption
@onready var _version: Label = %VersionLabel
@onready var _status: Label = %StatusLabel
@onready var _import_dialog: FileDialog = %ImportDialog
@onready var _io_dialog: FileDialog = %IoDialog

var _dialog_mode := DialogMode.SAVE_CSV


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
	%ImportCsvButton.pressed.connect(_on_import_csv_pressed)
	%ImportSampleButton.pressed.connect(_on_import_sample_pressed)
	%ExportCsvButton.pressed.connect(_on_export_csv_pressed)
	%BackupZipButton.pressed.connect(_on_backup_zip_pressed)
	%RestoreZipButton.pressed.connect(_on_restore_zip_pressed)
	%RestoreLastButton.pressed.connect(_on_restore_last_pressed)
	_import_dialog.file_selected.connect(_on_csv_chosen)
	_io_dialog.file_selected.connect(_on_io_chosen)
	var version := str(ProjectSettings.get_setting("application/config/version", "0.1.0"))
	if version.strip_edges() == "":
		version = "0.1.0"
	_version.text = "Version %s" % version
	_status.text = ""
	_setup_unlock_check()


func _on_lead_selected(index: int) -> void:
	if index < 0 or index >= LEAD_VALUES.size():
		return
	GarageStore.set_notify_lead_days(int(LEAD_VALUES[index]))


func _on_help_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/help.tscn")


func _on_import_csv_pressed() -> void:
	_import_dialog.popup_centered()


func _on_import_sample_pressed() -> void:
	_open_preview(CsvImport.parse_file(VMT_SAMPLE))


func _on_csv_chosen(path: String) -> void:
	_open_preview(CsvImport.parse_file(path))


func _open_preview(parsed: Dictionary) -> void:
	GarageStore.pending_import = parsed
	get_tree().change_scene_to_file("res://scenes/import_preview.tscn")


func _on_export_csv_pressed() -> void:
	if GarageStore.write_export_csv(EXPORT_CSV_PATH):
		_status.text = "Wrote user://oil-due-export.csv"
	else:
		_status.text = "Couldn't write user://oil-due-export.csv"
		return
	_dialog_mode = DialogMode.SAVE_CSV
	_io_dialog.title = "Export CSV"
	_io_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_io_dialog.filters = PackedStringArray(["*.csv ; CSV"])
	_io_dialog.popup_centered()


func _on_backup_zip_pressed() -> void:
	if GarageStore.write_backup_zip(BACKUP_ZIP_PATH):
		_status.text = "Wrote user://oil-due-backup.zip"
	else:
		_status.text = "Couldn't write user://oil-due-backup.zip"
		return
	_dialog_mode = DialogMode.SAVE_ZIP
	_io_dialog.title = "Backup zip"
	_io_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_io_dialog.filters = PackedStringArray(["*.zip ; ZIP"])
	_io_dialog.popup_centered()


func _on_restore_zip_pressed() -> void:
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
			_status.text = "Wrote user://oil-due-export.csv"
		return
	if _dialog_mode == DialogMode.SAVE_ZIP:
		if GarageStore.write_backup_zip(path):
			_status.text = "Wrote user://oil-due-backup.zip"
		return
	if _dialog_mode == DialogMode.OPEN_ZIP:
		_open_restore_confirm(path)


func _open_restore_confirm(path: String) -> void:
	GarageStore.pending_restore_path = path
	get_tree().change_scene_to_file("res://scenes/restore_confirm.tscn")


func _setup_unlock_check() -> void:
	var group: Control = %GroupDeveloper
	if not OS.has_feature("debug"):
		group.visible = false
		return
	group.visible = true
	var box := %UnlockCheck as CheckButton
	box.set_pressed_no_signal(GarageStore.is_unlocked())
	if not box.toggled.is_connected(_on_unlock_toggled):
		box.toggled.connect(_on_unlock_toggled)


func _on_unlock_toggled(pressed: bool) -> void:
	GarageStore.set_unlocked(pressed)
