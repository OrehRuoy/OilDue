extends Control
class_name IosSwitch

signal toggled(on: bool)

const TRACK_W := 51.0
const TRACK_H := 31.0
const KNOB := 27.0
const PAD := 2.0
const COLOR_ON := Color("#34C759")
const COLOR_OFF := Color("#3D3832")
const COLOR_KNOB := Color.WHITE

var on := false:
	set(v):
		on = v
		queue_redraw()

var _tap_ms := 0


func _ready() -> void:
	custom_minimum_size = Vector2(TRACK_W, TRACK_H)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			_try_toggle()
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			accept_event()
			_try_toggle()


func _try_toggle() -> void:
	var now := Time.get_ticks_msec()
	if now - _tap_ms < PanScroll.TAP_DEBOUNCE_MS:
		return
	_tap_ms = now
	toggled.emit(not on)


func _draw() -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = COLOR_ON if on else COLOR_OFF
	track.set_corner_radius_all(int(TRACK_H * 0.5))
	draw_style_box(track, Rect2(Vector2.ZERO, Vector2(TRACK_W, TRACK_H)))
	var knob_x := TRACK_W - PAD - KNOB if on else PAD
	var knob_y := (TRACK_H - KNOB) * 0.5
	var knob := StyleBoxFlat.new()
	knob.bg_color = COLOR_KNOB
	knob.set_corner_radius_all(int(KNOB * 0.5))
	draw_style_box(knob, Rect2(Vector2(knob_x, knob_y), Vector2(KNOB, KNOB)))
