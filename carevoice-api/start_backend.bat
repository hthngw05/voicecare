@echo off
REM CareVoice backend launcher.
REM Double-click this file (or the desktop shortcut) to start the API.
REM Ctrl+C in the console window to stop it.

setlocal
cd /d "%~dp0"

if not exist ".venv\Scripts\python.exe" (
  echo [error] Python venv not found at .venv\Scripts\python.exe
  echo Run setup first: python -m venv .venv ^&^& .venv\Scripts\pip install -r requirements.txt
  pause
  exit /b 1
)

title CareVoice API ^| http://localhost:8000
echo Starting CareVoice API on http://0.0.0.0:8000
echo Android emulator reaches this at http://10.0.2.2:8000
echo Press Ctrl+C to stop.
echo.

".venv\Scripts\python.exe" -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload

echo.
echo Server exited. Press any key to close.
pause >nul
