# Script to fix Lambda dependencies and redeploy

# Configuration
$REGION = 'us-east-1'
$S3_BUCKET = 'xviper-us-east1-965239903867'
$LAMBDA_FUNCTION_NAME = 'xviper-alexa-skill'

Write-Host "Fixing Lambda dependencies for $LAMBDA_FUNCTION_NAME..." -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host ""

# Create a temporary working directory
$workDir = "lambda-fix"
if (Test-Path $workDir) {
    Remove-Item -Path $workDir -Recurse -Force
}
New-Item -ItemType Directory -Path $workDir | Out-Null

# Copy lambda files to the working directory
Copy-Item -Path "lambda\*" -Destination $workDir -Recurse

# Ensure package.json has all required dependencies
$packageJsonPath = "$workDir\package.json"
$packageJson = Get-Content -Path $packageJsonPath -Raw | ConvertFrom-Json

# Check if dependencies exist
$dependencies = $packageJson.dependencies
if (-not $dependencies) {
    $dependencies = @{}
    $packageJson | Add-Member -MemberType NoteProperty -Name "dependencies" -Value $dependencies
}

# Make sure required dependencies are included
$requiredDeps = @{
    "ask-sdk-core" = "^2.14.0"
    "ask-sdk-model" = "^1.39.0"
    "axios" = "^1.6.0"
    "aws-sdk" = "^2.1502.0"
}

foreach ($dep in $requiredDeps.GetEnumerator()) {
    if (-not $dependencies.($dep.Key)) {
        $dependencies | Add-Member -MemberType NoteProperty -Name $dep.Key -Value $dep.Value
        Write-Host "Added missing dependency: $($dep.Key): $($dep.Value)" -ForegroundColor Yellow
    }
}

# Save updated package.json
$packageJson | ConvertTo-Json | Set-Content -Path $packageJsonPath

# Install dependencies
Write-Host "Installing dependencies..." -ForegroundColor Cyan
Set-Location -Path $workDir
Invoke-Expression "npm install --production"

# Create deployment package
Write-Host "Creating deployment package..." -ForegroundColor Cyan
if (Test-Path "../deployment-fixed.zip") {
    Remove-Item "../deployment-fixed.zip" -Force
}

# Using 7zip for better handling of node_modules
$use7zip = $false

try {
    # Check if 7zip is available
    $7zipPath = "C:\Program Files\7-Zip\7z.exe"
    if (Test-Path $7zipPath) {
        $use7zip = $true
        Write-Host "Using 7-Zip for packaging..." -ForegroundColor Green
        Set-Alias -Name 7z -Value $7zipPath
        & 7z a -r "../deployment-fixed.zip" *
    } else {
        throw "7-Zip not found"
    }
} catch {
    Write-Host "Using PowerShell Compress-Archive..." -ForegroundColor Yellow
    Compress-Archive -Path * -DestinationPath "../deployment-fixed.zip" -Force
}

# Return to original directory
Set-Location -Path ".."

# Upload to S3
Write-Host "Uploading updated deployment package to S3..." -ForegroundColor Cyan
$uploadCmd = "aws s3 cp deployment-fixed.zip s3://$S3_BUCKET/deployment-fixed.zip --region $REGION"
Invoke-Expression $uploadCmd

# Update Lambda function code
Write-Host "Updating Lambda function code..." -ForegroundColor Cyan
$updateFunctionCmd = "aws lambda update-function-code --function-name $LAMBDA_FUNCTION_NAME --s3-bucket $S3_BUCKET --s3-key deployment-fixed.zip --region $REGION"
Invoke-Expression $updateFunctionCmd

# Wait for Lambda update to complete
Write-Host "Waiting for Lambda update to complete..." -ForegroundColor Cyan
Start-Sleep -Seconds 5
$getFunctionCmd = "aws lambda get-function --function-name $LAMBDA_FUNCTION_NAME --region $REGION"
$function = Invoke-Expression $getFunctionCmd

Write-Host ""
Write-Host "Lambda function updated successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "NEXT STEPS:" -ForegroundColor Cyan
Write-Host "1. Test your Alexa skill again in the Alexa Developer Console" -ForegroundColor Cyan
Write-Host "2. If it still fails, check the CloudWatch logs for errors" -ForegroundColor Cyan