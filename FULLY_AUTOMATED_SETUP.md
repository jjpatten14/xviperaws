# Fully Automated OAuth Setup for Alexa Skill

This guide provides a complete solution for setting up OAuth account linking with Amazon Cognito for your Alexa skill. The automation handles everything from Cognito User Pool creation to Alexa skill configuration.

## Advantages of This Solution

- **Fully Automated**: One script handles the entire setup process
- **Secure Authentication**: No hardcoded credentials in your Lambda function
- **Proper Account Linking**: Works properly with the Alexa mobile app
- **Token-Based**: Uses secure, time-limited tokens
- **User-Friendly**: Minimal manual steps required
- **Scalable**: Works for multiple users

## Prerequisites

1. **AWS CLI**: Make sure it's installed and configured with appropriate permissions
2. **PowerShell**: Required to run the automation script
3. **ASK CLI** (optional): For automating Alexa skill configuration (install with `npm install -g ask-cli` and run `ask init`)

## Quick Start Guide

To set up everything in one go:

1. Open a command prompt and navigate to the project directory
2. Run the automation script:

```
setup-complete-with-alexa.bat
```

This script will:
- Create a Cognito User Pool with custom attributes for Viper credentials
- Configure an app client with proper OAuth settings
- Set up callback URLs that work with the Alexa mobile app
- Create and configure a DynamoDB table for user data
- Deploy the Lambda function with secure authentication
- Set up the Alexa skill with account linking (automatic with ASK CLI, instructions provided without it)
- Create a test user for immediate testing

## What Happens During Setup

The automation script:

1. **Cognito Setup**:
   - Creates a User Pool with custom attributes for Viper credentials
   - Sets up an app client with proper OAuth scopes and redirects
   - Configures a Cognito domain for hosted login

2. **DynamoDB Setup**:
   - Creates a table for mapping Alexa user IDs to Viper credentials
   - Sets up appropriate IAM permissions

3. **Lambda Deployment**:
   - Creates a Lambda function that securely retrieves credentials from Cognito
   - Sets up IAM roles and policies for Lambda
   - Configures environment variables

4. **Alexa Skill Configuration**:
   - Updates the skill with account linking information
   - Sets the endpoint to the Lambda function
   - Configures the interaction model

5. **Test User Setup**:
   - Creates a test user with Viper credentials
   - Sets up all necessary attributes

## Testing the Integration

After running the script:

1. Open the Alexa app on your mobile device
2. Find your skill and select "Link Account"
3. Sign in with the test user credentials
4. Try voice commands like "Alexa, ask X Viper to lock my car"

## Troubleshooting

If you encounter issues:

- **Redirect URL Mismatch**: The script adds multiple redirect URLs including wildcards to handle all Alexa endpoints
- **Invalid Token**: Check the Cognito token timeouts in the app client settings
- **Missing Permissions**: Verify that Lambda has the proper IAM permissions

## Manual Configuration (if needed)

If ASK CLI is not available, the script will output manual instructions for configuring your Alexa skill, including:

1. Account linking settings to enter in the Alexa Developer Console
2. Lambda ARN to use as your skill endpoint
3. Interaction model configuration

## Security Considerations

- Viper credentials are stored as custom attributes in Cognito, not in the Lambda code
- All tokens are time-limited and properly refreshed
- DynamoDB table uses encryption at rest
- Proper IAM permissions limit access to resources

## Need Help?

If you need assistance, refer to the AWS and Alexa documentation:

- [Amazon Cognito Developer Guide](https://docs.aws.amazon.com/cognito/latest/developerguide/what-is-amazon-cognito.html)
- [Alexa Skills Kit Documentation](https://developer.amazon.com/en-US/docs/alexa/ask-overviews/what-is-the-alexa-skills-kit.html)
- [AWS Lambda Documentation](https://docs.aws.amazon.com/lambda/latest/dg/welcome.html)