# Step 3: Update Lambda function code after making changes
# PowerShell Script for Windows compatibility

# Load configuration
if (Test-Path "config.txt") {
    $configContent = Get-Content -Path "config.txt" -Raw
    $configLines = $configContent -split "`n" | Where-Object { $_ -match "^[^#].*=.*" }
    
    foreach ($line in $configLines) {
        $parts = $line -split "=", 2
        $key = $parts[0].Trim()
        $value = $parts[1].Trim()
        
        # Set variables based on key
        if ($key -eq "AWS_REGION") { $AWS_REGION = $value }
        if ($key -eq "S3_BUCKET") { $S3_BUCKET = $value }
        if ($key -eq "LAMBDA_ARN") { $LAMBDA_ARN = $value }
    }
} else {
    Write-Host "Error: config.txt not found. Please run 1-init-resources.ps1 first." -ForegroundColor Red
    exit 1
}

# Move to the lambda directory
Set-Location -Path "lambda"

# Install dependencies
Write-Host "Installing dependencies..." -ForegroundColor Cyan
npm install

# Create a ZIP file for deployment
Write-Host "Creating updated deployment package..." -ForegroundColor Cyan
Compress-Archive -Path * -DestinationPath ../deployment.zip -Force

# Go back to parent directory
Set-Location -Path ".."

# Upload to S3
Write-Host "Uploading updated deployment package to S3..." -ForegroundColor Cyan
aws s3 cp deployment.zip "s3://$S3_BUCKET/deployment.zip"

# Get Lambda function name from ARN
$LAMBDA_FUNCTION_NAME = $LAMBDA_ARN -split ":" | Select-Object -Last 1

# Update Lambda function code
Write-Host "Updating Lambda function code..." -ForegroundColor Cyan
aws lambda update-function-code `
    --function-name $LAMBDA_FUNCTION_NAME `
    --s3-bucket $S3_BUCKET `
    --s3-key deployment.zip `
    --region $AWS_REGION

# Clean up
Remove-Item -Path deployment.zip

Write-Host "Lambda function updated successfully!" -ForegroundColor Green
Write-Host "You can test it in the AWS Lambda console or with Alexa." -ForegroundColor Cyan