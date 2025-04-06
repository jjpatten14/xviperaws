@echo off
echo Deploying Improved Lambda Function
echo ================================
echo.
echo This script will:
echo 1. Create a temporary directory with improved Lambda code
echo 2. Install dependencies
echo 3. Package and deploy to AWS
echo.

set REGION=us-east-1
set LAMBDA_FUNCTION_NAME=xviper-alexa-skill
set S3_BUCKET=xviper-us-east1-965239903867

echo Creating temporary directory...
if exist lambda-improved rmdir /s /q lambda-improved
mkdir lambda-improved

echo Copying files...
copy /y lambda\*.* lambda-improved\
copy /y improve-lambda.js lambda-improved\index.js

echo Installing dependencies...
cd lambda-improved
call npm install --production

echo Creating deployment package...
cd ..
if exist deployment-improved.zip del deployment-improved.zip

cd lambda-improved
powershell -Command "Compress-Archive -Path * -DestinationPath ..\deployment-improved.zip -Force"
cd ..

echo Uploading to S3...
aws s3 cp deployment-improved.zip s3://%S3_BUCKET%/deployment-improved.zip --region %REGION%

echo Updating Lambda function...
aws lambda update-function-code --function-name %LAMBDA_FUNCTION_NAME% --s3-bucket %S3_BUCKET% --s3-key deployment-improved.zip --region %REGION%

echo Setting environment variables...
aws lambda update-function-configuration --function-name %LAMBDA_FUNCTION_NAME% --environment "Variables={DEFAULT_USERNAME=jjpatten14@gmail.com,DEFAULT_PASSWORD=Josh888888$,USER_MAPPING_TABLE=XviperUserMappings}" --region %REGION%

echo Done!
echo.
echo You can now test your Alexa skill again.
echo.
pause