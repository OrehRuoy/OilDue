extends Control


func _ready() -> void:
	_check_garage()
	await _check_history()
	get_tree().quit()


func _check_garage() -> void:
	var packed := load("res://scenes/garage.tscn") as PackedScene
	var g: Node = packed.instantiate()
	add_child(g)
	var top: Node = g.find_child("TopBar", true, false)
	var names: PackedStringArray = []
	for child in top.get_children():
		names.append(str(child.name))
	print("TopBar children: %s" % ", ".join(names))
	var add: Node = g.find_child("AddService", true, false)
	print("AddService parent: %s prev: %s text: %s" % [
		add.get_parent().name,
		_prev_sibling(add),
		(add as Button).text,
	])
	g.queue_free()


func _prev_sibling(node: Node) -> String:
	var parent := node.get_parent()
	var i := node.get_index()
	if i <= 0:
		return "(none)"
	return str(parent.get_child(i - 1).name)


func _check_history() -> void:
	var snap: Dictionary = GarageStore.data.duplicate(true)
	GarageStore.data = {
		"schema": 1,
		"unlocked": false,
		"notify_lead_days": 7,
		"vehicles": [{
			"id": "v_check",
			"name": "Check",
			"archived": false,
			"odometer": 10000,
			"services": [{
				"id": "s_oil",
				"type_id": "oil_change",
				"label": "Oil change",
				"interval_miles": 5000,
				"interval_months": 6,
				"notify": false,
			}],
			"history": [{
				"id": "h_01",
				"service_id": "s_oil",
				"date": "2026-08-01",
				"miles": 9800,
				"cost_cents": 4599,
				"notes": "",
				"receipt": "",
			}],
		}],
	}
	GarageStore.selected_vehicle_id = "v_check"
	GarageStore.selected_service_id = "s_oil"
	var packed := load("res://scenes/service_list.tscn") as PackedScene
	var page: Control = packed.instantiate()
	add_child(page)
	await get_tree().process_frame
	var rows: Node = page.find_child("HistoryRows", true, false)
	for child in rows.get_children():
		var ctrl := child as Control
		print("History row min_h=%.0f size_h=%.0f clip=%s" % [
			ctrl.custom_minimum_size.y,
			ctrl.size.y,
			ctrl.clip_contents,
		])
		_print_labels(ctrl)
	page.queue_free()
	GarageStore.data = snap


func _print_labels(n: Node) -> void:
	if n is Label:
		var lab := n as Label
		print("  label '%s' font=%d h=%.0f" % [lab.text, lab.get_theme_font_size("font_size"), lab.size.y])
	for child in n.get_children():
		_print_labels(child)
