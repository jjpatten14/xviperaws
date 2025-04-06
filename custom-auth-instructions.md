# Implementing Custom Authentication for Alexa Skill

This approach uses a custom login page and a simplified authentication flow that bypasses most of the complexity of OAuth. It still works with account linking but gives you complete control over the user experience.

## Step 1: Host the Custom Login Page

1. Take the `custom-login.html` file and host it on a static web server.
   - You can use Amazon S3 static website hosting
   - Or another service like GitHub Pages, Netlify, or Vercel
   - Make sure the page is accessible over HTTPS

2. For S3 hosting:
   ```
   aws s3 mb s3://xviper-auth-page --region us-east-1
   aws s3 website s3://xviper-auth-page --index-document custom-login.html
   aws s3 cp custom-login.html s3://xviper-auth-page/ --acl public-read
   ```

3. Note the URL of your hosted page, e.g.:
   ```
   https://xviper-auth-page.s3-website-us-east-1.amazonaws.com/custom-login.html
   ```

## Step 2: Set Up a Custom Authorization Server (Lambda)

1. Create a new Lambda function to act as your authorization server:

```javascript
// Custom OAuth server for Alexa skills
exports.handler = async (event) => {
    console.log('Event:', JSON.stringify(event));
    
    // Parse query parameters from the event
    const queryParams = event.queryStringParameters || {};
    
    // Handle different OAuth endpoints
    if (event.path === '/authorize') {
        return handleAuthorize(queryParams);
    } else if (event.path === '/token') {
        return handleToken(event);
    } else {
        return {
            statusCode: 404,
            body: JSON.stringify({ error: 'Not Found' })
        };
    }
};

// Handle authorization request
function handleAuthorize(queryParams) {
    const {
        client_id,
        redirect_uri,
        response_type,
        state,
        scope
    } = queryParams;
    
    // Validate client_id, redirect_uri, etc.
    
    // Redirect to your custom login page with the original OAuth parameters
    const loginUrl = 'https://your-hosted-login-page.com/custom-login.html' +
        `?client_id=${encodeURIComponent(client_id)}` +
        `&redirect_uri=${encodeURIComponent(redirect_uri)}` +
        `&response_type=${encodeURIComponent(response_type)}` +
        `&state=${encodeURIComponent(state)}` +
        `&scope=${encodeURIComponent(scope)}`;
    
    return {
        statusCode: 302,
        headers: {
            'Location': loginUrl
        },
        body: ''
    };
}

// Handle token exchange
function handleToken(event) {
    // Parse the request body
    const body = JSON.parse(event.body);
    const {
        grant_type,
        code,
        client_id,
        client_secret,
        redirect_uri
    } = body;
    
    // Validate the parameters
    
    // In a real implementation, you would validate the authorization code
    // Here we're just generating a random access token
    
    // Generate access token
    const accessToken = `access_${Date.now()}_${Math.random().toString(36).substring(2, 10)}`;
    const refreshToken = `refresh_${Date.now()}_${Math.random().toString(36).substring(2, 10)}`;
    
    return {
        statusCode: 200,
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            access_token: accessToken,
            refresh_token: refreshToken,
            token_type: 'Bearer',
            expires_in: 3600
        })
    };
}
```

2. Create an API Gateway to expose this Lambda:
   - Create a REST API
   - Add routes for `/authorize` and `/token`
   - Deploy the API
   - Note the API endpoint URL

## Step 3: Configure Alexa Skill Account Linking

1. Go to the Alexa Developer Console
2. Select your skill
3. Navigate to "Account Linking" in the left menu
4. Configure these settings:

   **Security Provider**: OAuth 2.0
   
   **Authorization URI**:
   ```
   https://your-api-gateway-url.execute-api.us-east-1.amazonaws.com/prod/authorize
   ```
   
   **Access Token URI**:
   ```
   https://your-api-gateway-url.execute-api.us-east-1.amazonaws.com/prod/token
   ```
   
   **Client ID**: Create a random string (e.g., "xviper-alexa-client")
   
   **Client Secret**: Create a random string
   
   **Client Authentication Scheme**: Credentials in request body
   
   **Scope**: `profile`
   
   **Domains**: Add your API Gateway domain and your login page domain

5. Save the settings

## Step 4: Update the Lambda Handler

1. Add the `customAuthHandler.js` file to your Lambda function
2. Update your Lambda index.js to use this for authentication

## Step 5: Test Account Linking

1. Open the Alexa app on your mobile device
2. Go to your skill
3. Click "Link Account"
4. You should be redirected to your custom login page
5. The page will automatically authenticate and redirect back to Alexa
6. Test your skill by saying "Alexa, ask X Viper to lock my car"

## Simplified Approach: Skip Account Linking

If you want to avoid account linking entirely, you can use the simpler approach:

1. Deploy the simple Lambda function from earlier that uses hardcoded credentials
2. Update your skill to not require account linking

This is the easiest approach and avoids all the OAuth complexity, but doesn't give users a way to use their own credentials.