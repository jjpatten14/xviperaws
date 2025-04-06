# Script to update Cognito app client redirect URLs
$env:AWS_DEFAULT_OUTPUT = 'json'
$REGION = 'us-east-1'
$USER_POOL_NAME = 'XViperUserPool'
$ALEXA_VENDOR_ID = "M2SYY47BAYR6E5"

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
            
            # Get the client details to see current callback URLs
            $clientDetailCmd = "aws cognito-idp describe-user-pool-client --user-pool-id $USER_POOL_ID --client-id $clientId --region $REGION"
            $clientDetailJson = Invoke-Expression $clientDetailCmd
            $clientDetail = $clientDetailJson | ConvertFrom-Json
            
            # Update client settings to add example.com as a callback URL
            Write-Host "Updating callback URLs to include example.com for testing..." -ForegroundColor Yellow
            
            $callbackUrls = "https://pitangui.amazon.com/api/skill/link/$ALEXA_VENDOR_ID,https://layla.amazon.com/api/skill/link/$ALEXA_VENDOR_ID,https://alexa.amazon.com/api/skill/link/$ALEXA_VENDOR_ID,https://alexa.amazon.co.jp/api/skill/link/$ALEXA_VENDOR_ID,https://pitangui.amazon.com/api/skill/link/*,https://layla.amazon.com/api/skill/link/*,https://alexa.amazon.com/api/skill/link/*,https://alexa.amazon.co.jp/api/skill/link/*,https://m.media-amazon.com/images/G/01/mobile-apps/dex/alexa/alexa-skills-kit/callbacks/*,https://d84l1y8p4kdic.cloudfront.net,https://example.com"
            $tokenValidityUnits = '{"RefreshToken":"days","IdToken":"hours","AccessToken":"hours"}'
            
            $updateClientCmd = "aws cognito-idp update-user-pool-client --user-pool-id $USER_POOL_ID --client-id $clientId --client-name $clientName --refresh-token-validity 30 --access-token-validity 1 --id-token-validity 1 --token-validity-units '$tokenValidityUnits' --explicit-auth-flows ALLOW_REFRESH_TOKEN_AUTH ALLOW_USER_PASSWORD_AUTH ALLOW_CUSTOM_AUTH ALLOW_USER_SRP_AUTH --allowed-o-auth-flows code --allowed-o-auth-scopes 'openid email profile' --supported-identity-providers COGNITO --callback-urls '$callbackUrls' --prevent-user-existence-errors ENABLED --region $REGION"
            
            Invoke-Expression $updateClientCmd
            
            Write-Host "Successfully updated callback URLs to include example.com" -ForegroundColor Green
            Write-Host "Please wait 1-2 minutes for changes to propagate, then try the test URL again." -ForegroundColor Cyan
        } else {
            Write-Host "No app clients found for this user pool." -ForegroundColor Red
        }
    } else {
        Write-Host "User pool not found: $USER_POOL_NAME" -ForegroundColor Red
    }
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}