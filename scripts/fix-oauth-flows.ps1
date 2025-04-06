# Fix OAuth flows configuration for Cognito app client
$env:AWS_DEFAULT_OUTPUT = 'json'
$REGION = 'us-east-1'
$USER_POOL_NAME = 'XViperUserPool'

Write-Host "Fixing OAuth flows configuration..." -ForegroundColor Cyan

try {
    # Find the user pool
    $userPoolsCmd = "aws cognito-idp list-user-pools --max-results 60 --region $REGION"
    $userPoolsJson = Invoke-Expression $userPoolsCmd
    $userPools = $userPoolsJson | ConvertFrom-Json
    
    $pool = $userPools.UserPools | Where-Object { $_.Name -eq $USER_POOL_NAME }
    
    if ($pool) {
        $USER_POOL_ID = $pool.Id
        Write-Host "Found user pool: $USER_POOL_ID" -ForegroundColor Green
        
        # Get client info
        $clientsInfoCmd = "aws cognito-idp list-user-pool-clients --user-pool-id $USER_POOL_ID --region $REGION"
        $clientsInfoJson = Invoke-Expression $clientsInfoCmd
        $clientsInfo = $clientsInfoJson | ConvertFrom-Json
        
        if ($clientsInfo.UserPoolClients.Count -gt 0) {
            $clientId = $clientsInfo.UserPoolClients[0].ClientId
            $clientName = $clientsInfo.UserPoolClients[0].ClientName
            
            Write-Host "Found app client: $clientName ($clientId)" -ForegroundColor Green
            
            # Get current client configuration
            $clientDetailCmd = "aws cognito-idp describe-user-pool-client --user-pool-id $USER_POOL_ID --client-id $clientId --region $REGION"
            $clientDetailJson = Invoke-Expression $clientDetailCmd
            $clientDetail = $clientDetailJson | ConvertFrom-Json
            
            Write-Host "Current OAuth configuration:" -ForegroundColor Yellow
            Write-Host "- OAuth Flows: $($clientDetail.UserPoolClient.AllowedOAuthFlows -join ', ')" -ForegroundColor Yellow
            Write-Host "- OAuth Scopes: $($clientDetail.UserPoolClient.AllowedOAuthScopes -join ', ')" -ForegroundColor Yellow
            Write-Host "- Generate Secret: $($clientDetail.UserPoolClient.GenerateSecret)" -ForegroundColor Yellow
            
            # Create files for configuration
            $callbacksFile = Join-Path $pwd "callbacks.json"
            $scopesFile = Join-Path $pwd "scopes.json"
            $oauthFlowsFile = Join-Path $pwd "oauth_flows.json"
            
            # Get existing callback URLs or create default ones
            $callbackUrls = $clientDetail.UserPoolClient.CallbackURLs
            if (!$callbackUrls -or $callbackUrls.Count -eq 0) {
                $callbackUrls = @(
                    "https://example.com",
                    "https://pitangui.amazon.com/api/skill/link/M2SYY47BAYR6E5",
                    "https://layla.amazon.com/api/skill/link/M2SYY47BAYR6E5",
                    "https://alexa.amazon.com/api/skill/link/M2SYY47BAYR6E5",
                    "https://alexa.amazon.co.jp/api/skill/link/M2SYY47BAYR6E5"
                )
            }
            
            # Ensure example.com is in the list
            if (!($callbackUrls -contains "https://example.com")) {
                $callbackUrls += "https://example.com"
            }
            
            # Create OAuth flows
            $oauthFlows = @("code", "implicit")
            
            # Create OAuth scopes
            $scopes = @("openid", "email", "profile")
            
            # Save to files
            ConvertTo-Json $callbackUrls | Set-Content $callbacksFile
            ConvertTo-Json $oauthFlows | Set-Content $oauthFlowsFile
            ConvertTo-Json $scopes | Set-Content $scopesFile
            
            Write-Host "Created configuration files:" -ForegroundColor Yellow
            Write-Host "- Callback URLs: $(Get-Content $callbacksFile)" -ForegroundColor Yellow
            Write-Host "- OAuth Flows: $(Get-Content $oauthFlowsFile)" -ForegroundColor Yellow
            Write-Host "- OAuth Scopes: $(Get-Content $scopesFile)" -ForegroundColor Yellow
            
            Write-Host "Updating OAuth configuration..." -ForegroundColor Yellow
            
            # Update the app client with OAuth flows enabled
            $updateClientCmd = "aws cognito-idp update-user-pool-client --user-pool-id $USER_POOL_ID --client-id $clientId --callback-urls file://$callbacksFile --allowed-o-auth-flows file://$oauthFlowsFile --allowed-o-auth-flows-user-pool-client --allowed-o-auth-scopes file://$scopesFile --supported-identity-providers COGNITO --explicit-auth-flows ALLOW_REFRESH_TOKEN_AUTH ALLOW_USER_PASSWORD_AUTH ALLOW_CUSTOM_AUTH ALLOW_USER_SRP_AUTH --region $REGION"
            
            Invoke-Expression $updateClientCmd | Out-Null
            
            Write-Host "OAuth configuration updated successfully!" -ForegroundColor Green
            
            # Clean up
            Remove-Item $callbacksFile -Force
            Remove-Item $oauthFlowsFile -Force
            Remove-Item $scopesFile -Force
            
            # Get domain info
            $poolInfoCmd = "aws cognito-idp describe-user-pool --user-pool-id $USER_POOL_ID --region $REGION"
            $poolInfoJson = Invoke-Expression $poolInfoCmd
            $poolInfo = $poolInfoJson | ConvertFrom-Json
            $domain = $poolInfo.UserPool.Domain
            
            # Generate test URL
            $testUrl = "https://$domain.auth.$REGION.amazoncognito.com/login?client_id=$clientId&response_type=code&scope=openid+email+profile&redirect_uri=https://example.com"
            
            Write-Host "Test URL:" -ForegroundColor Cyan
            Write-Host $testUrl -ForegroundColor Cyan
            
            $openBrowser = Read-Host "Would you like to open the test URL in your browser? (y/n)"
            if ($openBrowser -eq "y" -or $openBrowser -eq "Y") {
                Start-Process $testUrl
            }
        } else {
            Write-Host "No app clients found for this user pool." -ForegroundColor Red
        }
    } else {
        Write-Host "User pool '$USER_POOL_NAME' not found." -ForegroundColor Red
    }
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}