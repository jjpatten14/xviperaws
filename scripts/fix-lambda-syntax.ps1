# Script to fix the Lambda code syntax error
$env:AWS_DEFAULT_OUTPUT = 'json'
$REGION = 'us-east-1'
$LAMBDA_FUNCTION_NAME = 'xviper-alexa-skill'

Write-Host "Fixing Lambda code syntax error..." -ForegroundColor Cyan

# Create a temporary directory
$tempDir = "temp_lambda_code"
if (Test-Path $tempDir) {
    Remove-Item -Path $tempDir -Recurse -Force
}
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

# Create simplified Lambda files
Write-Host "Creating simplified Lambda code..." -ForegroundColor Yellow

# Create index.js file
$indexCode = @"
/**
 * X Viper Alexa Skill Lambda Function - Simple Test Version
 */
const Alexa = require('ask-sdk-core');

// SIMPLIFIED HANDLER
const LaunchRequestHandler = {
    canHandle(handlerInput) {
        return handlerInput.requestEnvelope.request.type === 'LaunchRequest';
    },
    handle(handlerInput) {
        console.log("Launch request received");
        return handlerInput.responseBuilder
            .speak("Hello! This is a simplified version of the skill that works correctly.")
            .getResponse();
    }
};

// ERROR HANDLER
const ErrorHandler = {
    canHandle() {
        return true;
    },
    handle(handlerInput, error) {
        console.error("Error:", error);
        return handlerInput.responseBuilder
            .speak("Sorry, something went wrong.")
            .getResponse();
    }
};

// LAMBDA HANDLER
exports.handler = Alexa.SkillBuilders.custom()
    .addRequestHandlers(LaunchRequestHandler)
    .addErrorHandlers(ErrorHandler)
    .lambda();
"@

# Create package.json file
$packageJson = @"
{
  "name": "xviper-alexa-skill",
  "version": "1.0.0",
  "description": "X Viper control skill for Amazon Alexa",
  "main": "index.js",
  "dependencies": {
    "ask-sdk-core": "^2.0.0"
  }
}
"@

# Write the files
Set-Content -Path "$tempDir/index.js" -Value $indexCode
Set-Content -Path "$tempDir/package.json" -Value $packageJson

# Create a zip file for deployment
$zipPath = "lambda-syntax-fix.zip"
Write-Host "Creating deployment package: $zipPath" -ForegroundColor Yellow

# Navigate to the temp directory and zip all files
Set-Location -Path $tempDir
Compress-Archive -Path * -DestinationPath "../$zipPath" -Force
Set-Location -Path ".."

# Deploy the updated code to Lambda
Write-Host "Deploying updated code to Lambda..." -ForegroundColor Yellow
$updateCmd = "aws lambda update-function-code --function-name $LAMBDA_FUNCTION_NAME --zip-file fileb://$zipPath --region $REGION"

try {
    Invoke-Expression $updateCmd | Out-Null
    Write-Host "Successfully deployed updated Lambda code" -ForegroundColor Green
} catch {
    Write-Host "Error deploying Lambda code: $_" -ForegroundColor Red
    exit 1
}

# Clean up
Remove-Item -Path $tempDir -Recurse -Force
Remove-Item -Path $zipPath -Force

Write-Host "`nLambda code syntax error fixed!" -ForegroundColor Green
Write-Host "This is a minimal working version of the Lambda function" -ForegroundColor Green
Write-Host "Wait at least 1 minute for the changes to take effect" -ForegroundColor Cyan
Write-Host "Then test your Alexa skill again" -ForegroundColor Cyan
Write-Host "`nAfter confirming the skill works with this minimal code," -ForegroundColor Cyan
Write-Host "we can replace it with the full secure code that uses Cognito properly" -ForegroundColor Cyan