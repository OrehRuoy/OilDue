extends Node
## "Enjoying Oil Due?" after a real save. State lives in garage.json under "review".

const EnjoyingCardScript := "res://scripts/enjoying_card.gd"
const FeedbackFormScript := "res://scripts/feedback_form.gd"

const MIN_GAP_DAYS := 30
const SETTLE_MSEC := 500
const FIRST_RUN_LOG := "res://scenes/last_oil.tscn"
const GARAGE := "res://scenes/garage.tscn"
const ONBOARDING := [
	"res://scenes/last_oil.tscn",
	"res://scenes/more_services.tscn",
	"res://scenes/vehicle_add.tscn",
]

var _pending := ""
var _quiet_scene := ""
var _quiet_msec := -1


func _ready() -> void:
	record_use_day()
	set_process(false)


func _process(_delta: float) -> void:
	if _pending == "":
		set_process(false)
		return
	if not _ui_allowed():
		_pending = ""
		set_process(false)
		return
	var path := _scene_path()
	if path != _quiet_scene:
		_quiet_scene = path
		_quiet_msec = -1
		return
	if not scene_allows(_pending, path) or _blocked():
		_quiet_msec = -1
		return
	var now := Time.get_ticks_msec()
	if _quiet_msec < 0:
		_quiet_msec = now
		return
	if now - _quiet_msec < SETTLE_MSEC:
		return
	_pending = ""
	_quiet_msec = -1
	set_process(false)
	if can_show(_state(), GarageStore.today_ymd(), AppInfo.app_version()):
		_show_card(false)


func record_use_day() -> void:
	var today := GarageStore.today_ymd()
	var current := _state()
	var next := add_use_day(current, today)
	if next.get("use_days") == current.get("use_days"):
		return
	_write(next)


func on_service_logged() -> void:
	var next := with_log(_state())
	_write(next)
	var path := _scene_path()
	_pending = "garage" if path == FIRST_RUN_LOG else "any"
	_quiet_scene = ""
	_quiet_msec = -1
	if not _ui_allowed():
		_pending = ""
		set_process(false)
		return
	set_process(true)


func show_feedback() -> void:
	_show_feedback()


func debug_show_card() -> void:
	if not OS.is_debug_build():
		return
	_show_card(true)


func debug_show_feedback() -> void:
	if not OS.is_debug_build():
		return
	_show_feedback()


func on_yes(debug_preview: bool) -> void:
	if not debug_preview:
		_write(with_completed(_state(), GarageStore.today_ymd(), AppInfo.app_version()))
	_request_review()


func on_no(debug_preview: bool) -> void:
	if not debug_preview:
		_write(with_completed(_state(), GarageStore.today_ymd(), AppInfo.app_version()))
	_show_feedback()


func on_dismiss(debug_preview: bool) -> void:
	if debug_preview:
		return
	var current := _state()
	current["completed"] = bool(current.get("completed", false))
	_write(with_shown(current, GarageStore.today_ymd(), AppInfo.app_version()))


static func can_show(state: Dictionary, today: String, version: String) -> bool:
	if bool(state.get("completed", false)):
		return false
	if int(state.get("logged_services", 0)) < 2 and use_day_count(state) < 2:
		return false
	var shown_version := str(state.get("last_shown_version", "")).strip_edges()
	if shown_version != "" and shown_version == version.strip_edges():
		return false
	if not cooldown_done(str(state.get("last_shown_date", "")), today):
		return false
	return true


static func scene_allows(pending: String, scene_path: String) -> bool:
	if pending == "":
		return false
	if scene_path == "" or scene_path.begins_with("res://tests/"):
		return false
	if pending == "garage":
		return scene_path == GARAGE
	return not ONBOARDING.has(scene_path)


static func add_use_day(state: Dictionary, today: String) -> Dictionary:
	var next := state.duplicate(true)
	var days: Array = []
	var raw = next.get("use_days", [])
	if typeof(raw) == TYPE_ARRAY:
		for item in raw:
			var day := str(item).strip_edges()
			if day != "" and not days.has(day):
				days.append(day)
	var today_s := today.strip_edges()
	if today_s != "" and not days.has(today_s):
		days.append(today_s)
	if days.size() > 8:
		days = days.slice(days.size() - 8)
	next["use_days"] = days
	return next


static func with_log(state: Dictionary) -> Dictionary:
	var next := state.duplicate(true)
	next["logged_services"] = int(next.get("logged_services", 0)) + 1
	return next


static func with_shown(state: Dictionary, today: String, version: String) -> Dictionary:
	var next := state.duplicate(true)
	next["last_shown_date"] = today
	next["last_shown_version"] = version
	if typeof(next.get("completed", false)) != TYPE_BOOL:
		next["completed"] = false
	return next


static func with_completed(state: Dictionary, today: String, version: String) -> Dictionary:
	var next := with_shown(state, today, version)
	next["completed"] = true
	return next


static func use_day_count(state: Dictionary) -> int:
	var seen := {}
	var raw = state.get("use_days", [])
	if typeof(raw) != TYPE_ARRAY:
		return 0
	for item in raw:
		var day := str(item).strip_edges()
		if day != "":
			seen[day] = true
	return seen.size()


static func cooldown_done(last_shown: String, today: String) -> bool:
	var last := last_shown.strip_edges()
	if last == "":
		return true
	var parts := last.split("-")
	if parts.size() != 3:
		return true
	var due := GarageStore.add_days_ymd(last, MIN_GAP_DAYS)
	return today >= due


func _show_card(debug_preview: bool) -> void:
	var host := _host()
	if host == null:
		return
	if host.get_node_or_null("EnjoyingCard") != null or host.get_node_or_null("FeedbackForm") != null:
		return
	DisplayServer.virtual_keyboard_hide()
	if not debug_preview:
		_write(with_shown(_state(), GarageStore.today_ymd(), AppInfo.app_version()))
	var card = load(EnjoyingCardScript).new()
	card.name = "EnjoyingCard"
	card.debug_preview = debug_preview
	host.add_child(card)


func _show_feedback() -> void:
	var host := _host()
	if host == null:
		return
	if host.get_node_or_null("FeedbackForm") != null:
		return
	var form = load(FeedbackFormScript).new()
	form.name = "FeedbackForm"
	host.add_child(form)


func _request_review() -> void:
	if not Engine.has_singleton("StoreKit"):
		_open_write_review()
		return
	var store: Object = Engine.get_singleton("StoreKit")
	if store == null or not store.has_method("request_review"):
		_open_write_review()
		return
	var result = store.call("request_review")
	if typeof(result) == TYPE_INT and int(result) != OK:
		_open_write_review()


func _open_write_review() -> void:
	if DisplayServer.get_name() == "headless":
		return
	OS.shell_open(AppInfo.WRITE_REVIEW_URL)


func _state() -> Dictionary:
	var raw = GarageStore.data.get("review", {})
	if typeof(raw) != TYPE_DICTIONARY:
		raw = {}
	var days: Array = []
	var stored = raw.get("use_days", [])
	if typeof(stored) == TYPE_ARRAY:
		days = stored.duplicate()
	return {
		"use_days": days,
		"logged_services": int(raw.get("logged_services", 0)),
		"last_shown_date": str(raw.get("last_shown_date", "")),
		"last_shown_version": str(raw.get("last_shown_version", "")),
		"completed": bool(raw.get("completed", false)),
	}


func _write(state: Dictionary) -> void:
	var days: Array = []
	var raw = state.get("use_days", [])
	if typeof(raw) == TYPE_ARRAY:
		days = raw.duplicate()
	GarageStore.data["review"] = {
		"use_days": days,
		"logged_services": int(state.get("logged_services", 0)),
		"last_shown_date": str(state.get("last_shown_date", "")),
		"last_shown_version": str(state.get("last_shown_version", "")),
		"completed": bool(state.get("completed", false)),
	}
	GarageStore.save()


func _scene_path() -> String:
	var scene := get_tree().current_scene
	if scene == null:
		return ""
	return str(scene.scene_file_path)


func _host() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	if tree.current_scene != null:
		return tree.current_scene
	return tree.root


func _ui_allowed() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	var path := _scene_path()
	if path.begins_with("res://tests/") or path.begins_with("res://tools/"):
		return false
	return true


func _blocked() -> bool:
	var scene := get_tree().current_scene
	if scene == null:
		return true
	return _branch_blocked(scene)


func _branch_blocked(node: Node) -> bool:
	for child in node.get_children():
		var name := str(child.name)
		if name == "EnjoyingCard" or name == "FeedbackForm":
			continue
		var showing := true
		if child is CanvasItem:
			showing = (child as CanvasItem).visible
		elif child is CanvasLayer:
			showing = (child as CanvasLayer).visible
		if not showing:
			continue
		if child is CanvasLayer:
			return true
		if name.ends_with("Popup") or name.ends_with("Sheet"):
			return true
		if _branch_blocked(child):
			return true
	return false
