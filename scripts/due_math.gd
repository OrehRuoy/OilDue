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
	return "%s %d, %d" % [MONTH_ABBR[month], int(parsed.day), int(parsed.year)]


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
	var overdue := false
	if interval_months > 0 and next_date != "" and compare_ymd(today, next_date) >= 0:
		overdue = true
	if interval_miles > 0 and next_miles > 0 and odometer >= next_miles:
		overdue = true
	if overdue:
		return "overdue"
	if interval_months > 0 and next_date != "":
		var until := days_until(today, next_date)
		if until > 0 and until <= lead_days:
			return "due_soon"
	if interval_miles > 0 and next_miles > 0:
		var remaining := next_miles - odometer
		if remaining > 0 and remaining <= 500:
			return "due_soon"
	return "ok"


static func format_cents(cents: int) -> String:
	var n := cents
	if n < 0:
		n = 0
	var dollars := n / 100
	var rem := n % 100
	return "$%d.%02d" % [dollars, rem]


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
