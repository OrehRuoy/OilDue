extends RefCounted
class_name ServiceIcons

const OIL := preload("res://assets/glyphs/svc_oil.png")
const TIRE := preload("res://assets/glyphs/svc_tire.png")
const BRAKE := preload("res://assets/glyphs/svc_brake.png")
const COOLANT := preload("res://assets/glyphs/svc_coolant.png")
const SPARK := preload("res://assets/glyphs/svc_spark.png")
const BATTERY := preload("res://assets/glyphs/svc_battery.png")
const WIPER := preload("res://assets/glyphs/svc_wiper.png")
const FILTER := preload("res://assets/glyphs/svc_filter.png")
const WRENCH := preload("res://assets/glyphs/svc_wrench.png")
const CAR := preload("res://assets/glyphs/svc_car.png")


static func texture_for(type_id: String) -> Texture2D:
	match type_id:
		"oil_change":
			return OIL
		"tire_rotation":
			return TIRE
		"brake_inspect":
			return BRAKE
		"coolant":
			return COOLANT
		"spark_plugs":
			return SPARK
		"battery":
			return BATTERY
		"wipers":
			return WIPER
		"air_filter", "cabin_filter":
			return FILTER
		_:
			return WRENCH
