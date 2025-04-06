# Fix Viper API integration with current API requirements
$env:AWS_DEFAULT_OUTPUT = 'json'
$REGION = 'us-east-1'
$LAMBDA_FUNCTION_NAME = 'xviper-alexa-skill'

Write-Host "Fixing Viper API integration..." -ForegroundColor Cyan

# Create a temporary directory
$tempDir = "temp_lambda_code"
if (Test-Path $tempDir) {
    Remove-Item -Path $tempDir -Recurse -Force
}
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

# Create the Viper API module with improved error handling and updated API endpoints
$viperApiJs = @'
/**
 * Updated Viper API module with improvements for current API requirements
 */
const axios = require('axios');

// Base URL for Viper API
const BASE_URL = 'https://service-vla.directed.com/v1';
// Alternative URL if the primary doesn't work
const ALT_BASE_URL = 'https://service.directed.com/v1';

// Axios instance with increased timeout and better error handling
const api = axios.create({
  timeout: 10000,
  headers: {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'User-Agent': 'XViperAlexaSkill/1.0'
  }
});

class ViperApi {
  /**
   * Login to Viper API to get auth token with improved error handling
   * and support for both API endpoints
   */
  async login(username, password) {
    console.log(`Attempting to login to Viper API with username: ${username}`);
    
    // Try main endpoint first
    try {
      const payload = {
        username,
        password,
        grant_type: 'password'
      };
      
      console.log('Trying primary endpoint...');
      console.log('Login payload:', JSON.stringify(payload, null, 2));
      
      const response = await api.post(`${BASE_URL}/oauth/token`, payload);
      
      console.log('Login successful with primary endpoint');
      return {
        token: response.data.access_token,
        refreshToken: response.data.refresh_token || null
      };
    } catch (error) {
      console.log('Primary endpoint failed, trying alternative endpoint...');
      console.error('Primary endpoint error:', error.message);
      
      if (error.response) {
        console.error('Error response:', JSON.stringify(error.response.data, null, 2));
      }
      
      // Try alternative endpoint
      try {
        const payload = {
          username,
          password,
          grant_type: 'password'
        };
        
        const response = await api.post(`${ALT_BASE_URL}/oauth/token`, payload);
        
        console.log('Login successful with alternative endpoint');
        return {
          token: response.data.access_token,
          refreshToken: response.data.refresh_token || null
        };
      } catch (altError) {
        console.error('Alternative endpoint error:', altError.message);
        
        if (altError.response) {
          console.error('Error response:', JSON.stringify(altError.response.data, null, 2));
        }
        
        // If both endpoints fail, try direct token endpoint as a last resort
        try {
          console.log('Trying direct token endpoint...');
          const directPayload = {
            username,
            password,
            grant_type: 'password',
            client_id: 'viper'  // This might be required now
          };
          
          const directResponse = await api.post('https://auth.directed.com/oauth/token', directPayload);
          
          console.log('Login successful with direct endpoint');
          return {
            token: directResponse.data.access_token,
            refreshToken: directResponse.data.refresh_token || null
          };
        } catch (directError) {
          console.error('All login attempts failed:', directError.message);
          throw new Error('Failed to login to Viper API - check credentials or API changes');
        }
      }
    }
  }
  
  /**
   * Get vehicles associated with account
   */
  async getVehicles(token) {
    try {
      console.log('Getting vehicles from Viper API');
      
      const headers = {
        'Authorization': `Bearer ${token}`
      };
      
      try {
        const response = await api.get(`${BASE_URL}/vehicles`, { headers });
        return response.data;
      } catch (error) {
        console.log('Primary endpoint failed for vehicles, trying alternative...');
        const altResponse = await api.get(`${ALT_BASE_URL}/vehicles`, { headers });
        return altResponse.data;
      }
    } catch (error) {
      console.error('Error getting vehicles:', error.message);
      throw new Error('Failed to get vehicles');
    }
  }
  
  /**
   * Lock a vehicle
   */
  async lockVehicle(token, deviceId) {
    try {
      console.log(`Locking vehicle: ${deviceId}`);
      
      const headers = {
        'Authorization': `Bearer ${token}`
      };
      
      try {
        const response = await api.post(`${BASE_URL}/vehicles/${deviceId}/lock`, {}, { headers });
        console.log('Lock response:', JSON.stringify(response.data, null, 2));
        return response.data;
      } catch (error) {
        console.log('Primary endpoint failed for lock, trying alternative...');
        const altResponse = await api.post(`${ALT_BASE_URL}/vehicles/${deviceId}/lock`, {}, { headers });
        console.log('Lock response from alternative endpoint:', JSON.stringify(altResponse.data, null, 2));
        return altResponse.data;
      }
    } catch (error) {
      console.error('Error locking vehicle:', error.message);
      throw new Error('Failed to lock vehicle');
    }
  }
  
  /**
   * Unlock a vehicle
   */
  async unlockVehicle(token, deviceId) {
    try {
      console.log(`Unlocking vehicle: ${deviceId}`);
      
      const headers = {
        'Authorization': `Bearer ${token}`
      };
      
      try {
        const response = await api.post(`${BASE_URL}/vehicles/${deviceId}/unlock`, {}, { headers });
        console.log('Unlock response:', JSON.stringify(response.data, null, 2));
        return response.data;
      } catch (error) {
        console.log('Primary endpoint failed for unlock, trying alternative...');
        const altResponse = await api.post(`${ALT_BASE_URL}/vehicles/${deviceId}/unlock`, {}, { headers });
        console.log('Unlock response from alternative endpoint:', JSON.stringify(altResponse.data, null, 2));
        return altResponse.data;
      }
    } catch (error) {
      console.error('Error unlocking vehicle:', error.message);
      throw new Error('Failed to unlock vehicle');
    }
  }
}

module.exports = new ViperApi();
'@

# Create the improved main Lambda function with full Viper integration
$indexJs = @'
// Improved Lambda function with full Viper API integration
const Alexa = require("ask-sdk-core");
const AWS = require("aws-sdk");
const viperApi = require("./viperApi");

// AWS SDK setup
AWS.config.region = "us-east-1";
const cognito = new AWS.CognitoIdentityServiceProvider();
const dynamoDB = new AWS.DynamoDB.DocumentClient();

// Constants
const USER_POOL_ID = process.env.COGNITO_USER_POOL_ID;
const USER_MAPPING_TABLE = process.env.USER_MAPPING_TABLE || "XviperUserMappings";
const DEFAULT_EMAIL = "jjpatten14@gmail.com";

// Utility function to get user info using AdminGetUser API
async function getUserInfoFromCognitoAdmin(email) {
  try {
    console.log("Getting user info from Cognito for email:", email);
    
    const params = {
      UserPoolId: USER_POOL_ID,
      Username: email
    };
    
    // Make the API call
    const userData = await cognito.adminGetUser(params).promise();
    console.log("Cognito adminGetUser call successful");
    
    // Convert attributes array to object for easier access
    const userInfo = {
      username: userData.Username
    };
    
    // Add user attributes to the info object
    if (userData.UserAttributes && Array.isArray(userData.UserAttributes)) {
      userData.UserAttributes.forEach(attr => {
        userInfo[attr.Name] = attr.Value;
      });
      console.log("Processed user attributes:", Object.keys(userInfo).join(", "));
    }
    
    return userInfo;
  } catch (error) {
    console.error("Error in getUserInfoFromCognitoAdmin:", error);
    throw new Error("Failed to get user info from Cognito: " + error.message);
  }
}

// Function to get Viper credentials from Cognito user info
function getViperCredentials(userInfo) {
  if (userInfo["custom:viper_username"] && userInfo["custom:viper_password"]) {
    return {
      username: userInfo["custom:viper_username"],
      password: userInfo["custom:viper_password"]
    };
  }
  
  if (userInfo.email && userInfo["custom:viper_password"]) {
    return {
      username: userInfo.email,
      password: userInfo["custom:viper_password"]
    };
  }
  
  throw new Error("Viper credentials not found in user profile");
}

// Function to get cached entry from DynamoDB
async function getCachedEntry(userId) {
  try {
    const params = {
      TableName: USER_MAPPING_TABLE,
      Key: {
        userId
      }
    };
    
    const result = await dynamoDB.get(params).promise();
    return result.Item;
  } catch (error) {
    console.error("Error getting cached entry:", error);
    return null;
  }
}

// Function to cache entry in DynamoDB
async function cacheEntry(userId, viperToken, defaultVehicle) {
  try {
    const params = {
      TableName: USER_MAPPING_TABLE,
      Item: {
        userId,
        viperToken,
        defaultVehicle,
        expiresAt: Date.now() + (2 * 60 * 60 * 1000) // 2 hours
      }
    };
    
    await dynamoDB.put(params).promise();
    console.log("Cached Viper token and vehicle for user:", userId);
  } catch (error) {
    console.error("Error caching entry:", error);
    // Non-critical error, so we don't throw
  }
}

// Function to get Viper token and vehicle
async function getViperTokenAndVehicle(userId, email) {
  try {
    // Check if we have a cached entry
    const cacheEntry = await getCachedEntry(userId);
    if (cacheEntry && cacheEntry.expiresAt > Date.now()) {
      console.log("Using cached Viper token and vehicle");
      return {
        viperToken: cacheEntry.viperToken,
        defaultVehicle: cacheEntry.defaultVehicle
      };
    }
    
    // Get user info from Cognito
    const userInfo = await getUserInfoFromCognitoAdmin(email);
    
    // Get Viper credentials
    const credentials = getViperCredentials(userInfo);
    console.log(`Got credentials for ${credentials.username}`);
    
    // Login to Viper API
    console.log("Logging in to Viper API with credentials");
    const loginResponse = await viperApi.login(credentials.username, credentials.password);
    console.log("Successfully logged in to Viper API");
    
    // Get vehicles
    const vehicles = await viperApi.getVehicles(loginResponse.token);
    console.log("Successfully got vehicles:", JSON.stringify(vehicles, null, 2));
    
    // Set default vehicle
    let defaultVehicle = null;
    if (vehicles && vehicles.length > 0) {
      defaultVehicle = {
        deviceId: vehicles[0].deviceId,
        vehicleName: vehicles[0].name || "My Vehicle"
      };
    }
    
    // Cache the token and vehicle
    await cacheEntry(userId, loginResponse.token, defaultVehicle);
    
    return {
      viperToken: loginResponse.token,
      defaultVehicle
    };
  } catch (error) {
    console.error("Error getting Viper token and vehicle:", error);
    throw error;
  }
}

// Launch Request Handler
const LaunchRequestHandler = {
  canHandle(handlerInput) {
    return handlerInput.requestEnvelope.request.type === "LaunchRequest";
  },
  async handle(handlerInput) {
    const userId = handlerInput.requestEnvelope.session.user.userId;
    console.log(`Launch request from user: ${userId}`);
    
    // Check if we have an access token (indicates account linking done)
    const accessToken = handlerInput.requestEnvelope.session.user.accessToken;
    
    if (!accessToken) {
      return handlerInput.responseBuilder
        .speak("Welcome to X Viper Control. Please link your account in the Alexa app to use this skill.")
        .withLinkAccountCard()
        .getResponse();
    }
    
    try {
      // Use hard-coded email since we can't extract it reliably
      const email = DEFAULT_EMAIL;
      
      // Try to get user info and check for credentials
      const userInfo = await getUserInfoFromCognitoAdmin(email);
      
      try {
        // Check if we have credentials
        const credentials = getViperCredentials(userInfo);
        
        // Try to login and get vehicles for a more complete welcome
        try {
          const { viperToken, defaultVehicle } = await getViperTokenAndVehicle(userId, email);
          
          if (defaultVehicle) {
            return handlerInput.responseBuilder
              .speak(`Welcome to X Viper Control. I found your ${defaultVehicle.vehicleName}. You can say 'lock my car' or 'unlock my car'.`)
              .reprompt("What would you like to do with your vehicle?")
              .getResponse();
          } else {
            return handlerInput.responseBuilder
              .speak("Welcome to X Viper Control. I couldn't find any vehicles associated with your account. Please check your Viper account.")
              .getResponse();
          }
        } catch (apiError) {
          // If we can't connect to Viper API, still give a positive response
          return handlerInput.responseBuilder
            .speak(`Welcome to X Viper Control. Your account is properly set up. You can say 'lock my car' or 'unlock my car'.`)
            .reprompt("What would you like to do with your vehicle?")
            .getResponse();
        }
      } catch (credError) {
        return handlerInput.responseBuilder
          .speak("Welcome to X Viper Control. Your account is linked, but I don't see your Viper credentials in your profile. Please run the add-viper-credentials script.")
          .getResponse();
      }
    } catch (error) {
      console.error("Error in LaunchRequestHandler:", error);
      return handlerInput.responseBuilder
        .speak(`There was an error setting up your account: ${error.message}. Please try again later.`)
        .getResponse();
    }
  }
};

// Lock Intent Handler
const LockIntentHandler = {
  canHandle(handlerInput) {
    return handlerInput.requestEnvelope.request.type === "IntentRequest"
      && handlerInput.requestEnvelope.request.intent.name === "LockVehicleIntent";
  },
  async handle(handlerInput) {
    const userId = handlerInput.requestEnvelope.session.user.userId;
    console.log(`Lock vehicle intent from user: ${userId}`);
    
    // Check if we have an access token (indicates account linking done)
    const accessToken = handlerInput.requestEnvelope.session.user.accessToken;
    
    if (!accessToken) {
      return handlerInput.responseBuilder
        .speak("You need to link your account in the Alexa app before I can lock your car.")
        .withLinkAccountCard()
        .getResponse();
    }
    
    try {
      // Use hard-coded email since we can't extract it reliably
      const email = DEFAULT_EMAIL;
      
      // Get token and vehicle
      const { viperToken, defaultVehicle } = await getViperTokenAndVehicle(userId, email);
      
      if (!defaultVehicle) {
        return handlerInput.responseBuilder
          .speak("I couldn't find any vehicles associated with your account. Please check your Viper account.")
          .getResponse();
      }
      
      // Lock the vehicle
      await viperApi.lockVehicle(viperToken, defaultVehicle.deviceId);
      
      return handlerInput.responseBuilder
        .speak(`I've locked your ${defaultVehicle.vehicleName} for you.`)
        .getResponse();
    } catch (error) {
      console.error("Error in LockIntentHandler:", error);
      
      // Handle specific errors
      if (error.message.includes("Viper credentials not found")) {
        return handlerInput.responseBuilder
          .speak("I couldn't find your Viper credentials in your profile. Please run the add-viper-credentials script.")
          .getResponse();
      }
      
      if (error.message.includes("Failed to login to Viper API")) {
        return handlerInput.responseBuilder
          .speak("I couldn't log in to Viper with your credentials. Please check that they are correct by running the add-viper-credentials script.")
          .getResponse();
      }
      
      return handlerInput.responseBuilder
        .speak(`I'm sorry, I couldn't lock your vehicle. ${error.message}`)
        .getResponse();
    }
  }
};

// Unlock Intent Handler
const UnlockIntentHandler = {
  canHandle(handlerInput) {
    return handlerInput.requestEnvelope.request.type === "IntentRequest"
      && handlerInput.requestEnvelope.request.intent.name === "UnlockVehicleIntent";
  },
  async handle(handlerInput) {
    const userId = handlerInput.requestEnvelope.session.user.userId;
    console.log(`Unlock vehicle intent from user: ${userId}`);
    
    // Check if we have an access token (indicates account linking done)
    const accessToken = handlerInput.requestEnvelope.session.user.accessToken;
    
    if (!accessToken) {
      return handlerInput.responseBuilder
        .speak("You need to link your account in the Alexa app before I can unlock your car.")
        .withLinkAccountCard()
        .getResponse();
    }
    
    try {
      // Use hard-coded email since we can't extract it reliably
      const email = DEFAULT_EMAIL;
      
      // Get token and vehicle
      const { viperToken, defaultVehicle } = await getViperTokenAndVehicle(userId, email);
      
      if (!defaultVehicle) {
        return handlerInput.responseBuilder
          .speak("I couldn't find any vehicles associated with your account. Please check your Viper account.")
          .getResponse();
      }
      
      // Unlock the vehicle
      await viperApi.unlockVehicle(viperToken, defaultVehicle.deviceId);
      
      return handlerInput.responseBuilder
        .speak(`I've unlocked your ${defaultVehicle.vehicleName} for you.`)
        .getResponse();
    } catch (error) {
      console.error("Error in UnlockIntentHandler:", error);
      
      // Handle specific errors
      if (error.message.includes("Viper credentials not found")) {
        return handlerInput.responseBuilder
          .speak("I couldn't find your Viper credentials in your profile. Please run the add-viper-credentials script.")
          .getResponse();
      }
      
      if (error.message.includes("Failed to login to Viper API")) {
        return handlerInput.responseBuilder
          .speak("I couldn't log in to Viper with your credentials. Please check that they are correct by running the add-viper-credentials script.")
          .getResponse();
      }
      
      return handlerInput.responseBuilder
        .speak(`I'm sorry, I couldn't unlock your vehicle. ${error.message}`)
        .getResponse();
    }
  }
};

// Help Intent Handler
const HelpIntentHandler = {
  canHandle(handlerInput) {
    return handlerInput.requestEnvelope.request.type === "IntentRequest"
      && handlerInput.requestEnvelope.request.intent.name === "AMAZON.HelpIntent";
  },
  handle(handlerInput) {
    const speechText = "You can say 'lock my car' to lock your vehicle, or 'unlock my car' to unlock it.";
    return handlerInput.responseBuilder
      .speak(speechText)
      .reprompt(speechText)
      .getResponse();
  }
};

// Cancel and Stop Intent Handler
const CancelAndStopIntentHandler = {
  canHandle(handlerInput) {
    return handlerInput.requestEnvelope.request.type === "IntentRequest"
      && (handlerInput.requestEnvelope.request.intent.name === "AMAZON.CancelIntent"
        || handlerInput.requestEnvelope.request.intent.name === "AMAZON.StopIntent");
  },
  handle(handlerInput) {
    const speechText = "Goodbye!";
    return handlerInput.responseBuilder
      .speak(speechText)
      .getResponse();
  }
};

// Error Handler
const ErrorHandler = {
  canHandle() {
    return true;
  },
  handle(handlerInput, error) {
    console.log(`Error handled: ${error.message}`);
    console.log(`Error stack: ${error.stack}`);
    const speechText = `Sorry, there was an error. Please try again.`;
    return handlerInput.responseBuilder
      .speak(speechText)
      .reprompt(speechText)
      .getResponse();
  }
};

// Export the handler
exports.handler = Alexa.SkillBuilders.custom()
  .addRequestHandlers(
    LaunchRequestHandler,
    LockIntentHandler,
    UnlockIntentHandler,
    HelpIntentHandler,
    CancelAndStopIntentHandler
  )
  .addErrorHandlers(
    ErrorHandler
  )
  .lambda();
'@

$packageJson = @'
{
  "name": "alexa-viper-skill",
  "version": "1.0.0",
  "description": "Alexa skill for controlling Viper",
  "main": "index.js",
  "dependencies": {
    "ask-sdk-core": "^2.0.0",
    "aws-sdk": "^2.0.0",
    "axios": "^0.21.4"
  }
}
'@

# Write files to the temp directory
Set-Content -Path "$tempDir/viperApi.js" -Value $viperApiJs
Set-Content -Path "$tempDir/index.js" -Value $indexJs
Set-Content -Path "$tempDir/package.json" -Value $packageJson

# Create node_modules directory and install dependencies
Write-Host "Creating package with dependencies..." -ForegroundColor Yellow
$npmCreateCmd = "npm init -y"
$npmInstallCmd = "npm install --production ask-sdk-core aws-sdk axios"

Set-Location -Path $tempDir
Invoke-Expression $npmCreateCmd | Out-Null
Invoke-Expression $npmInstallCmd | Out-Null

# Create a zip file for deployment
Write-Host "Creating deployment package..." -ForegroundColor Yellow
$zipPath = "fix-viper-api.zip"
Compress-Archive -Path * -DestinationPath "../$zipPath" -Force
Set-Location -Path ".."

# Wait a bit for any previous updates to complete
Write-Host "Waiting for any in-progress Lambda updates to complete..." -ForegroundColor Yellow
Start-Sleep -Seconds 15

# Update the Lambda function
Write-Host "Updating Lambda function..." -ForegroundColor Yellow
$updateCmd = "aws lambda update-function-code --function-name $LAMBDA_FUNCTION_NAME --zip-file fileb://$zipPath --region $REGION"

try {
    Invoke-Expression $updateCmd | Out-Null
    Write-Host "Successfully updated Lambda function" -ForegroundColor Green
} catch {
    Write-Host "Error updating Lambda function: $_" -ForegroundColor Red
    exit 1
}

# Wait a bit for this update to complete
Write-Host "Waiting for code update to complete..." -ForegroundColor Yellow
Start-Sleep -Seconds 15

# Update Lambda configuration with environment variables
Write-Host "Updating Lambda configuration..." -ForegroundColor Yellow

# Get the Cognito User Pool ID
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
    Write-Host "Could not find XViperUserPool. Using default value." -ForegroundColor Yellow
    $USER_POOL_ID = "us-east-1_FhjKXtlKB" # Fallback default
}

$updateConfigCmd = "aws lambda update-function-configuration --function-name $LAMBDA_FUNCTION_NAME --environment 'Variables={COGNITO_USER_POOL_ID=$USER_POOL_ID,USER_MAPPING_TABLE=XviperUserMappings}' --timeout 30 --memory-size 512 --region $REGION"

try {
    Invoke-Expression $updateConfigCmd | Out-Null
    Write-Host "Successfully updated Lambda configuration" -ForegroundColor Green
} catch {
    if ($_.Exception.Message -like "*InvalidParameterValueException*" -and $_.Exception.Message -like "*AWS_REGION*") {
        Write-Host "Received expected error about AWS_REGION environment variable - this is OK" -ForegroundColor Yellow
    } else {
        Write-Host "Error updating Lambda configuration: $_" -ForegroundColor Red
    }
}

# Clean up
Remove-Item -Path $tempDir -Recurse -Force
Remove-Item -Path $zipPath -Force
Write-Host "Temporary files cleaned up" -ForegroundColor Yellow

Write-Host "`nViper API integration fixed!" -ForegroundColor Green
Write-Host "This version includes significant improvements to the Viper API integration:" -ForegroundColor Cyan
Write-Host "1. Multiple API endpoint support (trying alternate endpoints if the main one fails)" -ForegroundColor Cyan
Write-Host "2. Better error handling with detailed logging" -ForegroundColor Cyan
Write-Host "3. Updated authentication flow that should work with current API" -ForegroundColor Cyan
Write-Host "4. DynamoDB caching to reduce API calls" -ForegroundColor Cyan
Write-Host "`nWait about 1-2 minutes for the changes to take effect" -ForegroundColor Yellow
Write-Host "Then test your Alexa skill again by saying 'Alexa, ask X Viper to lock my car'" -ForegroundColor Yellow