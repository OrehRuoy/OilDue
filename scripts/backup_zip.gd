extends RefCounted
class_name BackupZip

const READ_ERROR := "Couldn't read this backup. The garage on this phone was not changed."


static func write_zip(path: String, data_json_text: String, photos_dir: String) -> bool:
	if path.strip_edges() == "":
		return false
	var zip := ZIPPacker.new()
	if zip.open(path) != OK:
		return false
	if zip.start_file("garage.json") != OK:
		zip.close()
		return false
	if zip.write_file(data_json_text.to_utf8_buffer()) != OK:
		zip.close_file()
		zip.close()
		return false
	zip.close_file()
	_pack_photos(zip, photos_dir)
	return zip.close() == OK


static func read_zip(path: String) -> Dictionary:
	var fail := _fail()
	if path.strip_edges() == "":
		return fail
	if not FileAccess.file_exists(path):
		return fail
	var reader := ZIPReader.new()
	if reader.open(path) != OK:
		return fail
	var json_path := _garage_json_path(reader)
	if json_path == "":
		reader.close()
		return fail
	var json_bytes := reader.read_file(json_path)
	var json_text := json_bytes.get_string_from_utf8()
	var photos := _read_photos(reader)
	reader.close()
	if json_text.strip_edges() == "":
		return fail
	var json := JSON.new()
	if json.parse(json_text) != OK:
		return fail
	if typeof(json.data) != TYPE_DICTIONARY:
		return fail
	var payload: Dictionary = json.data
	if not payload.has("schema"):
		return fail
	if typeof(payload.get("vehicles", null)) != TYPE_ARRAY:
		return fail
	return {
		"ok": true,
		"error": "",
		"json_text": json_text,
		"photos": photos,
	}


static func _fail() -> Dictionary:
	return {
		"ok": false,
		"error": READ_ERROR,
		"json_text": "",
		"photos": {},
	}


static func _pack_photos(zip: ZIPPacker, photos_dir: String) -> void:
	if photos_dir.strip_edges() == "":
		return
	var dir := DirAccess.open(photos_dir)
	if dir == null:
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir():
			var file_path := "%s/%s" % [photos_dir.trim_suffix("/"), fname]
			var bytes := FileAccess.get_file_as_bytes(file_path)
			if zip.start_file("photos/%s" % fname) == OK:
				zip.write_file(bytes)
				zip.close_file()
		fname = dir.get_next()
	dir.list_dir_end()


static func _garage_json_path(reader: ZIPReader) -> String:
	for name in reader.get_files():
		var n := str(name).replace("\\", "/")
		if n == "garage.json" or n.ends_with("/garage.json"):
			return str(name)
	return ""


static func _read_photos(reader: ZIPReader) -> Dictionary:
	var photos := {}
	for name in reader.get_files():
		var n := str(name).replace("\\", "/")
		if not n.begins_with("photos/"):
			continue
		var base := n.get_file()
		if base == "" or base == ".":
			continue
		photos[base] = reader.read_file(str(name))
	return photos
