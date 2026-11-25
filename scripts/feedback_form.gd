extends CanvasLayer
## In-app feedback. Web3Forms success is JSON {"success": true} only.

var _margin: MarginContainer
var _scroll: ScrollContainer
var _center: CenterContainer
var _card: PanelContainer
var _heading: Label
var _note: TextEdit
var _email_caption: Label
var _email: LineEdit
var _status: Label
var _cancel: Button
var _send: Button
var _http: HTTPRequest
var _sending := false
var _thanks := false
var _kb := -1.0


func _ready() -> void:
	layer = 41
	_build()
	_dim_in()
	get_viewport().size_changed.connect(_on_viewport_changed)
	_apply_safe()
	call_deferred("_fit_card")
	set_process(true)


func _process(_delta: float) -> void:
	var kb := ReviewChrome.keyboard_inset(get_viewport())
	if absf(kb - _kb) < 1.0:
		return
	_kb = kb
	_apply_safe()
	call_deferred("_fit_card")


func _on_viewport_changed() -> void:
	_kb = -1.0
	_apply_safe()
	call_deferred("_fit_card")


func _dim_in() -> void:
	var dim := get_node_or_null("Dim") as ColorRect
	if dim == null or _card == null:
		return
	dim.modulate.a = 0.0
	_card.modulate.a = 0.0
	_card.scale = Vector2(0.96, 0.96)
	_card.resized.connect(func() -> void: _card.pivot_offset = _card.size * 0.5)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(dim, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_card, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_card, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _build() -> void:
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = ReviewChrome.COLOR_DIM
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(_on_dim_input)
	add_child(dim)

	_margin = MarginContainer.new()
	_margin.name = "SafeMargin"
	_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_margin)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	_margin.add_child(_scroll)

	_center = CenterContainer.new()
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll.add_child(_center)

	_card = PanelContainer.new()
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_card.add_theme_stylebox_override("panel", ReviewChrome.card_style())
	_center.add_child(_card)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(column)

	_heading = Label.new()
	_heading.text = tr("How can we make Oil Due better?")
	_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_heading.add_theme_font_size_override("font_size", 22)
	_heading.add_theme_color_override("font_color", ReviewChrome.COLOR_TEXT)
	column.add_child(_heading)

	_note = TextEdit.new()
	_note.placeholder_text = tr("What should we change?")
	_note.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_note.custom_minimum_size = Vector2(0, 140)
	_note.scroll_fit_content_height = false
	_note.focus_mode = Control.FOCUS_CLICK
	_note.add_theme_color_override("font_color", ReviewChrome.COLOR_TEXT)
	_note.add_theme_color_override("font_placeholder_color", ReviewChrome.COLOR_PLACEHOLDER)
	_note.add_theme_color_override("caret_color", ReviewChrome.COLOR_TEXT)
	_note.add_theme_color_override("background_color", Color(0, 0, 0, 0))
	_note.add_theme_stylebox_override("normal", ReviewChrome.field_style(false))
	_note.add_theme_stylebox_override("focus", ReviewChrome.field_style(true))
	_note.add_theme_stylebox_override("read_only", ReviewChrome.field_style(false))
	_note.text_changed.connect(_refresh_send)
	_note.focus_entered.connect(_scroll_focus)
	column.add_child(_note)

	_email_caption = Label.new()
	_email_caption.text = tr("Email (optional)")
	_email_caption.theme_type_variation = &"Caption"
	_email_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_email_caption)

	_email = LineEdit.new()
	_email.placeholder_text = tr("Email (optional)")
	_email.custom_minimum_size = Vector2(0, 48)
	_email.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS
	_email.focus_entered.connect(_scroll_focus)
	column.add_child(_email)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 15)
	_status.add_theme_color_override("font_color", ReviewChrome.COLOR_BODY)
	_status.visible = false
	column.add_child(_status)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	column.add_child(row)
	_cancel = Button.new()
	_cancel.text = tr("Cancel")
	_cancel.theme_type_variation = &"SecondaryButton"
	_cancel.custom_minimum_size = Vector2(0, 52)
	_cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cancel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_cancel.focus_mode = Control.FOCUS_NONE
	_cancel.pressed.connect(_on_cancel)
	row.add_child(_cancel)
	_send = Button.new()
	_send.text = tr("Send")
	_send.theme_type_variation = &"CreamButton"
	_send.custom_minimum_size = Vector2(0, 52)
	_send.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_send.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_send.focus_mode = Control.FOCUS_NONE
	_send.add_theme_color_override("font_disabled_color", ReviewChrome.COLOR_PLACEHOLDER)
	_send.add_theme_stylebox_override("disabled", ReviewChrome.disabled_button_style())
	_send.pressed.connect(_on_send)
	row.add_child(_send)
	_refresh_send()


func _apply_safe() -> void:
	if _margin == null:
		return
	var insets := ReviewChrome.safe_insets(get_viewport())
	var kb := ReviewChrome.keyboard_inset(get_viewport())
	var bottom := insets.w
	if kb > 0.0:
		bottom = maxf(insets.w, kb + 8.0)
	_margin.add_theme_constant_override("margin_left", int(insets.x))
	_margin.add_theme_constant_override("margin_top", int(insets.y))
	_margin.add_theme_constant_override("margin_right", int(insets.z))
	_margin.add_theme_constant_override("margin_bottom", int(bottom))


func _fit_card() -> void:
	if _scroll == null or _card == null or _note == null or _center == null:
		return
	var width := _scroll.size.x
	var avail := _scroll.size.y
	if width < 20.0 or avail < 20.0:
		return
	_card.custom_minimum_size.x = minf(360.0, width)
	if not _thanks:
		var other := _card.get_combined_minimum_size().y - _note.custom_minimum_size.y
		var note_h := clampf(avail - other - 4.0, 72.0, 150.0)
		if absf(_note.custom_minimum_size.y - note_h) > 1.0:
			_note.custom_minimum_size.y = note_h
	var need := _card.get_combined_minimum_size().y
	_center.custom_minimum_size = Vector2(width, maxf(avail, need))
	_scroll_focus()


func _scroll_focus() -> void:
	if _scroll == null:
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is Control and _scroll.is_ancestor_of(focus):
		_scroll.ensure_control_visible(focus)


func _on_dim_input(event: InputEvent) -> void:
	if _sending:
		return
	var pressed := false
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		pressed = mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch:
		pressed = (event as InputEventScreenTouch).pressed
	if pressed:
		_on_cancel()


func _refresh_send() -> void:
	if _send == null or _note == null:
		return
	_send.disabled = _sending or _thanks or _note.text.strip_edges() == ""


func _on_cancel() -> void:
	if _http != null:
		_http.cancel_request()
	DisplayServer.virtual_keyboard_hide()
	visible = false
	queue_free()


func _on_send() -> void:
	var message := _note.text.strip_edges()
	if message == "" or _sending or _thanks:
		return
	_sending = true
	_refresh_send()
	_set_status("", ReviewChrome.COLOR_BODY)
	var payload := {
		"access_key": AppInfo.WEB3FORMS_ACCESS_KEY,
		"subject": "Oil Due feedback",
		"from_name": "Oil Due app",
		"message": message,
		"app_version": AppInfo.app_version(),
		"ios_version": AppInfo.ios_version(),
	}
	var email := _email.text.strip_edges()
	if email != "":
		payload["email"] = email
	_http = HTTPRequest.new()
	_http.timeout = 20.0
	add_child(_http)
	_http.request_completed.connect(_on_result)
	var err := _http.request(
		AppInfo.WEB3FORMS_URL,
		PackedStringArray(["Content-Type: application/json", "Accept: application/json"]),
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)
	if err != OK:
		_fail()


func _on_result(result: int, _code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var ok := false
	if result == HTTPRequest.RESULT_SUCCESS:
		var parsed = JSON.parse_string(body.get_string_from_utf8())
		ok = typeof(parsed) == TYPE_DICTIONARY and (parsed as Dictionary).get("success") == true
	_clear_http()
	if ok:
		_show_thanks()
		return
	_fail()


func _fail() -> void:
	_sending = false
	_clear_http()
	_set_status(tr("Couldn't send, please try again"), ReviewChrome.COLOR_DANGER)
	_refresh_send()


func _show_thanks() -> void:
	_sending = false
	_thanks = true
	DisplayServer.virtual_keyboard_hide()
	_note.visible = false
	_email_caption.visible = false
	_email.visible = false
	_send.visible = false
	_heading.text = tr("Thanks! Feedback sent.")
	_set_status("", ReviewChrome.COLOR_BODY)
	_cancel.text = tr("OK")
	_refresh_send()
	call_deferred("_fit_card")


func _set_status(text: String, color: Color) -> void:
	_status.text = text
	_status.visible = text != ""
	_status.add_theme_color_override("font_color", color)


func _clear_http() -> void:
	if _http == null:
		return
	var http := _http
	_http = null
	if is_instance_valid(http):
		http.queue_free()
