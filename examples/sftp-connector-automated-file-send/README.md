<!-- BEGIN_TF_DOCS -->
# AWS Transfer Family SFTP Connector Example with EventBridge Integration

This example demonstrates how to use the AWS Transfer Family SFTP connector module to connect an S3 bucket to an external SFTP server, with automatic file transfer triggered directly by EventBridge when files are uploaded to S3.

## Architecture

This example creates:

1. An AWS Transfer Family SFTP server
2. An S3 bucket for file storage with EventBridge notifications enabled
3. A KMS key for encryption
4. An SFTP connector that connects the S3 bucket to an external SFTP server
5. An EventBridge rule that captures S3 object created events
6. An EventBridge target that directly initiates file transfers to the SFTP server using the Transfer Family API

## How It Works

1. When a file is uploaded to the S3 bucket, an S3 event notification is sent to EventBridge
2. EventBridge directly calls the AWS Transfer Family StartFileTransfer API using the configured IAM role
3. The file is automatically transferred from S3 to the external SFTP server

## SFTP Credentials

This example provides two options for SFTP credentials:

1. **Use an existing Secrets Manager secret** - Provide the ARN of an existing secret containing SFTP credentials
2. **Create a new secret** - Provide username and either password or private key to create a new secret

### Existing Secret Format

If using an existing secret, it must contain credentials in one of these formats:

If using private key authentication:

```json
{
  "Username": "your-sftp-username",
  "PrivateKey": "begin pk"
}
```

## Usage

There are several ways to provide the required variables:

### Option 1: Using terraform.tfvars (Recommended)

Edit the `terraform.tfvars` file with your specific values:

```hcl
aws_region = "us-east-1"
sftp_server_url = "sftp://example.com:22"
# Leave existing_secret_arn empty to create a new secret
existing_secret_arn = ""
sftp_username = "sftp-user"
sftp_password = "your-password"
# sftp_private_key = "your-private-key"  # Uncomment if using private key
sftp_remote_path = "/upload"
trust_all_certificates = false
```

Then simply run:

```bash
terraform init
terraform apply
```

### Option 2: Using Environment Variables

Set the required environment variables:

```bash
export TF_VAR_sftp_server_url="sftp://example.com:22"
# Either provide an existing secret ARN
export TF_VAR_existing_secret_arn="arn:aws:secretsmanager:region:account-id:secret:secret-name"
# Or provide credentials to create a new secret
export TF_VAR_sftp_username="your-username"
export TF_VAR_sftp_password="your-password"
# export TF_VAR_sftp_private_key="$(cat ~/.ssh/id_rsa)"  # Uncomment if using private key
export TF_VAR_sftp_remote_path="/upload"
export TF_VAR_aws_region="us-east-1"

terraform init
terraform apply
```

Alternatively, you can use the provided `.envrc` file with [direnv](https://direnv.net/):

```bash
direnv allow
terraform init
terraform apply
```

### Option 3: Command Line Variables

```bash
terraform init
terraform apply -var="sftp_server_url=sftp://example.com:22" \
                -var="sftp_username=your-username" \
                -var="sftp_password=your-password" \
                -var="sftp_remote_path=/upload" \
                -var="aws_region=us-east-1"
```

## Testing the Integration

After deploying the infrastructure, you can test the automatic file transfer by uploading a file to either S3 bucket:

### Option 1: Upload to the test bucket (recommended for testing)

```bash
# Get the test bucket name from Terraform outputs
terraform output test_bucket_name

# Upload a test file
aws s3 cp test-file.txt s3://$(terraform output -raw test_bucket_name)/
```

### Option 2: Upload to the main SFTP bucket

```bash
# Get the main bucket name from Terraform outputs
terraform output sftp_bucket_name

# Upload a test file
aws s3 cp test-file.txt s3://$(terraform output -raw sftp_bucket_name)/
```

The file should be automatically transferred to the external SFTP server at the specified remote path.

### Monitoring the Transfer

You can monitor the transfer process by checking:

1. **CloudWatch Logs** for the Lambda function:

   ```bash
   aws logs describe-log-groups --log-group-name-prefix "/aws/lambda/sftp-transfer"
   ```

2. **Transfer Family console** to see transfer history

3. **EventBridge console** to see rule invocations

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5 |
| <a name="requirement_archive"></a> [archive](#requirement\_archive) | >= 2.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.95.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.1 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_archive"></a> [archive](#provider\_archive) | >= 2.0 |
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.95.0 |
| <a name="provider_random"></a> [random](#provider\_random) | >= 3.1 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_sftp_connector"></a> [sftp\_connector](#module\_sftp\_connector) | ../../modules/transfer-connectors | n/a |
| <a name="module_test_s3_bucket"></a> [test\_s3\_bucket](#module\_test\_s3\_bucket) | git::https://github.com/terraform-aws-modules/terraform-aws-s3-bucket.git | 179576ca9e3d524f09370ff643ea80a0f753cdd7 |

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_event_rule.s3_object_created](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) | resource |
| [aws_cloudwatch_event_target.lambda_target](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_iam_policy.connector_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.lambda_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.connector_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.lambda_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.connector_policy_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.lambda_policy_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_kms_alias.transfer_family_key_alias](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.transfer_family_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_kms_key_policy.transfer_family_key_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key_policy) | resource |
| [aws_lambda_code_signing_config.lambda_code_signing](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_code_signing_config) | resource |
| [aws_lambda_function.sftp_transfer](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_permission.allow_eventbridge](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_s3_bucket_notification.test_bucket_notification](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_notification) | resource |
| [aws_signer_signing_profile.lambda_signing_profile](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/signer_signing_profile) | resource |
| [aws_sqs_queue.lambda_dlq](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue) | resource |
| [random_id.suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [random_pet.name](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/pet) | resource |
| [archive_file.lambda_zip](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.lambda_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_kms_key.existing](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/kms_key) | data source |
| [aws_secretsmanager_secret.existing](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_sftp_server_endpoint"></a> [sftp\_server\_endpoint](#input\_sftp\_server\_endpoint) | SFTP server endpoint hostname (e.g., s-1234567890abcdef0.server.transfer.us-east-1.amazonaws.com or example.com) - sftp:// prefix will be added automatically | `string` | n/a | yes |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region | `string` | `"us-east-1"` | no |
| <a name="input_existing_secret_arn"></a> [existing\_secret\_arn](#input\_existing\_secret\_arn) | ARN of an existing Secrets Manager secret containing SFTP credentials (must contain username and either password or privateKey). If not provided, a new secret will be created. | `string` | `null` | no |
| <a name="input_sftp_private_key"></a> [sftp\_private\_key](#input\_sftp\_private\_key) | Private key for SFTP authentication (used only if existing\_secret\_arn is not provided and sftp\_password is not provided) | `string` | `""` | no |
| <a name="input_sftp_username"></a> [sftp\_username](#input\_sftp\_username) | Username for SFTP authentication (used only if existing\_secret\_arn is not provided) | `string` | `""` | no |
| <a name="input_test_connector_post_deployment"></a> [test\_connector\_post\_deployment](#input\_test\_connector\_post\_deployment) | Whether to test the connector connection after deployment | `bool` | `false` | no |
| <a name="input_trusted_host_keys"></a> [trusted\_host\_keys](#input\_trusted\_host\_keys) | List of trusted host keys for the SFTP server (required for secure connections) | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_connector_arn"></a> [connector\_arn](#output\_connector\_arn) | The ARN of the AWS Transfer Family connector |
| <a name="output_connector_id"></a> [connector\_id](#output\_connector\_id) | The ID of the AWS Transfer Family connector |
| <a name="output_connector_static_ips"></a> [connector\_static\_ips](#output\_connector\_static\_ips) | Static IP addresses of the SFTP connector |
| <a name="output_connector_url"></a> [connector\_url](#output\_connector\_url) | The URL of the SFTP server the connector connects to |
| <a name="output_eventbridge_rule_arn"></a> [eventbridge\_rule\_arn](#output\_eventbridge\_rule\_arn) | The ARN of the EventBridge rule for S3 object created events |
| <a name="output_kms_key_arn"></a> [kms\_key\_arn](#output\_kms\_key\_arn) | The ARN of the KMS key used for encryption |
| <a name="output_lambda_function_arn"></a> [lambda\_function\_arn](#output\_lambda\_function\_arn) | The ARN of the Lambda function that initiates SFTP transfers |
| <a name="output_test_bucket_arn"></a> [test\_bucket\_arn](#output\_test\_bucket\_arn) | The ARN of the test S3 bucket for uploading files to trigger SFTP transfers |
| <a name="output_test_bucket_name"></a> [test\_bucket\_name](#output\_test\_bucket\_name) | The name of the test S3 bucket for uploading files to trigger SFTP transfers |
<!-- END_TF_DOCS -->