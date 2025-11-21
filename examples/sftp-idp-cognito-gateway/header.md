# SFTP Server with API Gateway and Cognito Authentication

This example demonstrates how to set up an AWS Transfer Family SFTP server that uses API Gateway as an intermediary between the Transfer server and a Lambda function for custom identity provider authentication with Amazon Cognito.

## Architecture

```
SFTP Client → Transfer Family Server → API Gateway → Lambda Function → Cognito User Pool
                                                         ↓
                                                   DynamoDB (User Config)
```

The authentication flow works as follows:
1. SFTP client connects to Transfer Family server
2. Transfer Family server calls API Gateway endpoint with user credentials
3. API Gateway invokes Lambda function
4. Lambda function authenticates user against Cognito User Pool
5. If authentication succeeds, Lambda retrieves user configuration from DynamoDB
6. Lambda returns user configuration to Transfer Family server via API Gateway

## Key Features

- **API Gateway Integration**: Uses API Gateway as an intermediary for enhanced monitoring and control
- **Cognito Authentication**: Secure user authentication using Amazon Cognito User Pool
- **DynamoDB Configuration**: User-specific SFTP configuration stored in DynamoDB
- **IAM Security**: Proper IAM roles and policies for secure service communication

## Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform >= 1.5
- An AWS account with permissions to create the required resources

## Usage

1. Clone this repository and navigate to this example:
   ```bash
   cd examples/sftp-idp-cognito-gateway
   ```

2. Initialize Terraform:
   ```bash
   terraform init
   ```

3. Review and customize variables in `variables.tf` or create a `terraform.tfvars` file:
   ```hcl
   aws_region = "us-east-1"
   cognito_user_pool_name = "my-sftp-users"
   bucket_prefix = "my-company"
   ```

4. Plan the deployment:
   ```bash
   terraform plan
   ```

5. Apply the configuration:
   ```bash
   terraform apply
   ```

## Post-Deployment Setup

After deployment, you need to:

1. **Create Cognito Users**:
   ```bash
   aws cognito-idp admin-create-user \
     --user-pool-id <cognito_user_pool_id> \
     --username user1 \
     --temporary-password TempPass123! \
     --message-action SUPPRESS
   
   aws cognito-idp admin-set-user-password \
     --user-pool-id <cognito_user_pool_id> \
     --username user1 \
     --password MySecurePass123! \
     --permanent
   ```

2. **Configure User Settings in DynamoDB**:
   ```bash
   aws dynamodb put-item \
     --table-name <dynamodb_users_table> \
     --item '{
       "user": {"S": "user1"},
       "HomeDirectory": {"S": "/my-company-sftp-storage-bucket/user1/"},
       "Role": {"S": "arn:aws:iam::ACCOUNT:role/transfer-user-role"},
       "Policy": {"S": "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Action\":[\"s3:GetObject\",\"s3:PutObject\",\"s3:DeleteObject\"],\"Resource\":\"arn:aws:s3:::my-company-sftp-storage-bucket/user1/*\"}]}"}
     }'
   ```

3. **Test SFTP Connection**:
   ```bash
   sftp user1@<transfer_server_endpoint>
   ```

## API Gateway Benefits

Using API Gateway provides several advantages:

- **Enhanced Monitoring**: CloudWatch metrics and logs for API calls
- **Rate Limiting**: Built-in throttling and rate limiting capabilities  
- **Request/Response Transformation**: Ability to modify requests and responses
- **Caching**: Optional response caching for improved performance
- **Security**: Additional security layers like API keys, WAF integration

## Monitoring

The setup includes comprehensive monitoring:

- **API Gateway Logs**: Request/response logging in CloudWatch
- **Lambda Logs**: Function execution logs and errors
- **Transfer Family Logs**: SFTP session and authentication logs
- **Cognito Logs**: Authentication attempt logs

## Security Considerations

- Cognito User Pool uses strong password policies
- IAM roles follow least privilege principle
- API Gateway uses IAM authentication
- All inter-service communication uses AWS IAM roles
- No hardcoded credentials in the configuration

## Cleanup

To remove all resources:

```bash
terraform destroy
```

## Troubleshooting

Common issues and solutions:

1. **Authentication Failures**: Check Cognito user status and password
2. **API Gateway Errors**: Review CloudWatch logs for detailed error messages
3. **Lambda Timeouts**: Increase Lambda timeout if needed
4. **DynamoDB Access**: Verify user configuration exists in DynamoDB table

## Outputs

The deployment provides these outputs:
- `transfer_server_endpoint`: SFTP server endpoint for client connections
- `api_gateway_url`: API Gateway URL used by Transfer Family
- `cognito_user_pool_id`: Cognito User Pool ID for user management
- `s3_bucket_name`: S3 bucket for file storage
- `dynamodb_users_table`: DynamoDB table for user configuration