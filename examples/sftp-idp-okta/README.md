# SFTP with Okta Identity Provider Example

This example demonstrates how to set up AWS Transfer Family SFTP server with a custom identity provider using Okta for user authentication and AWS Lambda for identity provider logic.

## Architecture

This example creates a complete SFTP solution with Okta-based authentication:

- **Transfer Server**: Public SFTP endpoint with Lambda-based custom identity provider
- **Okta Integration**: OAuth 2.0 authentication against Okta
- **Lambda Function**: Custom identity provider that validates Okta users and returns Transfer Family configuration
- **DynamoDB Tables**: Stores user configurations and identity provider settings
- **S3 Bucket**: Secure file storage with user-specific directories
- **Secrets Manager**: Securely stores generated user password

## Resources Created

- AWS Transfer Family SFTP server (public endpoint)
- Custom Identity Provider Lambda function (via transfer-custom-idp-solution module)
- DynamoDB tables for users and identity providers configuration
- S3 bucket with versioning and encryption
- IAM roles and policies for Transfer Family session access
- AWS Secrets Manager secret for Okta user password

## How It Works

1. **User Authentication**: Users authenticate via SFTP using their Okta email and password
2. **Lambda Validation**: The Lambda function validates credentials against Okta OAuth 2.0
3. **DynamoDB Lookup**: Lambda retrieves user configuration from DynamoDB (home directory, IAM role, IP allowlist)
4. **Session Creation**: Transfer Family creates an SFTP session with the returned configuration
5. **File Access**: Users access their dedicated S3 directory based on their username

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.5
- An AWS account with permissions to create the required resources
- Okta account with an OAuth application configured
- Okta client secret for the application

## Okta Configuration

This example uses the following Okta configuration:

- **Okta Domain**: `integrator-7292670.okta.com`
- **Client ID**: `0oax6hum50n7CJNA8697` (optional, only needed for retrieving user attributes)
- **User Email**: `nizarl@amazon.com`

**Authentication Method**: This example uses Okta's Authentication API with username/password. Users authenticate directly against Okta without OAuth flows.

## Usage

### 1. Configure Terraform Variables

Create a `terraform.tfvars` file:

```hcl
okta_api_token = "your-okta-api-token-here"
okta_user_id   = "00u..."  # Your existing Okta user ID
```

### 2. Deploy the Infrastructure

```bash
terraform init
terraform plan
terraform apply
```

### 3. Test the SFTP Connection

```bash
# Get the server endpoint
SERVER_ENDPOINT=$(terraform output -raw server_endpoint)

# Get the user email
USER_EMAIL=$(terraform output -raw okta_user_email)

# Connect via SFTP using your Okta password
sftp $USER_EMAIL@$SERVER_ENDPOINT

# Once connected, you'll see the root of the S3 bucket
sftp> ls
sftp> put testfile.txt
sftp> get testfile.txt
```

## User Configuration

The example retrieves an existing Okta user and creates the following configurations in DynamoDB:

1. **Primary User** (from Okta):
   - Home directory: Root of S3 bucket
   - Full access to all files
   - Uses existing Okta password

2. **Default User** (`$default$`):
   - Fallback configuration for any Okta user not explicitly configured
   - Home directory: `/home` mapped to `/users/{username}` in S3
   - IP allowlist: `0.0.0.0/0` (all IPs allowed)

## Security Considerations

- The Okta API token is marked as sensitive and should be stored securely
- Uses existing Okta user password (no password generation or storage)
- S3 bucket has public access blocked and encryption enabled
- IAM roles follow least-privilege principles
- All resources are tagged for tracking and management

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

## Troubleshooting

### Authentication Failures

- Verify the Okta user password is correct
- Ensure the user exists in Okta and is active
- Check that the user is assigned to the application (if okta_app_id is provided)

### Connection Issues

- Verify the server endpoint is accessible
- Check security groups and network ACLs if using VPC endpoint
- Review CloudWatch logs for the Transfer Family server

## Outputs

- `server_id`: The ID of the Transfer Family server
- `server_endpoint`: The SFTP endpoint to connect to
- `okta_user_id`: The Okta user ID
- `okta_user_email`: Email address of the Okta user
- `s3_bucket_name`: Name of the S3 bucket for file storage
- `connection_instructions`: Step-by-step connection instructions
