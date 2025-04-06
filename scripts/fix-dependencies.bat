@echo off
echo Fixing Lambda Dependencies
echo =========================
echo.
echo This script will:
echo 1. Update package.json with required dependencies
echo 2. Install dependencies properly
echo 3. Create a new deployment package
echo 4. Upload it to S3
echo 5. Update the Lambda function
echo.
powershell -ExecutionPolicy Bypass -File "%~dp0fix-dependencies.ps1"
pause