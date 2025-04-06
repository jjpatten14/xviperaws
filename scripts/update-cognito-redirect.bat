@echo off
echo ==================================================
echo Update Cognito Redirect URLs
echo ==================================================
echo.
echo This script will:
echo 1. Find your Cognito app client
echo 2. Add https://example.com as an allowed callback URL
echo 3. Enable testing of the login page
echo.
echo After running this script, wait 1-2 minutes and try the test URL again.
echo.

powershell -ExecutionPolicy Bypass -File "%~dp0update-cognito-redirect.ps1"

echo.
echo Now wait 1-2 minutes for changes to propagate, then run:
echo test-cognito-login.bat
echo.
pause