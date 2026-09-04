extends CanvasLayer

var _on_danger: Callable = Callable()
var _on_safe: Callable = Callable()


static func present(
	host: Node,
	title: String,
	body: String,
	safe_text: String,
	danger_text: String,
	on_danger: Callable,
	on_safe: Callable = Callable()
) -> void:
	if host == null:
		return
	var tree := host.get_tree()
	var root: Node = tree.current_scene if tree != null and tree.current_scene != null else host
	var packed := load("res://scenes/ui/confirm_sheet.tscn") as PackedScene
	if packed == null:
		return
	var sheet := packed.instantiate()
	root.add_child(sheet)
	sheet.setup(title, body, safe_text, danger_text, on_danger, on_safe)


func setup(
	title: String,
	body: String,
	safe_text: String,
	danger_text: String,
	on_danger: Callable,
	on_safe: Callable = Callable()
) -> void:
	_on_danger = on_danger
	_on_safe = on_safe
	%Title.text = title
	var body_s := body.strip_edges()
	%Body.text = body_s
	%Body.visible = body_s != ""
	%SafeButton.text = safe_text if safe_text.strip_edges() != "" else "Keep"
	var danger_s := danger_text.strip_edges()
	%DangerButton.visible = danger_s != ""
	if danger_s != "":
		%DangerButton.text = danger_s
	_pad_home_indicator()
	%SafeButton.pressed.connect(_on_safe_pressed)
	%DangerButton.pressed.connect(_on_danger_pressed)
	%Dim.gui_input.connect(_on_dim_gui_input)


func _pad_home_indicator() -> void:
	var win := DisplayServer.window_get_size()
	if win.y <= 0:
		return
	var safe := DisplayServer.get_display_safe_area()
	var extra := maxi(16, win.y - safe.end.y)
	%BottomPad.custom_minimum_size.y = extra


func _on_safe_pressed() -> void:
	_finish_safe()


func _on_danger_pressed() -> void:
	var cb := _on_danger
	_close()
	if cb.is_valid():
		cb.call()


func _on_dim_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			_finish_safe()
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_finish_safe()


func _finish_safe() -> void:
	var cb := _on_safe
	_close()
	if cb.is_valid():
		cb.call()


func _close() -> void:
	queue_free()
