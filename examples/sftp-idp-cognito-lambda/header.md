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

### 2. Retrieve the Cognito User Passwords

After deployment, retrieve the auto-generated passwords from Secrets Manager:

```bash
# Get the secret name from Terraform output
SECRET_NAME=$(terraform output -raw cognito_user_password_secret_name)

# Retrieve all user credentials
aws secretsmanager get-secret-value \
  --secret-id $SECRET_NAME \
  --query SecretString \
  --output text | jq

# Or retrieve specific user passwords
aws secretsmanager get-secret-value \
  --secret-id $SECRET_NAME \
  --query SecretString \
  --output text | jq -r '.user1.password'

aws secretsmanager get-secret-value \
  --secret-id $SECRET_NAME \
  --query SecretString \
  --output text | jq -r '.user2.password'
```

### 3. Test the SFTP Connection

The example creates two Cognito users to demonstrate different behaviors:

#### User 1 (Primary User with Explicit Configuration)

This user has an explicit DynamoDB record with custom home directory mapping:

```bash
# Get the server endpoint
SERVER_ENDPOINT=$(terraform output -raw server_endpoint)

# Get the username
USER=$(terraform output -raw cognito_username)

# Connect via SFTP (you'll be prompted for the password)
sftp $USER@$SERVER_ENDPOINT

# Once connected, you'll see the root of the S3 bucket
sftp> ls
# Shows all files in the bucket root
```

#### User 2 (Default Fallback User)

This user has NO explicit DynamoDB record, so it uses the `$default$` configuration:

```bash
# Connect as user2
sftp user2@$SERVER_ENDPOINT

# Once connected, you'll be in an isolated user-specific directory
sftp> ls
# Shows only files in /home/users/user2/

# Files uploaded by user2 are isolated from user1
sftp> put myfile.txt
# File is stored at: s3://<bucket>/users/user2/myfile.txt
```

Or use an SFTP client like FileZilla with:
- **Host**: Server endpoint from Terraform output
- **Username**: `user1` (explicit config) or `user2` (default fallback)
- **Password**: Retrieved from Secrets Manager
- **Port**: 22

**Key Differences:**
- **user1**: Has full bucket access, sees root directory (`/`)
- **user2**: Has isolated access, sees only their folder (`/home/users/user2/`)
- **user2**: Demonstrates the `$default$` fallback behavior for any authenticated Cognito user without explicit configuration

## Cognito User Details

The example creates two Cognito users to demonstrate different configuration approaches:

### User 1 (Primary User - Explicit Configuration)

- **Username**: Configurable via `cognito_username` variable (default: `user1`)
- **Email**: Configurable via `cognito_user_email` variable (default: `user1@example.com`)
- **Password**: Auto-generated 16-character secure password stored in Secrets Manager
- **Home Directory**: Logical mapping to root of S3 bucket (`/`)
- **IP Allowlist**: None (unrestricted access)
- **S3 Permissions**: Full access to entire bucket
- **DynamoDB Record**: Explicit transfer_users record with custom configuration

### User 2 (Default Fallback User - Demonstrates `$default$`)

- **Username**: `user2` (hardcoded)
- **Email**: `user2@example.com` (hardcoded)
- **Password**: Auto-generated 16-character secure password stored in Secrets Manager
- **Home Directory**: Isolated user-specific folder (`/home/users/user2/`)
- **IP Allowlist**: `0.0.0.0/0` (inherited from `$default$` configuration)
- **S3 Permissions**: Access only to their isolated folder
- **DynamoDB Record**: None - uses the `$default$` fallback configuration

> [!NOTE]
> Both users are only created when using a new Cognito pool. When using an existing pool, you manage users separately.

## User Configuration

The example creates two types of users:

1. **Primary Cognito User** (configurable username):
   - No IP restrictions
   - Home directory mapped to root of S3 bucket
   - Full access to entire bucket
   - Authenticates via Cognito credentials

2. **Default Fallback User** (`$default$`):
   - IP allowlist: `0.0.0.0/0` (all IPs - restrict in production)
   - Home directory mapped to user-specific folder: `/home/users/<username>/`
   - Isolated access per authenticated user
   - Catches any authenticated Cognito user not explicitly configured

## DynamoDB Configuration

The example configures DynamoDB items for identity provider and users:

1. **Identity Provider Configuration** (Cognito User Pool ID):
   - Provider key: Cognito User Pool ID (e.g., `us-east-1_ABC123`)
   - Cognito User Pool Client ID
   - AWS Region
   - MFA settings (disabled by default)
   - Module type: `cognito`

2. **User Records** (for each user in transfer_users list):
   - Username and identity provider key (Cognito Pool ID)
   - Home directory mappings (virtual to physical paths)
   - IAM role for S3 access
   - IP allowlist (optional, only for default user)

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

### Using an Existing Cognito User Pool

To use an existing Cognito User Pool instead of creating a new one:

```hcl
# terraform.tfvars
existing_cognito_user_pool_id        = "us-east-1_XXXXXXXXX"
existing_cognito_user_pool_client_id = "1234567890abcdefghijklmnop"
existing_cognito_user_pool_region    = "us-east-1"
```

When using an existing pool:
- No new Cognito User Pool or user will be created
- You must manage users in your existing pool
- The password secret outputs will be null

## Outputs

The example provides the following outputs:

- `server_id`: Transfer Family server ID
- `server_endpoint`: SFTP server endpoint for connections
- `s3_bucket_name`: S3 bucket name for file storage
- `cognito_user_pool_id`: Cognito User Pool ID (created or existing)
- `cognito_user_pool_name`: Cognito User Pool name (only when created by this module)
- `cognito_user_pool_client_id`: Cognito User Pool Client ID (created or existing)
- `cognito_username`: Created Cognito username (null when using existing pool)
- `cognito_user_password_secret_name`: Secrets Manager secret name containing the password (null when using existing pool)
- `lambda_function_arn`: Custom IDP Lambda function ARN
- `users_table_name`: DynamoDB users table name
- `identity_providers_table_name`: DynamoDB identity providers table name

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

> [!IMPORTANT]
> The S3 bucket must be empty before destruction. Remove all files first if needed.
