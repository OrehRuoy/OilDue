extends Control

const ServiceIcons = preload("res://scripts/service_icons.gd")
const PanScroll = preload("res://scripts/pan_scroll.gd")
const ConfirmSheet = preload("res://scripts/confirm_sheet.gd")
const DueMath = preload("res://scripts/due_math.gd")
const PickSheet = preload("res://scripts/pick_sheet.gd")
const VehicleCatalog = preload("res://scripts/vehicle_catalog.gd")

@onready var _year_edit: LineEdit = %YearEdit
@onready var _make_edit: LineEdit = %MakeEdit
@onready var _model_edit: LineEdit = %ModelEdit
@onready var _name_edit: LineEdit = %NameEdit
@onready var _vin_edit: LineEdit = %VinEdit
@onready var _plate_edit: LineEdit = %PlateEdit
@onready var _tire_edit: LineEdit = %TireEdit
@onready var _filter_edit: LineEdit = %FilterEdit
@onready var _odometer_edit: LineEdit = %OdometerEdit
@onready var _error: Label = %ErrorLabel
@onready var _photo_hole: Panel = %PhotoHole
@onready var _photo_sheet: ColorRect = %PhotoSheet
@onready var _photo_slot: Panel = %PhotoSlot
@onready var _placeholder: Control = %PlaceholderRow
@onready var _place_hole: Panel = %PlaceHole


func _ready() -> void:
	var vehicle := _target_vehicle()
	if GarageStore.selected_vehicle_id == "":
		GarageStore.selected_vehicle_id = str(vehicle.get("id", ""))
	_year_edit.text = str(_as_int(vehicle.get("year"), 0))
	_make_edit.text = str(vehicle.get("make", ""))
	_model_edit.text = str(vehicle.get("model", ""))
	_name_edit.text = str(vehicle.get("name", ""))
	_vin_edit.text = str(vehicle.get("vin", ""))
	_plate_edit.text = str(vehicle.get("plate", ""))
	_tire_edit.text = str(vehicle.get("tire_size", ""))
	_filter_edit.text = str(vehicle.get("oil_filter", ""))
	_odometer_edit.text = DueMath.format_miles(int(vehicle.get("odometer", 0)))
	_error.text = ""
	_show_photo(str(vehicle.get("photo", "")))
	_photo_sheet.visible = false
	%SaveButton.pressed.connect(_on_save_pressed)
	%AddCarButton.pressed.connect(_on_add_car_pressed)
	_arm_make_model_fields()
	PanScroll.wire_fields($Margin/PageHost/PageScroll)
	PanScroll.wire($Margin/PageHost/PageScroll/Column/FormGroup, func() -> void: pass)
	%ArchiveButton.pressed.connect(_on_archive_pressed)
	%PhotoSlot.gui_input.connect(_on_photo_gui_input)
	%PlaceholderRow.gui_input.connect(_on_photo_gui_input)
	_odometer_edit.focus_exited.connect(_on_odometer_focus_exited)
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


func _target_vehicle() -> Dictionary:
	var vehicle := GarageStore.vehicle_by_id(GarageStore.selected_vehicle_id)
	if vehicle.is_empty():
		vehicle = GarageStore.primary_vehicle()
	return vehicle


func _vehicle_display_name(vehicle: Dictionary) -> String:
	var stored := str(vehicle.get("name", "")).strip_edges()
	if stored != "":
		return stored
	return _vehicle_spec_line(vehicle)


func _vehicle_spec_line(vehicle: Dictionary) -> String:
	var year := _as_int(vehicle.get("year"), 0)
	var make := str(vehicle.get("make", "")).strip_edges()
	var model := str(vehicle.get("model", "")).strip_edges()
	var parts: PackedStringArray = PackedStringArray()
	if year > 0:
		parts.append(str(year))
	if make != "":
		parts.append(make)
	if model != "":
		parts.append(model)
	return " ".join(parts)


func _as_int(value: Variant, fallback: int) -> int:
	if value == null:
		return fallback
	var value_type := typeof(value)
	if value_type == TYPE_INT or value_type == TYPE_FLOAT:
		return int(value)
	var raw := str(value).strip_edges()
	if raw.is_valid_int():
		return int(raw)
	return fallback


func _show_photo(filename: String) -> void:
	for child in _photo_hole.get_children():
		_photo_hole.remove_child(child)
		child.queue_free()
	for child in _place_hole.get_children():
		_place_hole.remove_child(child)
		child.queue_free()
	var vehicle := _target_vehicle()
	var tex := PhotoService.load_texture(filename)
	if tex != null:
		_photo_slot.visible = true
		_placeholder.visible = false
		var pic := TextureRect.new()
		pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pic.modulate = Color.WHITE
		pic.texture = tex
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_photo_hole.add_child(pic)
		var fade := TextureRect.new()
		fade.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		fade.anchor_top = 0.6
		fade.offset_top = 0
		fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		fade.stretch_mode = TextureRect.STRETCH_SCALE
		fade.texture = _hero_fade_texture()
		_photo_hole.add_child(fade)
		var labels := VBoxContainer.new()
		labels.mouse_filter = Control.MOUSE_FILTER_IGNORE
		labels.add_theme_constant_override("separation", 2)
		labels.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		labels.anchor_top = 1.0
		labels.offset_left = 12.0
		labels.offset_right = -12.0
		labels.offset_top = -72.0
		labels.offset_bottom = -12.0
		var nick := Label.new()
		nick.text = _vehicle_display_name(vehicle)
		nick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		nick.add_theme_color_override("font_color", Color("#F4EFE6"))
		nick.add_theme_font_size_override("font_size", 24)
		var spec := Label.new()
		spec.text = _vehicle_spec_line(vehicle)
		spec.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spec.add_theme_color_override("font_color", Color("#C8C2B8"))
		spec.add_theme_font_size_override("font_size", 14)
		labels.add_child(nick)
		labels.add_child(spec)
		_photo_hole.add_child(labels)
		return
	_photo_slot.visible = false
	_placeholder.visible = true
	%PlaceNick.text = _vehicle_display_name(vehicle)
	%PlaceSpec.text = _vehicle_spec_line(vehicle)
	var wrap := CenterContainer.new()
	wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ServiceIcons.CAR != null:
		var glyph := TextureRect.new()
		glyph.texture = ServiceIcons.CAR
		glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		glyph.custom_minimum_size = Vector2(40, 40)
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wrap.add_child(glyph)
	_place_hole.add_child(wrap)


func _hero_fade_texture() -> GradientTexture2D:
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0))
	grad.set_color(1, Color(0, 0, 0, 0.55))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_LINEAR
	tex.fill_from = Vector2(0.5, 0.0)
	tex.fill_to = Vector2(0.5, 1.0)
	tex.width = 16
	tex.height = 128
	return tex


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
	var miles_raw := _odometer_edit.text.strip_edges().replace(",", "")
	if miles_raw != "" and not miles_raw.is_valid_int():
		_error.text = "Enter miles as a whole number."
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
	if miles_raw.is_valid_int():
		GarageStore.set_odometer(int(miles_raw))
	get_tree().change_scene_to_file("res://scenes/garage.tscn")


func _on_odometer_focus_exited() -> void:
	var raw := _odometer_edit.text.strip_edges().replace(",", "")
	if raw.is_valid_int():
		_odometer_edit.text = DueMath.format_miles(int(raw))


func _on_add_car_pressed() -> void:
	if GarageStore.is_unlocked() or GarageStore.vehicles_list().size() == 0:
		get_tree().change_scene_to_file("res://scenes/vehicle_add.tscn")
		return
	_open_unlock()


func _open_unlock() -> void:
	GarageStore.unlock_back_scene = "res://scenes/vehicle_edit.tscn"
	get_tree().change_scene_to_file("res://scenes/unlock.tscn")


func _on_archive_pressed() -> void:
	if not GarageStore.is_unlocked():
		_open_unlock()
		return
	var vehicle := _target_vehicle()
	var nick := _vehicle_display_name(vehicle)
	if nick == "":
		nick = "this car"
	ConfirmSheet.present(
		self,
		"Archive this car?",
		"Hide %s from the garage. History stays." % nick,
		"Keep",
		"Archive",
		_on_archive_confirm
	)


func _on_archive_confirm() -> void:
	var vehicle := _target_vehicle()
	var vehicle_id := str(vehicle.get("id", "")).strip_edges()
	if vehicle_id == "":
		return
	GarageStore.set_archived(vehicle_id, true)
	get_tree().change_scene_to_file("res://scenes/garage.tscn")
