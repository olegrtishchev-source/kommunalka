@echo off
REM Запуск эмулятора kommunalka_api33 (Android 13 / API 33).
REM JAVA_HOME задаётся локально (глобально не задан).
set JAVA_HOME=C:\Program Files\Android\Android Studio\jbr
set EMU=C:\Users\olegr\AppData\Local\Android\sdk\emulator\emulator.exe
REM -gpu host — аппаратный рендеринг (было auto → часто отключал ускорение и
REM вызывал системный ANR «Process system isn't responding»). -no-snapshot-load
REM — чистый старт, чтобы подхватить обновлённый config.ini (RAM 4G, 4 ядра).
start "" "%EMU%" -avd kommunalka_api33 -gpu host -no-snapshot-load
