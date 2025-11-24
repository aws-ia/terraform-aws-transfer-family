# SFTP with Cognito Identity Provider Example

This example demonstrates how to set up AWS Transfer Family SFTP server with a custom identity provider using Cognito and Lambda.

## Architecture

- **Transfer Server**: SFTP server with API Gateway identity provider
- **Cognito User Pool**: Manages user authentication
- **Lambda Function**: Custom identity provider logic
- **DynamoDB Tables**: Stores user configurations and identity provider settings
- **S3 Bucket**: File storage for SFTP users

## Resources Created

- AWS Transfer Family SFTP server
- Cognito User Pool and Client
- Custom identity provider Lambda function (via module)
- DynamoDB tables for users and identity providers
- S3 bucket for file transfers
- IAM roles and policies

## Usage

1. Deploy the infrastructure:
```bash
terraform init
terraform plan
terraform apply
```

2. Test the SFTP connection using the mock user:
```bash
sftp $default$@<transfer-server-endpoint>
```

The mock user `$default$` is pre-configured with:
- Identity provider key: `domain2019.local`
- Home directory: Logical mapping to S3 bucket
- IP allowlist: `0.0.0.0/0` (all IPs allowed)
- S3 permissions for user-specific folder access

## Mock User Configuration

The example creates a user with username `$default$` that has:
- Logical home directory mapping to S3
- IAM policy allowing S3 access to user-specific folders
- IP allowlist permitting connections from any IP
- Integration with the public key authentication module

## Testing

After deployment, you can test the SFTP connection using any SFTP client:
```bash
sftp $default$@<server-endpoint>
```

The user will have access to their dedicated folder in the S3 bucket.