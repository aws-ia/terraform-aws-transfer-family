# AWS Transfer Family SFTP Connector Module

This Terraform module creates an AWS Transfer Family SFTP connector that enables secure file transfers between an S3 bucket and an external SFTP server.

## Features

- **SFTP Connector Creation**: Creates AWS Transfer Family SFTP connector with configurable settings
- **Secrets Management**: Automatically creates and manages AWS Secrets Manager secret for SFTP credentials
- **IAM Role Automation**: Creates necessary IAM roles for S3 access and logging (or uses provided roles)
- **Host Key Management**: Supports both manual trusted host key configuration and automatic discovery
- **Security**: Configurable security policies and KMS encryption support
- **Logging**: CloudWatch logging integration with automated IAM role creation

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   External      │    │  AWS Transfer    │    │   Amazon S3     │
│   SFTP Server   │◄──►│  Family          │◄──►│   Bucket        │
│                 │    │  Connector       │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                              │
                              ▼
                       ┌──────────────────┐
                       │  AWS Secrets     │
                       │  Manager         │
                       │  (Credentials)   │
                       └──────────────────┘
```

## Usage

### Basic Usage with Auto-Discovery

```hcl
module "sftp_connector" {
  source = "../../modules/transfer-connectors"

  connector_name    = "my-sftp-connector"
  sftp_server_url   = "sftp://external-server.example.com:22"
  s3_bucket_arn     = "arn:aws:s3:::my-transfer-bucket"
  
  # SFTP Authentication
  sftp_username     = "myuser"
  sftp_password     = "mypassword"
  
  # Auto-discover host keys (default)
  auto_discover_host_keys = true
  
  tags = {
    Environment = "production"
    Project     = "file-transfer"
  }
}
```

### Advanced Usage with Manual Host Keys

```hcl
module "sftp_connector" {
  source = "../../modules/transfer-connectors"

  connector_name    = "my-sftp-connector"
  sftp_server_url   = "sftp://external-server.example.com:2222"
  s3_bucket_arn     = "arn:aws:s3:::my-transfer-bucket"
  
  # SFTP Authentication
  sftp_username     = "myuser"
  sftp_password     = var.sftp_password  # Use variable for sensitive data
  
  # Manual host key configuration
  auto_discover_host_keys = false
  trusted_host_keys = [
    "ssh-rsa AAAAB3NzaC1yc2EAAAA...",
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA..."
  ]
  
  # Custom settings
  max_concurrent_connections = 5
  security_policy_name      = "TransferSecurityPolicy-2024-01"
  
  # Use existing IAM roles
  s3_access_role_arn = "arn:aws:iam::123456789012:role/existing-s3-role"
  logging_role_arn   = "arn:aws:iam::123456789012:role/existing-logging-role"
  
  # KMS encryption
  kms_key_arn = "arn:aws:kms:REGION:ACCOUNT_ID:key/KEY_ID"
  
  tags = {
    Environment = "production"
    Project     = "file-transfer"
    Owner       = "data-team"
  }
}
```

## Host Key Management

### Auto-Discovery (Recommended for Development)

When `auto_discover_host_keys = true` and no `trusted_host_keys` are provided, the module will:

1. Create the SFTP connector without host keys
2. Use the AWS Transfer Family `test-connection` API to discover host keys
3. Update the connector with the discovered host keys

```hcl
# Auto-discovery configuration
auto_discover_host_keys = true
trusted_host_keys      = []  # Leave empty for auto-discovery
```

### Manual Configuration (Recommended for Production)

For production environments, it's recommended to manually specify trusted host keys:

```hcl
# Manual host key configuration
auto_discover_host_keys = false
trusted_host_keys = [
  "ssh-rsa AAAAB3NzaC1yc2EAAAA...",
  "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA..."
]
```

To get host keys manually:
```bash
ssh-keyscan -p 22 external-server.example.com
```

## IAM Roles

### Automatic Role Creation (Default)

The module automatically creates IAM roles with appropriate permissions:

- **S3 Access Role**: Permissions for S3 bucket operations and Secrets Manager access
- **Logging Role**: CloudWatch logging permissions using AWS managed policy

### Using Existing Roles

You can provide existing IAM role ARNs:

```hcl
s3_access_role_arn = "arn:aws:iam::123456789012:role/my-existing-s3-role"
logging_role_arn   = "arn:aws:iam::123456789012:role/my-existing-logging-role"
```

Required permissions for S3 access role:
- `s3:ListBucket` on the target bucket
- `s3:GetObject`, `s3:PutObject`, `s3:DeleteObject` on bucket objects
- `secretsmanager:GetSecretValue` on the credentials secret
- `kms:Decrypt`, `kms:GenerateDataKey` (if using KMS)

## Security Considerations

1. **Credentials**: SFTP passwords are stored securely in AWS Secrets Manager
2. **Encryption**: Use KMS keys for encrypting secrets and S3 objects
3. **Host Keys**: Use manual host key configuration in production
4. **IAM**: Follow principle of least privilege for IAM roles
5. **Security Policies**: Use the latest Transfer Family security policies

## Troubleshooting

### Connection Issues

1. **Check SFTP server accessibility**: Ensure the SFTP server is reachable from AWS
2. **Verify credentials**: Check the Secrets Manager secret contains correct username/password
3. **Host key mismatch**: Verify trusted host keys match the SFTP server's keys
4. **Security groups**: Ensure AWS Transfer Family can reach the external SFTP server

### Auto-Discovery Issues

If auto-discovery fails:
1. Check AWS CLI is available in the Terraform execution environment
2. Verify AWS credentials have permissions for Transfer Family operations
3. Ensure the SFTP server accepts connections for host key discovery
4. Consider using manual host key configuration as fallback

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5 |
| aws | >= 5.95.0 |

## Providers

| Name | Version |
|------|---------|
| aws | >= 5.95.0 |

## Resources

| Name | Type |
|------|------|
| aws_secretsmanager_secret.sftp_credentials | resource |
| aws_secretsmanager_secret_version.sftp_credentials | resource |
| aws_iam_role.s3_access_role | resource |
| aws_iam_policy.s3_access_policy | resource |
| aws_iam_role_policy_attachment.s3_access_policy_attachment | resource |
| aws_iam_policy.kms_access_policy | resource |
| aws_iam_role_policy_attachment.kms_access_policy_attachment | resource |
| aws_iam_role.logging_role | resource |
| aws_iam_role_policy_attachment.logging_policy_attachment | resource |
| aws_transfer_connector.sftp_connector | resource |
| terraform_data.test_connection | resource |
| terraform_data.update_connector_with_host_keys | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| connector_name | Name of the AWS Transfer Family connector | `string` | `"sftp-connector"` | no |
| sftp_server_url | URL of the SFTP server to connect to (e.g., sftp://example.com:22 or sftp://example.com) | `string` | n/a | yes |
| s3_bucket_arn | ARN of the S3 bucket to connect to the SFTP server | `string` | n/a | yes |
| s3_access_role_arn | ARN of the IAM role for S3 access (if not provided, a new role will be created) | `string` | `null` | no |
| logging_role_arn | ARN of the IAM role for CloudWatch logging (if not provided, a new role will be created) | `string` | `null` | no |
| sftp_username | Username for SFTP authentication | `string` | n/a | yes |
| sftp_password | Password for SFTP authentication | `string` | n/a | yes |
| trusted_host_keys | List of trusted host keys for the SFTP server. Leave empty to auto-discover. | `list(string)` | `[]` | no |
| auto_discover_host_keys | Whether to auto-discover trusted host keys from the SFTP server | `bool` | `true` | no |
| max_concurrent_connections | Maximum number of concurrent connections to the SFTP server | `number` | `1` | no |
| security_policy_name | The name of the security policy to use for the connector | `string` | `"TransferSecurityPolicy-2024-01"` | no |
| kms_key_arn | ARN of the KMS key used for encrypting secrets | `string` | `null` | no |
| tags | A map of tags to assign to resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| connector_id | The ID of the AWS Transfer Family connector |
| connector_arn | The ARN of the AWS Transfer Family connector |
| connector_url | The URL of the SFTP server the connector connects to |
| s3_access_role_arn | The ARN of the IAM role used by the connector for S3 access |
| logging_role_arn | The ARN of the IAM role used for connector logging |
| secrets_manager_secret_arn | The ARN of the Secrets Manager secret containing SFTP credentials |
| secrets_manager_secret_name | The name of the Secrets Manager secret containing SFTP credentials |
| security_policy_name | The security policy used by the connector |
| max_concurrent_connections | Maximum number of concurrent connections configured for the connector |
| auto_discover_enabled | Whether auto-discovery of host keys is enabled |
| trusted_host_keys_provided | Whether trusted host keys were provided by the user |

## Examples

See the [examples directory](../../examples/sftp-connector-example) for complete usage examples.
