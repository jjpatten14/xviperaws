@echo off
echo ==================================================
echo Final Fix for Cognito Redirect URLs
echo ==================================================
echo.
echo This script will:
echo 1. Preserve existing callback URLs
echo 2. Add https://example.com as an allowed callback URL
echo 3. Fix OAuth scope formatting
echo.
echo After running this script, wait 1-2 minutes for changes to propagate.
echo.

powershell -ExecutionPolicy Bypass -File "%~dp0fix-redirect-final.ps1"

echo.
echo Wait for 2 minutes, then try the test URL provided above.
echo.
echo [Press any key to continue...]
pause > nul