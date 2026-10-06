@echo off
REM Показать доступные устройства и эмуляторы.
echo === adb devices ===
"C:\Users\olegr\AppData\Local\Android\sdk\platform-tools\adb.exe" devices
echo.
echo === flutter devices ===
call flutter devices
echo.
echo === flutter emulators ===
call flutter emulators
