extends Control

const ServiceIcons = preload("res://scripts/service_icons.gd")

@onready var _year_edit: LineEdit = %YearEdit
@onready var _make_edit: LineEdit = %MakeEdit
@onready var _model_edit: LineEdit = %ModelEdit
@onready var _name_edit: LineEdit = %NameEdit
@onready var _vin_edit: LineEdit = %VinEdit
@onready var _plate_edit: LineEdit = %PlateEdit
@onready var _tire_edit: LineEdit = %TireEdit
@onready var _filter_edit: LineEdit = %FilterEdit
@onready var _error: Label = %ErrorLabel
@onready var _photo_rect: TextureRect = %PhotoRect
@onready var _nick: Label = %NickLabel
@onready var _photo_sheet: ColorRect = %PhotoSheet


func _ready() -> void:
	var vehicle := _target_vehicle()
	if GarageStore.selected_vehicle_id == "":
		GarageStore.selected_vehicle_id = str(vehicle.get("id", ""))
	_year_edit.text = str(int(vehicle.get("year", 0)))
	_make_edit.text = str(vehicle.get("make", ""))
	_model_edit.text = str(vehicle.get("model", ""))
	_name_edit.text = str(vehicle.get("name", ""))
	_vin_edit.text = str(vehicle.get("vin", ""))
	_plate_edit.text = str(vehicle.get("plate", ""))
	_tire_edit.text = str(vehicle.get("tire_size", ""))
	_filter_edit.text = str(vehicle.get("oil_filter", ""))
	_error.text = ""
	_nick.text = _vehicle_display_name(vehicle)
	_show_photo(str(vehicle.get("photo", "")))
	_photo_sheet.visible = false
	%SaveButton.pressed.connect(_on_save_pressed)
	%AddCarButton.pressed.connect(_on_add_car_pressed)
	%PhotoSlot.gui_input.connect(_on_photo_gui_input)
	%ChoosePhoto.pressed.connect(_on_choose_photo)
	%TakePhoto.pressed.connect(_on_take_photo)
	%RemovePhoto.pressed.connect(_on_remove_photo)
	%PhotoCancel.pressed.connect(_close_sheet)
	_photo_sheet.gui_input.connect(_on_sheet_gui_input)
	PhotoService.picked.connect(_on_photo_picked)
	PhotoService.failed.connect(_on_photo_failed)


func _exit_tree() -> void:
	if PhotoService.picked.is_connected(_on_photo_picked):
		PhotoService.picked.disconnect(_on_photo_picked)
	if PhotoService.failed.is_connected(_on_photo_failed):
		PhotoService.failed.disconnect(_on_photo_failed)


func _target_vehicle() -> Dictionary:
	var vehicle := GarageStore.vehicle_by_id(GarageStore.selected_vehicle_id)
	if vehicle.is_empty():
		vehicle = GarageStore.primary_vehicle()
	return vehicle


func _vehicle_display_name(vehicle: Dictionary) -> String:
	var stored := str(vehicle.get("name", "")).strip_edges()
	if stored != "":
		return stored
	return ("%s %s %s" % [
		vehicle.get("year", ""),
		vehicle.get("make", ""),
		vehicle.get("model", ""),
	]).strip_edges()


func _show_photo(filename: String) -> void:
	var tex := PhotoService.load_texture(filename)
	if tex != null:
		_photo_rect.texture = tex
		_photo_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_photo_rect.modulate = Color.WHITE
	else:
		_photo_rect.texture = ServiceIcons.CAR
		_photo_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_photo_rect.modulate = Color.WHITE


func _open_sheet() -> void:
	_error.text = ""
	_photo_sheet.visible = true


func _close_sheet() -> void:
	_photo_sheet.visible = false


func _on_photo_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			_open_sheet()
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_open_sheet()


func _on_sheet_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			_close_sheet()
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_close_sheet()


func _on_choose_photo() -> void:
	_close_sheet()
	PhotoService.pick_library()


func _on_take_photo() -> void:
	_close_sheet()
	PhotoService.pick_camera()


func _on_remove_photo() -> void:
	_close_sheet()
	GarageStore.set_vehicle_photo("")
	_show_photo("")


func _on_photo_picked(src_path: String) -> void:
	var vehicle := _target_vehicle()
	var vehicle_id := str(vehicle.get("id", "")).strip_edges()
	if vehicle_id == "":
		_error.text = "Couldn't read that photo."
		return
	var dest := "v_%s.jpg" % vehicle_id
	if not PhotoService.save_jpeg(src_path, dest):
		_error.text = "Couldn't read that photo."
		return
	GarageStore.set_vehicle_photo(dest)
	_show_photo(dest)


func _on_photo_failed(_message: String) -> void:
	_error.text = "Couldn't read that photo."


func _on_save_pressed() -> void:
	_error.text = ""
	var year_raw := _year_edit.text.strip_edges()
	if not year_raw.is_valid_int():
		_error.text = "Enter year as a whole number."
		return
	GarageStore.update_primary_vehicle({
		"year": int(year_raw),
		"make": _make_edit.text.strip_edges(),
		"model": _model_edit.text.strip_edges(),
		"name": _name_edit.text.strip_edges(),
		"vin": _vin_edit.text.strip_edges(),
		"plate": _plate_edit.text.strip_edges(),
		"tire_size": _tire_edit.text.strip_edges(),
		"oil_filter": _filter_edit.text.strip_edges(),
	})
	get_tree().change_scene_to_file("res://scenes/garage.tscn")


func _on_add_car_pressed() -> void:
	if GarageStore.is_unlocked() or GarageStore.vehicles_list().size() == 0:
		get_tree().change_scene_to_file("res://scenes/vehicle_add.tscn")
		return
	get_tree().change_scene_to_file("res://scenes/unlock.tscn")
