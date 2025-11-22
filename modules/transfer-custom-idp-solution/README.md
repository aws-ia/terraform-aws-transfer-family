# AWS Transfer Family Custom Identity Provider Solution Module

This Terraform module creates a complete custom identity provider solution for AWS Transfer Family using Lambda, DynamoDB, and optionally API Gateway. The module automatically builds Lambda artifacts from the AWS Transfer Family Toolkit GitHub repository.

## Usage

### Basic Usage (Direct Lambda)

```hcl
module "custom_idp" {
  source = "../../modules/transfer-custom-idp-solution"

  name_prefix = "my-sftp"
  
  # DynamoDB tables will be created automatically
  users_table_name              = ""
  identity_providers_table_name = ""
  
  # No VPC attachment
  use_vpc    = false
  create_vpc = false
  
  # Direct Lambda invocation (no API Gateway)
  provision_api = false
  
  tags = {
    Environment = "production"
    Project     = "file-transfer"
  }
}
```

### With VPC (Create New VPC)

```hcl
module "custom_idp" {
  source = "../../modules/transfer-custom-idp-solution"

  name_prefix = "my-sftp"
  
  # Create new VPC for Lambda
  use_vpc    = true
  create_vpc = true
  vpc_cidr   = "10.0.0.0/16"
  
  provision_api = false
  
  tags = {
    Environment = "production"
  }
}
```

### With Existing VPC

```hcl
module "custom_idp" {
  source = "../../modules/transfer-custom-idp-solution"

  name_prefix = "my-sftp"
  
  # Use existing VPC
  use_vpc            = true
  create_vpc         = false
  vpc_id             = "vpc-12345678"
  subnet_ids         = ["subnet-12345678", "subnet-87654321"]
  security_group_ids = ["sg-12345678"]
  
  provision_api = false
  
  tags = {
    Environment = "production"
  }
}
```

### With API Gateway

```hcl
module "custom_idp" {
  source = "../../modules/transfer-custom-idp-solution"

  name_prefix = "my-sftp"
  
  # Enable API Gateway
  provision_api = true
  
  use_vpc    = false
  create_vpc = false
  
  tags = {
    Environment = "production"
  }
}
```

### With Existing DynamoDB Tables

```hcl
module "custom_idp" {
  source = "../../modules/transfer-custom-idp-solution"

  name_prefix = "my-sftp"
  
  # Use existing DynamoDB tables
  users_table_name              = "existing-users-table"
  identity_providers_table_name = "existing-providers-table"
  
  use_vpc       = false
  provision_api = false
  
  tags = {
    Environment = "production"
  }
}
```

## Resources Created

### Always Created
- **Lambda Function**: Custom identity provider handler
- **Lambda Layer**: Python dependencies
- **S3 Bucket**: Stores build artifacts
- **CodeBuild Project**: Builds Lambda artifacts from GitHub
- **IAM Roles**: Lambda execution role, Transfer invocation role
- **IAM Policies**: DynamoDB access, CloudWatch Logs, optional Secrets Manager

### Conditionally Created
- **DynamoDB Tables**: Users and Identity Providers tables (if not using existing)
- **VPC Resources**: VPC, subnets, NAT gateways, security groups (if `create_vpc = true`)
- **API Gateway**: REST API, resources, methods, deployment, stage (if `provision_api = true`)

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aws | >= 5.0 |
| null | >= 3.0 |
| external | >= 2.0 |
| archive | >= 2.0 |

### Prerequisites

- AWS CLI configured (required for CodeBuild trigger)
- Internet access for GitHub repository cloning
- Appropriate AWS permissions to create resources

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| name_prefix | Prefix for resource names | `string` | `"transfer-idp"` | no |
| github_repository_url | GitHub repository URL for custom IdP solution | `string` | `"https://github.com/aws-samples/toolkit-for-aws-transfer-family.git"` | no |
| github_branch | Git branch to clone | `string` | `"main"` | no |
| solution_path | Path to solution within repository | `string` | `"solutions/custom-idp"` | no |
| use_vpc | Attach Lambda function to VPC | `bool` | `true` | no |
| create_vpc | Create a new VPC for the solution | `bool` | `false` | no |
| vpc_cidr | CIDR block for VPC (if creating new VPC) | `string` | `"10.0.0.0/16"` | no |
| vpc_id | Existing VPC ID (if not creating new VPC) | `string` | `""` | no |
| subnet_ids | List of subnet IDs for Lambda (if not creating VPC) | `list(string)` | `[]` | no |
| security_group_ids | List of security group IDs for Lambda (if not creating VPC) | `list(string)` | `[]` | no |
| lambda_timeout | Lambda function timeout in seconds | `number` | `60` | no |
| lambda_memory_size | Lambda function memory size in MB | `number` | `1024` | no |
| lambda_runtime | Lambda function runtime | `string` | `"python3.11"` | no |
| log_level | Log level for Lambda function (INFO or DEBUG) | `string` | `"INFO"` | no |
| username_delimiter | Delimiter for username and IdP name | `string` | `"@@"` | no |
| users_table_name | Name of existing users table. If empty, creates new table | `string` | `""` | no |
| identity_providers_table_name | Name of existing identity providers table. If empty, creates new table | `string` | `""` | no |
| provision_api | Create API Gateway REST API | `bool` | `false` | no |
| secrets_manager_permissions | Grant Lambda access to Secrets Manager | `bool` | `true` | no |
| enable_tracing | Enable AWS X-Ray tracing | `bool` | `false` | no |
| artifacts_force_destroy | Allow deletion of S3 bucket with artifacts | `bool` | `true` | no |
| codebuild_image | CodeBuild Docker image | `string` | `"aws/codebuild/amazonlinux2-x86_64-standard:5.0"` | no |
| codebuild_compute_type | CodeBuild compute type | `string` | `"BUILD_GENERAL1_SMALL"` | no |
| force_build | Force rebuild even if artifacts exist | `bool` | `false` | no |
| tags | Tags to apply to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| lambda_function_arn | Lambda function ARN for identity provider |
| lambda_function_name | Lambda function name |
| lambda_function_qualified_arn | Qualified ARN of the Lambda function |
| transfer_invocation_role_arn | Transfer Family invocation role ARN |
| api_gateway_url | API Gateway URL (if provisioned) |
| api_gateway_role_arn | ARN of the API Gateway IAM role (if provisioned) |
| artifacts_bucket_name | Name of the S3 bucket storing build artifacts |
| codebuild_project_name | Name of the CodeBuild project |
| users_table_name | DynamoDB users table name |
| users_table_arn | DynamoDB users table ARN |
| identity_providers_table_name | DynamoDB identity providers table name |
| identity_providers_table_arn | DynamoDB identity providers table ARN |
| vpc_id | ID of the created VPC (if created) |
| private_subnet_ids | IDs of the private subnets (if VPC created) |
| security_group_id | ID of the Lambda security group (if VPC created) |


