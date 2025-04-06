# Setting Up Amazon Cognito for Xviper Alexa Skill OAuth

## 1. Create a Cognito User Pool

1. Go to the AWS Console and navigate to Amazon Cognito
2. Select "User Pools" and click "Create User Pool"
3. Choose "Email" as the sign-in option
4. Under "Required attributes", select "email" and "name"
5. Configure password policies as needed (default is fine)
6. Configure MFA as optional or off for testing
7. Configure email delivery through Amazon SES or use Cognito's default
8. Name your user pool "XviperUserPool"
9. Under "Initial app client", choose "Public client" for Alexa Skills
10. Name the app client "XviperAlexaClient"
11. Set "Refresh token expiration" to 30 days
12. Under "Advanced app client settings":
    - Add "https://pitangui.amazon.com/api/skill/link/M3RPN48POS9B20" to Callback URLs
    - Add "https://layla.amazon.com/api/skill/link/M3RPN48POS9B20" to Callback URLs 
    - Add "https://alexa.amazon.co.jp/api/skill/link/M3RPN48POS9B20" to Callback URLs
    - (Add your skill's callback URLs for all regions you support)
13. Under "Allowed OAuth Flows", select "Authorization code grant"
14. Under "Allowed OAuth Scopes", select "email", "openid", and "profile"
15. Complete the creation process

Take note of:
- User Pool ID
- App Client ID
- Domain name (you'll need to set this up in the app integration tab)

## 2. Setting Up Your Domain

1. Go to the "App integration" tab in your User Pool
2. Under "Domain", choose "Use a Cognito domain"
3. Enter a domain prefix (e.g., "xviper-alexa")
4. Click "Create"

## 3. Configure Alexa Skill for Account Linking

1. Go to the Alexa Developer Console
2. Select your Xviper skill
3. Navigate to "Account Linking" in the left menu
4. Set "Authorization URI" to: `https://[your-domain].auth.[region].amazoncognito.com/oauth2/authorize`
5. Set "Access Token URI" to: `https://[your-domain].auth.[region].amazoncognito.com/oauth2/token`
6. Set "Client ID" to your Cognito App Client ID
7. For "Scopes", add: `openid profile email`
8. Set "Authorization Grant Type" to "Auth Code Grant"
9. Add the following domains to "Alexa allowed skills in the Authorization URI":
   - pitangui.amazon.com
   - layla.amazon.com
   - alexa.amazon.co.jp
10. Save the configuration

## 4. Create a Test User in Cognito

1. Go to the "Users" tab in your User Pool
2. Click "Create user"
3. Choose "Send an email invitation"
4. Enter:
   - Email: jjpatten14@gmail.com 
   - Name: Joshua Jerome-Patten
   - Set a temporary password or have Cognito generate one
5. Click "Create user"

## 5. Modify Lambda Function to Use Cognito Tokens

The Cognito integration will be managed through the Alexa Skill account linking. The Lambda function will receive the access token when a user links their account and makes a request.