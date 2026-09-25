extends Control

const DueMath = preload("res://scripts/due_math.gd")
const SpendRollup = preload("res://scripts/spend_rollup.gd")

const COLOR_PRIMARY := Color("#F4EFE6")
const COLOR_MUTED := Color("#9A9388")


func _ready() -> void:
	var vehicle := GarageStore._current_vehicle()
	var name := str(vehicle.get("name", "")).strip_edges()
	if name == "":
		name = "This car"
	%CarLabel.text = name
	var roll := SpendRollup.rollup(vehicle)
	var rows: Array = roll.get("rows", [])
	if rows.is_empty():
		%TotalLabel.visible = false
		%EmptyLabel.visible = true
		%Breakdown.visible = false
		return
	%EmptyLabel.visible = false
	%TotalLabel.visible = true
	%Breakdown.visible = true
	%TotalLabel.text = DueMath.format_cents(int(roll.get("total_cents", 0)))
	for item in rows:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = item
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 12)
		var left := Label.new()
		left.text = str(row.get("label", ""))
		left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		left.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		left.add_theme_color_override("font_color", COLOR_PRIMARY)
		left.add_theme_font_size_override("font_size", 17)
		var right := Label.new()
		right.text = DueMath.format_cents(int(row.get("cents", 0)))
		right.add_theme_color_override("font_color", COLOR_MUTED)
		right.add_theme_font_size_override("font_size", 17)
		line.add_child(left)
		line.add_child(right)
		%Rows.add_child(line)
