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
