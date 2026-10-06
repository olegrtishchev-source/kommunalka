@echo off
REM Запуск приложения на эмуляторе (emulator-5554).
cd /d "%~dp0.."
call flutter run -d emulator-5554
