# AWS Transfer Family with Custom IdP (API Gateway) Example

This example demonstrates how to deploy AWS Transfer Family with a custom identity provider using **API Gateway REST integration** instead of direct Lambda integration. This approach provides additional flexibility and can be useful for integration with external systems or when you need REST API access to the authentication logic.

## Architecture Overview

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   SFTP Client   │───▶│ Transfer Family │───▶│   API Gateway   │───▶│ Lambda Function │
└─────────────────┘    └─────────────────┘    └─────────────────┘    └─────────────────┘
                                                        │                        │
                                                        ▼                        ▼
                                               ┌─────────────────┐    ┌─────────────────┐
                                               │   CloudWatch    │    │    DynamoDB     │
                                               │      Logs       │    │   (Users & IDPs)│
                                               └─────────────────┘    └─────────────────┘
                                                                               │
                                                                               ▼
                                                                    ┌─────────────────┐
                                                                    │ Cognito/LDAP/etc│
                                                                    │ Identity Provider│
                                                                    └─────────────────┘
```

## Key Features

- **API Gateway Integration**: Uses REST API instead of direct Lambda invocation
- **Multiple Identity Providers**: Supports Cognito, LDAP, and other IDPs simultaneously
- **Flexible User Management**: DynamoDB-based user and IDP configuration
- **Enhanced Monitoring**: CloudWatch dashboard and detailed logging
- **Security**: IAM-based API Gateway authentication
- **Scalability**: API Gateway provides built-in throttling and caching

## What Gets Deployed

### Core Infrastructure
- **AWS Transfer Family Server** with SFTP protocol
- **API Gateway REST API** with `/servers/{serverId}/users/{username}/config` endpoint
- **Lambda Function** for identity provider logic
- **DynamoDB Tables** for users and identity provider configuration

### Authentication Setup
- **Cognito User Pool** with two test users (admin and regular user)
- **Multiple IAM Roles** with different permission levels
- **S3 Bucket** for file storage with appropriate directory structure

### Monitoring & Logging
- **CloudWatch Dashboard** for Transfer Family metrics
- **Enhanced Logging** with DEBUG level for troubleshooting
- **X-Ray Tracing** for API Gateway and Lambda performance monitoring

## Deployment

### Prerequisites
- AWS CLI configured with appropriate permissions
- Terraform >= 1.0 installed
- Access to create IAM roles, Lambda functions, API Gateway, and DynamoDB tables

### Deploy the Infrastructure

1. **Clone and navigate to the example:**
   ```bash
   cd examples/sftp-custom-idp-api-gateway
   ```

2. **Initialize Terraform:**
   ```bash
   terraform init
   ```

3. **Review and customize variables (optional):**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your preferred settings
   ```

4. **Deploy the infrastructure:**
   ```bash
   terraform plan
   terraform apply
   ```

5. **Note the outputs:**
   ```bash
   terraform output
   ```

## Testing the Deployment

### SFTP Connection Testing

After deployment, you can test SFTP connections using the provided credentials:

```bash
# Connect as admin user (full bucket access)
sftp admin@<transfer-server-endpoint>

# Connect as regular user (restricted to user directory)
sftp user@<transfer-server-endpoint>
```

### API Gateway Direct Testing

You can also test the API Gateway endpoint directly:

```bash
# Get the API Gateway URL from terraform output
API_URL=$(terraform output -raw api_gateway_url)
SERVER_ID=$(terraform output -raw transfer_server_id)

# Test authentication via API Gateway
curl -X GET "${API_URL}/servers/${SERVER_ID}/users/admin/config?protocol=SFTP&sourceIp=127.0.0.1" \
  -H "PasswordBase64: $(echo -n 'AdminPass123!' | base64)" \
  --aws-sigv4 "aws:amz:us-east-1:execute-api"
```

## Configuration Details

### User Configuration

The example creates several user configurations in DynamoDB:

1. **Admin User (`admin`)**:
   - Uses Cognito authentication
   - Full bucket access
   - Home directory: `/bucket-name/` (root level)

2. **Regular User (`user`)**:
   - Uses Cognito authentication  
   - Restricted to user directory
   - Home directory: `/bucket-name/user-example-com/`

3. **Default User (`$default$`)**:
   - Uses LDAP authentication (disabled by default)
   - Fallback for unknown users
   - Dynamic home directory based on username

### Identity Provider Configuration

1. **Cognito Provider**:
   - Module: `cognito`
   - Configuration includes User Pool ID and region
   - Supports password authentication

2. **LDAP Provider**:
   - Module: `ldap`
   - Disabled by default (no real LDAP server)
   - Can be enabled by providing real LDAP configuration

## API Gateway vs Lambda Integration

### API Gateway Benefits:
- **REST API Access**: External systems can authenticate users via HTTP
- **Built-in Features**: Throttling, caching, request/response transformation
- **Monitoring**: Enhanced CloudWatch metrics and logging
- **Security**: IAM-based authentication with fine-grained permissions
- **Flexibility**: Can add additional endpoints for user management

### Lambda Direct Benefits:
- **Simplicity**: Fewer components and configuration
- **Performance**: Slightly lower latency (no API Gateway hop)
- **Cost**: Lower cost for high-volume scenarios

## Monitoring and Troubleshooting

### CloudWatch Dashboard
Access the pre-configured dashboard to monitor:
- Transfer Family metrics (files in/out, bytes transferred)
- Lambda function performance and errors
- API Gateway request metrics

### Log Analysis
```bash
# View Lambda logs
aws logs tail /aws/lambda/<function-name> --follow

# View API Gateway logs (if enabled)
aws logs tail API-Gateway-Execution-Logs_<api-id>/prod --follow
```

### Common Issues

1. **Authentication Failures**:
   - Check DynamoDB user configuration
   - Verify Cognito user exists and password is correct
   - Review Lambda function logs for detailed error messages

2. **Permission Errors**:
   - Verify IAM roles have correct S3 permissions
   - Check that Transfer Family can assume the user roles

3. **API Gateway Issues**:
   - Ensure API Gateway has permission to invoke Lambda
   - Verify request format matches expected parameters
   - Check API Gateway execution role permissions

## Customization

### Adding New Identity Providers

1. **Add IDP Configuration to DynamoDB**:
   ```hcl
   resource "aws_dynamodb_table_item" "new_provider" {
     table_name = module.custom_idp.identity_providers_table_name
     hash_key   = "provider"
     
     item = jsonencode({
       provider = { S = "new_idp" }
       module   = { S = "new_idp" }
       config   = { M = { /* IDP-specific config */ } }
     })
   }
   ```

2. **Create Users for New IDP**:
   ```hcl
   resource "aws_dynamodb_table_item" "new_user" {
     table_name = module.custom_idp.users_table_name
     hash_key   = "user"
     range_key  = "identity_provider_key"
     
     item = jsonencode({
       user = { S = "username" }
       identity_provider_key = { S = "new_idp" }
       config = { M = { /* User-specific config */ } }
     })
   }
   ```

### Modifying API Gateway

The API Gateway configuration can be extended by modifying the `custom-idp` module or by adding additional resources in your deployment.

## Cleanup

To remove all resources:

```bash
terraform destroy
```

**Note**: Ensure S3 bucket is empty before destroying, as Terraform cannot delete non-empty buckets.

## Security Considerations

- **API Gateway Authentication**: Uses IAM authentication by default
- **Encryption**: All data encrypted at rest and in transit
- **Network Security**: Can be deployed in VPC for additional isolation
- **Audit Logging**: All authentication attempts logged to CloudWatch
- **Secrets Management**: Passwords stored securely in Cognito/Secrets Manager

## Cost Optimization

- **DynamoDB**: Uses on-demand billing by default
- **Lambda**: Right-sized memory allocation (512MB)
- **API Gateway**: Regional endpoint for lower latency and cost
- **CloudWatch**: 14-day log retention to balance monitoring and cost

## Support

For issues specific to this example:
1. Check the troubleshooting section above
2. Review CloudWatch logs for detailed error messages
3. Verify all prerequisites are met
4. Ensure AWS credentials have sufficient permissions

For general AWS Transfer Family questions, refer to the [AWS Transfer Family documentation](https://docs.aws.amazon.com/transfer/).