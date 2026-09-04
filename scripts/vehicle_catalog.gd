extends RefCounted
class_name VehicleCatalog

const PATH := "res://data/vehicle_makes.json"

static var _loaded := false
static var _makes: PackedStringArray = PackedStringArray()
static var _models_by_make: Dictionary = {}
static var _canonical_make: Dictionary = {}


static func makes() -> PackedStringArray:
	_ensure()
	return _makes.duplicate()


static func models(make: String) -> PackedStringArray:
	_ensure()
	var key := make.strip_edges().to_lower()
	if key == "" or not _models_by_make.has(key):
		return PackedStringArray()
	var rows: PackedStringArray = _models_by_make[key]
	return rows.duplicate()


static func has_make(make: String) -> bool:
	_ensure()
	return _canonical_make.has(make.strip_edges().to_lower())


static func has_model(make: String, model: String) -> bool:
	var want := model.strip_edges().to_lower()
	if want == "":
		return false
	for item in models(make):
		if item.to_lower() == want:
			return true
	return false


static func canonical_make(make: String) -> String:
	_ensure()
	var raw := make.strip_edges()
	if raw == "":
		return ""
	var key := raw.to_lower()
	if _canonical_make.has(key):
		return str(_canonical_make[key])
	return raw


static func canonical_model(make: String, model: String) -> String:
	var raw := model.strip_edges()
	if raw == "":
		return ""
	var want := raw.to_lower()
	for item in models(make):
		if item.to_lower() == want:
			return item
	return raw


static func filter(items: PackedStringArray, query: String) -> PackedStringArray:
	var q := query.strip_edges().to_lower()
	if q == "":
		return items.duplicate()
	var prefix := PackedStringArray()
	var contains := PackedStringArray()
	for item in items:
		var low := str(item).to_lower()
		if low.begins_with(q):
			prefix.append(item)
		elif low.contains(q):
			contains.append(item)
	var out := prefix
	for item in contains:
		out.append(item)
	return out


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	_makes = PackedStringArray()
	_models_by_make = {}
	_canonical_make = {}
	if not FileAccess.file_exists(PATH):
		push_warning("VehicleCatalog: missing %s" % PATH)
		return
	var text := FileAccess.get_file_as_string(PATH)
	if text.strip_edges() == "":
		return
	var json := JSON.new()
	if json.parse(text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		push_error("VehicleCatalog: parse failed")
		return
	var data: Dictionary = json.data
	var names: Array = data.keys()
	names.sort()
	for name in names:
		var make_s := str(name).strip_edges()
		if make_s == "":
			continue
		var key := make_s.to_lower()
		var models_out := PackedStringArray()
		var seen := {}
		var raw_models: Variant = data[name]
		if typeof(raw_models) == TYPE_ARRAY:
			var model_names: Array = []
			for item in raw_models:
				var model_s := str(item).strip_edges()
				if model_s == "" or seen.has(model_s.to_lower()):
					continue
				seen[model_s.to_lower()] = true
				model_names.append(model_s)
			model_names.sort()
			for model_s in model_names:
				models_out.append(model_s)
		_makes.append(make_s)
		_canonical_make[key] = make_s
		_models_by_make[key] = models_out
