# Create a completely new app client for Alexa
$env:AWS_DEFAULT_OUTPUT = 'json'
$REGION = 'us-east-1'
$USER_POOL_NAME = 'XViperUserPool'
$NEW_APP_CLIENT_NAME = 'XViperAlexaClientNew'
$ALEXA_VENDOR_ID = "M2SYY47BAYR6E5"

Write-Host "Creating a new app client specifically for Alexa..." -ForegroundColor Cyan

# Find the user pool
$userPoolsCmd = "aws cognito-idp list-user-pools --max-results 60 --region $REGION"
$userPoolsJson = Invoke-Expression $userPoolsCmd
$userPools = $userPoolsJson | ConvertFrom-Json

$pool = $userPools.UserPools | Where-Object { $_.Name -eq $USER_POOL_NAME }

if ($pool) {
    $USER_POOL_ID = $pool.Id
    Write-Host "Found user pool: $USER_POOL_ID" -ForegroundColor Green
    
    # Create callback URLs JSON file
    $callbackUrls = @(
        "https://pitangui.amazon.com/api/skill/link/$ALEXA_VENDOR_ID",
        "https://layla.amazon.com/api/skill/link/$ALEXA_VENDOR_ID",
        "https://alexa.amazon.com/api/skill/link/$ALEXA_VENDOR_ID",
        "https://alexa.amazon.co.jp/api/skill/link/$ALEXA_VENDOR_ID",
        "https://pitangui.amazon.com/api/skill/link/*",
        "https://layla.amazon.com/api/skill/link/*",
        "https://alexa.amazon.com/api/skill/link/*",
        "https://alexa.amazon.co.jp/api/skill/link/*",
        "https://m.media-amazon.com/images/G/01/mobile-apps/dex/alexa/alexa-skills-kit/callbacks/*",
        "https://example.com"
    )
    
    $callbacksFile = "alexa_callbacks_new.json"
    ConvertTo-Json $callbackUrls | Set-Content $callbacksFile
    
    # Create OAuth flows JSON file
    $oauthFlows = @("code")
    $oauthFlowsFile = "alexa_oauth_flows_new.json"
    ConvertTo-Json $oauthFlows | Set-Content $oauthFlowsFile
    
    # Create OAuth scopes JSON file
    $scopes = @("openid", "email", "profile")
    $scopesFile = "alexa_scopes_new.json"
    ConvertTo-Json $scopes | Set-Content $scopesFile
    
    Write-Host "Creating new app client with correct Alexa settings..." -ForegroundColor Yellow
    
    # Create new app client with required settings
    $createClientCmd = "aws cognito-idp create-user-pool-client --user-pool-id $USER_POOL_ID " +
                       "--client-name $NEW_APP_CLIENT_NAME " +
                       "--generate-secret " +
                       "--refresh-token-validity 30 " +
                       "--allowed-o-auth-flows file://$oauthFlowsFile " +
                       "--allowed-o-auth-flows-user-pool-client " +
                       "--allowed-o-auth-scopes file://$scopesFile " +
                       "--callback-urls file://$callbacksFile " +
                       "--supported-identity-providers COGNITO " +
                       "--prevent-user-existence-errors ENABLED " +
                       "--region $REGION"
    
    $createClientResult = Invoke-Expression $createClientCmd
    $newClient = $createClientResult | ConvertFrom-Json
    
    # Clean up temp files
    Remove-Item $callbacksFile -Force
    Remove-Item $oauthFlowsFile -Force
    Remove-Item $scopesFile -Force
    
    if ($newClient.UserPoolClient) {
        $NEW_CLIENT_ID = $newClient.UserPoolClient.ClientId
        $NEW_CLIENT_SECRET = $newClient.UserPoolClient.ClientSecret
        
        Write-Host "`nNew App Client Created Successfully!" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Green
        Write-Host "Client Name: $NEW_APP_CLIENT_NAME" -ForegroundColor Cyan
        Write-Host "Client ID: $NEW_CLIENT_ID" -ForegroundColor Cyan
        Write-Host "Client Secret: $NEW_CLIENT_SECRET" -ForegroundColor Cyan
        Write-Host "========================================" -ForegroundColor Green
        
        # Get domain info
        $poolInfoCmd = "aws cognito-idp describe-user-pool --user-pool-id $USER_POOL_ID --region $REGION"
        $poolInfoJson = Invoke-Expression $poolInfoCmd
        $poolInfo = $poolInfoJson | ConvertFrom-Json
        $domain = $poolInfo.UserPool.Domain
        
        # Save Alexa configuration to file
        $configFile = "new_alexa_config.txt"
        @"
ALEXA SKILL ACCOUNT LINKING CONFIGURATION WITH NEW APP CLIENT
=============================================================
Authorization URL: https://$domain.auth.$REGION.amazoncognito.com/oauth2/authorize
Access Token URL: https://$domain.auth.$REGION.amazoncognito.com/oauth2/token
Client ID: $NEW_CLIENT_ID
Client Secret: $NEW_CLIENT_SECRET
Client Authentication Scheme: HTTP Basic (Credentials in request body)
Scope: openid email profile
Domain List: $domain.auth.$REGION.amazoncognito.com
=============================================================

IMPORTANT: Update your Alexa skill configuration with these new values.
"@ | Set-Content $configFile
        
        Write-Host "`nConfiguration saved to $configFile" -ForegroundColor Yellow
        Write-Host "Please update your Alexa skill with these new values." -ForegroundColor Yellow
        
        # Generate test URL
        $testUrl = "https://$domain.auth.$REGION.amazoncognito.com/login?client_id=$NEW_CLIENT_ID&response_type=code&scope=openid+email+profile&redirect_uri=https://example.com"
        Write-Host "`nTest URL: $testUrl" -ForegroundColor Cyan
        
        # Ask to update Lambda env var
        $updateLambda = Read-Host "Would you like to update Lambda environment variables with this new app client? (y/n)"
        if ($updateLambda -eq "y" -or $updateLambda -eq "Y") {
            $envVarsJson = @{
                "Variables" = @{
                    "COGNITO_USER_POOL_ID" = $USER_POOL_ID,
                    "USER_MAPPING_TABLE" = "XviperUserMappings",
                    "COGNITO_APP_CLIENT_ID" = $NEW_CLIENT_ID
                }
            } | ConvertTo-Json
            
            $envFile = "new_lambda_env.json"
            Set-Content -Path $envFile -Value $envVarsJson
            
            $updateLambdaCmd = "aws lambda update-function-configuration --function-name xviper-alexa-skill --environment file://$envFile --region $REGION"
            Invoke-Expression $updateLambdaCmd
            
            Remove-Item $envFile -Force
            
            Write-Host "Lambda environment variables updated with new app client ID!" -ForegroundColor Green
        }
    } else {
        Write-Host "Failed to create new app client." -ForegroundColor Red
    }
} else {
    Write-Host "User pool '$USER_POOL_NAME' not found." -ForegroundColor Red
}