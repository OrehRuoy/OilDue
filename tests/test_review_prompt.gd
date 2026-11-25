extends Control


func _ready() -> void:
	var fail := _run()
	if fail == "":
		%Result.text = "PASS"
	else:
		%Result.text = "FAIL: %s" % fail
	print(%Result.text)
	get_tree().quit(0 if fail == "" else 1)


func _run() -> String:
	var snap: Dictionary = GarageStore.data.duplicate(true)
	var fail := _cases()
	GarageStore.data = snap
	GarageStore.save()
	return fail


func _cases() -> String:
	var fail := _expect(AppInfo.APP_STORE_ID == "6805591903", "app store id")
	if fail != "":
		return fail
	fail = _expect(
		AppInfo.WRITE_REVIEW_URL == "https://apps.apple.com/app/id6805591903?action=write-review",
		"write review url"
	)
	if fail != "":
		return fail
	fail = _expect(AppInfo.WRITE_REVIEW_URL.contains(AppInfo.APP_STORE_ID), "url contains id")
	if fail != "":
		return fail
	fail = _expect(AppInfo.WEB3FORMS_URL == "https://api.web3forms.com/submit", "web3forms url")
	if fail != "":
		return fail
	fail = _expect(AppInfo.WEB3FORMS_ACCESS_KEY.length() == 36, "web3forms key stored")
	if fail != "":
		return fail
	fail = _expect(AppInfo.app_version() == "1.0.5", "marketing version 1.0.5")
	if fail != "":
		return fail
	var presets := FileAccess.get_file_as_string("res://export_presets.cfg")
	fail = _expect(presets.contains("application/short_version=\"1.0.5\""), "export short version")
	if fail != "":
		return fail
	fail = _expect(presets.contains("application/version=\"1.0.4\""), "export build")
	if fail != "":
		return fail
	fail = _expect(presets.contains("plugins/StoreKit=true"), "StoreKit plugin enabled")
	if fail != "":
		return fail
	var workflow := FileAccess.get_file_as_string("res://.github/workflows/ios-testflight.yml")
	fail = _expect(
		workflow.contains("ios/plugins/storekit/StoreKit.release.xcframework"),
		"workflow checks StoreKit.release.xcframework"
	)
	if fail != "":
		return fail
	var build_sh := FileAccess.get_file_as_string("res://native/build_plugins.sh")
	fail = _expect(build_sh.contains("pack_plugin \"StoreKit\""), "build script packs StoreKit")
	if fail != "":
		return fail
	fail = _expect(build_sh.contains(".release.xcframework"), "build script writes release xcframework")
	if fail != "":
		return fail

	var fresh := {
		"use_days": ["2026-11-25"],
		"logged_services": 1,
		"last_shown_date": "",
		"last_shown_version": "",
		"completed": false,
	}
	fail = _expect(not ReviewPrompt.can_show(fresh, "2026-11-25", "1.0.5"), "one day and one log waits")
	if fail != "":
		return fail
	var two_logs := fresh.duplicate(true)
	two_logs["logged_services"] = 2
	fail = _expect(ReviewPrompt.can_show(two_logs, "2026-11-25", "1.0.5"), "two logs can show")
	if fail != "":
		return fail
	var two_days := ReviewPrompt.add_use_day(fresh, "2026-11-26")
	fail = _expect(ReviewPrompt.use_day_count(two_days) == 2, "second calendar day counted once")
	if fail != "":
		return fail
	fail = _expect(ReviewPrompt.can_show(two_days, "2026-11-26", "1.0.5"), "two days and one log can show")
	if fail != "":
		return fail
	var again := ReviewPrompt.add_use_day(two_days, "2026-11-26")
	fail = _expect(ReviewPrompt.use_day_count(again) == 2, "same day is not a new day")
	if fail != "":
		return fail

	fail = _expect(
		not ReviewPrompt.scene_allows("any", "res://scenes/last_oil.tscn"),
		"onboarding last oil does not show"
	)
	if fail != "":
		return fail
	fail = _expect(
		not ReviewPrompt.scene_allows("any", "res://scenes/vehicle_add.tscn"),
		"onboarding add car does not show"
	)
	if fail != "":
		return fail
	fail = _expect(
		not ReviewPrompt.scene_allows("any", "res://scenes/more_services.tscn"),
		"onboarding more services does not show"
	)
	if fail != "":
		return fail
	fail = _expect(
		ReviewPrompt.scene_allows("garage", "res://scenes/garage.tscn"),
		"first-run oil setup shows on the garage"
	)
	if fail != "":
		return fail
	fail = _expect(
		not ReviewPrompt.scene_allows("garage", "res://scenes/service_list.tscn"),
		"first-run oil setup waits for the garage"
	)
	if fail != "":
		return fail
	fail = _expect(
		ReviewPrompt.scene_allows("any", "res://scenes/service_list.tscn"),
		"a later log can show on the history screen"
	)
	if fail != "":
		return fail

	var shown := ReviewPrompt.with_shown(two_logs, "2026-11-25", "1.0.5")
	fail = _expect(shown["completed"] == false, "showing does not complete")
	if fail != "":
		return fail
	fail = _expect(not ReviewPrompt.can_show(shown, "2026-11-25", "1.0.5"), "once per version")
	if fail != "":
		return fail
	fail = _expect(
		not ReviewPrompt.can_show(shown, "2026-12-20", "1.0.6"),
		"new version still waits 30 days"
	)
	if fail != "":
		return fail
	fail = _expect(
		ReviewPrompt.can_show(shown, "2026-12-25", "1.0.6"),
		"next version after 30 days"
	)
	if fail != "":
		return fail
	var done := ReviewPrompt.with_completed(two_logs, "2026-11-25", "1.0.5")
	fail = _expect(done["completed"] == true, "yes or no completes")
	if fail != "":
		return fail
	fail = _expect(not ReviewPrompt.can_show(done, "2027-06-01", "9.0.0"), "completed stays hidden")
	if fail != "":
		return fail
	var snoozed := ReviewPrompt.with_shown(two_logs, "2026-11-25", "1.0.5")
	fail = _expect(snoozed["completed"] == false, "x does not complete")
	if fail != "":
		return fail
	fail = _expect(str(snoozed["last_shown_date"]) == "2026-11-25", "x stores last shown date")
	if fail != "":
		return fail
	fail = _expect(str(snoozed["last_shown_version"]) == "1.0.5", "x stores last shown version")
	if fail != "":
		return fail
	var before: Dictionary = GarageStore.data.get("review", {}).duplicate(true)
	ReviewPrompt.debug_show_card()
	var scene := ReviewPrompt.get_tree().current_scene
	var card := scene.get_node_or_null("EnjoyingCard")
	fail = _expect(card != null, "debug card builds")
	if fail != "":
		return fail
	fail = _expect(str(card.get_node("SafeMargin").get_child(0).get_child(0).get_child(0).get_child(1).text) == "Enjoying Oil Due?", "card title")
	if fail != "":
		return fail
	card.queue_free()
	ReviewPrompt.debug_show_feedback()
	var form := scene.get_node_or_null("FeedbackForm")
	fail = _expect(form != null, "debug form builds")
	if fail != "":
		return fail
	var send := _find_button(form, "Send")
	fail = _expect(send != null and send.disabled, "send starts disabled")
	if fail != "":
		return fail
	form.queue_free()
	var after: Dictionary = GarageStore.data.get("review", {})
	fail = _expect(str(after.get("last_shown_version", "")) == str(before.get("last_shown_version", "")), "debug show does not record a show")
	if fail != "":
		return fail
	fail = _expect(bool(after.get("completed", false)) == bool(before.get("completed", false)), "debug show does not complete")
	return fail


func _expect(ok: bool, message: String) -> String:
	if ok:
		return ""
	return message


func _find_button(node: Node, label: String) -> Button:
	if node is Button and str((node as Button).text) == label:
		return node as Button
	for child in node.get_children():
		var found := _find_button(child, label)
		if found != null:
			return found
	return null
