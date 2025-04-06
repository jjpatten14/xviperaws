# Fix missing intents and improving error handling
$env:AWS_DEFAULT_OUTPUT = 'json'
$REGION = 'us-east-1'
$LAMBDA_FUNCTION_NAME = 'xviper-alexa-skill'

Write-Host "Fixing missing intents and improving error handling..." -ForegroundColor Cyan

# Create a temporary directory
$tempDir = "temp_lambda_code"
if (Test-Path $tempDir) {
    Remove-Item -Path $tempDir -Recurse -Force
}
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

# Create the Viper API module with the exact original working implementation
$viperApiJs = @'
/**
 * API client for interacting with the Viper API - Using the original working implementation
 */
const axios = require('axios');

class ViperApi {
    constructor() {
        this.BASE_URL = 'https://www.vcp.cloud/v1';
        this.LOGIN_URL = `${this.BASE_URL}/auth/login`;
        this.DEVICES_URL = `${this.BASE_URL}/devices/search/null?limit=100&deviceFilter=Installed&subAccounts=false`;
        this.COMMAND_URL = `${this.BASE_URL}/devices/command`;
        
        // Command constants
        this.COMMAND_LOCK = 'arm';
        this.COMMAND_UNLOCK = 'disarm';
        this.COMMAND_START = 'remote';  // Same command toggles start/stop
        this.COMMAND_STOP = 'remote';
        this.COMMAND_TRUNK = 'trunk';
        this.COMMAND_PANIC = 'panic';
    }

    /**
     * Login to the Viper API using the original working approach
     */
    async login(username, password) {
        try {
            console.log(`Attempting login for user: ${username}`);
            
            const formData = new URLSearchParams();
            formData.append('username', username);
            formData.append('password', password);

            console.log('Using original working login URL:', this.LOGIN_URL);
            console.log('Using form-encoded payload with exact format that worked previously');

            const response = await axios.post(this.LOGIN_URL, formData, {
                headers: {
                    'Content-Type': 'application/x-www-form-urlencoded'
                }
            });

            if (response.data && response.data.results && response.data.results.authToken) {
                const authToken = response.data.results.authToken.accessToken;
                const user = response.data.results.user;
                
                console.log(`Login successful for ${user.firstName} ${user.lastName}`);
                
                return {
                    token: authToken,
                    userId: user.id,
                    firstName: user.firstName,
                    lastName: user.lastName,
                    email: user.email,
                    username: user.username
                };
            } else {
                throw new Error('Invalid login response format');
            }
        } catch (error) {
            console.error('Login error:', error.response ? error.response.data : error.message);
            throw new Error(`Login failed: ${error.message}`);
        }
    }

    /**
     * Get all vehicles for the user
     */
    async getVehicles(authToken) {
        try {
            console.log('Fetching vehicles');
            
            const response = await axios.get(this.DEVICES_URL, {
                headers: {
                    'Authorization': `Bearer ${authToken}`
                }
            });

            if (response.data && response.data.results && response.data.results.devices) {
                const devices = response.data.results.devices;
                console.log(`Found ${devices.length} vehicles`);
                
                return devices.map(device => this._mapDeviceToVehicle(device));
            } else {
                throw new Error('Invalid get vehicles response format');
            }
        } catch (error) {
            console.error('Get vehicles error:', error.response ? error.response.data : error.message);
            throw new Error(`Failed to get vehicles: ${error.message}`);
        }
    }

    /**
     * Map API device data to vehicle object
     */
    _mapDeviceToVehicle(device) {
        return {
            id: device.id,
            deviceId: device.id, // For this API, id is used as deviceId for commands
            assetId: device.assetId || '',
            airId: device.airId || '',
            name: device.name || 'My Vehicle',
            model: device.vehicleModel || 'Unknown Model',
            year: device.vehicleYear || '',
            make: device.vehicleMake || '',
            status: device.status || 'unknown',
            lastKnownLocation: device.lastKnownLocation || '',
            lastKnownAddress: device.lastKnownAddress || '',
            isLocked: device.ignitionOn === undefined ? false : !device.ignitionOn,
            isOnline: (device.status || '').toLowerCase() === 'activewithmobile',
            engineRunning: !!device.ignitionOn
        };
    }

    /**
     * Send a command to a vehicle
     */
    async sendVehicleCommand(authToken, deviceId, command) {
        try {
            console.log(`Sending command "${command}" to device ${deviceId}`);
            
            const numericDeviceId = parseInt(deviceId, 10);
            if (isNaN(numericDeviceId)) {
                throw new Error('Invalid device ID format, must be numeric');
            }

            const commandData = {
                deviceId: numericDeviceId,
                command: command,
                param: null
            };

            const response = await axios.post(this.COMMAND_URL, commandData, {
                headers: {
                    'Authorization': `Bearer ${authToken}`,
                    'Content-Type': 'application/json'
                }
            });

            console.log('Command response:', JSON.stringify(response.data));
            return response.data;
        } catch (error) {
            console.error('Command error:', error.response ? error.response.data : error.message);
            throw new Error(`Failed to send command: ${error.message}`);
        }
    }

    /**
     * Lock a vehicle
     */
    async lockVehicle(authToken, deviceId) {
        return this.sendVehicleCommand(authToken, deviceId, this.COMMAND_LOCK);
    }

    /**
     * Unlock a vehicle
     */
    async unlockVehicle(authToken, deviceId) {
        return this.sendVehicleCommand(authToken, deviceId, this.COMMAND_UNLOCK);
    }

    /**
     * Start a vehicle's engine
     */
    async startVehicle(authToken, deviceId) {
        return this.sendVehicleCommand(authToken, deviceId, this.COMMAND_START);
    }

    /**
     * Stop a vehicle's engine
     */
    async stopVehicle(authToken, deviceId) {
        return this.sendVehicleCommand(authToken, deviceId, this.COMMAND_STOP);
    }

    /**
     * Open a vehicle's trunk
     */
    async openTrunk(authToken, deviceId) {
        return this.sendVehicleCommand(authToken, deviceId, this.COMMAND_TRUNK);
    }

    /**
     * Activate a vehicle's panic alarm
     */
    async activatePanic(authToken, deviceId) {
        return this.sendVehicleCommand(authToken, deviceId, this.COMMAND_PANIC);
    }
}

module.exports = new ViperApi();
'@

# Create the updated model JSON with all intents
$modelJson = @'
{
    "interactionModel": {
        "languageModel": {
            "invocationName": "x viper",
            "intents": [
                {
                    "name": "AMAZON.CancelIntent",
                    "samples": []
                },
                {
                    "name": "AMAZON.HelpIntent",
                    "samples": []
                },
                {
                    "name": "AMAZON.StopIntent",
                    "samples": []
                },
                {
                    "name": "LockVehicleIntent",
                    "slots": [],
                    "samples": [
                        "lock my vehicle",
                        "lock the car",
                        "lock my car",
                        "lock the vehicle"
                    ]
                },
                {
                    "name": "UnlockVehicleIntent",
                    "slots": [],
                    "samples": [
                        "unlock my vehicle",
                        "unlock the car",
                        "unlock my car",
                        "unlock the vehicle"
                    ]
                },
                {
                    "name": "StartEngineIntent",
                    "slots": [],
                    "samples": [
                        "start my car",
                        "start the engine",
                        "start the vehicle",
                        "start engine",
                        "remote start"
                    ]
                },
                {
                    "name": "StopEngineIntent",
                    "slots": [],
                    "samples": [
                        "stop my car",
                        "stop the engine",
                        "stop the vehicle",
                        "shut off engine",
                        "turn off car"
                    ]
                },
                {
                    "name": "OpenTrunkIntent",
                    "slots": [],
                    "samples": [
                        "open trunk",
                        "open the trunk",
                        "open my trunk",
                        "pop the trunk"
                    ]
                },
                {
                    "name": "DebugApiIntent",
                    "slots": [],
                    "samples": [
                        "debug api",
                        "debug the api",
                        "test the api",
                        "run api test"
                    ]
                }
            ],
            "types": []
        }
    }
}
'@

# Create the updated index.js with all intent handlers and better error handling
$indexJs = @'
/**
 * Xviper Alexa Skill Lambda Function - Complete with all intents and better error reporting
 */
const Alexa = require('ask-sdk-core');
const AWS = require('aws-sdk');
const viperApi = require('./viperApi');

// AWS SDK setup
AWS.config.region = process.env.AWS_REGION || 'us-east-1';
const cognito = new AWS.CognitoIdentityServiceProvider();
const dynamoDB = new AWS.DynamoDB.DocumentClient();

// Constants
const USER_POOL_ID = process.env.COGNITO_USER_POOL_ID;
const DEFAULT_EMAIL = process.env.DEFAULT_EMAIL || 'jjpatten14@gmail.com';
const USER_MAPPING_TABLE = process.env.USER_MAPPING_TABLE || 'XviperUserMappings';

/**
 * Get user info from Cognito using AdminGetUser API
 */
async function getUserInfoFromCognito(email) {
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
    console.error("Error in getUserInfoFromCognito:", error);
    throw new Error("Failed to get user info from Cognito: " + error.message);
  }
}

/**
 * Get Viper credentials from Cognito user attributes
 */
function getViperCredentials(userInfo) {
  console.log("Looking for Viper credentials in user attributes");
  
  if (userInfo["custom:viper_username"] && userInfo["custom:viper_password"]) {
    console.log(`Found credentials for ${userInfo["custom:viper_username"]}`);
    return {
      username: userInfo["custom:viper_username"],
      password: userInfo["custom:viper_password"]
    };
  }
  
  throw new Error("Viper credentials not found in Cognito user profile");
}

/**
 * Cache user data in DynamoDB
 */
async function cacheUserData(userId, token, defaultVehicle) {
  try {
    const params = {
      TableName: USER_MAPPING_TABLE,
      Item: {
        userId: userId,
        token: token,
        defaultVehicle: defaultVehicle,
        expiresAt: Date.now() + (2 * 60 * 60 * 1000) // 2 hours
      }
    };
    
    await dynamoDB.put(params).promise();
    console.log(`Cached token and vehicle for user ${userId}`);
  } catch (error) {
    console.error("Error caching user data:", error);
    // Non-critical, we can proceed without cache
  }
}

/**
 * Get cached user data
 */
async function getCachedUserData(userId) {
  try {
    const params = {
      TableName: USER_MAPPING_TABLE,
      Key: {
        userId: userId
      }
    };
    
    const result = await dynamoDB.get(params).promise();
    if (result.Item && result.Item.expiresAt > Date.now()) {
      console.log("Using cached token and vehicle");
      return result.Item;
    }
    
    return null;
  } catch (error) {
    console.error("Error getting cached data:", error);
    return null;
  }
}

/**
 * Format API errors to be more user-friendly
 */
function formatErrorForUser(error) {
  console.error("Original error:", error);
  
  // Extract the error message
  const errorMessage = error.message || "An unknown error occurred";
  
  // Check for common patterns and provide helpful responses
  if (errorMessage.includes("credentials not found")) {
    return "I couldn't find your Viper credentials. Please run the add-viper-credentials script to set them up.";
  }
  
  if (errorMessage.includes("Login failed")) {
    return "I couldn't log in to the Viper service with your credentials. Please check that they are correct.";
  }
  
  if (errorMessage.includes("Failed to get vehicles")) {
    return "I logged in successfully but couldn't find any vehicles in your account.";
  }
  
  if (errorMessage.includes("command") && errorMessage.includes("fail")) {
    return "I connected to your vehicle but the command wasn't accepted. Your vehicle might be offline or unavailable.";
  }
  
  if (errorMessage.includes("timeout") || errorMessage.includes("network")) {
    return "I couldn't connect to the Viper servers. There might be a network issue or the service might be down.";
  }
  
  // Catch-all with some detail for debugging
  return `There was a problem communicating with your vehicle: ${errorMessage}`;
}

/**
 * Generic vehicle command handler
 */
async function handleVehicleCommand(handlerInput, commandFunction, commandName) {
  const userId = Alexa.getUserId(handlerInput.requestEnvelope);
  console.log(`${commandName} intent from user: ${userId}`);
  
  // Check if we have an access token (indicates account linking done)
  const accessToken = handlerInput.requestEnvelope.session.user.accessToken;
  
  if (!accessToken) {
    return handlerInput.responseBuilder
      .speak(`You need to link your account in the Alexa app before I can ${commandName.toLowerCase()} your car.`)
      .withLinkAccountCard()
      .getResponse();
  }
  
  try {
    // Check for cached data first
    const cachedData = await getCachedUserData(userId);
    if (cachedData && cachedData.token && cachedData.defaultVehicle) {
      try {
        await commandFunction(cachedData.token, cachedData.defaultVehicle.deviceId);
        
        return handlerInput.responseBuilder
          .speak(`I've ${commandName.toLowerCase()}ed your ${cachedData.defaultVehicle.name || 'vehicle'} for you.`)
          .getResponse();
      } catch (cacheError) {
        console.log("Cache token expired or command failed, getting fresh token");
        // If cached token fails, continue with getting fresh token
      }
    }
    
    // Get user credentials from Cognito
    const userInfo = await getUserInfoFromCognito(DEFAULT_EMAIL);
    const credentials = getViperCredentials(userInfo);
    
    // Login with original API method
    console.log(`Logging in with credentials for: ${credentials.username}`);
    const loginResult = await viperApi.login(credentials.username, credentials.password);
    console.log("Login successful, got token");
    
    // Get vehicles
    const vehicles = await viperApi.getVehicles(loginResult.token);
    console.log(`Found ${vehicles.length} vehicles`);
    
    if (!vehicles || vehicles.length === 0) {
      return handlerInput.responseBuilder
        .speak("I couldn't find any vehicles associated with your account.")
        .getResponse();
    }
    
    // Cache the token and default vehicle
    const defaultVehicle = vehicles[0];
    await cacheUserData(userId, loginResult.token, defaultVehicle);
    
    // Send the command
    await commandFunction(loginResult.token, defaultVehicle.deviceId);
    
    return handlerInput.responseBuilder
      .speak(`I've ${commandName.toLowerCase()}ed your ${defaultVehicle.name || 'vehicle'} for you.`)
      .getResponse();
  } catch (error) {
    console.error(`Error in ${commandName}IntentHandler:`, error);
    
    // Format the error message for the user
    const userMessage = formatErrorForUser(error);
    
    return handlerInput.responseBuilder
      .speak(userMessage)
      .getResponse();
  }
}

// Launch Request Handler
const LaunchRequestHandler = {
  canHandle(handlerInput) {
    return Alexa.getRequestType(handlerInput.requestEnvelope) === 'LaunchRequest';
  },
  async handle(handlerInput) {
    const userId = Alexa.getUserId(handlerInput.requestEnvelope);
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
      // Try to get user info and check for credentials
      const userInfo = await getUserInfoFromCognito(DEFAULT_EMAIL);
      
      try {
        // Check if we have credentials
        const credentials = getViperCredentials(userInfo);
        
        return handlerInput.responseBuilder
          .speak(`Welcome to X Viper Control. You can say 'lock my car', 'unlock my car', 'start my car', 'stop my car', or 'open trunk'.`)
          .reprompt("What would you like to do with your vehicle?")
          .getResponse();
      } catch (credError) {
        return handlerInput.responseBuilder
          .speak("Welcome to X Viper Control. Your account is linked, but I don't see your Viper credentials in your profile. Please run the add-viper-credentials script.")
          .getResponse();
      }
    } catch (error) {
      console.error("Error in LaunchRequestHandler:", error);
      return handlerInput.responseBuilder
        .speak(`There was an error setting up your account: ${formatErrorForUser(error)}. Please try again later.`)
        .getResponse();
    }
  }
};

// Lock Intent Handler
const LockIntentHandler = {
  canHandle(handlerInput) {
    return Alexa.getRequestType(handlerInput.requestEnvelope) === 'IntentRequest'
      && Alexa.getIntentName(handlerInput.requestEnvelope) === 'LockVehicleIntent';
  },
  async handle(handlerInput) {
    return handleVehicleCommand(handlerInput, viperApi.lockVehicle.bind(viperApi), 'Lock');
  }
};

// Unlock Intent Handler
const UnlockIntentHandler = {
  canHandle(handlerInput) {
    return Alexa.getRequestType(handlerInput.requestEnvelope) === 'IntentRequest'
      && Alexa.getIntentName(handlerInput.requestEnvelope) === 'UnlockVehicleIntent';
  },
  async handle(handlerInput) {
    return handleVehicleCommand(handlerInput, viperApi.unlockVehicle.bind(viperApi), 'Unlock');
  }
};

// Start Engine Intent Handler
const StartEngineIntentHandler = {
  canHandle(handlerInput) {
    return Alexa.getRequestType(handlerInput.requestEnvelope) === 'IntentRequest'
      && Alexa.getIntentName(handlerInput.requestEnvelope) === 'StartEngineIntent';
  },
  async handle(handlerInput) {
    return handleVehicleCommand(handlerInput, viperApi.startVehicle.bind(viperApi), 'Start');
  }
};

// Stop Engine Intent Handler
const StopEngineIntentHandler = {
  canHandle(handlerInput) {
    return Alexa.getRequestType(handlerInput.requestEnvelope) === 'IntentRequest'
      && Alexa.getIntentName(handlerInput.requestEnvelope) === 'StopEngineIntent';
  },
  async handle(handlerInput) {
    return handleVehicleCommand(handlerInput, viperApi.stopVehicle.bind(viperApi), 'Stop');
  }
};

// Open Trunk Intent Handler
const OpenTrunkIntentHandler = {
  canHandle(handlerInput) {
    return Alexa.getRequestType(handlerInput.requestEnvelope) === 'IntentRequest'
      && Alexa.getIntentName(handlerInput.requestEnvelope) === 'OpenTrunkIntent';
  },
  async handle(handlerInput) {
    return handleVehicleCommand(handlerInput, viperApi.openTrunk.bind(viperApi), 'Open');
  }
};

// Session Ended Request Handler (REQUIRED to fix the handler error)
const SessionEndedRequestHandler = {
  canHandle(handlerInput) {
    return Alexa.getRequestType(handlerInput.requestEnvelope) === 'SessionEndedRequest';
  },
  handle(handlerInput) {
    console.log(`Session ended with reason: ${handlerInput.requestEnvelope.request.reason}`);
    return handlerInput.responseBuilder.getResponse();
  }
};

// Help Intent Handler
const HelpIntentHandler = {
  canHandle(handlerInput) {
    return Alexa.getRequestType(handlerInput.requestEnvelope) === 'IntentRequest'
      && Alexa.getIntentName(handlerInput.requestEnvelope) === 'AMAZON.HelpIntent';
  },
  handle(handlerInput) {
    const speechText = 'You can say lock my car, unlock my car, start my car, stop my car, or open trunk.';
    return handlerInput.responseBuilder
      .speak(speechText)
      .reprompt(speechText)
      .getResponse();
  }
};

// Cancel and Stop Intent Handler
const CancelAndStopIntentHandler = {
  canHandle(handlerInput) {
    return Alexa.getRequestType(handlerInput.requestEnvelope) === 'IntentRequest'
      && (Alexa.getIntentName(handlerInput.requestEnvelope) === 'AMAZON.CancelIntent'
        || Alexa.getIntentName(handlerInput.requestEnvelope) === 'AMAZON.StopIntent');
  },
  handle(handlerInput) {
    const speechText = 'Goodbye!';
    return handlerInput.responseBuilder
      .speak(speechText)
      .getResponse();
  }
};

// Debug Intent for testing the API directly
const DebugApiIntentHandler = {
  canHandle(handlerInput) {
    return Alexa.getRequestType(handlerInput.requestEnvelope) === 'IntentRequest'
      && Alexa.getIntentName(handlerInput.requestEnvelope) === 'DebugApiIntent';
  },
  async handle(handlerInput) {
    console.log("Debug API intent triggered");
    
    try {
      // Get user credentials from Cognito
      const userInfo = await getUserInfoFromCognito(DEFAULT_EMAIL);
      const credentials = getViperCredentials(userInfo);
      
      // Output detailed information
      console.log("=== DEBUG INFO ===");
      console.log(`Using credentials: ${credentials.username}`);
      console.log(`Viper API Base URL: ${viperApi.BASE_URL}`);
      console.log(`Viper API Login URL: ${viperApi.LOGIN_URL}`);
      
      // Test login
      console.log("Attempting login with original API endpoint and method");
      const loginResult = await viperApi.login(credentials.username, credentials.password);
      console.log("Login successful!");
      console.log(`Got token: ${loginResult.token.substring(0, 20)}...`);
      
      // Test getting vehicles
      console.log("Getting vehicles...");
      const vehicles = await viperApi.getVehicles(loginResult.token);
      console.log(`Found ${vehicles.length} vehicles`);
      
      // Test available commands
      if (vehicles && vehicles.length > 0) {
        const vehicle = vehicles[0];
        console.log("Checking available commands for vehicle:", vehicle.name);
        console.log("Lock command:", viperApi.COMMAND_LOCK);
        console.log("Unlock command:", viperApi.COMMAND_UNLOCK);
        console.log("Start command:", viperApi.COMMAND_START);
        console.log("Stop command:", viperApi.COMMAND_STOP);
        console.log("Trunk command:", viperApi.COMMAND_TRUNK);
        
        return handlerInput.responseBuilder
          .speak(`Debug successful! I was able to log in to the Viper API and found ${vehicles.length} vehicles. The first one is ${vehicle.name}. Available commands are: lock, unlock, start, stop, and open trunk.`)
          .getResponse();
      } else {
        return handlerInput.responseBuilder
          .speak("Debug partially successful. I was able to log in to the Viper API but didn't find any vehicles.")
          .getResponse();
      }
    } catch (error) {
      console.error("Debug error:", error);
      return handlerInput.responseBuilder
        .speak(`Debug failed: ${formatErrorForUser(error)}`)
        .getResponse();
    }
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
    
    // Format the error for the user
    const userMessage = formatErrorForUser(error);
    
    return handlerInput.responseBuilder
      .speak(userMessage)
      .reprompt("Please try again or say 'help' for available commands.")
      .getResponse();
  }
};

// Request Log Interceptor
const LogRequestInterceptor = {
  process(handlerInput) {
    console.log("Request received:", JSON.stringify({
      requestType: Alexa.getRequestType(handlerInput.requestEnvelope),
      intentName: handlerInput.requestEnvelope.request.intent 
        ? Alexa.getIntentName(handlerInput.requestEnvelope) 
        : null,
      userId: Alexa.getUserId(handlerInput.requestEnvelope)
    }));
  }
};

// Response Log Interceptor
const LogResponseInterceptor = {
  process(handlerInput, response) {
    console.log("Response sent:", JSON.stringify({
      speech: response.outputSpeech ? response.outputSpeech.ssml : null,
      reprompt: response.reprompt ? response.reprompt.outputSpeech.ssml : null,
      shouldEndSession: response.shouldEndSession
    }));
    return response;
  }
};

// LAMBDA HANDLER
exports.handler = Alexa.SkillBuilders.custom()
  .addRequestHandlers(
    LaunchRequestHandler,
    LockIntentHandler,
    UnlockIntentHandler,
    StartEngineIntentHandler,
    StopEngineIntentHandler,
    OpenTrunkIntentHandler,
    DebugApiIntentHandler,
    HelpIntentHandler,
    CancelAndStopIntentHandler,
    SessionEndedRequestHandler
  )
  .addRequestInterceptors(LogRequestInterceptor)
  .addResponseInterceptors(LogResponseInterceptor)
  .addErrorHandlers(ErrorHandler)
  .lambda();
'@

# Create package.json
$packageJson = @'
{
  "name": "alexa-viper-skill",
  "version": "1.0.0",
  "description": "Alexa skill for controlling Viper",
  "main": "index.js",
  "dependencies": {
    "ask-sdk-core": "^2.12.1",
    "aws-sdk": "^2.1349.0",
    "axios": "^0.21.4"
  }
}
'@

# Write files to the temp directory 
Set-Content -Path "$tempDir/viperApi.js" -Value $viperApiJs
Set-Content -Path "$tempDir/index.js" -Value $indexJs
Set-Content -Path "$tempDir/package.json" -Value $packageJson
Set-Content -Path "$tempDir/model.json" -Value $modelJson

# Create node_modules directory and install dependencies
Write-Host "Creating package with dependencies..." -ForegroundColor Yellow
$npmCreateCmd = "npm init -y"
$npmInstallCmd = "npm install --production ask-sdk-core aws-sdk axios"

Set-Location -Path $tempDir
Invoke-Expression $npmCreateCmd | Out-Null
Invoke-Expression $npmInstallCmd | Out-Null

# Create a zip file for deployment
Write-Host "Creating deployment package..." -ForegroundColor Yellow
$zipPath = "fix-missing-intents.zip"
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

# Update the Alexa skill model
Write-Host "Updating Alexa skill model with all intents..." -ForegroundColor Yellow

# Get skill id
$skillId = ""
try {
    $skillsCmd = "aws ask list-skills --skill-type-filter CUSTOM --region $REGION"
    $skillsJson = Invoke-Expression $skillsCmd
    $skills = $skillsJson | ConvertFrom-Json
    
    foreach ($skill in $skills.skills) {
        if ($skill.nameByLocale."en-US" -like "*Viper*") {
            $skillId = $skill.skillId
            Write-Host "Found skill id: $skillId" -ForegroundColor Green
            break
        }
    }
} catch {
    Write-Host "Error getting skill ID: $_" -ForegroundColor Yellow
    Write-Host "Skill model will need to be updated manually" -ForegroundColor Yellow
}

if ($skillId) {
    try {
        # Create temp file for model
        $modelFile = "model.json"
        Set-Content -Path $modelFile -Value $modelJson
        
        # Update skill model
        $updateModelCmd = "aws ask update-model --skill-id $skillId --locale en-US --file file://$modelFile --region $REGION"
        Invoke-Expression $updateModelCmd | Out-Null
        Write-Host "Successfully updated skill model" -ForegroundColor Green
        
        # Clean up
        Remove-Item -Path $modelFile -Force
    } catch {
        Write-Host "Error updating skill model: $_" -ForegroundColor Yellow
        Write-Host "Skill model will need to be updated manually" -ForegroundColor Yellow
    }
}

# Clean up
Remove-Item -Path $tempDir -Recurse -Force
Remove-Item -Path $zipPath -Force
Write-Host "Temporary files cleaned up" -ForegroundColor Yellow

Write-Host "`nFixed missing intents and improved error handling!" -ForegroundColor Green
Write-Host "This version includes:" -ForegroundColor Cyan
Write-Host "1. All vehicle control intents: Lock, Unlock, Start, Stop, and Open Trunk" -ForegroundColor Cyan
Write-Host "2. Better error handling with specific, user-friendly error messages" -ForegroundColor Cyan
Write-Host "3. Consolidated code with a generic vehicle command handler" -ForegroundColor Cyan
Write-Host "4. Additional logging for easier troubleshooting" -ForegroundColor Cyan
Write-Host "5. Updated skill model with all the available voice commands" -ForegroundColor Cyan

Write-Host "`nWait about 1-2 minutes for the changes to take effect" -ForegroundColor Yellow
Write-Host "Then you can try these commands:" -ForegroundColor Yellow
Write-Host "- 'Alexa, ask X Viper to lock my car'" -ForegroundColor Yellow
Write-Host "- 'Alexa, ask X Viper to unlock my car'" -ForegroundColor Yellow
Write-Host "- 'Alexa, ask X Viper to start my car'" -ForegroundColor Yellow
Write-Host "- 'Alexa, ask X Viper to stop my car'" -ForegroundColor Yellow
Write-Host "- 'Alexa, ask X Viper to open trunk'" -ForegroundColor Yellow