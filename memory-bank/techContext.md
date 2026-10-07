# Tech Context — Kommunalka

## Платформа и инструменты
- Flutter (Android-only), Windows 11, PowerShell.
- Flutter 3.47.4 stable, Dart 3.13.3.
- IDE: Android Studio (плагины Flutter + Dart). GIGA IDE для Flutter не подходит (LSP4IJ несовместим).
- Устройство: Xiaomi Redmi Note 10 Pro (Android 13, API 33).

## Зависимости (pubspec.yaml)
- База: supabase_flutter, drift + drift_flutter + drift_dev/build_runner, flutter_riverpod, go_router.
- Прочее: image, image_picker, url_launcher, shared_preferences, http + flutter_web_auth_2, flutter_lints.
- QR/оплата: qr_flutter (рендер платёжного QR), mobile_scanner (скан QR квитанции), gal (сохранение в галерею), share_plus (поделиться).
- Чеки/отчёты: file_picker (выбор PDF-чека), excel (xlsx-отчёт), archive (пост-обработка xlsx — вставка `<autoFilter>`; прямая зависимость с 5.9.5).

## Команды
- `flutter run -d <device-id>` / `flutter build apk --release`
- `flutter analyze`, `flutter test`
- `dart run build_runner build` — регенерация `.g.dart` (после правки drift-таблиц)
- Диагностический скрипт: `dart run test/excel_autofilter_check.dart` — проверяет `<autoFilter>` в xlsx.

## Конфигурация / секреты
- В `lib/main.dart` — только publishable ключи (Supabase URL/key, Яндекс Client ID, redirect URI). Секретов в клиенте нет.
- **Подпись релизной сборки (7.5):** `android/kommunalka-release.jks` (alias `kommunalka`, пароли `kommunalka2026`) + `android/key.properties`. Оба файла в `.gitignore`. `build.gradle.kts` читает `key.properties`; если его нет — фолбэк на debug-подпись. Ключ хранить надёжно: смена ключа ломает обновление приложения поверх (переустановка с удалением = сброс локального кэша, данные в Supabase не теряются).

## Примечание по среде
- `flutter test`/`flutter analyze` холодным прогоном > 30 с — запускать в фоне с записью вывода в файл.
- Кириллицу в консоли читать не через `Get-Content` (битая кодировка), а через `python -c "...read_text(encoding='utf-8')"` или `read_files`.
- build_runner опция `--delete-conflicting-outputs` удалена в новой версии (warning), outputs перезаписываются автоматически.
- Устройство в `flutter run`: id `e11a40c1` (M2101K6G, Xiaomi). При обрыве ADB: `adb kill-server; adb start-server`.
- Дамп локальной БД с устройства (для диагностики): `adb exec-out run-as ru.rtishchev.kommunalka cat app_flutter/kommunalka_local.sqlite > dev_db.sqlite` (через `cmd /c` — PowerShell портит бинарь). Читать через Python `sqlite3`. Файл `dev_db.sqlite` в `.gitignore`.

## Тестовые устройства
- **Только физическое устройство:** `e11a40c1` (M2101K6G, Xiaomi, Android 13/API 33, arm64) — единственный таргет (решение Олега, 07.10.2026). Эмулятор больше НЕ используется: AVD `kommunalka_api33` и `tools/emulator-*.bat` остаются в репозитории как исторический артефакт, в работе не задействуются.
- Запуск приложения: `flutter run -d e11a40c1`.
- **JAVA_HOME** глобально не задан — для `avdmanager`/`sdkmanager`/`emulator` задаётся локально в скриптах как `C:\Program Files\Android\Android Studio\jbr` (JBR, JDK 25).
- Установка system-image: `sdkmanager "system-images;android-33;google_apis;x86_64"` (нужен JAVA_HOME).
- Создание AVD: `avdmanager create avd --name kommunalka_api33 --package "system-images;android-33;google_apis;x86_64" --device pixel_5`.
- Хост: AMD64, Hyper-V/WHPX доступен (аппаратное ускорение эмулятора работает).

## Ключевые файлы
- `supabase/schema.sql` (схема + RLS), `supabase/migration_5.6.sql` (поле address), `supabase/migration_5.8.sql` — применены Олегом.
- `ТЗ.md`, `План_выполнения.md` — спецификация и журнал.
