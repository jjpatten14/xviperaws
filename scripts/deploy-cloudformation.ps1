# Deploy CloudFormation stack with confirmed S3 bucket

# Configuration
$REGION = 'us-east-1'
$S3_BUCKET = 'xviper-us-east1-965239903867'
$STACK_NAME = 'xviper-stack-emergency'
$SKILL_ID = 'amzn1.ask.skill.89b0ef4c-80f9-4e51-89ba-190195199b0b'

Write-Host "Deploying CloudFormation stack in $REGION..." -ForegroundColor Cyan
Write-Host "Using S3 bucket: $S3_BUCKET" -ForegroundColor Cyan
Write-Host ""

# Verify S3 bucket and deployment package again
try {
    Write-Host "Verifying S3 bucket and deployment package..." -ForegroundColor Cyan
    $bucketCheck = aws s3api head-bucket --bucket $S3_BUCKET --region $REGION
    $packageCheck = aws s3api head-object --bucket $S3_BUCKET --key deployment.zip --region $REGION
    Write-Host "Verification successful!" -ForegroundColor Green
} catch {
    Write-Host "ERROR: S3 bucket or deployment package verification failed." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

# Deploy CloudFormation stack
Write-Host "Creating CloudFormation stack..." -ForegroundColor Cyan
$createStackCmd = "aws cloudformation create-stack --stack-name $STACK_NAME --template-body file://cloudformation-emergency.yaml --capabilities CAPABILITY_NAMED_IAM --region $REGION"
Invoke-Expression $createStackCmd

Write-Host "Waiting for CloudFormation stack creation to complete..." -ForegroundColor Cyan
Write-Host "This may take several minutes..." -ForegroundColor Yellow
$waitStackCmd = "aws cloudformation wait stack-create-complete --stack-name $STACK_NAME --region $REGION"
Invoke-Expression $waitStackCmd

# Check if CloudFormation stack creation was successful
try {
    $describeStacksCmd = "aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION"
    $stackInfo = Invoke-Expression $describeStacksCmd
    
    Write-Host "CloudFormation stack created successfully!" -ForegroundColor Green
    
    # Get outputs from CloudFormation
    $lambdaArnCmd = "aws cloudformation describe-stacks --stack-name $STACK_NAME --query 'Stacks[0].Outputs[?OutputKey==""LambdaFunctionArn""].OutputValue' --output text --region $REGION"
    $LAMBDA_ARN = Invoke-Expression $lambdaArnCmd
    
    Write-Host "Lambda Function ARN: $LAMBDA_ARN" -ForegroundColor Green
    
    # Configure Alexa permissions
    Write-Host "Configuring Lambda permissions for Alexa skill..." -ForegroundColor Cyan
    
    # Extract Lambda function name from ARN
    $LAMBDA_FUNCTION_NAME = ($LAMBDA_ARN -split ":" | Select-Object -Last 1)
    
    # Add permission for Alexa to invoke Lambda
    $addPermissionCmd = "aws lambda add-permission --function-name $LAMBDA_FUNCTION_NAME --statement-id AlexaSkillKit --action lambda:InvokeFunction --principal alexa-appkit.amazon.com --event-source-token '$SKILL_ID' --region $REGION"
    Invoke-Expression $addPermissionCmd
    
    Write-Host "Lambda permission added for Alexa!" -ForegroundColor Green
    Write-Host ""
    Write-Host "SETUP COMPLETE!" -ForegroundColor Green
    Write-Host ""
    Write-Host "FINAL STEPS:" -ForegroundColor Cyan
    Write-Host "1. In the Alexa Developer Console, go to 'Endpoint'" -ForegroundColor Cyan
    Write-Host "2. Select 'AWS Lambda ARN'" -ForegroundColor Cyan
    Write-Host "3. Enter this ARN for Default Region: $LAMBDA_ARN" -ForegroundColor Green
    Write-Host "4. Click 'Save Endpoints'" -ForegroundColor Cyan
    Write-Host "5. Go to 'JSON Editor' under 'Interaction Model'" -ForegroundColor Cyan
    Write-Host "6. Upload the models/en-US.json file" -ForegroundColor Cyan
    Write-Host "7. Click 'Save Model' and then 'Build Model'" -ForegroundColor Cyan
} catch {
    Write-Host "CloudFormation stack creation failed." -ForegroundColor Red
    Write-Host "Check the AWS CloudFormation console for error details." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
}