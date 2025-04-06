@echo off
echo ==================================================
echo Fix OAuth Flows for Cognito
echo ==================================================
echo.
echo This script will:
echo 1. Enable proper OAuth flows for your app client
echo 2. Fix the "Client is not enabled for OAuth2.0 flows" error
echo 3. Ensure all callback URLs are preserved
echo.

powershell -ExecutionPolicy Bypass -File "%~dp0fix-oauth-flows.ps1"

echo.
echo After running this script, wait 1-2 minutes for changes to propagate,
echo then try the test URL provided.
echo.
pause