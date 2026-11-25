class_name AppInfo
extends Object
## Store listing and feedback endpoints. Do not print or log WEB3FORMS_ACCESS_KEY.

const APP_STORE_ID := "6805591903"
const WRITE_REVIEW_URL := "https://apps.apple.com/app/id6805591903?action=write-review"
const WEB3FORMS_URL := "https://api.web3forms.com/submit"
const WEB3FORMS_ACCESS_KEY := "155fdb3e-b48e-4f9a-8f80-0bb9d9fdc470"


static func app_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "")).strip_edges()


static func ios_version() -> String:
	if OS.has_feature("ios"):
		return OS.get_version()
	return ""
