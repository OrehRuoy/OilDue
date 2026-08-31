extends Control

const SRC_PNG := "user://test-photo-src.png"
const DEST_JPG := "test-photo-dest.jpg"


func _ready() -> void:
	var fail := _run()
	if fail == "":
		%Result.text = "PASS"
	else:
		%Result.text = "FAIL: %s" % fail
	print(%Result.text)


func _run() -> String:
	var img := Image.create(3000, 1500, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.2, 0.4, 0.8))
	var fail := _expect(img.save_png(SRC_PNG) == OK, "write temp png")
	if fail != "":
		_cleanup()
		return fail
	fail = _expect(PhotoService.save_jpeg(SRC_PNG, DEST_JPG), "save_jpeg")
	if fail != "":
		_cleanup()
		return fail
	var dest_path := PhotoService.photo_path(DEST_JPG)
	fail = _expect(FileAccess.file_exists(dest_path), "dest jpeg exists")
	if fail != "":
		_cleanup()
		return fail
	var loaded := Image.load_from_file(dest_path)
	fail = _expect(loaded != null and not loaded.is_empty(), "load dest jpeg")
	if fail != "":
		_cleanup()
		return fail
	var width := loaded.get_width()
	var height := loaded.get_height()
	fail = _expect(width <= 2048, "width <= 2048")
	if fail != "":
		_cleanup()
		return fail
	fail = _expect(height <= 1024, "height <= 1024")
	if fail != "":
		_cleanup()
		return fail
	fail = _expect(maxi(width, height) == 2048, "longest side == 2048")
	if fail != "":
		_cleanup()
		return fail
	fail = _expect(PhotoService.load_texture("nope.jpg") == null, "missing file is null")
	if fail != "":
		_cleanup()
		return fail
	_cleanup()
	return ""


func _cleanup() -> void:
	if FileAccess.file_exists(SRC_PNG):
		DirAccess.remove_absolute(SRC_PNG)
	var dest := PhotoService.photo_path(DEST_JPG)
	if dest != "" and FileAccess.file_exists(dest):
		DirAccess.remove_absolute(dest)


func _expect(ok: bool, message: String) -> String:
	if ok:
		return ""
	return message
