/**
 * Handle Cognito tokens for user authentication with Viper API
 */
const axios = require('axios');
const AWS = require('aws-sdk');
const viperApi = require('./viperApi');
const credentialManager = require('./credentialManager');

// Configure these values according to your Cognito setup
const COGNITO_REGION = 'us-east-1';
const COGNITO_USER_POOL_ID = 'us-east-1_FhjKXtlKB';
const COGNITO_APP_CLIENT_ID = '6ejq4pqebjkn5qasg82roeomgr';

class CognitoTokenHandler {
    constructor() {
        this.cognitoIdentityServiceProvider = new AWS.CognitoIdentityServiceProvider({
            region: COGNITO_REGION
        });
    }

    /**
     * Get user information from an access token
     * @param {string} accessToken The Cognito access token
     * @returns {Promise<object>} User info
     */
    async getUserInfo(accessToken) {
        try {
            // Call Cognito to get user info 
            const params = {
                AccessToken: accessToken
            };
            
            const userData = await this.cognitoIdentityServiceProvider.getUser(params).promise();
            
            // Extract relevant user attributes
            const userInfo = {
                userId: userData.Username,
                attributes: {}
            };
            
            // Convert array of attributes to object
            userData.UserAttributes.forEach(attr => {
                userInfo.attributes[attr.Name] = attr.Value;
            });
            
            return userInfo;
        } catch (error) {
            console.error('Error getting user info from Cognito:', error);
            throw new Error('Failed to get user info from token');
        }
    }
    
    /**
     * Handle authentication for a user based on access token
     * @param {string} accessToken The Cognito access token 
     * @param {string} alexaUserId The Alexa user ID
     * @returns {Promise<object>} Authentication info and default vehicle
     */
    async handleAuthentication(accessToken, alexaUserId) {
        try {
            if (!accessToken) {
                throw new Error('No access token provided');
            }
            
            // Get user info from Cognito token
            const userInfo = await this.getUserInfo(accessToken);
            
            // Check if we already have Viper API token mapped for this Cognito user
            let secretName = await credentialManager.getSecretNameForAlexaUser(alexaUserId);
            let credentials = null;
            
            if (secretName) {
                // Try to get existing credentials
                try {
                    credentials = await credentialManager.getCredentials(secretName);
                } catch (err) {
                    console.log('Existing credentials not found or expired, will create new ones');
                }
            }
            
            // If no valid credentials, authenticate with Viper API
            if (!credentials || !credentials.token) {
                // For Viper authentication, we need username and password
                // With Cognito, these would be stored as custom attributes or mapped separately
                // For now, we'll use environment variables as fallback
                const username = process.env.DEFAULT_USERNAME;
                const password = process.env.DEFAULT_PASSWORD;
                
                if (!username || !password) {
                    throw new Error('Viper credentials not found');
                }
                
                // Login to Viper API
                const loginResponse = await viperApi.login(username, password);
                
                // Store credentials securely
                credentials = {
                    username: username,
                    password: password,
                    token: loginResponse.token,
                    cognitoUser: userInfo.userId
                };
                
                secretName = await credentialManager.storeCredentials(credentials);
                await credentialManager.mapAlexaUserToCredentials(alexaUserId, secretName);
            }
            
            // Get default vehicle or set one if it doesn't exist
            let defaultVehicle = await credentialManager.getDefaultVehicleForUser(alexaUserId);
            
            if (!defaultVehicle) {
                // Get vehicles and set first one as default
                const vehicles = await viperApi.getVehicles(credentials.token);
                if (vehicles && vehicles.length > 0) {
                    const firstVehicle = vehicles[0];
                    await credentialManager.setDefaultVehicleForUser(
                        alexaUserId, 
                        firstVehicle.deviceId, 
                        firstVehicle.name
                    );
                    defaultVehicle = {
                        deviceId: firstVehicle.deviceId,
                        vehicleName: firstVehicle.name
                    };
                }
            }
            
            return {
                credentials,
                defaultVehicle,
                userInfo
            };
        } catch (error) {
            console.error('Error in handleAuthentication:', error);
            throw error;
        }
    }
}

module.exports = new CognitoTokenHandler();