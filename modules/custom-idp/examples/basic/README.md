# Basic Usage Example

This example demonstrates the minimal configuration required to deploy the AWS Transfer Family Custom IdP solution using Terraform.

## Overview

This basic example creates:
- Custom IdP Lambda function (without VPC attachment)
- DynamoDB tables for users and identity providers
- CloudWatch log group for Lambda logging
- AWS Transfer Family server with Lambda integration

## Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform >= 1.0 installed
- AWS provider >= 5.0

## Required Permissions

Your AWS credentials need the following permissions:
- Lambda function creation and management
- DynamoDB table creation and management
- IAM role and policy creation
- CloudWatch log group creation
- AWS Transfer Family server creation

## Quick Start

1. **Clone and navigate to the example:**
   ```bash
   cd examples/basic
   ```

2. **Initialize Terraform:**
   ```bash
   terraform init
   ```

3. **Review the plan:**
   ```bash
   terraform plan
   ```

4. **Deploy the infrastructure:**
   ```bash
   terraform apply
   ```

5. **Note the outputs** - they contain important information for next steps.

## Configuration

### Default Settings

This basic example uses the following default settings:
- **VPC**: Lambda runs without VPC attachment (internet access)
- **Logging**: INFO level with 14-day retention
- **DynamoDB**: Pay-per-request billing mode
- **Lambda**: 1024MB memory, 45-second timeout
- **Features**: API Gateway, X-Ray, and Secrets Manager disabled

### Customization

You can customize the deployment by modifying variables:

```bash
# Deploy with custom name prefix
terraform apply -var="name_prefix=my-custom-idp"

# Deploy in different region
terraform apply -var="aws_region=us-west-2"

# Add custom tags
terraform apply -var='tags={"Environment"="production","Team"="platform"}'
```

## Post-Deployment Configuration

After deployment, you need to configure the identity providers and users:

### 1. Configure Identity Providers

Add identity provider configurations to the DynamoDB table:

```json
{
  "provider": "local",
  "config": {
    "type": "local"
  }
}
```

### 2. Add Users

Add user configurations to the DynamoDB table:

```json
{
  "user": "testuser@@local",
  "identity_provider_key": "local",
  "password": "$argon2id$v=19$m=65536,t=3,p=4$...",
  "home_directory": "/bucket/testuser",
  "role": "arn:aws:iam::123456789012:role/TransferRole",
  "policy": "{\"Version\":\"2012-10-17\",\"Statement\":[...]}"
}
```

### 3. Test the Connection

Use an SFTP client to test the connection:

```bash
sftp testuser@@local@<transfer-server-endpoint>
```

## Monitoring

- **Lambda Logs**: Available in CloudWatch at `/aws/lambda/<function-name>`
- **Transfer Logs**: Available in CloudWatch (if enabled on the server)
- **DynamoDB Metrics**: Available in CloudWatch under DynamoDB service

## Cleanup

To remove all resources:

```bash
terraform destroy
```

## Next Steps

- Review the [enterprise example](../enterprise/) for advanced features
- See the main [module README](../../README.md) for detailed configuration options
- Check the [migration example](../migration/) if migrating from SAM template

## Troubleshooting

### Common Issues

1. **Lambda timeout errors**: Increase `lambda_timeout` variable
2. **Memory issues**: Increase `lambda_memory_size` variable
3. **Authentication failures**: Check DynamoDB table configurations
4. **Permission errors**: Verify IAM roles and policies

### Getting Help

- Check CloudWatch logs for detailed error messages
- Review the module documentation
- Ensure all prerequisites are met
- Verify AWS credentials and permissions