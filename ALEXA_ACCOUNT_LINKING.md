# Alexa Skill Account Linking Configuration

This guide will help you complete the account linking setup for your Alexa skill.

## Step 1: Update Your Cognito App Client

First, run the Alexa-specific configuration script:

```
alexa-specific-fix.bat
```

This script will:
1. Ensure your Cognito app client has the correct settings for Alexa
2. Update the callback URLs specifically for Alexa account linking
3. Set the proper OAuth flows and scopes
4. Display the configuration values you'll need for your Alexa skill

**IMPORTANT**: Take note of the Client ID and Client Secret displayed by the script. You'll need these values for Step 2.

## Step 2: Configure Account Linking in Alexa Developer Console

1. Go to the [Alexa Developer Console](https://developer.amazon.com/alexa/console/ask)
2. Select your skill
3. In the left navigation, click "Account Linking"
4. Enter the following information:

   **Security Provider Information:**
   - Auth Code Grant
   - Authorization URI: `https://xviper-auth.auth.us-east-1.amazoncognito.com/oauth2/authorize`
   - Access Token URI: `https://xviper-auth.auth.us-east-1.amazoncognito.com/oauth2/token`
   - Client ID: `[Client ID from the script output]`
   - Client Secret: `[Client Secret from the script output]`
   - Client Authentication Scheme: `HTTP Basic (Recommended)` or `Credentials in request body`
   - Scope: `openid email profile`
   - Domain List: `xviper-auth.auth.us-east-1.amazoncognito.com`

5. Click "Save" at the bottom of the page

## Step 3: Test Account Linking

1. Open the Alexa app on your mobile device
2. Go to "Skills & Games"
3. Select "Your Skills"
4. Find your skill and tap on it
5. Tap on "ENABLE TO USE"
6. You should see the Cognito login page
7. Enter your test user credentials:
   - Username: `jjpatten14@gmail.com`
   - Password: `[Your test user password]`
8. After successful login, you should be redirected back to the Alexa app
9. The skill should now be enabled and account linking complete

## Troubleshooting

If you see an "Unable to link account" error:

1. **Check Client Secret**: Make sure you're using the exact client secret shown in the script output
2. **Authentication Scheme**: Try switching between "HTTP Basic" and "Credentials in request body"
3. **Callback URLs**: Make sure all required Alexa callback URLs are included
4. **Domain Propagation**: Sometimes it takes time for DNS changes to propagate. Wait 5-10 minutes and try again

## Testing Voice Commands

Once account linking is successful, test with voice commands:

- "Alexa, ask X Viper to lock my car"
- "Alexa, ask X Viper to unlock my car"
- "Alexa, ask X Viper to start my car"