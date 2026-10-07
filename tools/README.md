# Тестовые устройства — Kommunalka

Два взаимозаменяемых таргета для тестирования (оба Android 13 / API 33 —
поведение одинаковое):

| Таргет | ID (`flutter devices`) | Как запустить |
|---|---|---|
| Физическое устройство | `e11a40c1` (M2101K6G, Xiaomi) | подключить по USB |
| Эмулятор | `emulator-5554` (sdk gphone64 x86_64) | `tools\emulator-start.bat` |

## Быстрый старт эмулятора

```bat
tools\emulator-start.bat
```
Дождаться загрузки (~1 мин при первом холодном старте) и проверить:
```bat
flutter devices
```
Эмулятор появится как `emulator-5554`.

## Запуск приложения

- На **эмуляторе**:
  ```bat
  flutter run -d emulator-5554
  ```
- На **физическом устройстве**:
  ```bat
  flutter run -d e11a40c1
  ```
- Авто-выбор (если подключено только одно): `just run` / `flutter run`.

Если подключены оба и нужно выбрать вручную — `flutter run` без `-d` покажет
список для выбора.

## Автоматизированный тестовый вход (для проверки сценариев)

`tools\login-test.bat` выполняет вход в приложение на устройстве через `adb input` —
полезно для прогона сценариев после экрана «Вход». Приложение должно быть уже
запущено и показывать экран «Вход».

```bat
REM вариант 1 — креды аргументами
tools\login-test.bat emulator-5554 user@example.com MyPass123

REM вариант 2 — креды из test_creds.txt (2 строки: email, пароль)
tools\login-test.bat
```

Файл `test_creds.txt` — в `.gitignore` (в git не попадёт). Результат — `_emu_screen.png`.

**Нюансы `adb input`:**
- символ `@` передаётся напрямую (`input text user@example.com`); экранирование `%40` НЕ работает;
- спецсимволы пароля (кириллица, `!`, `#`, кавычки) могут не передаться — берите ASCII-пароль или вводите вручную;
- координаты полей рассчитаны на 1080×2340 (AVD Pixel 5); при другом разрешении сверьтесь по скриншоту.

## Иконка и название приложения (Этап 7.6)

- `tools\make_launcher_icons.py` — генератор иконок запуска (чистый Python,
  только stdlib: `zlib`/`struct`; Pillow не нужен). Рисует фирменный домик на
  teal-фоне и пишет PNG во всех плотностях:
  - `mipmap-*/ic_launcher.png` — legacy-иконка (mdpi 48 … xxxhdpi 192);
  - `mipmap-*/ic_launcher_foreground.png` — foreground адаптивной иконки
    (mdpi 108 … xxxhdpi 432), фон задаётся `values/colors.xml`
    (`ic_launcher_background`), конфиг — `mipmap-anydpi-v26/ic_launcher.xml`.
  - Скрипт идемпотентен; после правки геометрии/цвета — перезапустить:
    ```bat
    python tools\make_launcher_icons.py
    ```
- `tools\_verify_icons.py` — проверка: валидность PNG (сигнатура, IHDR, IDAT) +
  ASCII-превью крупных иконок (визуальный контроль формы домика/фона):
  ```bat
  python tools\_verify_icons.py
  ```
- Название приложения в лаунчере — `android/app/src/main/res/values/strings.xml`
  (`app_name = Коммуналка`), подключено в `AndroidManifest.xml` через
  `android:label="@string/app_name"`.

## Остановка эмулятора

```bat
tools\emulator-stop.bat
```
(или просто закрыть окно эмулятора)

## Переключение физ. устройство ↔ эмулятор

Ничего пересобирать вручную не нужно — `flutter run -d <id>` соберёт под нужную
архитектуру автоматически:
- физ. устройство: `android-arm64`
- эмулятор: `android-x64`

Пересборка между разными архитектурами занимает время (первый прогон на
эмуляторе дольше).

## Если `adb devices` показывает `offline` / пропало устройство

```bat
adb kill-server
adb start-server
flutter devices
```

## Требования (уже настроены)

- Android SDK: `C:\Users\olegr\AppData\Local\Android\sdk`
- `JAVA_HOME` — JBR из Android Studio: `C:\Program Files\Android\Android Studio\jbr`
  (скрипты в `tools\` задают его сами; глобально не задан)
- System-image: `system-images;android-33;google_apis;x86_64`
- AVD: `kommunalka_api33` (Pixel 5, Android 13, google_apis/x86_64)
