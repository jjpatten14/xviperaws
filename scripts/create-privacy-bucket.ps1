# Create a new S3 bucket for hosting the privacy policy
$env:AWS_DEFAULT_OUTPUT = 'json'
$REGION = 'us-east-1'
$BUCKET_NAME = "xviper-privacy-policy-$(Get-Random -Minimum 1000 -Maximum 9999)"

Write-Host "Creating new S3 bucket for privacy policy: $BUCKET_NAME" -ForegroundColor Cyan

# Create the bucket
try {
    $createBucketCmd = "aws s3api create-bucket --bucket $BUCKET_NAME --region $REGION"
    Invoke-Expression $createBucketCmd | Out-Null
    Write-Host "Bucket created successfully: $BUCKET_NAME" -ForegroundColor Green
} catch {
    Write-Host "Failed to create bucket: $_" -ForegroundColor Red
    exit 1
}

# Upload the privacy policy HTML file
$filePath = "privacy-policy.html"
if (-not (Test-Path $filePath)) {
    Write-Host "Privacy policy file not found at: $filePath" -ForegroundColor Red
    exit 1
}

try {
    # Upload with public-read ACL
    $uploadCmd = "aws s3 cp $filePath s3://$BUCKET_NAME/privacy-policy.html --acl public-read --content-type 'text/html' --region $REGION"
    Invoke-Expression $uploadCmd | Out-Null
    Write-Host "Privacy policy uploaded successfully" -ForegroundColor Green
    
    # Create a website configuration for the bucket
    $websiteConfig = @"
{
    "IndexDocument": {
        "Suffix": "index.html"
    },
    "ErrorDocument": {
        "Key": "error.html"
    }
}
"@
    $websiteConfigFile = "website-config.json"
    Set-Content -Path $websiteConfigFile -Value $websiteConfig
    
    try {
        $setWebsiteCmd = "aws s3api put-bucket-website --bucket $BUCKET_NAME --website-configuration file://$websiteConfigFile --region $REGION"
        Invoke-Expression $setWebsiteCmd | Out-Null
        Write-Host "Added website configuration to bucket" -ForegroundColor Green
        Remove-Item -Path $websiteConfigFile
    } catch {
        Write-Host "Could not set website configuration: $_" -ForegroundColor Yellow
        Write-Host "The file will still be accessible, but not as a website" -ForegroundColor Yellow
    }
    
    # Add bucket policy for public read access
    $bucketPolicy = @"
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "PublicReadGetObject",
            "Effect": "Allow",
            "Principal": "*",
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::$BUCKET_NAME/*"
        }
    ]
}
"@
    $policyFile = "bucket-policy.json"
    Set-Content -Path $policyFile -Value $bucketPolicy
    
    try {
        $setPolicyCmd = "aws s3api put-bucket-policy --bucket $BUCKET_NAME --policy file://$policyFile --region $REGION"
        Invoke-Expression $setPolicyCmd | Out-Null
        Write-Host "Set bucket policy for public read access" -ForegroundColor Green
        Remove-Item -Path $policyFile
    } catch {
        Write-Host "Could not set bucket policy: $_" -ForegroundColor Yellow
        Write-Host "You may need to manually set permissions for public access" -ForegroundColor Yellow
    }
    
    # Make sure bucket public access is not blocked
    try {
        $publicAccessCmd = "aws s3api put-public-access-block --bucket $BUCKET_NAME --public-access-block-configuration 'BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false' --region $REGION"
        Invoke-Expression $publicAccessCmd | Out-Null
        Write-Host "Configured bucket to allow public access" -ForegroundColor Green
    } catch {
        Write-Host "Could not configure public access settings: $_" -ForegroundColor Yellow
    }
    
    # Get the URL for the uploaded file
    $websiteUrl = "http://$BUCKET_NAME.s3-website-$REGION.amazonaws.com/privacy-policy.html"
    $directUrl = "https://$BUCKET_NAME.s3.amazonaws.com/privacy-policy.html"
    
    Write-Host "`nPrivacy Policy is now available at:" -ForegroundColor Green
    Write-Host "Website URL: $websiteUrl" -ForegroundColor Cyan
    Write-Host "Direct URL: $directUrl" -ForegroundColor Cyan
    Write-Host "`nYou can use either URL in your Alexa skill configuration for the privacy policy link." -ForegroundColor Yellow
    
    # Save the bucket information for future use
    $bucketInfo = @"
S3_PRIVACY_BUCKET=$BUCKET_NAME
S3_PRIVACY_URL=$directUrl
S3_PRIVACY_WEBSITE_URL=$websiteUrl
"@
    $bucketInfoFile = "privacy-bucket-info.txt"
    Set-Content -Path $bucketInfoFile -Value $bucketInfo
    Write-Host "Bucket information saved to $bucketInfoFile" -ForegroundColor Green
    
} catch {
    Write-Host "Failed to upload privacy policy: $_" -ForegroundColor Red
    exit 1
}