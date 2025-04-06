@echo off
echo Updating Lambda Configuration with Credentials
echo ============================================
echo.
echo This script will add the following environment variables to Lambda:
echo - DEFAULT_USERNAME: jjpatten14@gmail.com
echo - DEFAULT_PASSWORD: Josh888888$
echo.
powershell -ExecutionPolicy Bypass -File "%~dp0update-lambda-config.ps1"
pause