<!-- BEGIN_TF_DOCS -->
# AWS Transfer Family Custom Identity Provider Solution Module

This Terraform module creates a complete custom identity provider solution for AWS Transfer Family using Lambda, DynamoDB, and optionally API Gateway. The module automatically builds Lambda artifacts from the AWS Transfer Family Toolkit GitHub repository.

## Features

- **Lambda-based Identity Provider**: Validates user credentials and returns Transfer Family configuration
- **DynamoDB Storage**: Stores user configurations and identity provider settings
- **Multiple Identity Provider Support**: Cognito, Active Directory, LDAP, public key authentication
- **API Gateway Integration**: Optional REST API for Transfer Family invocation
- **VPC Support**: Optional VPC attachment for Lambda function
- **Automated Build**: CodeBuild automatically builds Lambda artifacts from GitHub
- **Flexible Configuration**: Use existing or create new DynamoDB tables and VPC resources

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
- **IAM Roles**: Lambda execution role, Transfer/API Gateway invocation role
- **IAM Policies**: DynamoDB access, CloudWatch Logs, optional Secrets Manager

### Conditionally Created
- **DynamoDB Tables**: Users and Identity Providers tables (if not using existing)
- **VPC Resources**: VPC, subnets, NAT gateways, security groups (if `create_vpc = true`)
- **API Gateway**: REST API, resources, methods, deployment, stage (if `provision_api = true`)

## Examples

For complete working examples, see:
- [SFTP with Cognito (Lambda)](../../examples/sftp-idp-cognito-lambda) - Direct Lambda invocation
- [SFTP with Cognito (API Gateway)](../../examples/sftp-idp-cognito-api-gateway) - API Gateway integration

### Prerequisites

- AWS CLI configured (required for CodeBuild trigger)
- Internet access for GitHub repository cloning
- Appropriate AWS permissions to create resources

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.95.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.95.0 |
| <a name="provider_null"></a> [null](#provider\_null) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_api_gateway_deployment.identity_provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_deployment) | resource |
| [aws_api_gateway_integration.lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_integration) | resource |
| [aws_api_gateway_integration_response.success](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_integration_response) | resource |
| [aws_api_gateway_method.get_user_config](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_method) | resource |
| [aws_api_gateway_method_response.success](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_method_response) | resource |
| [aws_api_gateway_resource.config](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_resource) | resource |
| [aws_api_gateway_resource.server_id](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_resource) | resource |
| [aws_api_gateway_resource.servers](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_resource) | resource |
| [aws_api_gateway_resource.username](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_resource) | resource |
| [aws_api_gateway_resource.users](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_resource) | resource |
| [aws_api_gateway_rest_api.identity_provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_rest_api) | resource |
| [aws_api_gateway_stage.identity_provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_stage) | resource |
| [aws_codebuild_project.build](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/codebuild_project) | resource |
| [aws_dynamodb_table.identity_providers](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table) | resource |
| [aws_dynamodb_table.users](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table) | resource |
| [aws_eip.nat](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip) | resource |
| [aws_iam_role.codebuild_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.lambda_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.transfer_api_gateway_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.transfer_invocation_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.codebuild_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.dynamodb_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.secrets_manager](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.transfer_api_gateway_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.transfer_invoke_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.xray_tracing](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.lambda_api_gateway](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.lambda_basic](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.lambda_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_internet_gateway.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway) | resource |
| [aws_lambda_function.identity_provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_layer_version.dependencies](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_layer_version) | resource |
| [aws_lambda_permission.api_gateway_invoke](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_lambda_permission.transfer_invoke](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_nat_gateway.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/nat_gateway) | resource |
| [aws_route_table.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table_association.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_route_table_association.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_s3_bucket.artifacts](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_public_access_block.artifacts](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.artifacts](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.artifacts](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [aws_security_group.lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_subnet.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_subnet.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_vpc.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc) | resource |
| [aws_vpc_endpoint.dynamodb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_endpoint.s3](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [null_resource.build_trigger](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_s3_object.function_artifact](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/s3_object) | data source |
| [aws_s3_object.layer_artifact](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/s3_object) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_artifacts_force_destroy"></a> [artifacts\_force\_destroy](#input\_artifacts\_force\_destroy) | Allow deletion of S3 bucket with artifacts. Safe to enable as artifacts can be recreated | `bool` | `true` | no |
| <a name="input_codebuild_compute_type"></a> [codebuild\_compute\_type](#input\_codebuild\_compute\_type) | CodeBuild compute type | `string` | `"BUILD_GENERAL1_SMALL"` | no |
| <a name="input_codebuild_image"></a> [codebuild\_image](#input\_codebuild\_image) | CodeBuild Docker image | `string` | `"aws/codebuild/amazonlinux2-x86_64-standard:5.0"` | no |
| <a name="input_create_vpc"></a> [create\_vpc](#input\_create\_vpc) | Create a new VPC for the solution | `bool` | `false` | no |
| <a name="input_enable_deletion_protection"></a> [enable\_deletion\_protection](#input\_enable\_deletion\_protection) | Enable deletion protection for DynamoDB tables. This is enabled by default to prevent accidental deletion. | `bool` | `true` | no |
| <a name="input_enable_tracing"></a> [enable\_tracing](#input\_enable\_tracing) | Enable AWS X-Ray tracing | `bool` | `false` | no |
| <a name="input_force_build"></a> [force\_build](#input\_force\_build) | Force rebuild even if artifacts exist | `bool` | `false` | no |
| <a name="input_github_branch"></a> [github\_branch](#input\_github\_branch) | Git branch to clone | `string` | `"main"` | no |
| <a name="input_github_repository_url"></a> [github\_repository\_url](#input\_github\_repository\_url) | GitHub repository URL for the custom IdP solution | `string` | `"https://github.com/aws-samples/toolkit-for-aws-transfer-family.git"` | no |
| <a name="input_identity_providers_table_name"></a> [identity\_providers\_table\_name](#input\_identity\_providers\_table\_name) | Name of existing identity providers table. If not provided, a new table will be created | `string` | `""` | no |
| <a name="input_lambda_memory_size"></a> [lambda\_memory\_size](#input\_lambda\_memory\_size) | Lambda function memory size in MB | `number` | `1024` | no |
| <a name="input_lambda_runtime"></a> [lambda\_runtime](#input\_lambda\_runtime) | Lambda function runtime | `string` | `"python3.11"` | no |
| <a name="input_lambda_timeout"></a> [lambda\_timeout](#input\_lambda\_timeout) | Lambda function timeout in seconds | `number` | `60` | no |
| <a name="input_log_level"></a> [log\_level](#input\_log\_level) | Log level for Lambda function (INFO or DEBUG) | `string` | `"INFO"` | no |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Prefix for resource names | `string` | `"transfer-idp"` | no |
| <a name="input_provision_api"></a> [provision\_api](#input\_provision\_api) | Create API Gateway REST API | `bool` | `false` | no |
| <a name="input_secrets_manager_permissions"></a> [secrets\_manager\_permissions](#input\_secrets\_manager\_permissions) | Grant Lambda access to Secrets Manager | `bool` | `true` | no |
| <a name="input_security_group_ids"></a> [security\_group\_ids](#input\_security\_group\_ids) | List of security group IDs for Lambda (if not creating VPC) | `list(string)` | `[]` | no |
| <a name="input_solution_path"></a> [solution\_path](#input\_solution\_path) | Path to solution within repository | `string` | `"solutions/custom-idp"` | no |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | List of subnet IDs for Lambda (if not creating VPC) | `list(string)` | `[]` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to all resources | `map(string)` | `{}` | no |
| <a name="input_use_vpc"></a> [use\_vpc](#input\_use\_vpc) | Attach Lambda function to VPC | `bool` | `true` | no |
| <a name="input_username_delimiter"></a> [username\_delimiter](#input\_username\_delimiter) | Delimiter for username and IdP name | `string` | `"@@"` | no |
| <a name="input_users_table_name"></a> [users\_table\_name](#input\_users\_table\_name) | Name of existing users table. If not provided, a new table will be created | `string` | `""` | no |
| <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr) | CIDR block for VPC (if creating new VPC) | `string` | `"10.0.0.0/16"` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | Existing VPC ID (if not creating new VPC) | `string` | `""` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_api_gateway_role_arn"></a> [api\_gateway\_role\_arn](#output\_api\_gateway\_role\_arn) | ARN of the API Gateway IAM role (if provisioned) |
| <a name="output_api_gateway_url"></a> [api\_gateway\_url](#output\_api\_gateway\_url) | API Gateway URL (if provisioned) |
| <a name="output_artifacts_bucket_name"></a> [artifacts\_bucket\_name](#output\_artifacts\_bucket\_name) | Name of the S3 bucket storing the build artifacts |
| <a name="output_codebuild_project_name"></a> [codebuild\_project\_name](#output\_codebuild\_project\_name) | Name of the CodeBuild project that was used to build the artifacts |
| <a name="output_identity_providers_table_arn"></a> [identity\_providers\_table\_arn](#output\_identity\_providers\_table\_arn) | DynamoDB identity providers table ARN |
| <a name="output_identity_providers_table_name"></a> [identity\_providers\_table\_name](#output\_identity\_providers\_table\_name) | DynamoDB identity providers table name |
| <a name="output_lambda_function_arn"></a> [lambda\_function\_arn](#output\_lambda\_function\_arn) | Lambda function ARN for identity provider |
| <a name="output_lambda_function_name"></a> [lambda\_function\_name](#output\_lambda\_function\_name) | Lambda function name |
| <a name="output_lambda_function_qualified_arn"></a> [lambda\_function\_qualified\_arn](#output\_lambda\_function\_qualified\_arn) | Qualified ARN of the Lambda function |
| <a name="output_private_subnet_ids"></a> [private\_subnet\_ids](#output\_private\_subnet\_ids) | IDs of the private subnets |
| <a name="output_security_group_id"></a> [security\_group\_id](#output\_security\_group\_id) | ID of the Lambda security group |
| <a name="output_transfer_invocation_role_arn"></a> [transfer\_invocation\_role\_arn](#output\_transfer\_invocation\_role\_arn) | Transfer Family invocation role ARN |
| <a name="output_users_table_arn"></a> [users\_table\_arn](#output\_users\_table\_arn) | DynamoDB users table ARN |
| <a name="output_users_table_name"></a> [users\_table\_name](#output\_users\_table\_name) | DynamoDB users table name |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | ID of the created VPC |
<!-- END_TF_DOCS -->