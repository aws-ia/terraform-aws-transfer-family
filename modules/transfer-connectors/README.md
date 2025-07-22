# AWS Transfer Family SFTP Connector Module

This module creates an AWS Transfer Family SFTP connector that connects an S3 bucket to an external SFTP server.

## Features

- Creates an AWS Transfer Family SFTP connector
- Sets up necessary IAM roles and policies for the connector
- Configures CloudWatch logging for the connector
- Supports AS2 configuration for secure file transfers
- Manages SFTP connection settings and security policies

## Usage

```hcl
module "sftp_connector" {
  source = "aws-ia/transfer-family/aws//modules/transfer-connectors"

  connector_name        = "my-sftp-connector"
  sftp_server_url       = "sftp://example.com:22"
  s3_bucket_arn         = module.s3_bucket.s3_bucket_arn
  s3_bucket_name        = module.s3_bucket.s3_bucket_id
  user_secret_id        = aws_secretsmanager_secret.sftp_credentials.arn
  kms_key_arn           = aws_kms_key.transfer_family_key.arn
  aws_region            = var.aws_region
  trust_all_certificates = false
  security_policy_name  = "TransferSecurityPolicy-2024-01"

  tags = {
    Environment = "Production"
    Project     = "File Transfer"
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5 |
| aws | >= 5.95.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| connector_name | Name of the AWS Transfer Family connector | `string` | `"sftp-connector"` | no |
| sftp_server_url | URL of the SFTP server to connect to (e.g., sftp://example.com:22) | `string` | n/a | yes |
| s3_bucket_arn | ARN of the S3 bucket to connect to the SFTP server | `string` | n/a | yes |
| s3_bucket_name | Name of the S3 bucket to connect to the SFTP server | `string` | n/a | yes |
| user_secret_id | ARN of the AWS Secrets Manager secret containing SFTP credentials | `string` | n/a | yes |
| as2_username | Username for AS2 basic authentication | `string` | `""` | no |
| as2_password | Password for AS2 basic authentication | `string` | `""` | no |
| trust_all_certificates | Whether to trust all certificates for the SFTP connection | `bool` | `false` | no |
| security_policy_name | The name of the security policy to use for the connector | `string` | `"TransferSecurityPolicy-2024-01"` | no |
| logging_role | IAM role ARN for CloudWatch logging (if not provided, a new role will be created) | `string` | `null` | no |
| kms_key_arn | ARN of the KMS key used for encryption | `string` | n/a | yes |
| aws_region | AWS region where resources will be created | `string` | n/a | yes |
| tags | A map of tags to assign to resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| connector_id | The ID of the AWS Transfer Family connector |
| connector_arn | The ARN of the AWS Transfer Family connector |
| connector_url | The URL of the SFTP server the connector connects to |
| connector_role_arn | The ARN of the IAM role used by the connector |
| connector_logging_role_arn | The ARN of the IAM role used for connector logging (if created) |

## Security Considerations

- The module creates IAM roles with least privilege permissions
- Secrets for SFTP authentication are stored in AWS Secrets Manager
- KMS encryption is used for securing sensitive data
- Security policies can be configured to enforce secure connections
