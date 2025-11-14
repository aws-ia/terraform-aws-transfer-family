<!-- BEGIN_TF_DOCS -->
# Transfer Web App Module

This module creates web application resources for AWS Transfer Family.

## Overview

This module creates and configures a Transfer Family web app and related dependencies:

- IAM Identity Center organizational or account instance integration
- S3 Access Grants instance integration
- S3 Access Grants creation for fine-grained permissions
- Transfer Family web app provisioning, configuration, and customization
- Cross-Origin Resource Sharing (CORS) policies for S3 buckets
- Create a CloudFront distribution for custom URL
- Logging and monitoring via AWS CloudTrail

## Features

- **Browser-based interface** providing secure access to Amazon S3 data
- **Authentication** through AWS IAM Identity Center, supporting existing identity provider federation, multi-factor authentication
- **Granular permission management** through S3 Access Grants for user and group-level access control, folder and file-level permissions, and time-based access policies
- **Built-in compliance** including HIPAA eligibility, PCI DSS compliance, SOC 1, 2, and 3, and ISO certifications
- **Customization options** including logo, favicon, and personalized browser page title
- **Detailed audit trails** through CloudTrail capturing user authentication and data operations

## Quick Start

```hcl
module "transfer_web_app" {
  source = "aws-ia/transfer-family/aws//modules/transfer-web-app"

  # Configuration parameters
}
```

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.95.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.95.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_iam_role.transfer_web_app](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.transfer_web_app](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_transfer_web_app.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/transfer_web_app) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.assume_role_transfer](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.transfer_web_app](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_ssoadmin_instances.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssoadmin_instances) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_custom_title"></a> [custom\_title](#input\_custom\_title) | Custom title for the web app | `string` | `null` | no |
| <a name="input_favicon_file"></a> [favicon\_file](#input\_favicon\_file) | Path to favicon file for web app customization | `string` | `null` | no |
| <a name="input_iam_role_name"></a> [iam\_role\_name](#input\_iam\_role\_name) | Name for the IAM role used by the Transfer web app | `string` | `"transfer-web-app-role"` | no |
| <a name="input_identity_center_instance_arn"></a> [identity\_center\_instance\_arn](#input\_identity\_center\_instance\_arn) | ARN of the Identity Center instance. If not provided, will use the first available instance | `string` | `null` | no |
| <a name="input_logo_file"></a> [logo\_file](#input\_logo\_file) | Path to logo file for web app customization | `string` | `null` | no |
| <a name="input_provisioned_units"></a> [provisioned\_units](#input\_provisioned\_units) | Number of provisioned web app units | `number` | `1` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to assign to the resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_iam_role_arn"></a> [iam\_role\_arn](#output\_iam\_role\_arn) | The ARN of the IAM role used by the Transfer web app |
| <a name="output_iam_role_name"></a> [iam\_role\_name](#output\_iam\_role\_name) | The name of the IAM role used by the Transfer web app |
| <a name="output_web_app_access_endpoint"></a> [web\_app\_access\_endpoint](#output\_web\_app\_access\_endpoint) | The access endpoint URL for the Transfer web app |
| <a name="output_web_app_arn"></a> [web\_app\_arn](#output\_web\_app\_arn) | The ARN of the Transfer web app |
| <a name="output_web_app_id"></a> [web\_app\_id](#output\_web\_app\_id) | The ID of the Transfer web app |
<!-- END_TF_DOCS -->