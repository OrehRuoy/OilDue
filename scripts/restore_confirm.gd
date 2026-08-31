extends Control

@onready var _error: Label = %ErrorLabel
@onready var _replace: Button = %ReplaceButton


func _ready() -> void:
	_error.text = ""
	_replace.pressed.connect(_on_replace_pressed)
	%CancelButton.pressed.connect(_on_cancel_pressed)


func _on_replace_pressed() -> void:
	var path := GarageStore.pending_restore_path
	if not GarageStore.restore_from_zip(path):
		_error.text = GarageStore.last_backup_error
		if _error.text.strip_edges() == "":
			_error.text = "Couldn't read this backup. The garage on this phone was not changed."
		return
	GarageStore.pending_restore_path = ""
	get_tree().change_scene_to_file("res://scenes/garage.tscn")


func _on_cancel_pressed() -> void:
	GarageStore.pending_restore_path = ""
	get_tree().change_scene_to_file("res://scenes/settings.tscn")
