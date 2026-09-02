#include "date_picker_module.h"

#include "core/version.h"

#if VERSION_MAJOR == 4
#include "core/config/engine.h"
#include "core/object/class_db.h"
#else
#include "core/engine.h"
#endif

#include "date_picker.h"

DatePicker *date_picker;

void godot_datepicker_init() {
	GDREGISTER_CLASS(DatePicker);
	date_picker = memnew(DatePicker);
	Engine::get_singleton()->add_singleton(Engine::Singleton("DatePicker", date_picker));
}

void godot_datepicker_deinit() {
	if (date_picker) {
		memdelete(date_picker);
	}
}
