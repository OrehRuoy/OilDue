#ifndef DATE_PICKER_H
#define DATE_PICKER_H

#include "core/version.h"

#if VERSION_MAJOR == 4
#include "core/object/class_db.h"
#include "core/object/object.h"
#include "core/string/ustring.h"
#else
#include "core/class_db.h"
#include "core/object.h"
#include "core/ustring.h"
#endif

#ifdef __OBJC__
@class GodotDatePicker;
#else
typedef void GodotDatePicker;
#endif

class DatePicker : public Object {
	GDCLASS(DatePicker, Object);

	static void _bind_methods();

	GodotDatePicker *godot_date_picker;

public:
	static DatePicker *get_singleton();

	void present(const String &ymd);
	void emit_picked(const String &ymd);
	void emit_cancelled();

	DatePicker();
	~DatePicker();
};

#endif
