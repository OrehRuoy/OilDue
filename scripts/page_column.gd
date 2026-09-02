extends HBoxContainer

const MAX_W := 428.0


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ensure_pads()
	resized.connect(_fit)
	_fit()


func _ensure_pads() -> void:
	if get_child_count() != 1:
		return
	var mid := get_child(0) as Control
	if mid == null:
		return
	var left := Control.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var right := Control.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(left)
	move_child(left, 0)
	add_child(right)
	mid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL


func _fit() -> void:
	if get_child_count() < 3:
		return
	var mid := get_child(1) as Control
	if mid == null:
		return
	var w := size.x
	if w <= 0.0:
		return
	var target := minf(MAX_W, w)
	mid.custom_minimum_size = Vector2(target, mid.custom_minimum_size.y)
