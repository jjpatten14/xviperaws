@echo off
echo Updating Lambda Environment Variables Directly
echo =============================================
echo.
echo This script will update the Lambda environment variables using AWS CLI directly.
echo.

set REGION=us-east-1
set LAMBDA_FUNCTION_NAME=xviper-alexa-skill
set USERNAME_VALUE=jjpatten14@gmail.com
set PASSWORD_VALUE=Josh888888$
set TABLE_NAME=XviperUserMappings

echo Setting environment variables:
echo - DEFAULT_USERNAME: %USERNAME_VALUE%
echo - DEFAULT_PASSWORD: %PASSWORD_VALUE%
echo - USER_MAPPING_TABLE: %TABLE_NAME%
echo.

aws lambda update-function-configuration ^
  --function-name %LAMBDA_FUNCTION_NAME% ^
  --region %REGION% ^
  --environment "Variables={DEFAULT_USERNAME=%USERNAME_VALUE%,DEFAULT_PASSWORD=%PASSWORD_VALUE%,USER_MAPPING_TABLE=%TABLE_NAME%}"

echo.
echo Waiting for update to complete...
timeout /t 5 > NUL

echo.
echo Verifying configuration...
aws lambda get-function --function-name %LAMBDA_FUNCTION_NAME% --region %REGION% --query "Configuration.Environment"

echo.
echo Done. Try your Alexa skill again.
echo.
pause