# AWS Transfer Family SFTP Connector Example with EventBridge Integration

This example demonstrates how to use the AWS Transfer Family SFTP connector module to connect an S3 bucket to an external SFTP server, with automatic file transfer triggered directly by EventBridge when files are uploaded to S3.

## Architecture

This example creates:

1. An AWS Transfer Family SFTP server
2. An S3 bucket for file storage with EventBridge notifications enabled
3. A KMS key for encryption
4. A Secrets Manager secret for SFTP credentials
5. An SFTP connector that connects the S3 bucket to an external SFTP server
6. An EventBridge rule that captures S3 object created events
7. An EventBridge target that directly initiates file transfers to the SFTP server using the Transfer Family API

## How It Works

1. When a file is uploaded to the S3 bucket, an S3 event notification is sent to EventBridge
2. EventBridge directly calls the AWS Transfer Family StartFileTransfer API using the configured IAM role
3. The file is automatically transferred from S3 to the external SFTP server

## Usage

To run this example, you need to provide the following variables:

```bash
terraform init
terraform apply -var="sftp_server_url=sftp://example.com:22" \
                -var="sftp_username=your-username" \
                -var="sftp_password=your-password" \
                -var="sftp_remote_path=/upload" \
                -var="aws_region=us-east-1"
```

Alternatively, you can use a private key for authentication:

```bash
terraform init
terraform apply -var="sftp_server_url=sftp://example.com:22" \
                -var="sftp_username=your-username" \
                -var="sftp_private_key=$(cat ~/.ssh/id_rsa)" \
                -var="sftp_remote_path=/upload" \
                -var="aws_region=us-east-1"
```

## Testing the Integration

After deploying the infrastructure, you can test the automatic file transfer by uploading a file to the S3 bucket:

```bash
aws s3 cp test-file.txt s3://your-bucket-name/
```

The file should be automatically transferred to the external SFTP server at the specified remote path.

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
| sftp_username | Username for SFTP authentication | `string` | n/a | yes |
| sftp_password | Password for SFTP authentication | `string` | `""` | no |
| sftp_private_key | Private key for SFTP authentication | `string` | `""` | no |
| trust_all_certificates | Whether to trust all certificates for the SFTP connection | `bool` | `false` | no |
| sftp_remote_path | Remote path on the SFTP server where files will be uploaded | `string` | `"/"` | no |

## Outputs

| Name | Description |
|------|-------------|
| server_id | The ID of the created Transfer Family server |
| server_endpoint | The endpoint of the created Transfer Family server |
| sftp_bucket_name | The name of the S3 bucket used for SFTP storage |
| sftp_bucket_arn | The ARN of the S3 bucket used for SFTP storage |
| connector_id | The ID of the AWS Transfer Family connector |
| connector_arn | The ARN of the AWS Transfer Family connector |
| connector_url | The URL of the SFTP server the connector connects to |
| kms_key_arn | The ARN of the KMS key used for encryption |
| sftp_credentials_secret_arn | The ARN of the Secrets Manager secret containing SFTP credentials |
| eventbridge_rule_arn | The ARN of the EventBridge rule for S3 object created events |
| eventbridge_role_arn | The ARN of the IAM role used by EventBridge to initiate SFTP transfers |

## Notes

- This example creates resources that may incur AWS charges
- The SFTP server URL should be in the format `sftp://hostname:port`
- You must provide either a password or a private key for SFTP authentication
- The connector uses the AWS Transfer Family service to securely connect to the external SFTP server
- EventBridge directly calls the Transfer Family API to initiate file transfers without using Lambda
