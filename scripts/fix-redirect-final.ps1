# Script to fix Cognito redirect URL with precise formatting - final version
$env:AWS_DEFAULT_OUTPUT = 'json'
$REGION = 'us-east-1'
$USER_POOL_NAME = 'XViperUserPool'

Write-Host "Looking for Cognito user pool: $USER_POOL_NAME" -ForegroundColor Cyan

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
            
            # Show existing callback URLs and configuration
            $clientDetailCmd = "aws cognito-idp describe-user-pool-client --user-pool-id $USER_POOL_ID --client-id $clientId --region $REGION"
            $clientDetailJson = Invoke-Expression $clientDetailCmd
            $clientDetail = $clientDetailJson | ConvertFrom-Json
            
            # Get existing values to preserve
            $refreshTokenValidity = $clientDetail.UserPoolClient.RefreshTokenValidity
            $accessTokenValidity = $clientDetail.UserPoolClient.AccessTokenValidity
            $idTokenValidity = $clientDetail.UserPoolClient.IdTokenValidity
            $authFlows = $clientDetail.UserPoolClient.ExplicitAuthFlows -join " "
            
            # Save existing callback URLs to array and add example.com
            $callbackUrls = $clientDetail.UserPoolClient.CallbackURLs
            if ($callbackUrls -notcontains "https://example.com") {
                $callbackUrls += "https://example.com"
            }
            
            Write-Host "Current callback URLs:" -ForegroundColor Yellow
            foreach ($url in $callbackUrls) {
                Write-Host "  - $url" -ForegroundColor Yellow
            }
            
            # Create a temp file with exact JSON structure
            $callbacksFile = [System.IO.Path]::GetTempFileName()
            $callbackUrlsJson = ConvertTo-Json $callbackUrls
            Set-Content -Path $callbacksFile -Value $callbackUrlsJson
            
            # Create temp file for OAuth scopes
            $scopesFile = [System.IO.Path]::GetTempFileName()
            $scopesArray = @("openid", "email", "profile")
            $scopesJson = ConvertTo-Json $scopesArray
            Set-Content -Path $scopesFile -Value $scopesJson
            
            Write-Host "Updating callback URLs and OAuth configuration..." -ForegroundColor Yellow
            
            # Update client settings with callback URLs and other settings
            $updateCmd = "aws cognito-idp update-user-pool-client --user-pool-id $USER_POOL_ID --client-id $clientId --client-name $clientName --callback-urls file://$callbacksFile --allowed-o-auth-flows code --allowed-o-auth-scopes file://$scopesFile --supported-identity-providers COGNITO --explicit-auth-flows $authFlows --refresh-token-validity $refreshTokenValidity --region $REGION"
            
            if ($accessTokenValidity) {
                $updateCmd += " --access-token-validity $accessTokenValidity"
            }
            if ($idTokenValidity) {
                $updateCmd += " --id-token-validity $idTokenValidity" 
            }
            
            Invoke-Expression $updateCmd
            
            # Clean up temp files
            Remove-Item -Path $callbacksFile -Force
            Remove-Item -Path $scopesFile -Force
            
            Write-Host "Successfully updated client configuration" -ForegroundColor Green
            Write-Host "Added 'https://example.com' as an allowed callback URL" -ForegroundColor Green
            Write-Host "Please wait 1-2 minutes for changes to propagate." -ForegroundColor Cyan
            
            # Create test URL
            $domain = $poolInfo.UserPool.Domain
            $testUrl = "https://$domain.auth.$REGION.amazoncognito.com/login?client_id=$clientId&response_type=code&scope=openid+email+profile&redirect_uri=https://example.com"
            
            Write-Host "" 
            Write-Host "After waiting, try this exact URL:" -ForegroundColor Cyan
            Write-Host $testUrl -ForegroundColor Cyan
        } else {
            Write-Host "No app clients found for this user pool." -ForegroundColor Red
        }
    } else {
        Write-Host "User pool not found: $USER_POOL_NAME" -ForegroundColor Red
    }
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}