<!-- BEGIN_TF_DOCS -->
# AWS Transfer Family Terraform Module

This repository contains Terraform code which creates resources required to run a Transfer Family Server within AWS.

# AWS Transfer Family Terraform Modules

![Terraform Version](https://img.shields.io/badge/Terraform-%3E%3D1.0.7-blue.svg)
[![AWS Provider Version](https://img.shields.io/badge/AWS%20Provider-%3E%3D5.83.0-orange.svg)](https://registry.terraform.io/providers/hashicorp/aws/latest)
[![License](https://img.shields.io/badge/License-Apache%202.0-green.svg)](./LICENSE)

## Overview

This module creates and configures an AWS Transfer Server with the following features:

- Basic Transfer Server setup with SFTP protocol and security policies
- Custom hostname support through AWS Route53 or other DNS providers
- CloudWatch logging configuration with customizable retention
- Built-in validation checks for DNS and hostname configurations

## Quick Start

```hcl
module "transfer_sftp" {
  source = "github.com/aws-samples/aws-transfer-family-terraform-modules//modules/sftp-public-endpoint"
  identity_provider_type = "SERVICE_MANAGED"
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

![High-Level Architecture](/Users/divvy/terraform\_project/images/hlarch.png)

*Figure 1: High-level architecture of AWS Transfer Family deployment using this Terraform module*

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
- Flexible DNS provider options (Route53 or other providers)
- Custom hostname configuration
- Route53 hosted zone integration
- Automatic CNAME record creation (when using Route53)

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

## Prerequisites

- Terraform v1.0.7 or later
- AWS Provider v5.83.0 or later
- For custom hostname (based on the code):
  - If using Route53: A public Route53 hosted zone (seen in `data "aws_route53_zone"` with `private_zone = false`)
  - Custom hostname must be a subdomain of the hosted zone (enforced by the lifecycle precondition)

## Best Practices

- Enable CloudWatch logging for audit and monitoring purposes (optional, configurable via enable\_logging variable)
- Use the latest security policies (default is TransferSecurityPolicy-2024-01, configurable with validation)
- Follow the principle of least privilege for logging IAM roles (using AWS managed policy AWSTransferLoggingAccess)
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
  source = "https://github.com/aws-ia/terraform-aws-transfer-family"
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
  source = "path/to/module"
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

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0.7 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.83.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.83.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_group.transfer](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_iam_role.logging](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.logging](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_route53_record.sftp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_transfer_server.transfer_server](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/transfer_server) | resource |
| [aws_transfer_tag.with_custom_domain_name](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/transfer_tag) | resource |
| [aws_transfer_tag.with_custom_domain_route53_zone_id](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/transfer_tag) | resource |
| [aws_route53_zone.selected](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route53_zone) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_custom_hostname"></a> [custom\_hostname](#input\_custom\_hostname) | The custom hostname for the Transfer Family server | `string` | `null` | no |
| <a name="input_dns_provider"></a> [dns\_provider](#input\_dns\_provider) | The DNS provider for the custom hostname. Use 'none' for no custom hostname | `string` | `null` | no |
| <a name="input_domain"></a> [domain](#input\_domain) | The domain of the storage system that is used for file transfers | `string` | `"S3"` | no |
| <a name="input_enable_logging"></a> [enable\_logging](#input\_enable\_logging) | Enable CloudWatch logging for the transfer server | `bool` | `false` | no |
| <a name="input_endpoint_type"></a> [endpoint\_type](#input\_endpoint\_type) | The type of endpoint that you want your transfer server to use | `string` | `"PUBLIC"` | no |
| <a name="input_identity_provider"></a> [identity\_provider](#input\_identity\_provider) | Identity provider configuration | `string` | `"SERVICE_MANAGED"` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | Number of days to retain logs for | `number` | `30` | no |
| <a name="input_protocols"></a> [protocols](#input\_protocols) | Specifies the file transfer protocol or protocols over which your file transfer protocol client can connect to your server's endpoint | `list(string)` | <pre>[<br/>  "SFTP"<br/>]</pre> | no |
| <a name="input_route53_hosted_zone_name"></a> [route53\_hosted\_zone\_name](#input\_route53\_hosted\_zone\_name) | The name of the Route53 hosted zone to use (must end with a period, e.g., 'example.com.') | `string` | `null` | no |
| <a name="input_security_policy_name"></a> [security\_policy\_name](#input\_security\_policy\_name) | Specifies the name of the security policy that is attached to the server. If not provided, the default security policy will be used. | `string` | `"TransferSecurityPolicy-2024-01"` | no |
| <a name="input_server_name"></a> [server\_name](#input\_server\_name) | The name of the Transfer Family server | `string` | `"transfer-server"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to assign to the resource | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_server_endpoint"></a> [server\_endpoint](#output\_server\_endpoint) | The endpoint of the created Transfer Family server |
| <a name="output_server_id"></a> [server\_id](#output\_server\_id) | The ID of the transfer server |
<!-- END_TF_DOCS -->