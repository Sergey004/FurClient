@echo off
REM FA Nexus - Quick Start Script for Windows

echo.
echo 🚀 FA Nexus - Fur Affinity Client
echo ==================================
echo.

REM Check if node_modules exists
if not exist "node_modules" (
    echo 📦 Installing dependencies...
    call npm install
    echo.
)

REM Check if .env exists
if not exist ".env" (
    echo ⚙️  Creating .env file...
    (
        echo PORT=3001
        echo CLIENT_URL=http://localhost:3000
        echo NODE_ENV=development
        echo REACT_APP_API_URL=http://localhost:3001/api
    ) > .env
    echo ✅ .env file created
    echo.
)

REM TypeScript check
echo 🔍 Running TypeScript check...
call npm run lint
if errorlevel 1 (
    echo ❌ TypeScript errors found!
    pause
    exit /b 1
)
echo ✅ TypeScript OK
echo.

REM Start dev servers
echo 🟢 Starting dev servers...
echo    Frontend: http://localhost:3000
echo    Backend:  http://localhost:3001/api
echo.
echo Press Ctrl+C to stop
echo.

call npm run dev
pause
