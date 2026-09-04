extends Control

@onready var _status: Label = %StatusLabel
@onready var _price: Label = %Price


func _ready() -> void:
	_status.text = ""
	%BuyButton.pressed.connect(_on_buy_pressed)
	%RestoreButton.pressed.connect(_on_restore_pressed)
	%Back.pressed.connect(_on_back_pressed)
	if not Purchase.purchase_finished.is_connected(_on_purchase_finished):
		Purchase.purchase_finished.connect(_on_purchase_finished)
	if not Purchase.price_updated.is_connected(_on_price_updated):
		Purchase.price_updated.connect(_on_price_updated)
	_apply_price()


func _exit_tree() -> void:
	if Purchase.price_updated.is_connected(_on_price_updated):
		Purchase.price_updated.disconnect(_on_price_updated)
	if Purchase.purchase_finished.is_connected(_on_purchase_finished):
		Purchase.purchase_finished.disconnect(_on_purchase_finished)


func _on_price_updated(_price: String) -> void:
	_apply_price()


func _apply_price() -> void:
	if Purchase._ios_storekit():
		var live := Purchase.localized_price()
		if live == "":
			_show_loading_price()
		else:
			_show_price(live)
		return
	_show_price(Purchase.localized_price())


func _show_loading_price() -> void:
	_price.text = "…"
	%BuyButton.text = "Unlock Oil Due"


func _show_price(price: String) -> void:
	_price.text = price
	%BuyButton.text = "Unlock Oil Due — %s" % price


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
