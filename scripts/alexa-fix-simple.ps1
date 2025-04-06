# Simple Alexa-specific fix for Cognito app client
$env:AWS_DEFAULT_OUTPUT = 'json'
$REGION = 'us-east-1'
$USER_POOL_NAME = 'XViperUserPool'
$ALEXA_VENDOR_ID = "M2SYY47BAYR6E5"

Write-Host "Applying simplified Alexa fixes..." -ForegroundColor Cyan

try {
    # Find the user pool
    $userPoolsCmd = "aws cognito-idp list-user-pools --max-results 60 --region $REGION"
    $userPoolsJson = Invoke-Expression $userPoolsCmd
    $userPools = $userPoolsJson | ConvertFrom-Json
    
    $pool = $userPools.UserPools | Where-Object { $_.Name -eq $USER_POOL_NAME }
    
    if ($pool) {
        $USER_POOL_ID = $pool.Id
        Write-Host "Found user pool: $USER_POOL_ID" -ForegroundColor Green
        
        # Get domain info
        $poolInfoCmd = "aws cognito-idp describe-user-pool --user-pool-id $USER_POOL_ID --region $REGION"
        $poolInfoJson = Invoke-Expression $poolInfoCmd
        $poolInfo = $poolInfoJson | ConvertFrom-Json
        $domain = $poolInfo.UserPool.Domain
        
        # Get client info
        $clientsInfoCmd = "aws cognito-idp list-user-pool-clients --user-pool-id $USER_POOL_ID --region $REGION"
        $clientsInfoJson = Invoke-Expression $clientsInfoCmd
        $clientsInfo = $clientsInfoJson | ConvertFrom-Json
        
        if ($clientsInfo.UserPoolClients.Count -gt 0) {
            $clientId = $clientsInfo.UserPoolClients[0].ClientId
            $clientName = $clientsInfo.UserPoolClients[0].ClientName
            
            Write-Host "Found app client: $clientName ($clientId)" -ForegroundColor Green
            
            # Get current client details to retrieve client secret
            $clientDetailCmd = "aws cognito-idp describe-user-pool-client --user-pool-id $USER_POOL_ID --client-id $clientId --region $REGION"
            $clientDetailJson = Invoke-Expression $clientDetailCmd
            $clientDetail = $clientDetailJson | ConvertFrom-Json
            $clientSecret = $clientDetail.UserPoolClient.ClientSecret
            
            # Create required files for Alexa configuration
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
            
            # Create JSON files
            $callbacksFile = "alexa_callbacks.json"
            $scopesFile = "alexa_scopes.json"
            $oauthFlowsFile = "alexa_oauth_flows.json"
            
            # Use only code flow for Alexa
            $oauthFlows = @("code")
            
            # OAuth scopes
            $scopes = @("openid", "email", "profile")
            
            # Write to files
            ConvertTo-Json $callbackUrls | Set-Content $callbacksFile
            ConvertTo-Json $oauthFlows | Set-Content $oauthFlowsFile
            ConvertTo-Json $scopes | Set-Content $scopesFile
            
            # Update with simple command that works
            Write-Host "Updating app client with Alexa settings..." -ForegroundColor Yellow
            
            $updateCmd = "aws cognito-idp update-user-pool-client --user-pool-id $USER_POOL_ID --client-id $clientId --callback-urls file://$callbacksFile --allowed-o-auth-flows file://$oauthFlowsFile --allowed-o-auth-flows-user-pool-client --allowed-o-auth-scopes file://$scopesFile --supported-identity-providers COGNITO --region $REGION"
            
            Invoke-Expression $updateCmd | Out-Null
            
            # Clean up files
            Remove-Item $callbacksFile -Force
            Remove-Item $oauthFlowsFile -Force 
            Remove-Item $scopesFile -Force
            
            # Show configuration for Alexa skill
            Write-Host "`nAlexa Skill Account Linking Configuration:" -ForegroundColor Cyan
            Write-Host "=========================================" -ForegroundColor Cyan
            Write-Host "Authorization URL: https://$domain.auth.$REGION.amazoncognito.com/oauth2/authorize" -ForegroundColor Green
            Write-Host "Access Token URL: https://$domain.auth.$REGION.amazoncognito.com/oauth2/token" -ForegroundColor Green
            Write-Host "Client ID: $clientId" -ForegroundColor Green
            Write-Host "Client Secret: $clientSecret" -ForegroundColor Green
            Write-Host "Client Authentication Scheme: HTTP Basic or Credentials in request body" -ForegroundColor Green
            Write-Host "Scope: openid email profile" -ForegroundColor Green
            Write-Host "Domain List: xviper-auth.auth.us-east-1.amazoncognito.com" -ForegroundColor Green
            Write-Host "=========================================" -ForegroundColor Cyan
            
            # Save to file for reference
            $configFile = "alexa_config.txt"
            @"
Alexa Skill Account Linking Configuration:
=========================================
Authorization URL: https://$domain.auth.$REGION.amazoncognito.com/oauth2/authorize
Access Token URL: https://$domain.auth.$REGION.amazoncognito.com/oauth2/token
Client ID: $clientId
Client Secret: $clientSecret
Client Authentication Scheme: HTTP Basic or Credentials in request body
Scope: openid email profile
Domain List: $domain.auth.$REGION.amazoncognito.com
=========================================
"@ | Set-Content $configFile
            
            Write-Host "Configuration saved to $configFile" -ForegroundColor Yellow
            Write-Host "Use these values to configure account linking in the Alexa developer console" -ForegroundColor Yellow
        } else {
            Write-Host "No app clients found for this user pool." -ForegroundColor Red
        }
    } else {
        Write-Host "User pool '$USER_POOL_NAME' not found." -ForegroundColor Red
    }
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}