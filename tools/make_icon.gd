extends SceneTree

const SRC := "res://assets/icon.png"
const ICON_OUT := "res://assets/icon_1024.png"
const SPLASH_OUT := "res://assets/splash.png"
const TILE := Color("#2B0D0C")
const SPLASH_BG := Color("#1A1714")
const SIZE := 1024
const SIDE := 30
const SPLASH_WIDTH := 614


func _init() -> void:
	var src := _load_src()
	if src == null or src.is_empty():
		push_error("make_icon: could not load %s" % SRC)
		quit(1)
		return
	src.convert(Image.FORMAT_RGBA8)
	var box := _red_box(src)
	if box.size.x < 8 or box.size.y < 8:
		push_error("make_icon: red can bounding box empty")
		quit(1)
		return
	print("make_icon: source %dx%d red box %s" % [src.get_width(), src.get_height(), box])
	var can := _extract_can(src, box)
	_write_square(can, TILE, SIZE - SIDE * 2, ICON_OUT)
	_write_square(can, SPLASH_BG, SPLASH_WIDTH, SPLASH_OUT)
	print("make_icon: wrote %s and %s" % [ICON_OUT, SPLASH_OUT])
	quit()


func _load_src() -> Image:
	var tex := load(SRC) as Texture2D
	if tex != null:
		var img := tex.get_image()
		if img != null:
			return img
	var path := ProjectSettings.globalize_path(SRC)
	return Image.load_from_file(path)


func _red_box(src: Image) -> Rect2i:
	var min_x := src.get_width()
	var min_y := src.get_height()
	var max_x := -1
	var max_y := -1
	for y in range(src.get_height()):
		for x in range(src.get_width()):
			var c: Color = src.get_pixel(x, y)
			if c.r > 0.5 and c.g < 0.35:
				if x < min_x:
					min_x = x
				if y < min_y:
					min_y = y
				if x > max_x:
					max_x = x
				if y > max_y:
					max_y = y
	if max_x < min_x:
		return Rect2i()
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


func _extract_can(src: Image, box: Rect2i) -> Image:
	var can := Image.create(box.size.x, box.size.y, false, Image.FORMAT_RGBA8)
	can.blit_rect(src, box, Vector2i.ZERO)
	for y in range(can.get_height()):
		for x in range(can.get_width()):
			var c: Color = can.get_pixel(x, y)
			if c.r < 0.2 and c.g < 0.2:
				can.set_pixel(x, y, Color(0, 0, 0, 0))
	return can


func _write_square(can: Image, bg: Color, target_w: int, dest: String) -> void:
	var scale := float(target_w) / float(can.get_width())
	var tw := target_w
	var th := int(round(float(can.get_height()) * scale))
	var scaled := can.duplicate()
	scaled.resize(tw, th, Image.INTERPOLATE_LANCZOS)
	var out := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	out.fill(bg)
	var ox := int(round((SIZE - tw) * 0.5))
	var oy := int(round((SIZE - th) * 0.5))
	for y in range(th):
		for x in range(tw):
			var c: Color = scaled.get_pixel(x, y)
			if c.a < 0.02:
				continue
			var px := ox + x
			var py := oy + y
			if px < 0 or py < 0 or px >= SIZE or py >= SIZE:
				continue
			out.set_pixel(px, py, Color(c.r, c.g, c.b, 1.0))
	var err := out.save_png(ProjectSettings.globalize_path(dest))
	if err != OK:
		push_error("make_icon: save failed %s %s" % [dest, err])
