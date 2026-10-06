# Tech Context — Kommunalka

## Платформа и инструменты
- Flutter (Android-only), Windows 11, PowerShell.
- Flutter 3.47.4 stable, Dart 3.13.3.
- IDE: Android Studio (плагины Flutter + Dart). GIGA IDE для Flutter не подходит (LSP4IJ несовместим).
- Устройство: Xiaomi Redmi Note 10 Pro (Android 13, API 33).

## Зависимости (pubspec.yaml)
- supabase_flutter, drift + drift_flutter + drift_dev/build_runner, flutter_riverpod, go_router, image, image_picker, url_launcher, shared_preferences, excel, http + flutter_web_auth_2, flutter_lints.

## Команды
- `flutter run -d <device-id>` / `flutter build apk --release`
- `flutter analyze`, `flutter test`
- `dart run build_runner build` — регенерация `.g.dart` (после правки drift-таблиц)

## Конфигурация / секреты
- В `lib/main.dart` — только publishable ключи (Supabase URL/key, Яндекс Client ID, redirect URI). Секретов в клиенте нет.

## Примечание по среде
- `flutter test`/`flutter analyze` холодным прогоном > 30 с — запускать в фоне с записью вывода в файл.
- Кириллицу в консоли читать не через `Get-Content` (битая кодировка), а через `python -c "...read_text(encoding='utf-8')"` или `read_files`.
- build_runner опция `--delete-conflicting-outputs` удалена в новой версии (warning), outputs перезаписываются автоматически.

## Ключевые файлы
- `supabase/schema.sql` (схема + RLS), `supabase/migration_5.8.sql` (ALTER TABLE, выполнен).
- `ТЗ.md`, `План_выполнения.md` — спецификация и журнал.
