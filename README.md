# Survey Admin Web MVP

Barebones Flutter Web admin for the existing survey JSONs in Supabase Storage.

## Implemented

- Recursively discovers store folders in `survey-submissions`.
- Loads latest survey JSON per store and builds an in-memory store index.
- Store-number/city search and state filter.
- Multi-select stores.
- Open latest store submission or an older version.
- Direct test button for:
  `w-jefferson/2255/2026-09-02T16-49-21.211618Z-f09bbef1-166e-4edb-9ea8-d12f9a92484c.json`
- Grid/map renderer for room, tables, canopy cells, and spigots.
- Drag tables to edit their grid position.
- Raw JSON editor for fields not yet ported into graphical tools.
- Validate and save edits as a **new immutable JSON version** in the same store folder.
- Store Excel export.
- Store map PDF export using a captured image of the rendered map.
- Selected-stores Excel and PDF summary export.
- All-stores Excel export.
- Temporary production calculations:
  - `1 zone = 1 irrigation system`
  - `ramps = sum(ramp measured distances) / 36`

## Important MVP limitation

The complete mobile map-editor behavior is not reimplemented yet. The map canvas deliberately starts small: it renders the current objects and supports table dragging, while raw JSON editing gives complete data access. Port the mobile editor's exact table-pair, canopy, entrance, spigot/PSI, ramp endpoint, resize, and zone rules next.

The JSON document is preserved as a raw `Map<String, dynamic>` and only known fields are mutated. That prevents the admin from accidentally deleting mobile fields it does not yet model.

## Supabase security for testing

This Flutter Web app uses a Supabase **anon/publishable key**. Never put a `service_role` key in Flutter Web; browser code is inspectable.

Because login/auth is intentionally omitted for this MVP, your Storage policies must allow the client role you use to perform the required `SELECT` and `INSERT` operations on `survey-submissions`. Keep this temporary and add proper staff auth before production use.

## Run

```bash
flutter pub get
flutter run -d chrome \
  --dart-define=SUPABASE_URL="https://YOUR_PROJECT.supabase.co" \
  --dart-define=SUPABASE_ANON_KEY="YOUR_PUBLISHABLE_OR_ANON_KEY"
```

## Suggested project layout

```text
lib/
  controllers/
    store_list_controller.dart
    survey_admin_controller.dart
  models/
    production_calculation.dart
    store_record.dart
    survey_document.dart
  screens/
    store_list_screen.dart
    survey_editor_screen.dart
  services/
    excel_export_service.dart
    file_download_service.dart
    pdf_export_service.dart
    production_calculation_service.dart
    survey_storage_repository.dart
    survey_validation_service.dart
  utils/
    app_config.dart
    json_helpers.dart
  widgets/
    survey_map_canvas.dart
  main.dart
```

## Next architecture improvement before ~1000 stores

Do **not** keep scanning/downloading the entire bucket every time the store-list page opens. For the MVP this is simple and proves the flow, but at production scale maintain a small store/submission index (preferably a Supabase table) with store number, state, city, folder path, latest object path, upload time, and status. The JSON files can remain the canonical survey versions in Storage.
