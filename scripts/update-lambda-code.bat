@echo off
echo Updating Lambda code to use secureCognitoHandler...
powershell -ExecutionPolicy Bypass -File "%~dp0update-lambda-code.ps1"
if %ERRORLEVEL% NEQ 0 (
    echo Failed to update Lambda code! Please check the error message above.
    pause
    exit /b %ERRORLEVEL%
)
echo.
echo Lambda code successfully updated!
echo Try using your Alexa skill again after about 1 minute for the changes to take effect.
pause