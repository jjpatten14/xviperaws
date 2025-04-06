@echo off
echo Fixing Cognito permissions for Lambda function...
powershell -ExecutionPolicy Bypass -File "%~dp0fix-cognito-permissions.ps1"
if %ERRORLEVEL% NEQ 0 (
    echo Failed to apply fixes! Please check the error message above.
    pause
    exit /b %ERRORLEVEL%
)
echo.
echo All fixes applied successfully!
echo IMPORTANT: If you haven't added your Viper credentials to your Cognito profile,
echo           run the add-viper-credentials.bat script now.
echo.
pause