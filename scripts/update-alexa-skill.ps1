# Update Alexa skill account linking configuration
$env:AWS_DEFAULT_OUTPUT = 'json'
$REGION = 'us-east-1'
$USER_POOL_NAME = 'XViperUserPool'
$SKILL_ID = "amzn1.ask.skill.89b0ef4c-80f9-4e51-89ba-190195199b0b"

Write-Host "Updating Alexa skill account linking configuration..." -ForegroundColor Cyan

# First, check if ASK CLI is installed and configured
$askCliInstalled = $false
try {
    $askVersion = Invoke-Expression "ask --version" 2>&1
    if ($askVersion -match "\d+\.\d+\.\d+") {
        $askCliInstalled = $true
        Write-Host "ASK CLI detected: $askVersion" -ForegroundColor Green
    } else {
        Write-Host "ASK CLI not properly installed or not in PATH" -ForegroundColor Red
    }
} catch {
    Write-Host "ASK CLI not installed. Automatic Alexa skill updating not available." -ForegroundColor Red
}

if (-not $askCliInstalled) {
    Write-Host "`nASK CLI is required for automatic skill updates." -ForegroundColor Red
    Write-Host "Please install it using: npm install -g ask-cli" -ForegroundColor Yellow
    Write-Host "Then run: ask init" -ForegroundColor Yellow
    Write-Host "`nAlternatively, update the skill manually using the Alexa developer console." -ForegroundColor Yellow
    exit 1
}

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
    
    # Get the app client info
    $clientsInfoCmd = "aws cognito-idp list-user-pool-clients --user-pool-id $USER_POOL_ID --region $REGION"
    $clientsInfoJson = Invoke-Expression $clientsInfoCmd
    $clientsInfo = $clientsInfoJson | ConvertFrom-Json
    
    if ($clientsInfo.UserPoolClients.Count -gt 0) {
        # Use the most recently created app client
        $mostRecentClient = $clientsInfo.UserPoolClients | Sort-Object -Property LastModifiedDate -Descending | Select-Object -First 1
        $CLIENT_ID = $mostRecentClient.ClientId
        
        Write-Host "Using app client: $($mostRecentClient.ClientName) ($CLIENT_ID)" -ForegroundColor Green
        
        # Get client details to get secret
        $clientDetailCmd = "aws cognito-idp describe-user-pool-client --user-pool-id $USER_POOL_ID --client-id $CLIENT_ID --region $REGION"
        $clientDetailJson = Invoke-Expression $clientDetailCmd
        $clientDetail = $clientDetailJson | ConvertFrom-Json
        $CLIENT_SECRET = $clientDetail.UserPoolClient.ClientSecret
        
        # Create account linking configuration file
        $accountLinkingJson = @"
{
  "accountLinkingRequest": {
    "skipOnEnablement": false,
    "type": "AUTH_CODE",
    "authorizationUrl": "https://$domain.auth.$REGION.amazoncognito.com/oauth2/authorize",
    "accessTokenUrl": "https://$domain.auth.$REGION.amazoncognito.com/oauth2/token",
    "clientId": "$CLIENT_ID",
    "scopes": ["openid", "email", "profile"],
    "accessTokenScheme": "HTTP_BASIC",
    "clientSecret": "$CLIENT_SECRET",
    "domains": ["amazoncognito.com", "$domain.auth.$REGION.amazoncognito.com"]
  }
}
"@
        
        $accountLinkingFile = "account_linking.json"
        Set-Content -Path $accountLinkingFile -Value $accountLinkingJson
        
        Write-Host "Created account linking configuration:" -ForegroundColor Yellow
        Write-Host "Authorization URL: https://$domain.auth.$REGION.amazoncognito.com/oauth2/authorize" -ForegroundColor Yellow
        Write-Host "Access Token URL: https://$domain.auth.$REGION.amazoncognito.com/oauth2/token" -ForegroundColor Yellow
        Write-Host "Client ID: $CLIENT_ID" -ForegroundColor Yellow
        Write-Host "Client Secret: $CLIENT_SECRET" -ForegroundColor Yellow
        
        # Update the skill using ASK CLI
        Write-Host "`nUpdating Alexa skill account linking configuration..." -ForegroundColor Cyan
        $updateCmd = "ask api update-account-linking -s $SKILL_ID -f $accountLinkingFile"
        $updateResult = Invoke-Expression $updateCmd
        
        # Remove file
        Remove-Item $accountLinkingFile -Force
        
        Write-Host "`nAlexa skill account linking configuration updated!" -ForegroundColor Green
        Write-Host "`nNext steps:" -ForegroundColor Cyan
        Write-Host "1. Open the Alexa app" -ForegroundColor Cyan
        Write-Host "2. Disable the skill if currently enabled" -ForegroundColor Cyan
        Write-Host "3. Enable it again to start account linking" -ForegroundColor Cyan
        Write-Host "4. Sign in with your Cognito credentials" -ForegroundColor Cyan
    } else {
        Write-Host "No app clients found for this user pool." -ForegroundColor Red
    }
} else {
    Write-Host "User pool '$USER_POOL_NAME' not found." -ForegroundColor Red
}