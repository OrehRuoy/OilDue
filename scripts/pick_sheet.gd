extends CanvasLayer

const PanScroll = preload("res://scripts/pan_scroll.gd")
const VehicleCatalog = preload("res://scripts/vehicle_catalog.gd")
const COLOR_HAIRLINE := Color(0.239216, 0.219608, 0.196078, 1)
const COLOR_TEXT := Color("#F4EFE6")
const COLOR_MUTED := Color("#9A9388")
const COLOR_SELECTED := Color("#3D3832")

static var _busy := false
static var _open: CanvasLayer = null

var _items: PackedStringArray = PackedStringArray()
var _current := ""
var _on_pick: Callable = Callable()
var _allow_other := false
var _picked := false


static func present(host: Node, title: String, items: PackedStringArray, current: String, on_pick: Callable) -> void:
	_open_sheet(host, title, "", items, current, on_pick, true)


static func present_notice(host: Node, title: String, body: String) -> void:
	_open_sheet(host, title, body, PackedStringArray(), "", Callable(), false)


static func dismiss_keyboard() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		var vp := tree.root.get_viewport()
		if vp != null:
			var owner := vp.gui_get_focus_owner()
			if owner is Control:
				(owner as Control).release_focus()
			vp.gui_release_focus()
	DisplayServer.virtual_keyboard_hide()


static func _open_sheet(
	host: Node,
	title: String,
	body: String,
	items: PackedStringArray,
	current: String,
	on_pick: Callable,
	allow_other: bool
) -> void:
	dismiss_keyboard()
	if host == null or _busy:
		return
	_busy = true
	var tree := host.get_tree()
	var root: Node = tree.current_scene if tree != null and tree.current_scene != null else host
	var packed := load("res://scenes/ui/pick_sheet.tscn") as PackedScene
	if packed == null:
		_busy = false
		return
	var sheet := packed.instantiate() as CanvasLayer
	if sheet == null:
		_busy = false
		return
	_open = sheet
	root.add_child(sheet)
	sheet.setup(title, body, items, current, on_pick, allow_other)


func setup(
	title: String,
	body: String,
	items: PackedStringArray,
	current: String,
	on_pick: Callable,
	allow_other: bool
) -> void:
	_items = items
	_current = current.strip_edges()
	_on_pick = on_pick
	_allow_other = allow_other
	%Title.text = title
	var body_s := body.strip_edges()
	%Body.text = body_s
	%Body.visible = body_s != ""
	%Search.visible = allow_other
	%UseThis.visible = false
	%ListScroll.visible = allow_other
	%CancelButton.text = "OK" if not allow_other else "Cancel"
	_pad_home_indicator()
	%Search.text_changed.connect(_on_search_changed)
	%UseThis.pressed.connect(_on_use_this)
	%CancelButton.pressed.connect(_close)
	%Dim.gui_input.connect(_on_dim_gui_input)
	PanScroll.wire_fields(%Search)
	if allow_other:
		_rebuild()
	else:
		%Search.visible = false
		%UseThis.visible = false
		%ListScroll.visible = false


func _pad_home_indicator() -> void:
	var win := DisplayServer.window_get_size()
	if win.y <= 0:
		return
	var safe := DisplayServer.get_display_safe_area()
	var extra := maxi(16, win.y - safe.end.y)
	%BottomPad.custom_minimum_size.y = extra


func _on_search_changed(query: String) -> void:
	%UseThis.visible = _allow_other and query.strip_edges() != ""
	_rebuild()


func _rebuild() -> void:
	var rows: VBoxContainer = %Rows
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	var shown := VehicleCatalog.filter(_items, str(%Search.text))
	var count := shown.size()
	for i in range(count):
		var label := str(shown[i])
		rows.add_child(_make_row(label, false))
		if i < count - 1 or _allow_other:
			rows.add_child(_hairline())
	if _allow_other:
		rows.add_child(_make_row("Other…", true))


func _make_row(label: String, is_other: bool) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 52)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.text = label
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.add_theme_font_size_override("font_size", 17)
	var selected := not is_other and _current != "" and label.to_lower() == _current.to_lower()
	var color := COLOR_MUTED if is_other else COLOR_TEXT
	btn.add_theme_color_override("font_color", color)
	btn.add_theme_color_override("font_hover_color", color)
	btn.add_theme_color_override("font_pressed_color", color)
	btn.add_theme_color_override("font_focus_color", color)
	if selected:
		var style := StyleBoxFlat.new()
		style.bg_color = COLOR_SELECTED
		style.set_corner_radius_all(8)
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style)
		btn.add_theme_stylebox_override("pressed", style)
		btn.add_theme_stylebox_override("focus", style)
	if is_other:
		PanScroll.wire(btn, _on_other)
	else:
		PanScroll.wire(btn, _pick.bind(label))
	return btn


func _hairline() -> ColorRect:
	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(0, 1)
	line.color = COLOR_HAIRLINE
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


func _on_other() -> void:
	var typed := str(%Search.text).strip_edges()
	if typed != "":
		_pick(typed)
		return
	%Search.placeholder_text = "Type a custom name"
	%Search.grab_focus()


func _on_use_this() -> void:
	var typed := str(%Search.text).strip_edges()
	if typed != "":
		_pick(typed)


func _pick(value: String) -> void:
	if _picked:
		return
	var chosen := value.strip_edges()
	if chosen == "":
		return
	_picked = true
	var cb := _on_pick
	_close()
	if cb.is_valid():
		cb.call(chosen)


func _on_dim_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			_close()
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_close()


func _close() -> void:
	_busy = false
	if _open == self:
		_open = null
	queue_free()


func _exit_tree() -> void:
	_busy = false
	if _open == self:
		_open = null
