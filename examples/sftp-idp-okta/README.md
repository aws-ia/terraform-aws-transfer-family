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
- Okta account with permissions to create applications and manage API tokens

## Okta Configuration

This example supports **two authentication methods** for the Terraform Okta provider:

1. **API Token** (simpler, legacy) - Good for testing
2. **OAuth2 with Private Key JWT** (recommended, more secure) - Good for production

**Important**: The authentication method only affects how **Terraform authenticates to Okta** to manage resources. SFTP users authenticate separately using Okta's Authentication API with their username and password.

### Option 1: API Token Authentication

1. Log into **Okta Admin Console**
2. Go to **Security** → **API** → **Tokens**
3. Click **Create Token** and copy the value

### Option 2: OAuth2 Authentication (Recommended)

1. **Create OAuth2 Application**:
   - Go to **Applications** → **Create App Integration**
   - Select **API Services**
   - Note the **Client ID**

2. **Grant Scopes**:
   - Go to **Okta API Scopes** tab
   - Grant `okta.users.read` scope

3. **Generate Key Pair**:
   - In the application's **General** tab → **Client Credentials**
   - Select **Public Key / Private Key**
   - Generate a new key and note the **Key ID (kid)**
   - Download the private key in PKCS#1 format (begins with `<RSA PRIVATE KEY HEADER>`)

4. **Disable DPoP** (Critical):
   - In **General** tab, ensure "Require Demonstrating Proof of Possession (DPoP)" is **disabled**

5. **Get User ID**:
   - Go to **Directory** → **People** → click your user
   - Copy the user ID from the URL

For detailed setup instructions, see [Okta's Terraform Org Access guide](https://developer.okta.com/docs/guides/terraform-enable-org-access/-/main/).

## Usage

### 1. Configure Terraform Variables

Create a `terraform.tfvars` file with **ONE** of the following authentication methods:

#### Option A: API Token

```hcl
aws_region     = "us-east-1"
name_prefix    = "sftp-okta-example"
okta_org_name  = "your-org-name"
okta_base_url  = "okta.com"
okta_domain    = "your-org-name.okta.com"

okta_api_token = "your-okta-api-token-here"
okta_user_id   = "00u..."  # Your existing Okta user ID
```

#### Option B: OAuth2 (Recommended)

```hcl
aws_region     = "us-east-1"
name_prefix    = "sftp-okta-example"
okta_org_name  = "your-org-name"
okta_base_url  = "okta.com"
okta_domain    = "your-org-name.okta.com"

okta_client_id      = "0oa..."  # Your OAuth2 client ID
okta_private_key_id = "xxx..."  # Your key ID (kid)
okta_private_key    = <<-EOT
<RSA PRIVATE KEY HEADER>
[Your PKCS#1 formatted key content]
<RSA PRIVATE KEY FOOTER>
EOT
okta_scopes  = ["okta.users.read"]
okta_user_id = "00u..."  # Your existing Okta user ID
```

**Note:** See [Okta Terraform Provider docs](https://registry.terraform.io/providers/okta/okta/latest/docs) for authentication configuration details. Do not configure both methods at once as they conflict.

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

### Terraform Provider Issues

#### "empty access token" or OAuth2 Errors

- **Cause:** DPoP (Demonstrating Proof of Possession) is enabled on your Okta OAuth2 application
- **Fix:** Disable DPoP in Okta app settings → General tab → General Settings, then regenerate your private key

#### "The access token provided does not contain the required scopes"

- **Cause:** Missing `okta.users.read` scope
- **Fix:** Grant `okta.users.read` scope in your Okta application's API Scopes tab

#### "Conflicting configuration arguments" - api_token conflicts with scopes

- **Cause:** Both API token and OAuth2 configured in `terraform.tfvars`
- **Fix:** Choose ONE authentication method - comment out or remove the other

#### Private Key Format Error

- **Cause:** Private key is in PKCS#8 format instead of PKCS#1
- **Fix:** Ensure your key begins with `<RSA PRIVATE KEY HEADER>` (not `<PRIVATE KEY HEADER>`)

### SFTP Authentication Failures

- Verify the Okta user password is correct
- Ensure the user exists in Okta and is active
- Check that the user is assigned to the application (if okta_app_id is provided)
- Review CloudWatch logs for the Lambda function to see authentication details

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

## Additional Resources

- [Okta Terraform Provider Documentation](https://registry.terraform.io/providers/okta/okta/latest/docs)
- [Enable Terraform access for your Okta org](https://developer.okta.com/docs/guides/terraform-enable-org-access/-/main/)
- [AWS Transfer Family Documentation](https://docs.aws.amazon.com/transfer/)
- [Okta OAuth 2.0 Documentation](https://developer.okta.com/docs/guides/implement-oauth-for-okta/main/)
