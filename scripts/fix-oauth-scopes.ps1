# Script to fix OAuth scopes for Cognito app client
$env:AWS_DEFAULT_OUTPUT = 'json'
$REGION = 'us-east-1'
$USER_POOL_NAME = 'XViperUserPool'

Write-Host "Fixing OAuth scopes for Cognito app client..." -ForegroundColor Cyan

# Find the user pool
$userPoolsCmd = "aws cognito-idp list-user-pools --max-results 60 --region $REGION"
$userPoolsJson = Invoke-Expression $userPoolsCmd
$userPools = $userPoolsJson | ConvertFrom-Json

$pool = $userPools.UserPools | Where-Object { $_.Name -eq $USER_POOL_NAME }

if ($pool) {
    $USER_POOL_ID = $pool.Id
    Write-Host "Found user pool: $USER_POOL_ID" -ForegroundColor Green
    
    # Get all app clients
    $clientsCmd = "aws cognito-idp list-user-pool-clients --user-pool-id $USER_POOL_ID --region $REGION"
    $clientsJson = Invoke-Expression $clientsCmd
    $clients = $clientsJson | ConvertFrom-Json
    
    # Find the Alexa app client or create a new one
    $alexaClient = $null
    foreach ($client in $clients.UserPoolClients) {
        # Get client details
        $clientDetailsCmd = "aws cognito-idp describe-user-pool-client --user-pool-id $USER_POOL_ID --client-id $($client.ClientId) --region $REGION"
        $clientDetailsJson = Invoke-Expression $clientDetailsCmd
        $clientDetails = $clientDetailsJson | ConvertFrom-Json
        
        # Check if this is an Alexa client
        if ($clientDetails.UserPoolClient.ClientName -like "*alexa*" -or $clientDetails.UserPoolClient.ClientName -like "*Alexa*") {
            $alexaClient = $clientDetails.UserPoolClient
            Write-Host "Found Alexa app client: $($alexaClient.ClientName) ($($alexaClient.ClientId))" -ForegroundColor Green
            break
        }
    }
    
    # Create a new app client if no Alexa client found
    if (-not $alexaClient) {
        Write-Host "No Alexa app client found. Creating a new one..." -ForegroundColor Yellow
        
        $newClientName = "XViperAlexaClient"
        
        # Define callback URLs (replace with your actual Alexa skill's URLs)
        $callbackUrls = @(
            "https://pitangui.amazon.com/api/skill/link/MFYRCRLMTLFDDNW3",
            "https://layla.amazon.com/api/skill/link/MFYRCRLMTLFDDNW3",
            "https://alexa.amazon.co.jp/api/skill/link/MFYRCRLMTLFDDNW3"
        )
        
        # Convert callback URLs to comma-separated string
        $callbackUrlsString = $callbackUrls -join ","
        
        # Create app client with all scopes
        $createClientCmd = "aws cognito-idp create-user-pool-client --user-pool-id $USER_POOL_ID --client-name $newClientName --generate-secret --refresh-token-validity 30 --allowed-o-auth-flows authorization_code --allowed-o-auth-scopes openid email phone profile aws.cognito.signin.user.admin --callback-urls $callbackUrlsString --supported-identity-providers COGNITO --region $REGION"
        
        try {
            $createClientJson = Invoke-Expression $createClientCmd
            $createClient = $createClientJson | ConvertFrom-Json
            $alexaClient = $createClient.UserPoolClient
            Write-Host "Created new app client: $($alexaClient.ClientName) ($($alexaClient.ClientId))" -ForegroundColor Green
        } catch {
            Write-Host "Error creating app client: $_" -ForegroundColor Red
            exit 1
        }
    } else {
        # Update existing client to have correct scopes
        Write-Host "Updating existing Alexa app client with proper scopes..." -ForegroundColor Yellow
        
        # Get current callback URLs
        $callbackUrls = $alexaClient.CallbackURLs
        if (-not $callbackUrls -or $callbackUrls.Count -eq 0) {
            # Default callbacks if none found
            $callbackUrls = @(
                "https://pitangui.amazon.com/api/skill/link/MFYRCRLMTLFDDNW3",
                "https://layla.amazon.com/api/skill/link/MFYRCRLMTLFDDNW3",
                "https://alexa.amazon.co.jp/api/skill/link/MFYRCRLMTLFDDNW3"
            )
        }
        
        # Convert callback URLs to comma-separated string
        $callbackUrlsString = $callbackUrls -join ","
        
        # Update app client with all scopes
        $updateClientCmd = "aws cognito-idp update-user-pool-client --user-pool-id $USER_POOL_ID --client-id $($alexaClient.ClientId) --client-name $($alexaClient.ClientName) --refresh-token-validity 30 --allowed-o-auth-flows authorization_code --allowed-o-auth-scopes openid email phone profile aws.cognito.signin.user.admin --callback-urls $callbackUrlsString --supported-identity-providers COGNITO --region $REGION"
        
        try {
            $updateClientJson = Invoke-Expression $updateClientCmd
            $updateClient = $updateClientJson | ConvertFrom-Json
            Write-Host "Updated app client with proper scopes" -ForegroundColor Green
            
            # Extract client ID and secret for the user to update in Alexa developer console
            $clientId = $updateClient.UserPoolClient.ClientId
            $clientSecret = $updateClient.UserPoolClient.ClientSecret
            
            Write-Host "`nIMPORTANT: You need to update your Alexa Skill with these credentials:" -ForegroundColor Yellow
            Write-Host "Client ID: $clientId" -ForegroundColor Cyan
            Write-Host "Client Secret: $clientSecret" -ForegroundColor Cyan
            
            # Save to a file for reference
            $credentialsFile = "alexa_client_credentials.txt"
            Set-Content -Path $credentialsFile -Value @"
Client ID: $clientId
Client Secret: $clientSecret
Domain: https://$USER_POOL_NAME.auth.$REGION.amazoncognito.com
Authorization URI: https://$USER_POOL_NAME.auth.$REGION.amazoncognito.com/oauth2/authorize
Access Token URI: https://$USER_POOL_NAME.auth.$REGION.amazoncognito.com/oauth2/token
"@
            Write-Host "Credentials saved to $credentialsFile" -ForegroundColor Green
            
        } catch {
            Write-Host "Error updating app client: $_" -ForegroundColor Red
            exit 1
        }
    }
    
    # Get the domain name for this user pool
    $domainCmd = "aws cognito-idp describe-user-pool-domain --domain $USER_POOL_NAME --region $REGION"
    try {
        $domainJson = Invoke-Expression $domainCmd
        $domain = $domainJson | ConvertFrom-Json
        Write-Host "User pool domain: $USER_POOL_NAME.auth.$REGION.amazoncognito.com" -ForegroundColor Green
    } catch {
        Write-Host "No domain found for user pool. Creating one..." -ForegroundColor Yellow
        $createDomainCmd = "aws cognito-idp create-user-pool-domain --domain $USER_POOL_NAME --user-pool-id $USER_POOL_ID --region $REGION"
        Invoke-Expression $createDomainCmd | Out-Null
        Write-Host "Created user pool domain: $USER_POOL_NAME.auth.$REGION.amazoncognito.com" -ForegroundColor Green
    }
    
    Write-Host "`nOAuth scopes have been fixed!" -ForegroundColor Green
    Write-Host "For the changes to take effect, you need to:" -ForegroundColor Yellow
    Write-Host "1. Go to the Alexa developer console" -ForegroundColor Yellow
    Write-Host "2. Navigate to your skill's Account Linking settings" -ForegroundColor Yellow
    Write-Host "3. Update the Client ID and Client Secret with the values above" -ForegroundColor Yellow
    Write-Host "4. Save the changes and relink your account in the Alexa app" -ForegroundColor Yellow
    Write-Host "5. Once relinked, test the skill again" -ForegroundColor Yellow
    
} else {
    Write-Host "User pool not found. Please check the pool name and try again." -ForegroundColor Red
}