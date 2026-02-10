@echo off
REM Engineering Judge v3 Windows Installation Script
REM This script automates the installation of both frontend and backend environments

setlocal enabledelayedexpansion

echo ================================================
echo Engineering Judge v3 Installation Script (Windows)
echo ================================================
echo.

REM Check if Python is installed
echo Checking Python installation...
python --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Python is not installed or not in PATH.
    echo Please install Python 3.9+ from https://www.python.org/downloads/
    pause
    exit /b 1
) else (
    echo Python is installed.
    python --version
)

REM Check if Node.js is installed
echo.
echo Checking Node.js installation...
node --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Node.js is not installed or not in PATH.
    echo Please install Node.js LTS from https://nodejs.org/
    pause
    exit /b 1
) else (
    echo Node.js is installed.
    node --version
)

REM Check if Git is installed
echo.
echo Checking Git installation...
git --version >nul 2>&1
if errorlevel 1 (
    echo WARNING: Git is not installed or not in PATH.
    echo It is recommended to install Git from https://git-scm.com/download/win
) else (
    echo Git is installed.
    git --version
)

REM Navigate to the project directory
echo.
echo Setting up project directory...
set PROJECT_DIR=%~dp0
cd /d "%PROJECT_DIR%"

REM Check if we're in the right directory
if not exist "backend" (
    echo ERROR: Backend directory not found. Please run this script from the project root.
    pause
    exit /b 1
)

if not exist "frontend" (
    echo ERROR: Frontend directory not found. Please run this script from the project root.
    pause
    exit /b 1
)

echo.
echo ================================================
echo Installing Backend Environment
echo ================================================
echo.

REM Navigate to backend directory
cd backend

REM Create virtual environment if it doesn't exist
if not exist "venv" (
    echo Creating Python virtual environment...
    python -m venv venv
    if errorlevel 1 (
        echo ERROR: Failed to create virtual environment.
        pause
        exit /b 1
    )
    echo Virtual environment created.
) else (
    echo Virtual environment already exists.
)

REM Activate virtual environment
call venv\Scripts\activate.bat
if errorlevel 1 (
    echo ERROR: Failed to activate virtual environment.
    pause
    exit /b 1
)

REM Install backend dependencies
echo.
echo Installing backend dependencies...
if exist "requirements.txt" (
    pip install -r requirements.txt
) else (
    REM Install individual packages if requirements.txt doesn't exist
    pip install fastapi uvicorn sqlalchemy pydantic-settings passlib[bcrypt] python-jose[cryptography] python-multipart python-dotenv
)
if errorlevel 1 (
    echo ERROR: Failed to install backend dependencies.
    pause
    exit /b 1
)
echo Backend dependencies installed successfully.

REM Return to project root
cd ..

echo.
echo ================================================
echo Installing Frontend Environment
echo ================================================
echo.

REM Navigate to frontend directory
cd frontend

REM Install frontend dependencies
echo Installing frontend dependencies...
if exist "package.json" (
    npm install
) else (
    echo WARNING: package.json not found in frontend directory.
    echo Skipping frontend installation.
)
if errorlevel 1 (
    echo ERROR: Failed to install frontend dependencies.
    echo Make sure Node.js and npm are properly installed.
    pause
    exit /b 1
)
echo Frontend dependencies installed successfully.

REM Return to project root
cd ..

echo.
echo ================================================
echo Installation Complete!
echo ================================================
echo.

echo Backend environment setup in: %PROJECT_DIR%backend
echo Frontend environment setup in: %PROJECT_DIR%frontend
echo.

echo To start the backend server:
echo   1. cd backend
echo   2. venv\Scripts\activate
echo   3. uvicorn main:app --reload --host 0.0.0.0 --port 8000
echo.

echo To start the frontend development server:
echo   1. cd frontend
echo   2. npm start
echo.

echo The application will be available at:
echo   Frontend: http://localhost:3000
echo   Backend API: http://localhost:8000
echo   Backend API Docs: http://localhost:8000/docs
echo.

echo Press any key to exit...
pause >nul