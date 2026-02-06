<!-- BEGIN_TF_DOCS -->
# SFTP with Microsoft Entra ID Identity Provider Example

This example demonstrates how to set up AWS Transfer Family SFTP server with a custom identity provider using Microsoft Entra ID for user authentication and AWS Lambda for identity provider logic.

## Architecture

This example creates a complete SFTP solution with Microsoft Entra ID based authentication:

- **Transfer Server**: Public SFTP endpoint with Lambda-based custom identity provider
- **Lambda Function**: Custom identity provider that validates Microsoft Entra ID users and returns Transfer Family configuration
- **DynamoDB Tables**: Stores user configurations and identity provider settings
- **S3 Bucket**: Secure file storage with user-specific directories

## Resources Created

- AWS Transfer Family SFTP server (public endpoint)
- Custom Identity Provider Lambda function (via transfer-custom-idp-solution module)
- DynamoDB tables for users and identity providers configuration
- S3 bucket with versioning and encryption
- IAM roles and policies for Transfer Family session access, Custom Identity Provider Lambda function

## How It Works

1. **User Authentication**: Users authenticate via SFTP using their Microsoft Entra ID username and password
2. **DynamoDB Lookup**: Lambda function looks up username, user configuration (home directory, IAM role, IP allowlist) and identifies the Identity provider associated with the user. It then performs a lookup for the identity provider, retrieves its configuration and establishes a connection with Microsoft Entra ID.
3. **Session Creation**: Transfer Family creates an SFTP session with the returned configuration
4. **File Access**: Users access their dedicated S3 directory based on their username

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

### 3. Test the SFTP Connection

The example uses 2 kinds of Microsoft Entra ID users to demonstrate different behaviors:

#### User 1 (Primary User with Explicit Configuration)

This user has an explicit DynamoDB record with custom home directory mapping:

```bash
# Get the server endpoint
SERVER_ENDPOINT=$(terraform output -raw server_endpoint)

# Get the username
USER=transfer@xyz.onmicrosoft.com

# Connect via SFTP (you'll be prompted for the password)
sftp $USER@$SERVER_ENDPOINT

# Once connected, you'll see the root of the S3 bucket
sftp> ls
# Shows all files in the bucket root
```

#### User 2 (Default Fallback User)

This user has NO explicit DynamoDB record, so it uses the `$default$` configuration:

```bash
# Connect as user2 (User must exist in Microsoft Entra ID application)
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
- **Username**: `transfer@xyz.onmicrosoft.com` (explicit config) or `user2` (default fallback)
- **Password**: User password
- **Port**: 22

**Key Differences:**

- **User 1**: Has full bucket access, sees root directory (`/`)
- **User2**: Has isolated access, sees only their folder (`/home/users/user2/`)
- **User2**: Demonstrates the `$default$` fallback behavior for any authenticated Microsoft Entra ID user without explicit configuration

> [!NOTE]
> Users must be pre-created in Microsoft Entra ID. This example does NOT create users in Microsoft Entra ID.

## User Configuration

The example demonstrates access with two types of users:

1. **Primary User**:
   - No IP restrictions
   - Home directory mapped to root of S3 bucket
   - Full access to entire bucket
   - Authenticates via Microsoft Entra ID credentials

2. **Default Fallback User** (`$default$`):
   - IP allowlist: `0.0.0.0/0` (all IPs - restrict in production)
   - Home directory mapped to user-specific folder: `/home/users/<username>/`
   - Isolated access per authenticated user
   - Catches any authenticated Microsoft Entra ID user not explicitly configured

## DynamoDB Configuration

The example configures DynamoDB items for identity provider and users:

1. **Identity Provider Configuration**:
   - Provider: Name used for referencing the provider in the users table
   - Client ID: The Client ID of the Entra ID application that will be used for authentication and retrieving user profile attributes.
   - App Secret ARN: The ARN of the AWS Secrets Manager secret containing the client secret for the Entra ID application.
   - Authority URL: The authority URL for the Entra ID tenant
   - Module type: `entra`

2. **User Records** (for each user in entra\_usernames list):
   - Username and identity provider key
   - Home directory mappings (virtual to physical paths)
   - IAM role for S3 access
   - IP allowlist (optional, only for default user)

## Security Considerations

- **S3 Encryption**: Bucket uses AES256 server-side encryption
- **Versioning**: S3 versioning is enabled for data protection
- **Public Access**: S3 bucket blocks all public access
- **IP Allowlist**: Default allows all IPs - restrict to specific IPs in production

## Customization

You can customize the deployment by modifying variables:

```hcl
# terraform.tfvars
aws_region         = "us-east-1"
name_prefix        = "my-sftp"
entra_usernames    = ["user@example.onmicrosoft.com"]
entra_provider_name = "example.onmicrosoft.com"
entra_client_id    = "a11aaaa1-1111-1a11-111a-11a11a1a11aa"
entra_authority_url = "https://login.microsoftonline.com/xyz"
entra_client_secret_name = "entra-secret"

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
- `s3_bucket_arn`: S3 bucket ARN for file storage
- `lambda_function_arn`: Custom IDP Lambda function ARN
- `lambda_function_name`: Custom IDP Lambda function name
- `users_table_name`: DynamoDB users table name
- `identity_providers_table_name`: DynamoDB identity providers table name
- `transfer_session_role_arn`: ARN of the Transfer Family session role

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

> [!IMPORTANT]
> The S3 bucket must be empty before destruction. Remove all files first if needed.

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.95.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.6.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.95.0 |
| <a name="provider_random"></a> [random](#provider\_random) | >= 3.6.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_custom_idp"></a> [custom\_idp](#module\_custom\_idp) | ../../modules/transfer-custom-idp-solution | n/a |
| <a name="module_s3_bucket"></a> [s3\_bucket](#module\_s3\_bucket) | terraform-aws-modules/s3-bucket/aws | ~> 4.0 |
| <a name="module_transfer_server"></a> [transfer\_server](#module\_transfer\_server) | ../../modules/transfer-server | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_dynamodb_table_item.entra_provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table_item) | resource |
| [aws_dynamodb_table_item.entra_users](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table_item) | resource |
| [aws_dynamodb_table_item.transfer_user_records](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table_item) | resource |
| [aws_iam_role.transfer_session](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.lambda_secrets_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.transfer_session_s3](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [random_id.suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [random_pet.name](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/pet) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_lambda_function.identity_provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/lambda_function) | data source |
| [aws_secretsmanager_secret.entra_client_secret](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region | `string` | `"us-east-1"` | no |
| <a name="input_enable_deletion_protection"></a> [enable\_deletion\_protection](#input\_enable\_deletion\_protection) | Enable deletion protection for DynamoDB tables | `bool` | `true` | no |
| <a name="input_entra_authority_url"></a> [entra\_authority\_url](#input\_entra\_authority\_url) | Authority URL of existing Entra ID enterprise application | `string` | `null` | no |
| <a name="input_entra_client_id"></a> [entra\_client\_id](#input\_entra\_client\_id) | Client/Application ID of existing Entra ID enterprise application | `string` | `null` | no |
| <a name="input_entra_client_secret_name"></a> [entra\_client\_secret\_name](#input\_entra\_client\_secret\_name) | Name of the AWS Secrets Manager secret containing the Entra ID client secret | `string` | `null` | no |
| <a name="input_entra_provider_name"></a> [entra\_provider\_name](#input\_entra\_provider\_name) | Provider name of existing Entra ID enterprise application | `string` | `null` | no |
| <a name="input_entra_usernames"></a> [entra\_usernames](#input\_entra\_usernames) | Username for the Entra user | `list(string)` | <pre>[<br/>  "user1@example.onmicrosoft.com"<br/>]</pre> | no |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Prefix for resource names | `string` | `"sftp-entra-example"` | no |
| <a name="input_provision_api"></a> [provision\_api](#input\_provision\_api) | Create API Gateway REST API | `bool` | `false` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to all resources | `map(string)` | <pre>{<br/>  "Environment": "demo",<br/>  "Project": "transfer-family-entra"<br/>}</pre> | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_identity_providers_table_name"></a> [identity\_providers\_table\_name](#output\_identity\_providers\_table\_name) | DynamoDB identity providers table name |
| <a name="output_lambda_function_arn"></a> [lambda\_function\_arn](#output\_lambda\_function\_arn) | Custom IDP Lambda function ARN |
| <a name="output_lambda_function_name"></a> [lambda\_function\_name](#output\_lambda\_function\_name) | Custom IDP Lambda function name |
| <a name="output_s3_bucket_arn"></a> [s3\_bucket\_arn](#output\_s3\_bucket\_arn) | ARN of the S3 bucket used for Transfer Family |
| <a name="output_s3_bucket_name"></a> [s3\_bucket\_name](#output\_s3\_bucket\_name) | Name of the S3 bucket used for Transfer Family |
| <a name="output_server_endpoint"></a> [server\_endpoint](#output\_server\_endpoint) | The endpoint of the created Transfer Family server |
| <a name="output_server_id"></a> [server\_id](#output\_server\_id) | The ID of the created Transfer Family server |
| <a name="output_transfer_session_role_arn"></a> [transfer\_session\_role\_arn](#output\_transfer\_session\_role\_arn) | ARN of the Transfer Family session role |
| <a name="output_users_table_name"></a> [users\_table\_name](#output\_users\_table\_name) | DynamoDB users table name |
<!-- END_TF_DOCS -->