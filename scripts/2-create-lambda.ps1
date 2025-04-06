# Step 2: Create CloudFormation stack with Lambda function in us-east-1
# This script should be run AFTER 1-create-bucket.ps1

# HARDCODED REGION
$REGION = "us-east-1"

Write-Host "Creating Lambda function in $REGION" -ForegroundColor Yellow
Write-Host "====================================================" -ForegroundColor Yellow
Write-Host ""

# Read S3 bucket name from config
if (-not (Test-Path "s3-config.txt")) {
    Write-Host "ERROR: s3-config.txt not found." -ForegroundColor Red
    Write-Host "Please run 1-create-bucket.ps1 first!" -ForegroundColor Red
    exit 1
}

# Parse config file for S3 bucket name and skill ID
$S3_BUCKET = ""
$SKILL_ID = ""

Get-Content "s3-config.txt" | ForEach-Object {
    if ($_ -match "S3_BUCKET=(.*)") {
        $S3_BUCKET = $matches[1]
    }
    if ($_ -match "SKILL_ID=(.*)") {
        $SKILL_ID = $matches[1]
    }
}

if (-not $S3_BUCKET) {
    Write-Host "ERROR: Could not find S3_BUCKET in s3-config.txt" -ForegroundColor Red
    exit 1
}

Write-Host "Using S3 bucket: $S3_BUCKET in $REGION" -ForegroundColor Cyan

# Verify bucket exists and has deployment.zip
try {
    Write-Host "Verifying S3 bucket and deployment package..." -ForegroundColor Cyan
    aws s3api head-bucket --bucket $S3_BUCKET --region $REGION
    aws s3api head-object --bucket $S3_BUCKET --key deployment.zip --region $REGION
    Write-Host "Verification successful!" -ForegroundColor Green
} catch {
    Write-Host "ERROR: S3 bucket or deployment package not found." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

# Get AWS Account ID
$ACCOUNT_ID = aws sts get-caller-identity --query "Account" --output text --region $REGION
Write-Host "Using AWS Account: $ACCOUNT_ID" -ForegroundColor Cyan

# Set stack name
$STACK_NAME = "xviper-stack-east1"
Write-Host "Will create CloudFormation stack: $STACK_NAME in $REGION" -ForegroundColor Cyan
Write-Host ""

# Create CloudFormation template for lambda function
$cloudFormationContent = @"
AWSTemplateFormatVersion: '2010-09-09'
Description: 'CloudFormation template for X Viper Alexa Skill in us-east-1'

Resources:
  # DynamoDB Table for User Mappings
  XviperUserMappings:
    Type: AWS::DynamoDB::Table
    Properties:
      TableName: XviperUserMappings
      BillingMode: PAY_PER_REQUEST
      AttributeDefinitions:
        - AttributeName: alexaUserId
          AttributeType: S
      KeySchema:
        - AttributeName: alexaUserId
          KeyType: HASH
      SSESpecification:
        SSEEnabled: true

  # IAM Role for Lambda Function
  LambdaExecutionRole:
    Type: AWS::IAM::Role
    Properties:
      RoleName: lambda-xviper-role
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: lambda.amazonaws.com
            Action: sts:AssumeRole
      ManagedPolicyArns:
        - arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
      Policies:
        - PolicyName: XviperLambdaPolicy
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - dynamodb:GetItem
                  - dynamodb:PutItem
                  - dynamodb:UpdateItem
                  - dynamodb:Query
                Resource: !GetAtt XviperUserMappings.Arn
              - Effect: Allow
                Action:
                  - secretsmanager:CreateSecret
                  - secretsmanager:GetSecretValue
                  - secretsmanager:UpdateSecret
                Resource: '*'

  # Lambda Function
  XviperAlexaSkillFunction:
    Type: AWS::Lambda::Function
    DependsOn: 
      - LambdaExecutionRole
    Properties:
      FunctionName: xviper-alexa-skill
      Handler: index.handler
      Role: !GetAtt LambdaExecutionRole.Arn
      Code:
        S3Bucket: $S3_BUCKET
        S3Key: deployment.zip
      Runtime: nodejs16.x
      Timeout: 10
      MemorySize: 256
      Environment:
        Variables:
          USER_MAPPING_TABLE: !Ref XviperUserMappings

Outputs:
  LambdaFunctionArn:
    Description: ARN of the Lambda function
    Value: !GetAtt XviperAlexaSkillFunction.Arn
  
  DynamoDBTableName:
    Description: Name of the DynamoDB table
    Value: !Ref XviperUserMappings
  
  S3BucketName:
    Description: Name of the S3 bucket for Lambda code
    Value: $S3_BUCKET
"@

# Write CloudFormation template to file
Set-Content -Path "cloudformation-east1.yaml" -Value $cloudFormationContent

# Deploy CloudFormation stack
Write-Host "Deploying CloudFormation stack in $REGION..." -ForegroundColor Cyan
aws cloudformation create-stack `
    --stack-name $STACK_NAME `
    --template-body file://cloudformation-east1.yaml `
    --capabilities CAPABILITY_NAMED_IAM `
    --region $REGION

Write-Host "Waiting for CloudFormation stack creation to complete..." -ForegroundColor Cyan
Write-Host "This may take a few minutes..." -ForegroundColor Yellow
aws cloudformation wait stack-create-complete --stack-name $STACK_NAME --region $REGION

if ($LASTEXITCODE -eq 0) {
    Write-Host "CloudFormation stack created successfully in $REGION" -ForegroundColor Green
    
    # Get outputs from CloudFormation
    Write-Host "Retrieving resource information..." -ForegroundColor Cyan
    
    $LAMBDA_ARN = aws cloudformation describe-stacks --stack-name $STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='LambdaFunctionArn'].OutputValue" --output text --region $REGION
    $DYNAMODB_TABLE = aws cloudformation describe-stacks --stack-name $STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='DynamoDBTableName'].OutputValue" --output text --region $REGION
    
    Write-Host "Resources created in $REGION" -ForegroundColor Green
    Write-Host "Lambda Function ARN: $LAMBDA_ARN" -ForegroundColor Green
    Write-Host "DynamoDB Table: $DYNAMODB_TABLE" -ForegroundColor Green
    Write-Host "S3 Bucket: $S3_BUCKET" -ForegroundColor Green
    
    # Save outputs to config file for next steps
    $configContent = @"
# X Viper Alexa Skill Configuration

# AWS Configuration
AWS_REGION=$REGION
S3_BUCKET=$S3_BUCKET
LAMBDA_ARN=$LAMBDA_ARN
DYNAMODB_TABLE=$DYNAMODB_TABLE
STACK_NAME=$STACK_NAME

# Alexa Skill Configuration
SKILL_ID=$SKILL_ID

# Note: This file was created for us-east-1 region
"@
    Set-Content -Path "config-east1.txt" -Value $configContent
    
    # Create a script to configure Alexa permissions
    $alexaDeployContent = @"
# Configure Alexa skill to use Lambda in us-east-1

# Configuration values
`$REGION = "$REGION"
`$LAMBDA_ARN = "$LAMBDA_ARN"
`$SKILL_ID = "$SKILL_ID"

Write-Host "Configuring Lambda permissions for Alexa skill in `$REGION..." -ForegroundColor Cyan

# Extract Lambda function name from ARN
`$LAMBDA_FUNCTION_NAME = `$LAMBDA_ARN -split ":" | Select-Object -Last 1

# Add permission for Alexa to invoke Lambda
aws lambda add-permission `
    --function-name `$LAMBDA_FUNCTION_NAME `
    --statement-id AlexaSkillKit `
    --action lambda:InvokeFunction `
    --principal alexa-appkit.amazon.com `
    --event-source-token "`$SKILL_ID" `
    --region `$REGION

Write-Host "Lambda permission added for Alexa in `$REGION" -ForegroundColor Green
Write-Host ""
Write-Host "NEXT STEPS:" -ForegroundColor Cyan
Write-Host "1. In the Alexa Developer Console, go to 'Endpoint'" -ForegroundColor Cyan
Write-Host "2. Select 'AWS Lambda ARN'" -ForegroundColor Cyan
Write-Host "3. Enter this ARN for Default Region: $LAMBDA_ARN" -ForegroundColor Green
Write-Host "4. Click 'Save Endpoints'" -ForegroundColor Cyan
Write-Host "5. Go to 'JSON Editor' under 'Interaction Model'" -ForegroundColor Cyan
Write-Host "6. Upload the models/en-US.json file" -ForegroundColor Cyan
Write-Host "7. Click 'Save Model' and then 'Build Model'" -ForegroundColor Cyan
"@
    Set-Content -Path "3-configure-alexa.ps1" -Value $alexaDeployContent
    
    # Create batch file for easy execution
    $batchContent = @"
@echo off
powershell -ExecutionPolicy Bypass -File "%~dp03-configure-alexa.ps1"
pause
"@
    Set-Content -Path "3-configure-alexa.bat" -Value $batchContent
    
    Write-Host ""
    Write-Host "NEXT STEPS:" -ForegroundColor Cyan
    Write-Host "Run 3-configure-alexa.bat to configure Alexa permissions" -ForegroundColor Cyan
} else {
    Write-Host "CloudFormation stack creation failed." -ForegroundColor Red
    Write-Host "Check the AWS CloudFormation console for error details." -ForegroundColor Red
}