<!-- BEGIN_TF_DOCS -->
# AWS Transfer Family: SFTP Server with Internet Facing VPC Endpoint with Service Managed Users

This example demonstrates an AWS Transfer Family SFTP server deployment with a VPC endpoint with service managed users, and S3 storage integration.

## Overview

This example configures:

- VPC SFTP endpoint with service-managed users
  - Internet-facing endpoint using Elastic IP addresses
  - (Note: Omitting `address_allocation_ids` would create an internal VPC endpoint)
- Secure S3 bucket with KMS encryption
- User import through CSV configuration
- CloudWatch logging with customizable retention
- Configurable security groups with CIDR-based access control
- Optional workflow integration for file processing

## Features

### Server Configuration

- VPC SFTP endpoint deployment
  - Internet-facing endpoint when `address_allocation_ids` are specified
  - Internal endpoint when `address_allocation_ids` are not specified
- Service-managed authentication system
- Configurable logging retention
- Random resource name generation for uniqueness

### Storage Layer

- S3 bucket with:
  - KMS server-side encryption
  - Public access blocking
  - Versioning support
  - Secure bucket policies

### Security Implementation

- Service-managed authentication
- CloudWatch logging
- IAM role-based access control
- Configurable CIDR-based access control for ingress and egress traffic
- KMS key rotation enabled for encryption keys

## User Management

### CSV-Based User Import

Users are imported into the service using a CSV file (`users.csv`) for bulk import (Optional)

#### users.csv Structure

```csv
username,home_dir,public_key,role_arn
user1,/user1,ssh-rsa AAAA...,arn:aws:iam::123456789012:role/user1-role
```

#### Column Details

```
username: Unique identifier for SFTP access
home_dir: S3 bucket path (must start with /)
public_key: SSH public key for authentication (ssh-rsa or ecdsa-sha2-nistp256/384/521)
role_arn: (Optional) Custom IAM role ARN
```

#### Implementation

The user import is handled by the transfer-users module:

```
Located in: modules/transfer-users
Called by: examples/sftp-internet-facing-vpc-endpoint-service-managed-S3
```

Configuration in the example module:

```
module "sftp_users" {
    source = "../../modules/transfer-users"
    users = local.users
    create_test_user = true # Test user is for demo purposes
    server_id = module.transfer_server.server_id
    s3_bucket_name = module.s3_bucket.s3_bucket_id
    s3_bucket_arn = module.s3_bucket.s3_bucket_arn
    kms_key_id = aws_kms_key.transfer_family_key.arn
}
```

#### Considerations

```
CSV changes require terraform apply
Validate SSH key formats and IAM role ARNs
Ensure unique usernames and valid paths
Keep CSV file updated and backed up
```

### DNS Configuration (Optional)

1. This example supports Route 53 integration for custom domain management. To enable:

Set the variables `dns_provider='route53'`, `custom_hostname=<YOUR_CUSTOM_HOSTNAME>`, `route53_hosted_zone_name=<YOUR_ROUTE53_HOSTED_ZONE>`

```hcl
module "transfer_server" {

  # Other configurations go here

  dns_provider             = var.dns_provider
  custom_hostname          = var.custom_hostname
  route53_hosted_zone_name = var.route53_hosted_zone_name
}
```

2. This example also supports integration for custom domain management with other DNS providers. To enable:

Set the variables `dns_provider='other'`, `custom_hostname=<YOUR_CUSTOM_HOSTNAME>`

```hcl
module "transfer_server" {

  # Other configurations go here

  dns_provider             = var.dns_provider
  custom_hostname          = var.custom_hostname
}
```

## Security Considerations

- All S3 bucket public access is blocked
- KMS encryption is enabled for Amazon S3
- CloudWatch logging is enabled
- IAM roles are created. For production - review and apply permissions as required
- Configurable CIDR blocks for SFTP ingress and egress traffic
- Latest security policy (TransferSecurityPolicy-2024-01) applied

## VPC Endpoint Configuration

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
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.10.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.95.0 |
| <a name="requirement_awscc"></a> [awscc](#requirement\_awscc) | >= 0.24.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.95.0 |
| <a name="provider_random"></a> [random](#provider\_random) | >= 3.0.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_s3_bucket"></a> [s3\_bucket](#module\_s3\_bucket) | git::https://github.com/terraform-aws-modules/terraform-aws-s3-bucket.git | v5.0.0 |
| <a name="module_sftp_users"></a> [sftp\_users](#module\_sftp\_users) | ../../modules/transfer-users | n/a |
| <a name="module_transfer_server"></a> [transfer\_server](#module\_transfer\_server) | ../.. | n/a |
| <a name="module_vpc"></a> [vpc](#module\_vpc) | git::https://github.com/aws-ia/terraform-aws-vpc.git | v4.5.0 |

## Resources

| Name | Type |
|------|------|
| [aws_eip.sftp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip) | resource |
| [aws_kms_alias.transfer_family_key_alias](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.transfer_family_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_kms_key_policy.transfer_family_key_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key_policy) | resource |
| [aws_security_group.sftp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_vpc_security_group_egress_rule.sftp_egress](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.sftp_ingress](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [random_pet.name](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/pet) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_sftp_ingress_cidr_block"></a> [sftp\_ingress\_cidr\_block](#input\_sftp\_ingress\_cidr\_block) | List of CIDR blocks allowed to access SFTP. To set multiple cidr blocks seperate with comma '10.0.0.0/24, 10.0.1.0/24' | `string` | n/a | yes |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region | `string` | `"us-east-1"` | no |
| <a name="input_custom_hostname"></a> [custom\_hostname](#input\_custom\_hostname) | The custom hostname for the Transfer Family server | `string` | `null` | no |
| <a name="input_dns_provider"></a> [dns\_provider](#input\_dns\_provider) | The DNS provider for the custom hostname. Use null for no custom hostname | `string` | `null` | no |
| <a name="input_logging_role"></a> [logging\_role](#input\_logging\_role) | IAM role ARN that the Transfer Server assumes to write logs to CloudWatch Logs | `string` | `null` | no |
| <a name="input_route53_hosted_zone_name"></a> [route53\_hosted\_zone\_name](#input\_route53\_hosted\_zone\_name) | The name of the Route53 hosted zone to use (must end with a period, e.g., 'example.com.') | `string` | `null` | no |
| <a name="input_sftp_egress_cidr_block"></a> [sftp\_egress\_cidr\_block](#input\_sftp\_egress\_cidr\_block) | List of CIDR block for outbound traffic from SFTP server. To set multiple cidr blocks seperate with comma '10.0.0.0/24, 10.0.1.0/24' | `string` | `"0.0.0.0/0"` | no |
| <a name="input_stage"></a> [stage](#input\_stage) | Deployment stage | `string` | `"dev"` | no |
| <a name="input_users_file"></a> [users\_file](#input\_users\_file) | Path to CSV file containing user configurations | `string` | `null` | no |
| <a name="input_workflow_details"></a> [workflow\_details](#input\_workflow\_details) | Workflow details to attach to the transfer server | <pre>object({<br/>    on_upload = optional(object({<br/>      execution_role = string<br/>      workflow_id    = string<br/>    }))<br/>    on_partial_upload = optional(object({<br/>      execution_role = string<br/>      workflow_id    = string<br/>    }))<br/>  })</pre> | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_server_endpoint"></a> [server\_endpoint](#output\_server\_endpoint) | The endpoint of the created Transfer Family server |
| <a name="output_server_id"></a> [server\_id](#output\_server\_id) | The ID of the created Transfer Family server |
| <a name="output_sftp_bucket_name"></a> [sftp\_bucket\_name](#output\_sftp\_bucket\_name) | The name of the S3 bucket used for SFTP storage |
| <a name="output_user_details"></a> [user\_details](#output\_user\_details) | Map of users with their details including secret names and ARNs |
<!-- END_TF_DOCS -->