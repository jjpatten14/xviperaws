# Step 2: Deploy Alexa skill
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
        if ($key -eq "DYNAMODB_TABLE") { $DYNAMODB_TABLE = $value }
        if ($key -eq "STACK_NAME") { $STACK_NAME = $value }
        if ($key -eq "SKILL_ID") { $SKILL_ID = $value }
    }
} else {
    Write-Host "Error: config.txt not found. Please run 1-init-resources.ps1 first." -ForegroundColor Red
    exit 1
}

# Check if Skill ID is set
if (-not $SKILL_ID) {
    Write-Host "Error: SKILL_ID is not set in config.txt" -ForegroundColor Red
    Write-Host "Please create your Alexa skill in the Alexa Developer Console first," -ForegroundColor Red
    Write-Host "then add the Skill ID to config.txt and run this script again." -ForegroundColor Red
    exit 1
}

# Update skill.json with real values
Write-Host "Updating skill.json with actual values..." -ForegroundColor Cyan
$skillJson = Get-Content -Path "skill.json" -Raw
$skillJson = $skillJson -replace "arn:aws:lambda:us-east-1:XXXXXXXXXXXX:function:xviper-alexa-skill", $LAMBDA_ARN
Set-Content -Path "skill.json" -Value $skillJson

# Update sample-event.json with Skill ID
Write-Host "Updating sample-event.json with Skill ID..." -ForegroundColor Cyan
$sampleEvent = Get-Content -Path "sample-event.json" -Raw
$sampleEvent = $sampleEvent -replace "amzn1.ask.skill.12345678-1234-1234-1234-123456789012", $SKILL_ID
Set-Content -Path "sample-event.json" -Value $sampleEvent

# Get AWS account ID for the Lambda permission
$ACCOUNT_ID = aws sts get-caller-identity --query "Account" --output text

# Extract Lambda function name from ARN
$LAMBDA_FUNCTION_NAME = $LAMBDA_ARN -split ":" | Select-Object -Last 1

# Add Lambda permission for Alexa Skill
Write-Host "Setting up Alexa Skills Kit trigger for Lambda function..." -ForegroundColor Cyan
try {
    aws lambda add-permission `
        --function-name $LAMBDA_FUNCTION_NAME `
        --statement-id AlexaSkillKit `
        --action lambda:InvokeFunction `
        --principal alexa-appkit.amazon.com `
        --event-source-token "$SKILL_ID" `
        --region $AWS_REGION
    
    Write-Host "Lambda permission added successfully." -ForegroundColor Green
} catch {
    Write-Host "Warning: Lambda permission may already exist or there was an error." -ForegroundColor Yellow
    Write-Host $_.Exception.Message -ForegroundColor Yellow
}

# Create directories for Alexa CLI if needed
if (-not (Test-Path ".ask")) {
    New-Item -Path ".ask" -ItemType Directory | Out-Null
}

# Generate Alexa CLI config
$askConfig = @"
{
  "deploy_settings": {
    "default": {
      "skill_id": "$SKILL_ID",
      "resources": {
        "lambda": [
          {
            "alexaUsage": [
              "custom/default"
            ],
            "arn": "$LAMBDA_ARN",
            "awsRegion": "$AWS_REGION",
            "runtime": "nodejs16.x"
          }
        ],
        "manifest": {
          "eTag": ""
        },
        "interactionModel": {
          "en-US": {
            "eTag": ""
          }
        }
      }
    }
  }
}
"@
Set-Content -Path ".ask/config" -Value $askConfig

Write-Host "Alexa skill configuration updated." -ForegroundColor Green
Write-Host ""
Write-Host "NEXT STEPS:" -ForegroundColor Cyan
Write-Host "1. Go to the Alexa Developer Console: https://developer.amazon.com/alexa/console/ask" -ForegroundColor Cyan
Write-Host "2. Open your skill with ID: $SKILL_ID" -ForegroundColor Cyan
Write-Host "3. Under 'Interaction Model' > 'JSON Editor', upload the file models/en-US.json" -ForegroundColor Cyan
Write-Host "4. Click 'Save Model' and then 'Build Model'" -ForegroundColor Cyan
Write-Host "5. Under 'Endpoint', select 'AWS Lambda ARN' and paste this ARN: $LAMBDA_ARN" -ForegroundColor Cyan
Write-Host "6. Click 'Save Endpoints'" -ForegroundColor Cyan
Write-Host "7. Test your skill by saying 'Alexa, ask X Viper to lock my car'" -ForegroundColor Cyan
Write-Host ""
Write-Host "Note: Before you can use the skill, you will need to link your Viper account." -ForegroundColor Yellow
Write-Host "You'll be prompted to set this up the first time you use the skill." -ForegroundColor Yellow