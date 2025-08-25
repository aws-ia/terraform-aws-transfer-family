# AWS Transfer Family SFTP Connector Example with EventBridge Integration

This example demonstrates how to use the AWS Transfer Family SFTP connector module to connect an S3 bucket to an external SFTP server, with automatic file transfer triggered directly by EventBridge when files are uploaded to S3.

## Architecture

This example creates:

1. An AWS Transfer Family SFTP server
2. An S3 bucket for file storage with EventBridge notifications enabled
3. A KMS key for encryption
4. An SFTP connector that connects the S3 bucket to an external SFTP server
5. An EventBridge rule that captures S3 object created events
6. A Lambda function that initiates file transfers to the SFTP server using the Transfer Family API

## How It Works

1. When a file is uploaded to the S3 bucket, an S3 event notification is sent to EventBridge
2. EventBridge triggers a Lambda function which calls the AWS Transfer Family StartFileTransfer API
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
| terraform | >= 1.5 |
| aws | >= 5.95.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| aws_region | AWS region | `string` | `"us-east-1"` | no |
| sftp_server_url | URL of the SFTP server to connect to (e.g., sftp://example.com:22) | `string` | n/a | yes |
| existing_secret_arn | ARN of an existing Secrets Manager secret containing SFTP credentials | `string` | `""` | no |
| sftp_username | Username for SFTP authentication (used only if existing_secret_arn is not provided) | `string` | `"sftp-user"` | no |
| sftp_password | Password for SFTP authentication (used only if existing_secret_arn is not provided) | `string` | `""` | no |
| sftp_private_key | Private key for SFTP authentication (used only if existing_secret_arn is not provided) | `string` | `""` | no |
| trust_all_certificates | Whether to trust all certificates for the SFTP connection | `bool` | `false` | no |
| sftp_remote_path | Remote path on the SFTP server where files will be uploaded | `string` | `"/"` | no |

## Outputs

| Name | Description |
|------|-------------|
| server_id | The ID of the created Transfer Family server |
| server_endpoint | The endpoint of the created Transfer Family server |
| sftp_bucket_name | The name of the S3 bucket used for SFTP storage |
| sftp_bucket_arn | The ARN of the S3 bucket used for SFTP storage |
| test_bucket_name | The name of the test S3 bucket for uploading files to trigger SFTP transfers |
| test_bucket_arn | The ARN of the test S3 bucket for uploading files to trigger SFTP transfers |
| connector_id | The ID of the AWS Transfer Family connector |
| connector_arn | The ARN of the AWS Transfer Family connector |
| connector_url | The URL of the SFTP server the connector connects to |
| kms_key_arn | The ARN of the KMS key used for encryption |
| sftp_credentials_secret_arn | The ARN of the Secrets Manager secret containing SFTP credentials |
| eventbridge_rule_arn | The ARN of the EventBridge rule for S3 object created events |
| lambda_function_arn | The ARN of the Lambda function that initiates SFTP transfers |

## Notes

- This example creates resources that may incur AWS charges
- The SFTP server URL should be in the format `sftp://hostname:port`
- You must provide either an existing secret ARN or credentials to create a new secret
- The connector uses the AWS Transfer Family service to securely connect to the external SFTP server
- Lambda function initiates file transfers when S3 objects are created via EventBridge triggers
- The example uses `TransferSFTPConnectorSecurityPolicy-2024-03` as the security policy for the SFTP connector
