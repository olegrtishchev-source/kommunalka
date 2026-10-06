@echo off
REM Запуск приложения на физическом устройстве (Xiaomi M2101K6G, e11a40c1).
cd /d "%~dp0.."
call flutter run -d e11a40c1
