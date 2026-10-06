@echo off
REM Остановка эмулятора kommunalka_api33.
set ADB=C:\Users\olegr\AppData\Local\Android\sdk\platform-tools\adb.exe
"%ADB%" -s emulator-5554 emu kill
