<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0.7 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.83.0 |
| <a name="requirement_awscc"></a> [awscc](#requirement\_awscc) | >= 0.24.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.94.1 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.7.1 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_s3_bucket"></a> [s3\_bucket](#module\_s3\_bucket) | git::https://github.com/terraform-aws-modules/terraform-aws-s3-bucket.git | fc09cc6fb779b262ce1bee5334e85808a107d8a3 |
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
| <a name="input_route53_hosted_zone_name"></a> [route53\_hosted\_zone\_name](#input\_route53\_hosted\_zone\_name) | The name of the Route53 hosted zone to use (must end with a period, e.g., 'example.com.') | `string` | `null` | no |
| <a name="input_users_file"></a> [users\_file](#input\_users\_file) | Path to CSV file containing user configurations | `string` | `"users.csv"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_server_endpoint"></a> [server\_endpoint](#output\_server\_endpoint) | The endpoint of the created Transfer Family server |
| <a name="output_server_id"></a> [server\_id](#output\_server\_id) | The ID of the created Transfer Family server |
| <a name="output_sftp_bucket_name"></a> [sftp\_bucket\_name](#output\_sftp\_bucket\_name) | The name of the S3 bucket used for SFTP storage |
| <a name="output_user_details"></a> [user\_details](#output\_user\_details) | Map of users with their details including secret names and ARNs |
<!-- END_TF_DOCS -->