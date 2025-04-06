# Setting Up Secure User Authentication with Cognito

This guide explains how to properly set up Amazon Cognito for your Alexa skill with true user authentication (no hardcoded credentials).

## 1. Create and Configure Your Cognito User Pool

1. **Create a User Pool**:
   - Go to AWS Console > Amazon Cognito > User Pools
   - Click "Create user pool"
   - Choose "Email" as the sign-in option
   - Configure standard attributes (email is required)
   - Configure password policy as needed
   - Choose verification method (email verification is recommended)

2. **Configure App Client**:
   - Add a new app client if needed (Public client for Alexa skills)
   - Enable "Authorization code grant" flow
   - Set a refresh token expiration (30 days recommended)
   - Add callback URLs for Alexa:
     ```
     https://pitangui.amazon.com/api/skill/link/M2SYY47BAYR6E5
     https://layla.amazon.com/api/skill/link/M2SYY47BAYR6E5
     https://alexa.amazon.com/api/skill/link/M2SYY47BAYR6E5
     https://alexa.amazon.co.jp/api/skill/link/M2SYY47BAYR6E5
     https://pitangui.amazon.com/api/skill/link/*
     https://layla.amazon.com/api/skill/link/*
     https://alexa.amazon.com/api/skill/link/*
     https://alexa.amazon.co.jp/api/skill/link/*
     ```
   - Enable OAuth scopes: `email`, `openid`, `profile`

3. **Add Custom Attributes**:
   - Go to User Pool > Sign-up experience > Custom attributes
   - Add a custom attribute: `custom:viper_username` (String)
   - Add a custom attribute: `custom:viper_password` (String)
     - Note: In a production app, you would use a token or encrypted value, not the actual password
   - Ensure custom attributes are mutable

4. **Set Up Domain**:
   - Go to App integration > Domain
   - Choose "Use Cognito domain" and enter a domain prefix 
   - Under "Branding version" select "Managed login"

5. **Configure Managed Login Branding**:
   - Under App integration > Hosted UI customization
   - Add your logo and customize the appearance
   - Customize sign-in text and other elements

## 2. Configure Your Alexa Skill for Account Linking

1. Go to the Alexa Developer Console > Your Skill > Account Linking

2. Configure with these settings:
   - Security Provider: OAuth 2.0
   - Authorization URL: `https://your-domain.auth.region.amazoncognito.com/oauth2/authorize`
   - Access Token URL: `https://your-domain.auth.region.amazoncognito.com/oauth2/token`
   - Client ID: Your Cognito app client ID
   - Client Secret: Your Cognito app client secret (if you created one)
   - Client Authentication Scheme: HTTP Basic (if you have a client secret) or Credentials in request body
   - Scope: `openid profile email`
   - Domain List: Add `amazoncognito.com` and your specific domain

3. Save and build your skill

## 3. Create a Lambda IAM Role with Proper Permissions

Your Lambda function needs permission to interact with Cognito. Create an IAM policy with:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "cognito-idp:GetUser",
                "cognito-idp:AdminGetUser"
            ],
            "Resource": "arn:aws:cognito-idp:REGION:ACCOUNT_ID:userpool/USER_POOL_ID"
        },
        {
            "Effect": "Allow",
            "Action": [
                "dynamodb:GetItem",
                "dynamodb:PutItem",
                "dynamodb:UpdateItem"
            ],
            "Resource": "arn:aws:dynamodb:REGION:ACCOUNT_ID:table/XviperUserMappings"
        }
    ]
}
```

Attach this policy to your Lambda execution role.

## 4. Deploy the Lambda Function

1. Update your Lambda environment variables:
   ```
   COGNITO_USER_POOL_ID=your-user-pool-id
   USER_MAPPING_TABLE=XviperUserMappings
   ```

2. Deploy the Lambda code with:
   ```
   deploy-secure-cognito.bat
   ```

## 5. Set Up User Registration

For your users to use the skill, they'll need to:

1. Create a Cognito account (via your login page)
2. Provide their Viper API credentials 

You have two options:

### Option A: Collect Viper Credentials During Registration

Add custom fields to your registration form for Viper username and password.

### Option B: Add Viper Credentials After Registration

Have users log in to a web portal where they can add their Viper credentials.

## Security Considerations

1. **Never store passwords in plain text**: In a real application, you would:
   - Use a secure token exchange rather than storing the actual password
   - Encrypt sensitive information
   - Use AWS Secrets Manager or similar service for credential management

2. **Implement proper error handling**: Provide clear instructions to users when authentication fails

3. **Use HTTPS for all endpoints**: Ensure all communications are encrypted 

4. **Set up MFA**: Consider requiring multi-factor authentication for added security

5. **Implement token rotation**: Periodically refresh the API tokens to minimize risk if a token is compromised