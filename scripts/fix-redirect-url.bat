@echo off
echo ==================================================
echo Fix Cognito Redirect URLs
echo ==================================================
echo.
echo This script will:
echo 1. Find your Cognito app client
echo 2. Add https://example.com as an allowed callback URL
echo 3. Use precise JSON formatting to ensure proper configuration
echo.
echo After running this script, wait 1-2 minutes and try the test URL again.
echo.

powershell -ExecutionPolicy Bypass -File "%~dp0fix-redirect-url.ps1"

echo.
echo Now run the test login utility after 1-2 minutes:
echo test-cognito-login.bat
echo.
pause