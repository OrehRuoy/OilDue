extends Node

const PRODUCT_ID := "unlock_oil_due"

signal purchase_finished(ok: bool)

var last_ok := false
var last_message := ""
var _warned_missing := false
var _store_inited := false


func _ready() -> void:
	if _ios_storekit():
		_bind_store()
	_sync_from_store()


func is_unlocked() -> bool:
	return GarageStore.is_unlocked()


func buy() -> void:
	if _ios_storekit():
		_store_buy()
		return
	_warn_missing_once()
	GarageStore.set_unlocked(true)
	NotifyService.reschedule()
	last_ok = true
	last_message = "Unlocked."


func restore() -> void:
	if _ios_storekit():
		_store_restore()
		return
	last_ok = false
	last_message = "Nothing to restore in the editor."


func _ios_storekit() -> bool:
	return OS.has_feature("ios") and (
		Engine.has_singleton("StoreKit") or Engine.has_singleton("InAppStore")
	)


func _store() -> Object:
	if Engine.has_singleton("StoreKit"):
		return Engine.get_singleton("StoreKit")
	if Engine.has_singleton("InAppStore"):
		return Engine.get_singleton("InAppStore")
	return null


func _bind_store() -> void:
	var store := _store()
	if store == null:
		return
	_connect_if_present(store, "purchase_updated", _on_native_purchase_updated)
	_connect_if_present(store, "purchase_failed", _on_native_purchase_failed)
	_connect_if_present(store, "entitlements_updated", _on_native_entitlements_updated)
	if not _store_inited and store.has_method("initialize"):
		_store_inited = true
		store.call("initialize", PRODUCT_ID)


func _connect_if_present(store: Object, signal_name: String, callable: Callable) -> void:
	if store.has_signal(signal_name) and not store.is_connected(signal_name, callable):
		store.connect(signal_name, callable)


func _sync_from_store() -> void:
	if not _ios_storekit():
		return
	var store := _store()
	if store == null:
		return
	if not _store_owned(store):
		return
	GarageStore.set_unlocked(true)
	NotifyService.reschedule()


func _store_owned(store: Object) -> bool:
	if store.has_method("has_lifetime"):
		return bool(store.call("has_lifetime"))
	if store.has_method("is_purchased"):
		return bool(store.call("is_purchased", PRODUCT_ID))
	if store.has_method("has_product"):
		return bool(store.call("has_product", PRODUCT_ID))
	return false


func _store_buy() -> void:
	var store := _store()
	last_ok = false
	last_message = "Purchase didn't complete."
	if store == null:
		return
	if store.has_method("purchase"):
		store.call("purchase", PRODUCT_ID)
	elif store.has_method("buy"):
		store.call("buy", PRODUCT_ID)
	elif store.has_method("purchase_product"):
		store.call("purchase_product", PRODUCT_ID)


func _store_restore() -> void:
	var store := _store()
	last_ok = false
	last_message = "Nothing to restore."
	if store == null:
		return
	if store.has_method("restore"):
		store.call("restore")
	elif store.has_method("restore_purchases"):
		store.call("restore_purchases")


func _on_native_purchase_updated(_product_id: String = "") -> void:
	GarageStore.set_unlocked(true)
	NotifyService.reschedule()
	last_ok = true
	last_message = "Unlocked."
	purchase_finished.emit(true)


func _on_native_purchase_failed(message: String = "") -> void:
	last_ok = false
	if str(message).strip_edges() == "":
		last_message = "Purchase didn't complete."
	else:
		last_message = str(message)
	purchase_finished.emit(false)


func _on_native_entitlements_updated(unlocked: bool = false) -> void:
	if unlocked:
		GarageStore.set_unlocked(true)
		NotifyService.reschedule()
		last_ok = true
		last_message = "Unlocked."
	else:
		last_ok = false
		last_message = "Nothing to restore."
	purchase_finished.emit(unlocked)


func _warn_missing_once() -> void:
	if _warned_missing:
		return
	_warned_missing = true
	push_warning("Purchase: StoreKit plugin not present; editor unlock only.")
