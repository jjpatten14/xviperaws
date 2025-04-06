# Script to update Lambda code with secureCognitoHandler
$env:AWS_DEFAULT_OUTPUT = 'json'
$REGION = 'us-east-1'
$LAMBDA_FUNCTION_NAME = 'xviper-alexa-skill'

Write-Host "Updating Lambda code to use secureCognitoHandler..." -ForegroundColor Cyan

# Create a temporary directory
$tempDir = "temp_lambda_code"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

# Copy the current Lambda code
Write-Host "Copying current Lambda code files..." -ForegroundColor Yellow
Copy-Item -Path "lambda/*.js" -Destination $tempDir -Force
Copy-Item -Path "lambda/package.json" -Destination $tempDir -Force

# Modify the cognitoIndex.js file to use secureCognitoHandler instead of alexaCognitoHandler
$cognitoIndexPath = "$tempDir/cognitoIndex.js"
$content = Get-Content -Path $cognitoIndexPath -Raw

# Change the import statement from alexaCognitoHandler to secureCognitoHandler
$updatedContent = $content -replace "const alexaCognitoHandler = require\('./alexaCognitoHandler'\);", "const alexaCognitoHandler = require('./secureCognitoHandler');"

# Save the updated file
Set-Content -Path $cognitoIndexPath -Value $updatedContent

# Create or make sure oauthIndex.js exists
$oauthIndexPath = "$tempDir/oauthIndex.js"
if (-not (Test-Path $oauthIndexPath)) {
    Write-Host "Creating oauthIndex.js for OAuth support..." -ForegroundColor Yellow
    $oauthContent = @"
/**
 * X Viper Alexa Skill Lambda Function - OAuth Router
 */
const Alexa = require('ask-sdk-core');
const cognitoIndex = require('./cognitoIndex');

// This file serves as a router to ensure we're using Cognito auth
exports.handler = cognitoIndex.handler;
"@
    Set-Content -Path $oauthIndexPath -Value $oauthContent
}

# Create the new Lambda entry point index.js that will route to the appropriate handler
$indexPath = "$tempDir/index.js"
$indexContent = @"
/**
 * X Viper Alexa Skill Lambda Function - Main Entry Point
 */
const oauthIndex = require('./oauthIndex');

// This is the main entry point, which routes to the OAuth handler
exports.handler = oauthIndex.handler;
"@
Set-Content -Path $indexPath -Value $indexContent

# Create a zip file for deployment
$zipPath = "secure-lambda-deployment.zip"
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
Write-Host "Temporary files cleaned up" -ForegroundColor Yellow

Write-Host "`nLambda code successfully updated to use secureCognitoHandler!" -ForegroundColor Green
Write-Host "This should fix the 'Failed to get userinfo from cognito' error" -ForegroundColor Green
Write-Host "Try using your Alexa skill again after about 1 minute for the changes to take effect" -ForegroundColor Cyan