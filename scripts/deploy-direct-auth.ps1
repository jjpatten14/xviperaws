# Automated script to deploy and configure direct authentication approach
# This script handles everything from creating files to deploying to AWS

# Configuration - Update these values as needed
$REGION = 'us-east-1'
$LAMBDA_FUNCTION_NAME = 'xviper-alexa-skill'
$S3_BUCKET = 'xviper-us-east1-965239903867'
$DEFAULT_USERNAME = ${env:VIPER_USERNAME}
$DEFAULT_PASSWORD = ${env:VIPER_PASSWORD}

Write-Host "Automated Direct Authentication Deployment" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "This script will:" -ForegroundColor Cyan
Write-Host "1. Create a simplified Lambda function with direct authentication" -ForegroundColor Cyan
Write-Host "2. Package it with dependencies" -ForegroundColor Cyan
Write-Host "3. Deploy it to AWS" -ForegroundColor Cyan
Write-Host "4. Update environment variables" -ForegroundColor Cyan
Write-Host ""

# Create working directory
$workDir = "lambda-direct"
if (Test-Path $workDir) {
    Write-Host "Removing existing $workDir directory..." -ForegroundColor Yellow
    Remove-Item -Path $workDir -Recurse -Force
}

Write-Host "Creating $workDir directory..." -ForegroundColor Cyan
New-Item -ItemType Directory -Path $workDir | Out-Null

# Create index.js with simplified Lambda function
Write-Host "Creating simplified Lambda function..." -ForegroundColor Cyan
$indexJs = @"
/**
 * Simplified X Viper Alexa Skill Lambda Function with Direct Authentication
 * 
 * This function authenticates directly with the Viper API using environment
 * variables, without requiring OAuth/account linking.
 */
const axios = require('axios');

// API Configuration 
const API_CONFIG = {
    baseUrl: 'https://www.vcp.cloud/v1',
    loginUrl: 'https://www.vcp.cloud/v1/auth/login',
    devicesUrl: 'https://www.vcp.cloud/v1/devices/search/null?limit=100&deviceFilter=Installed&subAccounts=false',
    commandUrl: 'https://www.vcp.cloud/v1/devices/command'
};

// Command constants
const COMMANDS = {
    LOCK: 'arm',
    UNLOCK: 'disarm',
    START: 'remote',
    STOP: 'remote',
    TRUNK: 'trunk',
    PANIC: 'panic'
};

// Default credentials from environment variables
const DEFAULT_USERNAME = process.env.DEFAULT_USERNAME;
const DEFAULT_PASSWORD = process.env.DEFAULT_PASSWORD;

// Session cache for API tokens
const tokenCache = {
    token: null,
    expires: 0
};

// User vehicle cache (simple in-memory cache for demo)
const vehicleCache = {};

// Alexa Skill Event Handler
exports.handler = async (event) => {
    console.log('Event received:', JSON.stringify(event, null, 2));
    
    try {
        // Extract request type and intent
        const requestType = event.request.type;
        const alexaUserId = event.session?.user?.userId || 'unknown';
        
        // Log the request
        console.log(`Request type: \${requestType}, User ID: \${alexaUserId}`);
        
        // Route the request based on type
        if (requestType === 'LaunchRequest') {
            return handleLaunch(alexaUserId);
        } else if (requestType === 'IntentRequest') {
            const intentName = event.request.intent.name;
            return handleIntent(intentName, alexaUserId);
        } else if (requestType === 'SessionEndedRequest') {
            return createResponse('Goodbye!', true);
        } else {
            return createResponse("I don't understand that request. Please try again.", false);
        }
    } catch (error) {
        console.error('Error handling event:', error);
        return createResponse('Sorry, there was a problem processing your request. ' + error.message, true);
    }
};

// Handle launch request
async function handleLaunch(userId) {
    try {
        console.log('Handling launch request');
        
        // Try to get the user's default vehicle
        const vehicle = await getDefaultVehicle(userId);
        
        if (vehicle) {
            return createResponse(
                `Welcome to X Viper control. Your \${vehicle.name || 'vehicle'} is ready. You can ask me to lock, unlock, start or stop your vehicle.`,
                false,
                'What would you like me to do?'
            );
        } else {
            return createResponse(
                'Welcome to X Viper control. Please make sure your vehicle is set up properly. You can ask me to lock, unlock, start or stop your vehicle.',
                false,
                'What would you like me to do?'
            );
        }
    } catch (error) {
        console.error('Error handling launch:', error);
        return createResponse('Sorry, I had trouble connecting to your vehicle system. Please try again later.', true);
    }
}

// Handle intent request
async function handleIntent(intentName, userId) {
    console.log(`Handling intent: \${intentName}`);
    
    try {
        switch (intentName) {
            case 'LockVehicleIntent':
                return await handleLockVehicle(userId);
                
            case 'UnlockVehicleIntent':
                return await handleUnlockVehicle(userId);
                
            case 'StartEngineIntent':
                return await handleStartEngine(userId);
                
            case 'StopEngineIntent':
                return await handleStopEngine(userId);
                
            case 'OpenTrunkIntent':
                return await handleOpenTrunk(userId);
                
            case 'AMAZON.HelpIntent':
                return createResponse('You can ask me to lock or unlock your vehicle, start or stop the engine, or open the trunk. For example, say "lock my car" or "start my car engine".', false, 'What would you like me to do?');
                
            case 'AMAZON.CancelIntent':
            case 'AMAZON.StopIntent':
                return createResponse('Goodbye!', true);
                
            default:
                return createResponse("I'm not sure how to help with that. You can ask me to lock, unlock, start or stop your vehicle.", false, 'What would you like me to do?');
        }
    } catch (error) {
        console.error(`Error handling intent \${intentName}:`, error);
        return createResponse(`Sorry, I couldn't process that request. \${error.message}`, true);
    }
}

// Lock vehicle handler
async function handleLockVehicle(userId) {
    try {
        console.log('Processing lock vehicle request');
        
        // Get API token
        const token = await getApiToken();
        
        // Get default vehicle
        const vehicle = await getDefaultVehicle(userId);
        if (!vehicle) {
            return createResponse("I couldn't find your vehicle. Please make sure your vehicle is set up correctly.", true);
        }
        
        // Send lock command
        await sendCommand(token, vehicle.id, COMMANDS.LOCK);
        
        return createResponse(`I've locked your \${vehicle.name || 'vehicle'} for you.`, true);
    } catch (error) {
        console.error('Error locking vehicle:', error);
        return createResponse(`I'm sorry, I couldn't lock your vehicle. \${error.message}`, true);
    }
}

// Unlock vehicle handler
async function handleUnlockVehicle(userId) {
    try {
        console.log('Processing unlock vehicle request');
        
        // Get API token
        const token = await getApiToken();
        
        // Get default vehicle
        const vehicle = await getDefaultVehicle(userId);
        if (!vehicle) {
            return createResponse("I couldn't find your vehicle. Please make sure your vehicle is set up correctly.", true);
        }
        
        // Send unlock command
        await sendCommand(token, vehicle.id, COMMANDS.UNLOCK);
        
        return createResponse(`I've unlocked your \${vehicle.name || 'vehicle'} for you.`, true);
    } catch (error) {
        console.error('Error unlocking vehicle:', error);
        return createResponse(`I'm sorry, I couldn't unlock your vehicle. \${error.message}`, true);
    }
}

// Start engine handler
async function handleStartEngine(userId) {
    try {
        console.log('Processing start engine request');
        
        // Get API token
        const token = await getApiToken();
        
        // Get default vehicle
        const vehicle = await getDefaultVehicle(userId);
        if (!vehicle) {
            return createResponse("I couldn't find your vehicle. Please make sure your vehicle is set up correctly.", true);
        }
        
        // Send start command
        await sendCommand(token, vehicle.id, COMMANDS.START);
        
        return createResponse(`I've started your \${vehicle.name || 'vehicle'}'s engine for you.`, true);
    } catch (error) {
        console.error('Error starting engine:', error);
        return createResponse(`I'm sorry, I couldn't start your vehicle's engine. \${error.message}`, true);
    }
}

// Stop engine handler
async function handleStopEngine(userId) {
    try {
        console.log('Processing stop engine request');
        
        // Get API token
        const token = await getApiToken();
        
        // Get default vehicle
        const vehicle = await getDefaultVehicle(userId);
        if (!vehicle) {
            return createResponse("I couldn't find your vehicle. Please make sure your vehicle is set up correctly.", true);
        }
        
        // Send stop command
        await sendCommand(token, vehicle.id, COMMANDS.STOP);
        
        return createResponse(`I've stopped your \${vehicle.name || 'vehicle'}'s engine for you.`, true);
    } catch (error) {
        console.error('Error stopping engine:', error);
        return createResponse(`I'm sorry, I couldn't stop your vehicle's engine. \${error.message}`, true);
    }
}

// Open trunk handler
async function handleOpenTrunk(userId) {
    try {
        console.log('Processing open trunk request');
        
        // Get API token
        const token = await getApiToken();
        
        // Get default vehicle
        const vehicle = await getDefaultVehicle(userId);
        if (!vehicle) {
            return createResponse("I couldn't find your vehicle. Please make sure your vehicle is set up correctly.", true);
        }
        
        // Send trunk command
        await sendCommand(token, vehicle.id, COMMANDS.TRUNK);
        
        return createResponse(`I've opened your \${vehicle.name || 'vehicle'}'s trunk for you.`, true);
    } catch (error) {
        console.error('Error opening trunk:', error);
        return createResponse(`I'm sorry, I couldn't open your vehicle's trunk. \${error.message}`, true);
    }
}

// Helper functions
function createResponse(speechText, endSession, repromptText = null) {
    const response = {
        version: '1.0',
        response: {
            outputSpeech: {
                type: 'PlainText',
                text: speechText
            },
            shouldEndSession: endSession
        }
    };
    
    if (repromptText && !endSession) {
        response.response.reprompt = {
            outputSpeech: {
                type: 'PlainText',
                text: repromptText
            }
        };
    }
    
    return response;
}

// API functions
async function getApiToken() {
    try {
        // Check if we have a valid cached token
        if (tokenCache.token && tokenCache.expires > Date.now()) {
            console.log('Using cached API token');
            return tokenCache.token;
        }
        
        // Log the credentials being used (excluding password)
        console.log(`Authenticating with username: \${DEFAULT_USERNAME}`);
        
        if (!DEFAULT_USERNAME || !DEFAULT_PASSWORD) {
            throw new Error('Missing username or password in environment variables');
        }
        
        // Prepare the login data
        const formData = new URLSearchParams();
        formData.append('username', DEFAULT_USERNAME);
        formData.append('password', DEFAULT_PASSWORD);
        
        // Make the login request
        console.log('Sending login request to Viper API');
        const response = await axios.post(API_CONFIG.loginUrl, formData, {
            headers: {
                'Content-Type': 'application/x-www-form-urlencoded'
            }
        });
        
        // Check if we got a valid response
        if (response.data && response.data.results && response.data.results.authToken) {
            const authToken = response.data.results.authToken.accessToken;
            const user = response.data.results.user;
            
            console.log(`Login successful for \${user.firstName} \${user.lastName}`);
            
            // Cache the token
            tokenCache.token = authToken;
            tokenCache.expires = Date.now() + (12 * 60 * 60 * 1000); // 12 hours
            
            return authToken;
        } else {
            throw new Error('Invalid login response format');
        }
    } catch (error) {
        console.error('Login error:', error.response ? error.response.data : error.message);
        throw new Error('Authentication failed');
    }
}

async function getVehicles(token) {
    try {
        console.log('Fetching vehicles');
        
        const response = await axios.get(API_CONFIG.devicesUrl, {
            headers: {
                'Authorization': `Bearer \${token}`
            }
        });
        
        if (response.data && response.data.results && response.data.results.devices) {
            const devices = response.data.results.devices;
            console.log(`Found \${devices.length} vehicles`);
            
            // Map to simpler vehicle objects
            return devices.map(device => ({
                id: device.id,
                name: device.name || 'My Vehicle',
                model: device.vehicleModel || 'Unknown Model',
                year: device.vehicleYear || '',
                make: device.vehicleMake || ''
            }));
        } else {
            throw new Error('Invalid get vehicles response format');
        }
    } catch (error) {
        console.error('Get vehicles error:', error.response ? error.response.data : error.message);
        throw new Error('Failed to get vehicles');
    }
}

async function getDefaultVehicle(userId) {
    try {
        // Check cache first
        if (vehicleCache[userId]) {
            console.log('Using cached vehicle');
            return vehicleCache[userId];
        }
        
        // Get API token
        const token = await getApiToken();
        
        // Fetch vehicles
        const vehicles = await getVehicles(token);
        
        if (vehicles && vehicles.length > 0) {
            // Use the first vehicle as default
            const defaultVehicle = vehicles[0];
            console.log(`Selected default vehicle: \${defaultVehicle.name} (ID: \${defaultVehicle.id})`);
            
            // Cache the vehicle
            vehicleCache[userId] = defaultVehicle;
            
            return defaultVehicle;
        } else {
            return null;
        }
    } catch (error) {
        console.error('Error getting default vehicle:', error);
        throw error;
    }
}

async function sendCommand(token, deviceId, command) {
    try {
        console.log(`Sending command "\${command}" to device \${deviceId}`);
        
        const numericDeviceId = parseInt(deviceId, 10);
        if (isNaN(numericDeviceId)) {
            throw new Error('Invalid device ID format, must be numeric');
        }
        
        const commandData = {
            deviceId: numericDeviceId,
            command: command,
            param: null
        };
        
        const response = await axios.post(API_CONFIG.commandUrl, commandData, {
            headers: {
                'Authorization': `Bearer \${token}`,
                'Content-Type': 'application/json'
            }
        });
        
        console.log('Command response:', JSON.stringify(response.data));
        return response.data;
    } catch (error) {
        console.error('Command error:', error.response ? error.response.data : error.message);
        throw new Error('Failed to send command to your vehicle');
    }
}
"@

$indexJsPath = "$workDir/index.js"
Set-Content -Path $indexJsPath -Value $indexJs

# Create package.json
Write-Host "Creating package.json..." -ForegroundColor Cyan
$packageJson = @"
{
  "name": "xviper-alexa-skill",
  "version": "1.0.0",
  "description": "X Viper Alexa Skill with direct authentication",
  "main": "index.js",
  "dependencies": {
    "axios": "^1.6.0"
  }
}
"@

$packageJsonPath = "$workDir/package.json"
Set-Content -Path $packageJsonPath -Value $packageJson

# Install dependencies
Write-Host "Installing dependencies..." -ForegroundColor Cyan
Set-Location -Path $workDir
Invoke-Expression "npm install --production"
Set-Location -Path ".."

# Create deployment package
Write-Host "Creating deployment package..." -ForegroundColor Cyan
$deploymentZip = "direct-auth-deployment.zip"
if (Test-Path $deploymentZip) {
    Remove-Item -Path $deploymentZip -Force
}

# Package with PowerShell
Write-Host "Packaging with PowerShell..." -ForegroundColor Cyan
Set-Location -Path $workDir
Invoke-Expression "Compress-Archive -Path * -DestinationPath ..\$deploymentZip -Force"
Set-Location -Path ".."

# Upload to S3
Write-Host "Uploading to S3..." -ForegroundColor Cyan
$s3UploadCmd = "aws s3 cp $deploymentZip s3://$S3_BUCKET/$deploymentZip --region $REGION"
Invoke-Expression $s3UploadCmd

# Update Lambda function code
Write-Host "Updating Lambda function code..." -ForegroundColor Cyan
$updateCodeCmd = "aws lambda update-function-code --function-name $LAMBDA_FUNCTION_NAME --s3-bucket $S3_BUCKET --s3-key $deploymentZip --region $REGION"
Invoke-Expression $updateCodeCmd

# Wait for update to complete
Write-Host "Waiting for Lambda update to complete..." -ForegroundColor Cyan
Start-Sleep -Seconds 5

# Update Lambda environment variables
Write-Host "Setting environment variables..." -ForegroundColor Cyan
$escapedPassword = $DEFAULT_PASSWORD.Replace('$', '`$')
$updateEnvCmd = "aws lambda update-function-configuration --function-name $LAMBDA_FUNCTION_NAME --environment 'Variables={DEFAULT_USERNAME=$DEFAULT_USERNAME,DEFAULT_PASSWORD=$escapedPassword}' --region $REGION"
Invoke-Expression $updateEnvCmd

# All done!
Write-Host ""
Write-Host "All done!" -ForegroundColor Green
Write-Host ""
Write-Host "The Lambda function has been deployed with direct authentication." -ForegroundColor Green
Write-Host "You can now use your Alexa skill without account linking!" -ForegroundColor Green
Write-Host ""
Write-Host "IMPORTANT: If your skill still has account linking enabled in the Alexa Developer Console:" -ForegroundColor Yellow
Write-Host "1. Go to the Alexa Developer Console" -ForegroundColor Yellow
Write-Host "2. Select your skill" -ForegroundColor Yellow
Write-Host "3. Navigate to 'Account Linking' in the left menu" -ForegroundColor Yellow
Write-Host "4. Turn off account linking" -ForegroundColor Yellow
Write-Host "5. Save and build your skill" -ForegroundColor Yellow
Write-Host ""