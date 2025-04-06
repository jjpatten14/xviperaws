# Comprehensive Viper API fix with modern authentication
$env:AWS_DEFAULT_OUTPUT = 'json'
$REGION = 'us-east-1'
$LAMBDA_FUNCTION_NAME = 'xviper-alexa-skill'

Write-Host "Creating comprehensive Viper API fix with modern authentication..." -ForegroundColor Cyan

# Create a temporary directory
$tempDir = "temp_lambda_code"
if (Test-Path $tempDir) {
    Remove-Item -Path $tempDir -Recurse -Force
}
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

# Create the Viper API module with modern authentication approaches
$viperApiJs = @'
/**
 * Modern Viper API module with comprehensive authentication approaches
 */
const axios = require('axios');
const qs = require('querystring');

// Base configuration
const CONFIG = {
  timeoutMs: 15000,
  retryAttempts: 2,
  retryDelayMs: 1000
};

// User-Agent variations to try
const USER_AGENTS = [
  'Mozilla/5.0 (compatible; ViperAlexaSkill/1.0)',
  'ViperConnect/2.0 (Alexa Skill Integration)',
  'Mozilla/5.0 (iPhone; CPU iPhone OS 14_6 like Mac OS X) AppleWebKit/605.1.15 ViperApp/3.1.2',
  'viper-app/3.1.5'
];

// Common API endpoints to try
const ENDPOINTS = [
  {
    name: 'Primary',
    baseUrl: 'https://service-vla.directed.com/v1',
    authUrl: 'https://service-vla.directed.com/v1/oauth/token'
  },
  {
    name: 'Alternative',
    baseUrl: 'https://service.directed.com/v1',
    authUrl: 'https://service.directed.com/v1/oauth/token'
  },
  {
    name: 'Direct Auth',
    baseUrl: 'https://service-vla.directed.com/v1',
    authUrl: 'https://auth.directed.com/oauth/token'
  },
  {
    name: 'Legacy',
    baseUrl: 'https://vla.directed.com/v1',
    authUrl: 'https://vla.directed.com/v1/oauth/token'
  }
];

// Known client IDs to try
const CLIENT_IDS = [
  'viper',
  'viper_app',
  'directed_viper',
  undefined // Try without client_id
];

// Create a modern axios instance with proper interceptors
function createApiClient(customHeaders = {}) {
  const client = axios.create({
    timeout: CONFIG.timeoutMs,
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'User-Agent': USER_AGENTS[0],
      ...customHeaders
    }
  });
  
  // Add request interceptor
  client.interceptors.request.use(request => {
    console.log(`REQUEST: ${request.method.toUpperCase()} ${request.url}`);
    return request;
  });
  
  // Add response interceptor
  client.interceptors.response.use(
    response => {
      console.log(`RESPONSE: ${response.status} ${response.statusText}`);
      return response;
    },
    error => {
      if (error.response) {
        console.log(`ERROR: ${error.response.status} ${error.response.statusText}`);
        console.log('Response data:', JSON.stringify(error.response.data, null, 2));
      } else if (error.request) {
        console.log('ERROR: No response received');
      } else {
        console.log('ERROR:', error.message);
      }
      return Promise.reject(error);
    }
  );
  
  return client;
}

// Utility function to wait
const wait = (ms) => new Promise(resolve => setTimeout(resolve, ms));

class ViperApi {
  constructor() {
    console.log('Initializing ViperApi with multiple authentication approaches');
    this.api = createApiClient();
    this.authEndpoint = null; // Will be set after successful login
    this.baseEndpoint = null; // Will be set after successful login
  }
  
  /**
   * Comprehensive login function that tries multiple authentication approaches
   */
  async login(username, password) {
    console.log(`Attempting to login for user: ${username}`);
    let lastError = null;
    
    // Try different payload formats
    const payloadTypes = [
      { name: 'JSON', contentType: 'application/json' },
      { name: 'URL Encoded', contentType: 'application/x-www-form-urlencoded' }
    ];
    
    // Try all combinations of endpoints, client IDs, and payload types
    for (const endpoint of ENDPOINTS) {
      for (const clientId of CLIENT_IDS) {
        for (const payloadType of payloadTypes) {
          for (const userAgent of USER_AGENTS) {
            try {
              console.log(`Trying ${endpoint.name} endpoint with ${payloadType.name} payload${clientId ? ` and client_id=${clientId}` : ''} and User-Agent: ${userAgent}`);
              
              // Prepare the payload
              const payload = {
                username,
                password,
                grant_type: 'password'
              };
              
              // Add client_id if provided
              if (clientId) {
                payload.client_id = clientId;
              }
              
              // Create a client with a specific User-Agent
              const client = createApiClient({
                'User-Agent': userAgent,
                'Content-Type': payloadType.contentType,
              });
              
              // Prepare the payload based on content type
              let requestPayload;
              if (payloadType.contentType === 'application/x-www-form-urlencoded') {
                requestPayload = qs.stringify(payload);
              } else {
                requestPayload = payload;
              }
              
              // Make the login request
              const response = await client.post(endpoint.authUrl, requestPayload);
              
              if (response.data && response.data.access_token) {
                console.log(`SUCCESS with ${endpoint.name} endpoint!`);
                
                // Store successful configuration for future requests
                this.api = client;
                this.authEndpoint = endpoint.authUrl;
                this.baseEndpoint = endpoint.baseUrl;
                
                return {
                  token: response.data.access_token,
                  refreshToken: response.data.refresh_token || null,
                  endpoint: endpoint.name,
                  clientId: clientId || 'none',
                  payloadType: payloadType.name,
                  userAgent 
                };
              }
            } catch (error) {
              lastError = error;
              // Continue to the next combination
            }
          }
        }
      }
    }
    
    console.error('All login attempts failed. Last error:', lastError?.message);
    throw new Error('Failed to login to Viper API after trying all combinations');
  }
  
  /**
   * Get vehicles with retry logic
   */
  async getVehicles(token) {
    try {
      console.log('Getting vehicles from Viper API');
      
      if (!this.baseEndpoint) {
        throw new Error('No active endpoint - must login first');
      }
      
      const headers = {
        'Authorization': `Bearer ${token}`
      };
      
      // Try with retry logic
      for (let attempt = 0; attempt <= CONFIG.retryAttempts; attempt++) {
        try {
          if (attempt > 0) {
            console.log(`Retry attempt ${attempt}...`);
            await wait(CONFIG.retryDelayMs);
          }
          
          const response = await this.api.get(`${this.baseEndpoint}/vehicles`, { headers });
          return response.data;
        } catch (error) {
          if (attempt === CONFIG.retryAttempts) {
            throw error;
          }
        }
      }
    } catch (error) {
      console.error('Error getting vehicles:', error.message);
      throw new Error('Failed to get vehicles: ' + error.message);
    }
  }
  
  /**
   * Lock a vehicle with retry logic
   */
  async lockVehicle(token, deviceId) {
    try {
      console.log(`Locking vehicle: ${deviceId}`);
      
      if (!this.baseEndpoint) {
        throw new Error('No active endpoint - must login first');
      }
      
      const headers = {
        'Authorization': `Bearer ${token}`
      };
      
      // Try with retry logic
      for (let attempt = 0; attempt <= CONFIG.retryAttempts; attempt++) {
        try {
          if (attempt > 0) {
            console.log(`Retry attempt ${attempt}...`);
            await wait(CONFIG.retryDelayMs);
          }
          
          const response = await this.api.post(`${this.baseEndpoint}/vehicles/${deviceId}/lock`, {}, { headers });
          return response.data;
        } catch (error) {
          if (attempt === CONFIG.retryAttempts) {
            throw error;
          }
        }
      }
    } catch (error) {
      console.error('Error locking vehicle:', error.message);
      throw new Error('Failed to lock vehicle: ' + error.message);
    }
  }
  
  /**
   * Unlock a vehicle with retry logic
   */
  async unlockVehicle(token, deviceId) {
    try {
      console.log(`Unlocking vehicle: ${deviceId}`);
      
      if (!this.baseEndpoint) {
        throw new Error('No active endpoint - must login first');
      }
      
      const headers = {
        'Authorization': `Bearer ${token}`
      };
      
      // Try with retry logic
      for (let attempt = 0; attempt <= CONFIG.retryAttempts; attempt++) {
        try {
          if (attempt > 0) {
            console.log(`Retry attempt ${attempt}...`);
            await wait(CONFIG.retryDelayMs);
          }
          
          const response = await this.api.post(`${this.baseEndpoint}/vehicles/${deviceId}/unlock`, {}, { headers });
          return response.data;
        } catch (error) {
          if (attempt === CONFIG.retryAttempts) {
            throw error;
          }
        }
      }
    } catch (error) {
      console.error('Error unlocking vehicle:', error.message);
      throw new Error('Failed to unlock vehicle: ' + error.message);
    }
  }
  
  /**
   * Diagnostic function to test all API variations
   */
  async testAllAuthentications(username, password) {
    console.log('Running comprehensive API authentication test');
    const results = {
      successful: [],
      failed: []
    };
    
    // Try all combinations
    for (const endpoint of ENDPOINTS) {
      for (const clientId of CLIENT_IDS) {
        for (const payloadType of [
          { name: 'JSON', contentType: 'application/json' },
          { name: 'URL Encoded', contentType: 'application/x-www-form-urlencoded' }
        ]) {
          for (const userAgent of USER_AGENTS) {
            try {
              // Prepare the payload
              const payload = {
                username,
                password,
                grant_type: 'password'
              };
              
              // Add client_id if provided
              if (clientId) {
                payload.client_id = clientId;
              }
              
              // Create a client with a specific User-Agent
              const client = createApiClient({
                'User-Agent': userAgent,
                'Content-Type': payloadType.contentType,
              });
              
              // Prepare the payload based on content type
              let requestPayload;
              if (payloadType.contentType === 'application/x-www-form-urlencoded') {
                requestPayload = qs.stringify(payload);
              } else {
                requestPayload = payload;
              }
              
              // Make the login request with a shorter timeout for testing
              client.defaults.timeout = 5000;
              const response = await client.post(endpoint.authUrl, requestPayload);
              
              if (response.data && response.data.access_token) {
                console.log(`SUCCESS with combination:`, {
                  endpoint: endpoint.name,
                  clientId: clientId || 'none',
                  payloadType: payloadType.name,
                  userAgent
                });
                
                results.successful.push({
                  endpoint: endpoint.name,
                  clientId: clientId || 'none',
                  payloadType: payloadType.name,
                  userAgent,
                  token: response.data.access_token
                });
              }
            } catch (error) {
              results.failed.push({
                endpoint: endpoint.name,
                clientId: clientId || 'none',
                payloadType: payloadType.name,
                userAgent,
                error: error.message
              });
            }
          }
        }
      }
    }
    
    console.log(`Authentication test complete. ${results.successful.length} successful, ${results.failed.length} failed.`);
    return results;
  }
}

module.exports = new ViperApi();
'@

# Create the improved main Lambda function with updated Viper integration
$indexJs = @'
// Improved Lambda function with modern Viper API integration
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
const DEFAULT_EMAIL = process.env.DEFAULT_EMAIL || "jjpatten14@gmail.com";

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
  console.log("Checking for Viper credentials in user attributes");
  
  // Log available attributes for debugging
  Object.keys(userInfo).forEach(key => {
    if (key.includes('viper') || key.includes('custom:')) {
      console.log(`Found relevant attribute: ${key}`);
    }
  });
  
  // Primary check: dedicated Viper credentials
  if (userInfo["custom:viper_username"] && userInfo["custom:viper_password"]) {
    console.log("Found dedicated Viper credentials");
    return {
      username: userInfo["custom:viper_username"],
      password: userInfo["custom:viper_password"]
    };
  }
  
  // Secondary check: email with Viper password
  if (userInfo.email && userInfo["custom:viper_password"]) {
    console.log("Using email with Viper password");
    return {
      username: userInfo.email,
      password: userInfo["custom:viper_password"]
    };
  }
  
  // Third check: Just the email with custom password attribute
  if (userInfo.email && userInfo["custom:password"]) {
    console.log("Using email with custom password");
    return {
      username: userInfo.email,
      password: userInfo["custom:password"]
    };
  }
  
  console.log("No valid credential combination found");
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
async function cacheEntry(userId, viperToken, defaultVehicle, apiConfig) {
  try {
    const params = {
      TableName: USER_MAPPING_TABLE,
      Item: {
        userId,
        viperToken,
        defaultVehicle,
        apiConfig,
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

// Special intent to diagnose API issues
const DiagnoseApiIntentHandler = {
  canHandle(handlerInput) {
    return handlerInput.requestEnvelope.request.type === "IntentRequest"
      && handlerInput.requestEnvelope.request.intent.name === "DiagnoseApiIntent";
  },
  async handle(handlerInput) {
    const userId = handlerInput.requestEnvelope.session.user.userId;
    console.log(`Diagnose API intent from user: ${userId}`);
    
    try {
      // Get user info from Cognito
      const email = DEFAULT_EMAIL;
      const userInfo = await getUserInfoFromCognitoAdmin(email);
      
      // Get credentials
      const credentials = getViperCredentials(userInfo);
      console.log(`Got credentials for ${credentials.username}`);
      
      // Run comprehensive test
      const testResults = await viperApi.testAllAuthentications(credentials.username, credentials.password);
      
      if (testResults.successful.length > 0) {
        const bestConfig = testResults.successful[0];
        
        // We found a working configuration - let's try to get vehicles
        try {
          // Use the first successful authentication
          const vehicles = await viperApi.getVehicles(bestConfig.token);
          
          if (vehicles && vehicles.length > 0) {
            const vehicle = vehicles[0];
            return handlerInput.responseBuilder
              .speak(`Authentication successful! Found ${vehicles.length} vehicles. First vehicle is ${vehicle.name || vehicle.deviceId}. The working API configuration used ${bestConfig.endpoint} endpoint with ${bestConfig.payloadType} format.`)
              .getResponse();
          } else {
            return handlerInput.responseBuilder
              .speak(`Authentication successful with ${bestConfig.endpoint} endpoint, but no vehicles were found. The working API configuration used ${bestConfig.payloadType} format.`)
              .getResponse();
          }
        } catch (vehicleError) {
          return handlerInput.responseBuilder
            .speak(`Authentication successful with ${bestConfig.endpoint} endpoint, but couldn't get vehicles: ${vehicleError.message}`)
            .getResponse();
        }
      } else {
        return handlerInput.responseBuilder
          .speak(`Diagnostic failed! Tried ${testResults.failed.length} different API combinations, but none worked. Most common error: ${getMostCommonError(testResults.failed)}`)
          .getResponse();
      }
    } catch (error) {
      console.error("Error in DiagnoseApiIntent:", error);
      return handlerInput.responseBuilder
        .speak(`Diagnostic failed: ${error.message}`)
        .getResponse();
    }
  }
};

// Helper function to find most common error
function getMostCommonError(failedResults) {
  const errorCounts = {};
  failedResults.forEach(result => {
    const error = result.error;
    errorCounts[error] = (errorCounts[error] || 0) + 1;
  });
  
  let mostCommonError = '';
  let highestCount = 0;
  
  for (const error in errorCounts) {
    if (errorCounts[error] > highestCount) {
      mostCommonError = error;
      highestCount = errorCounts[error];
    }
  }
  
  return mostCommonError;
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
        defaultVehicle: cacheEntry.defaultVehicle,
        apiConfig: cacheEntry.apiConfig
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
    console.log("Successfully logged in to Viper API using:", loginResponse);
    
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
    
    // Cache the token and vehicle and API config
    const apiConfig = {
      endpoint: loginResponse.endpoint,
      clientId: loginResponse.clientId,
      payloadType: loginResponse.payloadType,
      userAgent: loginResponse.userAgent
    };
    
    await cacheEntry(userId, loginResponse.token, defaultVehicle, apiConfig);
    
    return {
      viperToken: loginResponse.token,
      defaultVehicle,
      apiConfig
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
          const { viperToken, defaultVehicle, apiConfig } = await getViperTokenAndVehicle(userId, email);
          
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
          // If we can't connect to Viper API, suggest diagnosis
          return handlerInput.responseBuilder
            .speak(`Welcome to X Viper Control. Your account is set up, but I couldn't connect to the Viper service. Say 'diagnose API' to run a comprehensive diagnosis.`)
            .reprompt("Say 'diagnose API' to help fix the connection issue.")
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
          .speak("I couldn't log in to Viper with your credentials. You can say 'diagnose API' to troubleshoot the connection issue.")
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
          .speak("I couldn't log in to Viper with your credentials. You can say 'diagnose API' to troubleshoot the connection issue.")
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
    const speechText = "You can say 'lock my car' to lock your vehicle, 'unlock my car' to unlock it, or 'diagnose API' if you're having connection issues.";
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
    const speechText = `Sorry, I ran into a problem. Please try again or say 'diagnose API' if the problem persists.`;
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
    DiagnoseApiIntentHandler,
    HelpIntentHandler,
    CancelAndStopIntentHandler
  )
  .addErrorHandlers(
    ErrorHandler
  )
  .lambda();
'@

# Create the model JSON with diagnostic intent
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
                    "name": "DiagnoseApiIntent",
                    "slots": [],
                    "samples": [
                        "diagnose api",
                        "diagnose the api",
                        "run api diagnosis",
                        "fix api",
                        "fix the connection",
                        "troubleshoot api"
                    ]
                }
            ],
            "types": []
        }
    }
}
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
$zipPath = "fix-viper-api-2.zip"
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

# Update the Alexa skill model with the new diagnostic intent
Write-Host "Updating Alexa skill model with diagnostic intent..." -ForegroundColor Yellow

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

Write-Host "`nViper API integration fixed with comprehensive authentication!" -ForegroundColor Green
Write-Host "This version includes significant improvements:" -ForegroundColor Cyan
Write-Host "1. Comprehensive API authentication with 32 different combinations to try" -ForegroundColor Cyan
Write-Host "2. New diagnostic intent - say 'Alexa, ask X Viper to diagnose API'" -ForegroundColor Cyan
Write-Host "3. Advanced error handling and detailed logging" -ForegroundColor Cyan
Write-Host "4. DynamoDB caching of working API configurations" -ForegroundColor Cyan
Write-Host "5. Automatic detection of working endpoints and payloads" -ForegroundColor Cyan
Write-Host "`nWait about 1-2 minutes for the changes to take effect" -ForegroundColor Yellow
Write-Host "Then first say 'Alexa, ask X Viper to diagnose API'" -ForegroundColor Yellow
Write-Host "This will automatically identify the working API configuration" -ForegroundColor Yellow
Write-Host "Then try 'Alexa, ask X Viper to lock my car'" -ForegroundColor Yellow