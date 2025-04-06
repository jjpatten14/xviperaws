# Step 1: Create S3 bucket in us-east-1 and upload deployment package

# HARDCODED REGION
$REGION = "us-east-1"

Write-Host "Creating S3 bucket in $REGION" -ForegroundColor Yellow
Write-Host "====================================================" -ForegroundColor Yellow
Write-Host ""

# Get AWS Account ID
$ACCOUNT_ID = aws sts get-caller-identity --query "Account" --output text --region $REGION
Write-Host "Using AWS Account: $ACCOUNT_ID" -ForegroundColor Cyan

# Set bucket name
$S3_BUCKET = "xviper-code-$ACCOUNT_ID"

Write-Host "Will create S3 bucket: $S3_BUCKET in $REGION" -ForegroundColor Cyan
Write-Host ""

# Create bucket in us-east-1 (special case that doesn't need location constraint)
try {
    # Check if bucket exists
    aws s3api head-bucket --bucket $S3_BUCKET --region $REGION 2>&1 | Out-Null
    Write-Host "Bucket already exists: $S3_BUCKET" -ForegroundColor Green
} catch {
    Write-Host "Creating new bucket: $S3_BUCKET in $REGION" -ForegroundColor Cyan
    aws s3api create-bucket --bucket $S3_BUCKET --region $REGION
    
    # Wait for bucket creation to propagate
    Write-Host "Waiting for bucket creation to propagate..." -ForegroundColor Cyan
    Start-Sleep -Seconds 10
    
    # Verify bucket was created
    try {
        aws s3api head-bucket --bucket $S3_BUCKET --region $REGION
        Write-Host "Bucket created successfully: $S3_BUCKET" -ForegroundColor Green
    } catch {
        Write-Host "ERROR: Failed to create bucket. Exiting." -ForegroundColor Red
        exit 1
    }
}

# Create deployment package
Set-Location -Path "lambda"
Write-Host "Installing dependencies..." -ForegroundColor Cyan
npm install
Write-Host "Creating deployment package..." -ForegroundColor Cyan
if (Test-Path "../deployment.zip") { Remove-Item "../deployment.zip" -Force }
Compress-Archive -Path * -DestinationPath ../deployment.zip -Force
Set-Location -Path ".."

# Upload to S3
Write-Host "Uploading deployment package to S3..." -ForegroundColor Cyan
aws s3 cp deployment.zip "s3://$S3_BUCKET/deployment.zip" --region $REGION

# Verify the file was uploaded
try {
    Write-Host "Verifying upload..." -ForegroundColor Cyan
    $objExists = aws s3api head-object --bucket $S3_BUCKET --key deployment.zip --region $REGION
    Write-Host "Deployment package verified in S3!" -ForegroundColor Green
    
    # List objects in bucket
    Write-Host "Objects in bucket:" -ForegroundColor Cyan
    aws s3 ls "s3://$S3_BUCKET/" --region $REGION
} catch {
    Write-Host "ERROR: Failed to verify deployment package in S3." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

# Save bucket info for next step
$configContent = @"
# S3 Bucket Configuration for Alexa Skill

# CREATED IN REGION: $REGION
S3_BUCKET=$S3_BUCKET
SKILL_ID=amzn1.ask.skill.89b0ef4c-80f9-4e51-89ba-190195199b0b
"@
Set-Content -Path "s3-config.txt" -Value $configContent

Write-Host ""
Write-Host "SUCCESS!" -ForegroundColor Green
Write-Host "S3 bucket created and deployment package uploaded." -ForegroundColor Green
Write-Host "Configuration saved to s3-config.txt" -ForegroundColor Green
Write-Host ""
Write-Host "NEXT STEPS:" -ForegroundColor Cyan
Write-Host "Run 2-create-lambda.ps1 to create the Lambda function" -ForegroundColor Cyan