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

![High-Level Architecture](https://github.com/aws-ia/terraform-aws-transfer-family/blob/main/images/AWS%20Transfer%20Family%20Architecture.png)

Figure 1: High-level architecture of AWS Transfer Family deployment using this Terraform module

![Architecture using VPC Endpoints](https://github.com/aws-ia/terraform-aws-transfer-family/blob/main/images/Transfer%20Family%20VPC%20endpoint.png)

Figure 2: Architecture using VPC endpoints of the AWS Transfer Family deployment using this Terraform module

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
- Mandatory Elastic IP address allocation and association checks for Internet-facing VPC deployments

## Best Practices

- Enable CloudWatch logging for audit and monitoring purposes (optional, configurable via enable_logging variable)
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
  - Hosting Server using Public or VPC configuration
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

## Support & Feedback

The AWS Transfer Family module for Terraform is maintained by AWS Solution Architects. It is not part of an AWS service and support is provided best-effort by the AWS Storage community.

To post feedback, submit feature ideas, or report bugs, please use the [Issues section](https://github.com/aws-ia/terraform-aws-transfer-family/issues) of this GitHub repo.

If you are interested in contributing to the Storage Gateway module, see the [Contribution guide](https://github.com/aws-ia/terraform-aws-transfer-family/blob/main/CONTRIBUTING.md).

## Requirements

| Name                                                                     | Version   |
| ------------------------------------------------------------------------ | --------- |
| <a name="requirement_terraform"></a> [terraform](#requirement_terraform) | >= 1.5    |
| <a name="requirement_aws"></a> [aws](#requirement_aws)                   | >= 5.95.0 |

## Providers

| Name                                             | Version   |
| ------------------------------------------------ | --------- |
| <a name="provider_aws"></a> [aws](#provider_aws) | >= 5.83.0 |

## Modules

No modules.

## Resources

| Name                                                                                                                                            | Type        |
| ----------------------------------------------------------------------------------------------------------------------------------------------- | ----------- |
| [aws_cloudwatch_log_group.transfer](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group)           | resource    |
| [aws_route53_record.sftp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record)                           | resource    |
| [aws_transfer_server.transfer_server](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/transfer_server)              | resource    |
| [aws_transfer_tag.with_custom_domain_name](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/transfer_tag)            | resource    |
| [aws_transfer_tag.with_custom_domain_route53_zone_id](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/transfer_tag) | resource    |
| [aws_route53_zone.selected](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route53_zone)                        | data source |

## Inputs

| Name                                                                                                      | Description                                                                                                                           | Type                                                                                                                                                                                                                                      | Default                            | Required |
| --------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------- | :------: |
| <a name="input_custom_hostname"></a> [custom_hostname](#input_custom_hostname)                            | The custom hostname for the Transfer Family server                                                                                    | `string`                                                                                                                                                                                                                                  | `null`                             |    no    |
| <a name="input_dns_provider"></a> [dns_provider](#input_dns_provider)                                     | The DNS provider for the custom hostname. Use 'none' for no custom hostname                                                           | `string`                                                                                                                                                                                                                                  | `null`                             |    no    |
| <a name="input_domain"></a> [domain](#input_domain)                                                       | The domain of the storage system that is used for file transfers                                                                      | `string`                                                                                                                                                                                                                                  | `"S3"`                             |    no    |
| <a name="input_enable_logging"></a> [enable_logging](#input_enable_logging)                               | Enable CloudWatch logging for the transfer server                                                                                     | `bool`                                                                                                                                                                                                                                    | `false`                            |    no    |
| <a name="input_endpoint_details"></a> [endpoint_details](#input_endpoint_details)                         | VPC endpoint configuration block for the Transfer Server                                                                              | <pre>object({<br/> address_allocation_ids = optional(list(string))<br/> security_group_ids = list(string)<br/> subnet_ids = list(string)<br/> vpc_id = string<br/> })</pre>                                                               | `null`                             |    no    |
| <a name="input_endpoint_type"></a> [endpoint_type](#input_endpoint_type)                                  | The type of endpoint that you want your transfer server to use                                                                        | `string`                                                                                                                                                                                                                                  | `"PUBLIC"`                         |    no    |
| <a name="input_identity_provider"></a> [identity_provider](#input_identity_provider)                      | Identity provider configuration                                                                                                       | `string`                                                                                                                                                                                                                                  | `"SERVICE_MANAGED"`                |    no    |
| <a name="input_log_group_kms_key_id"></a> [log_group_kms_key_id](#input_log_group_kms_key_id)             | encryption key for cloudwatch log group                                                                                               | `string`                                                                                                                                                                                                                                  | `null`                             |    no    |
| <a name="input_log_retention_days"></a> [log_retention_days](#input_log_retention_days)                   | Number of days to retain logs for                                                                                                     | `number`                                                                                                                                                                                                                                  | `30`                               |    no    |
| <a name="input_logging_role"></a> [logging_role](#input_logging_role)                                     | IAM role ARN that the Transfer Server assumes to write logs to CloudWatch Logs                                                        | `string`                                                                                                                                                                                                                                  | `null`                             |    no    |
| <a name="input_protocols"></a> [protocols](#input_protocols)                                              | Specifies the file transfer protocol or protocols over which your file transfer protocol client can connect to your server's endpoint | `list(string)`                                                                                                                                                                                                                            | <pre>[<br/> "SFTP"<br/>]</pre>     |    no    |
| <a name="input_route53_hosted_zone_name"></a> [route53_hosted_zone_name](#input_route53_hosted_zone_name) | The name of the Route53 hosted zone to use (must end with a period, e.g., 'example.com.')                                             | `string`                                                                                                                                                                                                                                  | `null`                             |    no    |
| <a name="input_security_policy_name"></a> [security_policy_name](#input_security_policy_name)             | Specifies the name of the security policy that is attached to the server. If not provided, the default security policy will be used.  | `string`                                                                                                                                                                                                                                  | `"TransferSecurityPolicy-2024-01"` |    no    |
| <a name="input_server_name"></a> [server_name](#input_server_name)                                        | The name of the Transfer Family server                                                                                                | `string`                                                                                                                                                                                                                                  | `"transfer-server"`                |    no    |
| <a name="input_tags"></a> [tags](#input_tags)                                                             | A map of tags to assign to the resource                                                                                               | `map(string)`                                                                                                                                                                                                                             | `{}`                               |    no    |
| <a name="input_workflow_details"></a> [workflow_details](#input_workflow_details)                         | Workflow details to attach to the transfer server                                                                                     | <pre>object({<br/> on_upload = optional(object({<br/> execution_role = string<br/> workflow_id = string<br/> }))<br/> on_partial_upload = optional(object({<br/> execution_role = string<br/> workflow_id = string<br/> }))<br/> })</pre> | `null`                             |    no    |

## Outputs

| Name                                                                             | Description                                        |
| -------------------------------------------------------------------------------- | -------------------------------------------------- |
| <a name="output_server_endpoint"></a> [server_endpoint](#output_server_endpoint) | The endpoint of the created Transfer Family server |
| <a name="output_server_id"></a> [server_id](#output_server_id)                   | The ID of the transfer server                      |

<!-- END_TF_DOCS -->
