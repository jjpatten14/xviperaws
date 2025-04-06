# Script to fix Cognito redirect URL with precise formatting
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
            
            # Show existing callback URLs
            $clientDetailCmd = "aws cognito-idp describe-user-pool-client --user-pool-id $USER_POOL_ID --client-id $clientId --region $REGION"
            $clientDetailJson = Invoke-Expression $clientDetailCmd
            $clientDetail = $clientDetailJson | ConvertFrom-Json
            
            if ($clientDetail.UserPoolClient.CallbackURLs) {
                Write-Host "Current callback URLs:" -ForegroundColor Yellow
                foreach ($url in $clientDetail.UserPoolClient.CallbackURLs) {
                    Write-Host "  - $url" -ForegroundColor Yellow
                }
            } else {
                Write-Host "No callback URLs currently set" -ForegroundColor Yellow
            }
            
            # Create a temp file with exact JSON structure
            $tempFile = [System.IO.Path]::GetTempFileName()
            
            # Create the callback URL array with precise JSON format
            $callbackUrlsJson = @"
[
  "https://pitangui.amazon.com/api/skill/link/M2SYY47BAYR6E5",
  "https://layla.amazon.com/api/skill/link/M2SYY47BAYR6E5",
  "https://alexa.amazon.com/api/skill/link/M2SYY47BAYR6E5",
  "https://alexa.amazon.co.jp/api/skill/link/M2SYY47BAYR6E5",
  "https://pitangui.amazon.com/api/skill/link/*",
  "https://layla.amazon.com/api/skill/link/*",
  "https://alexa.amazon.com/api/skill/link/*",
  "https://alexa.amazon.co.jp/api/skill/link/*",
  "https://m.media-amazon.com/images/G/01/mobile-apps/dex/alexa/alexa-skills-kit/callbacks/*",
  "https://d84l1y8p4kdic.cloudfront.net",
  "https://example.com"
]
"@
            Set-Content -Path $tempFile -Value $callbackUrlsJson
            
            Write-Host "Updating callback URLs with precise JSON formatting..." -ForegroundColor Yellow
            
            # Update the client with callback URLs from the file
            $updateCmd = "aws cognito-idp update-user-pool-client --user-pool-id $USER_POOL_ID --client-id $clientId --callback-urls file://$tempFile --allowed-o-auth-flows code --allowed-o-auth-scopes 'openid email profile' --supported-identity-providers COGNITO --explicit-auth-flows ALLOW_REFRESH_TOKEN_AUTH ALLOW_USER_PASSWORD_AUTH ALLOW_CUSTOM_AUTH ALLOW_USER_SRP_AUTH --region $REGION"
            Invoke-Expression $updateCmd
            
            # Clean up the temp file
            Remove-Item -Path $tempFile -Force
            
            Write-Host "Successfully updated callback URLs" -ForegroundColor Green
            Write-Host "Added 'https://example.com' as an allowed callback URL" -ForegroundColor Green
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