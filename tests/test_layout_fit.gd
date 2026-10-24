extends Control

const WIDTHS := [375, 390, 393, 428]
const LOCALES := ["en", "de", "fr", "es_419", "pt_BR"]
const SCENES := [
	"res://scenes/garage.tscn",
	"res://scenes/service_add.tscn",
	"res://scenes/settings.tscn",
	"res://scenes/service_list.tscn",
	"res://scenes/service_edit.tscn",
	"res://scenes/vehicle_add.tscn",
	"res://scenes/vehicle_edit.tscn",
	"res://scenes/spend.tscn",
	"res://scenes/more_services.tscn",
	"res://scenes/last_oil.tscn",
	"res://scenes/help.tscn",
	"res://scenes/unlock.tscn",
]


func _ready() -> void:
	GarageStore._install_translations()
	var dir := OS.get_environment("LAYOUT_OUT")
	if dir == "":
		dir = "/tmp/oildue-layout"
	DirAccess.make_dir_recursive_absolute(dir)
	var widths: Array = WIDTHS.duplicate()
	var scenes: Array = SCENES.duplicate()
	var width_filter := OS.get_environment("LAYOUT_WIDTHS")
	if width_filter != "":
		widths = []
		for part in width_filter.split(","):
			widths.append(int(part))
	var scene_filter := OS.get_environment("LAYOUT_SCENES")
	if scene_filter != "":
		scenes = []
		for part in scene_filter.split(","):
			scenes.append(part.strip_edges())
	var fail := ""
	for width in widths:
		for loc in LOCALES:
			for path in scenes:
				var hit: String = await _audit(width, 812, loc, path, dir)
				if hit != "" and fail == "":
					fail = hit
				elif hit != "":
					print(hit)
	if fail == "":
		%Result.text = "PASS"
	else:
		%Result.text = "FAIL: %s" % fail
		print(fail)
	print(%Result.text)
	get_tree().quit()


func _audit(width: int, height: int, loc: String, path: String, dir: String) -> String:
	TranslationServer.set_locale(loc)
	_seed()
	var vp := SubViewport.new()
	vp.size = Vector2i(width, height)
	vp.disable_3d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var screen := (load(path) as PackedScene).instantiate()
	vp.add_child(screen)
	for _i in 3:
		await get_tree().process_frame
	var view := Vector2(width, height)
	_walk(screen, view, loc, width, path)
	var hit := str(screen.get_meta("layout_hit", ""))
	if OS.get_environment("LAYOUT_PNG") == "1":
		var img := vp.get_texture().get_image()
		if img != null and img.get_width() > 0:
			img.save_png("%s/%s_%s_%d.png" % [dir, path.get_file().get_basename(), loc, width])
	screen.queue_free()
	vp.queue_free()
	await get_tree().process_frame
	return hit


func _walk(node: Node, view: Vector2, loc: String, width: int, path: String) -> void:
	if node is Control and (node as Control).is_visible_in_tree():
		var c := node as Control
		var g := c.get_global_rect()
		var bad := false
		if g.size.x > 1.0 and (g.position.x < -1.0 or g.end.x > view.x + 1.0) and not _inside_horizontal_scroll(c):
			bad = true
		if c.get_combined_minimum_size().x > view.x + 1.0:
			bad = true
		if bad:
			var scene := path.get_file()
			var msg := "%s %s %d %s x=%.1f..%.1f min=%.1f" % [scene, loc, width, c.name, g.position.x, g.end.x, c.get_combined_minimum_size().x]
			var root := _root_screen(c)
			if root != null and str(root.get_meta("layout_hit", "")) == "":
				root.set_meta("layout_hit", msg)
			print("OFFSCREEN " + msg)
	for child in node.get_children():
		_walk(child, view, loc, width, path)


func _root_screen(c: Node) -> Node:
	var n := c
	while n != null and not (n.get_parent() is SubViewport):
		n = n.get_parent()
	return n


func _inside_horizontal_scroll(c: Control) -> bool:
	var n: Node = c.get_parent()
	while n != null:
		if n is ScrollContainer:
			var scroll := n as ScrollContainer
			if scroll.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
				return true
		n = n.get_parent()
	return false


func _seed() -> void:
	var today := GarageStore.today_ymd()
	GarageStore.data = {
		"schema": 1,
		"units": "mi",
		"currency": "EUR",
		"notify_lead_days": 7,
		"unlocked": true,
		"log_tip_seen": true,
		"oil_remind_asked": true,
		"scheduled_ids": [],
		"distance_unit": "mi",
		"vehicles": [
			{
				"id": "v1",
				"year": 2020,
				"make": "Mitsubishi",
				"model": "Outlander",
				"name": "My car",
				"vin": "",
				"plate": "",
				"odometer": 77000,
				"odometer_date": today,
				"photo": "",
				"archived": false,
				"services": [
					{
						"id": "svc_oil",
						"type_id": "oil_change",
						"label": "Oil change",
						"interval_miles": 5000,
						"interval_months": 6,
						"last_date": GarageStore.add_days_ymd(today, -20),
						"last_miles": 72000,
						"next_date": "2027-04-15",
						"next_miles": 82000,
						"notify": false,
					},
				],
				"history": [
					{
						"id": "h1",
						"service_id": "svc_oil",
						"date": GarageStore.add_days_ymd(today, -20),
						"miles": 72000,
						"cost_cents": 8900,
						"notes": "Full synthetic",
					},
				],
			},
		],
	}
	GarageStore.selected_vehicle_id = "v1"
	GarageStore.selected_service_id = "svc_oil"
