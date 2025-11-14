# Custom Identity Providers Module

This module creates AWS Transfer Family custom identity providers using native Terraform resources.

## Usage

```hcl
module "custom_idp" {
  source = "./modules/custom-idps"

  lambda_zip_path = "path/to/lambda.zip"
  stack_name      = "my-custom-idp"
  
  use_vpc         = true
  subnets         = "subnet-12345678,subnet-87654321"
  security_groups = "sg-12345678"
  
  provision_api = true
  
  tags = {
    Environment = "prod"
  }
}
```

## Resources Created

- Lambda function for identity provider logic
- DynamoDB tables for users and identity providers (optional)
- API Gateway for REST API (optional)
- IAM roles and policies
- CloudWatch logs

## Requirements

- Lambda deployment package (ZIP file)
- VPC configuration if `use_vpc = true`

## Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| lambda_zip_path | Path to Lambda ZIP file | string | n/a |
| stack_name | Resource name prefix | string | "sam-app" |
| use_vpc | Use VPC configuration | bool | true |
| provision_api | Create API Gateway | bool | false |

## Outputs

| Name | Description |
|------|-------------|
| lambda_function_arn | Lambda function ARN |
| transfer_invocation_role_arn | Transfer invocation role ARN |
