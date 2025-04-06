@echo off
echo Deploying OAuth Implementation for Xviper Alexa Skill
echo ===================================================
echo.
echo This script will:
echo 1. Copy oauthIndex.js and cognitoTokenHandler.js to the lambda directory
echo 2. Update the Lambda function with OAuth capabilities
echo.

set REGION=us-east-1
set LAMBDA_FUNCTION_NAME=xviper-alexa-skill
set S3_BUCKET=xviper-us-east1-965239903867

echo Step 1: Setting up the deployment directory...
if exist lambda-oauth rmdir /s /q lambda-oauth
mkdir lambda-oauth

echo Copying files to deployment directory...
xcopy /s /y lambda\* lambda-oauth\
copy /y lambda\oauthIndex.js lambda-oauth\index.js
copy /y lambda\cognitoTokenHandler.js lambda-oauth\

echo.
echo Step 2: Installing dependencies...
cd lambda-oauth
call npm install --production

echo.
echo Step 3: Creating deployment package...
cd ..
if exist deployment-oauth.zip del deployment-oauth.zip

cd lambda-oauth
echo Using PowerShell to create zip file...
powershell -Command "Compress-Archive -Path * -DestinationPath ..\deployment-oauth.zip -Force"
cd ..

echo.
echo Step 4: Uploading to S3...
aws s3 cp deployment-oauth.zip s3://%S3_BUCKET%/deployment-oauth.zip --region %REGION%

echo.
echo Step 5: Updating Lambda function...
aws lambda update-function-code ^
  --function-name %LAMBDA_FUNCTION_NAME% ^
  --s3-bucket %S3_BUCKET% ^
  --s3-key deployment-oauth.zip ^
  --region %REGION%

echo.
echo Step 6: Waiting for update to complete...
timeout /t 5 > NUL

echo.
echo OAuth implementation deployed successfully!
echo.
echo NEXT STEPS:
echo 1. Complete the Amazon Cognito setup as described in cognito-setup.md
echo 2. Configure account linking in the Alexa Developer Console
echo 3. Test your skill by saying "Alexa, open X Viper"
echo.

pause