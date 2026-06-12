@echo off
REM ============================================================
REM  Re-establish the phone <-> backend tunnel for the Flutter app.
REM  Double-click this whenever the app says "Connection refused".
REM ============================================================
set ADB=%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe

echo Checking device...
"%ADB%" devices

echo.
echo Setting reverse tunnel (phone 127.0.0.1:8000 -^> laptop backend)...
"%ADB%" reverse tcp:8000 tcp:8000

echo.
echo Active tunnels:
"%ADB%" reverse --list

echo.
echo Done. If the device shows "offline", unplug/replug the cable and run this again.
pause
