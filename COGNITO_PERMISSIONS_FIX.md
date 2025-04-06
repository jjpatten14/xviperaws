# Fixing "Failed to get userinfo from cognito" Error

This guide helps you fix the "Failed to get userinfo from cognito" error that occurs when using the Alexa Viper skill.

## The Problem

When asking Alexa to control your Viper system (like locking or unlocking your car), you receive an error message:
> "I'm sorry, I couldn't lock your vehicle. Failed to get userinfo from cognito"

This happens because:
1. The Lambda function lacks proper permissions to access Cognito user information
2. Your Cognito user profile might not have your Viper credentials stored correctly
3. The Lambda function may not be correctly configured to use the secure Cognito handler

## How to Fix

### Step 1: Run the Fix Script

1. Open Command Prompt 
2. Navigate to this directory
3. Run the `fix-cognito-permissions.bat` script

This script will:
- Add proper IAM permissions to your Lambda function to access Cognito
- Configure the Lambda function's environment variables
- Ensure the DynamoDB table exists for user mappings
- Verify the Cognito user pool has the necessary custom attributes
- Increase Lambda memory and timeout for better performance

### Step 2: Add Your Viper Credentials

Make sure your Viper credentials are stored in your Cognito user profile:

1. Run the `add-viper-credentials.bat` script
2. Enter your Cognito username (email)
3. Enter your Viper username (can be the same as email)
4. Enter your Viper password

This ensures that when the Lambda function runs, it can retrieve your personal Viper credentials from your Cognito profile instead of using default credentials.

### Step 3: Test Your Configuration

1. Run the `test-viper-credentials.bat` script
2. Enter your Cognito username when prompted
3. The script will verify:
   - Your Cognito user profile has the Viper credentials
   - The Lambda function has the correct environment variables
   - All permissions are properly set up

### Step 4: Test the Skill

Try using the skill again with a command like:
> "Alexa, ask X Viper to lock my car"

The skill should now be able to access your Cognito profile and use your personal Viper credentials to control your vehicle.

## Troubleshooting

If you still experience issues after following these steps:

1. Run `test-viper-credentials.bat` to check if all configurations are correct
2. Check the Lambda logs by running `check-lambda-logs.bat`
3. Make sure your Viper credentials are correct by testing them with the Viper mobile app
4. **Important**: Lambda configuration updates can take several minutes to complete. After running the fix script, you may need to wait 5-10 minutes before the changes take full effect.
5. Ensure that your Alexa account is properly linked with your Cognito account
6. If you see a "ResourceConflictException" error, it means a Lambda update is already in progress. The script will automatically wait and retry, but in some cases, you may need to wait and run it again later.

### Dealing with Lambda Update Conflicts

AWS Lambda has a limitation where only one configuration update can happen at a time. If you see errors related to "ResourceConflictException" while running the scripts, it means:

- Another update is already in progress
- The script will automatically wait and retry several times
- If it still fails after retries, wait 5-10 minutes and run the script again
- You can check the Lambda update status by running `test-viper-credentials.bat`

## Available Scripts

This directory includes several scripts to help fix and verify your setup:

- `fix-cognito-permissions.bat` - Fixes Lambda permissions and configuration for Cognito access
- `add-viper-credentials.bat` - Adds your Viper credentials to your Cognito user profile
- `test-viper-credentials.bat` - Tests if the configuration is correct
- `update-lambda-code.bat` - Updates Lambda code to use secureCognitoHandler (NEW!)
- `check-lambda-logs.bat` - Checks Lambda logs for any errors
- `check-user-attributes.bat` - Verifies your Cognito user attributes

## Complete Fix Procedure

For a complete fix of the "Failed to get userinfo from cognito" error, follow these steps in order:

1. Run `fix-cognito-permissions.bat` to add proper IAM permissions to Lambda
2. Run `add-viper-credentials.bat` to store your Viper credentials in Cognito
3. Run `update-lambda-code.bat` to update the Lambda code to use the secure handler
4. Wait approximately 1 minute for Lambda code changes to take effect
5. Test your skill again by saying "Alexa, ask X Viper to lock my car"

If you still encounter issues, run `test-viper-credentials.bat` to verify your configuration.

## Technical Details

The fix works by:
1. Adding specific IAM permissions for the Lambda function to access Cognito and DynamoDB
2. Ensuring the Lambda function uses the secure Cognito handler that retrieves your personal credentials
3. Configuring the Lambda with proper environment variables pointing to your Cognito user pool
4. Adding custom attributes to the Cognito user pool schema to store your Viper credentials
5. Creating the necessary DynamoDB table for user mapping

The updated IAM policy grants the Lambda function permission to:
- Get user information from Cognito
- Read and store data in the DynamoDB mapping table
- Use proper resource-specific permissions for better security