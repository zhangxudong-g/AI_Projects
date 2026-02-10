@echo off
REM Engineering Judge v3 Startup Script for Windows
REM This script starts both frontend and backend servers

setlocal enabledelayedexpansion

echo ================================================
echo Engineering Judge v3 Startup Script (Windows)
echo ================================================
echo.

REM Check if backend directory exists
if not exist "backend" (
    echo ERROR: Backend directory not found. Please run this script from the project root.
    pause
    exit /b 1
)

REM Check if frontend directory exists
if not exist "frontend" (
    echo ERROR: Frontend directory not found. Please run this script from the project root.
    pause
    exit /b 1
)

echo Starting Engineering Judge v3...
echo.

REM Start backend server in a new window
echo Starting backend server on port 8000...
start "Backend Server" cmd /k "cd /d %~dp0backend && venv\Scripts\activate && uvicorn main:app --reload --host 0.0.0.0 --port 8000"

REM Wait a bit for backend to start
timeout /t 5 /nobreak >nul

REM Start frontend server in a new window
echo Starting frontend server on port 3000...
start "Frontend Server" cmd /k "cd /d %~dp0frontend && npm start"

echo.
echo ================================================
echo Servers started successfully!
echo ================================================
echo.

echo Backend server: http://localhost:8000
echo Frontend server: http://localhost:3000
echo API Documentation: http://localhost:8000/docs
echo.

echo Note: If this is your first time running the application,
echo make sure to initialize the database by running:
echo   cd backend
echo   venv\Scripts\activate
echo   python -c "from database.base import engine; from models.user import User, Case, Execution, Report, SystemConfig; User.metadata.create_all(bind=engine); Case.metadata.create_all(bind=engine); Execution.metadata.create_all(bind=engine); Report.metadata.create_all(bind=engine); SystemConfig.metadata.create_all(bind=engine); print('Database initialized successfully!')"
echo.

echo Press any key to exit...
pause >nul