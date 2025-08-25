# AWS Transfer Family SFTP Connector Module

This module creates an AWS Transfer Family SFTP connector that connects an S3 bucket to an external SFTP server.

## Features

- Creates an AWS Transfer Family SFTP connector
- Sets up necessary IAM roles and policies for the connector
- Configures CloudWatch logging for the connector
- Manages SFTP connection settings and security policies

## Usage

```hcl
module "sftp_connector" {
  source = "aws-ia/transfer-family/aws//modules/transfer-connectors"

  connector_name        = "my-sftp-connector"
  sftp_server_url       = "sftp://example.com:22"
  s3_bucket_arn         = module.s3_bucket.s3_bucket_arn
  s3_bucket_name        = module.s3_bucket.s3_bucket_id
  user_secret_id        = aws_secretsmanager_secret.sftp_credentials.arn
  kms_key_arn           = aws_kms_key.transfer_family_key.arn
  aws_region            = var.aws_region
  trust_all_certificates = false
  security_policy_name  = "TransferSecurityPolicy-2024-01"

  tags = {
    Environment = "Production"
    Project     = "File Transfer"
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5 |
| aws | >= 5.95.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| connector_name | Name of the AWS Transfer Family connector | `string` | `"sftp-connector"` | no |
| sftp_server_url | URL of the SFTP server to connect to (e.g., sftp://example.com:22) | `string` | n/a | yes |
| s3_bucket_arn | ARN of the S3 bucket to connect to the SFTP server | `string` | n/a | yes |
| s3_bucket_name | Name of the S3 bucket to connect to the SFTP server | `string` | n/a | yes |
| user_secret_id | ARN of the AWS Secrets Manager secret containing SFTP credentials | `string` | n/a | yes |
| as2_username | Username for AS2 basic authentication | `string` | `""` | no |
| as2_password | Password for AS2 basic authentication | `string` | `""` | no |
| trust_all_certificates | Whether to trust all certificates for the SFTP connection | `bool` | `false` | no |
| security_policy_name | The name of the security policy to use for the connector | `string` | `"TransferSecurityPolicy-2024-01"` | no |
| logging_role | IAM role ARN for CloudWatch logging (if not provided, a new role will be created) | `string` | `null` | no |
| kms_key_arn | ARN of the KMS key used for encryption | `string` | n/a | yes |
| aws_region | AWS region where resources will be created | `string` | n/a | yes |
| tags | A map of tags to assign to resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| connector_id | The ID of the AWS Transfer Family connector |
| connector_arn | The ARN of the AWS Transfer Family connector |
| connector_url | The URL of the SFTP server the connector connects to |
| connector_role_arn | The ARN of the IAM role used by the connector |
| connector_logging_role_arn | The ARN of the IAM role used for connector logging (if created) |

## Security Considerations

- The module creates IAM roles with least privilege permissions
- Secrets for SFTP authentication are stored in AWS Secrets Manager
- KMS encryption is used for securing sensitive data
- Security policies can be configured to enforce secure connections

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.95.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_archive"></a> [archive](#provider\_archive) | n/a |
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.95.0 |
| <a name="provider_external"></a> [external](#provider\_external) | n/a |
| <a name="provider_null"></a> [null](#provider\_null) | n/a |
| <a name="provider_random"></a> [random](#provider\_random) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_iam_policy.connector_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.connector_logging_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.connector_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.lambda_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.rotation_lambda_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.lambda_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.connector_logging_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.connector_policy_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.rotation_lambda_basic](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_lambda_function.rotation_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_permission.allow_secretsmanager](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_secretsmanager_secret.sftp_credentials](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret_rotation.sftp_credentials_rotation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_rotation) | resource |
| [aws_secretsmanager_secret_version.sftp_credentials](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [aws_transfer_connector.sftp_connector](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/transfer_connector) | resource |
| [null_resource.discover_and_test_connector](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [random_id.connector_id](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [archive_file.rotation_lambda_zip](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [external_external.connector_ips](https://registry.terraform.io/providers/hashicorp/external/latest/docs/data-sources/external) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_S3_kms_key_arn"></a> [S3\_kms\_key\_arn](#input\_S3\_kms\_key\_arn) | ARN of the KMS key used for encryption (optional) | `string` | `null` | no |
| <a name="input_connector_name"></a> [connector\_name](#input\_connector\_name) | Name of the AWS Transfer Family connector | `string` | `"sftp-connector"` | no |
| <a name="input_create_secret"></a> [create\_secret](#input\_create\_secret) | Whether to create a new secret for SFTP credentials | `bool` | `false` | no |
| <a name="input_logging_role"></a> [logging\_role](#input\_logging\_role) | IAM role ARN for CloudWatch logging (if not provided, a new role will be created) | `string` | `null` | no |
| <a name="input_s3_bucket_arn"></a> [s3\_bucket\_arn](#input\_s3\_bucket\_arn) | ARN of the S3 bucket to connect to the SFTP server | `string` | n/a | yes |
| <a name="input_s3_bucket_name"></a> [s3\_bucket\_name](#input\_s3\_bucket\_name) | Name of the S3 bucket to connect to the SFTP server | `string` | n/a | yes |
| <a name="input_secret_kms_key_id"></a> [secret\_kms\_key\_id](#input\_secret\_kms\_key\_id) | KMS key ID for encrypting the secret | `string` | `null` | no |
| <a name="input_secret_name"></a> [secret\_name](#input\_secret\_name) | Name for the new secret (only used when create\_secret is true) | `string` | `null` | no |
| <a name="input_secrets_manager_kms_key_arn"></a> [secrets\_manager\_kms\_key\_arn](#input\_secrets\_manager\_kms\_key\_arn) | ARN of the KMS key used to encrypt the secrets manager secret containing SFTP credentials | `string` | `null` | no |
| <a name="input_security_policy_name"></a> [security\_policy\_name](#input\_security\_policy\_name) | The name of the security policy to use for the connector (must be in the format TransferSFTPConnectorSecurityPolicy-*) | `string` | `"TransferSFTPConnectorSecurityPolicy-2024-03"` | no |
| <a name="input_sftp_password"></a> [sftp\_password](#input\_sftp\_password) | SFTP password for authentication (optional if using private key) | `string` | `""` | no |
| <a name="input_sftp_private_key"></a> [sftp\_private\_key](#input\_sftp\_private\_key) | SFTP private key for authentication (optional if using password) | `string` | `""` | no |
| <a name="input_sftp_username"></a> [sftp\_username](#input\_sftp\_username) | SFTP username for authentication | `string` | `""` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to assign to resources | `map(string)` | `{}` | no |
| <a name="input_test_connector_post_deployment"></a> [test\_connector\_post\_deployment](#input\_test\_connector\_post\_deployment) | Whether to test the connector connection after deployment | `bool` | `false` | no |
| <a name="input_trusted_host_keys"></a> [trusted\_host\_keys](#input\_trusted\_host\_keys) | List of trusted host keys for the SFTP server. If empty, SSH key auto-discovery will run automatically. | `list(string)` | `[]` | no |
| <a name="input_url"></a> [url](#input\_url) | URL of the SFTP server to connect to (e.g., example.com or sftp://example.com:22) | `string` | n/a | yes |
| <a name="input_user_secret_id"></a> [user\_secret\_id](#input\_user\_secret\_id) | ARN of the AWS Secrets Manager secret containing SFTP credentials (optional - will auto-detect for AWS Transfer Family servers) | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_connector_arn"></a> [connector\_arn](#output\_connector\_arn) | The ARN of the AWS Transfer Family connector |
| <a name="output_connector_id"></a> [connector\_id](#output\_connector\_id) | The ID of the AWS Transfer Family connector |
| <a name="output_connector_logging_role_arn"></a> [connector\_logging\_role\_arn](#output\_connector\_logging\_role\_arn) | The ARN of the IAM role used for connector logging (if created) |
| <a name="output_connector_role_arn"></a> [connector\_role\_arn](#output\_connector\_role\_arn) | The ARN of the IAM role used by the connector |
| <a name="output_connector_static_ips"></a> [connector\_static\_ips](#output\_connector\_static\_ips) | Static IP addresses of the created SFTP connector (if available via AWS CLI) |
| <a name="output_connector_url"></a> [connector\_url](#output\_connector\_url) | The URL of the SFTP server the connector connects to |
| <a name="output_effective_host_keys"></a> [effective\_host\_keys](#output\_effective\_host\_keys) | The actual host keys being used by the connector (either scanned or provided) |
| <a name="output_scanned_host_keys"></a> [scanned\_host\_keys](#output\_scanned\_host\_keys) | The SSH host keys discovered from the remote SFTP server |
| <a name="output_secret_arn"></a> [secret\_arn](#output\_secret\_arn) | ARN of the created secret (if create\_secret is true) |
| <a name="output_ssh_scanning_enabled"></a> [ssh\_scanning\_enabled](#output\_ssh\_scanning\_enabled) | Whether SSH host key scanning was performed for this connector |
<!-- END_TF_DOCS -->