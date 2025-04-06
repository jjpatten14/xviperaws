# Fix privacy bucket access without using ACLs
$env:AWS_DEFAULT_OUTPUT = 'json'
$REGION = 'us-east-1'

# Read the bucket name from the saved info
$infoFile = "privacy-bucket-info.txt"
if (-not (Test-Path $infoFile)) {
    Write-Host "Bucket info file not found: $infoFile" -ForegroundColor Red
    exit 1
}

$bucketInfo = Get-Content $infoFile
$BUCKET_NAME = ""
foreach ($line in $bucketInfo) {
    if ($line -match "S3_PRIVACY_BUCKET=(.+)") {
        $BUCKET_NAME = $matches[1]
        break
    }
}

if (-not $BUCKET_NAME) {
    Write-Host "Bucket name not found in info file" -ForegroundColor Red
    exit 1
}

Write-Host "Fixing access for privacy policy bucket: $BUCKET_NAME" -ForegroundColor Cyan

# Re-upload the privacy policy HTML file without ACL
$filePath = "privacy-policy.html"
if (-not (Test-Path $filePath)) {
    Write-Host "Privacy policy file not found at: $filePath" -ForegroundColor Red
    exit 1
}

try {
    # Upload without public-read ACL but with correct content type
    $uploadCmd = "aws s3 cp $filePath s3://$BUCKET_NAME/privacy-policy.html --content-type 'text/html' --region $REGION"
    Invoke-Expression $uploadCmd | Out-Null
    Write-Host "Privacy policy re-uploaded successfully" -ForegroundColor Green
    
    # Generate a pre-signed URL that lasts 10 years (maximum allowed duration)
    $presignCmd = "aws s3 presign s3://$BUCKET_NAME/privacy-policy.html --expires-in 315360000 --region $REGION"
    $presignedUrl = Invoke-Expression $presignCmd
    Write-Host "Generated long-lasting pre-signed URL" -ForegroundColor Green
    
    # Upload a simple index.html that redirects to the privacy policy
    $indexHtml = @"
<!DOCTYPE html>
<html>
<head>
    <meta http-equiv="refresh" content="0; url=privacy-policy.html">
    <title>Redirecting...</title>
</head>
<body>
    <p>Redirecting to privacy policy...</p>
    <p><a href="privacy-policy.html">Click here if you are not redirected.</a></p>
</body>
</html>
"@
    $indexPath = "index.html"
    Set-Content -Path $indexPath -Value $indexHtml
    $uploadIndexCmd = "aws s3 cp $indexPath s3://$BUCKET_NAME/index.html --content-type 'text/html' --region $REGION"
    Invoke-Expression $uploadIndexCmd | Out-Null
    Write-Host "Index page uploaded as redirect" -ForegroundColor Green
    Remove-Item -Path $indexPath
    
    # Get the URLs
    $directUrl = "https://$BUCKET_NAME.s3.amazonaws.com/privacy-policy.html"
    $presignedInfo = @"
IMPORTANT PRIVACY POLICY URLS:

1. Standard S3 URL (may not work due to permissions):
$directUrl

2. Pre-signed URL (will work for 10 years):
$presignedUrl

Use the pre-signed URL for your Alexa skill configuration for the privacy policy link.
"@
    $urlInfoFile = "privacy-policy-urls.txt"
    Set-Content -Path $urlInfoFile -Value $presignedInfo
    Write-Host "URL information saved to $urlInfoFile" -ForegroundColor Green
    
    Write-Host "`nPrivacy Policy is now available via pre-signed URL:" -ForegroundColor Green
    Write-Host $presignedUrl -ForegroundColor Cyan
    Write-Host "`nThis URL will work for 10 years even with default S3 privacy settings." -ForegroundColor Yellow
    Write-Host "Use this URL in your Alexa skill configuration for the privacy policy link." -ForegroundColor Yellow
    
} catch {
    Write-Host "Failed to generate pre-signed URL: $_" -ForegroundColor Red
    exit 1
}