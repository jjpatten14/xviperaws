@echo off
echo Fixing Lambda code import issue...
powershell -ExecutionPolicy Bypass -File "%~dp0fix-lambda-import.ps1"
if %ERRORLEVEL% NEQ 0 (
    echo Failed to fix Lambda code! Please check the error message above.
    pause
    exit /b %ERRORLEVEL%
)
echo.
echo Lambda code has been updated!
echo Wait at least 1 minute for the changes to take effect.
echo Then test your Alexa skill again.
pause