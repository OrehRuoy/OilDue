extends MarginContainer

const PAD := 16


func _ready() -> void:
	get_viewport().size_changed.connect(_apply)
	_apply()


func _apply() -> void:
	var win := DisplayServer.window_get_size()
	if win.x <= 0 or win.y <= 0:
		return
	var safe := DisplayServer.get_display_safe_area()
	var vp := get_viewport_rect().size
	var sx := vp.x / float(win.x)
	var sy := vp.y / float(win.y)
	add_theme_constant_override("margin_left", maxi(PAD, int(round(safe.position.x * sx))))
	add_theme_constant_override("margin_top", maxi(PAD, int(round(safe.position.y * sy))))
	add_theme_constant_override("margin_right", maxi(PAD, int(round((win.x - safe.end.x) * sx))))
	add_theme_constant_override("margin_bottom", maxi(PAD, int(round((win.y - safe.end.y) * sy))))
