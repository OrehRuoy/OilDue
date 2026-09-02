extends Control

const PanScroll = preload("res://scripts/pan_scroll.gd")
const DueMath = preload("res://scripts/due_math.gd")

@onready var _year_edit: LineEdit = %YearEdit
@onready var _make_edit: LineEdit = %MakeEdit
@onready var _model_edit: LineEdit = %ModelEdit
@onready var _name_edit: LineEdit = %NameEdit
@onready var _miles_edit: LineEdit = %OdometerEdit
@onready var _error: Label = %ErrorLabel


func _ready() -> void:
	_error.text = ""
	%AddButton.pressed.connect(_on_add_pressed)
	%Back.pressed.connect(_on_back_pressed)
	_miles_edit.focus_exited.connect(_on_miles_focus_exited)
	PanScroll.wire_fields($Margin/PageHost)
	PanScroll.wire($Margin/PageHost/Column/FormGroup, func() -> void: pass)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/garage.tscn")


func _on_miles_focus_exited() -> void:
	var raw := _miles_edit.text.strip_edges().replace(",", "")
	if raw.is_valid_int():
		_miles_edit.text = DueMath.format_miles(int(raw))


func _on_add_pressed() -> void:
	_error.text = ""
	var year_raw := _year_edit.text.strip_edges()
	if not year_raw.is_valid_int():
		_error.text = "Enter year as a whole number."
		return
	var make_s := _make_edit.text.strip_edges()
	var model_s := _model_edit.text.strip_edges()
	var name_s := _name_edit.text.strip_edges()
	if make_s == "" and model_s == "" and name_s == "":
		_error.text = "Enter make, model, or a name."
		return
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
	if not GarageStore.add_vehicle(int(year_raw), make_s, model_s, name_s, miles):
		_error.text = "Couldn't add this car."
		return
	get_tree().change_scene_to_file("res://scenes/garage.tscn")
