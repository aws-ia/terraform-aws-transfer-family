# Enterprise Usage Example

This example demonstrates the full enterprise configuration of the AWS Transfer Family Custom IdP solution with all advanced features enabled.

## Overview

This enterprise example creates:
- Custom IdP Lambda function with VPC integration
- DynamoDB tables with KMS encryption and point-in-time recovery
- API Gateway integration with custom domain support
- CloudWatch monitoring with alarms and structured logging
- X-Ray distributed tracing
- KMS key for encryption
- Enterprise-grade security and compliance features

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Enterprise Architecture                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────┐    ┌──────────────────┐    ┌─────────────┐ │
│  │   Transfer      │    │   API Gateway    │    │   Lambda    │ │
│  │   Family        │───▶│   (Optional)     │───▶│   Function  │ │
│  │   Server        │    │                  │    │   (VPC)     │ │
│  └─────────────────┘    └──────────────────┘    └─────────────┘ │
│                                                         │       │
│  ┌─────────────────┐    ┌──────────────────┐           │       │
│  │   CloudWatch    │    │   DynamoDB       │◀──────────┘       │
│  │   Alarms &      │    │   Tables         │                   │
│  │   Logs          │    │   (Encrypted)    │                   │
│  └─────────────────┘    └──────────────────┘                   │
│                                                                 │
│  ┌─────────────────┐    ┌──────────────────┐                   │
│  │   X-Ray         │    │   KMS Key        │                   │
│  │   Tracing       │    │   (Custom)       │                   │
│  └─────────────────┘    └──────────────────┘                   │
└─────────────────────────────────────────────────────────────────┘
```

## Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform >= 1.0 installed
- AWS provider >= 5.0
- Existing VPC with private subnets (recommended)
- Security groups configured for Lambda access
- SNS topic for alarm notifications (optional)

## Required Permissions

Your AWS credentials need comprehensive permissions including:
- Lambda function creation and VPC attachment
- DynamoDB table creation with encryption
- API Gateway creation and configuration
- KMS key creation and management
- CloudWatch alarms and log groups
- X-Ray tracing configuration
- AWS Transfer Family server creation
- IAM role and policy creation

## Quick Start

1. **Clone and navigate to the example:**
   ```bash
   cd examples/enterprise
   ```

2. **Copy and customize the variables:**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your specific values
   ```

3. **Initialize Terraform:**
   ```bash
   terraform init
   ```

4. **Review the plan:**
   ```bash
   terraform plan
   ```

5. **Deploy the infrastructure:**
   ```bash
   terraform apply
   ```

## Configuration Options

### VPC Integration

```hcl
# Use existing VPC (recommended for enterprise)
use_existing_vpc = true
vpc_id = "vpc-12345678"
lambda_security_group_name = "lambda-sg"
```

### API Gateway vs Lambda Integration

```hcl
# API Gateway integration (recommended for enterprise)
enable_api_gateway = true

# OR Lambda integration
enable_api_gateway = false
```

### Security and Encryption

```hcl
# Create custom KMS key
create_kms_key = true
kms_key_deletion_window = 30

# OR use existing KMS key
create_kms_key = false
existing_kms_key_id = data.aws_kms_key.existing.arn
```

### Monitoring and Observability

```hcl
# Enable comprehensive monitoring
enable_monitoring = true
enable_xray_tracing = true
enable_structured_logging = true
sns_alarm_topic_arn = "arn:aws:sns:us-east-1:ACCOUNT-ID:alerts"
```

### Performance Tuning

```hcl
# High-performance Lambda configuration
lambda_memory_size = 2048
lambda_timeout = 60
dynamodb_billing_mode = "PAY_PER_REQUEST"  # or "PROVISIONED"
```

## Enterprise Features

### 1. Security Features

- **KMS Encryption**: Custom KMS key for all encryption needs
- **VPC Integration**: Lambda runs in private subnets
- **IAM Least Privilege**: Minimal required permissions
- **Security Policies**: Latest Transfer Family security policies

### 2. Monitoring and Observability

- **CloudWatch Alarms**: Lambda errors, duration, and DynamoDB throttles
- **Structured Logging**: Enhanced Transfer Family logging
- **X-Ray Tracing**: Distributed tracing across all components
- **Custom Metrics**: Application-specific metrics

### 3. High Availability and Resilience

- **Multi-AZ Deployment**: Lambda and DynamoDB across multiple AZs
- **Point-in-Time Recovery**: DynamoDB backup and recovery
- **Auto Scaling**: DynamoDB on-demand scaling
- **Error Handling**: Comprehensive error handling and retries

### 4. Compliance and Governance

- **Encryption at Rest**: All data encrypted with KMS
- **Encryption in Transit**: TLS for all communications
- **Audit Logging**: Comprehensive CloudWatch logging
- **Tagging Strategy**: Consistent resource tagging

## Post-Deployment Configuration

### 1. Configure Identity Providers

Add enterprise identity provider configurations:

```json
{
  "provider": "ldap",
  "config": {
    "server": "ldap.company.com",
    "port": 636,
    "use_ssl": true,
    "base_dn": "ou=users,dc=company,dc=com",
    "bind_dn": "cn=service,ou=services,dc=company,dc=com",
    "bind_password_secret": "arn:aws:secretsmanager:us-east-1:123456789012:secret:ldap-bind-password"
  }
}
```

### 2. Configure Enterprise Users

Add users with enterprise features:

```json
{
  "user": "john.doe@@ldap",
  "identity_provider_key": "ldap",
  "home_directory": "/enterprise-bucket/users/john.doe",
  "role": "arn:aws:iam::123456789012:role/TransferEnterpriseRole",
  "policy": "{\"Version\":\"2012-10-17\",\"Statement\":[...]}",
  "posix_profile": {
    "uid": 1001,
    "gid": 1001,
    "secondary_gids": [1002, 1003]
  }
}
```

### 3. Set Up Monitoring Dashboards

Create CloudWatch dashboards for monitoring:

```bash
# Use the provided dashboard template
aws cloudwatch put-dashboard --dashboard-name "TransferFamilyEnterprise" --dashboard-body file://dashboard.json
```

## Monitoring and Alerting

### CloudWatch Alarms

The deployment creates several alarms:

1. **Lambda Errors**: Triggers when error rate exceeds threshold
2. **Lambda Duration**: Triggers when execution time is too high
3. **DynamoDB Throttles**: Triggers on DynamoDB throttling

### Log Analysis

Monitor logs in CloudWatch:

- **Lambda Logs**: `/aws/lambda/{function-name}`
- **Transfer Logs**: `/aws/transfer/{name-prefix}`
- **API Gateway Logs**: `/aws/apigateway/{api-id}`

### X-Ray Tracing

View distributed traces in X-Ray console:
- End-to-end request tracing
- Performance bottleneck identification
- Error root cause analysis

## Scaling and Performance

### Lambda Scaling

- **Concurrent Executions**: Monitor and adjust reserved concurrency
- **Memory Allocation**: Tune based on performance metrics
- **Timeout Settings**: Balance between performance and cost

### DynamoDB Scaling

- **On-Demand Mode**: Automatic scaling based on traffic
- **Provisioned Mode**: Manual capacity planning for predictable workloads
- **Global Tables**: Multi-region replication for disaster recovery

## Security Best Practices

### Network Security

- Lambda in private subnets
- Security groups with minimal required access
- VPC endpoints for AWS services

### Data Protection

- KMS encryption for all data at rest
- TLS 1.2+ for data in transit
- Secrets Manager for sensitive credentials

### Access Control

- IAM roles with least privilege
- Resource-based policies
- Cross-account access controls

## Disaster Recovery

### Backup Strategy

- DynamoDB point-in-time recovery enabled
- CloudWatch logs retention configured
- KMS key backup and recovery procedures

### Multi-Region Deployment

For multi-region deployment:

1. Deploy in primary region
2. Set up DynamoDB Global Tables
3. Deploy in secondary region with shared tables
4. Configure Route 53 health checks

## Cost Optimization

### Resource Optimization

- Right-size Lambda memory allocation
- Optimize DynamoDB capacity mode
- Set appropriate log retention periods
- Use reserved capacity for predictable workloads

### Monitoring Costs

- CloudWatch cost alarms
- AWS Cost Explorer analysis
- Resource tagging for cost allocation

## Troubleshooting

### Common Issues

1. **VPC Connectivity**: Ensure NAT Gateway or VPC endpoints
2. **Security Group Rules**: Verify Lambda can reach DynamoDB
3. **KMS Permissions**: Check key policies and IAM permissions
4. **API Gateway Throttling**: Monitor and adjust throttling limits

### Debugging Steps

1. Check CloudWatch logs for errors
2. Use X-Ray traces for performance issues
3. Verify DynamoDB table configurations
4. Test Lambda function independently

## Compliance and Auditing

### SOC 2 Compliance

- Encryption at rest and in transit
- Access logging and monitoring
- Change management through Terraform
- Regular security assessments

### Audit Trail

- CloudTrail for API calls
- CloudWatch logs for application events
- DynamoDB streams for data changes
- X-Ray for request tracing

## Cleanup

To remove all resources:

```bash
terraform destroy
```

**Note**: KMS keys have a deletion window and cannot be immediately deleted.

## Next Steps

- Review the [basic example](../basic/) for simpler deployments
- See the main [module README](../../README.md) for detailed configuration options
- Check the [migration example](../migration/) for SAM to Terraform migration

## Support

For enterprise support:
- Review CloudWatch alarms and logs
- Use X-Ray for performance analysis
- Check AWS Support for service-specific issues
- Consult AWS Well-Architected Framework guidelines