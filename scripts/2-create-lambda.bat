@echo off
echo Step 2: Creating Lambda function in us-east-1
echo =========================================
echo.
powershell -ExecutionPolicy Bypass -File "%~dp02-create-lambda.ps1"
pause