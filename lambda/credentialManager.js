/**
 * Handles secure storage and retrieval of user credentials
 */
const AWS = require('aws-sdk');

class CredentialManager {
    constructor() {
        this.secretsManager = new AWS.SecretsManager();
        this.dynamoDB = new AWS.DynamoDB.DocumentClient();
        this.USER_MAPPING_TABLE = process.env.USER_MAPPING_TABLE || 'XviperUserMappings';
        
        // Hard-coded credentials for simplified auth
        this.DEFAULT_USERNAME = process.env.DEFAULT_USERNAME;
        this.DEFAULT_PASSWORD = process.env.DEFAULT_PASSWORD;
    }

    /**
     * Store credentials in AWS Secrets Manager
     * @param {object} credentials The credentials to store
     * @returns {Promise<string>} The secret ID
     */
    async storeCredentials(credentials) {
        const secretName = `xviper-user-${Date.now()}`;
        const secretValue = JSON.stringify({
            username: credentials.username,
            password: credentials.password,
            token: credentials.token
        });

        const params = {
            Name: secretName,
            SecretString: secretValue
        };

        try {
            const result = await this.secretsManager.createSecret(params).promise();
            console.log(`Stored credentials in secret: ${result.ARN}`);
            return secretName;
        } catch (error) {
            console.error('Error storing credentials:', error);
            throw new Error('Failed to store credentials');
        }
    }

    /**
     * Retrieve credentials from AWS Secrets Manager
     * @param {string} secretName The secret name
     * @returns {Promise<object>} The credentials
     */
    async getCredentials(secretName) {
        const params = {
            SecretId: secretName
        };

        try {
            const result = await this.secretsManager.getSecretValue(params).promise();
            if (result.SecretString) {
                return JSON.parse(result.SecretString);
            } else {
                throw new Error('Secret does not contain string value');
            }
        } catch (error) {
            console.error('Error retrieving credentials:', error);
            throw new Error('Failed to retrieve credentials');
        }
    }

    /**
     * Update credentials in AWS Secrets Manager
     * @param {string} secretName The secret name
     * @param {object} credentials The updated credentials
     * @returns {Promise<void>}
     */
    async updateCredentials(secretName, credentials) {
        const secretValue = JSON.stringify({
            username: credentials.username,
            password: credentials.password,
            token: credentials.token
        });

        const params = {
            SecretId: secretName,
            SecretString: secretValue
        };

        try {
            await this.secretsManager.updateSecret(params).promise();
            console.log(`Updated credentials in secret: ${secretName}`);
        } catch (error) {
            console.error('Error updating credentials:', error);
            throw new Error('Failed to update credentials');
        }
    }

    /**
     * Map Alexa user ID to credentials secret name
     * @param {string} alexaUserId The Alexa user ID
     * @param {string} secretName The secret name containing credentials
     * @returns {Promise<void>}
     */
    async mapAlexaUserToCredentials(alexaUserId, secretName) {
        const params = {
            TableName: this.USER_MAPPING_TABLE,
            Item: {
                alexaUserId: alexaUserId,
                secretName: secretName,
                createdAt: new Date().toISOString()
            }
        };

        try {
            await this.dynamoDB.put(params).promise();
            console.log(`Mapped Alexa user ${alexaUserId} to secret ${secretName}`);
        } catch (error) {
            console.error('Error mapping user to credentials:', error);
            throw new Error('Failed to map user to credentials');
        }
    }

    /**
     * Get credential secret name for Alexa user ID
     * @param {string} alexaUserId The Alexa user ID
     * @returns {Promise<string>} The secret name
     */
    async getSecretNameForAlexaUser(alexaUserId) {
        const params = {
            TableName: this.USER_MAPPING_TABLE,
            Key: {
                alexaUserId: alexaUserId
            }
        };

        try {
            const result = await this.dynamoDB.get(params).promise();
            if (result.Item && result.Item.secretName) {
                return result.Item.secretName;
            } else {
                return null;
            }
        } catch (error) {
            console.error('Error getting secret name for user:', error);
            throw new Error('Failed to get credentials for user');
        }
    }

    /**
     * Map Alexa user ID to default vehicle
     * @param {string} alexaUserId The Alexa user ID
     * @param {string} deviceId The vehicle device ID
     * @param {string} vehicleName The vehicle name
     * @returns {Promise<void>}
     */
    async setDefaultVehicleForUser(alexaUserId, deviceId, vehicleName) {
        const params = {
            TableName: this.USER_MAPPING_TABLE,
            Key: {
                alexaUserId: alexaUserId
            },
            UpdateExpression: 'set defaultDeviceId = :d, defaultVehicleName = :n',
            ExpressionAttributeValues: {
                ':d': deviceId,
                ':n': vehicleName
            }
        };

        try {
            await this.dynamoDB.update(params).promise();
            console.log(`Set default vehicle for ${alexaUserId} to ${vehicleName} (${deviceId})`);
        } catch (error) {
            console.error('Error setting default vehicle:', error);
            throw new Error('Failed to set default vehicle');
        }
    }

    /**
     * Get default vehicle for Alexa user ID
     * @param {string} alexaUserId The Alexa user ID
     * @returns {Promise<object>} The default vehicle info
     */
    async getDefaultVehicleForUser(alexaUserId) {
        const params = {
            TableName: this.USER_MAPPING_TABLE,
            Key: {
                alexaUserId: alexaUserId
            }
        };

        try {
            const result = await this.dynamoDB.get(params).promise();
            if (result.Item && result.Item.defaultDeviceId) {
                return {
                    deviceId: result.Item.defaultDeviceId,
                    vehicleName: result.Item.defaultVehicleName || 'My Vehicle'
                };
            } else {
                return null;
            }
        } catch (error) {
            console.error('Error getting default vehicle:', error);
            throw new Error('Failed to get default vehicle');
        }
    }
}

module.exports = new CredentialManager();