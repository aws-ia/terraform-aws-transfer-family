# AWS Transfer Family with Cognito Authentication Example

This example demonstrates how to set up AWS Transfer Family with a custom identity provider using Amazon Cognito for user authentication.

## Architecture

```
SFTP Client → Transfer Family Server → Lambda (Custom IdP) → Cognito User Pool
                                    ↓
                                DynamoDB (User Config) → S3 Bucket
```

## What This Example Creates

- **Cognito User Pool**: For user authentication
- **Test User**: Pre-configured Cognito user for testing
- **Custom IdP Lambda**: Handles authentication requests
- **Transfer Family Server**: SFTP server with Lambda integration
- **S3 Bucket**: Storage backend for file transfers
- **DynamoDB Tables**: User and identity provider configuration
- **IAM Roles**: Proper permissions for Transfer Family operations

## Quick Start

### 1. Deploy the Infrastructure

```bash
# Navigate to the example directory
cd examples/sftp-custom-idp-cognito

# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Deploy (takes ~3-5 minutes)
terraform apply
```

### 2. Get Connection Details

After deployment, Terraform will output the connection details:

```bash
# View outputs
terraform output

# Get the SFTP connection command
terraform output sftp_connection_command

# Get test user credentials (sensitive)
terraform output -json test_user_credentials
```

### 3. Test SFTP Connection

Use the provided connection command:

```bash
# Connect via SFTP (replace with your actual endpoint)
sftp testuser@@cognito@s-1234567890abcdef0.server.transfer.us-east-1.amazonaws.com

# When prompted, enter the password: TestPass123!
```

### 4. Test File Operations

Once connected, you can perform standard SFTP operations:

```bash
# List files
ls

# Upload a file
put local-file.txt

# Download a file
get remote-file.txt

# Create a directory
mkdir test-directory

# Exit
quit
```

## Configuration Details

### Cognito Configuration

The example creates:
- **User Pool**: `transfer-cognito-xxx-transfer-users`
- **Test User**: `testuser` with password `TestPass123!`
- **Client**: Configured for username/password authentication

### DynamoDB Configuration

The Lambda function uses two DynamoDB tables:

#### Identity Providers Table
```json
{
  "provider": "cognito",
  "module": "cognito",
  "config": {
    "cognito_client_id": "your-client-id",
    "cognito_user_pool_region": "us-east-1"
  }
}
```

#### Users Table
```json
{
  "user": "testuser",
  "identity_provider_key": "cognito",
  "config": {
    "Role": "arn:aws:iam::123456789012:role/transfer-user-role",
    "HomeDirectory": "/your-bucket/testuser"
  }
}
```

### Username Format

The example uses the format: `username@@provider`
- `testuser@@cognito` - Uses Cognito authentication for user "testuser"

## Customization

### Adding More Users

1. **Create Cognito User**:
```bash
aws cognito-idp admin-create-user \
  --user-pool-id "your-pool-id" \
  --username "newuser" \
  --user-attributes Name=email,Value=newuser@example.com \
  --temporary-password "TempPass123!" \
  --message-action SUPPRESS
```

2. **Set Permanent Password**:
```bash
aws cognito-idp admin-set-user-password \
  --user-pool-id "your-pool-id" \
  --username "newuser" \
  --password "NewUserPass123!" \
  --permanent
```

3. **Add to DynamoDB**:
```bash
aws dynamodb put-item \
  --table-name "your-users-table" \
  --item '{
    "user": {"S": "newuser"},
    "identity_provider_key": {"S": "cognito"},
    "config": {"M": {
      "Role": {"S": "arn:aws:iam::123456789012:role/transfer-user-role"},
      "HomeDirectory": {"S": "/your-bucket/newuser"}
    }}
  }'
```

### Changing Authentication Settings

To modify Cognito settings, update the `aws_cognito_user_pool` resource in `main.tf`:

```hcl
resource "aws_cognito_user_pool" "transfer_users" {
  # Enable MFA
  mfa_configuration = "ON"
  
  # Require additional attributes
  schema {
    attribute_data_type = "String"
    name               = "department"
    required           = true
  }
}
```

## Troubleshooting

### Common Issues

1. **Authentication Fails**
   - Verify the username format: `username@@cognito`
   - Check that the user exists in Cognito
   - Ensure the password is correct
   - Verify DynamoDB user configuration

2. **Permission Denied**
   - Check IAM role permissions
   - Verify S3 bucket policy
   - Ensure home directory exists

3. **Lambda Errors**
   - Check CloudWatch logs: `/aws/lambda/your-function-name`
   - Verify DynamoDB table configuration
   - Check Cognito client configuration

### Viewing Logs

```bash
# Lambda logs
aws logs filter-log-events \
  --log-group-name "/aws/lambda/your-function-name" \
  --start-time $(date -d '1 hour ago' +%s)000

# Transfer Family logs (if enabled)
aws logs filter-log-events \
  --log-group-name "/aws/transfer/your-server-name"
```

## Security Considerations

This example is designed for testing and demonstration. For production use:

1. **Use strong passwords** and consider MFA
2. **Implement proper IAM policies** with least privilege
3. **Enable VPC endpoints** for private connectivity
4. **Use KMS encryption** for S3 and DynamoDB
5. **Enable CloudTrail** for audit logging
6. **Implement IP restrictions** if needed

## Cleanup

To remove all resources:

```bash
terraform destroy
```

## Cost Considerations

This example creates the following billable resources:
- AWS Transfer Family server (~$0.30/hour)
- Lambda function (pay per invocation)
- DynamoDB tables (pay per request)
- S3 bucket (pay per storage/requests)
- CloudWatch logs (pay per GB stored)

Estimated cost: ~$7-10/day for testing

## Next Steps

- Explore other identity providers (LDAP, Okta)
- Implement VPC integration for enhanced security
- Add monitoring and alerting
- Set up automated user provisioning
- Integrate with existing identity systems