# Script to find and delete problematic Cognito domains
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
        
        # Get domain info
        $domainInfoCmd = "aws cognito-idp describe-user-pool --user-pool-id $USER_POOL_ID --region $REGION"
        $domainInfoJson = Invoke-Expression $domainInfoCmd
        $domainInfo = $domainInfoJson | ConvertFrom-Json
        
        $existingDomain = $domainInfo.UserPool.Domain
        
        if ($existingDomain) {
            Write-Host "Found domain: $existingDomain" -ForegroundColor Yellow
            Write-Host "Deleting domain..." -ForegroundColor Yellow
            
            $deleteDomainCmd = "aws cognito-idp delete-user-pool-domain --domain $existingDomain --user-pool-id $USER_POOL_ID --region $REGION"
            Invoke-Expression $deleteDomainCmd
            
            Write-Host "Domain deletion initiated. Waiting for it to complete..." -ForegroundColor Yellow
            Start-Sleep -Seconds 10
            
            # Verify domain was deleted
            $verifyInfoCmd = "aws cognito-idp describe-user-pool --user-pool-id $USER_POOL_ID --region $REGION"
            $verifyInfoJson = Invoke-Expression $verifyInfoCmd
            $verifyInfo = $verifyInfoJson | ConvertFrom-Json
            
            if (-not $verifyInfo.UserPool.Domain) {
                Write-Host "Domain successfully deleted!" -ForegroundColor Green
            } else {
                Write-Host "Domain still exists. It may take more time to delete." -ForegroundColor Yellow
                Write-Host "Continuing anyway, but you may need to delete it manually if the script fails." -ForegroundColor Yellow
            }
        } else {
            Write-Host "No existing domain found. Nothing to delete." -ForegroundColor Green
        }
    } else {
        Write-Host "User pool $USER_POOL_NAME not found. Nothing to delete." -ForegroundColor Yellow
    }
} catch {
    Write-Host "Error occurred while trying to delete Cognito domain:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host "You may need to delete the domain manually from the AWS Console." -ForegroundColor Red
}

Write-Host "Domain cleanup process complete." -ForegroundColor Cyan