<!-- BEGIN_TF_DOCS -->
# AWS Transfer Family SFTP Connector Example with Automated File Retrieval

This example demonstrates how to use the AWS Transfer Family SFTP connector module to automatically retrieve specific files from an external SFTP server on a scheduled basis using EventBridge Scheduler.

## Architecture

This example creates:

1. An AWS Transfer Family SFTP connector that connects to an external SFTP server
2. An S3 bucket for storing retrieved files with KMS encryption
3. A KMS key for encryption of all resources
4. An EventBridge Scheduler that automatically triggers file retrieval on a configurable schedule
5. Optional DynamoDB table for tracking file transfer status and metadata
6. IAM roles and policies for secure access between services

## How It Works

1. EventBridge Scheduler runs on the configured schedule (e.g., hourly, daily)
2. The scheduler directly calls the AWS Transfer Family StartFileTransfer API using the configured IAM role
3. The connector retrieves the specified files from the external SFTP server
4. Files are automatically stored in the S3 bucket with the configured prefix
5. Optional DynamoDB logging tracks transfer status and metadata

## SFTP Credentials

This example provides two options for SFTP credentials:

1. **Use an existing Secrets Manager secret** - Provide the ARN of an existing secret containing SFTP credentials
2. **Create a new secret** - Provide username and private key to create a new secret

### Existing Secret Format

If using an existing secret, it must contain credentials in this format:

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
sftp_server_endpoint = "example.com"
# Leave existing_secret_arn empty to create a new secret
existing_secret_arn = ""
sftp_username = "sftp-user"
sftp_private_key = "begin pk"
trusted_host_keys = ["ssh-rsa AAAAB3NzaC1yc2EAAAA..."]
file_paths_to_retrieve = ["/uploads/report.csv", "/data/file1.txt"]
eventbridge_schedule = "rate(1 hour)"
s3_prefix = "retrieved-files"
enable_dynamodb_tracking = false
```

Then simply run:

```bash
terraform init
terraform apply
```

### Option 2: Using Environment Variables

Set the required environment variables:

```bash
export TF_VAR_sftp_server_endpoint="example.com"
# Either provide an existing secret ARN
export TF_VAR_existing_secret_arn="arn:aws:secretsmanager:region:account-id:secret:secret-name"
# Or provide credentials to create a new secret
export TF_VAR_sftp_username="your-username"
export TF_VAR_sftp_private_key="$(cat ~/.ssh/id_rsa)"
export TF_VAR_trusted_host_keys='["ssh-rsa AAAAB3NzaC1yc2EAAAA..."]'
export TF_VAR_file_paths_to_retrieve='["/uploads/report.csv", "/data/file1.txt"]'
export TF_VAR_eventbridge_schedule="rate(1 hour)"
export TF_VAR_aws_region="us-east-1"

terraform init
terraform apply
```

### Option 3: Command Line Variables

```bash
terraform init
terraform apply -var="sftp_server_endpoint=example.com" \
                -var="sftp_username=your-username" \
                -var="sftp_private_key=$(cat ~/.ssh/id_rsa)" \
                -var='trusted_host_keys=["ssh-rsa AAAAB3NzaC1yc2EAAAA..."]' \
                -var='file_paths_to_retrieve=["/uploads/report.csv"]' \
                -var="eventbridge_schedule=rate(1 hour)" \
                -var="aws_region=us-east-1"
```

## Testing the Integration

After deploying the infrastructure, you can test the automatic file retrieval:

### Option 1: Wait for the scheduled retrieval

The EventBridge Scheduler will automatically trigger file retrieval based on your configured schedule.

### Option 2: Manually trigger the scheduler

```bash
# Get the scheduler name from Terraform outputs
terraform output scheduler_name

# Manually trigger the scheduler (if supported by AWS CLI)
aws scheduler invoke-schedule --name $(terraform output -raw scheduler_name)
```

### Option 3: Check the S3 bucket for retrieved files

```bash
# Get the S3 bucket name from Terraform outputs
terraform output s3_bucket_name

# List retrieved files
aws s3 ls s3://$(terraform output -raw s3_bucket_name)/retrieved-files/
```

### Monitoring the Retrieval

You can monitor the retrieval process by checking:

1. **Transfer Family console** to see transfer history and connector status

2. **S3 bucket** to verify files are being retrieved and stored

3. **EventBridge Scheduler console** to see schedule execution history

4. **DynamoDB table** (if enabled) to track transfer metadata:

   ```bash
   # Get the DynamoDB table name from Terraform outputs (if enabled)
   terraform output dynamodb_table_name

   # Query transfer records
   aws dynamodb scan --table-name $(terraform output -raw dynamodb_table_name)
   ```

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.10.0 |
| <a name="requirement_archive"></a> [archive](#requirement\_archive) | >= 2.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.95.0 |
| <a name="requirement_awscc"></a> [awscc](#requirement\_awscc) | >= 0.24.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_archive"></a> [archive](#provider\_archive) | >= 2.0 |
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.95.0 |
| <a name="provider_random"></a> [random](#provider\_random) | >= 3.0.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_retrieve_s3_bucket"></a> [retrieve\_s3\_bucket](#module\_retrieve\_s3\_bucket) | terraform-aws-modules/s3-bucket/aws | ~> 4.0 |
| <a name="module_sftp_connector"></a> [sftp\_connector](#module\_sftp\_connector) | ../../modules/transfer-connectors | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_event_rule.transfer_events](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) | resource |
| [aws_cloudwatch_event_target.event_listener_target](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_dynamodb_table.file_transfer_tracking](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table) | resource |
| [aws_iam_policy.connector_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.dynamodb_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.connector_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.event_listener_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.scheduler_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.status_checker_scheduler_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.event_listener_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.scheduler_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.status_checker_scheduler_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.connector_policy_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.scheduler_dynamodb_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_kms_alias.transfer_family_key_alias](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.transfer_family_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_kms_key_policy.transfer_family_key_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key_policy) | resource |
| [aws_lambda_function.event_listener](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_permission.allow_eventbridge_event_listener](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_lambda_permission.allow_scheduler_status_checker](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_scheduler_schedule.dynamodb_logging](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/scheduler_schedule) | resource |
| [aws_scheduler_schedule.sftp_retrieve_direct](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/scheduler_schedule) | resource |
| [aws_scheduler_schedule.status_checker](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/scheduler_schedule) | resource |
| [aws_sqs_queue.dlq](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue) | resource |
| [random_id.suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [random_pet.name](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/pet) | resource |
| [archive_file.event_listener_zip](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_kms_key.existing](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/kms_key) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_secretsmanager_secret.existing](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_sftp_server_endpoint"></a> [sftp\_server\_endpoint](#input\_sftp\_server\_endpoint) | SFTP server endpoint hostname (e.g., example.com) - sftp:// prefix will be added automatically | `string` | n/a | yes |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region | `string` | `"us-east-1"` | no |
| <a name="input_enable_dynamodb_tracking"></a> [enable\_dynamodb\_tracking](#input\_enable\_dynamodb\_tracking) | Enable DynamoDB tracking for file transfers | `bool` | `true` | no |
| <a name="input_eventbridge_schedule"></a> [eventbridge\_schedule](#input\_eventbridge\_schedule) | EventBridge schedule expression for automated file retrieval (e.g., 'rate(1 hour)' or 'cron(0 9 * * ? *)') | `string` | `"rate(1 minute)"` | no |
| <a name="input_existing_secret_arn"></a> [existing\_secret\_arn](#input\_existing\_secret\_arn) | ARN of an existing Secrets Manager secret containing SFTP credentials (must contain username and either password or privateKey). If not provided, a new secret will be created. | `string` | `null` | no |
| <a name="input_file_paths_to_retrieve"></a> [file\_paths\_to\_retrieve](#input\_file\_paths\_to\_retrieve) | List of file paths on the remote SFTP server to retrieve | `list(string)` | <pre>[<br/>  "/uploads/report.csv",<br/>  "/uploads/sample1.txt",<br/>  "/uploads/sample2.txt"<br/>]</pre> | no |
| <a name="input_s3_prefix"></a> [s3\_prefix](#input\_s3\_prefix) | S3 prefix to store retrieved files (local directory path) | `string` | `"retrieved-files"` | no |
| <a name="input_sftp_private_key"></a> [sftp\_private\_key](#input\_sftp\_private\_key) | Private key for SFTP authentication (used only if existing\_secret\_arn is not provided and sftp\_password is not provided) | `string` | `""` | no |
| <a name="input_sftp_username"></a> [sftp\_username](#input\_sftp\_username) | Username for SFTP authentication (used only if existing\_secret\_arn is not provided) | `string` | `"sftp-user"` | no |
| <a name="input_test_connector_post_deployment"></a> [test\_connector\_post\_deployment](#input\_test\_connector\_post\_deployment) | Whether to test the connector connection after deployment | `bool` | `false` | no |
| <a name="input_trusted_host_keys"></a> [trusted\_host\_keys](#input\_trusted\_host\_keys) | List of trusted host keys for the SFTP server (required for secure connections) | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_connector_arn"></a> [connector\_arn](#output\_connector\_arn) | The ARN of the SFTP connector |
| <a name="output_connector_id"></a> [connector\_id](#output\_connector\_id) | The ID of the SFTP connector |
| <a name="output_connector_static_ips"></a> [connector\_static\_ips](#output\_connector\_static\_ips) | Static IP addresses of the SFTP connector |
| <a name="output_dynamodb_table_arn"></a> [dynamodb\_table\_arn](#output\_dynamodb\_table\_arn) | ARN of the DynamoDB table for file transfer tracking (if enabled) |
| <a name="output_dynamodb_table_name"></a> [dynamodb\_table\_name](#output\_dynamodb\_table\_name) | Name of the DynamoDB table for file transfer tracking (if enabled) |
| <a name="output_eventbridge_schedule_arn"></a> [eventbridge\_schedule\_arn](#output\_eventbridge\_schedule\_arn) | ARN of the EventBridge schedule |
| <a name="output_eventbridge_schedule_name"></a> [eventbridge\_schedule\_name](#output\_eventbridge\_schedule\_name) | Name of the EventBridge schedule |
| <a name="output_kms_key_arn"></a> [kms\_key\_arn](#output\_kms\_key\_arn) | ARN of the KMS key used for encryption |
| <a name="output_retrieve_bucket_arn"></a> [retrieve\_bucket\_arn](#output\_retrieve\_bucket\_arn) | ARN of the S3 bucket for retrieved files |
| <a name="output_retrieve_bucket_name"></a> [retrieve\_bucket\_name](#output\_retrieve\_bucket\_name) | Name of the S3 bucket for retrieved files |
| <a name="output_sftp_credentials_secret_arn"></a> [sftp\_credentials\_secret\_arn](#output\_sftp\_credentials\_secret\_arn) | ARN of the Secrets Manager secret containing SFTP credentials |
<!-- END_TF_DOCS -->