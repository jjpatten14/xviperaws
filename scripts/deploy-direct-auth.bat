@echo off
echo X Viper Alexa Skill - Direct Authentication Deployment
echo ===================================================
echo.
echo This script will automatically:
echo 1. Create a simplified Lambda function with direct authentication
echo 2. Package it with dependencies
echo 3. Deploy it to AWS
echo 4. Update environment variables
echo.
echo No OAuth or account linking needed!
echo.
powershell -ExecutionPolicy Bypass -File "%~dp0deploy-direct-auth.ps1"
echo.
pause