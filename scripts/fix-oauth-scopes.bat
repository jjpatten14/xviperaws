@echo off
echo Fixing OAuth scopes for Cognito app client...
powershell -ExecutionPolicy Bypass -File "%~dp0fix-oauth-scopes.ps1"
if %ERRORLEVEL% NEQ 0 (
    echo Failed to fix OAuth scopes! Please check the error message above.
    pause
    exit /b %ERRORLEVEL%
)
echo.
echo OAuth scopes have been fixed!
echo Please update your Alexa skill with the new client credentials.
pause