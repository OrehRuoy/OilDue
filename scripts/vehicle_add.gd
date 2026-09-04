extends Control

const PanScroll = preload("res://scripts/pan_scroll.gd")
const DueMath = preload("res://scripts/due_math.gd")
const PickSheet = preload("res://scripts/pick_sheet.gd")
const VehicleCatalog = preload("res://scripts/vehicle_catalog.gd")
const ServiceIcons = preload("res://scripts/service_icons.gd")

@onready var _year_edit: LineEdit = %YearEdit
@onready var _make_edit: LineEdit = %MakeEdit
@onready var _model_edit: LineEdit = %ModelEdit
@onready var _name_edit: LineEdit = %NameEdit
@onready var _miles_edit: LineEdit = %OdometerEdit
@onready var _error: Label = %ErrorLabel
@onready var _photo_hole: Panel = %PhotoHole
@onready var _photo_sheet: ColorRect = %PhotoSheet

var _first_run := false
var _pending_photo := ""


func _ready() -> void:
	_first_run = GarageStore.vehicles_list().is_empty()
	_error.text = ""
	_photo_sheet.visible = false
	_apply_first_run_chrome()
	_fill_photo_hole("")
	%AddButton.pressed.connect(_on_add_pressed)
	%Back.pressed.connect(_on_back_pressed)
	_miles_edit.focus_exited.connect(_on_miles_focus_exited)
	_arm_make_model_fields()
	PanScroll.wire_fields($Margin/PageHost/PageScroll)
	PanScroll.wire($Margin/PageHost/PageScroll/Column/FormGroup, func() -> void: pass)
	%AddPhoto.pressed.connect(_open_photo_sheet)
	%ChoosePhoto.pressed.connect(_on_choose_photo)
	%TakePhoto.pressed.connect(_on_take_photo)
	%RemovePhoto.pressed.connect(_on_remove_photo)
	%PhotoCancel.pressed.connect(_close_photo_sheet)
	_photo_sheet.gui_input.connect(_on_photo_sheet_gui_input)
	PhotoService.picked.connect(_on_photo_picked)
	PhotoService.failed.connect(_on_photo_failed)


func _exit_tree() -> void:
	if PhotoService.picked.is_connected(_on_photo_picked):
		PhotoService.picked.disconnect(_on_photo_picked)
	if PhotoService.failed.is_connected(_on_photo_failed):
		PhotoService.failed.disconnect(_on_photo_failed)


func _apply_first_run_chrome() -> void:
	%Back.visible = not _first_run
	%Subline.visible = _first_run
	if _first_run:
		%Title.text = "Welcome to Oil Due"
		%AddButton.text = "Save car"
	else:
		%Title.text = "Add car"
		%AddButton.text = "Add car"


func _arm_make_model_fields() -> void:
	_lock_pick_field(_make_edit)
	_lock_pick_field(_model_edit)
	PanScroll.wire(_make_edit, _open_make_pick)
	PanScroll.wire(_model_edit, _open_model_pick)


func _lock_pick_field(field: LineEdit) -> void:
	field.editable = false
	field.focus_mode = Control.FOCUS_NONE
	field.set_meta("skip_pan_focus", true)


func _open_make_pick() -> void:
	PickSheet.present(self, "Make", VehicleCatalog.makes(), _make_edit.text, _on_make_picked)


func _open_model_pick() -> void:
	var make_s := _make_edit.text.strip_edges()
	if make_s == "":
		PickSheet.present_notice(self, "Model", "Pick make first")
		return
	PickSheet.present(self, "Model", VehicleCatalog.models(make_s), _model_edit.text, _on_model_picked)


func _on_make_picked(value: String) -> void:
	_make_edit.text = value.strip_edges()
	if not VehicleCatalog.has_model(_make_edit.text, _model_edit.text):
		_model_edit.text = ""


func _on_model_picked(value: String) -> void:
	_model_edit.text = value.strip_edges()


func _on_back_pressed() -> void:
	if _first_run:
		return
	get_tree().change_scene_to_file("res://scenes/garage.tscn")


func _on_miles_focus_exited() -> void:
	var raw := _miles_edit.text.strip_edges().replace(",", "")
	if raw.is_valid_int():
		_miles_edit.text = DueMath.format_miles(int(raw))


func _fill_photo_hole(src_path: String) -> void:
	for child in _photo_hole.get_children():
		_photo_hole.remove_child(child)
		child.queue_free()
	var tex: Texture2D = null
	if src_path.strip_edges() != "":
		var img := Image.load_from_file(src_path)
		if img != null and not img.is_empty() and img.get_width() >= 1:
			tex = ImageTexture.create_from_image(img)
	if tex == null and ServiceIcons.CAR != null:
		tex = ServiceIcons.CAR
	if tex == null:
		return
	var pic := TextureRect.new()
	pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.texture = tex
	_photo_hole.add_child(pic)


func _open_photo_sheet() -> void:
	PickSheet.dismiss_keyboard()
	_error.text = ""
	_photo_sheet.visible = true


func _close_photo_sheet() -> void:
	_photo_sheet.visible = false


func _on_photo_sheet_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			_close_photo_sheet()
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_close_photo_sheet()


func _on_choose_photo() -> void:
	_close_photo_sheet()
	PhotoService.pick_library()


func _on_take_photo() -> void:
	_close_photo_sheet()
	PhotoService.pick_camera()


func _on_remove_photo() -> void:
	_close_photo_sheet()
	_pending_photo = ""
	_fill_photo_hole("")


func _on_photo_picked(src_path: String) -> void:
	var path := src_path.strip_edges()
	if path == "":
		_error.text = "Couldn't read that photo."
		return
	_pending_photo = path
	_fill_photo_hole(path)
	%AddPhoto.text = "Change photo"


func _on_photo_failed(_message: String) -> void:
	_error.text = "Couldn't read that photo."


func _on_add_pressed() -> void:
	_error.text = ""
	var make_s := _make_edit.text.strip_edges()
	var model_s := _model_edit.text.strip_edges()
	if make_s == "" or model_s == "":
		_error.text = "Pick make and model."
		return
	var year_raw := _year_edit.text.strip_edges()
	var year := 0
	if year_raw != "":
		if not year_raw.is_valid_int():
			_error.text = "Enter year as a whole number."
			return
		year = int(year_raw)
	var name_s := _name_edit.text.strip_edges()
	var miles_raw := _miles_edit.text.strip_edges().replace(",", "")
	var miles := 0
	if miles_raw == "":
		miles = 0
	elif not miles_raw.is_valid_int():
		_error.text = "Enter miles as a whole number."
		return
	else:
		miles = int(miles_raw)
		if miles < 0:
			_error.text = "Miles cannot be negative."
			return
	var with_oil := not _first_run
	if not GarageStore.add_vehicle(year, make_s, model_s, name_s, miles, with_oil):
		_error.text = "Couldn't add this car."
		return
	if _pending_photo != "":
		var vehicle_id := GarageStore.selected_vehicle_id.strip_edges()
		var dest := "v_%s.jpg" % vehicle_id
		if PhotoService.save_jpeg(_pending_photo, dest):
			GarageStore.set_vehicle_photo(dest)
	get_tree().change_scene_to_file("res://scenes/garage.tscn")
