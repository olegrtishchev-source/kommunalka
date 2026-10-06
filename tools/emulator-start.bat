@echo off
REM Запуск эмулятора kommunalka_api33 (Android 13 / API 33).
REM JAVA_HOME задаётся локально (глобально не задан).
set JAVA_HOME=C:\Program Files\Android\Android Studio\jbr
set EMU=C:\Users\olegr\AppData\Local\Android\sdk\emulator\emulator.exe
start "" "%EMU%" -avd kommunalka_api33 -gpu auto
