extends Node

const DueMath = preload("res://scripts/due_math.gd")
const CAP := 64

var last_plan: Array = []
var _permission_asked := false
var _warned_missing := false
var _ns_node: Node
var _ns_ready := false
var _live_ids: Array = []


func reschedule(from_enable: bool = false) -> void:
	last_plan = _build_plan()
	_print_plan()
	var sched := _scheduler()
	if from_enable and Purchase.is_unlocked() and sched != null and OS.has_feature("ios") and not _permission_asked:
		_permission_asked = true
		if sched.has_method("request_permission"):
			sched.call("request_permission")
		elif sched.has_method("request_post_notifications_permission"):
			sched.call("request_post_notifications_permission")
	if sched == null:
		return
	if OS.has_feature("ios") and _ns_node != null and not _ns_ready:
		return
	_apply_os(sched)


func _apply_os(sched: Object) -> void:
	if sched.has_method("cancel_all"):
		sched.call("cancel_all")
		_live_ids.clear()
	elif sched.has_method("cancel"):
		for nid in _live_ids:
			sched.call("cancel", int(nid))
		_live_ids.clear()
	for item in last_plan:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		_schedule_one(sched, item)


func _build_plan() -> Array:
	var out: Array = []
	if not Purchase.is_unlocked():
		return out
	var today := GarageStore.today_ymd()
	for vitem in GarageStore.vehicles_list():
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
			var next_date := str(service.get("next_date", "")).strip_edges()
			if DueMath.parse_ymd(next_date).is_empty():
				continue
			if DueMath.compare_ymd(next_date, today) <= 0:
				continue
			var label := str(service.get("label", "")).strip_edges()
			var title := "Oil Due — %s" % nick if nick != "" else "Oil Due"
			var body := "%s due" % label if label != "" else "Service due"
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


func _scheduler() -> Object:
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
	if _ns_node.has_signal("initialization_completed"):
		_ns_node.connect("initialization_completed", _on_ns_ready)
	if _ns_node.has_method("initialize"):
		_ns_node.call("initialize")
	return _ns_node


func _on_ns_ready() -> void:
	_ns_ready = true
	var sched := _scheduler()
	if sched == null:
		return
	_apply_os(sched)


func _schedule_one(sched: Object, item: Dictionary) -> void:
	if not sched.has_method("schedule"):
		return
	var ymd := str(item.get("fire_ymd", ""))
	var parsed := DueMath.parse_ymd(ymd)
	if parsed.is_empty():
		return
	var unix := Time.get_unix_time_from_datetime_dict({
		"year": int(parsed.year),
		"month": int(parsed.month),
		"day": int(parsed.day),
		"hour": 9,
		"minute": 0,
		"second": 0,
	})
	var nid := int(item.get("id", 0))
	if sched == _ns_node:
		var delay := int(unix) - int(Time.get_unix_time_from_system())
		if delay < 1:
			return
		var data = ClassDB.instantiate("NotificationData")
		if data == null:
			return
		data.call("set_id", nid)
		data.call("set_title", str(item.get("title", "")))
		data.call("set_content", str(item.get("body", "")))
		data.call("set_delay", delay)
		sched.call("schedule", data)
		_live_ids.append(nid)
		return
	sched.call("schedule", nid, str(item.get("title", "")), str(item.get("body", "")), unix)
	_live_ids.append(nid)
