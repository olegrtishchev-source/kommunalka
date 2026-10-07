@echo off
REM Автоматизированный вход в приложение на устройстве через adb input.
REM Использование:
REM   tools\login-test.bat [device-id] [email] [password]
REM Если email/password не заданы — берутся из test_creds.txt (2 строки: email, пароль).
REM Требуется, чтобы приложение УЖЕ было запущено и показывало экран «Вход».
setlocal EnableDelayedExpansion

set ADB=%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe
set DEV=%1
if "%DEV%"=="" set DEV=emulator-5554

set EMAIL=%2
set PASS=%3

REM Читаем креды из файла, если не переданы аргументами.
if "%EMAIL%"=="" (
  cd /d "%~dp0.."
  if exist "test_creds.txt" (
    set /a _n=0
    for /f "usebackq delims=" %%L in ("test_creds.txt") do (
      set /a _n+=1
      if !_n!==1 set EMAIL=%%L
      if !_n!==2 set PASS=%%L
    )
  )
)

if "%EMAIL%"=="" (
  echo [ОШИБКА] Не задан email. Передай аргументом или создай test_creds.txt.
  exit /b 1
)

echo [login-test] device=%DEV% email=%EMAIL%

REM 1. Поднимаем приложение на передний план.
"%ADB%" -s %DEV% shell am start -n ru.rtishchev.kommunalka/.MainActivity >nul
timeout /t 4 /nobreak >nul

REM 2. Тап по полю Email (координаты для 1080x2340, AVD Pixel 5).
"%ADB%" -s %DEV% shell input tap 540 1115
timeout /t 1 /nobreak >nul
REM Пробелы в email кодируем как %s; символ @ передаётся adb напрямую.
set EMAIL_ADB=%EMAIL: =%%s%
"%ADB%" -s %DEV% shell input text "%EMAIL_ADB%"
timeout /t 1 /nobreak >nul

REM 3. Тап по полю Пароль и ввод.
"%ADB%" -s %DEV% shell input tap 540 1270
timeout /t 1 /nobreak >nul
set PASS_ADB=%PASS: =%%s%
"%ADB%" -s %DEV% shell input text "%PASS_ADB%"
timeout /t 1 /nobreak >nul

REM 4. Закрываем клавиатуру и жмём «Войти».
"%ADB%" -s %DEV% shell input keyevent 4
timeout /t 1 /nobreak >nul
"%ADB%" -s %DEV% shell input tap 540 1490
timeout /t 6 /nobreak >nul

REM 5. Скриншот результата.
"%ADB%" -s %DEV% exec-out screencap -p > _emu_screen.png
echo [login-test] Готово. Результат — _emu_screen.png
echo Подсказка: если поля сместились из-за клавиатуры — проверь координаты по скриншоту.

endlocal
