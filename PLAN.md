# Oil Due

Local car maintenance log. Not CARFAX.

- Bundle ID: `com.oildue.app`
- iOS first. No Play listing in v1.
- Free Get. Later: one non-consumable IAP `unlock_oil_due` at $2.99.
- No ads, no Firebase, no analytics, no accounts, no iCloud, no widgets.
- GDScript only. Godot 4.6.3. Renderer Mobile.

## Data conventions

- Dates stored as `YYYY-MM-DD` strings. Never unix timestamps.
- Money stored as integer cents. Never floats.
- `user://garage.json` schema integer, only goes up. Unknown keys pass through migrate.
- Atomic write to `garage.json.tmp`, then rename, then copy to `user://backups/` (keep 10).

## Day 3

Garage home UI. Header, service rows, miles popup, Gear / row navigation.

## Day 4

`GarageStore` loads/saves `user://garage.json`. First launch seeds 2018 Honda Civic. Update miles persists.

## Day 5

`DueMath` civil calendar (`YYYY-MM-DD`, no unix). Garage status from `DueMath.status`. Log a job on `service_edit`; `log_service` rolls next due and saves. History ids `h_01`….

## Day 6

Service history list (date, miles, `format_cents`). Log returns to the list. Header name/photo opens vehicle edit (`year`, `make`, `model`, `name`, `vin`, `plate`, `tire_size`, `oil_filter`). No PhotoPicker.

## Day 7

Garage **Add** appends a template (or Custom) via `add_service`. Gear opens Settings: lead days 3/7/14, Help (six sentences), version, privacy line. Does not reseed. No PhotoPicker, CSV, IAP, or notifications this pass.

## Day 8

VMT CSV import. Fingerprint equipment vs maintenance (else generic). Preview then merge onto the current car only — no new cars. Odometer never lowered. Jobs append history (`h_*`) without `log_service`; `last_*` / `next_*` from newest history. F6 `test_csv_import`. PhotoPicker still deferred. Second car waits for Unlock.

## Day 9

CSV job export (`jobs_csv`) and zip backup/restore (`ZIPPacker` / `ZIPReader`). Restore parses JSON before overwrite. F6 `test_csv_export`. PhotoPicker still deferred. `UIFileSharingEnabled` / Files app is an iOS export-preset job later, not this pass.

## Day 10

Editor/desktop photos: `PhotoService` copies JPEGs into `user://photos/` (filenames only in JSON). Longest side 2048, quality 0.82. Garage header and vehicle edit show the car photo; log sheet Receipt waits until Log; history thumbs if the file exists. F6 `test_photo_service`. iOS PhotoPicker (issue #99 / PR #105) is **not** done on device.

## Day 11

Edit a service’s interval miles/months (`update_service_intervals` recomputes `next_*` from last job). Delete a service with confirm; history rows for that service go with it. JPEGs are not deleted this pass. No vehicle delete.

## Day 12

Second car behind an Unlock placeholder. `add_vehicle` ids `v_02`… never reuse. Garage uses selected else primary; a name switcher shows when more than one car exists. Settings debug **Pretend unlocked**. Restore purchases is a stub (`StoreKit not wired yet.`). `unlocked` in JSON is a cache. StoreKit / notifications / iOS PhotoPicker still deferred. Second car is in.

## Day 13

Dark utility polish: project theme (`assets/theme.tres`) — background `#1C1C1E`, surface `#2C2C2E`, primary `#F2F2F7`, secondary `#8E8E93`, Overdue `#FF453A`, Due soon / accent `#FF9F0A`, OK `#30D158`. Huge status words on garage rows. App icon `assets/icon_1024.png` (opaque oil drop, no text). That PNG is the App Store 1024; export preset later.

## Day 14

Visual pass: white oil-can app icon (tiny amber due-dot), glyph Gear/Plus (not words), iOS grouped inset lists with hairlines. Ghost buttons, not amber pills. Plugins still deferred.

## Day 15

iOS grouped layout: compact garage header, due subtitles, Settings as left-label / right-value groups, extra service templates. Icon parked. Plugins still deferred.

## Day 16

AutoZone/CarMax utility. Photo-tile switcher if 2+ cars. Stroke glyphs. Human dates. Tighter empty/history. Looks still open next session.

## Day 17

Lauren PNG service icons; matching photo/placeholder tiles + name + red ring; warm night-garage background.

## Day 18

Dark-gray outlined Lauren glyphs (no status modulate); photos clipped inside the selected ring; garage_night.jpg + dim overlay.

## Day 19

Full-bleed KEEP_ASPECT_COVERED night-bay (no side bars) + warm-gray sweep on all screens. Icon parked. Plugins still deferred.

## Day 20

Vehicle-edit wide hero photo (clip COVER); Choose / Take / Remove sheet; PhotoService editor FileDialog + iOS PhotoPicker singleton if present. Night-bay still garage-only.

Privacy strings for a future iOS export preset (do not add `NSPhotoLibraryAddUsageDescription`):

- `NSPhotoLibraryUsageDescription`: Oil Due uses a photo you pick for the car or a receipt. Photos stay on this iPhone.
- `NSCameraUsageDescription`: Take a photo of the car or a paper receipt. Photos stay on this iPhone.

The exported binary must include PhotoPicker PR #105 (Godot 4.6 root VC is nil without it). Icon parked.

## Never add

Fuel log, VIN decode, NHTSA, shop directory, family sharing, CARFAX, ads, subscriptions, Firebase, Play listing.

## Deferred

iOS PhotoPicker plugin **binary** (PR #105; GDScript branch is in), local notifications, StoreKit/IAP, GitHub Actions iOS signing. `UIFileSharingEnabled` / Files app later. Export preset later.
