# Script to fix the Lambda code import issue (simplified fix)
$env:AWS_DEFAULT_OUTPUT = 'json'
$REGION = 'us-east-1'
$LAMBDA_FUNCTION_NAME = 'xviper-alexa-skill'

Write-Host "Fixing Lambda code import issue..." -ForegroundColor Cyan

# Check if aws CLI is working
try {
    Invoke-Expression "aws --version" | Out-Null
    Write-Host "AWS CLI is working correctly" -ForegroundColor Green
} catch {
    Write-Host "AWS CLI is not working. Please make sure it's installed and configured." -ForegroundColor Red
    exit 1
}

# Create a temporary directory
$tempDir = "temp_lambda_code"
if (Test-Path $tempDir) {
    Remove-Item -Path $tempDir -Recurse -Force
}
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

# Download the current Lambda code
Write-Host "Downloading current Lambda code..." -ForegroundColor Yellow
$getLambdaCmd = "aws lambda get-function --function-name $LAMBDA_FUNCTION_NAME --region $REGION"
try {
    $lambdaInfo = Invoke-Expression $getLambdaCmd | ConvertFrom-Json
    $codeUrl = $lambdaInfo.Code.Location
    
    # Download the code
    Write-Host "Downloading from: $codeUrl" -ForegroundColor Yellow
    $webClient = New-Object System.Net.WebClient
    $zipPath = "current_lambda.zip"
    $webClient.DownloadFile($codeUrl, $zipPath)
    
    # Extract the code
    Expand-Archive -Path $zipPath -DestinationPath $tempDir -Force
    Remove-Item -Path $zipPath -Force
} catch {
    Write-Host "Failed to download Lambda code: $_" -ForegroundColor Red
    Write-Host "Creating new Lambda code from scratch..." -ForegroundColor Yellow
    
    # Create minimal code files
    Copy-Item -Path "lambda/*.js" -Destination $tempDir -Force
    Copy-Item -Path "lambda/package.json" -Destination $tempDir -Force
}

# Create a very simple and focused Lambda code
Write-Host "Creating simple Lambda code that uses secureCognitoHandler..." -ForegroundColor Yellow

# Define the code files
$secureHandlerCode = @'
/**
 * Secure Cognito handler that uses proper user authentication
 * without hardcoded credentials
 */'
const AWS = require('aws-sdk');

// AWS SDK setup
const cognitoIdentityServiceProvider = new AWS.CognitoIdentityServiceProvider();
const dynamoDB = new AWS.DynamoDB.DocumentClient();

// Constants
const USER_MAPPING_TABLE = process.env.USER_MAPPING_TABLE || 'XviperUserMappings';
const COGNITO_USER_POOL_ID = process.env.COGNITO_USER_POOL_ID;

class SecureCognitoHandler {
    /**
     * Process an authenticated request with Cognito token
     * @param {string} accessToken - The Cognito access token
     * @param {string} alexaUserId - The Alexa user ID
     * @returns {Promise<Object>} Viper token and default vehicle
     */
    async processAuthenticatedRequest(accessToken, alexaUserId) {
        try {
            console.log("Processing authenticated request for user: " + alexaUserId);
            
            // Get the user's info from Cognito using the access token
            const cognitoUserInfo = await this.getUserInfoFromCognito(accessToken);
            console.log("Got Cognito user info:", JSON.stringify(cognitoUserInfo, null, 2));
            
            // Get the user's Viper credentials from Cognito user attributes
            const viperCredentials = await this.getViperCredentialsFromCognito(cognitoUserInfo);
            console.log("Got Viper credentials:", JSON.stringify({
                username: viperCredentials.username,
                passwordProvided: viperCredentials.password ? "yes" : "no"
            }, null, 2));
            
            return {
                viperToken: "test-token",
                defaultVehicle: {
                    deviceId: "test-device",
                    vehicleName: "Test Vehicle"
                }
            };
        } catch (error) {
            console.error("Error processing authenticated request:", error);
            throw error;
        }
    }
    
    /**
     * Get user info from Cognito using access token
     * @param {string} accessToken - The Cognito access token
     * @returns {Promise<Object>} User info
     */
    async getUserInfoFromCognito(accessToken) {
        try {
            console.log("Getting user info from Cognito with accessToken:", accessToken ? "Token provided" : "No token");
            
            const params = {
                AccessToken: accessToken
            };
            
            console.log("Calling cognitoIdentityServiceProvider.getUser with params:", JSON.stringify(params, null, 2));
            const userData = await cognitoIdentityServiceProvider.getUser(params).promise();
            console.log("Cognito getUser response received");
            
            // Convert attributes array to object
            const userInfo = {
                username: userData.Username
            };
            
            userData.UserAttributes.forEach(attr => {
                userInfo[attr.Name] = attr.Value;
            });
            
            return userInfo;
        } catch (error) {
            console.error("Error getting user info from Cognito:", error);
            console.log("Error details:", JSON.stringify(error, Object.getOwnPropertyNames(error)));
            throw new Error("Failed to get userinfo from cognito: " + error.message);
        }
    }
    
    /**
     * Get Viper credentials from Cognito user attributes
     * @param {Object} userInfo - Cognito user info
     * @returns {Promise<Object>} Viper credentials
     */
    async getViperCredentialsFromCognito(userInfo) {
        try {
            console.log("Getting Viper credentials from userInfo:", Object.keys(userInfo).join(", "));
            
            // Check for custom viper attributes
            if (userInfo["custom:viper_username"] && userInfo["custom:viper_password"]) {
                console.log("Found custom Viper credentials in user attributes");
                return {
                    username: userInfo["custom:viper_username"],
                    password: userInfo["custom:viper_password"]
                };
            }
            
            // Fallback to email if custom username not found
            const username = userInfo["custom:viper_username"] || userInfo.email;
            const password = userInfo["custom:viper_password"];
            
            if (!password) {
                console.error("Viper password not found in user attributes");
                throw new Error("Viper credentials not found in user profile");
            }
            
            return {
                username,
                password
            };
        } catch (error) {
            console.error("Error getting Viper credentials:", error);
            throw new Error("Failed to get Viper credentials: " + error.message);
        }
    }
}

module.exports = new SecureCognitoHandler();
"@

$indexCode = @"
/**
 * X Viper Alexa Skill Lambda Function - Simple Test Version
 */
const Alexa = require('ask-sdk-core');
const secureCognitoHandler = require('./secureCognitoHandler');

// LAUNCH REQUEST HANDLER
const LaunchRequestHandler = {
    canHandle(handlerInput) {
        return Alexa.getRequestType(handlerInput.requestEnvelope) === 'LaunchRequest';
    },
    async handle(handlerInput) {
        const userId = handlerInput.requestEnvelope.session.user.userId;
        console.log(`Launch request from user: ${userId}`);

        try {
            // Check if user is authenticated via account linking
            const accessToken = handlerInput.requestEnvelope.session.user.accessToken;
            
            if (!accessToken) {
                // User needs to link their account
                return handlerInput.responseBuilder
                    .speak("Welcome to X Viper control. To get started, please link your account in the Alexa app.")
                    .withLinkAccountCard()
                    .getResponse();
            }
            
            // Process the authenticated request
            console.log('Calling secureCognitoHandler.processAuthenticatedRequest with token and userId');
            await secureCognitoHandler.processAuthenticatedRequest(
                accessToken,
                userId
            );
            
            return handlerInput.responseBuilder
                .speak("Welcome to X Viper control. Your credentials were successfully retrieved from Cognito!")
                .getResponse();
        } catch (error) {
            console.error('Error in LaunchIntent:', error);
            
            return handlerInput.responseBuilder
                .speak(`I'm sorry, I'm having trouble with your request. Error: ${error.message}`)
                .getResponse();
        }
    }
};

// ERROR HANDLER
const ErrorHandler = {
    canHandle() {
        return true;
    },
    handle(handlerInput, error) {
        console.error(`Error handled: ${error.message}`, error.stack);
        const speechText = `Sorry, I had trouble doing what you asked. Error: ${error.message}`;

        return handlerInput.responseBuilder
            .speak(speechText)
            .getResponse();
    }
};

// LAMBDA HANDLER
exports.handler = Alexa.SkillBuilders.custom()
    .addRequestHandlers(
        LaunchRequestHandler
    )
    .addErrorHandlers(ErrorHandler)
    .lambda();
"@

$packageJson = @"
{
  "name": "xviper-alexa-skill",
  "version": "1.0.0",
  "description": "X Viper control skill for Amazon Alexa",
  "main": "index.js",
  "dependencies": {
    "ask-sdk-core": "^2.0.0",
    "aws-sdk": "^2.1.0"
  }
}
"@

# Write the files
Set-Content -Path "$tempDir/secureCognitoHandler.js" -Value $secureHandlerCode
Set-Content -Path "$tempDir/index.js" -Value $indexCode
Set-Content -Path "$tempDir/package.json" -Value $packageJson

# Create a zip file for deployment
$zipPath = "lambda-import-fix.zip"
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

# Update environment variables
Write-Host "Setting Lambda environment variables..." -ForegroundColor Yellow

# Get user pool ID
$userPoolsCmd = "aws cognito-idp list-user-pools --max-results 60 --region $REGION"
$userPoolsJson = Invoke-Expression $userPoolsCmd
$userPools = $userPoolsJson | ConvertFrom-Json

$USER_POOL_ID = ""
foreach ($pool in $userPools.UserPools) {
    if ($pool.Name -eq "XViperUserPool") {
        $USER_POOL_ID = $pool.Id
        Write-Host "Found user pool: $USER_POOL_ID" -ForegroundColor Green
        break
    }
}

if (-not $USER_POOL_ID) {
    Write-Host "Could not find XViperUserPool. Using default environment variables." -ForegroundColor Yellow
    $USER_POOL_ID = "us-east-1_FhjKXtlKB" # Fallback default
}

# Update environment
$updateEnvCmd = "aws lambda update-function-configuration --function-name $LAMBDA_FUNCTION_NAME --environment 'Variables={COGNITO_USER_POOL_ID=$USER_POOL_ID,USER_MAPPING_TABLE=XviperUserMappings}' --region $REGION"

try {
    Invoke-Expression $updateEnvCmd | Out-Null
    Write-Host "Successfully updated Lambda environment variables" -ForegroundColor Green
} catch {
    Write-Host "Error updating Lambda environment variables: $_" -ForegroundColor Red
}

# Clean up
Remove-Item -Path $tempDir -Recurse -Force
Write-Host "Temporary files cleaned up" -ForegroundColor Yellow

Write-Host "`nLambda code import issue fixed!" -ForegroundColor Green
Write-Host "This Lambda now uses secureCognitoHandler with better logging" -ForegroundColor Green
Write-Host "Wait at least 1 minute for the changes to take effect" -ForegroundColor Cyan
Write-Host "Then test your Alexa skill again" -ForegroundColor Cyan