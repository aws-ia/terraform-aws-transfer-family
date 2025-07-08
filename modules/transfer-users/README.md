<!-- BEGIN_TF_DOCS -->
# AWS Transfer Family User Import Module

This module allows import of SFTP users for AWS Transfer Family servers.

## Overview

The Transfer Users module handles:

- SFTP user import
- IAM role and policy configuration
- S3 bucket access permissions
- Optional demo test user creation

## Features

### User Management

This module provides user import functionality for AWS Transfer Family. For example CSV configuration and implementation, see the ([../examples/sftp-public-endpoint-service-managed-S3/README.md#user-management](https://github.com/aws-ia/terraform-aws-transfer-family/blob/dev/examples/sftp-public-endpoint-service-managed-S3/.header.md)) in the SFTP public endpoint example.

Key capabilities:

- Bulk user creation via CSV file
- Home directory mapping to S3 paths:

```
home_directory_type = "LOGICAL"
home_directory_mappings {
  entry = "/"
  target = "/${s3_bucket_name}${home_dir}"
}
```

### Security Configuration

- IAM role creation
- S3 bucket access controls
- KMS encryption support for S3
- SSH key pair generation for test users (Demo purpose only)

## Module Structure

### Core Resources

- `aws_transfer_user`: Creates SFTP users in AWS Transfer Family
- `aws_transfer_ssh_key`: Creates SSH keys for test user only
- `aws_iam_role` and `aws_iam_role_policy`: Sets up IAM roles and policies for user access
- `aws_secretsmanager_secret`: Stores SSH keys for test users (when enabled)

### Key Configurations

- User home directory mapping to S3 paths
- IAM policies for S3 and KMS access
- Optional test user creation with automated key generation

## IAM Permissions

The module creates IAM roles with permissions for:

- S3 bucket listing and object operations
- KMS key usage for encryption/decryption
- Transfer Family service assume role capabilities

## Best Practices

- Use the `users` variable for bulk user management
- Implement custom IAM roles for granular access control
- Regularly rotate SSH keys for production users
- Monitor user access patterns through CloudWatch Logs
- Use KMS encryption for enhanced security of S3 data and Secrets Manager

## Considerations

- Ensure the AWS region is consistent across all related resources
- Use `create_test_user` for demo purposes only
- Regularly review and update IAM policies to maintain least privilege

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0.7 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.83.0 |
| <a name="requirement_awscc"></a> [awscc](#requirement\_awscc) | >= 0.24.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.0.0 |
| <a name="requirement_tls"></a> [tls](#requirement\_tls) | >= 4.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.83.0 |
| <a name="provider_random"></a> [random](#provider\_random) | >= 3.0.0 |
| <a name="provider_tls"></a> [tls](#provider\_tls) | >= 4.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_iam_role.sftp_user_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.sftp_user_policies](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_secretsmanager_secret.sftp_private_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret_version.sftp_private_key_version](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [aws_transfer_ssh_key.user_ssh_keys](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/transfer_ssh_key) | resource |
| [aws_transfer_user.transfer_users](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/transfer_user) | resource |
| [random_pet.name](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/pet) | resource |
| [tls_private_key.test_user_key](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_s3_bucket_arn"></a> [s3\_bucket\_arn](#input\_s3\_bucket\_arn) | ARN of the S3 bucket for SFTP storage | `string` | n/a | yes |
| <a name="input_s3_bucket_name"></a> [s3\_bucket\_name](#input\_s3\_bucket\_name) | Name of the S3 bucket for SFTP storage | `string` | n/a | yes |
| <a name="input_server_id"></a> [server\_id](#input\_server\_id) | ID of the Transfer Family server | `string` | n/a | yes |
| <a name="input_create_test_user"></a> [create\_test\_user](#input\_create\_test\_user) | Whether to create a test SFTP user | `bool` | `false` | no |
| <a name="input_kms_key_id"></a> [kms\_key\_id](#input\_kms\_key\_id) | encryption key | `string` | `null` | no |
| <a name="input_users"></a> [users](#input\_users) | List of SFTP users | <pre>list(object({<br/>    username   = string<br/>    home_dir   = string<br/>    public_key = string<br/>    role_arn   = optional(string)<br/>  }))</pre> | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_created_users"></a> [created\_users](#output\_created\_users) | List of created usernames |
| <a name="output_test_user_secret"></a> [test\_user\_secret](#output\_test\_user\_secret) | Test user private key secret |
| <a name="output_user_details"></a> [user\_details](#output\_user\_details) | Map of users with their details |
<!-- END_TF_DOCS -->