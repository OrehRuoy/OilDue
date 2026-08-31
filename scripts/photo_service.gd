extends Node

signal picked(src_path: String)
signal failed(message: String)

const PHOTOS_DIR := "user://photos"
const MAX_SIDE := 2048
const JPEG_QUALITY := 0.82
const INBOX_FILE := "_pick.jpg"
const SOURCE_PHOTO_LIBRARY := 1
const SOURCE_CAMERA_REAR := 4

# iOS PhotoPicker is GDScript-ready. The exported binary must include
# PhotoPicker PR #105 (Godot 4.6 root VC is nil without it). Do not vendor
# an xcframework in this pass. Never store a PHAsset / Photo Library id.

var _dialog: FileDialog


func _ready() -> void:
	_dialog = FileDialog.new()
	_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_dialog.use_native_dialog = true
	_dialog.title = "Pick a photo"
	_dialog.filters = PackedStringArray([
		"*.jpg, *.jpeg, *.png ; Images",
	])
	_dialog.visible = false
	_dialog.file_selected.connect(_on_file_selected)
	add_child(_dialog)


func ensure_photos_dir() -> void:
	var user_dir := DirAccess.open("user://")
	if user_dir == null:
		return
	user_dir.make_dir("photos")


func photo_path(filename: String) -> String:
	var name := filename.get_file().strip_edges()
	if name == "":
		return ""
	return "%s/%s" % [PHOTOS_DIR, name]


func load_texture(filename: String) -> Texture2D:
	var path := photo_path(filename)
	if path == "":
		return null
	if not FileAccess.file_exists(path):
		return null
	var img := Image.load_from_file(path)
	if img == null or img.is_empty():
		return null
	return ImageTexture.create_from_image(img)


func save_jpeg(src_path: String, dest_filename: String) -> bool:
	var dest_name := dest_filename.get_file().strip_edges()
	if src_path.strip_edges() == "" or dest_name == "":
		return false
	var img := Image.load_from_file(src_path)
	return save_image(img, dest_name)


func save_image(img: Image, dest_filename: String) -> bool:
	var dest_name := dest_filename.get_file().strip_edges()
	if img == null or img.is_empty() or dest_name == "":
		return false
	_downscale(img)
	ensure_photos_dir()
	var dest := photo_path(dest_name)
	if dest == "":
		return false
	return img.save_jpg(dest, JPEG_QUALITY) == OK


func pick_image() -> void:
	pick_library()


func pick_library() -> void:
	_present(SOURCE_PHOTO_LIBRARY)


func pick_camera() -> void:
	_present(SOURCE_CAMERA_REAR)


func _present(source: int) -> void:
	if Engine.has_singleton("PhotoPicker"):
		var picker := Engine.get_singleton("PhotoPicker")
		var cb := Callable(self, "_on_plugin_image")
		if not picker.is_connected("image_picked", cb):
			picker.connect("image_picked", cb)
		picker.call("present", source)
		return
	_dialog.popup_centered()


func _on_plugin_image(img: Image) -> void:
	if img == null or img.is_empty():
		failed.emit("Couldn't read that photo.")
		return
	if not save_image(img, INBOX_FILE):
		failed.emit("Couldn't read that photo.")
		return
	picked.emit(photo_path(INBOX_FILE))


func _on_file_selected(path: String) -> void:
	if path.strip_edges() == "":
		return
	picked.emit(path)


func _downscale(img: Image) -> void:
	var width := img.get_width()
	var height := img.get_height()
	var longest := maxi(width, height)
	if longest <= MAX_SIDE:
		return
	var nw := width
	var nh := height
	if width >= height:
		nw = MAX_SIDE
		nh = int(round(float(height) * float(MAX_SIDE) / float(width)))
	else:
		nh = MAX_SIDE
		nw = int(round(float(width) * float(MAX_SIDE) / float(height)))
	if nw < 1:
		nw = 1
	if nh < 1:
		nh = 1
	img.resize(nw, nh, Image.INTERPOLATE_LANCZOS)
