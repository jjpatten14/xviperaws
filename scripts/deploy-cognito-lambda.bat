@echo off
echo Deploying Cognito-Compatible Lambda Function
echo ==========================================
echo.
echo This script will:
echo 1. Create a Lambda function that works with Cognito account linking
echo 2. Package it with all dependencies
echo 3. Deploy it to AWS
echo 4. Set up environment variables
echo.

set REGION=us-east-1
set LAMBDA_FUNCTION_NAME=xviper-alexa-skill
set S3_BUCKET=xviper-us-east1-965239903867
set DEFAULT_USERNAME=jjpatten14@gmail.com
set DEFAULT_PASSWORD=Josh888888$

echo Creating temporary directory...
if exist lambda-cognito rmdir /s /q lambda-cognito
mkdir lambda-cognito

echo Copying files...
xcopy /s /y lambda\*.* lambda-cognito\
copy /y lambda\cognitoIndex.js lambda-cognito\index.js
copy /y lambda\alexaCognitoHandler.js lambda-cognito\

echo Installing dependencies...
cd lambda-cognito
call npm install --production
cd ..

echo Creating deployment package...
if exist cognito-deployment.zip del cognito-deployment.zip

cd lambda-cognito
powershell -Command "Compress-Archive -Path * -DestinationPath ..\cognito-deployment.zip -Force"
cd ..

echo Uploading to S3...
aws s3 cp cognito-deployment.zip s3://%S3_BUCKET%/cognito-deployment.zip --region %REGION%

echo Updating Lambda function...
aws lambda update-function-code --function-name %LAMBDA_FUNCTION_NAME% --s3-bucket %S3_BUCKET% --s3-key cognito-deployment.zip --region %REGION%

echo Setting environment variables...
aws lambda update-function-configuration --function-name %LAMBDA_FUNCTION_NAME% --environment "Variables={DEFAULT_USERNAME=%DEFAULT_USERNAME%,DEFAULT_PASSWORD=%DEFAULT_PASSWORD%,USER_MAPPING_TABLE=XviperUserMappings}" --region %REGION%

echo Done!
echo.
echo Your Lambda function is now ready to work with Cognito account linking!
echo Next, run setup-managed-login.bat to configure Cognito properly.
echo.
pause