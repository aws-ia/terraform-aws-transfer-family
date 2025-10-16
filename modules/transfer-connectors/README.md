<!-- BEGIN_TF_DOCS -->
# SFTP Connectors Terraform Module

This repository contains Terraform code which creates resources required to configure a Transfer Family SFTP Connector within AWS.

## Overview

This module creates and configures an SFTP connector with the following features:

- Basic connector setup with SFTP protocol and security policies
- Automated discovery of Host Keys of the remote server (Optional), used to verify server identity at each connection
- CloudWatch logging configuration

**Note**: You must provide an `access_role` ARN - an IAM role that the connector assumes to access S3 and other AWS services. This module does not create the IAM role for you.

## Quick Start

```hcl
module "transfer_connectors" {
  source = "aws-ia/transfer-family/aws//modules/transfer-connectors"

  url         = "sftp://external-server.com"
  access_role = "arn:aws:iam::123456789012:role/transfer-connector-role"
  sftp_username    = "sftp-user"
  sftp_private_key = file("~/.ssh/id_rsa")

  tags = {
    Environment = "Dev"
    Project     = "File Transfer"
  }
}
```

## Architecture

### High-Level Architecture

![High-Level Architecture of SFTP connector deployment](https://github.com/aws-ia/terraform-aws-transfer-family/blob/main/images/TF_Connectors.png)

Figure 1: High-Level Architecture of SFTP connector deployment using this Terraform module

## Features

### Transfer Connector Configuration

- Deploy SFTP connectors to connect with remote SFTP servers
- Connector name customization (default: "transfer-connector")
- S3 domain support for storing files
- AWS Secrets Manager support for storing authentication credentials
- Automated IAM role and policy configuration for logging, and for accessing S3 and Secrets Manager
- Integration with CloudWatch for logging and monitoring

### Automation Features

- EventBridge scheduler integration for automated file retrieval
- S3 events integration for automated file push

## Security Policy Support

- Standard policies (2023-07 and 2024-03)
- FIPS-compliant policy

## Validation Checks

- SSH host key validation
- Credential configuration verification
- IAM access role validation
- Security policy compatibility checks

## Best Practices

- Enable CloudWatch logging for audit and monitoring purposes
- Choose the security policies that have an overlap with algorithms supported by remote SFTP server (default is TransferSFTPConnectorSecurityPolicy-2024-03)
- Use proper tagging for resources (supported via tags variable)
- Provide the public portion of the remote server's host key(s), as trusted\_host\_keys
- If the remote server only accepts connections from known IP addresses, get the static IP addresses (output) of connector allowlisted by the server administrator

## Installation

To use this module in your Terraform configuration:

1. Reference the module in your Terraform code:

```hcl
module "transfer_connector" {
  source = "aws-ia/transfer-family/aws//modules/transfer-connectors"

  url         = "sftp://external-server.com"
  access_role = "arn:aws:iam::123456789012:role/transfer-connector-role"
  sftp_username    = "sftp-user"
  sftp_private_key = file("~/.ssh/id_rsa")

  tags = {
    Environment = "Dev"
    Project     = "File Transfer"
  }
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

### SFTP connector setup

```hcl
module "transfer-connectors" {
  source = "aws-ia/transfer-family/aws//modules/transfer-connectors"

  url         = "sftp://external-server.com"
  access_role = "arn:aws:iam::123456789012:role/transfer-connector-role"

  sftp_username    = "sftp-user"
  sftp_private_key = file("~/.ssh/id_rsa")

  trusted_host_keys = [
    "ssh-rsa AAAAB3NzaC1yc2EAAAA..."
  ]

  tags = {
    Environment = "Demo"
    Project     = "File Transfer"
  }
}
```

## Examples for automating file transfers

1. This example demonstrates how to use the SFTP connector to automatically discover and retrieve files from an external SFTP server on a scheduled basis using EventBridge Scheduler and Lambda for dynamic file discovery: https://github.com/aws-ia/terraform-aws-transfer-family/tree/main/examples/sftp-connector-automated-file-retrieve-dynamic

2. This example demonstrates how to use the SFTP connector to automatically retrieve specific files from an external SFTP server on a scheduled basis using EventBridge Scheduler: https://github.com/aws-ia/terraform-aws-transfer-family/tree/main/examples/sftp-connector-automated-file-retrieve-static

3. This example demonstrates how to use the SFTP connector to connect an S3 location to an external SFTP server, and automatically send files that are uploaded to S3: https://github.com/aws-ia/terraform-aws-transfer-family/tree/main/examples/sftp-connector-automated-file-send

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5 |
| <a name="requirement_archive"></a> [archive](#requirement\_archive) | >= 2.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.95.0 |
| <a name="requirement_external"></a> [external](#requirement\_external) | >= 2.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.1 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_archive"></a> [archive](#provider\_archive) | >= 2.0 |
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.95.0 |
| <a name="provider_external"></a> [external](#provider\_external) | >= 2.0 |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_iam_role.connector_logging_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.lambda_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.rotation_lambda_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.access_role_secrets_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.lambda_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.connector_logging_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.rotation_lambda_basic](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_lambda_function.rotation_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_permission.allow_secretsmanager](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_secretsmanager_secret.sftp_credentials](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret_rotation.sftp_credentials_rotation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_rotation) | resource |
| [aws_secretsmanager_secret_version.sftp_credentials](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [aws_transfer_connector.sftp_connector](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/transfer_connector) | resource |
| [terraform_data.discover_and_test_connector](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.trusted_host_keys_warning](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [archive_file.rotation_lambda_zip](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [external_external.connector_ips](https://registry.terraform.io/providers/hashicorp/external/latest/docs/data-sources/external) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_access_role"></a> [access\_role](#input\_access\_role) | ARN of the IAM role to attach to the SFTP connector | `string` | n/a | yes |
| <a name="input_url"></a> [url](#input\_url) | URL of the SFTP server to connect to (e.g., example.com or sftp://example.com:22) | `string` | n/a | yes |
| <a name="input_connector_name"></a> [connector\_name](#input\_connector\_name) | Name of the AWS Transfer Family connector | `string` | `"sftp-connector"` | no |
| <a name="input_logging_role"></a> [logging\_role](#input\_logging\_role) | IAM role ARN for CloudWatch logging (if not provided, a new role will be created) | `string` | `null` | no |
| <a name="input_secret_name"></a> [secret\_name](#input\_secret\_name) | Name for the new secret (only used when create\_secret is true) | `string` | `null` | no |
| <a name="input_secrets_manager_kms_key_arn"></a> [secrets\_manager\_kms\_key\_arn](#input\_secrets\_manager\_kms\_key\_arn) | ARN of the KMS key used to encrypt the secrets manager secret containing SFTP credentials | `string` | `null` | no |
| <a name="input_security_policy_name"></a> [security\_policy\_name](#input\_security\_policy\_name) | The name of the security policy to use for the connector (must be in the format TransferSFTPConnectorSecurityPolicy-*) | `string` | `"TransferSFTPConnectorSecurityPolicy-2024-03"` | no |
| <a name="input_sftp_private_key"></a> [sftp\_private\_key](#input\_sftp\_private\_key) | SFTP private key for authentication (optional if using password) | `string` | `""` | no |
| <a name="input_sftp_username"></a> [sftp\_username](#input\_sftp\_username) | SFTP username for authentication | `string` | `""` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to assign to resources | `map(string)` | `{}` | no |
| <a name="input_test_connector_post_deployment"></a> [test\_connector\_post\_deployment](#input\_test\_connector\_post\_deployment) | Whether to test the connector connection after deployment | `bool` | `false` | no |
| <a name="input_trusted_host_keys"></a> [trusted\_host\_keys](#input\_trusted\_host\_keys) | Trusted-Host-Key is the public portion of the host key(s) that is used to identify the remote server you need to connect to. You can enter the Trusted Host Key(s) now, or add them after creating the connector by using the host key information returned by the TestConnection action. Note that your connector will be able to create connections to the remote server only if the server's SSH fingerprint matches one of the provided Trusted Host Key(s). If empty, SSH key auto-discovery will run automatically. | `list(string)` | `[]` | no |
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