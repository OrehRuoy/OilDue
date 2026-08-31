extends Control

@onready var _warning: Label = %WarningLabel


func _ready() -> void:
	var vehicle := GarageStore.vehicle_by_id(GarageStore.selected_vehicle_id)
	var service := GarageStore.service_by_id(vehicle, GarageStore.selected_service_id)
	var label := str(service.get("label", "")).strip_edges()
	if label == "":
		label = "this service"
	_warning.text = "This removes %s and its jobs." % label
	%RemoveButton.pressed.connect(_on_remove_pressed)
	%CancelButton.pressed.connect(_on_cancel_pressed)


func _on_remove_pressed() -> void:
	GarageStore.delete_selected_service()
	get_tree().change_scene_to_file("res://scenes/garage.tscn")


func _on_cancel_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/service_list.tscn")
