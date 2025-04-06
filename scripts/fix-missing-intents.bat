@echo off
echo Fixing missing intents and improving error handling...
powershell -ExecutionPolicy Bypass -File "%~dp0fix-missing-intents.ps1"
if %ERRORLEVEL% NEQ 0 (
    echo Error running script.
    pause
    exit /b 1
)
echo.
echo Deployment complete! Wait 1-2 minutes then you can try:
echo - "Alexa, ask X Viper to lock my car"
echo - "Alexa, ask X Viper to unlock my car"
echo - "Alexa, ask X Viper to start my car"
echo - "Alexa, ask X Viper to stop my car"
echo - "Alexa, ask X Viper to open trunk"
pause