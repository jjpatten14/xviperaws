/**
 * API client for interacting with the Viper API
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
     * Login to the Viper API
     * @param {string} username The user's username
     * @param {string} password The user's password
     * @returns {Promise<object>} The login response data with token
     */
    async login(username, password) {
        try {
            console.log(`Attempting login for user: ${username}`);
            
            const formData = new URLSearchParams();
            formData.append('username', username);
            formData.append('password', password);

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
     * @param {string} authToken The authentication token
     * @returns {Promise<Array>} List of vehicles
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
     * @private
     * @param {object} device The device data from API
     * @returns {object} The vehicle object
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
     * @param {string} authToken The authentication token
     * @param {string} deviceId The device ID
     * @param {string} command The command to send
     * @returns {Promise<object>} The command response
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
     * @param {string} authToken The authentication token
     * @param {string} deviceId The device ID
     * @returns {Promise<object>} The command response
     */
    async lockVehicle(authToken, deviceId) {
        return this.sendVehicleCommand(authToken, deviceId, this.COMMAND_LOCK);
    }

    /**
     * Unlock a vehicle
     * @param {string} authToken The authentication token
     * @param {string} deviceId The device ID
     * @returns {Promise<object>} The command response
     */
    async unlockVehicle(authToken, deviceId) {
        return this.sendVehicleCommand(authToken, deviceId, this.COMMAND_UNLOCK);
    }

    /**
     * Start a vehicle's engine
     * @param {string} authToken The authentication token
     * @param {string} deviceId The device ID
     * @returns {Promise<object>} The command response
     */
    async startVehicle(authToken, deviceId) {
        return this.sendVehicleCommand(authToken, deviceId, this.COMMAND_START);
    }

    /**
     * Stop a vehicle's engine
     * @param {string} authToken The authentication token
     * @param {string} deviceId The device ID
     * @returns {Promise<object>} The command response
     */
    async stopVehicle(authToken, deviceId) {
        return this.sendVehicleCommand(authToken, deviceId, this.COMMAND_STOP);
    }

    /**
     * Open a vehicle's trunk
     * @param {string} authToken The authentication token
     * @param {string} deviceId The device ID
     * @returns {Promise<object>} The command response
     */
    async openTrunk(authToken, deviceId) {
        return this.sendVehicleCommand(authToken, deviceId, this.COMMAND_TRUNK);
    }

    /**
     * Activate a vehicle's panic alarm
     * @param {string} authToken The authentication token
     * @param {string} deviceId The device ID
     * @returns {Promise<object>} The command response
     */
    async activatePanic(authToken, deviceId) {
        return this.sendVehicleCommand(authToken, deviceId, this.COMMAND_PANIC);
    }
}

module.exports = new ViperApi();