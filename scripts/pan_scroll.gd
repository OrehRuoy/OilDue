extends RefCounted
class_name PanScroll

const THRESHOLD := 8.0


static func wire(host: Control, on_tap: Callable) -> void:
	host.set_meta("pan_start", Vector2.ZERO)
	host.set_meta("pan_drag", false)
	host.gui_input.connect(_on_gui.bind(host, on_tap))


static func wire_focus(host: Control) -> void:
	wire(host, host.grab_focus)


static func wire_fields(root: Node) -> void:
	if root is LineEdit:
		wire_focus(root as LineEdit)
	elif root is TextEdit:
		wire_focus(root as TextEdit)
	for child in root.get_children():
		wire_fields(child)


static func _find_scroll(from: Node) -> ScrollContainer:
	var n: Node = from
	while n != null:
		if n is ScrollContainer:
			return n as ScrollContainer
		n = n.get_parent()
	return null


static func _on_gui(event: InputEvent, host: Control, on_tap: Callable) -> void:
	var scroll := _find_scroll(host)
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse.pressed:
			host.set_meta("pan_start", mouse.global_position)
			host.set_meta("pan_drag", false)
		else:
			var dragged := bool(host.get_meta("pan_drag", false))
			_mark_handled(host)
			if not dragged:
				on_tap.call()
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if motion.button_mask & MOUSE_BUTTON_MASK_LEFT == 0:
			return
		_apply_drag(host, scroll, motion.global_position, motion.relative)
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			host.set_meta("pan_start", touch.position)
			host.set_meta("pan_drag", false)
		else:
			var dragged := bool(host.get_meta("pan_drag", false))
			_mark_handled(host)
			if not dragged:
				on_tap.call()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		_apply_drag(host, scroll, drag.position, drag.relative)


static func _apply_drag(host: Control, scroll: ScrollContainer, pos: Vector2, relative: Vector2) -> void:
	if scroll == null:
		return
	var start: Vector2 = host.get_meta("pan_start", Vector2.ZERO)
	if not bool(host.get_meta("pan_drag", false)):
		if (pos - start).length() >= THRESHOLD:
			host.set_meta("pan_drag", true)
	if not bool(host.get_meta("pan_drag", false)):
		return
	var can_v := scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED
	var can_h := scroll.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED
	if can_v and (not can_h or absf(relative.y) >= absf(relative.x)):
		scroll.scroll_vertical -= int(relative.y)
	elif can_h:
		scroll.scroll_horizontal -= int(relative.x)
	_mark_handled(host)


static func _mark_handled(host: Control) -> void:
	if host == null or not is_instance_valid(host) or not host.is_inside_tree():
		return
	var vp := host.get_viewport()
	if vp != null:
		vp.set_input_as_handled()
