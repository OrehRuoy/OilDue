extends Control

@onready var _status: Label = %StatusLabel


func _ready() -> void:
	_status.text = ""
	%RestoreButton.pressed.connect(_on_restore_pressed)
	%Back.pressed.connect(_on_back_pressed)


func _on_restore_pressed() -> void:
	_status.text = "StoreKit not wired yet."


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/vehicle_edit.tscn")
