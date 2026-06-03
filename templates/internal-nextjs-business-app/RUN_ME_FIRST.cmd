@echo off
setlocal
cd /d "%~dp0"

echo.
echo Internal tools starter
echo ========================
echo.

where node >nul 2>nul
if errorlevel 1 (
  echo Node.js is missing. Install Node.js 22 or newer, then run this file again.
  echo Download: https://nodejs.org/
  pause
  exit /b 1
)

where npm >nul 2>nul
if errorlevel 1 (
  echo npm is missing. Reinstall Node.js 22 or newer, then run this file again.
  pause
  exit /b 1
)

call npm run start-here
if errorlevel 1 goto failed

echo.
echo Checking your laptop...
call npm run doctor
if errorlevel 1 goto failed

echo.
echo Installing project packages. This can take a few minutes the first time.
call npm install
if errorlevel 1 goto failed

echo.
echo Starting the local app. Keep this window open while you use it.
echo Open http://localhost:3000 when the app says it is ready.
echo.
call npm run dev
if errorlevel 1 goto failed

exit /b 0

:failed
echo.
echo Something stopped the local startup.
echo Read the message above, fix the missing item, then run this file again.
pause
exit /b 1
