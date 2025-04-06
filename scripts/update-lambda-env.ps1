# Simple script to update Lambda environment variables
$env:AWS_DEFAULT_OUTPUT = 'json'
$REGION = 'us-east-1'
$LAMBDA_FUNCTION_NAME = 'xviper-alexa-skill'
$USER_POOL_NAME = 'XViperUserPool'
$DYNAMODB_TABLE = 'XviperUserMappings'

Write-Host "Updating Lambda environment variables..." -ForegroundColor Cyan

# Find the user pool ID
$userPoolsCmd = "aws cognito-idp list-user-pools --max-results 60 --region $REGION"
$userPoolsJson = Invoke-Expression $userPoolsCmd
$userPools = $userPoolsJson | ConvertFrom-Json

$pool = $userPools.UserPools | Where-Object { $_.Name -eq $USER_POOL_NAME }
$USER_POOL_ID = ""

if ($pool) {
    $USER_POOL_ID = $pool.Id
    Write-Host "Found user pool: $USER_POOL_ID" -ForegroundColor Green
} else {
    Write-Host "User pool '$USER_POOL_NAME' not found." -ForegroundColor Red
    exit 1
}

# Create JSON file for environment variables
$envVars = @{
    "Variables" = @{
        "COGNITO_USER_POOL_ID" = $USER_POOL_ID
        "USER_MAPPING_TABLE" = $DYNAMODB_TABLE
    }
}

$envVarsJson = ConvertTo-Json $envVars

# Save to file
$envFile = "lambda_env.json"
Set-Content -Path $envFile -Value $envVarsJson

Write-Host "Environment variables to set:" -ForegroundColor Yellow
Write-Host "COGNITO_USER_POOL_ID: $USER_POOL_ID" -ForegroundColor Yellow
Write-Host "USER_MAPPING_TABLE: $DYNAMODB_TABLE" -ForegroundColor Yellow

# Update Lambda configuration
$updateCmd = "aws lambda update-function-configuration --function-name $LAMBDA_FUNCTION_NAME --environment file://$envFile --region $REGION"
Write-Host "Running command: $updateCmd" -ForegroundColor Yellow

try {
    Invoke-Expression $updateCmd
    Write-Host "Lambda environment variables updated successfully!" -ForegroundColor Green
} catch {
    Write-Host "Error updating Lambda environment variables: $($_.Exception.Message)" -ForegroundColor Red
}

# Clean up
Remove-Item -Path $envFile -Force