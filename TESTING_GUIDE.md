# Testing Guide: Alexa Skill with Cognito Authentication

This guide walks you through testing your Alexa skill with Cognito authentication to ensure everything is working properly.

## 1. Verify Cognito Domain is Working

First, make sure your Cognito domain is properly set up and accessible:

```
test-cognito-login.bat
```

This will:
- Locate your Cognito user pool
- Find your app client ID
- Generate a test URL
- Offer to open the URL in your browser

If the URL opens and shows a login page, your Cognito domain is working correctly. If you see an error page, wait 5-10 minutes and try again (domain propagation can take time).

## 2. Test Logging In with Your Test User

Once the login page is showing properly, try logging in with your test user:

- **Email**: jjpatten14@gmail.com
- **Password**: (The temporary password created during setup)

If login is successful, you should be redirected to a page that says "example.com refused to connect". This is expected because we're using a dummy redirect URL for testing.

## 3. Test the Alexa Skill Account Linking

To test the full account linking flow with Alexa:

1. Open the Alexa app on your mobile device
2. Go to "Skills & Games"
3. Select "Your Skills"
4. Find the "X Viper" skill
5. Tap on "Link Account"
6. You should be redirected to the Cognito login page
7. Sign in with the test user credentials
8. After successful login, you should be redirected back to the Alexa app
9. The skill should now show as "Account linked"

## 4. Test Voice Commands

Once account linking is successful, test the skill with voice commands:

- "Alexa, ask X Viper to lock my car"
- "Alexa, ask X Viper to unlock my car"
- "Alexa, ask X Viper to start my car"

The responses should indicate that the commands were processed successfully.

## Troubleshooting

If you encounter issues:

### Login Page Not Showing
- **Issue**: "Login pages unavailable" or other domain errors
- **Solution**: Run `fix-cognito-domain.bat` to recreate the domain

### Account Linking Fails
- **Issue**: "Unable to link your account" in the Alexa app
- **Solution**: Check if the callback URLs in the Cognito app client include all required Alexa domains

### Commands Not Working
- **Issue**: Alexa reports "there was a problem" with the skill
- **Solution**: Check Lambda logs in AWS CloudWatch to identify specific errors

### Token Errors
- **Issue**: Authentication token errors in Lambda logs
- **Solution**: Ensure the Cognito app client has proper OAuth scopes (openid, email, profile)