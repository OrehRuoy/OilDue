extends Control

const PanScroll = preload("res://scripts/pan_scroll.gd")


func _ready() -> void:
	PanScroll.wire($Margin/PageHost/Column/HelpScroll/GroupHelp, func() -> void: pass)
