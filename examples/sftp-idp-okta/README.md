<!-- BEGIN_TF_DOCS -->
# SFTP with Okta Identity Provider Example

This example demonstrates how to set up AWS Transfer Family SFTP server with a custom identity provider using Okta for user authentication and AWS Lambda for identity provider logic.

## Architecture

This example creates a complete SFTP solution with Okta-based authentication:

- **Transfer Server**: Public SFTP endpoint with Lambda-based custom identity provider
- **Okta Integration**: User authentication against Okta with optional MFA support
- **Lambda Function**: Custom identity provider that validates Okta credentials and returns Transfer Family configuration
- **DynamoDB Tables**: Stores user configurations and identity provider settings
- **S3 Bucket**: Secure file storage with user-specific directories

## Resources Created

- AWS Transfer Family SFTP server (public endpoint)
- Custom Identity Provider Lambda function (via transfer-custom-idp-solution module)
- DynamoDB tables for users and identity providers configuration
- S3 bucket with versioning and encryption
- IAM roles and policies for Transfer Family session access

## How It Works

1. **User Authentication**: Users authenticate via SFTP using their Okta email and password (with optional MFA)
2. **Lambda Validation**: The Lambda function validates credentials against Okta
3. **DynamoDB Lookup**: Lambda retrieves user configuration from DynamoDB (home directory, IAM role, IP allowlist)
4. **Session Creation**: Transfer Family creates an SFTP session with the returned configuration
5. **File Access**: Users access their dedicated S3 directory based on their username

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.5
- An AWS account with permissions to create the required resources
- Okta account with an existing user for SFTP access

## Setting Up Okta Users and MFA

### Step 1: Add Users in Okta

1. **Log into Okta Admin Console**
   - Navigate to your Okta admin console (e.g., `https://dev-xxxx-admin.okta.com/admin`)

2. **Create a new user:**
   - Go to **Directory** → **People**
   - Click **Add Person**
   - Enter the user details:
     - **Username:** User's email (e.g., `john@example.com`)
     - **Email:** Same as username
     - **Password:** Set a password (user can change on first login)
   - Click **Save**

### Step 2: Create SFTP Group (Optional but Recommended)

1. **Create a group for SFTP users:**
   - Go to **Directory** → **Groups**
   - Click **Add Group**
   - **Group name:** `sftp`
   - Click **Save**

2. **Add user to the group:**
   - Click on the `sftp` group
   - Click **Assign people**
   - Find your user and click the **+** icon next to their name
   - Click **Done**

### Step 3: Enable MFA Authenticator

This example supports **TOTP-based MFA** (Time-based One-Time Password) authenticators supported by Okta.

> [!NOTE]
> Only TOTP-based authenticators are supported. Push-based authenticators cannot be used with AWS Transfer Family.

1. **Add authenticator:**
   - Go to **Security** → **Authenticators**
   - Under the **Setup** tab, click **Add authenticator**
   - Choose your TOTP authenticator (e.g., **Google Authenticator** or **Okta Verify**)
   - Follow the prompts to enable it

2. **Create MFA enrollment policy:**
   - Go to the **Enrollment** tab
   - Click **Add a Policy**
   - **Policy name:** `SFTP Users MFA`
   - **Assign to groups:** Select `sftp` group
   - **Authenticators:** Change your authenticator (e.g., Google Authenticator) to **Required**
   - Click **Create policy**

3. **Add enrollment rule:**
   - In the **Add Rule** dialog that appears:
   - **Rule name:** `SFTP Users MFA Enrollment`
   - Click **Create rule**

### Step 4: Enforce MFA for SFTP Sessions

1. **Create global session policy:**
   - Go to **Security** → **Global Session Policy**
   - Click **Add Policy**
   - **Policy name:** `sftp policy`
   - **Assign to groups:** Add `sftp` group
   - Click **Create policy** and **Add rule**

2. **Configure MFA requirement:**
   - **Rule name:** `sftp rule`
   - **Multifactor authentication (MFA) is:** Select **Required**
   - Click **Create rule**

> [!NOTE]
> **To disable MFA after enabling:** If you've completed Steps 3-4 but want to test without MFA, you must:
> 1. Go to **Security** → **Global Session Policy** → Delete or disable the `sftp policy`
> 2. Go to **Security** → **Authenticators** → **Enrollment** tab → Delete or disable the `SFTP Users MFA` policy
> 3. Set `okta_mfa_required = false` (or omit it) in your terraform.tfvars
>
> Both Okta policies and the Terraform variable must be aligned for authentication to work.

### Step 5: User Enrollment in MFA

If MFA is enabled, end users must enroll in MFA before they can use SFTP:

1. **User logs into Okta:**
   - Open a browser and navigate to your Okta organization URL (e.g., `https://dev-xxxx.okta.com`)
   - Log in with username (email) and password

2. **Enroll in authenticator:**
   - User will be prompted to set up MFA
   - Choose **Set up** under your authenticator (e.g., Google Authenticator or Okta Verify)
   - Scan the QR code with the authenticator app on your phone
   - Enter the verification code to complete setup
   - Click **Continue** to finish sign-in

### Using MFA for SFTP

When MFA is enabled, users authenticate by **concatenating their password with the TOTP code**:

```bash
# If password is "MySecurePass123" and TOTP code is "456789"
# Enter: MySecurePass123456789

sftp user@example.com@server-endpoint
Password: MySecurePass123456789
```

**Important:** There is no separator between the password and TOTP code—they are concatenated directly.

### Enable MFA in Terraform

After configuring MFA in Okta, enable it in your Terraform configuration:

```hcl
# In terraform.tfvars
okta_mfa_required = true
okta_mfa_token_length = 6  # Default: 6 digits
```

> [!TIP]
> Most authenticator apps use 6-digit codes. If your organization uses a different length, adjust `okta_mfa_token_length` accordingly.

## Usage

### 1. Configure Terraform Variables

Create a `terraform.tfvars` file:

```hcl
aws_region     = "us-east-1"
name_prefix    = "sftp-okta-example"

# Okta Configuration
okta_domain     = "your-org-name.okta.com"
okta_user_email = "user@example.com"  # Email of Okta user for SFTP

# Optional: Okta application client ID
# okta_app_client_id = "0oax..."

# Optional: Enable MFA (default: false)
# okta_mfa_required      = true
# okta_mfa_token_length  = 6

# Optional: S3 Encryption (default: AES256)
# s3_encryption_algorithm = "aws:kms"
# s3_kms_key_id          = "arn:aws:kms:us-east-1:123456789012:key/..."

# Optional: IP allowlist for default user (default: 0.0.0.0/0)
# default_user_ipv4_allow_list = ["10.0.0.0/8", "192.168.1.0/24"]

# Optional: Tags for all resources
# tags = {
#   Environment = "demo"
#   Project     = "transfer-family-okta"
# }

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

# Connect via SFTP
# - Without MFA: Use your Okta password
# - With MFA: Use your Okta password + TOTP code (e.g., MyPassword123456)
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

- **MFA Support**: Enable TOTP-based MFA for enhanced security
- **Password Authentication**: Uses existing Okta user passwords (no password storage in AWS)
- **S3 Security**: Bucket has public access blocked and encryption enabled
- **IAM Roles**: Follow least-privilege principles
- **Resource Tagging**: All resources are tagged for tracking and management
- **IP Allowlisting**: Optionally configure IP restrictions per user in DynamoDB

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

> [!IMPORTANT]
> The S3 bucket must be empty before destruction. Remove all files first if needed.

## Troubleshooting

### SFTP Authentication Failures

#### Without MFA

- Verify the Okta user password is correct
- Ensure the user exists in Okta and is active
- Check that the user email matches the configured `okta_user_email`
- Review CloudWatch logs for the Lambda function to see authentication details

#### With MFA Enabled

**"Authentication Failed" with MFA**

- Ensure password and TOTP code are concatenated with no spaces or separators
- Verify the TOTP code is current (codes expire every 30 seconds)
- Check that the user has MFA enrolled in Okta
- Confirm `okta_mfa_token_length` matches your authenticator app's code length

**Example correct format:**

```bash
# Password: MyPass123
# TOTP Code: 456789
# Enter: MyPass123456789  (no spaces, no separators)
```

**Wrong formats:**

- `MyPass123 456789` (space between password and code)
- `MyPass123-456789` (dash separator)
- `MyPass123` (missing TOTP code when MFA is enabled)

### Connection Issues

- Verify the server endpoint is accessible
- Check security groups and network ACLs if using VPC endpoint
- Review CloudWatch logs for the Transfer Family server

## Outputs

- `server_id`: The ID of the Transfer Family server
- `server_endpoint`: The SFTP endpoint to connect to
- `okta_user_email`: Email address of the Okta user
- `okta_domain`: Okta domain for identity provider
- `s3_bucket_name`: Name of the S3 bucket for file storage
- `identity_providers_table_name`: DynamoDB identity providers table name (for testing/verification)
- `users_table_name`: DynamoDB users table name (for testing/verification)
- `lambda_function_name`: Custom identity provider Lambda function name (for debugging)
- `connection_instructions`: Step-by-step connection instructions (adapts based on MFA setting)

## Additional Resources

- [AWS Transfer Family Custom IDP Toolkit](https://github.com/aws-samples/toolkit-for-aws-transfer-family/tree/main/solutions/custom-idp#okta)
- [AWS Transfer Family Documentation](https://docs.aws.amazon.com/transfer/)
- [Okta Authentication API](https://developer.okta.com/docs/reference/api/authn/)
- [Deploy Okta as a custom identity provider for AWS Transfer Family](https://aws.amazon.com/blogs/storage/deploy-okta-as-a-custom-identity-provider-for-aws-transfer-family/)

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.95.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.95.0 |
| <a name="provider_random"></a> [random](#provider\_random) | >= 3.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_custom_idp"></a> [custom\_idp](#module\_custom\_idp) | ../../modules/transfer-custom-idp-solution | n/a |
| <a name="module_s3_bucket"></a> [s3\_bucket](#module\_s3\_bucket) | terraform-aws-modules/s3-bucket/aws | ~> 5.0 |
| <a name="module_transfer_server"></a> [transfer\_server](#module\_transfer\_server) | ../../modules/transfer-server | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_dynamodb_table_item.okta_provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table_item) | resource |
| [aws_dynamodb_table_item.transfer_user_records](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table_item) | resource |
| [aws_iam_role.transfer_session](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.transfer_session_s3](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [random_id.suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [random_pet.name](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/pet) | resource |
| [aws_iam_policy_document.transfer_session_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.transfer_session_s3](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_okta_domain"></a> [okta\_domain](#input\_okta\_domain) | Okta domain (e.g., integrator-7292670.okta.com) | `string` | n/a | yes |
| <a name="input_okta_user_email"></a> [okta\_user\_email](#input\_okta\_user\_email) | Email address of the Okta user for SFTP access | `string` | n/a | yes |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region to deploy resources | `string` | `"us-east-1"` | no |
| <a name="input_default_user_ipv4_allow_list"></a> [default\_user\_ipv4\_allow\_list](#input\_default\_user\_ipv4\_allow\_list) | List of IPv4 CIDR blocks allowed for the default user | `list(string)` | <pre>[<br/>  "0.0.0.0/0"<br/>]</pre> | no |
| <a name="input_enable_deletion_protection"></a> [enable\_deletion\_protection](#input\_enable\_deletion\_protection) | Enable deletion protection for DynamoDB tables | `bool` | `false` | no |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Prefix for resource names | `string` | `"transfer-okta"` | no |
| <a name="input_okta_app_client_id"></a> [okta\_app\_client\_id](#input\_okta\_app\_client\_id) | Okta application client ID for SFTP authentication | `string` | `""` | no |
| <a name="input_okta_mfa_required"></a> [okta\_mfa\_required](#input\_okta\_mfa\_required) | Whether MFA is required for Okta authentication. When enabled, users append their TOTP code to their password (e.g., password123456) | `bool` | `false` | no |
| <a name="input_okta_mfa_token_length"></a> [okta\_mfa\_token\_length](#input\_okta\_mfa\_token\_length) | The number of digits in the MFA token (default is 6 for most authenticator apps) | `number` | `6` | no |
| <a name="input_provision_api"></a> [provision\_api](#input\_provision\_api) | Whether to provision API Gateway instead of Lambda for identity provider | `bool` | `false` | no |
| <a name="input_s3_encryption_algorithm"></a> [s3\_encryption\_algorithm](#input\_s3\_encryption\_algorithm) | S3 server-side encryption algorithm. Use 'AES256' for SSE-S3 or 'aws:kms' for SSE-KMS | `string` | `"AES256"` | no |
| <a name="input_s3_kms_key_id"></a> [s3\_kms\_key\_id](#input\_s3\_kms\_key\_id) | KMS key ID for S3 encryption. Required when s3\_encryption\_algorithm is 'aws:kms' | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to all resources | `map(string)` | <pre>{<br/>  "Environment": "Demo",<br/>  "Project": "Transfer-Okta-IDP"<br/>}</pre> | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_connection_instructions"></a> [connection\_instructions](#output\_connection\_instructions) | Instructions for connecting to the SFTP server |
| <a name="output_identity_providers_table_name"></a> [identity\_providers\_table\_name](#output\_identity\_providers\_table\_name) | Name of the DynamoDB identity providers table |
| <a name="output_lambda_function_name"></a> [lambda\_function\_name](#output\_lambda\_function\_name) | Name of the custom identity provider Lambda function |
| <a name="output_okta_domain"></a> [okta\_domain](#output\_okta\_domain) | Okta domain for identity provider |
| <a name="output_okta_user_email"></a> [okta\_user\_email](#output\_okta\_user\_email) | Email address of the Okta user |
| <a name="output_s3_bucket_name"></a> [s3\_bucket\_name](#output\_s3\_bucket\_name) | Name of the S3 bucket for file storage |
| <a name="output_server_endpoint"></a> [server\_endpoint](#output\_server\_endpoint) | The endpoint of the Transfer Family server |
| <a name="output_server_id"></a> [server\_id](#output\_server\_id) | The ID of the Transfer Family server |
| <a name="output_users_table_name"></a> [users\_table\_name](#output\_users\_table\_name) | Name of the DynamoDB users table |
<!-- END_TF_DOCS -->