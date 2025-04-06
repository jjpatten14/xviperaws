@echo off
echo Fixing Viper API integration...
powershell -ExecutionPolicy Bypass -File "%~dp0fix-viper-api.ps1"
if %ERRORLEVEL% NEQ 0 (
    echo Failed to fix Viper API integration! Please check the error message above.
    pause
    exit /b %ERRORLEVEL%
)
echo.
echo Viper API integration fixed!
echo Wait about 1-2 minutes for the changes to take effect.
echo Then test your Alexa skill again by saying "Alexa, ask X Viper to lock my car"
pause