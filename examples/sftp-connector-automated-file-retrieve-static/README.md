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

Alternatively, you can use the provided `.envrc` file with [direnv](https://direnv.net/):

```bash
direnv allow
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
terraform output eventbridge_schedule_name

# Manually trigger the scheduler (if supported by AWS CLI)
aws scheduler invoke-schedule --name $(terraform output -raw eventbridge_schedule_name)
```

### Option 3: Check the S3 bucket for retrieved files
```bash
# Get the S3 bucket name from Terraform outputs
terraform output retrieve_bucket_name

# List retrieved files
aws s3 ls s3://$(terraform output -raw retrieve_bucket_name)/retrieved-files/
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
| terraform | >= 1.5 |
| aws | >= 5.95.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| aws_region | AWS region | `string` | `"us-east-1"` | no |
| sftp_server_endpoint | SFTP server endpoint hostname (e.g., example.com) - sftp:// prefix will be added automatically | `string` | n/a | yes |
| existing_secret_arn | ARN of an existing Secrets Manager secret containing SFTP credentials (must contain username and either password or privateKey). If not provided, a new secret will be created. | `string` | `null` | no |
| sftp_username | Username for SFTP authentication (used only if existing_secret_arn is not provided) | `string` | `"sftp-user"` | no |
| sftp_private_key | Private key for SFTP authentication (used only if existing_secret_arn is not provided and sftp_password is not provided) | `string` | `""` | no |
| trusted_host_keys | List of trusted host keys for the SFTP server (required for secure connections) | `list(string)` | `[]` | no |
| connector_id | Existing connector ID to use for file retrieval. If not provided, a new connector will be created. | `string` | `null` | no |
| s3_prefix | S3 prefix to store retrieved files (local directory path) | `string` | `"retrieved-files"` | no |
| eventbridge_schedule | EventBridge schedule expression for automated file retrieval (e.g., 'rate(1 hour)' or 'cron(0 9 * * ? *)') | `string` | `"rate(1 hour)"` | no |
| file_paths_to_retrieve | List of file paths on the remote SFTP server to retrieve | `list(string)` | `["/uploads/report.csv", "/uploads/sample1.txt", "/uploads/sample2.txt"]` | no |
| enable_dynamodb_tracking | Enable DynamoDB table to track file transfer status | `bool` | `false` | no |
| test_connector_post_deployment | Whether to test the connector connection after deployment | `bool` | `false` | no |

## Outputs

| Name | Description |
|------|-------------|
| connector_id | The ID of the SFTP connector |
| connector_arn | The ARN of the SFTP connector |
| retrieve_bucket_name | Name of the S3 bucket for retrieved files |
| retrieve_bucket_arn | ARN of the S3 bucket for retrieved files |
| kms_key_arn | ARN of the KMS key used for encryption |
| eventbridge_schedule_name | Name of the EventBridge schedule |
| eventbridge_schedule_arn | ARN of the EventBridge schedule |
| sftp_credentials_secret_arn | ARN of the Secrets Manager secret containing SFTP credentials |
| dynamodb_table_name | Name of the DynamoDB table for file transfer tracking (if enabled) |
| dynamodb_table_arn | ARN of the DynamoDB table for file transfer tracking (if enabled) |

## Notes

- This example creates resources that may incur AWS charges
- The SFTP server endpoint should be just the hostname (e.g., `example.com`)
- You must provide either an existing secret ARN or credentials to create a new secret
- The connector uses the AWS Transfer Family service to securely connect to the external SFTP server
- EventBridge Scheduler directly initiates file transfers for the specified file paths
- The example uses `TransferSFTPConnectorSecurityPolicy-2024-03` as the security policy for the SFTP connector
- Files are retrieved exactly as specified in the `file_paths_to_retrieve` variable
