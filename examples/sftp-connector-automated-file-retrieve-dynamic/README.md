# AWS Transfer Family SFTP Connector Example with Dynamic File Discovery

This example demonstrates how to use the AWS Transfer Family SFTP connector module to automatically discover and retrieve files from an external SFTP server on a scheduled basis using EventBridge Scheduler and Lambda for dynamic file discovery.

## Architecture

This example creates:

1. An AWS Transfer Family SFTP connector that connects to an external SFTP server
2. An S3 bucket for storing retrieved files with KMS encryption
3. A KMS key for encryption of all resources
4. A Lambda function that dynamically discovers files in the remote directory
5. An EventBridge Scheduler that triggers the Lambda function on a configurable schedule
6. Optional DynamoDB table for tracking file transfer status and metadata
7. SQS Dead Letter Queue for Lambda error handling
8. Lambda code signing configuration for enhanced security
9. IAM roles and policies for secure access between services

## How It Works

1. EventBridge Scheduler runs on the configured schedule (e.g., hourly, daily)
2. The scheduler triggers a Lambda function that uses the Transfer Family API to list files in the remote directory
3. The Lambda function dynamically discovers available files and initiates transfers for each file
4. Files are automatically retrieved from the external SFTP server and stored in the S3 bucket
5. Optional DynamoDB logging tracks transfer status and metadata for each file
6. Failed Lambda executions are sent to the SQS Dead Letter Queue for investigation

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
source_directory = "/uploads"
eventbridge_schedule = "rate(1 hour)"
s3_prefix = "retrieved-files"
enable_dynamodb_tracking = true
test_connector_post_deployment = true
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
export TF_VAR_source_directory="/uploads"
export TF_VAR_eventbridge_schedule="rate(1 hour)"
export TF_VAR_enable_dynamodb_tracking="true"
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
                -var="source_directory=/uploads" \
                -var="eventbridge_schedule=rate(1 hour)" \
                -var="enable_dynamodb_tracking=true" \
                -var="aws_region=us-east-1"
```

## Testing the Integration

After deploying the infrastructure, you can test the dynamic file discovery and retrieval:

### Option 1: Wait for the scheduled discovery
The EventBridge Scheduler will automatically trigger the Lambda function based on your configured schedule.

### Option 2: Manually invoke the Lambda function
```bash
# Get the Lambda function name from Terraform outputs
terraform output lambda_function_name

# Manually invoke the Lambda function
aws lambda invoke --function-name $(terraform output -raw lambda_function_name) response.json
cat response.json
```

### Option 3: Check the S3 bucket for retrieved files
```bash
# Get the S3 bucket name from Terraform outputs
terraform output s3_bucket_name

# List retrieved files
aws s3 ls s3://$(terraform output -raw s3_bucket_name)/retrieved-files/ --recursive
```

### Monitoring the Discovery and Retrieval

You can monitor the discovery and retrieval process by checking:

1. **Lambda CloudWatch Logs** to see file discovery and transfer initiation:
   ```bash
   # Get the Lambda function name from Terraform outputs
   terraform output lambda_function_name
   
   # View recent logs
   aws logs describe-log-groups --log-group-name-prefix "/aws/lambda/$(terraform output -raw lambda_function_name)"
   ```

2. **Transfer Family console** to see transfer history and connector status

3. **S3 bucket** to verify files are being retrieved and stored

4. **EventBridge Scheduler console** to see schedule execution history

5. **DynamoDB table** (if enabled) to track transfer metadata:
   ```bash
   # Get the DynamoDB table name from Terraform outputs (if enabled)
   terraform output dynamodb_table_name
   
   # Query transfer records
   aws dynamodb scan --table-name $(terraform output -raw dynamodb_table_name)
   ```

6. **SQS Dead Letter Queue** for any Lambda execution failures:
   ```bash
   # Get the DLQ name from Terraform outputs
   terraform output dlq_name
   
   # Check for failed messages
   aws sqs receive-message --queue-url $(terraform output -raw dlq_url)
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
| source_directory | Source directory path on remote server to scan for files | `string` | `"/uploads"` | no |
| enable_dynamodb_tracking | Enable DynamoDB tracking for file transfers | `bool` | `false` | no |
| test_connector_post_deployment | Whether to test the connector connection after deployment | `bool` | `true` | no |

## Outputs

| Name | Description |
|------|-------------|
| s3_bucket_name | The name of the S3 bucket used for storing retrieved files |
| s3_bucket_arn | The ARN of the S3 bucket used for storing retrieved files |
| connector_id | The ID of the AWS Transfer Family connector |
| connector_arn | The ARN of the AWS Transfer Family connector |
| connector_url | The URL of the SFTP server the connector connects to |
| kms_key_arn | The ARN of the KMS key used for encryption |
| sftp_credentials_secret_arn | The ARN of the Secrets Manager secret containing SFTP credentials |
| lambda_function_name | The name of the Lambda function for file discovery |
| lambda_function_arn | The ARN of the Lambda function for file discovery |
| scheduler_name | The name of the EventBridge Scheduler |
| scheduler_arn | The ARN of the EventBridge Scheduler |
| dynamodb_table_name | The name of the DynamoDB table for tracking transfers (if enabled) |
| dynamodb_table_arn | The ARN of the DynamoDB table for tracking transfers (if enabled) |
| dlq_name | The name of the SQS Dead Letter Queue |
| dlq_url | The URL of the SQS Dead Letter Queue |

## Notes

- This example creates resources that may incur AWS charges
- The SFTP server endpoint should be just the hostname (e.g., `example.com`)
- You must provide either an existing secret ARN or credentials to create a new secret
- The connector uses the AWS Transfer Family service to securely connect to the external SFTP server
- Lambda function dynamically discovers files in the source directory and initiates transfers
- The example uses `TransferSFTPConnectorSecurityPolicy-2024-03` as the security policy for the SFTP connector
- Lambda code signing is enabled for enhanced security
- Failed Lambda executions are sent to the SQS Dead Letter Queue for investigation
