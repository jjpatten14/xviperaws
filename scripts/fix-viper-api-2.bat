@echo off
echo Fixing Viper API integration with comprehensive auth solution...
powershell -ExecutionPolicy Bypass -File "%~dp0fix-viper-api-2.ps1"
if %ERRORLEVEL% NEQ 0 (
    echo Error running script.
    pause
    exit /b 1
)
echo.
echo Deployment complete! Wait 1-2 minutes then:
echo 1. First say "Alexa, ask X Viper to diagnose API"
echo 2. Then try "Alexa, ask X Viper to lock my car"
pause