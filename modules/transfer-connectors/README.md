<!-- BEGIN_TF_DOCS -->
# AWS Transfer Family Terraform Module

This repository contains Terraform code which creates resources required to run a Transfer Family Server within AWS.

## Overview

This module creates and configures an AWS Transfer Server with the following features:

- Basic Transfer Server setup with SFTP protocol and security policies
- Custom hostname support through AWS Route53 or other DNS providers(Optional)
- CloudWatch logging configuration with customizable retention

## Quick Start

```hcl
module "transfer_sftp" {
  source = "aws-ia/transfer-family/aws//modules/transfer-server"

  identity_provider = "SERVICE_MANAGED"
  protocols             = ["SFTP"]
  domain               = "S3"

  tags = {
    Environment = "Dev"
    Project     = "File Transfer"
  }
}
```

## Architecture

### High-Level Architecture

![High-Level Architecture](https://github.com/aws-ia/terraform-aws-transfer-family/blob/dev/images/AWS%20Transfer%20Family%20Architecture.png)

Figure 1: High-level architecture of AWS Transfer Family deployment using this Terraform module

## Features

### Transfer Server Configuration

- Deploy SFTP server endpoints with public endpoint type
- Server name customization (default: "transfer-server")
- S3 domain support
- SFTP protocol support
- Service-managed identity provider
- Support for custom hostnames and DNS configurations
- Integration with CloudWatch for logging and monitoring

### DNS Management

#### DNS Configuration

This module supports custom DNS configurations for your Transfer Family server using Route 53 or other DNS providers.

#### Route 53 Integration

```
dns_provider = "route53"
custom_hostname = "sftp.example.com"
route53_hosted_zone_name = "example.com."
```

For Other DNS Providers:

```
dns_provider = "other"
custom_hostname = "sftp.example.com"
```

#### The module checks

```
Route 53 configurations are complete when selected
Custom hostname is provided when a DNS provider is specified
```

### Logging Features

- Optional CloudWatch logging
- Configurable log retention period (default: 30 days)
- Automated IAM role and policy configuration for logging
- AWS managed logging policy attachment

## Security Policy Support

Supports multiple AWS Transfer security policies including:

- Standard policies (2018-11 through 2024-01)
- FIPS-compliant policies
- PQ-SSH Experimental policies
- Restricted security policies

## Validation Checks

The module includes several built-in checks to ensure proper configuration:

- Route53 configuration validation
- Custom hostname verification
- DNS provider configuration checks
- Domain name compatibility verification
- Security policy name validation

## Best Practices

- Enable CloudWatch logging for audit and monitoring purposes (optional, configurable via enable\_logging variable)
- Use the latest security policies (default is TransferSecurityPolicy-2024-01, configurable with validation)
- Configure proper DNS settings when using custom hostnames (validated through check blocks)
- Utilize built-in validation checks for DNS provider and custom hostname configurations
- Use proper tagging for resources (supported via tags variable)

## Modules

This project utilizes multiple modules to create a complete AWS Transfer Family SFTP solution:

### Core Transfer Server Module (main module)

- Purpose: Creates and configures the AWS Transfer Server
- Key features:
  - SFTP protocol support
  - Public endpoint configuration
  - CloudWatch logging setup
  - Service-managed authentication
  - Custom hostname support (optional)

### Transfer Users Module

- Purpose: Manages SFTP user access and permissions
- Key features:
  - CSV-based user configuration support
  - Optional test user creation
  - IAM role and policy management
  - Integration with S3 bucket permissions
  - KMS encryption key access management

## Installation

To use these modules in your Terraform configuration:

1. Reference the modules in your Terraform code:

```hcl
module "transfer_server" {
  source = "aws-ia/transfer-family/aws//modules/transfer-server"

  # Module parameters
  # ...
}
```

2. Initialize your Terraform workspace:

```bash
terraform init
```

3. Review the planned changes:

```bash
terraform plan
```

4. Apply the configuration:

```bash
terraform apply
```

## Basic Usage

### Simple SFTP Server Setup

```hcl
module "transfer_server" {
  source = "aws-ia/transfer-family/aws//modules/transfer-server"

  # Basic server configuration
  server_name       = "demo-transfer-server"
  domain           = "S3"
  protocols        = ["SFTP"]
  endpoint_type    = "PUBLIC"
  identity_provider = "SERVICE_MANAGED"

  # Enable logging
  enable_logging    = true
  log_retention_days = 14

  tags = {
    Environment = "Demo"
    Project     = "SFTP"
  }
}
```

## Example for Internet Facing VPC Endpoint Configuration

This example demonstrates an internet-facing VPC endpoint configuration:

```hcl
module "transfer_server" {
  # Other configurations go here
  endpoint_type = "VPC"
  endpoint_details = {
    address_allocation_ids = aws_eip.sftp[*].allocation_id  # Makes the endpoint internet-facing
    security_group_ids     = [aws_security_group.sftp.id]
    subnet_ids             = local.public_subnets
    vpc_id                 = local.vpc_id
  }
}
```

Key points about VPC endpoint types:
- **Internet-facing endpoint**: Created when `address_allocation_ids` are specified (as shown in this example)
- Internet-facing endpoints require Elastic IPs and public subnets
- **Internal endpoint**: Created when `address_allocation_ids` are omitted
- Internal endpoints are only accessible from within the VPC or connected networks

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
| <a name="provider_random"></a> [random](#provider\_random) | n/a |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |

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
| [random_id.connector_id](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [terraform_data.discover_and_test_connector](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [archive_file.rotation_lambda_zip](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [external_external.connector_ips](https://registry.terraform.io/providers/hashicorp/external/latest/docs/data-sources/external) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_s3_bucket_arn"></a> [s3\_bucket\_arn](#input\_s3\_bucket\_arn) | ARN of the S3 bucket to connect to the SFTP server | `string` | n/a | yes |
| <a name="input_s3_bucket_name"></a> [s3\_bucket\_name](#input\_s3\_bucket\_name) | Name of the S3 bucket to connect to the SFTP server | `string` | n/a | yes |
| <a name="input_url"></a> [url](#input\_url) | URL of the SFTP server to connect to (e.g., example.com or sftp://example.com:22) | `string` | n/a | yes |
| <a name="input_S3_kms_key_arn"></a> [S3\_kms\_key\_arn](#input\_S3\_kms\_key\_arn) | ARN of the KMS key used for encryption (optional) | `string` | `null` | no |
| <a name="input_as2_mdn_response"></a> [as2\_mdn\_response](#input\_as2\_mdn\_response) | AS2 MDN response for the connector | `string` | `"NONE"` | no |
| <a name="input_as2_mdn_signing_algorithm"></a> [as2\_mdn\_signing\_algorithm](#input\_as2\_mdn\_signing\_algorithm) | AS2 MDN signing algorithm for the connector | `string` | `"NONE"` | no |
| <a name="input_as2_signing_algorithm"></a> [as2\_signing\_algorithm](#input\_as2\_signing\_algorithm) | AS2 signing algorithm for the connector | `string` | `"NONE"` | no |
| <a name="input_connector_name"></a> [connector\_name](#input\_connector\_name) | Name of the AWS Transfer Family connector | `string` | `"sftp-connector"` | no |
| <a name="input_create_secret"></a> [create\_secret](#input\_create\_secret) | Whether to create a new secret for SFTP credentials | `bool` | `false` | no |
| <a name="input_logging_role"></a> [logging\_role](#input\_logging\_role) | IAM role ARN for CloudWatch logging (if not provided, a new role will be created) | `string` | `null` | no |
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