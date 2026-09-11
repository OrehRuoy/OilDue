extends Control

@onready var _status: Label = %StatusLabel
@onready var _price: Label = %Price

var _busy := false


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
	if _busy:
		return
	_apply_price()


func _apply_price() -> void:
	if not Purchase._ios_storekit():
		_show_price(Purchase.localized_price())
		%BuyButton.disabled = false
		return
	var live := Purchase.localized_price()
	if live != "":
		_show_price(live)
		%BuyButton.disabled = false
		if _status.text == "Loading price…":
			_status.text = ""
		return
	_show_loading_price()
	%BuyButton.disabled = true
	var err := Purchase.last_products_error.strip_edges()
	if err != "":
		_status.text = err
	else:
		_status.text = "Loading price…"


func _show_loading_price() -> void:
	_price.text = "…"
	%BuyButton.text = "Unlock Oil Due"


func _show_price(price: String) -> void:
	_price.text = price
	%BuyButton.text = "Unlock Oil Due — %s" % price


func _on_buy_pressed() -> void:
	if _busy:
		return
	if Purchase._ios_storekit() and Purchase.localized_price() == "":
		_status.text = Purchase.last_products_error if Purchase.last_products_error != "" else "Loading price…"
		return
	_busy = true
	%BuyButton.disabled = true
	_status.text = "Contacting the App Store…" if Purchase._ios_storekit() else ""
	Purchase.buy()
	if GarageStore.is_unlocked():
		_go_back()
		return
	if Purchase._ios_storekit():
		return
	_busy = false
	%BuyButton.disabled = false
	_status.text = Purchase.last_message if Purchase.last_message != "" else "Purchase didn't complete."


func _on_restore_pressed() -> void:
	if _busy:
		return
	_busy = true
	_status.text = "Restoring…" if Purchase._ios_storekit() else ""
	Purchase.restore()
	if GarageStore.is_unlocked():
		_go_back()
		return
	if Purchase._ios_storekit():
		return
	_busy = false
	_status.text = Purchase.last_message if Purchase.last_message != "" else "Nothing to restore."


func _on_purchase_finished(ok: bool) -> void:
	_busy = false
	if ok and GarageStore.is_unlocked():
		_go_back()
		return
	_apply_price()
	_status.text = Purchase.last_message if Purchase.last_message != "" else "Purchase didn't complete."


func _on_back_pressed() -> void:
	_go_back()


func _go_back() -> void:
	var path := GarageStore.unlock_back_scene.strip_edges()
	if path == "" or not ResourceLoader.exists(path):
		path = "res://scenes/garage.tscn"
	GarageStore.unlock_back_scene = "res://scenes/garage.tscn"
	get_tree().change_scene_to_file(path)
