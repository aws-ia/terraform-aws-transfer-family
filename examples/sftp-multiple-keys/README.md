<!-- BEGIN_TF_DOCS -->
# SFTP Server with Multiple SSH Keys Example

This example demonstrates how to create an AWS Transfer Family SFTP server with users that have multiple SSH public keys. This configuration showcases:

- **Single Key User**: Traditional single SSH key configuration for backward compatibility.
- **Multiple Key User**: User with multiple SSH keys for key rotation and redundancy.
- **Key Rotation User**: User with both current and new keys for seamless rotation.

## Key Features

- Support for both single and multiple SSH keys per user
- Demonstrates key rotation scenarios
- Shows mixed user configurations in the same deployment
- Uses service-managed identity provider
- Includes S3 bucket with KMS encryption
- CloudWatch logging enabled

## Usage

Replace the example SSH keys in the `users` local variable with your actual public keys before deploying.

**Note**: The SSH keys in this example are truncated for readability. You must provide complete, valid SSH public keys.

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.95.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.95.0 |
| <a name="provider_random"></a> [random](#provider\_random) | >= 3.0.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_s3_bucket"></a> [s3\_bucket](#module\_s3\_bucket) | git::https://github.com/terraform-aws-modules/terraform-aws-s3-bucket.git | v4.1.2 |
| <a name="module_sftp_users"></a> [sftp\_users](#module\_sftp\_users) | ../../modules/transfer-users | n/a |
| <a name="module_transfer_server"></a> [transfer\_server](#module\_transfer\_server) | ../.. | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_kms_alias.transfer_family_key_alias](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.transfer_family_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_kms_key_policy.transfer_family_key_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key_policy) | resource |
| [random_pet.name](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/pet) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region | `string` | `"us-east-1"` | no |
| <a name="input_custom_hostname"></a> [custom\_hostname](#input\_custom\_hostname) | The custom hostname for the Transfer Family server | `string` | `null` | no |
| <a name="input_dns_provider"></a> [dns\_provider](#input\_dns\_provider) | The DNS provider for the custom hostname. Use null for no custom hostname | `string` | `null` | no |
| <a name="input_logging_role"></a> [logging\_role](#input\_logging\_role) | IAM role ARN that the Transfer Server assumes to write logs to CloudWatch Logs | `string` | `null` | no |
| <a name="input_route53_hosted_zone_name"></a> [route53\_hosted\_zone\_name](#input\_route53\_hosted\_zone\_name) | The name of the Route53 hosted zone to use (must end with a period, e.g., 'example.com.') | `string` | `null` | no |
| <a name="input_users"></a> [users](#input\_users) | List of users to create for the Transfer Family server | <pre>list(object({<br/>    username   = string<br/>    home_dir   = string<br/>    public_key = string<br/>  }))</pre> | `[]` | no |
| <a name="input_workflow_details"></a> [workflow\_details](#input\_workflow\_details) | Workflow details to attach to the transfer server | <pre>object({<br/>    on_upload = optional(object({<br/>      execution_role = string<br/>      workflow_id    = string<br/>    }))<br/>    on_partial_upload = optional(object({<br/>      execution_role = string<br/>      workflow_id    = string<br/>    }))<br/>  })</pre> | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_s3_bucket_name"></a> [s3\_bucket\_name](#output\_s3\_bucket\_name) | Name of the S3 bucket used for file storage |
| <a name="output_server_endpoint"></a> [server\_endpoint](#output\_server\_endpoint) | Endpoint of the Transfer Family server |
| <a name="output_server_id"></a> [server\_id](#output\_server\_id) | ID of the Transfer Family server |
| <a name="output_user_details"></a> [user\_details](#output\_user\_details) | Details of created users including their public keys |
<!-- END_TF_DOCS -->