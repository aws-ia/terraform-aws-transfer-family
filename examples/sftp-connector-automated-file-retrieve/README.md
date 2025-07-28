# AWS Transfer Family SFTP Connector - Automated File Retrieve Workflow

This example demonstrates how to deploy an automated file retrieve workflow using an SFTP connector that retrieves specified file paths from a source directory in a remote server.

## Overview

This example creates an automated workflow in your AWS account that uses an SFTP connector to retrieve files from a remote SFTP server to S3 on a scheduled basis. The workflow includes:

1. **S3 Buckets**: 
   - Source bucket (simulating remote SFTP server storage)
   - Destination bucket (where retrieved files are stored)

2. **EventBridge Schedule**: Triggers the SFTP connector's Start-File-Transfer API on a pre-specified schedule

3. **DynamoDB Table**: Stores a list of file paths to be retrieved in each invocation of the workflow

4. **SFTP Connector**: Handles the actual file transfer from remote SFTP server to S3 (uses the connector submodule)

5. **Lambda Function**: Orchestrates the file retrieval process by reading from DynamoDB and calling the Transfer Family API

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Remote        │    │  AWS Transfer    │    │   Destination   │
│   SFTP Server   │◄──►│  Family          │───►│   S3 Bucket     │
│   (Simulated)   │    │  Connector       │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                              │                         
                              ▼                         
                       ┌──────────────────┐             
                       │  EventBridge     │             
                       │  Schedule        │             
                       │  (Automated)     │             
                       └──────────────────┘             
                              │                         
                              ▼                         
                       ┌──────────────────┐             
                       │  Lambda Function │             
                       │  (Orchestrator)  │             
                       └──────────────────┘             
                              │                         
                              ▼                         
                       ┌──────────────────┐             
                       │  DynamoDB Table  │             
                       │  (File Paths)    │             
                       └──────────────────┘             
```

## Features

### Automated File Retrieval
- **Scheduled Execution**: Uses EventBridge Schedule to trigger file retrieval at specified intervals
- **Dynamic File Management**: DynamoDB table stores file paths with status tracking
- **Batch Processing**: Retrieves multiple files in a single operation
- **Status Tracking**: Updates file status from 'pending' to 'in_progress' during processing

### SFTP Connector Integration
- **Auto-discovery**: Automatically discovers host keys from the SFTP server (development)
- **Manual Configuration**: Supports manually provided trusted host keys (production)
- **Secure Authentication**: Uses SSH private keys stored in AWS Secrets Manager
- **KMS Encryption**: All secrets and S3 objects are encrypted with KMS

### Storage and Security
- **S3 Integration**: Retrieved files are stored in encrypted S3 bucket
- **KMS Encryption**: End-to-end encryption for all data at rest
- **IAM Roles**: Least privilege access for all components
- **VPC Support**: Can be deployed in VPC for enhanced security

## Usage

### Prerequisites

1. **AWS CLI**: Configured with appropriate permissions
2. **Terraform**: Version >= 1.0.7
3. **Remote SFTP Server**: Access to an external SFTP server (or use the simulated one created by this example)

### User Inputs

1. **S3 Destination Prefix**: Local directory path where retrieved files will be stored
   ```hcl
   s3_destination_prefix = "retrieved/"
   ```

2. **EventBridge Schedule**: Schedule expression for automated retrieval
   ```hcl
   eventbridge_schedule_expression = "rate(1 hour)"  # or "cron(0 9 * * ? *)"
   ```

3. **Connector ID**: (Optional) Use existing connector or create new one
   ```hcl
   existing_connector_id = "c-1234567890abcdef0"  # Optional
   ```

### Deployment Steps

1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   cd terraform-aws-transfer-family/examples/sftp-connector-automated-file-retrieve
   ```

2. **Configure variables**:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your specific values
   ```

3. **Initialize and deploy**:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

### Managing File Paths

#### Adding Files for Retrieval

Add file paths to the DynamoDB table with status 'pending':

```bash
aws dynamodb put-item \
    --table-name <dynamodb-table-name> \
    --item '{
        "file_path": {"S": "/uploads/new-file.txt"},
        "status": {"S": "pending"},
        "created_at": {"S": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"},
        "local_directory_path": {"S": "retrieved/"}
    }'
```

#### Checking File Status

Query files by status:

```bash
aws dynamodb query \
    --table-name <dynamodb-table-name> \
    --index-name status-index \
    --key-condition-expression "#status = :status" \
    --expression-attribute-names '{"#status": "status"}' \
    --expression-attribute-values '{":status": {"S": "pending"}}'
```

### Monitoring

#### CloudWatch Logs
Monitor Lambda function execution:
```bash
aws logs tail /aws/lambda/retrieve-sftp-files-<random-id> --follow
```

#### Transfer Family
Check transfer status:
```bash
aws transfer describe-execution --workflow-id <workflow-id> --execution-id <execution-id>
```

#### S3 Retrieved Files
List retrieved files:
```bash
aws s3 ls s3://<destination-bucket-name>/retrieved/ --recursive
```

## Configuration Options

### Schedule Expressions

- **Rate-based**: `rate(1 hour)`, `rate(30 minutes)`, `rate(1 day)`
- **Cron-based**: `cron(0 9 * * ? *)` (daily at 9 AM UTC)

### File Path Patterns

The DynamoDB table supports various file path patterns:
- Single files: `/uploads/file.txt`
- Wildcard patterns: `/uploads/*.txt`
- Directory paths: `/uploads/documents/`

### Security Configurations

- **KMS Key Rotation**: Enabled by default
- **S3 Bucket Encryption**: Server-side encryption with KMS
- **DynamoDB Encryption**: Encryption at rest with KMS
- **Secrets Manager**: Encrypted SFTP credentials

## Troubleshooting

### Common Issues

1. **Lambda Timeout**: Increase timeout if processing many files
2. **DynamoDB Throttling**: Increase read/write capacity if needed
3. **SFTP Connection**: Verify host keys and credentials
4. **S3 Permissions**: Ensure connector has proper S3 access

### Debug Steps

1. Check Lambda logs for detailed error messages
2. Verify DynamoDB table has pending files
3. Test SFTP connectivity manually
4. Validate IAM permissions

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

## Security Considerations

- All S3 buckets have public access blocked
- KMS encryption is enabled for all data at rest
- IAM roles follow least privilege principle
- Secrets are stored in AWS Secrets Manager
- CloudWatch logging is enabled for audit trails

## Cost Optimization

- Use appropriate DynamoDB billing mode (On-Demand vs Provisioned)
- Configure S3 lifecycle policies for retrieved files
- Adjust Lambda memory allocation based on workload
- Use EventBridge schedule efficiently to avoid unnecessary executions

## Examples

### Basic Configuration

```hcl
module "sftp_automated_retrieve" {
  source = "./examples/sftp-connector-automated-file-retrieve"
  
  s3_destination_prefix           = "retrieved/"
  eventbridge_schedule_expression = "rate(1 hour)"
  
  sample_file_paths = [
    "/uploads/daily-report.csv",
    "/uploads/logs/*.log",
    "/data/exports/export.json"
  ]
}
```

### Production Configuration

```hcl
module "sftp_automated_retrieve" {
  source = "./examples/sftp-connector-automated-file-retrieve"
  
  existing_connector_id           = "c-1234567890abcdef0"
  s3_destination_prefix           = "production/retrieved/"
  eventbridge_schedule_expression = "cron(0 2 * * ? *)"  # Daily at 2 AM UTC
  
  trusted_host_keys = [
    "ssh-rsa AAAAB3NzaC1yc2EAAAA..."
  ]
  
  tags = {
    Environment = "production"
    Project     = "data-ingestion"
    Owner       = "data-team"
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0.7 |
| aws | >= 5.95.0 |
| awscc | >= 0.24.0 |
| random | >= 3.0.0 |
| archive | >= 2.0.0 |

## Providers

| Name | Version |
|------|---------|
| aws | >= 5.95.0 |
| random | >= 3.0.0 |
| archive | >= 2.0.0 |

## Resources Created

- AWS Transfer Family Server (simulated remote SFTP server)
- AWS Transfer Family Connector
- S3 Buckets (source and destination)
- DynamoDB Table (file paths management)
- Lambda Function (orchestration)
- EventBridge Schedule (automation)
- IAM Roles and Policies
- KMS Key and Alias
- CloudWatch Log Groups
- AWS Secrets Manager Secrets

## Support

For issues and questions:
1. Check the troubleshooting section
2. Review CloudWatch logs
3. Consult AWS Transfer Family documentation
4. Open an issue in the repository
