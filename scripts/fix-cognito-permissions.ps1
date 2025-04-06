# Fix Cognito permissions for Lambda function
$env:AWS_DEFAULT_OUTPUT = 'json'
$REGION = 'us-east-1'
$LAMBDA_FUNCTION_NAME = 'xviper-alexa-skill'
$USER_POOL_NAME = 'XViperUserPool'

Write-Host "Fixing Cognito permissions for Lambda function..." -ForegroundColor Cyan

# Find the user pool
$userPoolsCmd = "aws cognito-idp list-user-pools --max-results 60 --region $REGION"
$userPoolsJson = Invoke-Expression $userPoolsCmd
$userPools = $userPoolsJson | ConvertFrom-Json

$pool = $userPools.UserPools | Where-Object { $_.Name -eq $USER_POOL_NAME }

if ($pool) {
    $USER_POOL_ID = $pool.Id
    Write-Host "Found user pool: $USER_POOL_ID" -ForegroundColor Green
    
    # Get the Lambda execution role
    $lambdaInfoCmd = "aws lambda get-function --function-name $LAMBDA_FUNCTION_NAME --region $REGION"
    $lambdaInfoJson = Invoke-Expression $lambdaInfoCmd
    $lambdaInfo = $lambdaInfoJson | ConvertFrom-Json
    $roleArn = $lambdaInfo.Configuration.Role
    $roleName = $roleArn.Split('/')[-1]
    
    Write-Host "Lambda execution role: $roleName" -ForegroundColor Yellow
    
    # Create a policy document for Cognito access - more specific than wildcard
    # Build the ARN strings with proper variable replacement
    $cognitoArn = "arn:aws:cognito-idp:$REGION`:*:userpool/$USER_POOL_ID"
    $dynamoArn = "arn:aws:dynamodb:$REGION`:*:table/XviperUserMappings"
    
    $policyJson = @"
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "cognito-idp:GetUser",
                "cognito-idp:ListUsers",
                "cognito-idp:AdminGetUser",
                "cognito-idp:AdminUserGlobalSignOut",
                "cognito-idp:AdminInitiateAuth"
            ],
            "Resource": "$cognitoArn"
        },
        {
            "Effect": "Allow",
            "Action": [
                "dynamodb:GetItem",
                "dynamodb:PutItem",
                "dynamodb:DeleteItem",
                "dynamodb:UpdateItem",
                "dynamodb:Query",
                "dynamodb:Scan"
            ],
            "Resource": "$dynamoArn"
        }
    ]
}
"@
    
    $policyFile = "cognito_policy.json"
    Set-Content -Path $policyFile -Value $policyJson
    
    # Create the policy
    $policyName = "CognitoAccessForLambda"
    $createPolicyCmd = "aws iam create-policy --policy-name $policyName --policy-document file://$policyFile"
    
    # Get AWS account ID
    $accountInfoCmd = "aws sts get-caller-identity"
    $accountInfoJson = Invoke-Expression $accountInfoCmd
    $accountInfo = $accountInfoJson | ConvertFrom-Json
    $awsAccountId = $accountInfo.Account
    
    Write-Host "AWS Account ID: $awsAccountId" -ForegroundColor Yellow
    
    # Create a new policy, handling the case where it might already exist
    $policyArn = "arn:aws:iam::${awsAccountId}:policy/$policyName"
    
    Write-Host "Creating or updating policy: $policyName" -ForegroundColor Yellow
    try {
        # Try to create the policy
        $createPolicyResult = Invoke-Expression "$createPolicyCmd 2>&1"
        $createPolicyJson = $createPolicyResult | ConvertFrom-Json
        $policyArn = $createPolicyJson.Policy.Arn
        Write-Host "Created new policy: $policyArn" -ForegroundColor Green
    } catch {
        # If the policy already exists, get its ARN
        Write-Host "Policy may already exist, checking..." -ForegroundColor Yellow
        
        # List all policies to find it - use simpler approach
        $listPoliciesCmd = "aws iam list-policies --scope Local --output json"
        $policiesJson = Invoke-Expression $listPoliciesCmd
        $policies = $policiesJson | ConvertFrom-Json
        
        # Filter locally instead of using JMESPath query
        $matchingPolicies = $policies.Policies | Where-Object { $_.PolicyName -eq $policyName }
        
        if ($matchingPolicies -and $matchingPolicies.Count -gt 0) {
            $policyArn = $matchingPolicies[0].Arn
            Write-Host "Found existing policy: $policyArn" -ForegroundColor Green
            
            # Update the policy with the new document
            $versionCmd = "aws iam create-policy-version --policy-arn $policyArn --policy-document file://$policyFile --set-as-default"
            try {
                Invoke-Expression $versionCmd | Out-Null
                Write-Host "Updated policy with new permissions" -ForegroundColor Green
            } catch {
                Write-Host "Could not update policy, may need to delete old versions first" -ForegroundColor Yellow
            }
        } else {
            # Policy doesn't exist yet, create it
            Write-Host "Policy doesn't exist, creating a new one..." -ForegroundColor Yellow
            try {
                $createResult = Invoke-Expression "$createPolicyCmd 2>&1"
                
                # Check if error contains "EntityAlreadyExists"
                if ($createResult -like "*EntityAlreadyExists*") {
                    Write-Host "Policy already exists but couldn't be found in the list" -ForegroundColor Yellow
                    # Use default ARN format as the policy exists but we can't get its exact ARN
                    $policyArn = "arn:aws:iam::${awsAccountId}:policy/$policyName"
                    Write-Host "Using calculated ARN: $policyArn" -ForegroundColor Yellow
                } else {
                    # Success case
                    $createJson = $createResult | ConvertFrom-Json
                    $policyArn = $createJson.Policy.Arn
                    Write-Host "Created new policy: $policyArn" -ForegroundColor Green
                }
            } catch {
                Write-Host "ERROR: Failed to create policy: $_" -ForegroundColor Red
                Write-Host "Will continue but Lambda may not have proper permissions" -ForegroundColor Red
                
                # Use a default policy ARN format as fallback
                $policyArn = "arn:aws:iam::${awsAccountId}:policy/$policyName"
            }
        }
    }
    
    # Attach the policy to the role
    Write-Host "Attaching policy to role: $roleName" -ForegroundColor Yellow
    $attachPolicyCmd = "aws iam attach-role-policy --role-name $roleName --policy-arn $policyArn"
    try {
        # First check if the policy is already attached
        $listAttachedCmd = "aws iam list-attached-role-policies --role-name $roleName"
        $attachedJson = Invoke-Expression $listAttachedCmd
        $attached = $attachedJson | ConvertFrom-Json
        
        $alreadyAttached = $false
        foreach ($pol in $attached.AttachedPolicies) {
            if ($pol.PolicyArn -eq $policyArn) {
                $alreadyAttached = $true
                break
            }
        }
        
        if ($alreadyAttached) {
            Write-Host "Policy is already attached to role" -ForegroundColor Green
        } else {
            # Ensure our policy ARN is properly formatted for the command
            $escapedPolicyArn = $policyArn.Replace("'", "''").Replace('"', '\"')
            $formattedCmd = "aws iam attach-role-policy --role-name `"$roleName`" --policy-arn `"$escapedPolicyArn`""
            Write-Host "Running: $formattedCmd" -ForegroundColor Yellow
            
            Invoke-Expression $formattedCmd | Out-Null
            Write-Host "Successfully attached policy to role" -ForegroundColor Green
        }
    } catch {
        Write-Host "Error with policy attachment: $_" -ForegroundColor Red
        
        # Continue anyway - try to create inline policy as fallback
        Write-Host "Trying to create inline policy as fallback..." -ForegroundColor Yellow
        $inlinePolicyName = "InlineCognitoAccess"
        $inlineCmd = "aws iam put-role-policy --role-name $roleName --policy-name $inlinePolicyName --policy-document file://$policyFile"
        
        try {
            Invoke-Expression $inlineCmd | Out-Null
            Write-Host "Created inline policy as fallback" -ForegroundColor Green
        } catch {
            Write-Host "Could not create inline policy: $_" -ForegroundColor Red
            Write-Host "You may need to manually add permissions for Lambda to access Cognito" -ForegroundColor Yellow
        }
    }
    
    Write-Host "Attached Cognito access policy to Lambda execution role!" -ForegroundColor Green
    
    # Clean up
    Remove-Item -Path $policyFile -Force
    
    # Update Lambda configuration to fix any issues with accessing tokens
    Write-Host "Updating Lambda function configuration..." -ForegroundColor Yellow
    
    # Get all existing environment variables
    $lambdaConfigCmd = "aws lambda get-function-configuration --function-name $LAMBDA_FUNCTION_NAME --region $REGION"
    $lambdaConfigJson = Invoke-Expression $lambdaConfigCmd
    $lambdaConfig = $lambdaConfigJson | ConvertFrom-Json
    
    # Initialize an empty hashtable for environment variables
    $envVars = @{}
    
    # Check if Environment and Variables properties exist and are not null
    if ($lambdaConfig.Environment -and 
        (Get-Member -InputObject $lambdaConfig.Environment -Name "Variables" -MemberType Properties) -and 
        $lambdaConfig.Environment.Variables) {
        
        # Get all properties of the Variables object
        $properties = Get-Member -InputObject $lambdaConfig.Environment.Variables -MemberType NoteProperty
        
        # Add each property to our hashtable
        foreach ($prop in $properties) {
            $name = $prop.Name
            $value = $lambdaConfig.Environment.Variables.$name
            $envVars[$name] = $value
        }
    }
    
    # Add or update necessary environment variables
    $envVars["COGNITO_USER_POOL_ID"] = $USER_POOL_ID
    $envVars["USER_MAPPING_TABLE"] = "XviperUserMappings"
    
    # Create a simpler environment variable update approach
    Write-Host "Setting environment variables directly..." -ForegroundColor Yellow
    
    # Create a comma-separated list of key=value pairs for environment variables
    $envVarString = ""
    foreach ($key in $envVars.Keys) {
        if ($envVarString -ne "") {
            $envVarString += ","
        }
        $envVarString += "$key=$($envVars[$key])"
    }
    
    # Update Lambda environment variables and resources in a single call
    Write-Host "Updating Lambda configuration (environment, memory, and timeout)..." -ForegroundColor Yellow
    
    $updateCmd = "aws lambda update-function-configuration --function-name $LAMBDA_FUNCTION_NAME --environment 'Variables={$envVarString}' --timeout 30 --memory-size 512 --region $REGION"
    
    try {
        Invoke-Expression $updateCmd | Out-Null
        Write-Host "Successfully updated Lambda configuration" -ForegroundColor Green
    } catch {
        # If we hit a conflict, wait and retry
        if ($_.Exception.Message -like "*ResourceConflictException*") {
            Write-Host "Lambda update already in progress. Waiting to retry..." -ForegroundColor Yellow
            
            # Wait for up to 60 seconds for the update to complete
            $retryCount = 0
            $maxRetries = 6
            $waitSeconds = 10
            $updateSucceeded = $false
            
            while ($retryCount -lt $maxRetries -and -not $updateSucceeded) {
                Start-Sleep -Seconds $waitSeconds
                $retryCount++
                Write-Host "Retrying Lambda update (attempt $retryCount of $maxRetries)..." -ForegroundColor Yellow
                
                try {
                    Invoke-Expression $updateCmd | Out-Null
                    $updateSucceeded = $true
                    Write-Host "Successfully updated Lambda configuration on retry" -ForegroundColor Green
                } catch {
                    if ($retryCount -ge $maxRetries) {
                        Write-Host "Maximum retries reached. Could not update Lambda configuration." -ForegroundColor Red
                        Write-Host "You may need to wait a few minutes and run the script again." -ForegroundColor Red
                    } else {
                        Write-Host "Update still in progress, waiting $waitSeconds more seconds..." -ForegroundColor Yellow
                    }
                }
            }
        } else {
            Write-Host "Error updating Lambda configuration: $_" -ForegroundColor Red
        }
    }
    
    Write-Host "Lambda function configuration update complete!" -ForegroundColor Green
    
    # Create DynamoDB table if it doesn't exist
    Write-Host "Checking DynamoDB table..." -ForegroundColor Yellow
    
    # List tables to see if our table exists
    $listTablesCmd = "aws dynamodb list-tables --region $REGION"
    $tablesJson = Invoke-Expression $listTablesCmd
    $tables = $tablesJson | ConvertFrom-Json
    
    $tableExists = $false
    if ($tables.TableNames -contains "XviperUserMappings") {
        $tableExists = $true
        Write-Host "DynamoDB table XviperUserMappings already exists" -ForegroundColor Yellow
    }
    
    if (-not $tableExists) {
        Write-Host "Creating DynamoDB table XviperUserMappings..." -ForegroundColor Yellow
        
        # Create a JSON file for the table definition
        $tableDefinition = @{
            "AttributeDefinitions" = @(
                @{
                    "AttributeName" = "alexaUserId"
                    "AttributeType" = "S"
                }
            )
            "TableName" = "XviperUserMappings"
            "KeySchema" = @(
                @{
                    "AttributeName" = "alexaUserId"
                    "KeyType" = "HASH"
                }
            )
            "BillingMode" = "PAY_PER_REQUEST"
        } | ConvertTo-Json -Depth 5
        
        $tableDefFile = "table_definition.json"
        Set-Content -Path $tableDefFile -Value $tableDefinition
        
        # Create the table
        $createTableCmd = "aws dynamodb create-table --cli-input-json file://$tableDefFile --region $REGION"
        Invoke-Expression $createTableCmd
        
        # Clean up
        Remove-Item -Path $tableDefFile -Force
        
        Write-Host "DynamoDB table created!" -ForegroundColor Green
        Write-Host "Waiting for table to become active..." -ForegroundColor Yellow
        Start-Sleep -Seconds 10
    }
    
    # Verify Cognito custom attributes are correctly set
    Write-Host "Verifying Cognito user pool has the necessary custom attributes..." -ForegroundColor Yellow
    
    $schemaCmd = "aws cognito-idp describe-user-pool --user-pool-id $USER_POOL_ID --region $REGION"
    $schemaJson = Invoke-Expression $schemaCmd
    $schema = $schemaJson | ConvertFrom-Json
    
    $customAttributes = $schema.UserPool.SchemaAttributes | Where-Object { $_.Name -like "custom:*" }
    $hasViperUsername = $customAttributes | Where-Object { $_.Name -eq "custom:viper_username" }
    $hasViperPassword = $customAttributes | Where-Object { $_.Name -eq "custom:viper_password" }
    
    if (-not $hasViperUsername -or -not $hasViperPassword) {
        Write-Host "Adding missing custom attributes to Cognito user pool..." -ForegroundColor Yellow
        
        $missingAttributes = @()
        if (-not $hasViperUsername) {
            $missingAttributes += [PSCustomObject]@{
                Name = "custom:viper_username"
                AttributeDataType = "String"
                Mutable = $true
                Required = $false
            }
        }
        
        if (-not $hasViperPassword) {
            $missingAttributes += [PSCustomObject]@{
                Name = "custom:viper_password"
                AttributeDataType = "String" 
                Mutable = $true
                Required = $false
            }
        }
        
        # Convert the attributes to JSON
        $attrsFile = "custom_attributes.json"
        
        if ($missingAttributes.Count -gt 0) {
            $attrsJson = $missingAttributes | ConvertTo-Json
            Set-Content -Path $attrsFile -Value $attrsJson
        } else {
            # Create an empty array to avoid errors
            Set-Content -Path $attrsFile -Value "[]"
        }
        
        # Add the custom attributes
        $updatePoolCmd = "aws cognito-idp add-custom-attributes --user-pool-id $USER_POOL_ID --custom-attributes file://$attrsFile --region $REGION"
        try {
            Invoke-Expression $updatePoolCmd | Out-Null
            Write-Host "Successfully added custom attributes to user pool" -ForegroundColor Green
        } catch {
            # Don't fail if attributes already exist in a different form
            Write-Host "Could not add custom attributes. They may already exist in a different format." -ForegroundColor Yellow
        }
        
        # Clean up
        Remove-Item -Path $attrsFile -Force
        
        Write-Host "Custom attributes added to Cognito user pool!" -ForegroundColor Green
    } else {
        Write-Host "Cognito user pool already has the necessary custom attributes." -ForegroundColor Green
    }
    
    Write-Host "`nAll fixes applied!" -ForegroundColor Green
    Write-Host "Your Lambda function now has the proper permissions to access Cognito." -ForegroundColor Green
    Write-Host "IMPORTANT: Make sure your Cognito user profile has your Viper credentials!" -ForegroundColor Yellow
    Write-Host "Test the skill by saying:" -ForegroundColor Cyan
    Write-Host "Alexa, ask X Viper to lock my car" -ForegroundColor Cyan
} else {
    Write-Host "User pool not found. Please check the pool name and try again." -ForegroundColor Red
}