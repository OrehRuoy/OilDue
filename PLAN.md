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

## Day 20b

Vehicle-edit hero draws COVER photo; empty state is svc_car in the same box; sheet rows. Night-bay still garage-only.

## Day 21

Garage listing card (photo, huge nickname, miles/due stats, cream Log); vehicle-edit hero name overlay. Unlock is Day 22. Icon parked. Night-bay still garage-only. Cover-crop pan parked.

## Day 22

Unlock screen $2.99 + Restore; extra-car / archive / notify gates; archive hide/unarchive; overlay sheets (miles, photo, confirms); log/history cream CTAs. StoreKit sandbox, PhotoPicker PR #105, killed-app notify = TestFlight. Icon parked. Cover-crop pan parked. Keep 5–21.

## Day 22b

Garage Add-car tile in the 60px strip (even for 1 car); Log Remind me; Add Service template list. Unlock/archive/sheets from 22 stay.

## Day 23

Remind me OFF free when locked; Unlock / vehicle_add / service_add Day-21 look. Add tile caption remains Add. StoreKit/killed-app notify still TestFlight.

## Day 24

Locked Remind me displays off + iOS switch; garage trailing “Add service”; vehicle_add Back → garage; ScrollContainers SHOW_NEVER + swipe pans; add-car / Add Service grouped cards. StoreKit/killed-app notify still TestFlight.

## Day 25

History rows show date/miles/price with no clip; garage Settings gear is alone; listing-card muted Add service / Add another service under cream Log. StoreKit/killed-app notify still TestFlight.

## Day 26

NotifyService date-only, 64 cap, permission on first Remind me ON. StoreKit and PhotoPicker still later. Killed-app fire is TestFlight, not F5.

## Day 27

Purchase.buy/restore wired; editor Pretend unchanged; sandbox buy is TestFlight. PhotoPicker still later. Do not file the listing until a sandbox buy works on device.

## Day 28

PhotoService uses PhotoPicker singleton when present, else FileDialog / iOS stub. Real library/camera is TestFlight. Looks still later.

## Day 29

iOS plugins vendored for StoreKit (Taptico Godot 4.6 layout), Notification Scheduler iOS v5.2 (Godot 4.6 zip; v6.0 is 4.7), and PhotoPicker (PR #105 view controller). Editor stubs unchanged. `min_ios_version` 15.0. Provisioning UUID empty. GHA preflight greps the three plugins only. Sandbox buy + killed-app notify + real camera/library are TestFlight. Looks still later. Do not file the listing with Reminders until a killed-app notification has fired.

## Day 30

Square icon + splash, version 1.0.0, tests out of IPA. One warm theme (CreamButton only primary, no 11 px). Safe area on every screen. Empty first run with Add your car; existing garages untouched; Developer Load demo Civic. notify default false. Status text without paths. History rows unclipped. Nav.go, font, date picker, units, stats, Files picker deferred.

## Day 31

Log date is a tappable field (`Sep 2, 2026`), not a YYYY-MM-DD LineEdit. iOS presents `UIDatePicker` wheels via in-tree DatePicker (PR #105 view controller). Editor/Windows uses a month-grid sheet with Today. Storage stays `YYYY-MM-DD`. Real wheels are TestFlight. Keep 5–30.

## Day 32

History tap opens Edit job on the Log screen. Save rewrites that job; Delete job uses a dim-card confirm. `last_*` / `next_*` recompute from the newest remaining history. Numeric keyboards + notes TextEdit. Units/stats/Files still later. Keep 5–31.

## Day 33

All confirms use dim + `#2A2622` sheet: cream 52px Cancel, red 17px text for Delete / Archive / Replace. Godot AcceptDialog gone. Keep 5–32. Units/stats/Files still later.

## Day 34

Compact garage listing card, aligned history thumbs, forms/unlock/settings void killed, missing glyphs from Lauren zip. Keep 5–33. No feature changes. Units/stats/Files still later.

## Day 35

Selection highlight on Add service (`#3D3832` + cream hairline), Lauren white glyphs, compact log form, centered 428 column on non-garage screens, vehicle-edit hero or small placeholder. Keep 5–34. No feature changes. Units/stats/Files still later.

## Day 36

iOS Files list in `user://` (no FileDialog on phone). First-build check: icon 1024, splash, plugins, Developer hidden. Keep 5–35. No feature changes. Units/stats still later.

## Day 38

Fix device stretch/scale + hit targets; first-run one placeholder car (no fake miles/history). Existing garage.json untouched. StoreKit / killed-app notify / listing submit still later.

## Never add

Fuel log, VIN decode, NHTSA, shop directory, family sharing, CARFAX, ads, subscriptions, Firebase, Play listing.

## Deferred

Killed-app local notification fire, StoreKit sandbox buy, GitHub Actions iOS signing / xcodebuild (profile UUID still empty). Looks later (Nav.go, Inter font, units, stats). Real date wheels are TestFlight.
