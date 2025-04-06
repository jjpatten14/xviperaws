# Quick fix for Lambda handler error
$env:AWS_DEFAULT_OUTPUT = 'json'
$REGION = 'us-east-1'
$LAMBDA_FUNCTION_NAME = 'xviper-alexa-skill'

Write-Host "Creating quick-fix Lambda to resolve handler error..." -ForegroundColor Cyan

# Create a temporary directory
$tempDir = "temp_lambda_code"
if (Test-Path $tempDir) {
    Remove-Item -Path $tempDir -Recurse -Force
}
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

# Create the fixed Lambda function with proper handler
$indexJs = @'
const Alexa = require('ask-sdk-core');
const AWS = require('aws-sdk');

// Initialize AWS services
AWS.config.region = process.env.AWS_REGION || 'us-east-1';
const cognito = new AWS.CognitoIdentityServiceProvider();
const dynamoDB = new AWS.DynamoDB.DocumentClient();

// Constants
const USER_POOL_ID = process.env.COGNITO_USER_POOL_ID;
const USER_MAPPING_TABLE = process.env.USER_MAPPING_TABLE || "XviperUserMappings";
const DEFAULT_EMAIL = process.env.DEFAULT_EMAIL || "jjpatten14@gmail.com";

// Detailed logging
function log(level, message, data = null) {
  const timestamp = new Date().toISOString();
  console.log(`[${timestamp}] [${level.toUpperCase()}] ${message}`);
  if (data) {
    try {
      console.log(JSON.stringify(data, null, 2));
    } catch (e) {
      console.log('Could not stringify data:', e.message);
    }
  }
}

// Viper API module with basic logging
const viperApi = {
  login: async function(username, password) {
    log('info', `Attempting login for user: ${username}`);
    
    try {
      // Try different API endpoints
      const endpoints = [
        'https://service-vla.directed.com/v1/oauth/token',
        'https://service.directed.com/v1/oauth/token',
        'https://auth.directed.com/oauth/token'
      ];
      
      // Try with different payloads
      for (const endpoint of endpoints) {
        log('info', `Trying endpoint: ${endpoint}`);
        
        // Try JSON payload
        try {
          const payload = {
            username,
            password,
            grant_type: 'password'
          };
          
          log('debug', 'Using JSON payload', payload);
          
          const response = await fetch(endpoint, {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'User-Agent': 'ViperAlexaSkill/1.0'
            },
            body: JSON.stringify(payload)
          });
          
          if (response.ok) {
            const data = await response.json();
            log('info', 'Login successful!', data);
            
            if (data.access_token) {
              return {
                token: data.access_token,
                endpoint: endpoint
              };
            }
          } else {
            log('warn', `JSON payload failed with status: ${response.status}`);
          }
        } catch (error) {
          log('error', `Error with JSON payload: ${error.message}`);
        }
        
        // Try URL-encoded payload
        try {
          const params = new URLSearchParams();
          params.append('username', username);
          params.append('password', password);
          params.append('grant_type', 'password');
          
          log('debug', 'Using URL-encoded payload');
          
          const response = await fetch(endpoint, {
            method: 'POST',
            headers: {
              'Content-Type': 'application/x-www-form-urlencoded',
              'Accept': 'application/json',
              'User-Agent': 'ViperAlexaSkill/1.0'
            },
            body: params.toString()
          });
          
          if (response.ok) {
            const data = await response.json();
            log('info', 'Login successful with URL-encoded payload!', data);
            
            if (data.access_token) {
              return {
                token: data.access_token,
                endpoint: endpoint.replace('/oauth/token', '')
              };
            }
          } else {
            log('warn', `URL-encoded payload failed with status: ${response.status}`);
          }
        } catch (error) {
          log('error', `Error with URL-encoded payload: ${error.message}`);
        }
        
        // Try with client_id
        try {
          const payload = {
            username,
            password,
            grant_type: 'password',
            client_id: 'viper'
          };
          
          log('debug', 'Using payload with client_id', payload);
          
          const response = await fetch(endpoint, {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'User-Agent': 'ViperAlexaSkill/1.0'
            },
            body: JSON.stringify(payload)
          });
          
          if (response.ok) {
            const data = await response.json();
            log('info', 'Login successful with client_id!', data);
            
            if (data.access_token) {
              return {
                token: data.access_token,
                endpoint: endpoint.replace('/oauth/token', '')
              };
            }
          } else {
            log('warn', `client_id payload failed with status: ${response.status}`);
          }
        } catch (error) {
          log('error', `Error with client_id payload: ${error.message}`);
        }
      }
      
      throw new Error('All login attempts failed');
    } catch (error) {
      log('error', 'Login failed after trying all options', error);
      throw error;
    }
  },
  
  getVehicles: async function(token, baseEndpoint) {
    log('info', 'Getting vehicles');
    
    try {
      const response = await fetch(`${baseEndpoint}/vehicles`, {
        headers: {
          'Authorization': `Bearer ${token}`,
          'Accept': 'application/json'
        }
      });
      
      if (response.ok) {
        const data = await response.json();
        log('info', 'Got vehicles', data);
        return data;
      } else {
        log('error', `Failed to get vehicles: ${response.status}`);
        throw new Error(`Failed to get vehicles: ${response.status}`);
      }
    } catch (error) {
      log('error', 'Error getting vehicles', error);
      throw error;
    }
  },
  
  lockVehicle: async function(token, baseEndpoint, deviceId) {
    log('info', `Locking vehicle: ${deviceId}`);
    
    try {
      const response = await fetch(`${baseEndpoint}/vehicles/${deviceId}/lock`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Accept': 'application/json'
        }
      });
      
      if (response.ok) {
        const data = await response.json();
        log('info', 'Lock vehicle successful', data);
        return data;
      } else {
        log('error', `Failed to lock vehicle: ${response.status}`);
        throw new Error(`Failed to lock vehicle: ${response.status}`);
      }
    } catch (error) {
      log('error', 'Error locking vehicle', error);
      throw error;
    }
  },
  
  unlockVehicle: async function(token, baseEndpoint, deviceId) {
    log('info', `Unlocking vehicle: ${deviceId}`);
    
    try {
      const response = await fetch(`${baseEndpoint}/vehicles/${deviceId}/unlock`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Accept': 'application/json'
        }
      });
      
      if (response.ok) {
        const data = await response.json();
        log('info', 'Unlock vehicle successful', data);
        return data;
      } else {
        log('error', `Failed to unlock vehicle: ${response.status}`);
        throw new Error(`Failed to unlock vehicle: ${response.status}`);
      }
    } catch (error) {
      log('error', 'Error unlocking vehicle', error);
      throw error;
    }
  }
};

// Launch Request Handler
const LaunchRequestHandler = {
  canHandle(handlerInput) {
    return Alexa.getRequestType(handlerInput.requestEnvelope) === 'LaunchRequest';
  },
  handle(handlerInput) {
    const speechText = 'Welcome to X Viper Control. You can say lock my car or unlock my car.';
    return handlerInput.responseBuilder
      .speak(speechText)
      .reprompt(speechText)
      .getResponse();
  }
};

// Lock Intent Handler
const LockIntentHandler = {
  canHandle(handlerInput) {
    return Alexa.getRequestType(handlerInput.requestEnvelope) === 'IntentRequest'
      && Alexa.getIntentName(handlerInput.requestEnvelope) === 'LockVehicleIntent';
  },
  async handle(handlerInput) {
    log('info', 'Lock intent triggered');
    
    try {
      // Get credentials and token
      log('info', `Using default email: ${DEFAULT_EMAIL}`);
      
      // Get user info from Cognito
      const userInfo = await getUserFromCognito(DEFAULT_EMAIL);
      
      if (!userInfo["custom:viper_username"] || !userInfo["custom:viper_password"]) {
        log('error', 'Viper credentials not found');
        return handlerInput.responseBuilder
          .speak("I couldn't find your Viper credentials in your profile. Please run the add-viper-credentials script.")
          .getResponse();
      }
      
      const username = userInfo["custom:viper_username"];
      const password = userInfo["custom:viper_password"];
      log('info', `Got credentials for: ${username}`);
      
      // Login to Viper API
      const { token, endpoint } = await viperApi.login(username, password);
      log('info', 'Successfully logged in', { endpoint });
      
      // Get vehicles
      const vehicles = await viperApi.getVehicles(token, endpoint);
      
      if (!vehicles || vehicles.length === 0) {
        log('warn', 'No vehicles found');
        return handlerInput.responseBuilder
          .speak("I couldn't find any vehicles associated with your account.")
          .getResponse();
      }
      
      // Use first vehicle
      const vehicle = vehicles[0];
      log('info', 'Using vehicle', { deviceId: vehicle.deviceId, name: vehicle.name });
      
      // Lock the vehicle
      await viperApi.lockVehicle(token, endpoint, vehicle.deviceId);
      
      return handlerInput.responseBuilder
        .speak(`I've locked your ${vehicle.name || 'vehicle'} for you.`)
        .getResponse();
    } catch (error) {
      log('error', 'Error in lock intent handler', { message: error.message, stack: error.stack });
      return handlerInput.responseBuilder
        .speak(`I'm sorry, I couldn't lock your vehicle. ${error.message}`)
        .getResponse();
    }
  }
};

// Unlock Intent Handler  
const UnlockIntentHandler = {
  canHandle(handlerInput) {
    return Alexa.getRequestType(handlerInput.requestEnvelope) === 'IntentRequest'
      && Alexa.getIntentName(handlerInput.requestEnvelope) === 'UnlockVehicleIntent';
  },
  async handle(handlerInput) {
    log('info', 'Unlock intent triggered');
    
    try {
      // Get credentials and token
      log('info', `Using default email: ${DEFAULT_EMAIL}`);
      
      // Get user info from Cognito
      const userInfo = await getUserFromCognito(DEFAULT_EMAIL);
      
      if (!userInfo["custom:viper_username"] || !userInfo["custom:viper_password"]) {
        log('error', 'Viper credentials not found');
        return handlerInput.responseBuilder
          .speak("I couldn't find your Viper credentials in your profile. Please run the add-viper-credentials script.")
          .getResponse();
      }
      
      const username = userInfo["custom:viper_username"];
      const password = userInfo["custom:viper_password"];
      log('info', `Got credentials for: ${username}`);
      
      // Login to Viper API
      const { token, endpoint } = await viperApi.login(username, password);
      log('info', 'Successfully logged in', { endpoint });
      
      // Get vehicles
      const vehicles = await viperApi.getVehicles(token, endpoint);
      
      if (!vehicles || vehicles.length === 0) {
        log('warn', 'No vehicles found');
        return handlerInput.responseBuilder
          .speak("I couldn't find any vehicles associated with your account.")
          .getResponse();
      }
      
      // Use first vehicle
      const vehicle = vehicles[0];
      log('info', 'Using vehicle', { deviceId: vehicle.deviceId, name: vehicle.name });
      
      // Unlock the vehicle
      await viperApi.unlockVehicle(token, endpoint, vehicle.deviceId);
      
      return handlerInput.responseBuilder
        .speak(`I've unlocked your ${vehicle.name || 'vehicle'} for you.`)
        .getResponse();
    } catch (error) {
      log('error', 'Error in unlock intent handler', { message: error.message, stack: error.stack });
      return handlerInput.responseBuilder
        .speak(`I'm sorry, I couldn't unlock your vehicle. ${error.message}`)
        .getResponse();
    }
  }
};

// Helper function to get user from Cognito
async function getUserFromCognito(email) {
  log('info', `Getting user info from Cognito for: ${email}`);
  
  try {
    const params = {
      UserPoolId: USER_POOL_ID,
      Username: email
    };
    
    const userData = await cognito.adminGetUser(params).promise();
    log('info', 'Got user data from Cognito');
    
    // Convert attributes to object
    const userInfo = {};
    if (userData.UserAttributes) {
      userData.UserAttributes.forEach(attr => {
        userInfo[attr.Name] = attr.Value;
      });
      log('info', 'User attributes found', Object.keys(userInfo));
    }
    
    return userInfo;
  } catch (error) {
    log('error', 'Error getting user from Cognito', error);
    throw new Error(`Failed to get user info: ${error.message}`);
  }
}

// Help Intent Handler
const HelpIntentHandler = {
  canHandle(handlerInput) {
    return Alexa.getRequestType(handlerInput.requestEnvelope) === 'IntentRequest'
      && Alexa.getIntentName(handlerInput.requestEnvelope) === 'AMAZON.HelpIntent';
  },
  handle(handlerInput) {
    const speechText = 'You can say lock my car or unlock my car.';
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

// Session Ended Request Handler
const SessionEndedRequestHandler = {
  canHandle(handlerInput) {
    return Alexa.getRequestType(handlerInput.requestEnvelope) === 'SessionEndedRequest';
  },
  handle(handlerInput) {
    log('info', 'Session ended', handlerInput.requestEnvelope.request.reason);
    return handlerInput.responseBuilder.getResponse();
  }
};

// Error Handler
const ErrorHandler = {
  canHandle() {
    return true;
  },
  handle(handlerInput, error) {
    log('error', `Error handled: ${error.message}`);
    log('error', `Error stack: ${error.stack}`);
    
    const speechText = 'Sorry, there was a problem. Please try again.';
    return handlerInput.responseBuilder
      .speak(speechText)
      .reprompt(speechText)
      .getResponse();
  }
};

// Log Request Interceptor
const LogRequestInterceptor = {
  process(handlerInput) {
    log('info', 'Request received', {
      type: Alexa.getRequestType(handlerInput.requestEnvelope),
      intent: handlerInput.requestEnvelope.request.intent
        ? Alexa.getIntentName(handlerInput.requestEnvelope)
        : null
    });
    return;
  }
};

// Exports handler
exports.handler = Alexa.SkillBuilders.custom()
  .addRequestHandlers(
    LaunchRequestHandler,
    LockIntentHandler,
    UnlockIntentHandler,
    HelpIntentHandler,
    CancelAndStopIntentHandler,
    SessionEndedRequestHandler
  )
  .addErrorHandlers(ErrorHandler)
  .addRequestInterceptors(LogRequestInterceptor)
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
    "aws-sdk": "^2.0.0"
  }
}
'@

# Write files to the temp directory
Set-Content -Path "$tempDir/index.js" -Value $indexJs
Set-Content -Path "$tempDir/package.json" -Value $packageJson

# Create node_modules directory and install dependencies
Write-Host "Creating package with dependencies..." -ForegroundColor Yellow
$npmCreateCmd = "npm init -y"
$npmInstallCmd = "npm install --production ask-sdk-core aws-sdk"

Set-Location -Path $tempDir
Invoke-Expression $npmCreateCmd | Out-Null
Invoke-Expression $npmInstallCmd | Out-Null

# Create a zip file for deployment
Write-Host "Creating deployment package..." -ForegroundColor Yellow
$zipPath = "quick-fix-lambda.zip"
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

$updateConfigCmd = "aws lambda update-function-configuration --function-name $LAMBDA_FUNCTION_NAME --environment 'Variables={COGNITO_USER_POOL_ID=$USER_POOL_ID,USER_MAPPING_TABLE=XviperUserMappings,DEFAULT_EMAIL=jjpatten14@gmail.com}' --timeout 60 --memory-size 512 --region $REGION"

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

Write-Host "`nQuick-fix Lambda deployed!" -ForegroundColor Green
Write-Host "This version includes:" -ForegroundColor Cyan
Write-Host "1. Fixed request handler structure to work properly with Alexa" -ForegroundColor Cyan
Write-Host "2. Built-in fetch-based API client with no dependencies" -ForegroundColor Cyan
Write-Host "3. Multiple authentication approaches that try various endpoints and payload formats" -ForegroundColor Cyan
Write-Host "4. Comprehensive logging without external dependencies" -ForegroundColor Cyan

Write-Host "`nWait about 1-2 minutes for the changes to take effect" -ForegroundColor Yellow
Write-Host "Then try 'Alexa, ask X Viper to lock my car'" -ForegroundColor Yellow