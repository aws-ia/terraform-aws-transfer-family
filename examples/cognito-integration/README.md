# AWS Transfer Family with Cognito Integration Example

This example demonstrates how to set up an AWS Transfer Family SFTP server with Cognito authentication using a custom identity provider (Lambda function).

## Architecture

- **AWS Transfer Family**: SFTP server with custom identity provider
- **AWS Cognito**: User pool for authentication
- **AWS Lambda**: Custom identity provider function
- **DynamoDB**: Configuration storage
- **S3**: File storage for SFTP users

## Features

- Cognito-based user authentication
- 5 pre-seeded test users
- User-specific home directories in S3
- MFA support configuration
- CloudWatch logging

## Deployment

1. Initialize Terraform:
```bash
terraform init
```

2. Plan the deployment:
```bash
terraform plan
```

3. Apply the configuration:
```bash
terraform apply
```

## Test Users

The following test users are automatically created:

| Username | Password | Email |
|----------|----------|-------|
| sftpuser1 | Password123! | sftpuser1@example.com |
| sftpuser2 | Password123! | sftpuser2@example.com |
| sftpuser3 | Password123! | sftpuser3@example.com |
| sftpuser4 | Password123! | sftpuser4@example.com |
| sftpuser5 | Password123! | sftpuser5@example.com |

## Connecting to SFTP

After deployment, connect using any SFTP client:

```bash
sftp sftpuser1@<transfer-server-endpoint>
```

When prompted, enter the password: `Password123!`

## Configuration

The DynamoDB table stores the configuration with the following schema:

```json
{
  "provider": {
    "S": "cognito"
  },
  "config": {
    "M": {    
      "mfa_token_length": {
        "N": "6"
      },
      "cognito_client_id": {
        "S": "[cognito client id]"
      },
      "cognito_user_pool_region": {
        "S": "[cognito user pool region]"
      },  
      "mfa": {
        "BOOL": true
      }
    }
  },
  "module": {
    "S": "cognito"
  }
}
```

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

## Security Notes

- Test passwords are hardcoded for demonstration purposes
- In production, use proper password policies and rotation
- Consider enabling MFA for enhanced security
- Review IAM policies for least privilege access
