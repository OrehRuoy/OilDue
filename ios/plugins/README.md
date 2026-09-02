# iOS plugin binaries

- `storekit/` — Taptico Godot 4.6 StoreKit layout. CI (or macOS) builds `StoreKit.xcframework` from `native/godot-storekit`.
- `photopicker/` — godot-ios-plugins PhotoPicker with PR #105 (Godot 4.6 view controller). CI builds `PhotoPicker.xcframework` from `native/godot-photopicker`.
- `datepicker/` — in-tree `UIDatePicker` with PR #105 view controller. CI builds `DatePicker.xcframework` from `native/godot-datepicker`.
- `NotificationSchedulerPlugin/` — vendored from Notification Scheduler iOS v5.2 (Godot 4.6). Do not use v6.0 (that is 4.7).

Do not commit StoreKit/PhotoPicker/DatePicker xcframeworks; build them with `./native/build_plugins.sh` on macOS. Notification Scheduler xcframeworks are vendored from the 4.6 release zip.

Enable in **Project → Export → iOS → Plugins**: StoreKit, NotificationSchedulerPlugin, PhotoPicker, DatePicker.
