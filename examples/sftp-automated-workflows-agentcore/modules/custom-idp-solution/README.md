# Terraform Module for AWS Transfer Family Custom IdP Solution

This is a comprehensive Terraform module that deploys the AWS Transfer Family Custom IdP solution using CodeBuild to automatically download and build the code from the GitHub repository.

## Module Structure

```
terraform-aws-transfer-custom-idp/
├── main.tf                 # Main orchestration
├── variables.tf            # Input variables
├── outputs.tf              # Module outputs
├── versions.tf             # Provider requirements
├── locals.tf               # Local values
├── s3.tf                   # S3 bucket for artifacts
├── codebuild.tf            # CodeBuild project
├── iam.tf                  # IAM roles and policies
├── lambda.tf               # Lambda function and layer
├── dynamodb.tf             # DynamoDB tables
├── vpc.tf                  # VPC resources (conditional)
├── api_gateway.tf          # API Gateway (conditional)
├── buildspec.yml           # CodeBuild specification
├── examples/
│   └── complete/
│       ├── main.tf
│       └── variables.tf
└── README.md
```

## Architecture

The module uses the following approach:

1. **CodeBuild Orchestration**: Terraform creates a CodeBuild project that downloads the solution from GitHub and executes the build script
2. **Artifact Storage**: Build artifacts (Lambda function code and layer) are stored in S3
3. **Lambda Deployment**: Terraform deploys Lambda function using the built artifacts
4. **Infrastructure**: All supporting infrastructure (DynamoDB, VPC, API Gateway) is created by Terraform

## Key Features

- **Automated Build Process**: CodeBuild automatically downloads source code and builds Lambda artifacts
- **Flexible VPC Configuration**: Create new VPC or use existing infrastructure
- **Optional API Gateway**: Choose between Lambda-only or API Gateway integration
- **Multiple IdP Support**: Supports LDAP, Okta, Cognito, Entra ID, Public Key, Secrets Manager
- **Conditional Resources**: Only create resources you need

## Usage

### Basic Usage

```hcl
module "transfer_custom_idp" {
  source = "path/to/this/module"
  
  name_prefix = "my-transfer-idp"
  
  # Use existing VPC
  use_vpc            = true
  create_vpc         = false
  vpc_id             = "vpc-12345678"
  subnet_ids         = ["subnet-12345678", "subnet-87654321"]
  security_group_ids = ["sg-12345678"]
  
  tags = {
    Environment = "production"
    Project     = "file-transfer"
  }
}

# Create AWS Transfer Family Server
resource "aws_transfer_server" "main" {
  identity_provider_type = "AWS_LAMBDA"
  function               = module.transfer_custom_idp.lambda_function_arn
  protocols              = ["SFTP"]
  endpoint_type          = "PUBLIC"
}
```

### With New VPC

```hcl
module "transfer_custom_idp" {
  source = "path/to/this/module"
  
  name_prefix = "my-transfer-idp"
  
  # Create new VPC
  use_vpc    = true
  create_vpc = true
  vpc_cidr   = "10.0.0.0/16"
  
  # Enable API Gateway
  provision_api = true
  
  tags = {
    Environment = "development"
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aws | >= 5.0 |
| null | >= 3.0 |

## Providers

| Name | Version |
|------|---------|
| aws | >= 5.0 |
| null | >= 3.0 |

## Modules

No external modules are used. All resources are created using native Terraform AWS provider resources.

## Resources

| Name | Type |
|------|------|
| aws_api_gateway_deployment.this | resource |
| aws_api_gateway_integration.lambda | resource |
| aws_api_gateway_method.get | resource |
| aws_api_gateway_resource.config | resource |
| aws_api_gateway_resource.server_id | resource |
| aws_api_gateway_resource.servers | resource |
| aws_api_gateway_resource.username | resource |
| aws_api_gateway_resource.users | resource |
| aws_api_gateway_rest_api.this | resource |
| aws_api_gateway_stage.prod | resource |
| aws_cloudwatch_log_group.codebuild | resource |
| aws_cloudwatch_log_group.lambda | resource |
| aws_codebuild_project.build | resource |
| aws_dynamodb_table.identity_providers | resource |
| aws_dynamodb_table.users | resource |
| aws_iam_role.api_gateway | resource |
| aws_iam_role.codebuild | resource |
| aws_iam_role.lambda | resource |
| aws_iam_role_policy.api_gateway | resource |
| aws_iam_role_policy.codebuild | resource |
| aws_iam_role_policy.lambda | resource |
| aws_iam_role_policy_attachment.lambda_vpc | resource |
| aws_lambda_function.handler | resource |
| aws_lambda_layer_version.dependencies | resource |
| aws_lambda_permission.api_gateway | resource |
| aws_lambda_permission.transfer_family | resource |
| aws_s3_bucket.artifacts | resource |
| aws_s3_bucket_public_access_block.artifacts | resource |
| aws_s3_bucket_server_side_encryption_configuration.artifacts | resource |
| aws_s3_bucket_versioning.artifacts | resource |
| aws_security_group.lambda | resource |
| null_resource.build_trigger | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| codebuild_compute_type | CodeBuild compute type | `string` | `"BUILD_GENERAL1_SMALL"` | no |
| codebuild_image | CodeBuild Docker image | `string` | `"aws/codebuild/amazonlinux2-x86_64-standard:5.0"` | no |
| create_vpc | Create a new VPC for the solution | `bool` | `false` | no |
| enable_tracing | Enable AWS X-Ray tracing | `bool` | `false` | no |
| force_build | Force rebuild even if artifacts exist | `bool` | `false` | no |
| github_branch | Git branch to clone | `string` | `"main"` | no |
| github_repository_url | GitHub repository URL for the custom IdP solution | `string` | `"https://github.com/aws-samples/toolkit-for-aws-transfer-family.git"` | no |
| identity_providers_table_name | Name of existing identity providers table. If not provided, a new table will be created | `string` | `""` | no |
| lambda_memory_size | Lambda function memory size in MB | `number` | `256` | no |
| lambda_runtime | Lambda function runtime | `string` | `"python3.11"` | no |
| lambda_timeout | Lambda function timeout in seconds | `number` | `60` | no |
| log_level | Log level for Lambda function (INFO or DEBUG) | `string` | `"INFO"` | no |
| name_prefix | Prefix for resource names | `string` | `"transfer-custom-idp"` | no |
| provision_api | Create API Gateway REST API | `bool` | `false` | no |
| secrets_manager_permissions | Grant Lambda access to Secrets Manager | `bool` | `true` | no |
| security_group_ids | List of security group IDs for Lambda (if not creating VPC) | `list(string)` | `[]` | no |
| solution_path | Path to solution within repository | `string` | `"solutions/custom-idp"` | no |
| subnet_ids | List of subnet IDs for Lambda (if not creating VPC) | `list(string)` | `[]` | no |
| tags | Tags to apply to all resources | `map(string)` | `{}` | no |
| use_vpc | Attach Lambda function to VPC | `bool` | `true` | no |
| username_delimiter | Delimiter for username and IdP name | `string` | `"@@"` | no |
| users_table_name | Name of existing users table. If not provided, a new table will be created | `string` | `""` | no |
| vpc_cidr | CIDR block for VPC (if creating new VPC) | `string` | `"10.0.0.0/16"` | no |
| vpc_id | Existing VPC ID (if not creating new VPC) | `string` | `""` | no |

## Outputs

| Name | Description |
|------|-------------|
| api_gateway_role_arn | ARN of the API Gateway IAM role (if provisioned) |
| api_gateway_url | URL of the API Gateway (if provisioned) |
| artifacts_bucket_name | Name of the S3 bucket storing build artifacts |
| codebuild_project_name | Name of the CodeBuild project |
| identity_providers_table_arn | ARN of the DynamoDB identity providers table |
| identity_providers_table_name | Name of the DynamoDB identity providers table |
| lambda_function_arn | ARN of the Lambda function |
| lambda_function_name | Name of the Lambda function |
| lambda_function_qualified_arn | Qualified ARN of the Lambda function |
| private_subnet_ids | IDs of private subnets (if VPC created) |
| users_table_arn | ARN of the DynamoDB users table |
| users_table_name | Name of the DynamoDB users table |
| vpc_id | ID of the VPC (if created) |

## Deployment Instructions

### Prerequisites

1. AWS CLI configured with appropriate credentials
2. Terraform >= 1.0 installed
3. Appropriate IAM permissions to create resources

### Step 1: Initialize Terraform

```bash
terraform init
```

### Step 2: Review the plan

```bash
terraform plan
```

### Step 3: Apply the configuration

```bash
terraform apply
```

This will:
1. Create S3 bucket for artifacts
2. Create and execute CodeBuild project to build Lambda artifacts
3. Deploy Lambda function and layer
4. Create DynamoDB tables
5. (Optional) Create VPC resources
6. (Optional) Create API Gateway

### Step 4: Configure Identity Providers and Users

After deployment, you need to populate the DynamoDB tables with identity provider and user configurations. See the [original solution documentation](https://github.com/aws-samples/toolkit-for-aws-transfer-family/tree/main/solutions/custom-idp) for details on configuring:

- Identity providers (LDAP, Okta, Cognito, etc.)
- User records with session settings
- Public keys (if using)

### Step 5: Create AWS Transfer Family Server

Use the Lambda function ARN output to configure your Transfer Family server with the custom identity provider.

## Examples

See the `examples/` directory for complete usage examples:

- `examples/complete/` - Complete example with existing VPC
- Example with new VPC creation
- Example with API Gateway integration

## Features

### Automated Build Process

- **CodeBuild Integration**: Automatically downloads source code from GitHub and builds Lambda artifacts
- **No Manual Build**: No need to run `build.sh` locally
- **Reproducible Builds**: Consistent build environment using CodeBuild

### Flexible Configuration

- **VPC Options**: Create new VPC or use existing infrastructure
- **API Gateway**: Optional API Gateway for WAF integration
- **Identity Providers**: Support for multiple IdP modules
- **Conditional Resources**: Only create what you need

### Production Ready

- **Logging**: CloudWatch Logs for Lambda and CodeBuild
- **Encryption**: S3 bucket encryption for artifacts
- **IAM Least Privilege**: Minimal required permissions
- **Tagging**: Consistent resource tagging

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

Note: DynamoDB tables with data will be deleted. Ensure you have backups if needed.

## Notes

1. **First Run**: The initial apply will take several minutes as CodeBuild downloads the repository and builds the Lambda artifacts.

2. **Force Rebuild**: Set `force_build = true` to force a rebuild even if artifacts exist.

3. **Build Logs**: Check CodeBuild logs in CloudWatch if build fails.

4. **VPC Endpoints**: If using private subnets, ensure VPC endpoints exist for DynamoDB, STS, and Secrets Manager.

5. **Transfer Family**: This module creates the Lambda function. You still need to create the AWS Transfer Family server separately (or use the examples provided).

## Troubleshooting

### CodeBuild Fails

Check CloudWatch Logs for the CodeBuild project. Common issues:
- GitHub repository not accessible
- Build script errors
- Permission issues with S3

### Lambda Function Errors

Check CloudWatch Logs for the Lambda function. Common issues:
- DynamoDB tables not accessible
- VPC configuration preventing network access
- Missing environment variables

### VPC Connectivity

If Lambda can't reach IdPs:
- Ensure NAT Gateway exists for internet access
- Verify security group allows outbound traffic
- Check VPC endpoints for AWS services

## Advanced Configuration

### Using with Existing DynamoDB Tables

If using existing DynamoDB tables (e.g., global tables for multi-region deployments):

```hcl
module "transfer_custom_idp" {
  source = "path/to/this/module"
  
  # Use existing tables - new tables will not be created
  users_table_name                = "global-transfer-users"
  identity_providers_table_name   = "global-transfer-identity-providers"
  
  # ... other configuration
}
```

### Custom Build Configuration

To use a specific branch or commit:

```hcl
module "transfer_custom_idp" {
  source = "path/to/this/module"
  
  github_branch = "feature-branch"
  force_build   = true  # Force rebuild on every apply
  
  # ... other configuration
}
```

## Module Dependencies

This module uses the following external dependencies:

- **AWS CLI**: Required for CodeBuild build triggering

## License

This module is released under the MIT License. The underlying AWS Transfer Family Custom IdP solution is also MIT-0 licensed.

## Contributing

Contributions are welcome! Please ensure:
- Code follows Terraform best practices
- Examples are provided for new features
- Documentation is updated

## Support

For issues with:
- **This Terraform module**: Open an issue in the module repository
- **The underlying solution**: Refer to the [AWS samples repository](https://github.com/aws-samples/toolkit-for-aws-transfer-family)
- **AWS Transfer Family**: Consult AWS documentation or support
