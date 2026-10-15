extends Node

const DueMath = preload("res://scripts/due_math.gd")
const CAP := 64
const TEST_ID := 900001
const TEST_TITLE := "Oil Due test"
const TEST_BODY := "If you see this, killed-app notify works"

signal permission_resolved(ok: bool)

var last_plan: Array = []
var scheduler_override: Object = null
var _warned_missing := false
var _ns_node: Node
var _ns_ready := false
var _live_ids: Array = []
var _pending_test_sec := 0
var _signals_bound := false


func reschedule() -> void:
	last_plan = _build_plan()
	_print_plan()
	var sched := _scheduler()
	if sched == null:
		return
	if OS.has_feature("ios") and _ns_node != null and not _ns_ready:
		return
	_apply_os(sched)


func has_os_permission() -> bool:
	if not OS.has_feature("ios"):
		return true
	var sched := _scheduler()
	if sched == null:
		return true
	if sched.has_method("has_post_notifications_permission"):
		return bool(sched.call("has_post_notifications_permission"))
	if sched.has_method("has_permission"):
		return bool(sched.call("has_permission"))
	return false


func open_settings() -> void:
	var sched := _scheduler()
	if sched != null and sched.has_method("open_app_info_settings"):
		sched.call("open_app_info_settings")


func ensure_permission() -> void:
	if has_os_permission():
		permission_resolved.emit(true)
		return
	var sched := _scheduler()
	if sched == null:
		permission_resolved.emit(true)
		return
	if sched.has_method("request_post_notifications_permission"):
		sched.call("request_post_notifications_permission")
	elif sched.has_method("request_permission"):
		sched.call("request_permission")
	else:
		permission_resolved.emit(true)


func schedule_test(delay_sec: int) -> String:
	if not OS.is_debug_build():
		return ""
	if not OS.has_feature("ios"):
		return tr("No notification plugin in the editor.")
	var sched := _scheduler()
	if sched == null:
		return tr("No notification plugin in the editor.")
	if not has_os_permission():
		_pending_test_sec = maxi(1, delay_sec)
		ensure_permission()
		return tr("Allow notifications to send the test.")
	_fire_test(delay_sec)
	return tr("Test notification in 1 min. You can kill the app.")


func _fire_test(delay_sec: int) -> void:
	var sched := _scheduler()
	if sched == null or not sched.has_method("schedule"):
		return
	if OS.has_feature("ios") and _ns_node != null and not _ns_ready:
		_pending_test_sec = maxi(1, delay_sec)
		return
	var delay := maxi(1, delay_sec)
	if sched.has_method("cancel"):
		sched.call("cancel", TEST_ID)
	_live_ids.erase(TEST_ID)
	if _uses_notification_data(sched):
		sched.call("schedule", make_notification(TEST_ID, tr(TEST_TITLE), tr(TEST_BODY), delay))
	else:
		var unix := int(Time.get_unix_time_from_system()) + delay
		sched.call("schedule", TEST_ID, tr(TEST_TITLE), tr(TEST_BODY), unix)
	if not _live_ids.has(TEST_ID):
		_live_ids.append(TEST_ID)


func _apply_os(sched: Object) -> void:
	if sched.has_method("cancel"):
		for nid in _stale_ids():
			sched.call("cancel", int(nid))
	_live_ids.clear()
	var scheduled: Array = []
	for item in last_plan:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		if _schedule_one(sched, item):
			scheduled.append(int(item.get("id", 0)))
	GarageStore.data["scheduled_ids"] = scheduled
	GarageStore.save()


func _build_plan() -> Array:
	var out: Array = []
	var unlocked := Purchase.is_unlocked()
	var today := GarageStore.today_ymd()
	var vehicles := GarageStore.vehicles_list()
	var first_id := ""
	if not vehicles.is_empty() and typeof(vehicles[0]) == TYPE_DICTIONARY:
		first_id = str(vehicles[0].get("id", ""))
	for vitem in vehicles:
		if typeof(vitem) != TYPE_DICTIONARY:
			continue
		var vehicle: Dictionary = vitem
		var vid := str(vehicle.get("id", ""))
		var nick := str(vehicle.get("name", "")).strip_edges()
		for sitem in vehicle.get("services", []):
			if typeof(sitem) != TYPE_DICTIONARY:
				continue
			var service: Dictionary = sitem
			if not bool(service.get("notify", false)):
				continue
			if not unlocked:
				if vid != first_id or str(service.get("type_id", "")) != "oil_change":
					continue
			var next_date := str(service.get("next_date", "")).strip_edges()
			if DueMath.parse_ymd(next_date).is_empty():
				continue
			if DueMath.compare_ymd(next_date, today) <= 0:
				continue
			var label := str(service.get("label", "")).strip_edges()
			var title := tr("Oil Due — %s") % nick if nick != "" else tr("Oil Due")
			var shown := tr(label) if label != "" else ""
			var body := tr("%s due") % shown if shown != "" else tr("Service due")
			out.append({
				"id": _stable_id(vid, str(service.get("id", ""))),
				"vehicle_id": vid,
				"service_id": str(service.get("id", "")),
				"fire_ymd": next_date,
				"title": title,
				"body": body,
			})
	out.sort_custom(_plan_sooner)
	if out.size() > CAP:
		out.resize(CAP)
	return out


func _plan_sooner(a: Dictionary, b: Dictionary) -> bool:
	return DueMath.compare_ymd(str(a.get("fire_ymd", "")), str(b.get("fire_ymd", ""))) < 0


func _stable_id(vid: String, sid: String) -> int:
	var h := ("%s/%s" % [vid, sid]).hash()
	if h < 0:
		h = -h
	if h == 0:
		h = 1
	return h


func _print_plan() -> void:
	if last_plan.is_empty():
		print("NotifyService last_plan: (none)")
		return
	var dates: PackedStringArray = []
	for item in last_plan:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		dates.append(str(item.get("fire_ymd", "")))
	print("NotifyService last_plan: %s" % ", ".join(dates))


func local_nine_unix(ymd: String) -> int:
	var parsed := DueMath.parse_ymd(ymd)
	if parsed.is_empty():
		return 0
	var utc_naive := int(Time.get_unix_time_from_datetime_dict({
		"year": int(parsed.year),
		"month": int(parsed.month),
		"day": int(parsed.day),
		"hour": 9,
		"minute": 0,
		"second": 0,
	}))
	var zone: Dictionary = Time.get_time_zone_from_system()
	var bias := int(zone.get("bias", 0))
	return utc_naive + bias * 60


func make_notification(id: int, title: String, body: String, delay: int) -> NotificationData:
	var data := NotificationData.new()
	data.set_id(id)
	data.set_title(title)
	data.set_content(body)
	data.set_delay(delay)
	return data


func _uses_notification_data(sched: Object) -> bool:
	return sched == _ns_node or sched == scheduler_override


func _stale_ids() -> Array:
	var seen: Dictionary = {}
	var vehicles: Array = GarageStore.data.get("vehicles", [])
	for vitem in vehicles:
		if typeof(vitem) != TYPE_DICTIONARY:
			continue
		var vehicle: Dictionary = vitem
		var vid := str(vehicle.get("id", ""))
		for sitem in vehicle.get("services", []):
			if typeof(sitem) != TYPE_DICTIONARY:
				continue
			var service: Dictionary = sitem
			seen[_stable_id(vid, str(service.get("id", "")))] = true
	var saved: Array = GarageStore.data.get("scheduled_ids", [])
	if typeof(saved) == TYPE_ARRAY:
		for nid in saved:
			seen[int(nid)] = true
	for nid in _live_ids:
		seen[int(nid)] = true
	return seen.keys()


func _scheduler() -> Object:
	if scheduler_override != null:
		return scheduler_override
	if Engine.has_singleton("NotificationScheduler"):
		return Engine.get_singleton("NotificationScheduler")
	if Engine.has_singleton("NotificationSchedulerPlugin"):
		return _ios_node()
	if OS.has_feature("ios"):
		return _ios_node()
	if not _warned_missing:
		_warned_missing = true
		push_warning("NotifyService: NotificationScheduler plugin not present; date reminders stay in-app.")
	return null


func _ios_node() -> Object:
	if not OS.has_feature("ios"):
		return null
	if _ns_node != null:
		return _ns_node
	var script = load("res://addons/NotificationSchedulerPlugin/NotificationScheduler.gd")
	if script == null:
		return null
	_ns_node = script.new()
	add_child(_ns_node)
	_bind_permission_signals()
	if _ns_node.has_signal("initialization_completed"):
		_ns_node.connect("initialization_completed", _on_ns_ready)
	if _ns_node.has_method("initialize"):
		_ns_node.call("initialize")
	return _ns_node


func _bind_permission_signals() -> void:
	if _signals_bound or _ns_node == null:
		return
	_signals_bound = true
	if _ns_node.has_signal("post_notifications_permission_granted"):
		_ns_node.connect("post_notifications_permission_granted", _on_permission_granted)
	if _ns_node.has_signal("post_notifications_permission_denied"):
		_ns_node.connect("post_notifications_permission_denied", _on_permission_denied)


func _on_permission_granted(_permission_name: String = "") -> void:
	permission_resolved.emit(true)
	reschedule()
	if _pending_test_sec > 0:
		var delay := _pending_test_sec
		_pending_test_sec = 0
		_fire_test(delay)


func _on_permission_denied(_permission_name: String = "") -> void:
	_pending_test_sec = 0
	permission_resolved.emit(false)


func _on_ns_ready() -> void:
	_ns_ready = true
	var sched := _scheduler()
	if sched == null:
		return
	_apply_os(sched)
	if _pending_test_sec > 0:
		var delay := _pending_test_sec
		_pending_test_sec = 0
		_fire_test(delay)


func _schedule_one(sched: Object, item: Dictionary) -> bool:
	if not sched.has_method("schedule"):
		return false
	var unix := local_nine_unix(str(item.get("fire_ymd", "")))
	if unix <= 0:
		return false
	var now := int(Time.get_unix_time_from_system())
	if unix <= now:
		return false
	var nid := int(item.get("id", 0))
	if _uses_notification_data(sched):
		var delay := unix - now
		sched.call("schedule", make_notification(nid, str(item.get("title", "")), str(item.get("body", "")), delay))
		_live_ids.append(nid)
		return true
	sched.call("schedule", nid, str(item.get("title", "")), str(item.get("body", "")), unix)
	_live_ids.append(nid)
	return true
