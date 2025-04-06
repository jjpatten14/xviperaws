@echo off
echo Step 1: Creating S3 bucket in us-east-1
echo =====================================
echo.
powershell -ExecutionPolicy Bypass -File "%~dp01-create-bucket.ps1"
pause