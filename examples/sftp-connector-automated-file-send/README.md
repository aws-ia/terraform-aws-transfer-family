# AWS Transfer Family SFTP Connector Example

This example demonstrates how to use the AWS Transfer Family SFTP Connector module to connect an S3 bucket to an external SFTP server for automated file transfers.

## Overview

This example creates:

1. **Two SFTP Connectors** (demonstrating different approaches):
   - Auto-discovery connector: Automatically discovers host keys from the SFTP server
   - Manual keys connector: Uses manually provided trusted host keys (created only if host keys are provided)

2. **S3 Bucket**: Encrypted bucket for file storage and transfers

3. **KMS Key**: For encrypting secrets and S3 objects

4. **IAM Roles**: Automatically created roles for S3 access and logging

5. **Secrets Manager**: Secure storage of SFTP credentials

6. **EventBridge Integration** (Optional): Automated file transfers triggered by S3 events

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   External      │    │  AWS Transfer    │    │   Amazon S3     │
│   SFTP Server   │◄──►│  Family          │◄──►│   Bucket        │
│                 │    │  Connector       │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                              │                         │
                              ▼                         │
                       ┌──────────────────┐             │
                       │  AWS Secrets     │             │
                       │  Manager         │             │
                       │  (Credentials)   │             │
                       └──────────────────┘             │
                                                        │
                       ┌──────────────────┐             │
                       │  EventBridge     │◄────────────┘
                       │  (Optional)      │
                       │  S3 Events       │
                       └──────────────────┘
```

## Usage

### Prerequisites

1. **External SFTP Server**: You need access to an external SFTP server
2. **SFTP Credentials**: Username and password for the SFTP server
3. **Network Access**: Ensure AWS Transfer Family can reach your SFTP server

### Basic Deployment

1. **Set Required Variables**:
   ```bash
   export TF_VAR_sftp_server_url="sftp://your-server.example.com:22"
   export TF_VAR_sftp_username="your-username"
   export TF_VAR_sftp_password="your-password"
   ```

2. **Deploy with Auto-Discovery** (Recommended for Development):
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

3. **Deploy with Manual Host Keys** (Recommended for Production):
   
   First, get the host keys from your SFTP server:
   ```bash
   ssh-keyscan -p 22 your-server.example.com
   ```
   
   Then create a `terraform.tfvars` file:
   ```hcl
   sftp_server_url = "sftp://your-server.example.com:22"
   sftp_username   = "your-username"
   sftp_password   = "your-password"
   trusted_host_keys = [
     "ssh-rsa AAAAB3NzaC1yc2EAAAA...",
     "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA..."
   ]
   ```

### Advanced Configuration

#### Enable EventBridge Integration

To automatically transfer files when they're uploaded to S3:

```hcl
enable_eventbridge_integration = true
sftp_remote_path               = "/uploads"
```

#### Use Existing IAM Roles

```hcl
existing_s3_role_arn     = "arn:aws:iam::123456789012:role/my-s3-role"
existing_logging_role_arn = "arn:aws:iam::123456789012:role/my-logging-role"
```

#### Customize Connection Settings

```hcl
max_concurrent_connections = 5
security_policy_name      = "TransferSecurityPolicy-2024-01"
```

## Testing the Connector

### Manual File Transfer

1. **Upload a file to S3**:
   ```bash
   aws s3 cp test-file.txt s3://your-bucket-name/
   ```

2. **Start a file transfer**:
   ```bash
   aws transfer start-file-transfer \
     --connector-id <connector-id> \
     --send-file-paths /test-file.txt \
     --remote-directory-path /uploads
   ```

### Automated Transfer (with EventBridge)

If EventBridge integration is enabled, files uploaded to the S3 bucket will automatically be transferred to the SFTP server.

## Host Key Management

### Auto-Discovery (Development)

The auto-discovery connector will:
1. Create the connector without host keys
2. Test the connection to discover host keys
3. Update the connector with discovered keys

**Pros**: Easy setup, no manual key management
**Cons**: Less secure, requires connection testing

### Manual Configuration (Production)

For production environments, manually specify host keys:

1. **Get host keys**:
   ```bash
   ssh-keyscan -p 22 your-server.example.com
   ```

2. **Add to configuration**:
   ```hcl
   trusted_host_keys = [
     "ssh-rsa AAAAB3NzaC1yc2EAAAA...",
     "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA..."
   ]
   ```

**Pros**: More secure, no connection testing required
**Cons**: Manual key management required

## Security Best Practices

1. **Use Manual Host Keys in Production**: Avoid auto-discovery in production environments
2. **Rotate Credentials Regularly**: Update SFTP passwords in Secrets Manager
3. **Use KMS Encryption**: Enable KMS encryption for secrets and S3 objects
4. **Least Privilege IAM**: Use minimal required permissions for IAM roles
5. **Network Security**: Ensure proper network access controls for your SFTP server

## Troubleshooting

### Connection Issues

1. **Check SFTP server accessibility**:
   ```bash
   telnet your-server.example.com 22
   ```

2. **Verify credentials in Secrets Manager**:
   ```bash
   aws secretsmanager get-secret-value --secret-id <secret-name>
   ```

3. **Test connector**:
   ```bash
   aws transfer test-connection --connector-id <connector-id>
   ```

### Auto-Discovery Issues

If auto-discovery fails:
1. Check AWS CLI is available in Terraform execution environment
2. Verify AWS credentials have Transfer Family permissions
3. Ensure SFTP server accepts connections for key discovery
4. Check CloudWatch logs for detailed error messages

### Permission Issues

1. **Check IAM roles**: Ensure roles have required S3 and Secrets Manager permissions
2. **Verify KMS permissions**: Ensure roles can decrypt KMS keys
3. **Check S3 bucket policies**: Ensure connector can access the bucket

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

**Note**: This will delete all created resources including the S3 bucket and its contents.

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| sftp_server_url | URL of the external SFTP server | `string` | n/a | yes |
| sftp_username | Username for SFTP authentication | `string` | n/a | yes |
| sftp_password | Password for SFTP authentication | `string` | n/a | yes |
| trusted_host_keys | List of trusted host keys | `list(string)` | `[]` | no |
| max_concurrent_connections | Maximum concurrent connections | `number` | `1` | no |
| security_policy_name | Security policy name | `string` | `"TransferSecurityPolicy-2024-01"` | no |
| existing_s3_role_arn | Existing S3 access role ARN | `string` | `null` | no |
| existing_logging_role_arn | Existing logging role ARN | `string` | `null` | no |
| enable_eventbridge_integration | Enable EventBridge integration | `bool` | `false` | no |
| sftp_remote_path | Remote path on SFTP server | `string` | `"/uploads"` | no |

## Outputs

| Name | Description |
|------|-------------|
| auto_discovery_connector_id | ID of the auto-discovery connector |
| auto_discovery_connector_arn | ARN of the auto-discovery connector |
| manual_keys_connector_id | ID of the manual keys connector (if created) |
| s3_bucket_name | Name of the S3 bucket |
| kms_key_arn | ARN of the KMS key |
| sftp_server_url | SFTP server URL |
| auto_discovery_enabled | Whether auto-discovery is enabled |

## References

- [AWS Transfer Family Connectors](https://docs.aws.amazon.com/transfer/latest/userguide/connectors.html)
- [AWS Transfer Family API Reference](https://docs.aws.amazon.com/transfer/latest/APIReference/API_CreateConnector.html)
- [FICO Blog: Modernizing File Transfers](https://aws.amazon.com/blogs/storage/how-fico-modernizes-file-transfers-with-etl-automation-using-aws-transfer-family/)
