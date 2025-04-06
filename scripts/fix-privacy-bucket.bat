@echo off
echo Generating pre-signed URL for privacy policy...
powershell -ExecutionPolicy Bypass -File "%~dp0fix-privacy-bucket.ps1"
if %ERRORLEVEL% NEQ 0 (
    echo Error running script.
    pause
    exit /b 1
)
echo.
echo Please use the pre-signed URL shown above in your Alexa skill configuration.
echo This URL has been saved to privacy-policy-urls.txt for your reference.
pause