extends CanvasLayer
## Centered "Enjoying Oil Due?" card. Yes, No, and the corner X.

var debug_preview := false

var _card: PanelContainer
var _dim: ColorRect


func _ready() -> void:
	layer = 40
	_build()
	_dim.modulate.a = 0.0
	_card.modulate.a = 0.0
	_card.scale = Vector2(0.96, 0.96)
	_card.resized.connect(_place_pivot)
	get_viewport().size_changed.connect(_apply_safe)
	_apply_safe()
	call_deferred("_play_in")


func _place_pivot() -> void:
	_card.pivot_offset = _card.size * 0.5


func _play_in() -> void:
	_place_pivot()
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_dim, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_card, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_card, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _build() -> void:
	_dim = ColorRect.new()
	_dim.color = ReviewChrome.COLOR_DIM
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)

	var margin := MarginContainer.new()
	margin.name = "SafeMargin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(center)

	_card = PanelContainer.new()
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_card.add_theme_stylebox_override("panel", ReviewChrome.card_style())
	center.add_child(_card)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(column)

	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(header)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(spacer)
	var close := Button.new()
	close.text = "×"
	close.theme_type_variation = &"IconButton"
	close.custom_minimum_size = Vector2(44, 44)
	close.focus_mode = Control.FOCUS_NONE
	close.add_theme_font_size_override("font_size", 20)
	close.add_theme_color_override("font_color", ReviewChrome.COLOR_MUTED)
	close.add_theme_color_override("font_hover_color", ReviewChrome.COLOR_TEXT)
	close.add_theme_color_override("font_pressed_color", ReviewChrome.COLOR_TEXT)
	close.pressed.connect(_on_close)
	header.add_child(close)

	var title := Label.new()
	title.text = tr("Enjoying Oil Due?")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", ReviewChrome.COLOR_TEXT)
	column.add_child(title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	column.add_child(row)
	var no := Button.new()
	no.text = tr("No")
	no.theme_type_variation = &"SecondaryButton"
	no.custom_minimum_size = Vector2(0, 52)
	no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	no.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	no.focus_mode = Control.FOCUS_NONE
	no.pressed.connect(_on_no)
	row.add_child(no)
	var yes := Button.new()
	yes.text = tr("Yes")
	yes.theme_type_variation = &"CreamButton"
	yes.custom_minimum_size = Vector2(0, 52)
	yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	yes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	yes.focus_mode = Control.FOCUS_NONE
	yes.pressed.connect(_on_yes)
	row.add_child(yes)
	_apply_safe()


func _apply_safe() -> void:
	var margin := get_node_or_null("SafeMargin") as MarginContainer
	if margin == null:
		return
	var insets := ReviewChrome.safe_insets(get_viewport())
	margin.add_theme_constant_override("margin_left", int(insets.x))
	margin.add_theme_constant_override("margin_top", int(insets.y))
	margin.add_theme_constant_override("margin_right", int(insets.z))
	margin.add_theme_constant_override("margin_bottom", int(insets.w))
	var width := get_viewport().get_visible_rect().size.x - insets.x - insets.z
	_card.custom_minimum_size.x = minf(360.0, maxf(220.0, width))


func _on_yes() -> void:
	var preview := debug_preview
	_close()
	ReviewPrompt.on_yes(preview)


func _on_no() -> void:
	var preview := debug_preview
	_close()
	ReviewPrompt.on_no(preview)


func _on_close() -> void:
	var preview := debug_preview
	_close()
	ReviewPrompt.on_dismiss(preview)


func _close() -> void:
	visible = false
	queue_free()
