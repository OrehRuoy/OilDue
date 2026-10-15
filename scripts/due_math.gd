extends RefCounted
class_name DueMath

const MONTH_DAYS := [0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]


static func parse_ymd(s: String) -> Dictionary:
	if s.length() != 10:
		return {}
	if s[4] != "-" or s[7] != "-":
		return {}
	var year_s := s.substr(0, 4)
	var month_s := s.substr(5, 2)
	var day_s := s.substr(8, 2)
	if not year_s.is_valid_int() or not month_s.is_valid_int() or not day_s.is_valid_int():
		return {}
	var year := int(year_s)
	var month := int(month_s)
	var day := int(day_s)
	if month < 1 or month > 12:
		return {}
	var dim := days_in_month(year, month)
	if day < 1 or day > dim:
		return {}
	return {"year": year, "month": month, "day": day}


static func format_ymd(year: int, month: int, day: int) -> String:
	return "%04d-%02d-%02d" % [year, month, day]


const MONTH_ABBR := ["", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]


static func format_display_date(ymd: String) -> String:
	var parsed := parse_ymd(ymd)
	if parsed.is_empty():
		return ""
	var month := int(parsed.month)
	if month < 1 or month > 12:
		return ""
	var day := int(parsed.day)
	var year := int(parsed.year)
	var month_name := TranslationServer.translate(MONTH_ABBR[month])
	var loc := TranslationServer.get_locale()
	if loc.begins_with("de"):
		return "%d. %s %d" % [day, month_name, year]
	if loc.begins_with("pt"):
		return "%d de %s de %d" % [day, month_name, year]
	if loc.begins_with("fr") or loc.begins_with("es"):
		return "%d %s %d" % [day, month_name, year]
	return "%s %d, %d" % [month_name, day, year]


static func days_in_month(year: int, month: int) -> int:
	if month < 1 or month > 12:
		return 0
	if month == 2 and _is_leap(year):
		return 29
	return MONTH_DAYS[month]


static func add_months_ymd(ymd: String, months: int) -> String:
	var parsed := parse_ymd(ymd)
	if parsed.is_empty():
		return ""
	var year := int(parsed.year)
	var month := int(parsed.month) + months
	while month > 12:
		month -= 12
		year += 1
	while month < 1:
		month += 12
		year -= 1
	var day := int(parsed.day)
	var dim := days_in_month(year, month)
	if day > dim:
		day = dim
	return format_ymd(year, month, day)


static func compare_ymd(a: String, b: String) -> int:
	var pa := parse_ymd(a)
	var pb := parse_ymd(b)
	if pa.is_empty() or pb.is_empty():
		return 0
	if int(pa.year) < int(pb.year):
		return -1
	if int(pa.year) > int(pb.year):
		return 1
	if int(pa.month) < int(pb.month):
		return -1
	if int(pa.month) > int(pb.month):
		return 1
	if int(pa.day) < int(pb.day):
		return -1
	if int(pa.day) > int(pb.day):
		return 1
	return 0


static func days_until(from_ymd: String, to_ymd: String) -> int:
	var from_p := parse_ymd(from_ymd)
	var to_p := parse_ymd(to_ymd)
	if from_p.is_empty() or to_p.is_empty():
		return 0
	return _ordinal(int(to_p.year), int(to_p.month), int(to_p.day)) - _ordinal(
		int(from_p.year), int(from_p.month), int(from_p.day)
	)


static func compute_next_miles(last_miles: int, interval_miles: int) -> int:
	if interval_miles <= 0:
		return 0
	return last_miles + interval_miles


static func compute_next_date(last_date: String, interval_months: int) -> String:
	if interval_months <= 0:
		return ""
	if parse_ymd(last_date).is_empty():
		return ""
	return add_months_ymd(last_date, interval_months)


static func status(
	today: String,
	odometer: int,
	next_date: String,
	next_miles: int,
	lead_days: int,
	interval_miles: int,
	interval_months: int
) -> String:
	var date_s := next_date.strip_edges()
	var has_date := not parse_ymd(date_s).is_empty()
	if not has_date and next_miles <= 0:
		return "not_set"
	var overdue := false
	if interval_months > 0 and has_date and compare_ymd(today, date_s) >= 0:
		overdue = true
	if interval_miles > 0 and next_miles > 0 and odometer >= next_miles:
		overdue = true
	if overdue:
		return "overdue"
	if interval_months > 0 and has_date:
		var until := days_until(today, date_s)
		if until > 0 and until <= lead_days:
			return "due_soon"
	if interval_miles > 0 and next_miles > 0:
		var remaining := next_miles - odometer
		if remaining > 0 and remaining <= due_soon_miles():
			return "due_soon"
	return "ok"


const MI_TO_KM := 1.609344
const MI_COUNTRIES := ["US", "GB", "LR", "MM", "AS", "GU", "MP", "PR", "UM", "VI"]


static func due_soon_miles() -> int:
	if distance_unit() == "km":
		return display_to_miles(800, "km")
	return 500


static func distance_unit() -> String:
	var raw := str(GarageStore.data.get("distance_unit", "mi")).strip_edges()
	return "km" if raw == "km" else "mi"


static func country_code(locale: String) -> String:
	var raw := locale.strip_edges().replace("-", "_")
	if not raw.contains("_"):
		return ""
	return raw.split("_")[-1].to_upper()


static func unit_for_locale(locale: String) -> String:
	var country := country_code(locale)
	if country == "":
		return "mi"
	if MI_COUNTRIES.has(country):
		return "mi"
	return "km"


static func miles_to_display(miles: int, unit: String = "") -> int:
	var use := unit if unit == "mi" or unit == "km" else distance_unit()
	if miles < 0:
		miles = 0
	if use != "km":
		return miles
	return int(round(float(miles) * MI_TO_KM))


static func display_to_miles(shown: int, unit: String = "") -> int:
	var use := unit if unit == "mi" or unit == "km" else distance_unit()
	if shown < 0:
		shown = 0
	if use != "km":
		return shown
	return int(round(float(shown) / MI_TO_KM))


static func format_distance(stored_miles: int) -> String:
	var unit := distance_unit()
	return "%s %s" % [format_miles(miles_to_display(stored_miles, unit)), unit]


const CURRENCY_CODES := [
	"USD", "CAD", "MXN", "BRL", "EUR", "GBP", "CHF", "AUD", "NZD", "INR",
	"SGD", "ZAR", "JPY", "KRW", "SEK", "NOK", "DKK", "PLN", "TRY", "IDR",
]
const REGION_CURRENCY := {
	"US": "USD",
	"CA": "CAD",
	"MX": "MXN",
	"BR": "BRL",
	"DE": "EUR",
	"FR": "EUR",
	"ES": "EUR",
	"IT": "EUR",
	"NL": "EUR",
	"BE": "EUR",
	"AT": "EUR",
	"IE": "EUR",
	"PT": "EUR",
	"FI": "EUR",
	"GR": "EUR",
	"LU": "EUR",
	"SK": "EUR",
	"SI": "EUR",
	"EE": "EUR",
	"LV": "EUR",
	"LT": "EUR",
	"MT": "EUR",
	"CY": "EUR",
	"HR": "EUR",
	"GB": "GBP",
	"CH": "CHF",
	"AU": "AUD",
	"NZ": "NZD",
	"IN": "INR",
	"SG": "SGD",
	"ZA": "ZAR",
	"JP": "JPY",
	"KR": "KRW",
	"SE": "SEK",
	"NO": "NOK",
	"DK": "DKK",
	"PL": "PLN",
	"TR": "TRY",
	"ID": "IDR",
}
# suffix: symbol after the number. space: gap between number and symbol.
# comma: decimal comma and dot thousands. zero: no minor units (round to the major unit).
const CURRENCY_INFO := {
	"USD": {"symbol": "$", "suffix": false, "space": false, "comma": false, "zero": false},
	"CAD": {"symbol": "CA$", "suffix": false, "space": false, "comma": false, "zero": false},
	"MXN": {"symbol": "MX$", "suffix": false, "space": false, "comma": false, "zero": false},
	"BRL": {"symbol": "R$", "suffix": false, "space": true, "comma": true, "zero": false},
	"EUR": {"symbol": "€", "suffix": true, "space": true, "comma": true, "zero": false},
	"GBP": {"symbol": "£", "suffix": false, "space": false, "comma": false, "zero": false},
	"CHF": {"symbol": "CHF", "suffix": false, "space": true, "comma": false, "zero": false},
	"AUD": {"symbol": "A$", "suffix": false, "space": false, "comma": false, "zero": false},
	"NZD": {"symbol": "NZ$", "suffix": false, "space": false, "comma": false, "zero": false},
	"INR": {"symbol": "₹", "suffix": false, "space": false, "comma": false, "zero": false},
	"SGD": {"symbol": "S$", "suffix": false, "space": false, "comma": false, "zero": false},
	"ZAR": {"symbol": "R", "suffix": false, "space": false, "comma": false, "zero": false},
	"JPY": {"symbol": "¥", "suffix": false, "space": false, "comma": false, "zero": true},
	"KRW": {"symbol": "₩", "suffix": false, "space": false, "comma": false, "zero": true},
	"SEK": {"symbol": "kr", "suffix": true, "space": true, "comma": true, "zero": false},
	"NOK": {"symbol": "kr", "suffix": true, "space": true, "comma": true, "zero": false},
	"DKK": {"symbol": "kr", "suffix": true, "space": true, "comma": true, "zero": false},
	"PLN": {"symbol": "zł", "suffix": true, "space": true, "comma": true, "zero": false},
	"TRY": {"symbol": "₺", "suffix": false, "space": false, "comma": true, "zero": false},
	"IDR": {"symbol": "Rp", "suffix": false, "space": true, "comma": true, "zero": false},
}


static func currency_for_locale(locale: String) -> String:
	var country := country_code(locale)
	if REGION_CURRENCY.has(country):
		return str(REGION_CURRENCY[country])
	return "USD"


static func currency_code() -> String:
	var raw := str(GarageStore.data.get("currency", "USD")).strip_edges().to_upper()
	if CURRENCY_INFO.has(raw):
		return raw
	return "USD"


static func known_currency(code: String) -> bool:
	return CURRENCY_INFO.has(code.strip_edges().to_upper())


static func currency_in_label(label: String) -> String:
	var open := label.rfind("(")
	var close := label.rfind(")")
	if open < 0 or close <= open:
		return ""
	var code := label.substr(open + 1, close - open - 1).strip_edges().to_upper()
	if CURRENCY_INFO.has(code):
		return code
	return ""


static func format_cents(cents: int, code: String = "") -> String:
	var info := _currency_info(code)
	var n := cents
	if n < 0:
		n = 0
	var comma_dec: bool = info["comma"]
	var body := ""
	if info["zero"]:
		var major := int(round(float(n) / 100.0))
		var sep := "." if comma_dec else ","
		body = _group_digits(str(major), sep)
	else:
		var major_i := n / 100
		var rem := n % 100
		var sep := "." if comma_dec else ","
		var dec := "," if comma_dec else "."
		body = "%s%s%02d" % [_group_digits(str(major_i), sep), dec, rem]
	var symbol := str(info["symbol"])
	var gap := " " if info["space"] else ""
	if info["suffix"]:
		return body + gap + symbol
	return symbol + gap + body


static func format_cost_input(cents: int, code: String = "") -> String:
	if cents <= 0:
		return ""
	var info := _currency_info(code)
	if info["zero"]:
		return str(int(round(float(cents) / 100.0)))
	var major := cents / 100
	var rem := cents % 100
	if rem == 0:
		return str(major)
	var dec := "," if info["comma"] else "."
	return "%d%s%02d" % [major, dec, rem]


static func parse_cents(raw: String) -> Dictionary:
	var trimmed := raw.strip_edges()
	if trimmed == "":
		return {"ok": true, "cents": 0}
	var s := ""
	for i in range(trimmed.length()):
		var c := trimmed[i]
		if (c >= "0" and c <= "9") or c == "," or c == ".":
			s += c
	if s == "":
		return {"ok": false, "cents": 0}
	var last_comma := s.rfind(",")
	var last_dot := s.rfind(".")
	var dec := -1
	if last_comma >= 0 and last_dot >= 0:
		dec = last_comma if last_comma > last_dot else last_dot
	elif last_comma >= 0:
		var frac := s.substr(last_comma + 1)
		if frac.length() >= 1 and frac.length() <= 2 and frac.is_valid_int():
			dec = last_comma
	elif last_dot >= 0:
		dec = last_dot
	var major_s := s
	var minor_s := ""
	if dec >= 0:
		major_s = s.substr(0, dec)
		minor_s = s.substr(dec + 1)
	major_s = major_s.replace(",", "").replace(".", "")
	minor_s = minor_s.replace(",", "").replace(".", "")
	if major_s == "":
		major_s = "0"
	if not major_s.is_valid_int():
		return {"ok": false, "cents": 0}
	if minor_s.length() > 2:
		minor_s = minor_s.substr(0, 2)
	elif minor_s.length() == 1:
		minor_s += "0"
	elif minor_s.length() == 0:
		minor_s = "00"
	if not minor_s.is_valid_int():
		return {"ok": false, "cents": 0}
	return {"ok": true, "cents": int(major_s) * 100 + int(minor_s)}


static func _currency_info(code: String) -> Dictionary:
	var use := code.strip_edges().to_upper()
	if use == "":
		use = currency_code()
	if not CURRENCY_INFO.has(use):
		use = "USD"
	return CURRENCY_INFO[use]


static func _group_digits(digits: String, sep: String) -> String:
	var out := ""
	var count := 0
	for i in range(digits.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			out = sep + out
		out = digits[i] + out
		count += 1
	return out


static func format_miles(value: int) -> String:
	var n := value
	if n < 0:
		n = 0
	var digits := str(n)
	var out := ""
	var count := 0
	for i in range(digits.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			out = "," + out
		out = digits[i] + out
		count += 1
	return out


static func _is_leap(year: int) -> bool:
	return year % 4 == 0 and (year % 100 != 0 or year % 400 == 0)


static func _ordinal(year: int, month: int, day: int) -> int:
	var n := day
	var y := 1
	while y <= year - 1:
		n += 366 if _is_leap(y) else 365
		y += 1
	var m := 1
	while m <= month - 1:
		n += days_in_month(year, m)
		m += 1
	return n
