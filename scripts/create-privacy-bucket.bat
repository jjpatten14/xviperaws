@echo off
echo Creating new S3 bucket for privacy policy hosting...
powershell -ExecutionPolicy Bypass -File "%~dp0create-privacy-bucket.ps1"
if %ERRORLEVEL% NEQ 0 (
    echo Error running script.
    pause
    exit /b 1
)
echo.
echo Please use the URL shown above in your Alexa skill configuration for the privacy policy link.
pause