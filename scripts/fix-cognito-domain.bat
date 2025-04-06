@echo off
echo ==================================================
echo Cognito Domain Fix Utility
echo ==================================================
echo.
echo This utility will:
echo 1. Find and delete the problematic Cognito domain
echo 2. Wait for deletion to complete
echo 3. Run the full setup script with the fixed domain
echo.
echo Prerequisites:
echo - AWS CLI installed and configured
echo - PowerShell installed
echo.

REM Check AWS CLI is installed
aws --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: AWS CLI is not installed or not in PATH
    echo Please install AWS CLI from https://aws.amazon.com/cli/
    pause
    exit /b 1
)

echo Starting domain fix process...
echo.
echo Step 1: Finding and deleting existing Cognito domain

powershell -ExecutionPolicy Bypass -File "%~dp0fix-cognito-domain.ps1"

echo.
echo Step 2: Running full setup script with fixed domain configuration
echo.
echo NOTE: This will create a new Cognito domain and configure everything from scratch.
echo.
echo Press any key to continue...
pause > nul

call "%~dp0run-complete-setup.bat"