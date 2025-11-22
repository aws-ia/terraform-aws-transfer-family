# SFTP with Cognito Identity Provider Example

This example demonstrates how to set up AWS Transfer Family SFTP server with a custom identity provider using Amazon Cognito for user authentication and AWS Lambda for identity provider logic.

## Architecture

This example creates a complete SFTP solution with Cognito-based authentication:

- **Transfer Server**: Public SFTP endpoint with Lambda-based custom identity provider
- **Cognito User Pool**: Manages user authentication and credentials
- **Lambda Function**: Custom identity provider that validates Cognito users and returns Transfer Family configuration
- **DynamoDB Tables**: Stores user configurations and identity provider settings
- **S3 Bucket**: Secure file storage with user-specific directories
- **Secrets Manager**: Securely stores generated Cognito user passwords

## Resources Created

- AWS Transfer Family SFTP server (public endpoint)
- Amazon Cognito User Pool with password policy
- Cognito User Pool Client for authentication
- Cognito User with auto-generated secure password
- Custom Identity Provider Lambda function (via transfer-custom-idp-solution module)
- DynamoDB tables for users and identity providers configuration
- S3 bucket with versioning and encryption
- IAM roles and policies for Transfer Family session access
- AWS Secrets Manager secret for Cognito user password

## How It Works

1. **User Authentication**: Users authenticate via SFTP using their Cognito username and password
2. **Lambda Validation**: The Lambda function validates credentials against Cognito
3. **DynamoDB Lookup**: Lambda retrieves user configuration from DynamoDB (home directory, IAM role, IP allowlist)
4. **Session Creation**: Transfer Family creates an SFTP session with the returned configuration
5. **File Access**: Users access their dedicated S3 directory based on their username

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.0
- An AWS account with permissions to create the required resources

## Usage

### 1. Deploy the Infrastructure

```bash
terraform init
terraform plan
terraform apply
```

### 2. Retrieve the Cognito User Password

After deployment, retrieve the auto-generated password from Secrets Manager:

```bash
# Get the secret name from Terraform output
SECRET_NAME=$(terraform output -raw cognito_user_password_secret_name)

# Retrieve the password
aws secretsmanager get-secret-value \
  --secret-id $SECRET_NAME \
  --query SecretString \
  --output text | jq -r '.password'
```

### 3. Test the SFTP Connection

Connect to the SFTP server using the Cognito credentials:

```bash
# Get the server endpoint
SERVER_ENDPOINT=$(terraform output -raw server_endpoint)

# Get the username
USER=$(terraform output -raw cognito_username)

# Connect via SFTP (you'll be prompted for the password)
sftp $USER@$SERVER_ENDPOINT
```

Or use an SFTP client like FileZilla with:
- **Host**: Server endpoint from Terraform output
- **Username**: Cognito username (default: `user1`)
- **Password**: Retrieved from Secrets Manager
- **Port**: 22

## User Configuration

The example creates a Cognito user with the following configuration:

- **Username**: Configurable via `cognito_username` variable (default: `user1`)
- **Email**: Configurable via `cognito_user_email` variable (default: `user1@example.com`)
- **Password**: Auto-generated 16-character secure password stored in Secrets Manager
- **Home Directory**: Logical mapping to `s3://<bucket-name>/<username>/`
- **IP Allowlist**: `0.0.0.0/0` (all IPs allowed - restrict in production)
- **S3 Permissions**: Full access to user-specific folder

## DynamoDB Configuration

The example configures two DynamoDB items:

1. **Identity Provider Configuration** (`cognito_pool`):
   - Cognito User Pool Client ID
   - AWS Region
   - MFA settings (disabled by default)
   - Module type: `cognito`

2. **User Record** (username):
   - Home directory mapping
   - IAM role for S3 access
   - IP allowlist
   - Identity provider key reference

## Security Considerations

- **Password Storage**: Passwords are stored in AWS Secrets Manager with encryption
- **S3 Encryption**: Bucket uses AES256 server-side encryption
- **Versioning**: S3 versioning is enabled for data protection
- **Public Access**: S3 bucket blocks all public access
- **IP Allowlist**: Default allows all IPs - restrict to specific IPs in production
- **Password Policy**: Enforces strong passwords (8+ chars, mixed case, numbers, symbols)

## Customization

You can customize the deployment by modifying variables:

```hcl
# terraform.tfvars
aws_region         = "us-east-1"
name_prefix        = "my-sftp"
cognito_username   = "myuser"
cognito_user_email = "myuser@example.com"

tags = {
  Environment = "production"
  Project     = "secure-file-transfer"
}
```

## Outputs

The example provides the following outputs:

- `server_id`: Transfer Family server ID
- `server_endpoint`: SFTP server endpoint for connections
- `s3_bucket_name`: S3 bucket name for file storage
- `cognito_user_pool_id`: Cognito User Pool ID
- `cognito_username`: Created Cognito username
- `cognito_user_password_secret_name`: Secrets Manager secret name containing the password
- `lambda_function_arn`: Custom IDP Lambda function ARN
- `users_table_name`: DynamoDB users table name
- `identity_providers_table_name`: DynamoDB identity providers table name

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

Note: The S3 bucket must be empty before destruction. Remove all files first if needed.
