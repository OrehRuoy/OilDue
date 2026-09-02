extends Control

@onready var _status: Label = %StatusLabel


func _ready() -> void:
	_status.text = ""
	%BuyButton.pressed.connect(_on_buy_pressed)
	%RestoreButton.pressed.connect(_on_restore_pressed)
	%Back.pressed.connect(_on_back_pressed)
	if not Purchase.purchase_finished.is_connected(_on_purchase_finished):
		Purchase.purchase_finished.connect(_on_purchase_finished)


func _on_buy_pressed() -> void:
	Purchase.buy()
	if GarageStore.is_unlocked():
		_go_back()
		return
	if Purchase._ios_storekit():
		return
	_status.text = Purchase.last_message if Purchase.last_message != "" else "Purchase didn't complete."


func _on_restore_pressed() -> void:
	Purchase.restore()
	if GarageStore.is_unlocked():
		_go_back()
		return
	if Purchase._ios_storekit():
		return
	_status.text = Purchase.last_message if Purchase.last_message != "" else "Nothing to restore."


func _on_purchase_finished(ok: bool) -> void:
	if ok and GarageStore.is_unlocked():
		_go_back()
		return
	_status.text = Purchase.last_message if Purchase.last_message != "" else "Purchase didn't complete."


func _on_back_pressed() -> void:
	_go_back()


func _go_back() -> void:
	var path := GarageStore.unlock_back_scene.strip_edges()
	if path == "" or not ResourceLoader.exists(path):
		path = "res://scenes/garage.tscn"
	GarageStore.unlock_back_scene = "res://scenes/garage.tscn"
	get_tree().change_scene_to_file(path)
