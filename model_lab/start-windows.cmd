@echo off
cd /d "%~dp0"
where node >nul 2>nul
if errorlevel 1 (
  echo Install Node.js 22.12 or newer, then run this file again.
  pause
  exit /b 1
)
if not exist node_modules (
  call npm ci --omit=dev
  if errorlevel 1 (
    pause
    exit /b 1
  )
)
echo Open http://localhost:5173 in your browser. Keep this window open.
call npm run dev -- --port 5173
pause
