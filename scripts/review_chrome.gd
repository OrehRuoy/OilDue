class_name ReviewChrome
extends RefCounted
## Colors, radius, and insets copied from the confirm sheet and theme.tres.

const COLOR_DIM := Color(0.101961, 0.090196, 0.078431, 0.55)
const COLOR_CARD := Color(0.164706, 0.14902, 0.133333, 1)
const COLOR_TEXT := Color(0.94902, 0.94902, 0.968627, 1)
const COLOR_BODY := Color(0.784314, 0.760784, 0.721569, 1)
const COLOR_MUTED := Color(0.603922, 0.576471, 0.533333, 1)
const COLOR_PLACEHOLDER := Color(0.435294, 0.403922, 0.360784, 1)
const COLOR_BORDER := Color(0.239216, 0.219608, 0.196078, 1)
const COLOR_DANGER := Color(1, 0.270588, 0.227451, 1)
const COLOR_DISABLED := Color(0.13, 0.118, 0.106, 1)


static func card_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = COLOR_CARD
	box.set_corner_radius_all(16)
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 8
	box.content_margin_bottom = 16
	return box


static func field_style(focused: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = COLOR_CARD
	box.set_corner_radius_all(12)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	if focused:
		box.set_border_width_all(1)
		box.border_color = COLOR_BORDER
	return box


static func disabled_button_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = COLOR_DISABLED
	box.set_corner_radius_all(12)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 14
	box.content_margin_bottom = 14
	return box


static func safe_insets(viewport: Viewport) -> Vector4:
	if viewport == null:
		return Vector4(16, 16, 16, 16)
	var win := DisplayServer.window_get_size()
	if win.x <= 0 or win.y <= 0:
		return Vector4(16, 16, 16, 16)
	var safe := DisplayServer.get_display_safe_area()
	var vp := viewport.get_visible_rect().size
	var sx := vp.x / float(win.x)
	var sy := vp.y / float(win.y)
	return Vector4(
		maxf(16.0, safe.position.x * sx),
		maxf(16.0, safe.position.y * sy),
		maxf(16.0, (win.x - safe.end.x) * sx),
		maxf(16.0, (win.y - safe.end.y) * sy)
	)


static func keyboard_inset(viewport: Viewport) -> float:
	if viewport == null:
		return 0.0
	var win := DisplayServer.window_get_size()
	if win.y <= 0:
		return 0.0
	var vp := viewport.get_visible_rect().size
	var sy := vp.y / float(win.y)
	return maxf(0.0, float(DisplayServer.virtual_keyboard_get_height()) * sy)
