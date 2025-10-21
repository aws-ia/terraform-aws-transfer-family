# SFTP Server with Cognito Identity Provider

This example demonstrates how to set up an AWS Transfer Family SFTP server using Amazon Cognito as the identity provider through the custom-idps-nizar module.

## Architecture

- **AWS Transfer Family**: SFTP server with API Gateway identity provider
- **Amazon Cognito**: User pool for authentication
- **DynamoDB**: Stores user configurations and identity provider settings
- **Lambda**: Handles authentication requests using cognito.py
- **S3**: File storage for SFTP users

## Quick Start

```bash
terraform init
terraform apply
```

## Test SFTP Connection

After deployment, test the connection:
```bash
sftp testuser@<transfer-server-endpoint>
# Use password: TempPass123!
```

## Configuration

The example creates:
- A Cognito user pool with a test user
- DynamoDB tables seeded with user and identity provider configurations
- An SFTP server configured to use the custom IDP module
- S3 bucket with appropriate permissions for the test user

## User Management

Users are managed through:
1. **Cognito User Pool**: For authentication
2. **DynamoDB Users Table**: For SFTP-specific configuration (home directory, IAM role, policies)

To add more users, create them in both Cognito and the DynamoDB users table.
