@echo off
echo Creating quick-fix Lambda to resolve handler error...
powershell -ExecutionPolicy Bypass -File "%~dp0quick-fix-lambda.ps1"
if %ERRORLEVEL% NEQ 0 (
    echo Error running script.
    pause
    exit /b 1
)
echo.
echo Deployment complete! Wait 1-2 minutes then test your skill by saying:
echo "Alexa, ask X Viper to lock my car"
pause