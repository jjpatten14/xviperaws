/**
 * Secure Cognito handler that uses proper user authentication
 * without hardcoded credentials
 */
const AWS = require('aws-sdk');
const viperApi = require('./viperApi');

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
            console.log(Processing authenticated request for user: );
            
            // Get the user's info from Cognito using the access token
            const cognitoUserInfo = await this.getUserInfoFromCognito(accessToken);
            console.log('Got Cognito user info:', JSON.stringify({
                sub: cognitoUserInfo.sub,
                email: cognitoUserInfo.email,
                name: cognitoUserInfo.name
            }));
            
            // Check if we have a mapping for this user in DynamoDB
            const userMapping = await this.getUserMapping(alexaUserId);
            
            // Check if we have a cached Viper token
            if (userMapping && userMapping.viperToken && userMapping.expiresAt > Date.now()) {
                console.log('Using cached Viper token');
                return {
                    viperToken: userMapping.viperToken,
                    defaultVehicle: userMapping.defaultVehicle
                };
            }
            
            // We need to get a fresh Viper token
            console.log('No valid cached token, getting Viper credentials');
            
            // Get the user's Viper credentials from Cognito user attributes
            const viperCredentials = await this.getViperCredentialsFromCognito(cognitoUserInfo);
            
            // Login to Viper API
            console.log('Logging in to Viper API with user credentials');
            const loginResponse = await viperApi.login(
                viperCredentials.username,
                viperCredentials.password
            );
            
            // Get vehicles
            const vehicles = await viperApi.getVehicles(loginResponse.token);
            let defaultVehicle = null;
            
            if (vehicles && vehicles.length > 0) {
                defaultVehicle = {
                    deviceId: vehicles[0].deviceId,
                    vehicleName: vehicles[0].name
                };
            }
            
            // Store the mapping
            await this.storeUserMapping(alexaUserId, {
                cognitoSubject: cognitoUserInfo.sub,
                viperToken: loginResponse.token,
                defaultVehicle,
                expiresAt: Date.now() + (12 * 60 * 60 * 1000) // 12 hours
            });
            
            return {
                viperToken: loginResponse.token,
                defaultVehicle
            };
        } catch (error) {
            console.error('Error processing authenticated request:', error);
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
            const params = {
                AccessToken: accessToken
            };
            
            const userData = await cognitoIdentityServiceProvider.getUser(params).promise();
            
            // Convert attributes array to object
            const userInfo = {
                username: userData.Username
            };
            
            userData.UserAttributes.forEach(attr => {
                userInfo[attr.Name] = attr.Value;
            });
            
            return userInfo;
        } catch (error) {
            console.error('Error getting user info from Cognito:', error);
            throw new Error('Failed to get user info from Cognito');
        }
    }
    
    /**
     * Get Viper credentials from Cognito user attributes
     * @param {Object} userInfo - Cognito user info
     * @returns {Promise<Object>} Viper credentials
     */
    async getViperCredentialsFromCognito(userInfo) {
        try {
            // Get username from custom attribute or use email
            const username = userInfo['custom:viper_username'] || userInfo.email;
            const password = userInfo['custom:viper_password'];
            
            if (!password) {
                throw new Error('Viper credentials not found in user profile');
            }
            
            return {
                username,
                password
            };
        } catch (error) {
            console.error('Error getting Viper credentials:', error);
            throw new Error('Failed to get Viper credentials');
        }
    }
    
    /**
     * Get user mapping from DynamoDB
     * @param {string} alexaUserId - The Alexa user ID
     * @returns {Promise<Object|null>} The user mapping or null
     */
    async getUserMapping(alexaUserId) {
        try {
            const params = {
                TableName: USER_MAPPING_TABLE,
                Key: {
                    alexaUserId
                }
            };
            
            const result = await dynamoDB.get(params).promise();
            return result.Item || null;
        } catch (error) {
            console.error('Error getting user mapping:', error);
            return null;
        }
    }
    
    /**
     * Store user mapping in DynamoDB
     * @param {string} alexaUserId - The Alexa user ID
     * @param {Object} mapping - The mapping data
     * @returns {Promise<void>}
     */
    async storeUserMapping(alexaUserId, mapping) {
        try {
            const params = {
                TableName: USER_MAPPING_TABLE,
                Item: {
                    alexaUserId,
                    ...mapping,
                    updatedAt: Date.now()
                }
            };
            
            await dynamoDB.put(params).promise();
            console.log(Stored mapping for user: );
        } catch (error) {
            console.error('Error storing user mapping:', error);
            throw error;
        }
    }
    
    /**
     * Update default vehicle for a user
     * @param {string} alexaUserId - The Alexa user ID
     * @param {Object} vehicle - The vehicle data
     * @returns {Promise<void>}
     */
    async updateDefaultVehicle(alexaUserId, vehicle) {
        try {
            const mapping = await this.getUserMapping(alexaUserId);
            
            if (mapping) {
                mapping.defaultVehicle = vehicle;
                await this.storeUserMapping(alexaUserId, mapping);
                console.log(Updated default vehicle for user: );
            } else {
                throw new Error('User mapping not found');
            }
        } catch (error) {
            console.error('Error updating default vehicle:', error);
            throw error;
        }
    }
}

module.exports = new SecureCognitoHandler();
