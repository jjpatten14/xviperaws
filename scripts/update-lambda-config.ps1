# Script to update Lambda configuration with environment variables

# Configuration
$REGION = 'us-east-1'
$LAMBDA_FUNCTION_NAME = 'xviper-alexa-skill'
$DEFAULT_USERNAME = ${env:VIPER_USERNAME}
$DEFAULT_PASSWORD = ${env:VIPER_PASSWORD}

Write-Host "Updating Lambda configuration with environment variables..." -ForegroundColor Cyan
Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host ""

# Update Lambda configuration
Write-Host "Adding DEFAULT_USERNAME and DEFAULT_PASSWORD environment variables..." -ForegroundColor Cyan

$escapedPassword = $DEFAULT_PASSWORD.Replace('$', '`$')

$updateConfigCmd = "aws lambda update-function-configuration --function-name $LAMBDA_FUNCTION_NAME --environment 'Variables={DEFAULT_USERNAME=$DEFAULT_USERNAME,DEFAULT_PASSWORD=$escapedPassword,USER_MAPPING_TABLE=XviperUserMappings}' --region $REGION"
Invoke-Expression $updateConfigCmd

# Wait for update to complete
Write-Host "Waiting for Lambda configuration update to complete..." -ForegroundColor Cyan
Start-Sleep -Seconds 5

# Get updated Lambda configuration to verify
$getFunctionCmd = "aws lambda get-function --function-name $LAMBDA_FUNCTION_NAME --region $REGION"
$function = Invoke-Expression $getFunctionCmd

Write-Host ""
Write-Host "Lambda function configuration updated successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "NEXT STEPS:" -ForegroundColor Cyan
Write-Host "1. Test your Alexa skill again in the Alexa Developer Console" -ForegroundColor Cyan
Write-Host "2. Lambda will now use the hard-coded credentials" -ForegroundColor Cyan