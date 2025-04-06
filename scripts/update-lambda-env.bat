@echo off
echo ==================================================
echo Update Lambda Environment Variables
echo ==================================================
echo.
echo This script will:
echo 1. Set the correct Cognito User Pool ID in Lambda
echo 2. Set the DynamoDB table name
echo 3. Update the Lambda function configuration
echo.

powershell -ExecutionPolicy Bypass -File "%~dp0update-lambda-env.ps1"

echo.
echo Lambda environment variables should now be updated.
echo.
echo Now try testing your Alexa skill again.
echo.
pause